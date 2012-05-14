# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::ImportExportPlugin::FoswikiHandler

import/export from local filesystem handler

=cut

package Foswiki::Plugins::ImportExportPlugin::FoswikiHandler;

# Always use strict to enforce variable scoping
use strict;
use warnings;
use File::Copy;
use File::Find;
use Foswiki::Func;

=begin TML

---++ ClassMethod new( $class, $query, $filterlist ) -> $handler

=cut

sub new {
    my $class      = shift;
    my $query      = shift;
    my $filterlist = shift;

    my $this = bless( { cgi => $query, filters => $filterlist }, $class );
    return $this;
}

=begin TML

---++ ClassMethod check(  ) -> $status text

=cut

sub check {
    my $this = shift;

    my $webs =
      Foswiki::Sandbox::untaintUnchecked( $this->{cgi}->{param}->{webs}[0] );
    my @output = ("---++ checking $webs for broken or odd links \n<hr>\n");

    my @webs = split( /,\s*/, $webs );

    my %links;
    my %crashes;
    my %topiccount;
    my $brokenlink_topiccount = 0;

    foreach my $web (@webs) {
        print STDERR "$web \n";

        next unless ( Foswiki::Func::webExists($web) );

        my $webObject = Foswiki::Meta->new( $Foswiki::Plugins::SESSION, $web );

        #TODO: ew! there's no iterator version in Func
        my $topicItr = $webObject->eachTopic();
        my $count;
        while ( $topicItr->hasNext() ) {
            my $topic = $topicItr->next();
            $topiccount{$web}++;

            #            next unless ( $count++ < 5 );
            my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

            #filters can return 'skipweb','skip', text or 'nochange'
            my %filterOutput = (
                result => 'nochange',
                web    => $web,
                topic  => $topic,
                type   => 'topic',

                #filename => $files{$topic}{filename},
                text => $text
            );
            foreach my $filter ( @{ $this->{filters} } ) {
                %filterOutput = $filter->(%filterOutput);
                if ( $filterOutput{result} eq 'skipweb' ) {

                    #print STDERR "SKIPPING $filterOutput{web} web\n";
                    push( @output, "   * __SKIPPING__ $filterOutput{web} web" );
                    $web = '';
                    last;
                }
                if ( $filterOutput{result} eq 'skip' ) {

           #print STDERR "SKIPPING $filterOutput{web} , $filterOutput{topic}\n";
                    push( @output,
"   * __SKIPPING__ $filterOutput{web} . $filterOutput{topic}"
                    );
                    last;
                }
                if ( defined( $filterOutput{links} )
                    && ref( $filterOutput{links} ) eq 'ARRAY' )
                {
                    print STDERR "-- links: "
                      . join( ',', @{ $filterOutput{links} } ) . "\n";
                    map {
                        push(
                            @{ $links{$_} },
                            $filterOutput{web} . '.' . $filterOutput{topic}
                        );
                    } @{ $filterOutput{links} };
                }
            }
            next if ( $filterOutput{result} eq 'skip' );
            last if ( $filterOutput{result} eq 'skipweb' );
            if ( $filterOutput{result} eq 'crash' ) {
                push( @output,
"   1 [[$filterOutput{web}.$filterOutput{topic}][$filterOutput{web}, $filterOutput{topic}]]: %RED%__CRASHES__%ENDCOLOR% "
                );
                $crashes{"$filterOutput{web}.$filterOutput{topic}"} =
                  $filterOutput{crash};
                next;
            }

            #list of links for each topic
            if ( $filterOutput{result} ne 'nochange' ) {
                push( @output,
"   1 [[$filterOutput{web}.$filterOutput{topic}][$filterOutput{web}, $filterOutput{topic}]]: $filterOutput{result}"
                );
                $brokenlink_topiccount++;
            }

        }
    }

    push( @output, '---++ Summary of broken links and where they are used' );

    #list of links and how often they are used in that web
    my $linkCount = scalar( keys(%links) );
    push( @output,
        map { '   1 ' . $_ . ' : ' . join( ' , ', @{ $links{$_} } ) }
        sort( keys(%links) ) );

    ####summary
    push( @output, "\n<hr>\n" );
    push( @output, "number of broken links: $linkCount\n" );
    push( @output,
        "number of crashed topics: " . scalar( keys(%crashes) . "\n" ) );
    push( @output,
        "number of topics with broken links : $brokenlink_topiccount\n" );
    my $totaltopics = 0;
    push(
        @output,
        map {
            $totaltopics += $topiccount{$_};
            "topics in $_: " . $topiccount{$_} . "\n"
          } keys(%topiccount)
    );
    push( @output, "number of topics checked: $totaltopics\n" );
    push( @output, "\n" );
    push( @output, "\n" );
    push( @output, "\n" );
    push( @output, "\n<hr>\n" );

    return join( "<br>\n", ( @output, ) );

}

=begin TML

---++ ClassMethod finish(  ) 

=cut

sub finish {
    return 'finishing local resources';

}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: SvenDowideit

Copyright (C) 2012 SvenDowideit@fosiki.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
