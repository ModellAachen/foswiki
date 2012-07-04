package Foswiki::Plugins::BibtexPlugin::CgiBibSearch;

use strict;

use Assert;
use Error qw( :try );

require Foswiki;
require Foswiki::UI;
require Foswiki::Time;

my $debug = 0;

sub writeDebug {
    &Foswiki::Func::writeDebug( "cgisearch - " . $_[0] ) if $debug;
}

sub writeDebugTimes {
    &Foswiki::Func::writeDebugTimes( "cgisearch - " . $_[0] ) if $debug;
}

###############################################################################
sub cgibibsearch {

    # the cgi-interface:

    $Foswiki::Plugins::SESSION = shift;

    my $query = $Foswiki::Plugins::SESSION->{cgiQuery};

    my $thePathInfo   = $query->path_info();
    my $theRemoteUser = $query->remote_user();
    my $theUrl        = $query->url;

    &writeDebug("starting cgibibsearch");

    ##
    # initialize the topic location
    ##
    my $topic = $Foswiki::Plugins::SESSION->{topicName};
    my $web   = $Foswiki::Plugins::SESSION->{webName};

    ##
    # get params
    ##
    my $theTopic     = $query->param('bibtopic');
    my $theMatch     = $query->param("match") || "all";
    my $theReverse   = $query->param("rev");
    my $theSort      = join( " ", $query->param("sort") );
    my $theFormat    = $query->param("format");
    my $theErrors    = $query->param("errors");
    my $theBibfile   = $query->param("file");
    my $theStyle     = $query->param("bibstyle");
    my $theForm      = $query->param("form");
    my $theAbstracts = $query->param("abstracts");
    my $theKeywords  = $query->param("keywords");
    my $theTotal     = $query->param("total");
    my $theDisplay   = $query->param("display");
    my $theSelect    = $query->param("select") || "";

    ##
    # map cgi parameters
    ##
    my $mixed = "off";
    my $style = $theStyle;
    if ($theFormat) {
        $mixed = "on"  if $theFormat eq "mix";
        $style = "raw" if $theFormat eq "raw";

        #    $style = "bibtool" if $theFormat eq "bibtool";
    }

    my @textFields =
      ( "author", "year", "title", "key", "type", "phrase", "inside",
        "select" );
    my @radioFields = ( "match", "format", "sort", "rev", "abstracts" );

    if ( !$theSelect ) {

        # build the selection string for handleBibtex()
        my $isFirst = 1;
        foreach my $attrName (@textFields) {
            my $valueString = $query->param($attrName);
            next if !$valueString;

            if ($isFirst) {
                $isFirst = 0;
            }
            else {
                $theSelect .= " and " if $theMatch eq 'all';
                $theSelect .= " or "  if $theMatch eq 'any';
            }

            my $isFirstSpec = 1;
            foreach my $attrSpec ( split( /\s/, $valueString ) ) {
                if ( $attrSpec =~ /([<>=:!]*)(.*)/ ) {
                    my $compare = $1;
                    my $value   = $2;
                    if ( !$compare ) {
                        if ( $attrName eq "year" ) {
                            $compare = "=";
                        }
                        else {
                            $compare = ":";
                        }
                    }
                    if ($isFirstSpec) {
                        $isFirstSpec = 0;
                    }
                    else {
                        $theSelect .= " and " if $theMatch eq 'all';
                        $theSelect .= " or "  if $theMatch eq 'any';
                    }

                    my $name;
                    if ( $attrName =~ /(key|type)/ ) {
                        $name = '$' . $attrName;
                    }
                    else {
                        $name = $attrName;
                    }
                    if ( $attrName eq "phrase" ) {
                        $theSelect .=
                            "((keywords $compare \'$value\') or "
                          . "(title $compare \'$value\') or "
                          . "(abstract $compare \'$value\') or "
                          . "(note $compare \'$value\') or "
                          . "(annote $compare \'$value\') or "
                          . "(\$key $compare \'$value\'))";
                    }
                    elsif ( $attrName eq "inside" ) {
                        $theSelect .=
                            "((journal $compare \'$value\') or "
                          . "(series $compare \'$value\') or "
                          . "(booktitle $compare \'$value\') or "
                          . "(school $compare \'$value\') or "
                          . "(institute $compare \'$value\'))";
                    }
                    else {
                        $theSelect .= "$name $compare \'$value\' ";
                    }
                }
            }
        }
    }

    ##
    # get the view template
    ##
    my $skin = $query->param("skin")
      || &Foswiki::Func::getPreferencesValue("SKIN");
    my ( $meta, $text ) = &Foswiki::Func::readTopic( $web, $topic );
    my $tmpl = &Foswiki::Func::readTemplate( "view", $skin );

    $tmpl = Foswiki::Func::expandCommonVariables( $tmpl, $topic, $web );
    $tmpl = Foswiki::Func::renderText($tmpl);

    $tmpl =~ s/%SEARCHSTRING%//go;
    $tmpl =~ s/%REVINFO%//go;
    $tmpl =~ s/%REVTITLE%/bibsearch /go;
    $tmpl =~ s/%REVARG%//go;

    ##
    # call the plugin
    ##
    my $result = &Foswiki::Plugins::BibtexPlugin::bibSearch(
        $theTopic, $theBibfile,   $theSelect,   $style,
        $theSort,  $theReverse,   $mixed,       $theErrors,
        $theForm,  $theAbstracts, $theKeywords, $theTotal,
        $theDisplay
    );

    ##
    # put the topic text into the view template
    ##
    $text =~ s/%BIBTEXRESULT%/$result/g;
    $text =~ s/%BIBTEX%/$result/g;
    $text =~ s/%BIBTEX{[^}]*}%/$result/g;
    $text =~ s/%STARTBIBTEX.*?%.*?%STOPBIBTEX%/$result/gs;

    $text = Foswiki::Func::expandCommonVariables( $text, $topic, $web );
    $text = Foswiki::Func::renderText($text);

    $tmpl =~ s/%TEXT%/$text/go;

    ##
    # replace query strings
    ##
    if ($theForm) {
        foreach my $fieldName (@textFields) {
            my $valueString = $query->param($fieldName);
            next if !$valueString;
            $tmpl =~
              s/(<input.*name="$fieldName".*value=")[^"]*/$1$valueString/;
        }
        foreach my $fieldName (@radioFields) {
            my $valueString = $query->param($fieldName);
            next if !$valueString;
            $tmpl =~ s/(<input.*name="$fieldName".*)\s*checked="checked"\s/$1/g;
            $tmpl =~
s/(<input.*name="$fieldName".*value="$valueString")/$1 checked="checked" /;
        }
    }

    # remove edit and revisions tags:
    $tmpl =~ s/%EDITTOPIC%//g;
    $tmpl =~ s/%REVISIONS%/ -- /g;

    ##
    # finaly, print out
    ##
    &Foswiki::Func::writeHeader();
    $Foswiki::Plugins::SESSION->{response}->print($tmpl);

    &writeDebug("cgibibsearch done");

    return (0);
}

1;
