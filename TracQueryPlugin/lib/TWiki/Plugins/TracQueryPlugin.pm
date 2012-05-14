# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Thomas Weigert
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
# =========================
#

# =========================
package TWiki::Plugins::TracQueryPlugin;

use DBI;

use strict;

# =========================
use vars qw( $web $topic $user $installWeb $VERSION $debug $RELEASE $pluginName
  %db $url $dbHost $dbName $dbUser $dbPasswd $dbPort $dbType %schema );

$VERSION    = '$Rev: 17316 (03 Aug 2008) $';
$RELEASE    = 'TWiki 4.2';
$pluginName = "TracQueryPlugin";               # Name of this Plugin
$debug      = 0;

%db = ();

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");
    $url = TWiki::Func::getPreferencesValue("\U$pluginName\E_URL") || '';
    if ( $url =~ /\/$/ ) { $url =~ s/(.*?)\/$/$1/; }

    $dbType = $TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_DB}
      || 'SQLite';    # Trac data base (either SQLite or MySQL)
    $dbType = lc($dbType);
    $dbName =
      $TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_DB_NAME};  # Trac database name
    $dbHost = $TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_HOST}
      || '';                                                # Trac database host
    $dbPort =
      $TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_DB_PORT};  # Trac database name
    $dbUser = $TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_USER}
      || '';    # user who has access to $dbName database
    $dbPasswd = $TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_PASSWD}
      || '';    # password for $dbUser

    TWiki::Func::registerTagHandler( 'TRAC', \&handleQuery, 'context-free' );
    TWiki::Func::registerTagHandler( 'TRACSUM', \&handleSumQuery,
        'context-free' );
    TWiki::Func::registerTagHandler( 'TRACMIN', \&handleMinQuery,
        'context-free' );
    TWiki::Func::registerTagHandler( 'TRACMAX', \&handleMaxQuery,
        'context-free' );
    TWiki::Func::registerTagHandler( 'TRACCOUNT', \&handleCountQuery,
        'context-free' );
    TWiki::Func::registerTagHandler( 'TRACAVG', \&handleAvgQuery,
        'context-free' );

    %schema = (    # All have 'name' as key field, omitted
        version   => [ 'time',  'description' ],
        milestone => [ 'due',   'completed', 'description' ],
        component => [ 'owner', 'description' ]
    );

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================

# In a more generic application, it might be better to change the
# query syntax to something like { ... search='     '... }
# where the text in the search attribute gives the query to be performed.
# e.g. for the examples in the docu
# search=""
# search="status='new|assigned'"
# search="owner='%WIKINAME%'"
# and use operators as in DBCacheContrib or QuerySearch

sub handleQuery {
    my ( $session, $attributes, $topic, $web ) = @_;

    my $webName   = $session->{webName};
    my $topicName = $session->{topicName};

    my $format =
         $attributes->remove('format')
      || TWiki::Func::getPreferencesValue("\U$pluginName\E_FORMAT")
      || "| \$id | \$severity | \$priority | \$status | \$reporter | \$component | \$description |";
    my $separator = $attributes->remove('separator');
    my $newline   = $attributes->remove('newline');

    my $res = performQuery($attributes);
    my $text = formatResult( $res, $format, $separator, $newline );
    return CGI::span( { class => 'twikiAlert' }, 'Query returned no results' )
      unless $text;
    return $text;

}

sub performQuery {

    my ($attributes) = @_;

    my @tables =
      split( /\s*,\s*/, $attributes->remove("_DEFAULT") || 'ticket' );
    my $table   = shift @tables;
    my $limit   = $attributes->remove('limit') || 0;
    my $custom  = '';
    my @cfields = ();

    if ( $table eq 'ticket' ) {
        $custom = TWiki::Func::getPreferencesValue("\U$pluginName\E_CUSTOM")
          || '';
        @cfields = split( '\s*,\s*', $custom );
    }

    $attributes->remove($TWiki::Attrs::RAWKEY);

    my $sqldb = openDB( \%db );
    return unless $sqldb;

    my $statement = "SELECT *";
    if (@cfields) {

        # make a renaming for every custom field
        my $cnt = 0;
        foreach (@cfields) {
            $statement .= ", c$cnt.value AS $_";
            $cnt++;
        }
    }
    if (@tables) {
        foreach my $tbl (@tables) {
            foreach ( @{ $schema{$tbl} } ) {
                $statement .= ", $tbl.$_ AS ${tbl}_$_";
            }
        }
    }
    $statement .= " FROM $table";
    if (@cfields) {

# make a join for every custom field
# SELECT *, c0.value AS test_one FROM ticket LEFT OUTER JOIN ticket_custom c0 ON (ticket.id = c0.ticket AND c0.name = 'test_one') LEFT OUTER JOIN ticket_custom c1 ON (ticket.id = c1.ticket AND c.name = 'test_two') WHERE ticket.id = '1'
        my $cnt = 0;
        foreach (@cfields) {
            $statement .=
" LEFT OUTER JOIN ticket_custom c$cnt ON ($table.id = c$cnt.ticket AND c$cnt.name = '$_')";
            $cnt++;
        }
    }
    if (@tables) {

        # make a join for each additional table to be merged
        foreach my $tbl (@tables) {
            $statement .= " LEFT OUTER JOIN $tbl ON ($table.$tbl = $tbl.name)";
        }
    }
    my @keys = keys %{$attributes};
    $statement .= " WHERE " unless ( $attributes->isEmpty );
    my $i = 0;
    while ( my ( $key, $value ) = each %{$attributes} ) {
        my $j   = 0;
        my @tmp = makeArray($value);
        $statement .= "( " if ( $#tmp > 0 );
        foreach my $tvalue (@tmp) {

#EXCEPTIONS
# Here we would insert special code to look up in another table
#        ( $tvalue, $key ) = getFieldFromDB( "name", "component", "description", $tvalue, "component" ) if ( $key eq "component" );
#EXCEPTIONS
# Should there be special handling for keywords (e.g., recognize full
# keywords only from a list of keywords?
            if ( $key eq "summary" ) {
                $statement .= "$table.$key GLOB '*$tvalue*' ";
            }
            elsif ( $key eq "description" ) {
                $statement .= "$table.$key GLOB '*$tvalue*' ";
            }
            elsif ( $key eq "keyword" ) {

                #Should we isolate single keywords?
                $statement .= "$table.key GLOB '*$tvalue*' ";
            }
            else {
                $statement .= "$table.$key = '$tvalue' ";
            }
            $statement .= "OR " if ( ( $j >= 0 ) && ( $j < $#tmp ) );
            $j++;
        }
        $statement .= ") " if ( $#tmp > 0 );
        $statement .= "AND " if ( ( $i >= 0 ) && ( $i < $#keys ) );
        $i++;
    }
    &TWiki::Func::writeDebug("statement = $statement") if $debug;
    my $tmp = $sqldb->prepare($statement);
    return unless $tmp;
    $tmp->execute();
    my @res = ();
    while ( my $r = $tmp->fetchrow_hashref ) {
        push @res, $r;
    }
    $tmp->finish;
    return \@res;

}

sub formatResult {

    my ( $res, $format, $theSeparator, $newLine ) = @_;

    my $mixedAlpha = $TWiki::regex{mixedAlpha};
    my $numeric    = $TWiki::regex{numeric};
    if ($theSeparator) {
        $theSeparator =~ s/\$n\(\)/\n/gos;    # expand "$n()" to new line
        $theSeparator =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos;
    }
    if ($newLine) {
        $newLine =~ s/\$n\(\)/\n/gos;                # expand "$n()" to new line
        $newLine =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos;
    }
    else {
        $newLine = '%BR%';
    }

    my $result = '';
    foreach my $r ( @{$res} ) {
        my $row = $format;

        $row =~
s/\$milestonetotalhours/getCustomFieldSum('totalhours','milestone',getField($r,'name'))/geo;
        $row =~
s/\$milestoneestimatedhours/getCustomFieldSum('estimatedhours','milestone',getField($r,'name'))/geo;

        $row = TWiki::expandStandardEscapes($row);

        $row =~
s/\$([$mixedAlpha]+)\.([$mixedAlpha]+)\(\s*([^\)]*)\s*\)/breakName(getField($r,$1,$2), $3)/geo;
        $row =~ s/\$([$mixedAlpha]+)\.([$mixedAlpha]+)/getField($r,$1,$2)/geo;
        $row =~
s/\$([$mixedAlpha]+)\(\s*([^\)]*)\s*\)/breakName(getField($r,$1), $2)/geo;
        $row =~ s/\$([$mixedAlpha]+)/getField($r,$1)/geo;

        $row =~ s/\r?\n/$newLine/gos;
        if ($theSeparator) {
            $row .= $theSeparator;
        }
        else {
            $row =~ s/([^\n])$/$1\n/os;    # add new line at end if needed
        }
        $row = TWiki::expandStandardEscapes($row);

        $result .= $row;
    }

    return $result;

}

sub breakName {
    my ( $text, $args ) = @_;
    $text = TWiki::Render::breakName( $text, $args ) if $args;
    return $text;
}

sub getField {
    my ( $row, $fld, $fld2 ) = @_;
    my $field = $fld2 || $fld;
    $fld = "${fld}_$fld2" if $fld2;
    my $value = $$row{$fld};
    $value ||= '';
    $value = TWiki::Time::formatTime($value)
      if ( $field eq 'time'
        || $field eq 'changetime'
        || $field eq 'due'
        || $field eq 'completed' )
      && $value;

    return $value;
}

sub getCustomFieldAggregate {
    my ( $func, $field, $key, $value ) = @_;
    my $sqldb = openDB( \%db );
    my $statement =
"SELECT $func(c1.value) FROM ticket LEFT OUTER JOIN ticket_custom c1 ON (ticket.id = c1.ticket AND c1.name = '$field') WHERE $key='$value'";
    my $tmp = $sqldb->prepare($statement);
    $tmp->execute();
    my @row = $tmp->fetchrow_array();
    $tmp->finish;
    return $row[0] || '';
}

sub handleSumQuery {
    shift @_;
    return handleAggregateQuery( 'SUM', @_ );
}

sub handleMaxQuery {
    shift @_;
    return handleAggregateQuery( 'MAX', @_ );
}

sub handleMinQuery {
    shift @_;
    return handleAggregateQuery( 'MIN', @_ );
}

sub handleCountQuery {
    shift @_;
    return handleAggregateQuery( 'COUNT', @_ );
}

sub handleAvgQuery {
    shift @_;
    return handleAggregateQuery( 'AVG', @_ );
}

sub handleAggregateQuery {
    my ( $func, $attributes, $topic, $web ) = @_;

    $attributes->remove($TWiki::Attrs::RAWKEY);
    my $what  = $attributes->remove("_DEFAULT") || return '';
    my $key   = ( keys(%$attributes) )[0]       || return '';
    my $value = $attributes->{$key}             || return '';

    my $result = getCustomFieldAggregate( $func, $what, $key, $value );

    return $result;

}

sub getFieldFromDB {
    my ( $what, $table, $field, $value, $key ) = @_;
    my $sqldb     = openDB( \%db );
    my $statement = "SELECT $what FROM $table WHERE $field = '$value'";
    my $tmp       = $sqldb->prepare($statement);
    $tmp->execute();
    my @row = $tmp->fetchrow_array();
    $tmp->finish;
    return ( $row[0], $key );
}

sub openDB {

    my ($this) = @_;

    unless ( defined( $this->{DB} ) ) {
        if ( $dbType eq 'sqlite' ) {
            $this->{DB} =
              DBI->connect( "dbi:SQLite:dbname=$dbName", $dbUser, $dbPasswd,
                { PrintError => 1, RaiseError => 0 } );
        }
        elsif ( $dbType eq 'mysql' ) {
            my $host = '';
            $host .= ";host=$dbHost" if ( $dbHost ne '' );
            $host .= ";port=$dbPort" if ( $dbPort ne '' );
            $this->{DB} =
              DBI->connect( "DBI:mysql:$dbName$host", $dbUser, $dbPasswd,
                { PrintError => 1, RaiseError => 0 } );
        }
    }
    ## TW: should we test for failure to connect to db?
    return $this->{DB};

}

sub makeArray {
    my ($str) = @_;
    $str =~ s/\s//g;
    return split( /,/, $str );
}

sub completePageHandler {

    #my($html, $httpHeaders) = @_;
    # modify $_[0] or $_[1] if you must change the HTML or headers

    # Close the data base
    $db{DB}->disconnect if defined( $db{DB} );
    $db{DB} = undef;

}

1;
