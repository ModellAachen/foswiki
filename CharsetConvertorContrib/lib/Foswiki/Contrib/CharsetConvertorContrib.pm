# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Contrib::CharsetConvertorContrib

Static charset converter. Converts the character set used in a Foswiki
DB to UTF8.

ONLY FOR USE ON RCS STORES (RcsWrap, RcsLite)

=cut

package Foswiki::Contrib::CharsetConvertorContrib;

# Always use strict to enforce variable scoping
use strict;
use warnings;
use File::Copy;

our $VERSION = '$Rev: 11239 $';
our $RELEASE = '1.0.0';
our $SHORTDESCRIPTION =
  'Convert entire Foswiki RCS databases from one character set to another';

our $options;
our $session;

sub report {
    return if $options->{-q};
    print STDERR join( ' ', @_ ) . "\n";
}

sub error {
    if ( $options->{-a} ) {
        die join( ' ', @_ );
    }
    else {
        print STDERR join( ' ', @_ );
    }
}

# Convert a byte string encoded in the {Site}{CharSet} to a byte string encoded in utf8
# Return 1 if a conversion happened, 0 otherwise
sub _convert {
    my $old = $_[0];

# Convert octets encoded using site charset to unicode codepoints. Note that we use
# Encode::FB_HTMLCREF; this should be a nop as unicode can accomodate all characters.
    $_[0] =
      Encode::decode( $Foswiki::cfg{Site}{CharSet}, $_[0],
        Encode::FB_HTMLCREF );

# Convert the internal representation to utf-8 bytes. The utf8 flag is turned off
# on the resultant string.
    utf8::encode( $_[0] );

    return ( $_[0] ne $old ) ? 1 : 0;
}

sub _rename {
    my ( $from, $to ) = @_;
    my $uto = $to;
    utf8::decode($uto);
    report "Move $uto";
    return if ( $options->{-i} );
    File::Copy::move( $from, $to )
      || error "Failed to rename $uto: $!";
}

=begin TML

---++ StaticMethod convertCollection($collection)

Given the name of a collection (/ separated web name or empty string for the root) convert
the topics and filenames in that collection to a UTF8 namespace.

=cut

sub convertCollection {
    my ( $collection, %args ) = @_;

    $options = \%args;

    # Must do this before we construct the session object, otherwise the store
    # cache gets populated with Wrap handlers
    $Foswiki::cfg{Store}{Implementation} = 'Foswiki::Store::RcsLite';
    $session = new Foswiki();

# First we rename all webs and files as necessary by calling the recursive collection
# rename on the root web
    foreach my $tree ( $Foswiki::cfg{DataDir}, $Foswiki::cfg{PubDir} ) {
        _rename_collection( $tree, $collection );
    }

    # All file and directory names should now be utf8

    # Now we convert the content of topics
    _convert_topics_contents($collection);

    # And that's it!

    $session->finish();
}

# Rename a web and all it's contents if necessary
sub _rename_collection {
    my ( $tree, $web ) = @_;
    my $dir;

    my $webpath = $tree . '/' . $web . '/';
    next unless -d $webpath;
    my %rename;
    my @subcoll;
    opendir( $dir, $webpath ) || die "Failed to open '$webpath' $!";
    foreach my $e ( readdir($dir) ) {
        next if $e =~ /^\./;
        my $ne = $e;
        if ( _convert($ne) ) {
            $rename{ $webpath . $e } = $webpath . $ne;
        }
        if ( -d $webpath . $e ) {
            push( @subcoll, $web ? $web . '/' . $ne : $ne );
        }
    }
    closedir($dir);
    while ( my ( $old, $new ) = each %rename ) {
        _rename( $old, $new );
    }
    foreach $dir (@subcoll) {
        _rename_collection( $tree, $dir );
    }
}

# Convert the contents (*not* the name) of a topic
# The history conversion is done by loading the topic into RCSLite and performing the
# charset conversion on the fields.
sub _convert_topic {
    my ( $web, $topic ) = @_;
    my $converted = 0;

    # Convert .txt,v
    my $handler =
      Foswiki::Store::VC::RcsLiteHandler->new( $session->{store}, $web,
        $topic );
    my $uh = "$web.$topic";
    utf8::decode($uh);

    eval { $handler->_ensureProcessed(); };
    if ($@) {
        error "Aborted processing of $uh history: $@\n";
    }
    elsif ( $handler->{state} ne 'nocommav' ) {

        # need to convert fields
        foreach my $rev ( @{ $handler->{revs} } ) {
            $converted += _convert( $rev->{text} ) if defined $rev->{text};
            $converted += _convert( $rev->{log} )  if defined $rev->{log};
            $converted += _convert( $rev->{comment} )
              if defined $rev->{comment};
            $converted += _convert( $rev->{desc} )   if defined $rev->{desc};
            $converted += _convert( $rev->{author} ) if defined $rev->{author};
        }
        if ($converted) {
            report "Converted history of $uh ($converted changes)";
            unless ( $options->{-i} ) {
                eval { $handler->_writeMe(); };
                if ($@) {
                    error
"Failed to write $uh history. Existing history may be corrupt: $@";
                }
            }
        }
    }

    # Convert .txt
    my $raw = $handler->readFile( $handler->{file} );
    $converted = _convert($raw);
    if ($converted) {
        report "Converted content of $uh";
        $handler->saveFile( $handler->{file}, $raw ) unless $options->{-i};
    }
}

# Convert the contents (*not* the names) of topics found in a web dir
sub _convert_topics_contents {
    my $web = shift;
    my $dir;

    opendir( $dir, "$Foswiki::cfg{DataDir}/$web" )
      || die "Failed to open '$web' $!";
    foreach my $e ( readdir($dir) ) {
        next if $e =~ /^\./;
        if ( $web && $e =~ /^(.*)\.txt$/ ) {
            _convert_topic( $web, $1 );
        }
        elsif (-d "$Foswiki::cfg{DataDir}/$web/$e"
            && -e "$Foswiki::cfg{DataDir}/$web/$e/WebPreferences.txt" )
        {
            _convert_topics_contents( $web ? "$web/$e" : $e );
        }
    }
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: CrawfordCurrie

Copyright (C) 2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
