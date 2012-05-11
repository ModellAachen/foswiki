#
# TWiki WikiClone ($wikiversion has version info)
#
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
# =========================
#
# This is the default TWiki plugin. Use EmptyPlugin.pm as a template
# for your own plugins; see %SYSTEMWEB%.Plugins for details.
#
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional.
# For increased performance, DISABLE handlers you don't need.

# =========================
package TWiki::Plugins::PollPlugin;

use strict;

# =========================
use vars qw( $web $topic $user $installWeb $VERSION $RELEASE );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

# collect all votes from the bottom of the topic (after the <!--TWikiPoll--> comment)
# just in case if the votes are in the same topic
    my ( undef, undef, $votes ) = split /<\!\-\-TWikiPoll\-\->/, $_[0];

    # hide the votes from normal view
    $_[0] =~ s/<\!\-\-TWikiPoll\-\->.*//gso;

    $_[0] =~ s/%POLLRESULTS%/&handlePollResults("",$votes)/geos;
    $_[0] =~ s/%POLLRESULTS{(.*?)}%/&handlePollResults($1,$votes)/geos;

}

# =========================
sub handlePollResults {
    my ( $attributes, $votes ) = @_;

    my %default = (
        id          => 'id0',    # id of the poll
        web         => $web,     # web containing the topic
        topic       => $topic,   # topic containing the data
        join        => 'on',     # on=join ex-aequo together
        exaequosep  => ', ',     # separator between ex-aequo (same-count votes)
        itemformat  => '$item',  # format of an item
        countformat => '$count', # format of a count
        percformat  => '$perc%', # format of a percentage
        lineformat => '|  $i{0}  |  $c{0} ($p{0})  |'
        ,                        # format of a line of the result table
        limit => 5,              # max number of rows
        header =>
          '| *The winners are* | *Votes* |',    # header of the result table
    );

    my $params = bless {};

    # read defaults from the plugin topic preferences
    foreach my $k ( keys %default ) {
        $params->{$k} =
             TWiki::Func::extractNameValuePair( $attributes, $k )
          || TWiki::Func::getPreferencesValue("POLLPLUGIN_\U$k\E")
          || $default{$k};
    }

    # get the votes if the topic is not this one
    if ( $web ne $params->{web} || $topic ne $params->{topic} ) {
        my $text =
          TWiki::Func::readTopicText( $params->{web}, $params->{topic} ) || "";

# collect all votes from the bottom of the topic (after the <!--TWikiPoll--> comment)
        ( undef, undef, $votes ) = split /<\!\-\-TWikiPoll\-\->/, $text;
    }

    # remove empty lines
    $votes =~ s/(\n|\r)+/\n/gso;

    # list votes
    my @lines = split /\n/, $votes;

    # select the lines with the given id
    # and keep only last user's vote
    my %voted = ();
    my ( $userid, $date, @items );
    my $id = $params->{id};
    foreach my $line ( grep { /^\s*\|\s*$id\s*\|\s*.*?\s*\|\s*$/ } @lines ) {
        ( undef, undef, $date, $userid, @items ) = split /\s*\|\s*/, $line;
        $voted{$userid} = [@items];
    }

    # count voted separately for each column (columns 1..)
    # and also collectively (column 0)
    #     * this way you allow for more than 1 preference
    my @counts  = ();    # count for each column and item
    my @totals  = ();    # total for each column
    my $columns = 0;
    my ( $items, $item );
    foreach $items ( values %voted ) {
        $columns = 1;
        foreach $item ( @{$items} ) {
            $counts[0]{$item}++;           # cumulative for each item (column 0)
            $totals[0]++;                  # cumulative overall total (column 0)
            $counts[$columns]{$item}++;    # count the item
            $totals[$columns]++;           # and the column total
            $columns++;
        }
    }

    # rank each column
    my @rank = ();
    for ( my $col = 0 ; $col < $columns ; $col++ ) {
        $rank[$col] = $params->rankVotes( $counts[$col] );
    }

    # generate the table
    my $str = "$params->{header}";
    my ( $col, $lf, $cf, $pf, $perc, $count );
    for ( my $row = 0 ; $row < $params->{limit} ; $row++ ) {
        $str .= "\n";
        $lf = "$params->{lineformat}";
        for ( $col = 0 ; $col < $columns ; $col++ ) {
            if ( defined( $rank[$col][$row] ) ) {
                ( $count, $items ) = @{ $rank[$col][$row] };
                $items = join( $params->{exaequosep}, @$items );
                $perc = sprintf( "%.2d", $count * 100 / $totals[$col] );
                $pf = "$params->{percformat}";
                $pf =~ s/\$perc/$perc/g;
                $cf = "$params->{countformat}";
                $cf =~ s/\$count/$count/g;
                $lf =~ s/\$i\{$col\}/$items/g;
                $lf =~ s/\$c\{$col\}/$cf/g;
                $lf =~ s/\$p\{$col\}/$pf/g;
            }
        }
        $lf =~ s/\$i\{.*?\}//g;
        $lf =~ s/\$c\{.*?\}//g;
        $lf =~ s/\$p\{.*?\}//g;
        $str .= "$lf";
    }

    return $str;
}

# =========================
#
sub rankVotes ($$) {
    my ( $self, $c ) = @_;
    my %counts = %$c;    # column of values to be counted
    my @column = ();     # resulting list of pairs [count,item]

    my ( $item, $count, $f, %exaequo );

    # join ex-aequo elements if required
    if ( $self->{join} eq 'on' ) {

        # we want to collect all the ex-equo items together
        while ( ( $item, $count ) = each %counts ) {
            $f = $self->{itemformat};
            $f =~ s/\$item/$item/g;
            if ( !defined( $exaequo{$count} ) ) {
                $exaequo{$count} = [];
            }
            push @{ $exaequo{$count} }, ($f);
        }

        # then sort the values
        my $i = 0;
        foreach $count ( reverse sort { $a <=> $b } keys %exaequo ) {
            $column[ $i++ ] = [ $count, $exaequo{$count} ];
        }
    }
    else {

        # we want just the values in reverse count order
        my $i = 0;

        # sort on the values
        foreach $item (
            reverse sort { $counts{$a} <=> $counts{$b} }
            keys %counts
          )
        {
            $column[$i] = [ $counts{$item}, [$item] ];
            $i++;
        }
    }

    return \@column;
}

1;

__END__

