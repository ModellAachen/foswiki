package Foswiki::Engine::HTTP::Util;
use strict;

use HTTP::Headers ();
use HTTP::Body    ();
use IO::Select    ();

use Error qw(:try);
use Time::HiRes qw(time);
use Errno qw(EINTR EWOULDBLOCK EAGAIN);

sub readHeader {
    my ( $fd, $opts, $full ) = @_;
    my $sel        = IO::Select->new($fd);
    my $bytes_read = 0;
    my $data       = '';
    my $timeleft   = $opts->{read_headers_timeout};
    my ( $state, $limit );
    if ($full) {
        $state = 'request';
        $limit = $opts->{limit_request_line};
    }
    else {
        $state = 'headers';
        $limit = $opts->{limit_headers};
    }

    my $headers = HTTP::Headers->new();
    my ( $method, $uri, $proto, $input );
    my ( $header, $hdrval );

  READ:
    while ( $state ne 'done' && $bytes_read < $limit && $timeleft > 0 ) {
        my $now   = time;
        my @ready = $sel->can_read($timeleft);
        $timeleft -= time - $now;
        if ( @ready == 0 ) {
            next if $! == EINTR;
            throw Error::Simple("EBADF: $!");
        }
        my $rv = sysread( $fd, my ($buffer), $limit );
        unless ( defined $rv ) {
            next if $! == EINTR || $! == EAGAIN || $! == EWOULDBLOCK;
            throw Error::Simple("EBADF: $!");
        }
        $bytes_read += $rv;
        while ( $state ne 'done' && length($buffer) > 0 ) {
            if ( $buffer =~ /(.*?)(?:\x0D?\x0A|\x0D(?!\x0A))/s ) {
                $data .= $1;
                substr( $buffer, 0, $+[0], '' );
                if ( $data =~ /^\s*$/s ) {
                    $headers->push_header( $header => $hdrval )
                      if defined $header
                          && defined $hdrval
                          && $state eq 'headers';
                    $state = 'done';
                    $input = $buffer;
                }
            }
            else {
                $data .= $buffer;
                next READ;
            }
            if ( $state eq 'request' ) {
                ( $method, $uri, $proto ) =
                  $data =~ /^\s*(\S+)\s+(\S+)(?:\s+(\S+))?/;
                $state = defined $proto
                  && $proto =~ m!HTTP/1\.[01]!i ? 'headers' : 'done';
                $limit      = $opts->{limit_headers};
                $bytes_read = length($buffer);
            }
            elsif ( $state eq 'headers' ) {
                if ( $data =~ /^([^\s:]+)\s*:\s(.*)/ ) {
                    my @tmp = ( $1, $2 );
                    $headers->push_header( $header => $hdrval )
                      if defined $header && defined $hdrval;
                    ( $header, $hdrval ) = @tmp;
                }
                elsif ( $data =~ /^\s+(.*)/ ) {
                    $hdrval .= $1;
                }
            }
            $data = '';
        }
    }

    if ( $state eq 'done' ) {
        return ( $headers, \$input, $method, \$uri, $proto );
    }
    elsif ( $timeleft <= 0 ) {
        throw Error::Simple('ETIMEOUT');
    }
    elsif ( $bytes_read >= $limit ) {
        throw Error::Simple('ESIZELIMIT');
    }
}

sub readBody {
    my ( $fd, $headers, $input_ref, $timeleft ) = @_;

    my $body = HTTP::Body->new( $headers->header('Content-Type'),
        $headers->content_length );
    $body->add($$input_ref);
    my $bytes_read = length($$input_ref);

    my $sel = IO::Select->new($fd);

    while ( $bytes_read < $headers->content_length && $timeleft >= 0 ) {
        my $now   = time;
        my @ready = $sel->can_read($timeleft);
        $timeleft -= time - $now;
        if ( @ready == 0 ) {
            next if $! == EINTR;
            throw Error::Simple("EBADF: $!");
        }
        my $rv = sysread( $fd, my ($buffer), 4096 );
        unless ( defined $rv ) {
            next if $! == EINTR || $! == EAGAIN || $! == EWOULDBLOCK;
            throw Error::Simple("EBADF: $!");
        }
        $body->add($buffer);
        $bytes_read += $rv;
    }

    throw Error::Simple("EBADREQ")
      unless $bytes_read == $headers->content_length;

    return $body;
}

sub sendResponse {
    local $, = ' ';
    print STDERR @_, "\n";
}

1;
