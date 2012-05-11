package Confluence;
$VERSION = 2.1;

# Copyright (c) 2004 Asgeir.Nilsen@telenor.com
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use RPC::XML;
use RPC::XML::Client;
use Env qw(CONFLDEBUG);
use Carp;
use strict;
use vars '$AUTOLOAD';    # keep 'use strict' happy

our $API = 'confluence1';

use fields qw(url token client);

# Global variables
our $RaiseError = 1;
our $PrintError = 0;
our $LastError  = '';

# For debugging
sub _debugPrint {
    require Data::Dumper;
    $Data::Dumper::Terse     = 1;
    $Data::Dumper::Indent    = 0;
    $Data::Dumper::Quotekeys = 0;
    print STDERR ( shift @_ );
    print STDERR ( Data::Dumper::Dumper($_) . ( scalar @_ ? ', ' : '' ) )
      while ( $_ = shift @_ );
    print STDERR "\n";
}

sub setRaiseError {
    shift if ref $_[0];
    carp "setRaiseError expected scalar"
      unless defined $_[0] and not ref $_[0];
    my $old = $RaiseError;
    $RaiseError = $_[0];
    return $old;
}

sub setPrintError {
    shift if ref $_[0];
    carp "setPrintError expected scalar"
      unless defined $_[0] and not ref $_[0];
    my $old = $PrintError;
    $PrintError = $_[0];
    return $old;
}

sub lastError {
    return $LastError;
}

#  This function converts scalars to RPC::XML strings
sub argcopy {
    my ( $arg, $depth ) = @_;
    return $arg if $depth > 1;
    my $typ = ref $arg;
    if ( !$typ ) {
        if ( $arg =~ /true|false/ and $depth == 0 ) {
            return new RPC::XML::boolean($arg);
        }
        else { return new RPC::XML::string($arg); }
    }
    if ( $typ eq "HASH" ) {
        my %hash;
        foreach my $key ( keys %$arg ) {
            $hash{$key} = argcopy( $arg->{$key}, $depth + 1 );
        }
        return \%hash;
    }
    if ( $typ eq "ARRAY" ) {
        my @array = map { argcopy( $_, $depth + 1 ) } @$arg;
        return \@array;
    }
    return $arg;
}

sub new {
    my Confluence $self = shift;
    my ( $url, $user, $pass ) = @_;
    unless ( ref $self ) {
        $self = fields::new($self);
    }
    $self->{url} = shift;
    warn "Creating client connection to $url" if $CONFLDEBUG;
    $self->{client} = new RPC::XML::Client $url;
    warn "Logging in $user" if $CONFLDEBUG;
    my $result = $self->{client}->simple_request( "$API.login", $user, $pass );
    $LastError =
      defined($result)
      ? (
        ref($result) eq 'HASH'
        ? (
            exists $result->{faultString}
            ? "REMOTE ERROR: " . $result->{faultString}
            : ''
          )
        : ''
      )
      : "XML-RPC ERROR: Unable to connect to " . $self->{url};
    _debugPrint( "Result=", $result ) if $CONFLDEBUG;

    if ($LastError) {
        croak $LastError if $RaiseError;
        warn $LastError  if $PrintError;
    }
    $self->{token} = $LastError ? '' : $result;
    return $LastError ? '' : $self;
}

# login is an alias for new
sub login {
    return new @_;
}

sub updatePage {
    my Confluence $self = shift;
    my ($newPage)       = @_;
    my $saveRaise       = setRaiseError(0);
    my $result          = $self->storePage($newPage);
    setRaiseError($saveRaise);
    if ($LastError) {
        if ( $LastError =~ /already exists/ ) {
            my $oldPage =
              $self->getPage( $newPage->{space}, $newPage->{title} );
            $newPage->{id}      = $oldPage->{id};
            $newPage->{version} = $oldPage->{version};
            $result             = $self->storePage($newPage);
        }
        else {
            croak $LastError if $RaiseError;
            warn $LastError  if $PrintError;
        }
    }
    return $result;
}

sub _rpc {
    my Confluence $self = shift;
    my $method = shift;
    croak "ERROR: Not connected" unless $self->{token};
    my @args = map { argcopy( $_, 0 ) } @_;
    _debugPrint( "Sending $API.$method ", @args ) if $CONFLDEBUG;
    my $result =
      $self->{client}->simple_request( "$API.$method", $self->{token}, @args );
    $LastError =
      defined($result)
      ? (
        ref($result) eq 'HASH'
        ? (
            exists $result->{faultString}
            ? "REMOTE ERROR: " . $result->{faultString}
            : ''
          )
        : ''
      )
      : "XML-RPC ERROR: Unable to connect to " . $self->{url};
    _debugPrint( "Result=", $result ) if $CONFLDEBUG;

    if ($LastError) {
        croak $LastError if $RaiseError;
        warn $LastError  if $PrintError;
    }
    return $LastError ? '' : $result;
}

# Define commonly used functions to avoid overhead of autoload
sub getPage {
    my Confluence $self = shift;
    _rpc( $self, 'getPage', @_ );
}

sub storePage {
    my Confluence $self = shift;
    _rpc( $self, 'storePage', @_ );
}

sub exportSpace {
    my Confluence $self = shift;
    _rpc( $self, 'exportSpace', @_ );
}

sub exportSite {
    my Confluence $self = shift;
    _rpc( $self, 'exportSite', @_ );
}

# Use autolaod for everything else
sub AUTOLOAD {
    my Confluence $self = shift;
    $AUTOLOAD =~ s/Confluence:://;
    return if $AUTOLOAD =~ /DESTROY/;
    _rpc( $self, $AUTOLOAD, @_ );
}

1;
