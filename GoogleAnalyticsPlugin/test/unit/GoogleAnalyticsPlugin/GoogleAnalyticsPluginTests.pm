use strict;

# tests for basic formatting

package GoogleAnalyticsPluginTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;

#use Foswiki::UI::Save;
use Error qw( :try );

use Foswiki::Plugins::GoogleAnalyticsPlugin;
use Data::Dumper;    # for debugging

my $DEBUG  = 1;
my $WEB_ID = 'MY_GOOGLE_WEB_ID';
my $userWikiName;

sub new {
    my $self = shift()->SUPER::new( 'GoogleAnalyticsPluginFunctions', @_ );
    return $self;
}

sub loadExtraConfig {
    my $this = shift;
    $this->SUPER::loadExtraConfig();

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Enabled} = 1;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{WebPropertyId} = $WEB_ID;
    $userWikiName = Foswiki::Func::getWikiName( $this->{test_user} );
}

#sub tear_down {
#    my $this = shift;
#}

=pod

=cut

sub test_script_output {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Enable}{Webs} = '*';
    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Disable}{Webs} = '';
    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{WebPropertyId} = $WEB_ID;
    Foswiki::Plugins::GoogleAnalyticsPlugin::initPlugin(
        $this->{test_topic}, $this->{test_web},
        $this->{test_user},  'System'
    );

    my $html = <<HTML_END;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
	<meta http-equiv="content-type" content="text/html; charset=utf-8" />
	<title>outrageous</title>
</head>
<body>
Her outrageous leotards and sexy routines.
<!-- comment 1 --></body><!-- comment 2 -->
</html><!-- comment 3 -->
HTML_END

    Foswiki::Plugins::GoogleAnalyticsPlugin::postRenderingHandler($html);
    my $result = $html;

    my $expected = <<END_EXPECTED;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
	<meta http-equiv="content-type" content="text/html; charset=utf-8" />
	<title>outrageous</title>
</head>
<body>
Her outrageous leotards and sexy routines.
<!-- comment 1 --><!-- GOOGLEANALYTICSPLUGIN --><script type="text/javascript">
var gaJsHost = (("https:" == document.location.protocol) ? "https://ssl." : "http://www.");
document.write(unescape("%3Cscript src='" + gaJsHost + "google-analytics.com/ga.js' type='text/javascript'%3E%3C/script%3E"));
</script>
<script type="text/javascript">
try {
var pageTracker = _gat._getTracker("$WEB_ID");
pageTracker._trackPageview();
} catch(err) {}</script>
</body><!-- comment 2 -->
</html><!-- comment 3 -->
END_EXPECTED

    _trimSpaces($result);
    _trimSpaces($expected);
    $this->assert_str_equals( $expected, $result );
}

=pod

If setting {WebPropertyId} cannot be found, use the previous GOOGLESITEKEY.

=cut

sub test_script_output_GOOGLESITEKEY {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Enable}{Webs} = '*';
    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Disable}{Webs} = '';
    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{WebPropertyId} = '';
    Foswiki::Plugins::GoogleAnalyticsPlugin::initPlugin(
        $this->{test_topic}, $this->{test_web},
        $this->{test_user},  'System'
    );
    $this->_setWebPref( "GOOGLESITEKEY", "MY_OLD_GOOGLESITEKEY" );

    my $query = new Unit::Request("");
    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    my $t = new Foswiki( $this->{test_user_login}, $query );

    my $html = <<HTML_END;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
	<meta http-equiv="content-type" content="text/html; charset=utf-8" />
	<title>outrageous</title>
</head>
<body>
Her outrageous leotards and sexy routines.
<!-- comment 1 --></body><!-- comment 2 -->
</html><!-- comment 3 -->
HTML_END

    Foswiki::Plugins::GoogleAnalyticsPlugin::postRenderingHandler($html);
    my $result = $html;

    my $expected = <<END_EXPECTED;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
	<meta http-equiv="content-type" content="text/html; charset=utf-8" />
	<title>outrageous</title>
</head>
<body>
Her outrageous leotards and sexy routines.
<!-- comment 1 --><!-- GOOGLEANALYTICSPLUGIN --><script type="text/javascript">
var gaJsHost = (("https:" == document.location.protocol) ? "https://ssl." : "http://www.");
document.write(unescape("%3Cscript src='" + gaJsHost + "google-analytics.com/ga.js' type='text/javascript'%3E%3C/script%3E"));
</script>
<script type="text/javascript">
try {
var pageTracker = _gat._getTracker("MY_OLD_GOOGLESITEKEY");
pageTracker._trackPageview();
} catch(err) {}</script>
</body><!-- comment 2 -->
</html><!-- comment 3 -->
END_EXPECTED

    _trimSpaces($result);
    _trimSpaces($expected);
    $this->assert_str_equals( $expected, $result );

    $t->finish();
}

=pod

=cut

sub test_tracking_enabled_webs_all {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Enable}{Webs} =
      ' * ';
    my $web = 'Main';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Enable', 'Webs', $web );
    $this->assert_equals( 1, $enabled );
}

=pod

=cut

sub test_tracking_enabled_webs_empty {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Enable}{Webs} = '';
    my $web = 'Main';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Enable', 'Webs', $web );
    $this->assert_equals( 0, $enabled );
}

=pod

=cut

sub test_tracking_enabled_webs_named {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Enable}{Webs} =
      ' Main, ';
    my $web = 'Main';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Enable', 'Webs', $web );
    $this->assert_equals( 1, $enabled );
}

=pod

=cut

sub test_tracking_enabled_webs_named_other {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Enable}{Webs} =
      ' Sandbox, ';
    my $web = 'Main';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Enable', 'Webs', $web );
    $this->assert_equals( 0, $enabled );
}

=pod

=cut

sub test_tracking_disabled_webs_all {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Disable}{Webs} =
      ' * ';
    my $web = 'Main';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Disable', 'Webs', $web );
    $this->assert_equals( 0, $enabled );
}

=pod

=cut

sub test_tracking_disabled_webs_empty {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Disable}{Webs} = '';
    my $web = 'Main';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Disable', 'Webs', $web );
    $this->assert_equals( 1, $enabled );
}

=pod

=cut

sub test_tracking_disabled_webs_named {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Disable}{Webs} =
      ',Main';
    my $web = 'Main';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Disable', 'Webs', $web );
    $this->assert_equals( 0, $enabled );
}

=pod

=cut

sub test_tracking_disabled_webs_named_other {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Disable}{Webs} =
      ',Sandbox,';
    my $web = 'Main';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Disable', 'Webs', $web );
    $this->assert_equals( 1, $enabled );
}

=pod

=cut

sub test_tracking_enabled_users_all {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Enable}{Users} =
      ' * ';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Enable', 'Users', $userWikiName );
    $this->assert_equals( 1, $enabled );
}

=pod

=cut

sub test_tracking_enabled_users_empty {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Enable}{Users} = '';
    my $user = $this->{test_user};
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Enable', 'Users', $userWikiName );
    $this->assert_equals( 0, $enabled );
}

=pod

=cut

sub test_tracking_enabled_users_named {
    my ($this) = @_;

    my $userWikiName = Foswiki::Func::getWikiName( $this->{test_user} );
    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Enable}{Users} =
      " $userWikiName ";
    my $user = $this->{test_user};
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Enable', 'Users', $userWikiName );
    $this->assert_equals( 1, $enabled );
}

=pod

=cut

sub test_tracking_enabled_users_named_other {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Enable}{Users} =
      ' admin';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Enable', 'Users', $userWikiName );
    $this->assert_equals( 0, $enabled );
}

=pod

=cut

sub test_tracking_disabled_users_all {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Disable}{Users} =
      ' * ';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Disable', 'Users', $userWikiName );
    $this->assert_equals( 0, $enabled );
}

=pod

=cut

sub test_tracking_disabled_users_empty {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Disable}{Users} =
      '';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Disable', 'Users', $userWikiName );
    $this->assert_equals( 1, $enabled );
}

=pod

=cut

sub test_tracking_disabled_users_named {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Disable}{Users} =
      " $userWikiName ";
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Disable', 'Users', $userWikiName );
    $this->assert_equals( 0, $enabled );
}

=pod

=cut

sub test_tracking_disabled_users_named_other {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Disable}{Users} =
      ' admin';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Disable', 'Users', $userWikiName );
    $this->assert_equals( 1, $enabled );
}

=pod

=cut

sub test_tracking_enabled_scripts_all {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Enable}{Scripts} =
      ' * ';
    my $script = 'Manage';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Enable', 'Scripts', $script );
    $this->assert_equals( 1, $enabled );
}

=pod

=cut

sub test_tracking_enabled_scripts_empty {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Enable}{Scripts} =
      '';
    my $script = 'manage';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Enable', 'Scripts', $script );
    $this->assert_equals( 0, $enabled );
}

=pod

=cut

sub test_tracking_enabled_scripts_named {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Enable}{Scripts} =
      ' manage, ';
    my $script = 'manage';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Enable', 'Scripts', $script );
    $this->assert_equals( 1, $enabled );
}

=pod

=cut

sub test_tracking_enabled_scripts_named_other {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Enable}{Scripts} =
      ' view,edit,create, ';
    my $script = 'manage';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Enable', 'Scripts', $script );
    $this->assert_equals( 0, $enabled );
}

=pod

=cut

sub test_tracking_disabled_scripts_all {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Disable}{Scripts} =
      ' * ';
    my $script = 'Manage';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Disable', 'Scripts', $script );
    $this->assert_equals( 0, $enabled );
}

=pod

=cut

sub test_tracking_disabled_scripts_empty {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Disable}{Scripts} =
      '';
    my $script = 'manage';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Disable', 'Scripts', $script );
    $this->assert_equals( 1, $enabled );
}

=pod

=cut

sub test_tracking_disabled_scripts_named {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Disable}{Scripts} =
      ' manage, ';
    my $script = 'manage';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Disable', 'Scripts', $script );
    $this->assert_equals( 0, $enabled );
}

=pod

=cut

sub test_tracking_disabled_scripts_named_other {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Disable}{Scripts} =
      ' view,edit,create, ';
    my $script = 'manage';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledInSetting(
        'Disable', 'Scripts', $script );
    $this->assert_equals( 1, $enabled );
}

=pod

=cut

sub test_isTrackingEnabledForUser {
    my ($this) = @_;

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Enable}{Users} =
      '*';
    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Disable}{Users} =
      '';
    my $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledForUser('');
    $this->assert_equals( 1, $enabled );

    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Enable}{Users} = '';
    $Foswiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Disable}{Users} =
      '';
    $enabled =
      Foswiki::Plugins::GoogleAnalyticsPlugin::_isTrackingEnabledForUser('');
    $this->assert_equals( 0, $enabled );
}

=pod

Copied from PrefsTests.
Used to set the SKIN preference to text, so that the smaller response page is easier to handle.

=cut

sub _setWebPref {
    my ( $this, $pref, $val, $type ) = @_;
    $this->_set( $this->{test_web}, $Foswiki::cfg{WebPrefsTopicName},
        $pref, $val, $type );
}

sub _set {
    my ( $this, $web, $topic, $pref, $val, $type ) = @_;
    $this->assert_not_null($web);
    $this->assert_not_null($topic);
    $this->assert_not_null($pref);
    $type ||= 'Set';

    try {
        my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
        $text =~ s/^\s*\* $type $pref =.*$//gm;
        $text .= "\n\t* $type $pref = $val\n";
        Foswiki::Func::saveTopic( $web, $topic, $meta, $text,
            { dontlog => 1, minor => 1 } );
    }
    catch Foswiki::AccessControlException with {
        $this->assert( 0, shift->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() || '' );
    };
}

=pod

=cut

sub _debug {
    my ($text) = @_;

    return if !$DEBUG;
    Foswiki::Func::writeDebug($text);
    print STDOUT $text . "\n";
}

=pod

_trimSpaces( $text ) -> $text

Removes spaces from both sides of the text.

=cut

sub _trimSpaces {

    #my $text = $_[0]

    $_[0] =~ s/^[[:space:]]+//s;    # trim at start
    $_[0] =~ s/[[:space:]]+$//s;    # trim at end
}

1;
