#
#      Foswiki UpdateInfo Plugin
#
#      Written by Chris Huebsch chu@informatik.tu-chemnitz.de
#
# 31-Mar-2005:   SteffenPoulsen
#                  - Updated plugin to be I18N-aware
#  2-Apr-2005:   SteffenPoulsen
#                  - Support for more TML link syntaxes, cleaned up code, touched documentation
#  4-Apr-2005:   SteffenPoulsen
#                  - Support for _even more_ TML link syntaxes (i.e. "-" now allowed in WikiWord)
#  6-Apr-2005:   SteffenPoulsen (patch by DieterWeber)
#                  - Fetch default "days" and "version" variables from variables.
#                  - Search web/user/topic preferences first, and then in the plugin if we can't find it
# 10-Jan-2006:   SteffenPoulsen
#                  - Dakar compatibility
# 20-Apr-2006:   SteffenPoulsen
#                  - Cairo+Dakar compatibility
# 26-Jul-2006:   SteffenPoulsen
#                  - Updated to use default new and updated icons (from %SYSTEMWEB%.DocumentGraphics)

package Foswiki::Plugins::UpdateInfoPlugin;

use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
  $plural2SingularEnabled
  $wnre
  $wwre
  $manre
  $abbre
  $smanre
  $days
  $version
);

# This should always be $Rev$ so that the core can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'v3.0';

BEGIN {

    # 'Use locale' for internationalisation of Perl sorting and searching
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between UpdateInfoPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin preferences
    $debug = &Foswiki::Func::getPreferencesFlag("UPDATEINFOPLUGIN_DEBUG");

    $days =
         &Foswiki::Func::getPreferencesValue("UPDATEINFODAYS")
      || &Foswiki::Func::getPreferencesValue("UPDATEINFOPLUGIN_DAYS")
      || "5";

    $version =
         &Foswiki::Func::getPreferencesValue("UPDATEINFOVERSION")
      || &Foswiki::Func::getPreferencesValue("UPDATEINFOPLUGIN_VERSION")
      || "1.1";

    $wnre  = $Foswiki::regex{'webNameRegex'};
    $wwre  = $Foswiki::regex{'wikiWordRegex'};
    $manre = $Foswiki::regex{'mixedAlphaNum'};
    $abbre = $Foswiki::regex{'abbrevRegex'};

    #$smanre = $Foswiki::regex{'singleMixedAlphaNumRegex'};

    Foswiki::Func::writeDebug(
        "- Foswiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    Foswiki::Func::writeDebug(
        '- $Foswiki::cfg{UseLocale}: ' . "$Foswiki::cfg{UseLocale}" )
      if $debug;

    # Plugin correctly initialized
    return 1;
}

sub update_info {
    my ( $defweb, $wikiword, $opts ) = @_;
    $opts ||= '';    # pre-define $opts to prevent error messages

    # save old link (preserve [[-style links)
    my $oldwikiword = $wikiword;

    # clear [[-style formatting for [[WikiWordAsWebName.WikiWord][link text]]
    # and [[WikiWord][link text]]
    $wikiword =~ s/\[\[($wnre\.$wwre|$wwre)\]\[.*?\]\]/$1/o;

    ( $web, $topic ) = split( /\./, $wikiword );
    if ( !$topic ) {
        $topic = $web;
        $web   = $defweb;
    }

    # Turn spaced-out names into WikiWords - upper case first letter of
    # whole link, and first of each word.
    $topic =~ s/^(.)/\U$1/o;

    #$topic =~ s/\s($smanre)/\U$1/go;
    #$topic =~ s/\[\[($smanre)(.*?)\]\]/\u$1$2/o;

    my $match = 0;

    if ( $Foswiki::Plugins::VERSION < 1.1 ) {

        # Cairo

        ( $meta, $dummy ) = Foswiki::Store::readTopMeta( $web, $topic );
        if ($meta) {
            $match = 1;

            $opts =~ s/{(.*?)}/$1/geo;

            $params{"days"}    = "$days";
            $params{"version"} = "$version";

            foreach $param ( split( / /, $opts ) ) {
                ( $key, $val ) = split( /=/, $param );
                $val =~ tr [\"] [ ];
                $params{$key} = $val;
            }

            %info = $meta->findOne("TOPICINFO");
        }
    }
    else {

        # Dakar
        ( $meta, $dummy ) = Foswiki::Func::readTopic( $web, $topic );
        if ($meta) {
            $match = 1;

            $opts =~ s/{(.*?)}/$1/geo;

            $params{"days"}    = "$days";
            $params{"version"} = "$version";

            foreach $param ( split( / /, $opts ) ) {
                ( $key, $val ) = split( /=/, $param );
                $val =~ tr ["] [ ];
                $params{$key} = $val;
            }

            if ( defined(&Foswiki::Meta::findOne) ) {
                %info = $meta->findOne("TOPICINFO");
            }
            else {
                my $r = $meta->get("TOPICINFO");
                return '' unless $r;
                %info = %$r;
            }
        }
    }

    if ($match) {
        $updated =
          ( ( time - $info{"date"} ) / 86400 ) < $params{"days"};    #24*60*60
        $new = $updated
          && ( ( $info{"version"} + 0 ) <= ( $params{"version"} + 0 ) );

        $r = "";
        if ($updated) {
            $r = " %U%";
        }
        if ($new) {
            $r = " %N%";
        }

        # revert to old style wikiword formatting
        $wikiword = $oldwikiword;

        return $r;

    }
    else {
        return "";
    }
}

# =========================
sub commonTagsHandler {
    my ( $text, $topic, $web ) = @_;

# Match WikiWordAsWebName.WikiWord, WikiWords, [[WikiWord][link text]], [[WebName.WikiWord][link text]], [[link text]], [[linktext]] or WIK IWO RDS (all followed by %ISNEW..% syntax)
    $_[0] =~
s/($wnre\.$wwre|$wwre|\[\[$wwre\]\[.*?\]\]|\[\[$wnre}\.$wwre\]\[.*?\]\]|\[\[.*?\]\]|$abbre) %ISNEW({.*?})?%/"$1".update_info($web, $1, $2)/geo;

}

1;
