package Foswiki::Engine::HTTP;

use Foswiki::Engine ();
@ISA = qw(Foswiki::Engine);

use strict;

use Foswiki::Request         ();
use Foswiki::Request::Upload ();
use Foswiki::Response        ();

my $CRLF = "\x0D\x0A";

sub prepareConnection {
    my ( $this, $req ) = @_;
    $req->method( uc( $this->{args}{method} ) );
    $req->remote_addr( $this->{client}->peeraddr );
    $req->server_port( $this->{args}{server_port} );
    $req->secure(0);
}

sub prepareQueryParameters {
    my ( $this, $req ) = @_;
    $this->SUPER::prepareQueryParameters( $req,
        ${ $this->{args}{query_string_ref} } )
      if ${ $this->{args}{query_string_ref} };
}

sub prepareHeaders {
    my ( $this, $req ) = @_;
    foreach my $hdr ( $this->{args}{headers}->header_field_names ) {
        $req->header(
            -name  => $hdr,
            -value => [ $this->{args}{headers}->header($hdr) ]
        );
    }
    $req->remote_user(undef);
}

sub preparePath {
    my ( $this, $req ) = @_;
    $req->action( $this->{args}{action} );
    $req->path_info( ${ $this->{args}{path_info_ref} } );
    $req->uri( ${ $this->{args}{uri_ref} } );
}

sub prepareBody {
    my ( $this, $req ) = @_;

    return unless $this->{args}{headers}->content_length();
    $this->{body} = Foswiki::Engine::HTTP::Util::readBody(
        $this->{args}{headers},
        $this->{args}{input_ref},
        $this->{args}{timeleft}
    );
}

sub prepareBodyParameters {
    my ( $this, $req ) = @_;

    return unless $this->{args}{headers}->content_length();
    foreach my $p ( $this->{body}->compat_param ) {
        $req->bodyParam( $p => $this->{body}->compat_param($p) );
    }
}

sub prepareUploads {
    my ( $this, $req ) = @_;

    return unless $this->{args}{headers}->content_length();
    my %uploads;
    foreach my $value ( values %{ $this->{body}->upload } ) {
        $uploads{ $value->{filename} } = new Foswiki::Request::Upload(
            headers => $value->{headers},
            tmpname => $value->{tempname},
        );
    }
    $req->uploads( \%uploads );
}

sub finalizeUploads {
    my ( $this, $res, $req ) = @_;

    $req->delete($_) foreach keys %{ $req->uploads };
    delete $this->{body};
}

sub finalizeHeaders {
    my ( $this, $res, $req ) = @_;

    return if $this->{args}{proto} == 0.9;
    $this->SUPER::finalizeHeaders( $res, $req );
    my $hdr = HTTP::Headers->new();
    foreach my $h ( $res->getHeader ) {
        $hdr->header( $h => [ $res->getHeader($h) ] );
    }
    my $buffer = 'HTTP/'
      . $this->{args}{proto} . ' '
      . ( $res->status || '200 OK' )
      . $CRLF;
    syswrite( $this->{client}, $buffer . $hdr->as_string($CRLF) . $CRLF );
}

sub write {
    my ( $this, $buffer ) = @_;
    syswrite( $this->{client}, $buffer );
}

1;
