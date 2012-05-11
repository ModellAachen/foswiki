# Contrib for Foswiki Collaboration Platform, http://foswiki.org/
#
# Copyright 2008, Sven Dowideit, SvenDowideit@fosiki.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Contrib::DbiContrib;
use strict;
use warnings;

use DBI;
use Error qw( :try );
use Assert;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $pluginName $DB_instance);

$VERSION    = '$Rev: 0 (2009) $';
$pluginName = 'DbiContrib';
$RELEASE    = '1.0.2';
$SHORTDESCRIPTION =
  'API for other Contribs and plugins to use to abstract Database accesses';

# class to use to get connection to db, and to run queries.
###############################################################################

=pod

---++ ClassMethod new($options ) -> $object

=cut

sub new {
    my ( $class, $options ) = @_;

    my $this = bless( {}, $class );

    $this->{dsn} = $options->{dsn} || $Foswiki::cfg{DbiContrib}{DBI_dsn};
    $this->{dsn_user} = $options->{dsn_user}
      || $Foswiki::cfg{DbiContrib}{DBI_username};
    $this->{dsn_password} = $options->{dsn_password}
      || $Foswiki::cfg{DbiContrib}{DBI_password};

    $options->{AutoCommit} = 0 if ( $this->{dsn} =~ /:mysql:/ );
    $options->{RaiseError} = 1;

#  $options->{Profile} = 5;       #will output scads of profiling into your error log

    $this->{dsn_options} = $options;
    $this->{Results}     = {};

    return $this;
}

=pod

---++ ObjectMethod finish()
Break circular references.

Note to developers; please undef *all* fields in the object explicitly,
whether they are references or not. That way this method is "golden
documentation" of the live fields in the object.

=cut

sub finish {
    my $this = shift;
    $this->disconnect();
    undef $this->{DB};

    $this->{Results} = {};
    undef $this->{Results};

    return;
}

=pod

---++ connect() 
returns a DBI handle to a connection

used internally, and can be used to get direct access to DBI

=cut

sub connect {
    my $this = shift;

    return $this->{DB} if ( defined( $this->{DB} ) );

    $this->{DB} = DBI->connect_cached(
        $this->{dsn},          $this->{dsn_user},
        $this->{dsn_password}, $this->{dsn_options}
    );
    if ( !$this->{DB} ) {
        print STDERR "Cannot connect: $DBI::errstr \n\n"
          . join( '___',
            ( $this->{dsn}, $this->{dsn_user}, $this->{dsn_password} ) );
        return;
    }

    return $this->{DB};
}

sub commit {
    my $this = shift;
    if ( defined( $this->{DB} ) ) {
        $this->{DB}->commit();
    }
    return;
}

sub disconnect {
    my $this = shift;
    if ( defined( $this->{DB} ) ) {
        $this->commit();
        $this->{DB}->disconnect();
        undef $this->{DB};
    }
    return;
}

#returns an ref to an array dataset of rows (NOT a hash)
#dbSelect(query, @list of params to query)
#DEPRECATED
sub dbSelect {
    my $this   = shift;
    my $query  = shift;
    my @params = @_;

    my $key = "$query : " . join( '-', @params );

    #print STDERR "getHashRef($key)\n";
    #is it cached in memory?
    return $this->{Results}{$key}
      if ( defined( $this->{Results}{$key} ) );

    my $dbh = $this->connect();
    try {
        my $sth = $dbh->prepare($query);
        $sth->execute(@params);
        my $array_ref = $sth->fetchall_arrayref();

        #use Data::Dumper;
        #    print STDERR "cached: ".Dumper($hash_ref)."\n";
        #return  $array_ref;

        $this->{Results}{$key} = $array_ref
          if ( defined( $array_ref->[0][0] ) );
    }
    catch Error::Simple with {
        $this->{error} = $!;
        print STDERR "            ERROR: fetch_select($key) : $! : ("
          ;    # . $dbh->errstr . ')';

        #$this->{session}->writeWarning("ERROR: fetch_select($key) : $!");
        my @array = ();
        $this->{Results}{$key} = \@array;
    };
    return $this->{Results}{$key};
}

#returns a ref to an array of refs to hashs - indexed by column name
sub select {
    my $this   = shift;
    my $query  = shift;
    my @params = @_;

    ASSERT($query);

#sorry, not all select statements have params.... select name from grouplist....
#ASSERT(@params);

    my $key = "$query : " . join( '-', @params );

    #print STDERR "getHashRef($key)\n";
    #is it cached in memory?
    return $this->{Results}{$key}
      if ( defined( $this->{Results}{$key} ) );

    my $dbh = $this->connect();
    try {
        my $sth = $dbh->prepare($query);
        $sth->execute(@params);

        #return a ref to an array containing refs to hashes
        my $array_ref = $sth->fetchall_arrayref( {} );

        #use Data::Dumper;
        #print STDERR "cached: ".Dumper($array_ref)."\n";
        #return $array_ref;

        $this->{Results}{$key} = $array_ref
          if ( defined( $array_ref->[0] ) );
    }
    catch Error::Simple with {
        $this->{error} = $!;

        #print STDERR "            ERROR: fetch_select($key) : $! : ("
        #   . $dbh->err .' : '. $dbh->errstr . ')';

        #$this->{session}->writeWarning("ERROR: fetch_select($key) : $!");
        my @array = ();
        $this->{Results}{$key} = \@array;
    };
    return $this->{Results}{$key};
}

#dbReplace(query, @list of params to query)
#replace or insert
#DEPRECATED
sub dbInsert {
    my $this   = shift;
    my $query  = shift;
    my @params = @_;
    my $rows   = 0;

    my $dbh = $this->connect();
    try {
        $rows = $dbh->do( $query, undef, @params );
    }
    catch Error::Simple with {
        $this->{error} = $!;
        my $key = "$query : " . join( '-', @params );
        print STDERR
          "            ERROR: do($key) : $! : (";    # . $dbh->errstr . ')';

        #$this->{session}->writeWarning("ERROR: do($key) : $!");
    };
    return $rows;
}

sub dbDelete {
    return dbInsert(@_);
}

1;
