#
# Copyright (C) 2007 Crawford Currie, http://c-dot.co.uk
#
package Foswiki::Contrib::DBCacheContrib::Archivist::Storable;
use strict;

use Foswiki::Contrib::DBCacheContrib::MemArchivist ();
our @ISA = ( 'Foswiki::Contrib::DBCacheContrib::MemArchivist' );

use Storable;

sub clear {
    my $this = shift;
    unlink( $this->{_file} );
    undef $this->{root};
}

sub DESTROY {
    my $this = shift;
    undef $this->{root};
}

sub sync {
    my $this = shift;

#my ($package, $filename, $line) = caller(2);
#print STDERR "called sync $this->{_file} from $package, $line\n";

    # Clear the archivist to avoid having pointers in the Storable
    $this->{root}->setArchivist(undef) if $this->{root};
    Storable::lock_store( $this->getRoot(), $this->{_file} );
    $this->{root}->setArchivist($this) if $this->{root};
}

sub getRoot {
    my ($this) = @_;
    unless ( $this->{root} ) {
        if ( -e $this->{_file} ) {
            $this->{root} = Storable::lock_retrieve( $this->{_file} );
            $this->{root}->setArchivist($this);
        }
        else {
            $this->{root} = $this->newMap();
        }
    }
    return $this->{root};
}

1;
