package Foswiki::Plugins::GoogleAnalyticsPlugin;

use strict;
use Foswiki::Func;

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package. This should always be in the format
# $Rev$ so that Foswiki can determine the checked-in status of the
# extension.
our $VERSION = '$Rev$';

# $RELEASE is used in the "Find More Extensions" automation in configure.
# It is a manually maintained string used to identify functionality steps.
# You can use any of the following formats:
# tuple   - a sequence of integers separated by . e.g. 1.2.3. The numbers
#           usually refer to major.minor.patch release or similar. You can
#           use as many numbers as you like e.g. '1' or '1.2.3.4.5'.
# isodate - a date in ISO8601 format e.g. 2009-08-07
# date    - a date in 1 Jun 2009 format. Three letter English month names only.
# Note: it's important that this string is exactly the same in the extension
# topic - if you use %$RELEASE% with BuildContrib this is done automatically.
our $RELEASE = '2.1.1';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION =
  'Adds Google Analytics javascript code to specified pages';
our $NO_PREFS_IN_TOPIC = 1;
our $pluginName        = 'GoogleAnalyticsPlugin';

my $topic;
my $web;
my $user;
my $debug;
my $footerAdded = 0;

sub initPlugin {
    my ( $inTopic, $inWeb, $inUser, $installWeb ) = @_;

    $topic       = $inTopic;
    $web         = $inWeb;
    $user        = $inUser;
    $footerAdded = 0;

    return 1;
}

=pod

=cut

sub postRenderingHandler {

    _debug("sub postRenderingHandler");

    return if $footerAdded;
    return if !( $_[0] =~ /<\/body>/ );

    return if !_isTrackingEnabledForScript( $ENV{FOSWIKI_ACTION} );
    return if !_isTrackingEnabledForUser($user);
    return if !_isTrackingEnabledForWeb($web);

    my $result = _addToFooter( $_[0], _htmlTag() );
    $footerAdded = 1 if $result;
}

=pod

=cut

sub _isTrackingEnabledForScript {
    my ($script) = @_;

    $script ||= '';
    my $enabled = 0;

    if ( _isTrackingEnabledInSetting( 'Enable', 'Scripts', $script ) ) {
        $enabled = 1;
    }
    _debug("sub _isTrackingEnabledForScript:$script; enabled=$enabled");
    return $enabled;
}

=pod

=cut

sub _isTrackingEnabledForUser {
    my ($user) = @_;

    my $enabled  = 0;
    my $wikiName = Foswiki::Func::getWikiName($user);

    if ( _isTrackingEnabledInSetting( 'Enable', 'Users', $wikiName ) ) {
        $enabled = 1;
    }
    if ( !_isTrackingEnabledInSetting( 'Disable', 'Users', $wikiName ) ) {
        $enabled = 0;
    }
    _debug("sub _isTrackingEnabledForUser:$wikiName; enabled=$enabled");
    return $enabled;
}

=pod

=cut

sub _isTrackingEnabledForWeb {
    my ($web) = @_;

    my $enabled = 0;
    if ( _isTrackingEnabledInSetting( 'Enable', 'Webs', $web ) ) {
        $enabled = 1;
    }
    if ( !_isTrackingEnabledInSetting( 'Disable', 'Webs', $web ) ) {
        $enabled = 0;
    }
    _debug("sub _isTrackingEnabledForWeb:$web; enabled=$enabled");
    return $enabled;
}

=pod

_addToFooter( $html, $addThis )

Adds $addThis just before the end </body> tag.

=cut

sub _addToFooter {
    $_[0] =~ s/(<\/body>.*?<\/html>)/$_[1]$1/gs;
    return defined $1;
}

=pod

Inserts the user's Web Property ID into the javascript html string and returns the html.

=cut

sub _htmlTag {

    my $key = $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{WebPropertyId};
    _debug("sub _htmlTag");
    ($key) or _debug("\t no {WebPropertyId} key found");
    if ( !$key ) {

        # still support GOOGLESITEKEY as long as {WebPropertyId} is not entered
        $key = Foswiki::Func::getPreferencesValue( "GOOGLESITEKEY", $web );
        _debug("\t retrieving value of GOOGLESITEKEY in web '$web'");
        _debug("\t key=$key") if $key;
    }
    $key ||= '{WebPropertyId} or GOOGLESITEKEY not found';
    $key =~ s/^[[:space:]]+//s;    # trim at start
    $key =~ s/[[:space:]]+$//s;    # trim at end

    my $html = <<END;
<!-- GOOGLEANALYTICSPLUGIN --><script type="text/javascript">
var gaJsHost = (("https:" == document.location.protocol) ? "https://ssl." : "http://www.");
document.write(unescape("%3Cscript src='" + gaJsHost + "google-analytics.com/ga.js' type='text/javascript'%3E%3C/script%3E"));
</script>
<script type="text/javascript">
try {
var pageTracker = _gat._getTracker("$key");
pageTracker._trackPageview();
} catch(err) {}</script>
END

    return $html;
}

=pod

Checks if a given value matches a preferences pattern. The pref pattern
actually is a list of patterns. The function returns true if 
at least one of the patterns in the list matches.

=cut

sub _isTrackingEnabledInSetting {
    my ( $mode, $key, $value ) = @_;

    $value ||= '';
    my $setting = $Foswiki::cfg{Plugins}{$pluginName}{Tracking}{$mode}{$key}
      || '';

    _debug(
        "sub _isTrackingEnabledInSetting; mode=$mode, key=$key, value=$value");

    # if setting is empty:
    if ( !$setting ) {
        _debug("\t setting is empty");
        return 1 if $mode =~ /^Disable/i;
        return 0 if $mode =~ /^Enable/i;
    }

    # is setting is '*':
    if ( $setting =~ /^[[:space:]]*\*[[:space:]]*$/ ) {
        _debug("\t setting is *");
        return 0 if $mode =~ /^Disable/i;
        return 1 if $mode =~ /^Enable/i;
    }

    # check if value is in setting:
    my @items = split( /[[:space:]]*,[[:space:]]*/s, $setting );
    if ( grep /$value/, @items ) {
        _debug("\t '$value' is in items");
        return 0 if $mode =~ /^Disable/i;
        return 1 if $mode =~ /^Enable/i;
    }

    # return default
    _debug("\t return default");
    return 1 if $mode =~ /^Disable/i;
    return 0 if $mode =~ /^Enable/i;
}

=pod

=cut

sub _debug {
    my ($text) = @_;
    return if !$Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Debug};

    $text = "$pluginName: $text";

    #print STDERR $text . "\n";
    Foswiki::Func::writeDebug("$text");
}
1;
