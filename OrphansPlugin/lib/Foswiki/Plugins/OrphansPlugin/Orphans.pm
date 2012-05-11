# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004 Wind River
#
# Plugin written for Wind River Systems by CrawfordCurrie
# http://c-dot.co.uk - http://wikiring.com
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
# Class that handles the location and display of orphaned pages
#
use strict;
use Foswiki::Func;

=pod

---+ class Orphans
Algorithm class; implements the search for orphaned pages. Actually, it
implements collection of all references to all pages within a web.

To detect cycles, we need to have a list of root topics to start a mark-sweep
process from.

---++ =new ( $web, $params )=
   * =$web= name of the current web
   * =$params= Unparsed parameters to the %ORPHANS tag. The parameters processed are:
      * =web=, may be set to the name of a web to process
      * =allrefs=, a boolean which should be set true if all references are to be recorded. If false, only retains topics with *no* references.
Constructor. Processes the given web and generates an object that contains the
results of the orphan search in that web.

---++ =tabulate ( $fmt ) -> Foswiki ML table=
   * =$fmt= Unparsed parameters to the %ORPHANS tag
Generates a table of results according to directions in the parameters.

=cut

package Foswiki::Plugins::OrphansPlugin::Orphans;

# PUBLIC constructor
sub new {
    my ( $class, $theWeb, $params ) = @_;
    my $this = bless( {}, $class );

    $this->{_allwebs} =
      ( $params->{allwebs} && $params->{allwebs} =~ m/^(on|true|yes|1)$/io );
    $this->{_web} = $params->{web} || $theWeb;

    my $topic;

    foreach $topic ( Foswiki::Func::getTopicList( $this->{_web} ) ) {
        $this->{$topic} = 0;
    }

    my $wikiName = Foswiki::Func::getWikiName();

    # Root of a URL that points to topics in this web. Used to detect
    # absolute URL references to topics
    $this->{_hereUrl} =
      Foswiki::Func::getScriptUrl( $this->{_web}, "DUMMY", "view" );
    $this->{_hereUrl} =~ s/\/DUMMY$//o;

    my $allrefs = $params->{allrefs};
    $this->{_keepAllRefs} =
      ( defined($allrefs) && $allrefs =~ m/^(on|true|yes|1)$/i );

    # Note; we read topics even if this user is denied read access. This
    # is secure, because we don't admit to where the reference to a topic came
    # from.
    my @webs =
      $this->{_allwebs} ? Foswiki::Func::getPublicWebList() : ( $this->{_web} );
    foreach my $fromweb (@webs) {
        foreach $topic (
            grep( !/^WebStatistics$/, Foswiki::Func::getTopicList($fromweb) ) )
        {

            # This code (or similar) is a subset of code that is
            # duplicated widely. For example, Store.pm updateReferingPages

            my $text =
              Foswiki::Func::readTopicText( $fromweb, $topic, undef, 1 );

            # kill anchors
            $text =~ s/^\#$Foswiki::regex{wikiWordRegex}//go;

            # kill verbatim & noautolink
            $text =~ s/<(verbatim|noautolink)>.*?<\/\1>//sgo;

            # kill topic parent & info
            $text =~ s/^%META:TOPIC.*$//go;

            # Handle absolute URLs
            $text =~
s/(^|[\-\*\s\(])[a-z]+:\/\/\S*\/$this->{_web}\/($Foswiki::regex{wikiWordRegex})\//$this->_wikiword($2,$fromweb,$topic)/geo;

            # Handle [[]]
            $text =~
s/\[\[([^\]]+)\](\[[^\]]+\])?\]/$this->_spaced($1,$fromweb,$topic)/geo;

           # Note that we add " to the following RE's to ensure we pick up topic
           # references embedded in parameters to tags
            $text =~
s/[\s\(\"]$this->{_web}\.($Foswiki::regex{wikiWordRegex})/$this->_wikiword($1,$this->{_web},$topic)/ge;

            # Kill <noautolink>
            $text =~ s/\n<noautolink>.*?\n<\/noautolink>//sgo;

            # Handle plain wikiwords
            $text =~
s/[\s\(\"]($Foswiki::regex{wikiWordRegex})/$this->_wikiword($1,$fromweb,$topic)/geo;

            # Handle acronyms/abbreviations of three or more letters
            # 'Web.ABBREV' link:
            $text =~
s/[\s\(\"]$this->{_web}\.($Foswiki::regex{abbrevRegex})/$this->_wikiword($1,$fromweb,$topic)/ge;
            $text =~
s/[\s\(\"]($Foswiki::regex{abbrevRegex})/$this->_wikiword($1,$fromweb,$topic)/geo;
        }
    }
    return $this;
}

sub _uc {
    return uc(shift);
}

# PRIVATE handle a spaced wiki word (phrase in [[ ]])
sub _spaced {
    my ( $this, $text, $web, $topic ) = @_;

    $text =~ s/\s(\w)/&_uc($1)/geo;
    return $this->_link( $text, $web, $topic );
}

# PRIVATE handle a link or wiki word
sub _link {
    my ( $this, $text, $web, $topic ) = @_;
    my $thisweb = $this->{_web};

    $text =~ s/^.*\b$thisweb[\/\.]($Foswiki::regex{wikiWordRegex})\b/$1/;
    if ( $text ne "" ) {
        $this->_wikiword( $text, $web, $topic ) if ( $text =~ m/^\w+$/o );
    }

    return "";
}

# PRIVATE handle a wiki word
sub _wikiword {
    my ( $this, $text, $web, $topic ) = @_;

    # If the text in this topic refers to this topic,
    # don't treat it as a reference
    return "" if ( $text eq $topic );

    if ( exists( $this->{$text} ) ) {
        if ( !$this->{_keepAllRefs} ) {
            delete( $this->{$text} );
        }
        elsif ( !$this->{_referees}{$text}{$topic} ) {

            # This is potentially expensive. When looking for orphans,
            # it should suffice to know that a page is referred to, and
            # delete it from the hash. However we will need to know
            # _what_ refers to it if we are ever to detect cycles.
            $this->{$text}++;
            $this->{_referees}{$text}{"$web.$topic"} = 1;
        }
    }
    return "";
}

# PUBLIC generate a table of results
sub tabulate {
    my ( $this, $params ) = @_;

    my $web = $this->{_web};

    my $header = "| *Action* | *$web";
    my @list = grep( !/^_/, keys(%$this) );
    if ( $this->{_keepAllRefs} ) {
        $header .= " Topic* | *References* | *Referees* |";
        @list = sort { $this->{$a} <=> $this->{$b} } @list;
    }
    else {
        $header .= " Orphaned Topics* |";
        @list = sort @list;
    }

    my $scope = $this->{_allwebs} ? "" : "&amp;currentwebonly=on";
    my $text  = "";
    my $url1  = "| <a href=\"%SCRIPTURL%/rename%SCRIPTSUFFIX%/$web";
    foreach my $topic (@list) {
        $text .=
"$url1/$topic?newweb=Trash&amp;nonwikiword=on$scope\">delete</a> | [[$web.$topic][$topic]]";
        if ( $this->{_keepAllRefs} ) {
            $text .= " | " . $this->{$topic} . " |";
            foreach my $referee ( keys( %{ $this->{_referees}{$topic} } ) ) {
                $text .= " $referee";
            }
        }
        $text .= " |\n";
    }

    return "$header\n$text\n*" . scalar(@list) . " topics*\n";
}

1;
