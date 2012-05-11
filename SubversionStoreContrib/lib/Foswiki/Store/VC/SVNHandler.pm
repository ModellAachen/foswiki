# See bottom of file for license and copyright information

# Equivalent of RcsWrap and RcsLite for a subversion checkout area
package Foswiki::Store::VC::SVNHandler;
use Foswiki::Store::VC::Handler;
our @ISA = qw( Foswiki::Store::VC::Handler );

use strict;
use Assert;

require File::Spec;

require Foswiki::Sandbox;

# Make any missing paths on the way to this file
sub mkPathTo {
    my ( $this, $file ) = @_;

    my @components = split( /(\/+)/, $file );
    pop(@components);
    my $path = '';
    for my $dir (@components) {
        if ( $dir =~ /\/+/ ) {
            $path .= '/';
        }
        elsif ($path) {
            if ( !-e "$path$dir" && -e "$path/.svn" ) {
                my ( $output, $exit ) = Foswiki::Sandbox->sysCommand(
                    $Foswiki::cfg{SubversionContrib}{svnCommand}
                      . ' mkdir %FILENAME|F%',
                    FILENAME => $path . $dir
                );
                if ($exit) {
                    throw Error::Simple(
                        "SVN: mkdir $path $dir failed: $! $output");
                }
            }
            $path .= $dir;
        }
    }
}

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    undef $this->{rcsFile};
    return $this;
}

# Override VC::Handler
sub init {
    my $this = shift;

    return unless $this->{topic};

    unless ( -e $this->{file} ) {
        $this->mkPathTo( $this->{file} );

        unless ( open( F, '>' . $this->{file} ) ) {
            throw Error::Simple("SVN: add $this->{file} failed: $!");
        }
        close(F);

        my ( $output, $exit ) = Foswiki::Sandbox->sysCommand(
            $Foswiki::cfg{SubversionContrib}{svnCommand} . ' add %FILENAME|F%',
            FILENAME => $this->{file}
        );
        if ($exit) {
            throw Error::Simple("SVN: add $this->{file} failed: $! $output");
        }
    }
}

sub _info {
    my ( $this, $version ) = @_;
    $version = ( defined $version ) ? "-r $version" : '';
    my ( $info, $exit ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{SubversionContrib}{svnCommand}
          . " info $version %FILENAME|F%",

        FILENAME => $this->{file}
    );
    if ($exit) {
        throw Error::Simple( "SVN: info $version $this->{file} failed: $! $info"
              . join( ' ', caller ) );
    }
    my @info;
    foreach my $line ( split( /\r?\n/, $info ) ) {
        if ( $line =~ /^([\w ]+): (.*)$/ ) {
            push( @info, $1 );
            my $v = _fixTime($2);
            push( @info, $v );
        }
    }
    return @info;
}

sub _fixTime {
    my $v = shift;
    if ( $v =~ /^(\d[-\d]+) (\d[\d:]+) (?:([-+]\d\d)(\d\d)) \(.*\)$/ ) {
        my $d = $1 . 'T' . $2;
        $d .= "$3:$4" if defined $3;
        $v = Foswiki::Time::parseTime($d);
    }
    return $v;
}

# Override VC::Handler
sub getInfo {
    my ( $this, $version ) = @_;
    return $this->SUPER::getInfo() unless -e $this->{file};
    my %info = $this->_info($version);
    return {
        version => $info{'Revision'}          || 1,
        date    => $info{'Last Changed Date'} || 0,
        author  => $info{'Last Changed Author'},
        comment => ''    # Could recover comment from the log
    };
}

# Override VC::Handler
sub getRevisionHistory {
    my $this = shift;
    if ( -e $this->{file} ) {
        my ( $output, $exit ) = Foswiki::Sandbox->sysCommand(
            $Foswiki::cfg{SubversionContrib}{svnCommand} . ' log %FILE|F%',
            FILE => $this->{file} );
        if ($exit) {
            throw Error::Simple("SVN: log $this->{file} failed: $! $output");
        }
        my @revs;
        foreach my $rev ( split( /\r?\n/, $output ) ) {
            if ( $rev =~ /^r(\d+)\s\|\s([^|]+)\s\|\s([^|]+)\s\|/ ) {
                my $id   = $1;
                my $who  = $2;
                my $when = _fixTime($3);
                push( @revs, $id );
            }
        }
        return new Foswiki::ListIterator( \@revs );
    }
    return new Foswiki::ListIterator( [] );
}

sub getLatestRevisionID {
    my $this = shift;
    my $rev;
    eval {
        my %info = $this->_info();
        $rev = $info{Revision};
    };
    if ($@) {
        print STDERR $@;
    }
    return $rev;
}

sub getNextRevisionID {
    my $this = shift;
    my $f    = $this->{file};
    if ( !-d $f ) {
        $f =~ s#/+[^/]*$##;
    }
    my ( $output, $exit ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{SubversionContrib}{svnCommand} . ' log -r HEAD %DIR|F%',
        DIR => $f );
    if ($exit) {
        throw Error::Simple("SVN: log -r HEAD failed: $! $output");
    }
    if ( $output =~ /^r(\d+)\s*\|/m ) {
        return $1 + 1;
    }

    # Might not
    throw Error::Simple(`svn log -r HEAD`);
}

sub getLatestRevisionTime {
    my $this = shift;

    return 0 unless -e $this->{file};
    my %info = $this->_info();
    return $info{'Last Changed Date'};
}

# Override VC::Handler
sub revisionExists {
    my ( $this, $id ) = @_;
    return 0 unless defined $id;
    my ( $output, $exit ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{SubversionContrib}{svnCommand} . ' log %FILE|F%',
        FILE => $this->{file} );
    if ($exit) {
        throw Error::Simple("SVN: log $this->{file} failed: $! $output");
    }
    return ( $output =~ /^r$id / );
}

# Override VC::Handler
sub getRevision {
    my ( $this, $version ) = @_;
    return $this->SUPER::getRevision()
      unless defined $version
          && -e $this->{file};

    my ( $output, $exit ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{SubversionContrib}{svnCommand}
          . " cat -r %VERSION|U% %FILE|F%",
        VERSION => $version,
        FILE    => $this->{file}
    );
    if ($exit) {
        throw Error::Simple(
            "SVN: cat -r$version $this->{file} failed: $! $output");
    }
    return $output;
}

# Override VC::Handler
sub restoreLatestRevision {
    my $this = shift;

    my ( $output, $exit ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{SubversionContrib}{svnCommand} . ' revert %FILE|F%',
        FILE => $this->{file} );
    if ($exit) {
        throw Error::Simple("SVN: revert $this->{file} failed: $! $output");
    }
}

sub remove {
    my $this = shift;

    my ( $output, $exit ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{SubversionContrib}{svnCommand}
          . ' rm -m %COMMENT|U% %FILE|F%',
        COMMENT => '',
        FILE    => $this->{file}
    );
    if ($exit) {
        throw Error::Simple("SVN: rm $this->{file} failed: $! $output");
    }
}

sub copyFile {
    my ( $this, $from, $to ) = @_;

    $this->mkPathTo($to);

    my ( $output, $exit ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{SubversionContrib}{svnCommand} . ' cp %FROM|F% %TO|F%',
        FROM => $from,
        TO   => $to
    );
    if ($exit) {
        throw Error::Simple("SVN: copy $from $to failed: $! $output");
    }
}

sub moveFile {
    my ( $this, $from, $to ) = @_;

    $this->mkPathTo($to);
    my ( $output, $exit ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{SubversionContrib}{svnCommand} . ' mv %FROM|F% %TO|F%',
        FROM => $from,
        TO   => $to
    );
    if ($exit) {
        throw Error::Simple("SVN: move $from $to failed: $! $output");
    }
}

sub addRevisionFromText {
    my ( $this, $text, $comment, $user, $date ) = @_;
    $this->init();

    $this->saveFile( $this->{file}, $text );
    my ( $output, $exit ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{SubversionContrib}{svnCommand}
          . " commit -m %COMMENT|U% %FILE|F%",
        COMMENT => $comment,
        FILE    => $this->{file}
    );
    if ($exit) {
        throw Error::Simple("SVN: commit $this->{file} failed: $! $output");
    }
}

sub addRevisionFromStream {
    my ( $this, $stream, $comment, $user, $date ) = @_;
    $this->init();

    $this->saveStream($stream);
    my ( $output, $exit ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{SubversionContrib}{svnCommand}
          . " commit -m %COMMENT|U% %FILE|F%",
        COMMENT => $comment,
        FILE    => $this->{file}
    );
    if ($exit) {
        throw Error::Simple("SVN: commit $this->{file} failed: $! $output");
    }
}

sub replaceRevision {
    throw Error::Simple("Not implemented");
}

sub deleteRevision {
    throw Error::Simple("Not implemented");
}

sub revisionDiff {
    my ( $this, $rev1, $rev2, $contextLines ) = @_;

    my $ft = "$rev1:$rev2";
    $ft = $rev2 if ( $rev1 eq 'WORKING' );
    $ft = $rev1 if ( $rev2 eq 'WORKING' );

    if ( $rev1 == $rev2 || $ft eq 'WORKING' ) {
        return [];
    }

    my ( $output, $exit ) = Foswiki::Sandbox->sysCommand(
        $Foswiki::cfg{SubversionContrib}{svnCommand}
          . ' diff -r %FT|U% --non-interactive %FILE|F%',
        FT   => $ft,
        FILE => $this->{file}
    );
    if ($exit) {
        throw Error::Simple("SVN: diff failed: $! $output");
    }
    $output =~ s/\nProperty changes on:.*$//s;
    require Foswiki::Store::RcsWrap;
    return Foswiki::Store::RcsWrap::parseRevisionDiff( "---\n" . $output );
}

sub getRevisionAtTime {
    my ( $this, $date ) = @_;
    my %info =
      $this->_info( '{' . Foswiki::FormatTime( $date, '$http' ) . '}' );
    return $info{'Revision'};
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (C) 2008-2010 Foswiki Contributors
Foswiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this file
as follows:
Copyright (C) 2005-2007 TWiki Contributors.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
