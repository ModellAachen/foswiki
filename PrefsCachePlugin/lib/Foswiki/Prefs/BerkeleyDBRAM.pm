# See bottom of file for license and copyright information
package Foswiki::Prefs::BerkeleyDBRAM;

use strict;

use Foswiki::Prefs::TopicRAM    ();
use Foswiki::Prefs::BaseBackend ();
use BerkeleyDB;

our @ISA = ('Foswiki::Prefs::TopicRAM');

use Error qw(:try);

our $env;
our $db;
our %db;
our $dumped;
our $refcnt = 0;

sub new {
    my ( $class, $topicObject ) = @_;

    my $this = bless( {}, 'Foswiki::Prefs::TopicRAM' );
    $this->{values}      = {};
    $this->{local}       = {};
    $this->{topicObject} = $topicObject;

    _initDB();

    # SMELL: This really, really needs locking
    my $uid = $db{ $topicObject->getPath() };
    if ( !defined $uid ) {

        # Parse the topic into this object
        require Foswiki::Prefs::Parser;
        Foswiki::Prefs::Parser::parse( $topicObject, $this );

        # Transfer values into the DB for next time
        my $lock = $db->cds_lock();
        my $uid  = ++$db{UID};
        $db{ $topicObject->getPath() } = $uid;
        while ( my ( $k, $v ) = each %{ $this->{values} } ) {
            $db{"${uid}V$k"} = $v;
        }
        $db{"${uid}_V"} = join( ',', keys %{ $this->{values} } );
        while ( my ( $k, $v ) = each %{ $this->{local} } ) {
            $db{"${uid}L$k"} = $v;
        }
        $db{"${uid}_L"} = join( ',', keys %{ $this->{local} } );
        $db->db_sync();
        $lock->cds_unlock();
    }
    else {

        # Load from the DB
        foreach my $k ( split( ",", $db{"${uid}_V"} || '' ) ) {
            $this->{values}{$k} = $db{"${uid}V$k"};
        }
        foreach my $k ( split( ",", $db{"${uid}_L"} || '' ) ) {
            $this->{local}{$k} = $db{"${uid}L$k"};
        }
    }
    $refcnt++;

    return $this;
}

sub finish {
    my $this = shift;

    $this->SUPER::finish();
    if ( $db && --$refcnt <= 0 ) {
        $db->db_close();
        $db = undef;
    }
}

# Clean out the given topic from the DB; used when the topic
# is changed
sub invalidate {
    my ($topicObject) = @_;

    _initDB();
    my $uid = $db{ $topicObject->getPath() };
    return unless ( defined $uid );
    delete $db{ $topicObject->getPath() };
    foreach my $k ( split( ",", $db{"${uid}_V"} || '' ) ) {
        delete $db{"${uid}V$k"};
    }
    foreach my $k ( split( ",", $db{"${uid}_L"} || '' ) ) {
        delete $db{"${uid}L$k"};
    }
    delete $db{"${uid}_V"};
    delete $db{"${uid}_L"};
    $db->db_sync();
    $db->cds_unlock();
}

sub _initDB {
    unless ($db) {
        my $dbfile = $Foswiki::cfg{Store}{BackendBDB};
        unless ( -d $dbfile ) {
            mkdir($dbfile) || die "Failed to make $dbfile for prefs DB: $!";
        }
        $env = new BerkeleyDB::Env(
            -Home  => $dbfile,
            -Flags => DB_CREATE | DB_INIT_CDB | DB_INIT_MPOOL
        ) || die "cannot open prefs DB environment: $BerkeleyDB::Error\n";
        $db = tie(
            %db, 'BerkeleyDB::Hash',
            -Filename => $dbfile . '/DB',
            -Flags    => DB_CREATE,
            -Env      => $env
        );
        die "cannot open prefs DB: $BerkeleyDB::Error" unless $db;
    }
}

1;
__DATA__

Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
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
