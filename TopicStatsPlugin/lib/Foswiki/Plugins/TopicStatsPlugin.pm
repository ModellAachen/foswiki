# See bottom of file for default license and copyright information

=begin TML

---+ package TopicStatsPlugin

=cut

# change the package name!!!
package Foswiki::Plugins::TopicStatsPlugin;

# Always use strict to enforce variable scoping
use strict;

require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package.
# This should always be $Rev: 4684 (2009-08-18) $ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
our $VERSION = '$Rev: 4684 (2009-08-18) $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
our $RELEASE = '$Date: 2010-06-04 17:13:53 +0200 (Fri, 04 Jun 2010) $';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION =
  'TopicStats Plugin to generate Topic-wise list of users accessing the Topic';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use
# preferences set in the plugin topic. This is required for compatibility
# with older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, leave $NO_PREFS_IN_TOPIC at 1 and use
# =$Foswiki::cfg= entries set in =LocalSite.cfg=, or if you want the users
# to be able to change settings, then use standard Foswiki preferences that
# can be defined in your %USERSWEB%.SitePreferences and overridden at the web
# and topic level.
our $NO_PREFS_IN_TOPIC = 1;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

*REQUIRED*

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using =Foswiki::Func::writeWarning= and return 0. In this case
%<nop>FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

__Note:__ Please align macro names with the Plugin name, e.g. if
your Plugin is called !FooBarPlugin, name macros FOOBAR and/or
FOOBARSOMETHING. This avoids namespace issues.

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Register the _EXAMPLETAG function to handle %EXAMPLETAG{...}%
    # This will be called whenever %EXAMPLETAG% or %EXAMPLETAG{...}% is
    # seen in the topic text.
    Foswiki::Func::registerTagHandler( 'TOPICSTATS', \&_TOPICSTATS );

    # Plugin correctly initialized
    return 1;
}

# The function used to handle the %TOPICSTATS{...}% macro
# You would have one of these for each macro you want to process.
sub _TOPICSTATS {
    my ( $session, $params, $topic, $web ) = @_;

    # $session  - a reference to the Foswiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a Foswiki::Attrs object containing
    #             parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             (unnamed) parameter.
    # $topic - name of the topic in the query
    # $web   - name of the web in the query
    # Return: the result of processing the macro. This will replace the
    # macro call in the final text.

    my $logDate  = $params->{logdate} || '';
    my $script   = $params->{script}  || 'all';
    my $maxItems = $params->{max}     || 25;
    $topic = $params->{topic} if $params->{topic};
    $web   = $params->{web}   if $params->{web};

    $maxItems = 25    if $maxItems !~ /^\d+/;
    $script   = 'all' if $script !~ /view|save|all/;

    require Foswiki::Time;
    unless ($logDate) {
        $logDate =
          Foswiki::Time::formatTime( time(), '$year$mo', 'servertime' );
    }

    my $logMonth;
    my $logYear;
    if ( $logDate =~ /^(\d\d\d\d)(\d\d)$/ ) {
        $logYear  = $1;
        $logMonth = $2;
    }
    else {
        _printMsg( $session, "!Error in date $logDate - must be YYYYMM" );
        return;
    }

    my $logMonthYear =
      $Foswiki::Time::ISOMONTH[ $logMonth - 1 ] . ' ' . $logYear;

    # Do a single data collection pass on the temporary copy of logfile,
    # then process each web once.
    my @users =
      _collectLogData( $session, "1 $logMonthYear", $web, $topic, $script );

    return join ' ', @users;
}

sub _collectLogData {
    my ( $session, $start, $web, $topic, $script ) = @_;

    $start = Foswiki::Time::parseTime($start);

    my @users = ();

    my $it = $session->logger->eachEventSince( $start, 'info' );
    while ( $it->hasNext() ) {
        my $line = $it->next();
        my ( $date, $logFileUserName, $opName, $webTopic, $notes, $ip ) =
          @$line;

        # ignore minor changes - not statistically helpful
        next if ( $notes && $notes =~ /(minor|dontNotify)/ );

        # ignore searches for now - idea: make a "top search phrase list"
        next if ( $opName && $opName =~ /(search)/ );

        # ignore "renamed web" log lines
        next if ( $opName && $opName =~ /(renameweb)/ );

        # ignore "change password" log lines
        next if ( $opName && $opName =~ /(changepasswd)/ );

        next if ( $script =~ /view|save/ && ( $opName ne $script ) );

        my ( $webName, $topicName ) =
          ( $webTopic =~
/(^$Foswiki::regex{webNameRegex})\.($Foswiki::regex{wikiWordRegex}$|$Foswiki::regex{abbrevRegex}|.+)/
          );

        next if ( $webName ne $web );

        next if ( $topicName ne $topic );

        push @users, $logFileUserName;

    }

    return @users;

}
