#
# TextSectionPlugin for TWiki
# Copyright (C) 2004 Norbert Windrich
#
# TWiki WikiClone ($wikiversion has version info)
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
#
# TextSectionPlugin
# =========================
#
# Used to handle hide or display nested text sections
# Multiple tokens should not be in one line
# The recognised syntax is
#
# heading mode: render all ---+ headings
# %textsections%
#
# section mode: render special tags
# text
# %textsection% or %textsection{TITLE="..." HIDENUM="yes|no" USE_FORM=yes|no"}%
# text
# %textsectionend%
# text
#
# Change history:
# r1.0 - initial revision
# r1.1 move functionality similar to EditSectionPlugin
#      - change token %TEXTSECTIONS% to <textsection>
#      - <tagsections> functionality for heading mode added
# r1.2 - change token <textsections> to %textsection% to get a more twiki way
#
# Norbert Windrich

# =========================
package TWiki::Plugins::TextSectionPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb
  $query $sectionInitVal $useForm
  $VERSION $RELEASE $pluginName $debug
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName     = 'TextSectionPlugin';
$sectionInitVal = "0.";

my $skipSkin = "";    # Get skip skin values
my $useForm  = "";    # Get form flag
my $debug    = "";    # Get plugin debug flag

TWiki::Func::writeDebug(
"- TWiki::Plugins::${pluginName}::initPlugin:skipSkin=$skipSkin;useForm=$useForm;debug=$debug"
) if $debug;

# =========================
sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get skip skin values
    $skipSkin = TWiki::Func::getPreferencesValue("\U$pluginName\E_SKIPSKIN")
      || "";

    # Get form flag
    $useForm = TWiki::Func::getPreferencesFlag("\U$pluginName\E_USE_FORM");

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    TWiki::Func::writeDebug(
"- TWiki::Plugins::${pluginName}::initPlugin:skipSkin=$skipSkin;useForm=$useForm;debug=$debug"
    ) if $debug;
    $query = TWiki::Func::getCgiQuery();
    if ( !$query ) { return 0; }

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    # Skip generated documents
    if ( $_[0] =~ m/^[<][!]DOCTYPE/ ) { return; }    # nothing to do

    # check if there's an TEXTSECTION statement in this topic
    if ( $_[0] !~ m/%textsection.*%/i ) { return; }    # nothing to do

    my $usedSkin = &TWiki::Func::getSkin();
    foreach my $skin ( split( /[ ,]/, $skipSkin ) ) {
        if ( $usedSkin eq $skin ) {

            # remove all textsection entries (maybe for printing issues
            $_[0] =~ s/%textsection.*%//gi;
            return;
        }
    }
    my $viewList = $query->url_param('textsectionview') || $sectionInitVal;
    TWiki::Func::writeDebug(
        "- ${pluginName}::commonTagsHandler => $_[2],$_[1]:viewList=$viewList")
      if $debug;

# check if there's an %textsections% statement in this topic -> rendering all ---+ lines
    if ( $_[0] !~ m/%textsections%/i ) {
        $_[0] =
          dispText( $_[0], TWiki::Func::getScriptUrl( $_[2], $_[1], "view" ),
            $viewList );
    }
    else {
        $_[0] =
          dispHeadingText( $_[0],
            TWiki::Func::getScriptUrl( $_[2], $_[1], "view" ), $viewList );
    }
}

# =========================
sub dispText {
    my ( $text, $viewUrl, $viewList ) = @_;

    # structure handling
    my $section    = $sectionInitVal;
    my $newSection = $sectionInitVal;
    my $lastMax    = 0;

    # text handling
    my $theLine = "";
    my $newText = "";

    foreach $theLine ( split( /\n/, $text ) ) {
        if (   ( $theLine =~ m/%textsection%/i )
            || ( $theLine =~ m/%textsection{.*}%/i ) )
        {
            $newSection = $section . ( $lastMax + 1 ) . ".";   # add new section
            $lastMax = 0;    # set 0 for next level;
        }
        elsif ( $theLine =~ m/%textsectionend%/i ) {
            if ( $section ne $sectionInitVal )
            { # if structure correct, reduce, otherwise skip to avoid too many %textsectionend%
                $section =~
                  s/(^.*\.)(.*)\.$/$1/s;    # store left value of section string
                $lastMax =
                  $2;    # store right value of section string (number only)
            }
            $newSection = $section;    # new section is the old stored section

            $theLine =~ s/%textsectionend%//i;    # remove token
        }
        $newText .=
          getNewText( $section, $newSection, $viewList, $theLine, $viewUrl, 0 );
        $section = $newSection;
    }
    return ($newText);
}

# =========================
sub dispHeadingText {
    my ( $text, $viewUrl, $viewList ) = @_;

    # structure handling
    my $section    = $sectionInitVal;
    my $newSection = $sectionInitVal;
    my $lastMax    = 0;
    my $dotCnt     = 0;                 # no of '.' in $section
    my $plusCnt    = 0;                 # no of '+' in current line heading

    # text handling
    my $theLine = "";
    my $newText = "";
    my $tmpStr  = "";

    $text =~ s/%textsection.*%//gi;     # remove all tokens

    foreach $theLine ( split( /\n/, $text ) ) {
        if ( $theLine =~ m/^---\+/ ) {

            # get the number of '+'
            $tmpStr = $theLine;
            $tmpStr =~ s/^---(\+*).*/$1/;
            $plusCnt = length($tmpStr);

            # get the number of '.'
            $tmpStr = $section;
            $tmpStr =~ s/\.//g;
            $dotCnt = length($section) - length($tmpStr) - 1;

            if ( $plusCnt > $dotCnt ) {
                $lastMax = 1;
            }         # if no of '+' > '.' ==> add new section
            else {    # if no of '+' < '.' ==> remove last n stored section id´s
                while ( $plusCnt <= $dotCnt ) {
                    $section =~ s/(^.*\.)(.*)\.$/$1/s
                      ;    # store left value of section string
                    $lastMax =
                      $2;    # store right value of section string (number only)
                    $dotCnt--;
                }
                $lastMax++;    # add new section
            }
            $newSection = $section . $lastMax . ".";    # add new section
        }
        $newText .=
          getNewText( $section, $newSection, $viewList, $theLine, $viewUrl, 1 );
        $section = $newSection;
    }
    return ($newText);
}

# =========================
sub getNewList {
    my ( $section, $list ) = @_;
    my $newList = "";

    if ( $section eq "" ) { return ($list); }    # no change

    if ( $list =~ m/$section/ )
    {    # section is already in list => remove it and all sub sections
        $newList = $list . ",";    # add ',' for following substitution
        $newList =~ s/$section[^,]*,//g
          ;    # delete section till ',' so last char must be a ','
        $newList =~ s/,$//g;    # remove last ',' if any
    }
    else { $newList = $list . "," . $section; }    # add new section

    TWiki::Func::writeDebug(
"- ${pluginName}::getNewList => section=$section;list:$list;New list=$newList"
    ) if $debug;
    return ($newList);
}

# =========================
# Parameter: mode:   0: section mode    1: heading mode '---+'
sub getNewText {
    my ( $section, $newSection, $list, $text, $viewUrl, $mode ) = @_;

    my $preText      = "";
    my $sign         = "";
    my $useFormLocal = $useForm;

    if ( $list !~ m/$section/ ) { return (""); }    # Nothing to view
    if ( $section eq $newSection ) {
        return ( $text . "\n" );
    }                                               # if same section, view line
    if ( $list =~ m/$newSection/ ) {
        $sign = "-";
    }    # Is newSection already in view => add "-"
    else { $sign = "+"; }    # Is newSection not in view     => add "+"

    my $actionText =
      $viewUrl . "?" . "textsectionview=" . getNewList( $newSection, $list );

    if ($mode) {
        $preText = " <a href=\"$actionText\">" . $sign . "</a>";
        $text .= $preText;
        return ( $text . "\n" );
    }

    # use of tokens
    my $btnText = $sign;
    my $theArgs = $text;
    $theArgs =~ s/.*%textsection{(.*)}%.*/$1/i;
    if ($theArgs) {
        my $title = TWiki::Func::extractNameValuePair( $theArgs, "title" )
          || "";
        $useFormLocal =
          TWiki::Func::extractNameValuePair( $theArgs, "use_form" ) || $useForm;
        if ( !TWiki::Func::extractNameValuePair( $theArgs, "hidenum" ) ) {
            $btnText .= " " . $newSection;
            $btnText =~
              s/$sectionInitVal//;    # remove leading InitVal of section id
        }
        $btnText .= " " . $title;
    }

    if ($useFormLocal) {
        $preText = "<br>\n";
        $preText .=
"<form name=\"textsection$newSection\" action=\"$actionText\" method=\"post\">\n";
        $preText .=
"<input type=\"submit\" name=\"textsection$newSection\"  value=\"$btnText\" />\n";
        $preText .= "</form>\n";
    }
    else { $preText = "<br>\n<a href=\"$actionText\">" . $btnText . "</a>"; }

    $text =~ s/%textsection.*%/$preText/i;
    return ( $text . "\n" );
}

# =========================

1
