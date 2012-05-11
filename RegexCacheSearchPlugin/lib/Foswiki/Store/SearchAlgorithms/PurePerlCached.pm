# See bottom of file for license and copyright information

package Foswiki::Store::SearchAlgorithms::PurePerlCached;
use strict;

=begin TML

---+ package Foswiki::Store::SearchAlgorithms::PurePerlCached

Pure perl implementation of the RCS cache search with cached search results
using DB_File and Berkeley DB.



---++ search($searchString, $topics, $options, $sDir) -> \%seen
Search .txt files in $dir for $string. See RcsFile::searchInWebContent
for details.

=cut

use Foswiki::Func;
use DB_File;

# use Time::HiRes qw(gettimeofday tv_interval);  # Only needed to time search costs

sub search {
    my ( $searchString, $topics, $options, $sDir ) = @_;

    # my $start = [gettimeofday];  # For timing

    local $/ = "\n";
    my %seen;
    if ( $options->{type} && $options->{type} eq 'regex' ) {

        # Escape /, used as delimiter. This also blocks any attempt to use
        # the search string to execute programs on the server.
        $searchString =~ s!/!\\/!g;
    }
    else {

        # Escape non-word chars in search string for plain text search
        $searchString =~ s/(\W)/\\$1/g;
    }

    # Convert GNU grep \< \> syntax to \b
    $searchString =~ s/(?<!\\)\\[<>]/\\b/g;
    $searchString =~ s/^(.*)$/\\b$1\\b/go if $options->{'wordboundaries'};
    my $doMatch;
    if ( $options->{casesensitive} ) {
        $doMatch = sub { $_[0] =~ m/$searchString/ };
    }
    else {
        $doMatch = sub { $_[0] =~ m/$searchString/i };
    }

# I'd like to only open the DB once per view CGI mode. The open is not that expensive, except that
# we lose the cache if we open/close on every search (there can be many, even on a simple page).
#
# Greater benefit may be obtained in a persistent environment where the DB and cache are kept
# open across many page requests. However, I am not sure how to modify the code to allow this
# code to work in such an environment, e.g. mod_perl, mod_fastcgi
#
# Could I also use the supporting plugin to handle opening the DB? How, can I then pass thru
# the hash reference of the tied DB without using a global for our plugin.

    my $db_btree = new DB_File::BTREEINFO;
    $db_btree->{'cachesize'} = 4 * 1024 * 1024;

    my $workArea = Foswiki::Func::getWorkArea('RegexCachePlugin');
    my $workfile = $workArea . '/regex.db';

    my %cache;
    my $db = tie %cache, "DB_File", $workfile, O_RDWR | O_CREAT, 0666, $db_btree
      or die "Cannot open file '$workfile': $!\n";

    my @toScan;
    my $case  = $options->{casesensitive} ? " " : "i";
    my @dirs  = File::Spec->splitdir($sDir);
    my $web   = lc( $dirs[-2] ) . '\\';
    my $major = "\t" . $case . "\t" . $searchString;

    if ( $options->{files_without_match} ) {
      FILE1:
        for my $file (@$topics) {
            my $key = $web . lc($file) . $major;

            if ( $cache{$key} ) {
                my $line = $cache{$key};
                my $flag = substr( $line, 0, 1 );
                $line = substr( $line, 1 );

                if ( $flag eq 'Y' ) {
                    push( @{ $seen{$file} }, $line );
                }
            }
            else {
                push( @toScan, $file );
            }
        }
    }
    else {
      FILE2:
        for my $file (@$topics) {
            my $key = $web . lc($file) . $major;
            if ( $cache{$key} ) {
                my $line = $cache{$key};
                my $flag = substr( $line, 0, 1 );
                $line = substr( $line, 1 );

                if ( $flag eq 'Y' ) {
                    push( @toScan, $file );
                }
            }
            else {
                push( @toScan, $file );
            }
        }
    }

  FILE:
    for my $file (@toScan) {
        my $key = $web . lc($file) . $major;

        if ( !open( FILE, '<', "$sDir/$file.txt" ) ) {
            delete $cache{$key} if exists $cache{$key};
            next FILE;
        }

        my $cached = 0;

        while ( my $line = <FILE> ) {
            if ( &$doMatch($line) ) {
                chomp($line);
                push( @{ $seen{$file} }, $line )
                  ; # Return all matching lines to caller (unless $options->{files_without_match} see later)

                if ( !$cached )
                {    # But only update the cache with the first match
                    $cache{$key} = "Y" . $line;
                    $cached = 1;
                }
                if ( $options->{files_without_match} ) {
                    close(FILE);
                    next FILE;
                }
            }
        }
        if ( !$cached )
        { # If no line matched and hence cached, then hit the cache with a miss, so to speak
            $cache{$key} = "N";
        }
        close(FILE);
    }
    $db->sync();
    undef $db;
    untie %cache;

    # For timing:
    # my $int = tv_interval($start, [gettimeofday] );
    # print STDERR "Search Time = $int\n";
    return \%seen;
}

1;
__DATA__
#
# Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
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
# As per the GPL, removal of this notice is prohibited.
#
