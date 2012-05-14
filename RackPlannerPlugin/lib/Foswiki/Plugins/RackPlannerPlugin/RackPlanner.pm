# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

package Foswiki::Plugins::RackPlannerPlugin::RackPlanner;

use strict;
###use warnings;

use CGI;
use POSIX qw(ceil);

use vars qw( $session $theTopic $theWeb $topic $web $attributes $text $refText
  $defaultsInitialized %defaults %options @renderedOptions @flagOptions %months %daysofweek
  @processedTopics @unknownParams $rpId
  $cgi $pluginName
);

$pluginName = "RackPlannerPlugin";

# =========================
sub initPlugin {
    $defaultsInitialized = 0;
}

# =========================
sub expand {
    ( $attributes, $text, $topic, $web ) = @_;
    $refText  = $text;
    $theWeb   = $web;
    $theTopic = $topic;

    &_initDefaults() unless $defaultsInitialized;

    local (%options);
    return &_createUnknownParamsMessage() unless &_initOptions($attributes);

    if ( $options{'autotopic'} && defined $options{'racks'} ) {
        $options{'topic'} .=
          ( $options{'topic'} eq "" ? '' : ',' ) . $options{'racks'};
    }

    $rpId++;

    Foswiki::Func::addToZone( 'head', "RackPlannerPlugin_JS",
"<script src='%PUBURL%/%SYSTEMWEB%/$pluginName/rackplannertooltips.js' language='javascript' type='text/javascript'></script>"
    );

    return ( $options{'dir'} =~ /^(leftright|rightleft)$/i )
      ? &_renderHorizontal( &_fetch( &_getTopicText() ) )
      : &_render( &_fetch( &_getTopicText() ) );
}

# =========================
sub _initDefaults {
    my $webbgcolor = &Foswiki::Func::getPreferencesValue( "WEBBGCOLOR", $web )
      || '#33CC66';
    %defaults = (
        'topic'     => "$web.$topic",
        'autotopic' => 'off',
        'racks'     => undef,
        'units'     => 46,
        'steps'     => 1,
        'emptytext' => '.',
        'unknownparamsmsg' =>
'%RED% Sorry, some parameters are unknown: %UNKNOWNPARAMSLIST% %ENDCOLOR% <br/> Allowed parameters are (see %SYSTEMWEB%.$pluginName topic for more details): %KNOWNPARAMSLIST%',
        'fontsize'           => 'x-small',
        'iconsize'           => '12px',
        'dir'                => 'bottomup',          # or 'topdown'
        'displayconnectedto' => 0,
        'displaynotes'       => 0,
        'displayowner'       => 0,
        'notesicon'          => '%P%',
        'connectedtoicon'    => '%M%',
        'conflicticon'       => '%S%',
        'ownericon'          => '%ICON{persons}%',
        'devicefgcolor'      => '#000000',
        'devicebgcolor'      => '#f0f0f0',
        'emptyfgcolor'       => '#000000',
        'emptybgcolor'       => '#f0f0f0',
        'name'               => 'U',
        'rackstatformat' =>
          'Empty: %EUU<br/>Largest Empty Block: %LEBU<br/>Occupied: %OUU',
        'statformat' =>
'#Racks: %R, #Units: %U, Occupied: %OUU, Empty: %EUU, Largest Empty Block: %LEBU',
        'displaystats'      => 1,
        'unitcolumnformat'  => '%U',
        'displayunitcolumn' => 1,
        'unitcolumnpos'     => 'left',
        'unitcolumnfgcolor' => undef,
        'unitcolumnbgcolor' => undef,
        'columnwidth'       => "",
        'textdir'           => 'leftright',
        'enablejstooltips'  => 1,
        'tooltipfixleft'    => -163,
        'tooltipfixtop'     => 0,
        'tooltipbgcolor'    => "",
        'tooltipfgcolor'    => "",
        'tooltipformat' =>
'<b><span title="Device name"> %DEVICE%: </span></b> <span title="Form factor">%FORMFACTOR%</span> (<span title="Start-End units">%SUNIT%-%EUNIT%</span>, <span title="Rack name"> %RACK%</span>)<div title="Owner">%OWNERICON% %OWNER% </div><div title="Connected to">%CONNECTEDTOICON% %CONNECTEDTO% </div><div title="Notes">%NOTESICON% %NOTES% </div> <div style="font-size:xx-small;text-align:right;"><span style="background-color:red;" title="Close tooltip">%CLOSEBUTTON%</span></div>',
        'clicktooltip'     => 0,
        'clicktooltiptext' => 'click for information',
    );

    @renderedOptions = (
        'name',      'notesicon', 'conflicticon', 'connectedtoicon',
        'ownericon', 'emptytext'
    );
    @flagOptions = (
        'autotopic',          'displaystats',
        'displayconnectedto', 'displaynotes',
        'displayowner',       'displayunitcolumn',
        'enablejstooltips',   'clicktooltip'
    );

    $rpId = 0;

    $defaultsInitialized = 1;

}

# =========================
sub _initOptions {
    my ($attributes) = @_;

    my %params = &Foswiki::Func::extractParameters($attributes);

    my @allOptions = keys %defaults;

    # Check attributes:
    @unknownParams = ();
    foreach my $option ( keys %params ) {
        push( @unknownParams, $option )
          unless grep( /^\Q$option\E$/, @allOptions );
    }
    return 0 if $#unknownParams != -1;

    # Setup options (attributes>plugin preferences>defaults):
    %options = ();
    foreach my $option (@allOptions) {
        my $v = $params{$option};
        if ( defined $v ) {
            if ( grep /^\Q$option\E$/, @flagOptions ) {
                $options{$option} = ( $v !~ /^(0|off|false|no)$/i );
            }
            else {
                $options{$option} = $v;
            }
        }
        else {
            if ( grep /^\Q$option\E$/, @flagOptions ) {
                $v = &Foswiki::Func::getPreferencesFlag(
                    "\U$pluginName\E_\U$option\E")
                  || undef;
            }
            else {
                $v = &Foswiki::Func::getPreferencesValue(
                    "\U$pluginName\E_\U$option\E");
            }
            $v = undef if ( defined $v ) && ( $v eq "" );
            $options{$option} = ( defined $v ) ? $v : $defaults{$option};
        }

    }

    # Render some options:
    foreach my $option (@renderedOptions) {
        if ( $options{$option} !~ /^(\s|\&nbsp\;)*$/ ) {
            $options{$option} =
              &Foswiki::Func::expandCommonVariables( $options{$option}, $web );
            $options{$option} =
              &Foswiki::Func::renderText( $options{$option}, $web );
        }
    }

    @processedTopics = ();

    $cgi = &Foswiki::Func::getCgiQuery();

    return 1;
}

# =========================
sub _fetch {

    my ($text) = @_;
    my %entries = ();

    foreach
      my $line ( grep( /^\s*\|([^|]*\|){4,}\s*$/, split( /\r?\n/, $text ) ) )
    {

        my (
            $dummy,       $server, $rack,   $sunit, $ff,
            $connectedto, $owner,  $colimg, $notes
        ) = split /\s*\|\s*/, $line;

        next if $rack =~ /^\*[^\*]+\*$/;    ### ignore header

        my $bladeunit = undef;

        ( $bladeunit, $sunit ) = split /\s*\@\s*/, $sunit if ( $sunit =~ /\@/ );

        my $arrRef = $entries{$rack}{$sunit};
        unless ( defined $arrRef ) {
            my @arr = ();
            $arrRef = \@arr;
            $entries{$rack}{$sunit} = $arrRef;
        }

        my $infosRef = {
            'server'      => $server,
            'formfactor'  => $ff,
            'rack'        => $rack,
            'sunit'       => $sunit,
            'connectedto' => $connectedto,
            'owner'       => $owner,
            'colimg'      => $colimg,
            'notes'       => $notes,
            'bladeunit'   => $bladeunit
        };

        push @{$arrRef}, $infosRef;

    }

    $options{'racks'} = join( ',', keys %entries )
      unless defined $options{'racks'};

    return \%entries;
}

# =========================
sub _renderJSTooltipText {
    my ( $id, $entryRef, $sunit, $eunit ) = @_;
    my $text = $options{'tooltipformat'};
    $text =~
s /\%CLOSEBUTTON\%/$cgi->a({-href=>"javascript:rppTooltipHide('$id');"},'[X]')/egs;
    $text =~ s /\%SUNIT\%/$sunit/gs;
    $text =~ s /\%EUNIT\%/$eunit/gs;
    $text =~ s /\%DEVICE\%/\%SERVER\%/gs;
    $text =~
s /\%([^\%\s]+?ICON)\%/(defined $options{"\L$1\E"}?$options{"\L$1\E"}:"\%$1\%")/egs;
    $text =~
s /\%([^\%\s]+)\%/(defined $$entryRef{"\L$1\E"}?$$entryRef{"\L$1\E"}:"\%$1\%")/egs;
    return &Foswiki::Func::renderText($text);
}

# =========================
sub _renderHorizontal {

    my ($entriesRef) = @_;

    my @racks = split /\s*\,\s*/, $options{'racks'};

    my $startUnit = -abs( $options{'units'} );
    my $endUnit   = -1;
    my $steps     = abs( $options{'steps'} );

    my $conflictIcon = &_resizeIcon( $options{'conflicticon'} );

    if ( $options{'dir'} =~ /^leftright$/i ) {
        $endUnit   = -$startUnit;
        $startUnit = 1;
    }

    my $tooltips = "";

    my @stats     = ();
    my $unitRow   = "";
    my @rackRows  = ();
    my @fillCols  = ();
    my @statsRefs = ();
    for ( my $unit = $startUnit ; $unit <= $endUnit ; $unit += $steps ) {

        ### unit row:
        if ( $options{'displayunitcolumn'} ) {
            my $f = $options{'unitcolumnformat'};
            $f =~ s/\%U/abs($unit)/esg;
            $unitRow .= $cgi->td(
                { -align => 'center', -width => $options{'columnwidth'} }, $f );
        }

        ### rack rows:
        for ( my $rackNumber = 0 ; $rackNumber <= $#racks ; $rackNumber++ ) {
            my $rack = $racks[$rackNumber];
            if ( $unit == $startUnit ) {
                $statsRefs[$rackNumber] =
                  &_getRackStatistics( $$entriesRef{$rack} );
                push @stats, $statsRefs[$rackNumber];
                $rackRows[$rackNumber] =
                  $cgi->Td( { -align => 'center' }, " $rack " );
                $fillCols[$rackNumber] = 0;
            }

            my $entryListRef = $$entriesRef{$rack}{ abs($unit) };
            if (   ( defined $entryListRef )
                && ( $#$entryListRef != -1 )
                && ( $fillCols[$rackNumber] == 0 ) )
            {
                my $entryRef = shift @{$entryListRef};

                my $colspan = 1;
                if ( $$entryRef{'formfactor'} =~ m/(\d+)/ ) {
                    $colspan = $1 / $options{'steps'};
                    $colspan = 1 unless $colspan > 0;
                }

                if ( $unit + $colspan <= $endUnit + 1 ) {

                    $fillCols[$rackNumber] = $colspan - 1;

                    my $unitId = "RPP_${rpId}_${rackNumber}_" . abs($unit);
                    my ( $fgcolor, $bgcolor, $style ) =
                      &_getColorsAndStyle( $$entryRef{'colimg'},
                        ( $$entryRef{'server'} =~ /\// ) );

                    my $title =
                        $$entryRef{'formfactor'} . '('
                      . abs($unit) . '-'
                      . ( abs( $unit + $colspan - 1 ) ) . ')';

                    $tooltips .= &_renderHiddenTooltip(
                        "${unitId}_TT",
                        $unitId,
                        &_renderJSTooltipText(
                            "${unitId}_TT", $entryRef,
                            abs($unit),     abs( $unit + $colspan - 1 )
                        ),
                        $style
                    ) if $options{'enablejstooltips'};

                    my $tooltipshow =
                      $options{'enablejstooltips'}
                      ? "rppTooltipShow('${unitId}_TT','$unitId',$options{'tooltipfixleft'},$options{'tooltipfixtop'},true);"
                      : "";
                    my ( $onmouseover, $onclick );
                    $onmouseover = $options{'clicktooltip'} ? "" : $tooltipshow;
                    $onclick = $options{'clicktooltip'} ? $tooltipshow : "";

                    $rackRows[$rackNumber] .= $cgi->td(
                        {
                            -title => $options{'enablejstooltips'}
                              && $options{'clicktooltip'}
                            ? $options{'clicktooltiptext'}
                            : &_encodeTitle($title),
                            -align => ( $options{'textdir'} =~ /^topdown$/i )
                            ? 'center'
                            : 'left',
                            -valign      => 'top',
                            -colspan     => $colspan,
                            -style       => $style,
                            -bgcolor     => $bgcolor,
                            -width       => $options{'columnwidth'},
                            -id          => $unitId,
                            -onmouseover => $onmouseover,
                            -onclick     => $onclick,
                        },
                        &_renderTextContent($entryRef)
                    );
                }
                else {
                    unshift @{$entryListRef}, $entryRef;

                }

                if ( $#$entryListRef != -1 ) {
                    $rackRows[$rackNumber] .=
                      &_renderConflictCell( abs($unit), $entryListRef,
                        $conflictIcon );
                }

            }
            else {
                if ( $fillCols[$rackNumber] <= 0 ) {
                    $rackRows[$rackNumber] .= $cgi->td(
                        {
                            -align  => 'center',
                            -valign => 'top',
                            -width  => $options{'columnwidth'},
                            -title  => &_encodeTitle( abs($unit) ),
                            -style =>
"background-color:$options{'emptybgcolor'};color:$options{'emptyfgcolor'}"
                        },
                        &_renderEmptyText( $rack, $unit )
                    );
                }
                $fillCols[$rackNumber]-- if $fillCols[$rackNumber] > 0;
            }

            if ( $unit == $endUnit ) {
                $rackRows[$rackNumber] .= $cgi->th(
                    { -valign => 'top', -align => 'left' },
                    &_renderRackStatistics( $statsRefs[$rackNumber] )
                ) if $options{'displaystats'};

                $rackRows[$rackNumber] = $cgi->Tr( $rackRows[$rackNumber] );
            }
        }
    }

    ### unit row:
    my $fgcolor =
      defined $options{'unitcolumnfgcolor'}
      ? $options{'unitcolumnfgcolor'}
      : "";
    my $bgcolor =
      defined $options{'unitcolumnbgcolor'}
      ? $options{'unitcolumnbgcolor'}
      : "";
    $unitRow = $cgi->Tr(
        {
            -style  => "background-color:$bgcolor;color:$fgcolor;",
            -align  => 'center',
            -valign => 'middle'
        },
        $cgi->td( { -title => &_encodeTitle( $options{'units'} ) },
            $options{'name'} )
          . $unitRow
    ) if ( $options{'displayunitcolumn'} );

    ### table:
    my $text = "";
    $text .= $cgi->start_table(
        {
            -cellpadding => '1',
            -cellspacing => '1',
            -class       => 'rackPlannerPluginTable'
        }
    );
    $text .= $unitRow
      if $options{'displayunitcolumn'}
          && $options{'unitcolumnpos'} =~ /^(both|all|top|left)$/i;
    $text .= join(
        (
                 $options{'displayunitcolumn'}
              && $options{'unitcolumnpos'} =~ /^all$/i
        ) ? "$unitRow\n" : "\n",
        @rackRows
    );
    $text .= $unitRow
      if $options{'displayunitcolumn'}
          && $options{'unitcolumnpos'} =~ /^(both|all|bottom|right)$/i;
    $text .= $cgi->Tr(
        $cgi->td()
          . $cgi->td(
            { -colspan => $options{'units'} },
            &_renderStatistics( \@stats )
          )
    ) if $options{'displaystats'} && ( $#stats > 0 );

    $text .= $cgi->end_table();
    $text .= $tooltips;

    $text =
      $cgi->div( { -style => 'font-size:' . $options{'fontsize'} }, $text );

    return $text;
}

# =========================
sub _render {
    my ($entriesRef) = @_;
    my $text = "";

    my @racks = split /\s*\,\s*/, $options{'racks'};

    my $startUnit = -abs( $options{'units'} );
    my $endUnit   = -1;
    my $steps     = abs( $options{'steps'} );

    if ( $options{'dir'} =~ /^topdown$/i ) {
        $endUnit   = -$startUnit;
        $startUnit = 1;
    }
    $text .= '<noautolink>';
    $text .= $cgi->start_table(
        {
            -cellpadding => '0',
            -cellspacing => '1',
            -class       => 'rackPlannerPluginTable'
        }
    );

    ### render table header:
    my $tr = "";

    my $unitColumnStyle = "";
    $unitColumnStyle .=
      'background-color:' . $options{'unitcolumnbgcolor'} . ';'
      if $options{'unitcolumnbgcolor'};
    $unitColumnStyle .= 'color:' . $options{'unitcolumnfgcolor'} . ';'
      if $options{'unitcolumnfgcolor'};
    my $unitColumnHeader = $cgi->th(
        {
            -style => $unitColumnStyle,
            -align => 'center',
            -title => &_encodeTitle( $options{'units'} )
        },
        $options{'name'}
    );
    my $unitColumn = (
        $options{'displayunitcolumn'}
        ? $cgi->td(
            { -style => $unitColumnStyle, -valign => 'top' },
            &_renderUnitColumn( $startUnit, $endUnit, $steps )
          )
        : undef
    );

    $tr .= $unitColumnHeader
      if $options{'displayunitcolumn'}
          && $options{'unitcolumnpos'} =~ /^(left|both|all)$/i;

    for ( my $rackNumber = 0 ; $rackNumber <= $#racks ; $rackNumber++ ) {
        my $rack = $racks[$rackNumber];
        $tr .=
          $cgi->th( { -align => 'center' }, &Foswiki::Func::renderText($rack) )
          . "\n";
        $tr .= $unitColumnHeader
          if $options{'displayunitcolumn'}
              && ( $options{'unitcolumnpos'} =~ /^all$/i )
              && ( $rackNumber < $#racks );

    }

    $tr .= $unitColumnHeader
      if $options{'displayunitcolumn'}
          && $options{'unitcolumnpos'} =~ /^(right|both|all)$/i;

    $text .= $cgi->Tr($tr);

    ## render table data:
    $tr = "";

    my $tooltips = "";

    $tr .= $unitColumn
      if $options{'displayunitcolumn'}
          && $options{'unitcolumnpos'} =~ /^(left|both|all)$/ig;

    my $conflictIcon = &_resizeIcon( $options{'conflicticon'} );

    my $statRow = $cgi->td("");

    my @stats = ();
    for ( my $rackNumber = 0 ; $rackNumber <= $#racks ; $rackNumber++ ) {
        my $rack     = $racks[$rackNumber];
        my $td       = "";
        my $fillRows = 0;

        my $statsRef = &_getRackStatistics( $$entriesRef{$rack} );
        push @stats, $statsRef;
        $statRow .= $cgi->th(
            { -valign => 'top', -align => 'left' },
            &_renderRackStatistics($statsRef)
        ) if $options{'displaystats'};
        $statRow .= $cgi->th()
          if $options{'displayunitcolumn'}
              && $options{'unitcolumnpos'} =~ /^all$/ig;
        for ( my $unit = $startUnit ; $unit <= $endUnit ; $unit += $steps ) {
            my $itd          = "";
            my $rowspan      = 1;
            my $bgcolor      = $options{'devicebgcolor'};
            my $fgcolor      = $options{'devicefgcolor'};
            my $style        = "";
            my $entryListRef = $$entriesRef{$rack}{ abs($unit) };
            if (   ( defined $$entriesRef{$rack}{ abs($unit) } )
                && ( $#$entryListRef != -1 )
                && ( $fillRows == 0 ) )
            {
                my $entryRef = shift @{$entryListRef};

                if ( $$entryRef{'formfactor'} =~ m/(\d+)/ ) {
                    $rowspan = $1 / $options{'steps'};
                    $rowspan = 1 unless $rowspan > 0;
                }

                if ( $unit + $rowspan <= $endUnit + 1 ) {

                    my $unitId = "RPP_${rpId}_${rackNumber}_" . abs($unit);
                    $fillRows = $rowspan - 1;
                    my $title =
                        $$entryRef{'formfactor'} . '('
                      . abs($unit) . '-'
                      . ( abs( $unit + $rowspan - 1 ) ) . ')';

                    ( $fgcolor, $bgcolor, $style ) =
                      &_getColorsAndStyle( $$entryRef{'colimg'},
                        ( $$entryRef{'server'} =~ /\// ) );

                    $tooltips .= &_renderHiddenTooltip(
                        "${unitId}_TT",
                        $unitId,
                        &_renderJSTooltipText(
                            "${unitId}_TT", $entryRef,
                            abs($unit),     abs( $unit + $rowspan - 1 )
                        ),
                        $style
                    ) if $options{'enablejstooltips'};
                    $itd .= &_renderTextContent($entryRef);
                    my $tooltipshow =
                      $options{'enablejstooltips'}
                      ? "rppTooltipShow('${unitId}_TT','$unitId',$options{'tooltipfixleft'},$options{'tooltipfixtop'},true);"
                      : "";
                    my ( $onmouseover, $onclick );
                    $onmouseover = $options{'clicktooltip'} ? "" : $tooltipshow;
                    $onclick = $options{'clicktooltip'} ? $tooltipshow : "";

                    $itd = $cgi->td(
                        {
                            -title => $options{'enablejstooltips'}
                              && $options{'clicktooltip'}
                            ? $options{'clicktooltiptext'}
                            : &_encodeTitle($title),
                            -valign      => 'top',
                            -rowspan     => $rowspan,
                            -nowrap      => 'nowrap',
                            -style       => $style,
                            -bgcolor     => $bgcolor,
                            -id          => $unitId,
                            -onmouseover => $onmouseover,
                            -onclick     => $onclick,
                        },
                        $itd
                    ) . "\n";
                }
                else {
                    unshift @{$entryListRef}, $entryRef;
                }

                if ( $#$entryListRef != -1 ) {
                    $itd .=
                      &_renderConflictCell( abs($unit), $entryListRef,
                        $conflictIcon );
                }
                else {
                    $itd .=
                      $cgi->td( { -title => &_encodeTitle( abs($unit) ) },
                        '&nbsp;' )
                      if ( $rowspan > 1 );
                }

            }
            else {
                $bgcolor = $options{'emptybgcolor'};
                $fgcolor = $options{'emptyfgcolor'};
                if ( $fillRows == 0 ) {
                    $itd .= &_renderEmptyText( $rack, $unit );
                }
                else {
                    if ( defined $entryListRef && $#$entryListRef != -1 ) {

                        my $title =
                          &_renderConflictTitle( abs($unit), $entryListRef );
                        $itd .= $cgi->span( { -title => $title, },
                            &_retitleIcon( $conflictIcon, $title ) . '&nbsp;' );
                        $bgcolor = "white";
                        $fgcolor = "red";
                    }
                    else {
                        $itd .= "&nbsp;";
                        $bgcolor = "white";
                    }
                    $fillRows--;
                }
                $style = "background-color:$bgcolor;color:$fgcolor";
                $itd   = $cgi->td(
                    {
                        -title   => &_encodeTitle( abs($unit) ),
                        -style   => $style,
                        -bgcolor => $bgcolor
                    },
                    $itd
                );
            }
            $td .= $cgi->Tr($itd);

        }
        $td = '<noautolink>'
          . $cgi->start_table(
            {
                -cellpadding => '0',
                -cellspacing => '1',
                hight        => '100%',
                width        => '100%'
            }
          )
          . $td
          . $cgi->end_table()
          . '</noautolink>';

        $tr .= $cgi->td( { -valign => 'top', -align => 'left' }, $td );
        $tr .= $unitColumn
          if $options{'displayunitcolumn'}
              && ( $options{'unitcolumnpos'} =~ /^all$/ig )
              && ( $rackNumber < $#racks );
    }

    $tr .= $unitColumn
      if $options{'displayunitcolumn'}
          && $options{'unitcolumnpos'} =~ /^(right|both|all)$/ig;

    $text .= $cgi->Tr($tr);

    $text .= $cgi->Tr($statRow) if $options{'displaystats'};

    my $colspan =
      $#racks + 1 +
      (      $options{'displayunitcolumn'}
          && $options{'unitcolumnpos'} =~ /^all$/i ? $#racks : 0 );
    $text .=
      $cgi->Tr( $cgi->td()
          . $cgi->td( { -colspan => $colspan }, &_renderStatistics( \@stats ) )
      ) if $options{'displaystats'} && ( $#stats > 0 );

    $text .= $cgi->end_table();
    $text .= '</noautolink>';
    $text .= $tooltips;
    $text = $cgi->div( { -style => "font-size:$options{'fontsize'};" }, $text );

    return $text;
}

# =========================
sub _renderUnitColumn {
    my ( $startUnit, $endUnit, $steps ) = @_;
    my $text = "";
    for ( my $unit = $startUnit ; $unit <= $endUnit ; $unit += $steps ) {
        my $f = $options{'unitcolumnformat'};
        my $u = abs($unit);
        $f =~ s/%U/$u/g;
        $f = "<span style=\"background-color:"
          . (
            defined $options{'unitcolumnbgcolor'}
            ? $options{'unitcolumnbgcolor'}
            : "#f0f0f0"
          ) . "\">$f</span>";
        $text .= $cgi->Tr(
            $cgi->td(
                {
                    -valign  => 'top',
                    -align   => 'right',
                    -rowspan => '1',
                    -nowrap  => 'nowrap'
                },
                $f
            )
        );
    }
    $text = '<noautolink>'
      . $cgi->start_table(
        {
            -cellspacing => '1',
            -cellpadding => '0',
            -height      => '100%',
            -width       => '100%',
        }
      )
      . $text
      . $cgi->end_table()
      . '</noautolink>';
    return $text;
}

# =========================
sub _renderEmptyText {
    my ( $rack, $unit ) = @_;
    my $text = $options{'emptytext'};

    $text =~ s/%R/$rack/ig;
    $text =~ s/%U/$unit/ig;
    return " $text ";
}

# =========================
sub _renderConflictCell {
    my ( $unit, $entryListRef, $conflictIcon ) = @_;
    my $title = &_renderConflictTitle( $unit, $entryListRef );
    my $text = $cgi->td(
        {
            -title   => $title,
            -bgcolor => 'white',
            -style   => 'background-color:white;color:red'
        },
        &_retitleIcon( $conflictIcon, $title ) . '&nbsp;'
    );
    return $text;
}

# =========================
sub _renderHiddenTooltip {
    my ( $id, $pId, $text, $style ) = @_;

    my $fgcolor = $options{'tooltipfgcolor'}
      if defined $options{'tooltipfgcolor'} && $options{'tooltipfgcolor'} ne "";
    my $bgcolor = $options{'tooltipbgcolor'}
      if defined $options{'tooltipbgcolor'} && $options{'tooltipbgcolor'} ne "";

    $style = "" unless defined $style;

    $bgcolor = $options{'devicebgcolor'}
      if !defined $bgcolor && $style !~ /background-color:/;

    $style .= ";background-color:$bgcolor"
      if defined $bgcolor && $style !~ /background-color:/;
    $style .= ";color:$fgcolor"
      if defined $fgcolor && $style !~ /(^color:|;\s*color:)/;

    return $cgi->div(
        {
            -id => ${id},
            -style =>
"text-align:left;visibility:hidden;position:absolute;top:0;left:0;z-index:2;font: normal $options{'fontsize'} sans-serif;padding: 3px; border: solid 1px; $style",
        },
        $text
    );
}

# =========================
sub _renderTextContent {
    my ($entryRef) = @_;
    my $ret = "";
    my @colors       = split /\s+[\/\#]\s+/, $$entryRef{'colimg'};
    my @connectedtos = split /\s+[\/\#]\s+/, $$entryRef{'connectedto'};
    my @owners       = split /\s+[\/\#]\s+/, $$entryRef{'owner'};
    my @notes        = split /\s+[\/\#]\s+/, $$entryRef{'notes'};

    foreach my $s ( split( /\s+[\/\#]\s+/, $$entryRef{'server'} ) ) {
        my $colors = "";
        $colors = shift @colors if $#colors != -1;
        my $owner = undef;
        $owner = shift @owners if $#owners != -1;
        my $note = undef;
        $note = shift @notes if $#notes != -1;
        my $connectedto = undef;
        $connectedto = shift @connectedtos if $#connectedtos != -1;

        my $text = $s;

        $text .= ":"
          if ( $options{'displayconnectedto'}
            || $options{'displayowner'}
            || $options{'displaynotes'} );
        $text .= " $connectedto "
          if defined $connectedto && $options{'displayconnectedto'};
        $text .= " $owner " if defined $owner && $options{'displayowner'};
        $text .= " $note "  if defined $note  && $options{'displaynotes'};

        $text .= &_renderIconContent( $connectedto, $note );
        my ( $fgcolor, $bgcolor, $style ) =
          &_getColorsAndStyle( $colors, ( $$entryRef{'server'} !~ /\// ) );

        $text = &Foswiki::Func::renderText($text);

        $text =~ s/<sup[^>]*>(.*?)<\/sup[^>]*>/$1/igs;
        $text =~ s/<sub[^>]*>(.*?)<\/sub[^>]*>/$1/igs;

        my $fontsize = $options{'fontsize'};
        if ( $text =~ /<(a|div|span)\s+/i )
        {    ## modify existing links/span/div/font styles/colors/sizes
            foreach my $tag ( ( 'div', 'a', 'span' ) ) {
                unless (
                    $text =~ s/(<$tag\s+[^>]*?style=["'])[^"'>]*/$1$style/igs )
                {
                    $text =~ s/(<$tag\s+)/$1style="$style" /igs;
                }
                $text =~ s/(<$tag\s+[^>]*?color=['"])[^"'>]*/$1$fgcolor/igs;
            }
            $text =~
s/(<a[^>]+>)(.*?)(<\/a[^>]*>)/${1}<span style="color:$fgcolor">${2}<\/span>${3}/igs;
        }

#$text = $cgi->span({-style=>'font-size:'.$options{'fontsize'}.";$style", -title=>&_encodeTitle($owner,1)}, $text);
        $text = $cgi->span(
            { -style => $style, -title => &_encodeTitle( $owner, 1 ) }, $text );
        $text .= '<br/>' if ( $options{'dir'} =~ /^(leftright|rightleft)$/i );
        $ret .= $text;
    }

    sub _insBreaks {
        my ( $bef, $t, $beh ) = @_;
        $t =~ s/(\S)/$1<br\/>/gs;
        $t = $bef . $t if defined $bef;
        $t .= $beh if defined $beh;
        return $t;
    }
    $ret =~ s/(<\S+[^>]*>)?([^<]*)(<\/\w+[^>]*>)?/&_insBreaks($1,$2,$3)/egs
      if ( $options{'dir'} =~ /^(leftright|rightleft)$/i
        && $options{'textdir'} =~ /^topdown$/i );
    return $ret;
}

# =========================
sub _renderIconContent {
    my ( $connectedto, $note ) = @_;
    my $text            = "";
    my $notesIcon       = &_resizeIcon( $options{'notesicon'} );
    my $connectedtoIcon = &_resizeIcon( $options{'connectedtoicon'} );
    if (   ( defined $connectedto )
        && ( $connectedto !~ /^\s*$/ )
        && ( !$options{'displayconnectedto'} ) )
    {
        foreach my $ct ( split( /\s*\,\s*/, $connectedto ) ) {
            my $rt    = Foswiki::Func::renderText($ct);
            my $title = &_encodeTitle($ct);
            my $icon  = &_retitleIcon( $connectedtoIcon, $title );

            if ( $rt =~ /<a\s+[^>]*?href=\"([^\">]+)\"/ ) {
                $text .=
                  $cgi->a( { -href => &_encode_entities($1), -title => $title },
                    $icon );
            }
            else {
                $text .= $cgi->span( { -title => $title }, $icon );
            }
            $text .= '<br/>'
              if $options{'dir'} =~ /^(leftright|rightleft)$/i
                  && $options{'textdir'} =~ /^topdown$/i;
        }
    }

    if ( defined $note && $note !~ /^\s*$/ && !$options{'notes'} ) {
        my $rt    = Foswiki::Func::renderText($note);
        my $title = &_encodeTitle($note);
        my $icon  = &_retitleIcon( $notesIcon, $title );
        if ( $rt =~ /<a\s+[^>]*?href=\"([^\">]+)\"/ ) {
            $text .=
              $cgi->a( { -href => &_encode_entities($1), -title => $title },
                $icon );
        }
        else {
            $text .= $cgi->span( { -title => $title }, $icon );
        }
    }
    return $text;
}

# =========================
sub _getColorsAndStyle {
    my ( $colors, $denybgimage ) = @_;
    my ( $fgcolor, $bgcolor, $style ) =
      ( $options{'devicefgcolor'}, $options{'devicebgcolor'}, "" );

    #$denybgimage = 1 unless defined $denybgimage;

    if ( ( $colors =~ s/\@([a-z0-9]+)//i ) && ( !$denybgimage ) ) {
        $style .= $style eq '' ? '' : ';';
        $style .=
            'background-position:center;background-repeat:no-repeat;'
          . 'background-image:url('
          . Foswiki::Func::getPubUrlPath() . '/'
          . $Foswiki::cfg{SystemWebName} . '/'
          . $pluginName . '/'
          . $1 . '.png)';

    }
    foreach my $colimg ( split( /\s*,\s*/, $colors ) ) {
        if ( $colimg =~ /[^\s][\.\/\:]/ ) {
            $style .= $style eq '' ? '' : ';';
            $style .=
'background-position:center;background-repeat:no-repeat;background-image:url('
              . _encode_entities($colimg) . ');';
        }
        elsif ( $colimg =~ /^(\#[\d\w]+|\w+)$/ ) {
            if ( $style !~ /background-color:/ ) {
                $bgcolor = _encode_entities($colimg);
                $style .= $style eq '' ? '' : ';';
                $style .= 'background-color:' . $bgcolor;
            }
            else {
                $fgcolor = _encode_entities($colimg);
                $style .= $style eq '' ? '' : ';';
                $style .= 'color:' . $fgcolor;
            }
        }
    }
    return ( $fgcolor, $bgcolor, $style );
}

# =========================
sub _renderConflictTitle {
    my ( $unit, $entryListRef ) = @_;
    my $title = "$unit: conflict with";
    foreach my $entryRef ( @{$entryListRef} ) {
        $title .= " " . $$entryRef{'server'};
    }

    return &_encodeTitle($title);
}

# =========================
sub _resizeIcon {
    my ($icon) = @_;
    $icon =~ s/(<img\s+[^\>]*?width=")[^"]+"/$1$options{'iconsize'}"/;
    $icon =~ s/(<img\s+[^\>]*?height=")[^"]+"/$1$options{'iconsize'}"/;
    return $icon;
}

# =========================
sub _retitleIcon {
    my ( $icon, $title ) = @_;
    $icon =~ s/(alt|title)="[^"]*"/$1="$title"/ig;
    $icon =~ s/<img /<img alt="$title" /ig unless $icon =~ /alt=/;
    $icon =~ s/<img /<img title="$title" /ig unless $icon =~ /title=/;

    return $icon;
}

# =========================
sub _renderStatistics {
    my ($statsRef) = @_;
    my $text = $options{'statformat'};
    $text =~ s/%R/$#$statsRef+1/egi;
    my $maxContinuesEmptyUnits = 0;
    my $countEmptyUnits        = 0;
    my $countOccupiedUnits     = 0;
    foreach my $s ( @{$statsRef} ) {
        $maxContinuesEmptyUnits = $$s{'maxContinuesUnits'}
          if ( $$s{'maxContinuesUnits'} > $maxContinuesEmptyUnits );
        $countEmptyUnits    += $$s{'emptyUnits'};
        $countOccupiedUnits += $$s{'occupiedUnits'};
    }

    $text =~ s/%LEB/$maxContinuesEmptyUnits/ig;
    $text =~ s/%EU/$countEmptyUnits/ig;
    $text =~ s/%OU/$countOccupiedUnits/ig;
    $text =~ s/%U/($options{'units'}*($#$statsRef+1))/egi;

    return $text;
}

# =========================
sub _renderRackStatistics {
    my ($statsRef) = @_;

    my $text = $options{'rackstatformat'};

    $text =~ s/%EU/$$statsRef{'emptyUnits'}/g;
    $text =~ s/%LEB/$$statsRef{'maxContinuesUnits'}/g;
    $text =~ s/%OU/$$statsRef{'occupiedUnits'}/g;

    return $text;
}

# =========================
sub _getRackStatistics {
    my ($rackEntriesRef) = @_;

    my $startUnit = -abs( $options{'units'} );
    my $endUnit   = -1;
    my $steps     = abs( $options{'steps'} );

    if ( $options{'dir'} =~ /^topdown$/i ) {
        $endUnit   = -$startUnit;
        $startUnit = 1;
    }

    my $countEmptyUnits          = 0;
    my $countOccupiedUnits       = 0;
    my $countContinuesEmptyUnits = 0;
    my $maxContinuesEmptyUnits   = 0;
    for ( my $unit = $startUnit ; $unit <= $endUnit ; $unit += $steps ) {
        my $entriesRef = $$rackEntriesRef{ abs($unit) };
        if ( ( defined $entriesRef ) && ( $#$entriesRef != -1 ) ) {
            $$rackEntriesRef{ abs($unit) }[0]{'formfactor'} =~ m/(\d+)/;
            my $u = $1;
            if ( $u + $unit <= $endUnit + 1 ) {
                $countOccupiedUnits += $u;
                $countContinuesEmptyUnits = 0;
                $unit += $u - 1;
                next;
            }
            else {
                $countEmptyUnits          += $steps;
                $countContinuesEmptyUnits += $steps;
                $maxContinuesEmptyUnits = $countContinuesEmptyUnits
                  if ( $countContinuesEmptyUnits > $maxContinuesEmptyUnits );
            }
        }
        else {
            $countEmptyUnits          += $steps;
            $countContinuesEmptyUnits += $steps;
            $maxContinuesEmptyUnits = $countContinuesEmptyUnits
              if ( $countContinuesEmptyUnits > $maxContinuesEmptyUnits );
        }
    }
    return {
        'emptyUnits'        => $countEmptyUnits,
        'occupiedUnits'     => $countOccupiedUnits,
        'maxContinuesUnits' => $maxContinuesEmptyUnits
    };

}
### dro: following code is derived from Foswiki:Extensions.CalendarPlugin:
# =========================
sub _getTopicText() {

    my ( $web, $topic, $timezone );

    my $topics = $options{'topic'};

    my @topics = split /,\s*/, $topics;

    my $text = "";
    foreach my $topicpair (@topics) {

        ( $web, $topic ) = split /\./, $topicpair, 2;
        if ( !defined $topic ) {
            $topic = $web;
            $web   = $theWeb;
        }

        # ignore processed topics;
        grep( /^\Q$web.$topic\E$/, @processedTopics ) && next;

        push( @processedTopics, "$web.$topic" );

        if ( ( $topic eq $theTopic ) && ( $web eq $theWeb ) ) {

            # use current text so that preview can show unsaved events
            $text .= $refText;
        }
        else {
            $text .= &_readTopicText( $web, $topic );
        }
    }

    $text =~
      s/%INCLUDE{(.*?)}%/&_expandIncludedEvents($1, \@processedTopics)/geo;

    return $text;

}

# =========================
sub _readTopicText {
    my ( $theWeb, $theTopic ) = @_;
    my $text = '';
    if ( $Foswiki::Plugins::VERSION >= 1.010 ) {
        $text = &Foswiki::Func::readTopicText( $theWeb, $theTopic, '', 1 );
    }
    else {
        $text = &Foswiki::Func::readTopic( $theWeb, $theTopic );
    }

    # return raw topic text, including meta data
    return $text;
}

# =========================
sub _expandIncludedEvents {
    my ( $theAttributes, $theProcessedTopicsRef ) = @_;

    my ( $theWeb, $theTopic ) = ( $web, $topic );

    my $webTopic = &Foswiki::Func::extractNameValuePair($theAttributes);
    if ( $webTopic =~ /^([^\.]+)[\.\/](.*)$/ ) {
        $theWeb   = $1;
        $theTopic = $2;
    }
    else {
        $theTopic = $webTopic;
    }

    # prevent recursive loop
    grep ( /^\Q$theWeb.$theTopic\E$/, @{$theProcessedTopicsRef} ) and return "";

    push( @{$theProcessedTopicsRef}, "$theWeb.$theTopic" );

    my $text = &readTopicText( $theWeb, $theTopic );

    $text =~ s/.*?%STARTINCLUDE%//s;
    $text =~ s/%STOPINCLUDE%.*//s;

    # recursively expand includes
    $text =~
s/%INCLUDE{(.*?)}%/&_expandIncludedEvents( $1, $theProcessedTopicsRef )/geo;

    ## $text = Foswiki::Func::expandCommonVariables($text, $theTopic, $theWeb);

    return $text;
}

# =========================
sub _createUnknownParamsMessage {
    my $msg;
    $msg =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_UNKNOWNPARAMSMSG")
      || undef;
    $msg = $defaults{unknownparamsmsg} unless defined $msg;
    $msg =~ s/\%UNKNOWNPARAMSLIST\%/join(', ', sort @unknownParams)/eg;
    $msg =~ s/\%KNOWNPARAMSLIST\%/join(', ', sort keys %defaults)/eg;
    return $msg;
}

# =========================
sub _encode_entities {
    my ($text) = @_;

    return $text unless defined $text;

    $text =~ s/\</&lt;/g;
    $text =~ s/\>/&gt;/g;
    $text =~ s/\"/&quot;/g;
    $text =~ s/\[\[[^\]]+\]\[([^\]]+)\]\]/$1/g;
    $text =~ s/\[\[([^\]]+)\]\]/$1/g;

    return $text;

}

# =========================
sub _encodeTitle {
    my ( $title, $dontEncodeEntities ) = @_;
    return "" unless defined $title;
    $title =~ s/<[\/]?\w+[^>]*>//sg;
    $title =~ s/\[\[[^\]]+\]\[([^\]]+)\]\]/$1/g;
    $title =~ s/\[\[([^\]]+)\]\]/$1/g;

    $title = &_encode_entities($title) unless $dontEncodeEntities;
    return $title;
}
1;
