package MediaPluginTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use Foswiki::Func;
use Foswiki::UI::Save;
use Error qw( :try );
use Foswiki::Plugins::MediaPlugin;

my $DEBUG = 0;

sub loadExtraConfig {
    my $this = shift;
    $this->SUPER::loadExtraConfig();
    setLocalSite();
}

sub setLocalSite {
    $Foswiki::cfg{Plugins}{MediaPlugin}{Enabled} = 1;
    $Foswiki::cfg{Plugins}{MediaPlugin}{Debug}   = $DEBUG;
}

=pod

This formats the text up to immediately before <nop>s are removed, so we
can see the nops.

=cut

sub do_testHtmlOutput {
    my ( $this, $expected, $actual, $doRender ) = @_;
    my $session   = $this->{twiki};
    my $webName   = $this->{test_web};
    my $topicName = $this->{test_topic};

    if ($doRender) {
        $actual =
          Foswiki::Func::expandCommonVariables( $actual, $webName, $topicName );
        $actual =
          $session->renderer->getRenderedVersion( $actual, $webName,
            $topicName );
    }

    $this->assert_html_equals( $expected, $actual );
}

=pod

Test basic wmv.

=cut

sub test_wmv {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $pubUrl = Foswiki::Func::getUrlHost() . Foswiki::Func::getPubUrlPath();

    my $input =
'%MEDIA{"http://support.microsoft.com/support/mediaplayer/wmptest/samples/new/mediaexample.wmv" height="240" width="320"}%';
    my $expected = <<EXPECTED;
<noautolink><object classid="clsid:6BF52A52-394A-11d3-B153-00C04F79FAA6" codebase="http://activex.microsoft.com/activex/controls/mplayer/en/nsmp2inf.cab" height="286" width="320"><param name="ShowControls" value="true" /><param name="autostart" value="true" /><param name="type" value="application/x-mplayer2" /><embed ShowControls="true" autostart="true" height="286" pluginspage="http://www.microsoft.com/windows/windowsmedia/download/AllDownloads.aspx/" src="http://support.microsoft.com/support/mediaplayer/wmptest/samples/new/mediaexample.wmv" type="application/x-mplayer2" width="320"/></object></noautolink>
EXPECTED
    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName );
    $this->do_testHtmlOutput( $expected, $result, 0 );
}

=pod

Test basic mov.

=cut

sub test_mov_basic {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $pubUrl = Foswiki::Func::getUrlHost() . Foswiki::Func::getPubUrlPath();

    my $input = '%MEDIA{
"%ATTACHURL%/sample.mov"
height="180"
width="320"
}%';
    my $expected = <<EXPECTED;
<noautolink><object classid="clsid:02BF25D5-8C17-4B23-BC80-D3488ABDDC6B" codebase="http://www.apple.com/qtactivex/qtplugin.cab" height="196" width="320"><param name="autoplay" value="true" /><param name="controller" value="true" /><param name="src" value="$pubUrl/$webName/$topicName/sample.mov" /><embed autoplay="true" controller="true" height="196" pluginspage="/quicktime/download/" src="$pubUrl/$webName/$topicName/sample.mov" width="320"/></object></noautolink>
EXPECTED
    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName );
    $this->do_testHtmlOutput( $expected, $result, 0 );
}

=pod

Test mov with parameters.

=cut

sub test_mov_params {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $pubUrl = Foswiki::Func::getUrlHost() . Foswiki::Func::getPubUrlPath();

    my $input = '%MEDIA{
"%ATTACHURL%/sample.mov"
height="180"
width="320"
bgcolor="#000000"
cache="true"
loop="true"
kioskmode="true"
volume="50"
starttime="00:15:22.5"
}%';
    my $expected = <<EXPECTED;
<noautolink><object classid="clsid:02BF25D5-8C17-4B23-BC80-D3488ABDDC6B" codebase="http://www.apple.com/qtactivex/qtplugin.cab" height="196" width="320"><param name="autoplay" value="true" /><param name="bgcolor" value="#000000" /><param name="cache" value="true" /><param name="controller" value="true" /><param name="kioskmode" value="true" /><param name="loop" value="true" /><param name="src" value="$pubUrl/$webName/$topicName/sample.mov" /><param name="starttime" value="00:15:22.5" /><param name="volume" value="50" /><embed autoplay="true" bgcolor="#000000" cache="true" controller="true" height="196" kioskmode="true" loop="true" pluginspage="/quicktime/download/" src="$pubUrl/$webName/$topicName/sample.mov" starttime="00:15:22.5" volume="50" width="320"/></object></noautolink>
EXPECTED
    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName );
    $this->do_testHtmlOutput( $expected, $result, 0 );
}

=pod

Test basic swf.

=cut

sub test_swf_basic {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $pubUrl = Foswiki::Func::getUrlHost() . Foswiki::Func::getPubUrlPath();

    my $input    = '%MEDIA{"%ATTACHURL%/sample.swf"}%';
    my $expected = <<EXPECTED;
<noautolink><object classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000" codebase="http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=9,0,0,0" height="180" width="320"><param name="movie" value="$pubUrl/$webName/$topicName/sample.swf" /><embed height="180" src="$pubUrl/$webName/$topicName/sample.swf" width="320"/></object></noautolink>
EXPECTED
    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName );
    $this->do_testHtmlOutput( $expected, $result, 0 );
}

=pod

Test with all possible parameters.

=cut

sub test_swf_params {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $pubUrl = Foswiki::Func::getUrlHost() . Foswiki::Func::getPubUrlPath();

    my $input = '%MEDIA{
src="%ATTACHURL%/swf/ThumbController.swf"
width="100%"
height="100%"
bgcolor="#ffffff"
align="left"
salign="tl"
scale="showall"
quality="autohigh"
menu="false"
id="my_movie"
wmode="opaque"
play="false"
loop="false"
allowscriptaccess="never"
fullscreen="true"
base="%ATTACHURL%/swf/"
swliveconnect="true"
flashvars="flashvars="x=50&y=100&url=%ATTACHURL%/picture.jpg"
}%';
    my $expected = <<EXPECTED;
<noautolink><object align="left" classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000" codebase="http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=9,0,0,0" height="100%" id="my_movie" width="100%"><param name="allowscriptaccess" value="never" /><param name="base" value="$pubUrl/$webName/$topicName/swf/" /><param name="bgcolor" value="#ffffff" /><param name="flashvars" value="flashvars=" /><param name="fullscreen" value="true" /><param name="loop" value="false" /><param name="menu" value="false" /><param name="movie" value="$pubUrl/$webName/$topicName/swf/ThumbController.swf" /><param name="play" value="false" /><param name="quality" value="autohigh" /><param name="salign" value="tl" /><param name="scale" value="showall" /><param name="swliveconnect" value="true" /><param name="wmode" value="opaque" /><embed allowscriptaccess="never" base="$pubUrl/$webName/$topicName/swf/" bgcolor="#ffffff" flashvars="flashvars=" fullscreen="true" height="100%" loop="false" menu="false" play="false" quality="autohigh" salign="tl" scale="showall" src="$pubUrl/$webName/$topicName/swf/ThumbController.swf" swliveconnect="true" width="100%" wmode="opaque"/></object></noautolink>
EXPECTED
    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName );
    $this->do_testHtmlOutput( $expected, $result, 0 );
}

=pod

Tests pdf: should automatically generate the correct type.

=cut

sub test_pdf {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $pubUrl = Foswiki::Func::getUrlHost() . Foswiki::Func::getPubUrlPath();

    my $input = '%MEDIA{
"http://www.pdf-tools.com/public/downloads/whitepapers/whitepaper-pdfprimer.pdf"
type="application/force-download"
}%';
    my $expected = <<EXPECTED;
<noautolink><object><param name="data" value="http://www.pdf-tools.com/public/downloads/whitepapers/whitepaper-pdfprimer.pdf" /><param name="height" value="180" /><param name="type" value="application/force-download" /><param name="width" value="320" /></object></noautolink>
EXPECTED
    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName );
    $this->do_testHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_midi {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $pubUrl = Foswiki::Func::getUrlHost() . Foswiki::Func::getPubUrlPath();

    my $input = '%MEDIA{
"%ATTACHURL%/brahms-intermezzo-op118-no2.mid"
play="false"
}%';
    my $expected = <<EXPECTED;
<noautolink><object classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000" codebase="http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=9,0,0,0" height="180" width="320"><param name="autoplay" value="false" /><param name="autostart" value="false" /><param name="data" value="$pubUrl/$webName/$topicName/brahms-intermezzo-op118-no2.mid" /><param name="play" value="false" /><embed autoplay="false" autostart="false" data="$pubUrl/$webName/$topicName/brahms-intermezzo-op118-no2.mid" height="180" play="false" src="$pubUrl/$webName/$topicName/brahms-intermezzo-op118-no2.mid" width="320"/></object></noautolink>
EXPECTED
    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName );
    $this->do_testHtmlOutput( $expected, $result, 0 );
}

1;
