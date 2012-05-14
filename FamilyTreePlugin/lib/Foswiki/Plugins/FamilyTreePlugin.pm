
=pod

---+ package FamilyTreePlugin

Copyright (C) Crawford Currie 2005 http://c-dot.co.uk

=cut

package Foswiki::Plugins::FamilyTreePlugin;

use strict;

our $VERSION          = '$Rev$';
our $RELEASE          = '4 Oct 2010';
our $SHORTDESCRIPTION = 'A simple genealogy database';
our $node;

my $imgs = "<nop>%PUBURL%/<nop>%SYSTEMWEB%/FamilyTreePlugin";

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    Foswiki::Func::registerTagHandler( 'MANCESTORS',    \&_MANCESTORS );
    Foswiki::Func::registerTagHandler( 'FANCESTORS',    \&_FANCESTORS );
    Foswiki::Func::registerTagHandler( 'DESCENDANTS',   \&_DESCENDANTS );
    Foswiki::Func::registerTagHandler( 'GRDESCENDANTS', \&_GRDESCENDANTS );

    return 1;
}

# Handle the %MANCESTORS% tag
sub _MANCESTORS {
    my ( $session, $params, $topic, $web ) = @_;

    my $to = $params->{_DEFAULT};
    my @stack;
    my $wife = '';

    return "Bad parameters" unless ($to);

    while ( my $parents = _getParents($to) ) {

        my $col = ' <strong> ' . $to . ' </strong> ' . $wife . ' <br /> ';

        my $sibs = _getSiblings( $parents, $to );
        $col .= join( ' <br /> ', @$sibs );

        $wife = 'm. ' . _getFemale($parents);
        $to   = _getMale($parents);

        unshift( @stack, $col );
    }
    unshift( @stack, ' <strong> ' . $to . ' </strong> ' . $wife );

    my $row =
      CGI::Tr( join( '', map { CGI::td( { valign => 'top' }, $_ ) } @stack ) );
    return CGI::table( { border => 1 }, $row );
}

# Handle the %FANCESTORS% tag
sub _FANCESTORS {
    my ( $session, $params, $topic, $web ) = @_;

    my $to = $params->{_DEFAULT};
    my @stack;
    my $husband = '';

    return "Bad parameters" unless ($to);

    while ( my $parents = _getParents($to) ) {

        my $col = ' <strong> ' . $to . ' </strong> ' . $husband . ' <br /> ';

        my $sibs = _getSiblings( $parents, $to );
        $col .= join( ' <br /> ', @$sibs );

        $husband = 'm. ' . _getMale($parents);
        $to      = _getFemale($parents);

        unshift( @stack, $col );
    }
    unshift( @stack, ' <strong> ' . $to . ' </strong> ' . $husband );

    my $row =
      CGI::Tr( join( '', map { CGI::td( { valign => 'top' }, $_ ) } @stack ) );
    return CGI::table( { border => 1 }, $row );
}

# Handle the %DESCENDANTS% tag
sub _DESCENDANTS {
    my ( $session, $params, $topic, $web ) = @_;

    my $to = $params->{_DEFAULT} || $topic;
    my $style = <<HERE;
<noautolink>
<style>
.borderTable {
 margin: 0;
 padding: 0;
 height: 7px;
 overflow: hidden;
}

td.marriage {
// Marriage container
}
table.marriage {
 // Two-row table
 border: none;
}
td.marriageText {
 // First table row
}
td.marriageSpawn {
 // Second table row
}
.bio {
 width: auto;
 border: dotted thin green;
 margin: 7px;
}
.leftChild {
 background: url($imgs/leftChild.png) top left repeat-x;
 width: 7px;
 height: 7px;
}
.rightChild {
 background: url($imgs/rightChild.png) top right no-repeat;
 height: 7px;
}
.midChild {
 background: url($imgs/midChild.png) top left repeat-x;
 height: 7px;
}
.bottomChild {
 background: url($imgs/bottomChild.png) top left repeat-y;
}
</style>
</noautolink>
HERE
    return $style . _tabulateDescendants($to);
}

# Handle the %GRDESCENDANTS% tag
#  - Graph the descendants using GraphViz - DirectedGraphPlugin
#
sub _GRDESCENDANTS {
    my ( $session, $params, $topic, $web ) = @_;

    my $to      = $params->{_DEFAULT} || $topic;
    my $engine  = $params->{engine}   || "dot";
    my $raw     = $params->{raw}      || 0;
    my $orient  = $params->{orientation};
    my $ranksep = $params->{ranksep}  || ".25";
    my $nodesep = $params->{nodesep}  || ".25";
    my $size    = $params->{size};

    my $lt = "<";
    if ( $raw == 1 ) { $lt = "&lt;"; }

    $node = 0;    # Counter for unnamed nodes (no issue)

    my $nodeURL = Foswiki::Func::getScriptUrl( $web, "X", "view" );
    chop($nodeURL);

    my $gdPrefix .=
      $lt . "dot map=1 vectorformats=\"ps\" engine=\"$engine\" >\n";
    $gdPrefix .= "    digraph G { \n";
    $gdPrefix .= "       orientation=\"$orient\"\n" if $orient;
    $gdPrefix .= "       size = \"$size\"; \n"
      if $size;    #Graph size in width,high
     #$gdPrefix .= "       page = \"8.5,11\"; \n";  # Used to set multi-page PS output - breaks png output
    $gdPrefix .= "       ranksep=\"$ranksep\"; nodesep=\"$nodesep\";\n";
    $gdPrefix .= "       node [URL=\"" . $nodeURL . "\\N\" ];\n";

    my $gdSuffix = "}\n </dot>\n ";

    return $gdPrefix . _graphDescendants($to) . $gdSuffix;

#return "<verbatim>" . $gdPrefix . _graphDescendants( $to ) . $gdSuffix . "</verbatim>";
}

# Generate a digraph representing all descendants of $who
sub _graphDescendants {
    my $who = shift;

    my $marriages = _getMarriages($who);

    my $martable = '';
    foreach my $marriage (@$marriages) {
        $martable .= "$who -> $marriage [arrowhead=\"none\"];\n";
        my $kids   = _getOffspring($marriage);
        my $childs = '';
        my $cs     = 1;
        if ( scalar(@$kids) ) {
            foreach my $issue (@$kids) {
                $martable .= "$marriage -> $issue [arrowhead=\"none\"];\n";
                $childs   .= _graphDescendants($issue);
            }
            $cs = scalar(@$kids);
        }
        else {
            $node++;
            $childs =
              "$marriage -> n$node [arrowhead=\"none\", style=\"dotted\"]";
            $childs .=
"n$node [shape=plaintext,label=\"no issue\",fontname=\"Helvetica-Oblique\"];\n";
        }
        my $m1 =
            "%SPACEOUT{"
          . _getMale($marriage)
          . "}% m. %SPACEOUT{"
          . _getFemale($marriage) . "}%";

        my $mdate = Foswiki::Func::expandCommonVariables(
            '%FORMFIELD{"Date" topic="' . $marriage . '"}%' );
        my $m3 = Foswiki::Func::expandCommonVariables(
            '%FORMFIELD{"Disolved" topic="' . $marriage . '"}%' );
        if ( length($m3) > 1 ) { $mdate .= " - " . $m3; }
        $m3 = Foswiki::Func::expandCommonVariables(
            '%FORMFIELD{"Cause" topic="' . $marriage . '"}%' );
        if ( length($m3) > 1 ) {
            $mdate .= " (" . $m3 . ")";
        }

        if ( length($mdate) > 1 ) {
            $mdate = "\\n " . $mdate;
        }
        my $m = " $marriage [shape=plaintext,label=\"$m1$mdate\" ];\n";
        $martable .= $m . $childs;
    }
    my $w = $who . "[shape=record,label=\"%SPACEOUT{$who}%";
    $w .= "\\l b. %FORMFIELD{\"Born\" topic=\"$who\"}%";
    $w .= "\\l d. %FORMFIELD{\"Died\" topic=\"$who\"}%\\l\" ];\n";
    return $w . $martable;
}

# Generate a table representing all descendants of $who
sub _tabulateDescendants {
    my $who = shift;

    my $marriages = _getMarriages($who);
    my $fiveHigh  = "<img src='$imgs/fiveHigh.png'>";
    my $martable  = '';
    foreach my $marriage (@$marriages) {
        my $kids   = _getOffspring($marriage);
        my $childs = '';
        my $cs     = 1;
        my $extras = '';
        if ( scalar(@$kids) ) {
            for ( my $i = 0 ; $i < scalar(@$kids) ; $i++ ) {
                my $issue = $kids->[$i];
                my $class;
                if ( scalar(@$kids) == 1 ) {
                    $extras =
'<table width="100%" border=0 cellpadding=0 cellspacing=0 class=borderTable><tr><td width="50%">'
                      . $fiveHigh
                      . '</td><td class="bottomChild" width="50%">'
                      . $fiveHigh
                      . '</td></tr></table>';
                    $class = 'bottomChild';
                }
                elsif ( $i == 0 ) {
                    $class = '';
                    $extras =
'<table width="100%" border=0 cellpadding=0 cellspacing=0 class=borderTable><tr><td width="50%">'
                      . $fiveHigh
                      . '</td><td class="leftChild">'
                      . $fiveHigh
                      . '</td><td class="midChild">'
                      . $fiveHigh
                      . '</td></tr></table>';
                }
                elsif ( $i == scalar(@$kids) - 1 ) {
                    $extras =
'<table width="100%" border=0 cellpadding=0 cellspacing=0 class=borderTable><tr><td class="midChild">'
                      . $fiveHigh
                      . '</td><td width="7px" class="rightChild">'
                      . $fiveHigh
                      . '</td><td width="50%">'
                      . $fiveHigh
                      . '</td></tr></table>';
                }
                else {
                    $extras =
'<table width="100%" border=0 cellpadding=0 cellspacing=0 class=borderTable><tr><td width="50%" class="midChild">'
                      . $fiveHigh
                      . '</td><td class="bottomChild" width="1px">'
                      . $fiveHigh
                      . '</td><td class="midChild">'
                      . $fiveHigh
                      . '</td></tr></table>';
                }
                $childs .= CGI::td( $extras . _tabulateDescendants($issue) );
            }
            $cs = scalar(@$kids);
        }
        else {
            $childs = CGI::td( { align => "center" }, CGI::em('no issue') );
        }
        my $m = "[[$marriage][%SPACEOUT{$marriage}%]]";
        $m .= CGI::br()
          . CGI::em( '%FORMFIELD{"Date" topic="' . $marriage . '"}%' );
        $martable .= CGI::td(
            { class => 'marriage' },
            CGI::table(
                {
                    class       => 'marriage',
                    cellspacing => 0,
                    cellpadding => 0
                },
                CGI::Tr(
                    CGI::td(
                        {
                            colspan => $cs,
                            align   => 'center',
                            class   => 'marriageText'
                        },
                        $m
                    )
                  )
                  . CGI::Tr(
                    CGI::td(
                        { colspan => $cs },
'<table width="100%" border=0 cellpadding=0 cellspacing=0 class=borderTable><tr><td width="50%">'
                          . $fiveHigh
                          . '</td><td class="bottomChild" width="50%">'
                          . $fiveHigh
                          . '</td></tr></table>'
                    )
                  )
                  . CGI::Tr(
                    { valign => 'top', class => 'marriageSpawn' }, $childs
                  )
            )
        );
    }
    my $w = CGI::strong("[[$who][%SPACEOUT{$who}%]]");
    $w .= CGI::br() . CGI::em( 'b. %FORMFIELD{"Born" topic="' . $who . '"}%' );
    $w .= CGI::br() . CGI::em( 'd. %FORMFIELD{"Died" topic="' . $who . '"}%' );
    $w = CGI::div( { class => 'bio' }, $w );
    return CGI::table(
        { cellspacing => 0, cellpadding => 0, border => 0 },
        CGI::Tr(
            CGI::td(
                {
                    valign  => 'top',
                    align   => 'center',
                    colspan => scalar(@$marriages)
                },
                $w
            )
          )
          . CGI::Tr($martable)
    );
}

# Find out who $who married
sub _getMarriages {
    my $who  = shift;
    my $list = Foswiki::Func::expandCommonVariables(
            '%SEARCH{ "(^' 
          . $who . 'X|X' 
          . $who . '$)"
                  type="regex"
                  format="$topic"
                  multiple="on"
                  scope="topic"
                  nonoise="on"
                  separator=","}%'
    );
    my @names = split( /,/, $list );
    return \@names;
}

# Get the name of the union record that $of is logged as the issue of
sub _getParents {
    my $of = shift;

    # Establish the main line of descent
    my $parents = Foswiki::Func::expandCommonVariables(
        '%SEARCH{ "\| ' . $of . ' \|"
         type="regex"
         format="$topic"
         header=""
         nonoise="on"}%'
    );
    return $parents;
}

# Get the value of the "Male" field from a union record
sub _getMale {
    my $of = shift;

    return Foswiki::Func::expandCommonVariables(
        '%FORMFIELD{"Male" topic="' . $of . '"}%' );
}

# Get the value of the "Female" field from a union record
sub _getFemale {
    my $of = shift;

    return Foswiki::Func::expandCommonVariables(
        '%FORMFIELD{"Female" topic="' . $of . '"}%' );
}

# Get the siblings of a person record, as an array ref
sub _getSiblings {
    my ( $parents, $child ) = @_;

    my $kids = _getOffspring($parents);
    my @names = grep { !/^$child$/ } @$kids;
    return \@names;
}

# Get all the offspring of a union, as an array ref
sub _getOffspring {
    my $marriage = shift;
    my $list     = Foswiki::Func::expandCommonVariables(
        '%SEARCH{ "^\| [A-Z][A-Za-z0-9]+ \|.?$"
         type="regex"
         topic="' . $marriage . '"
         multiple="on"
         format="$text"
         separator="|"
         header=""
         nonoise="on"}%'
    );
    my @names = grep { $_ } map { s/\s+//g; $_ } split( /\|/, $list );
    return \@names;
}

1;
