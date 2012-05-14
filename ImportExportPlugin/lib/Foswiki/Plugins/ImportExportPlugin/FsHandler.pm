# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::ImportExportPlugin::FsHandler

import/export from local filesystem handler

=cut

package Foswiki::Plugins::ImportExportPlugin::FsHandler;

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

---++ ClassMethod import(  ) -> $status text

=cut

#TODO: ffs, crawford these
my @webs;
my %files;

sub import {
    my $this = shift;

    my $fspath =
      Foswiki::Sandbox::untaintUnchecked( $this->{cgi}->{param}->{fspath}[0] );
    my $importFrom =
      Foswiki::Sandbox::untaintUnchecked( $this->{cgi}->{param}->{importFrom}[0]
          || 'wiki' );
    print STDERR "   1 $fspath\n";
    print STDERR "   2 $importFrom\n";
    my @output = ("import $importFrom from $fspath\n<hr>\n");

    if ( $importFrom eq 'wiki' ) {

        #TODO: what if the source wiki has a customised WebPrefs setting?
        #TODO: what if the data and pub dirs are different
        #TODO: solve all these by using the wiki's cfg file.

        my $data = $fspath . '/data';
        my $pub  = $fspath . '/pub';

        File::Find::find(
            { wanted => \&findWebPrefs, untaint => 1, no_chdir => 1 }, $data );
        @webs = map {

            #do this here as we don't know $data in the wanted
            s/$data\///;
            s/\/WebPreferences\.txt//;
            $_
        } @webs;

        foreach my $web (@webs) {
            print STDERR "$web \n";

            #see if it exists - skip/merge
            my $destinationWebExists = -e $Foswiki::cfg{DataDir} . '/' . $web;

            #foreach topic, copy via filters
            %files = ();
            File::Find::find(
                {
                    wanted   => sub { findfiles($web) },
                    untaint  => 1,
                    no_chdir => 0
                },
                $data . "/$web"
            );
            if ( -e $pub . "/$web" ) {
                File::Find::find(
                    {
                        wanted   => sub { findAttachments($web) },
                        untaint  => 1,
                        no_chdir => 0
                    },
                    $pub . "/$web"
                );
            }

            foreach my $topic ( sort keys(%files) ) {
                print STDERR "   * $topic\n";
                my $text;
                if ( $files{$topic}{type} eq 'topic' ) {
                    $text =
                      Foswiki::Sandbox::untaintUnchecked(
                        Foswiki::Func::readFile( $files{$topic}{from} ) );
                }

                #filters can return 'skipweb','skip', text or 'nochange'
                my %filterOutput = (
                    result   => 'nochange',
                    web      => $web,
                    topic    => $files{$topic}{topic},
                    type     => $files{$topic}{type},
                    filename => $files{$topic}{filename},
                    text     => $text
                );
                foreach my $filter ( @{ $this->{filters} } ) {
                    %filterOutput = $filter->(%filterOutput);
                    if ( $filterOutput{result} eq 'skipweb' ) {
                        print STDERR "SKIPPING $filterOutput{web} web\n";
                        push( @output,
                            "   * __SKIPPING__ $filterOutput{web} web" );
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
                }
                next if ( $filterOutput{result} eq 'skip' );
                last if ( $filterOutput{result} eq 'skipweb' );
                if ($destinationWebExists) {

                    #maybe stop - can't really - for eg, importing into Main
                }
                else {
                    print STDERR "===== creating $web";
                    Foswiki::Func::createWeb( $web, '_default' );
                    $destinationWebExists = 1;
                }

#TODO: for eg, could grab _default version of WebHome if its just the twiki million rev release version
#TODO: if its a topic re-name, we need to use Func::moveTopic after everything is finished. else things get busted
#OR keep a list and then re-write all the topic text afterwards

                #TODO: what about twiki 'rcsDir' setting?
                my $destination;
                if ( $files{$topic}{type} eq 'topic' ) {
                    $destination =
                        $Foswiki::cfg{DataDir} . '/'
                      . $filterOutput{web} . '/'
                      . $filterOutput{topic} . '.'
                      . $files{$topic}{ext};
                    push( @output,
"   * !$web . !$topic => $filterOutput{web}.$filterOutput{topic}\n      * $filterOutput{result}"
                    );
                }
                else {
                    $destination =
                        $Foswiki::cfg{PubDir} . '/'
                      . $filterOutput{web} . '/'
                      . $filterOutput{topic} . '/'
                      . $filterOutput{filename};
                    mkdir( $Foswiki::cfg{PubDir} . '/' . $filterOutput{web} );
                    mkdir(  $Foswiki::cfg{PubDir} . '/'
                          . $filterOutput{web} . '/'
                          . $filterOutput{topic} );
                    push( @output,
                            "   * !$web . !$topic ("
                          . $filterOutput{filename}
                          . ") => $filterOutput{web}.$filterOutput{topic}\n      * $filterOutput{result}"
                    );
                }

 #print STDERR $files{$topic}{from} . ' -> ' . $destination."\n";
 #                push( @output, $files{$topic}{from} . ' -> ' . $destination );

                copy( $files{$topic}{from}, $destination );
                if ( -e $files{$topic}{from} . ',v' ) {
                    copy( $files{$topic}{from} . ',v', $destination . ',v' );
                    `rcs -u -M $destination,v`;
                }
                if ( $filterOutput{result} ne 'nochange' ) {
                    if ( $files{$topic}{type} eq 'topic' ) {

                        #commit the modified topic text
                        my $error = Foswiki::Func::saveTopicText(
                            $filterOutput{web}, $filterOutput{topic},
                            $filterOutput{text}, { forcenewrevision => 1 }
                        );
                        push( @output, $error ) if ($error);
                    }
                }
            }
        }
    }
    else {
        die "$importFrom not implemented yet";
    }

    return join( "<br>\n", ( @output, "\n<hr>\n" ) );

}

sub findWebPrefs {
    if ( $_ =~ /WebPreferences.txt$/ ) {
        push( @webs, Foswiki::Sandbox::untaintUnchecked($File::Find::name) );
    }
}

sub findfiles {

    #my $web = shift; #thought i needed this - can probly remove the crawfordin
    if ( $_ =~ /(.*)\.txt$/ ) {
        $files{ Foswiki::Sandbox::untaintUnchecked($1) } = {
            from     => Foswiki::Sandbox::untaintUnchecked($File::Find::name),
            type     => 'topic',
            topic    => $1,
            filename => Foswiki::Sandbox::untaintUnchecked($_),
            ext      => 'txt'
        };
    }
}

sub findAttachments {
    if ( -f $File::Find::name && not( $_ =~ /(.*),v$/ ) ) {

        my $file = Foswiki::Sandbox::untaintUnchecked($_);
        $File::Find::dir =~ /\/([^\/]*)$/;
        my $topic = $1;

        #print STDERR "found $topic / $file\n";
        $files{ $1 . '/' . $file } = {
            from     => Foswiki::Sandbox::untaintUnchecked($File::Find::name),
            type     => 'attachment',
            topic    => $topic,
            filename => $file,
        };
    }
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
