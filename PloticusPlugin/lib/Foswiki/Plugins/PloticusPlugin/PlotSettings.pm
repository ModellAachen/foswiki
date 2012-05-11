
package Foswiki::Plugins::PloticusPlugin::PlotSettings;

require Foswiki::Plugins::PloticusPlugin;

use strict;
use Assert;

my $debug = 0;

sub fromFile {
    my ( $class, $web, $topic, $plotName ) = @_;
    $debug = $Foswiki::Plugins::PloticusPlugin::debug;
    Foswiki::Func::writeDebug(
"PloticusPlugin::PlotSettings::fromFile - Creating new PlotSettings Object from file for $web / $topic / $plotName"
    );
    my $self = {};
    $self->{WEB}   = $web;
    $self->{TOPIC} = $topic;
    $self->{NAME}  = $plotName;
    $self->{TEXT}  = undef;

    #    $self->{SETTINGS} = [];

    my $ploticusFile = buildFileName( $web, $topic, $plotName );
    $self->{TEXT} = readFile($ploticusFile);

    bless( $self, $class );
    return $self;
}

sub buildFileName {
    my ( $web, $topic, $plotName ) = @_;
    return Foswiki::Func::getPubDir() . "/$web/$topic/$plotName.ploticus";
}

sub readFile {
    my $ploticusFile = $_[0];
    Foswiki::Func::writeDebug(
"PloticusPlugin::PlotSettings::readFile - Reading settings from $ploticusFile"
    ) if $debug;
    open( INFILE, $ploticusFile ) or return newFile();
    my $content = '';
    while (<INFILE>) {
        if ( /^\s*$/ or /^\<p\s*\// ) {
            $content .= " \n";
            next;
        }
        $content .= $_;
    }
    if ( $content =~
        /#shell|#endshell|\$shellrow|#sql|#load|#write|#endwrite|#cat/ )
    {
        $content = "#proc annotate\n";
        $content .= "location: 2 6\n";
        $content .= "ellipse: yes\n";
        $content .= "backcolor: red\n";
        $content .= "text:\n";
        $content .= "Security issue!\n";
        $content .= "At least one of the \n";
        $content .= "following directives was\n";
        $content .= "found in script syntax:\n";
        $content .= "-#shell\n";
        $content .= "-#endshell\n";
        $content .= "-\$shellrow\n";
        $content .= "-#sql\n";
        $content .= "-#load\n";
        $content .= "-#write\n";
        $content .= "-#endwrite\n";
        $content .= "-#cat\n";
    }
    return $content;
}

sub writeFile {
    my ( $web, $topic, $plotName, $text ) = @_;
    my $webDir = Foswiki::Func::getPubDir() . "/$web";
    unless ( -e $webDir )          { mkdir $webDir }
    unless ( -e "$webDir/$topic" ) { mkdir "$webDir/$topic" }
    my $ploticusFile = "$webDir/$topic/$plotName.ploticus";
    Foswiki::Func::writeDebug(
"PloticusPlugin::PlotSettings::writeFile - Writing ---=$text=--- to $ploticusFile"
    );    # if $debug;
    open( OUTFILE, ">", $ploticusFile )
      or die "Cannot create new Ploticusplot file!";
    Foswiki::Func::writeDebug(
"PloticusPlugin::PlotSettings::writeFile - Writing ---=$text=--- to $ploticusFile"
    );    # if $debug;
    $text =~ s/<p \/>//g;

    if ( $text =~
        /#shell|#endshell|\$shellrow|#sql|#load|#write|#endwrite|#cat/ )
    {
        $text = "#proc annotate\n";
        $text .= "location: 2 6\n";
        $text .= "ellipse: yes\n";
        $text .= "backcolor: red\n";
        $text .= "text:	\n";
        $text .= "Security issue!\n";
        $text .= "At least one of the \n";
        $text .= "following directives was\n";
        $text .= "found in script syntax:\n";
        $text .= "-#shell\n";
        $text .= "-#endshell\n";
        $text .= "-\$shellrow\n";
        $text .= "-#sql\n";
        $text .= "-#load\n";
        $text .= "-#write\n";
        $text .= "-#endwrite\n";
        $text .= "-#cat\n";
    }
    print OUTFILE "$text";
    close OUTFILE;
}

sub newFile {
    Foswiki::Func::writeDebug(
        "PloticusPlugin::PlotSettings::newFile - Creating new default settings")
      if $debug;
    my $text = '';
    $text .=
      "// simple vertical bars example - replace this with your own plot\n";
    $text .= "\n";
    $text .= "#proc areadef\n";
    $text .= "rectangle: 1 1 4 2\n";
    $text .= "xrange: 0 5\n";
    $text .= "yrange: 0 100\n";
    $text .= "\n";
    $text .= "#proc xaxis:\n";
    $text .= "stubs: text\n";
    $text .= "Africa\n";
    $text .= "America\n";
    $text .= "Asia\n";
    $text .= "Europe,\\nAustralia,\\nPacific\n";
    $text .= "\n";
    $text .= "#proc yaxis\n";
    $text .= "label: Growth Rate\n";
    $text .= "stubs: inc 20\n";
    $text .= "minortics: yes\n";
    $text .= "minorticinc: 5\n";
    $text .= "\n";
    $text .= "#proc getdata\n";
    $text .= "data: 76 \n";
    $text .= "54\n";
    $text .= "60\n";
    $text .= "59\n";
    $text .= "\n";
    $text .= "#proc bars\n";
    $text .= "lenfield: 1\n";
    $text .= "color: teal\n";
    $text .= "barwidth: 0.2\n";
    return $text;
}

sub render {
    my $self = shift;

    #    $self->{WEB}
    #    $self->{TOPIC}
    #    $self->{NAME}
    #    $self->{TEXT}
    my $text = '';
    $text .= "*Edit Settings for !$self->{NAME}*\n";
    $text .= "<a name=\"ploticusplot" . $self->{NAME} . "\"></a>\n";
    $text .=
        "<form action="
      . Foswiki::Func::getScriptUrl( "$self->{WEB}", "$self->{TOPIC}", "view" )
      . "\#ploticusplot$self->{NAME}\" method=\"post\">\n";
    $text .= "<table>\n";
    $text .= "  <tr valign=\"middle\">\n";
    $text .=
"    <td><textarea  rows=\"10\" cols=\"90\" name=\"ploticusPlotSettingsText\" >$self->{TEXT}</textarea>\n";
    $text .= "    </td>\n";
    $text .=
"    <td><input  type=\"submit\" value=\"Save Settings\" class=\"foswikiSubmit\" /><br>\n";
    $text .=
"        <a target=\"PloticusPlugin\" onclick=\"return launchWindow('System','PloticusPlugin')\" href=\"/foswiki/bin/view/System/PloticusPlugin\">PloticusPlugin help</a><br>\n";
    $text .=
"        <a target=\"PloticusHelp\" onclick=\"return launchWindow('System','PloticusHelp')\" href=\"/foswiki/bin/view/System/PloticusHelp\">Ploticus help</a>\n";
    $text .= "    </td>\n";
    $text .= "  </tr>\n";
    $text .= "</table>\n";
    $text .=
"<input type=\"hidden\" name=\"ploticusPlotName\" value=\"$self->{NAME}\" />";
    $text .=
      "<input type=\"hidden\" name=\"ploticusPlotAction\" value=\"save\" />";
    $text .= "</form>\n";
    return $text;
}

1;
