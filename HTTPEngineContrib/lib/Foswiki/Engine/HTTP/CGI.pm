package Foswiki::Engine::HTTP::CGI;
use strict;

use Cwd ();
use IO::Select();
use File::Spec                  ();
use HTTP::Headers               ();
use HTTP::Status                ();
use Foswiki::Engine::HTTP::Util ();

use Error qw(:try);
use Time::HiRes qw(time);
use Errno qw(EINTR EWOULDBLOCK EAGAIN);

*sendResponse = \&Foswiki::Engine::HTTP::Util::sendResponse;

sub new {
    my $class = shift;
    return bless {@_}, ref($class) || $class;
}

sub finish {
}

sub send_response {
    my ( $this, $sock ) = @_;

    my $file = File::Spec->catdir( $this->{scriptdir}, $this->{action} );
    if ( -e $file && !-d _ ) {
        unless ( -x _ ) {
            sendResponse( $sock, 403 );
        }

        if (
            defined $this->{headers}->content_length
            && (   $this->{headers}->content_length !~ /^\d+$/
                || $this->{headers}->content_length < 0 )
          )
        {

            #TODO: add limit on request body
            sendResponse( $sock, 400 );
        }

        my ( $write, $stdin );
        my ( $read,  $stdout );
        my ( $err,   $stderr );
        unless ( pipe( $write, $stdin )
            && pipe( $read, $stdout )
            && pipe( $err,  $stderr ) )
        {
            sendResponse( $sock, 500 );
        }

        $SIG{CHLD} = sub { wait };
        my $pid = fork;
        if ( !defined $pid ) {
            sendResponse( $sock, 500 );
        }
        elsif ( $pid > 0 ) {    # Parent process
            foreach ( $stdin, $stdout, $stderr ) {
                close($_);
            }
            $this->manageInteraction( $sock, $write, $read, $err );
        }
        elsif ( $pid == 0 ) {    # Child
            untie(*STDIN);
            untie(*STDOUT);
            untie(*STDERR);

            open STDIN,  '<&', $stdin;
            open STDOUT, '>&', $stdout;
            open STDERR, '>&', $stderr;
            foreach ( $write, $read, $err, $stdin, $stdout, $stderr, $sock ) {
                close($_);
            }

            #TODO: use Foswiki::Sandbox to untaint properly
            chdir( ( $this->{scriptdir} =~ /^(.*)$/ )[0] );

            #TODO: add error handling
            %ENV = $this->hdr2env;
            $file =~ /^(.*)$/;
            exec {$1} $1;
        }
    }
    else {
        sendResponse( $sock, 404 );
    }
}

sub hdr2env {
    my $this = shift;
    my %cgi  = (
        GATEWAY_INTERFACE => 'CGI/1.1',
        PATH_INFO         => ${ $this->{path_info_ref} } || '',
        QUERY_STRING      => ${ $this->{query_string_ref} } || '',
        REMOTE_ADDR       => $this->{opts}{peeraddr},
        REMOTE_HOST       => '',
        REQUEST_METHOD    => uc( $this->{method} ),
        SCRIPT_NAME       => "$this->{opts}{scripturlpath}/$this->{action}",
        SERVER_PORT       => $this->{server_port},
        SERVER_PROTOCOL   => "HTTP/$this->{proto}",
        SERVER_SOFTWARE   => 'Foswiki/HTTPEngineContrib',
    );
    $cgi{SERVER_NAME} = $this->{headers}->header('Host')
      || $this->{opts}{sockaddr};
    $cgi{CONTENT_TYPE} = $this->{headers}->content_type
      if $this->{headers}->content_type;
    $cgi{CONTENT_LENGTH} = $this->{headers}->content_length
      if $this->{headers}->content_length;
    foreach my $hdr ( $this->{headers}->header_field_names ) {
        next if $hdr =~ /^Content-(?:Type|Length)$/i;
        my $hdrkey = 'HTTP_' . uc($hdr);
        $hdrkey =~ tr/-/_/;
        $cgi{$hdrkey} = $this->{headers}->header($hdr);
    }
    return %cgi;
}

sub manageInteraction {
    my $this = shift;
    my ( $sock, $write, $read, $err ) = @_;
    $_->blocking(0) foreach @_;

    my ( $inref, $outref, $error, $cgiState, $cgiBodyLeft, $done );
    $inref    = $this->{input_ref};
    $outref   = \'';
    $cgiState = 'headers';
    $done     = 0;
    my $clBodyLeft = -length($$inref);
    $clBodyLeft += $this->{headers}->content_length
      if $this->{headers}->content_length;

    my $sr = IO::Select->new( $read, $err );
    my $sw = IO::Select->new();

    until ($done) {
        if ( $clBodyLeft > 0 ) {
            $sr->add($sock);
        }
        elsif ( $sr->exists($sock) ) {
            $sr->remove($sock);
        }
        if ( length($$outref) ) {
            $sw->add($sock);
        }
        elsif ( $sw->exists($sock) ) {
            $sw->remove($sock);
        }
        if ( length($$inref) ) {
            $sw->add($write);
        }
        elsif ( $sw->exists($write) ) {
            $sw->remove($write);
        }

        #TODO: deal with timeouts
        my ( $rh, $wh ) = IO::Select->select( $sr, $sw );
        my $rv;
        foreach my $fd ( @{$rh} ) {
            if ( fileno $fd == fileno $sock ) {
                $rv = sysread( $sock, $$inref, 4096, -1 );
                unless ( defined $rv ) {
                    next if $! == EINTR || $! == EAGAIN || $! == EWOULDBLOCK;
                    throw Error::Simple("EBADF: $!");
                }
                $clBodyLeft -= $rv;
            }
            elsif ( fileno $fd == fileno $err ) {
                $rv = sysread( $err, my ($buffer), 4096 );
                unless ( defined $rv ) {
                    next if $! == EINTR || $! == EAGAIN || $! == EWOULDBLOCK;
                    throw Error::Simple("EBADF: $!");
                }
                print STDERR $buffer;
            }
            else {
                $rv = sysread( $err, $$outref, 4096, -1 );
                unless ( defined $rv ) {
                    next if $! == EINTR || $! == EAGAIN || $! == EWOULDBLOCK;
                    throw Error::Simple("EBADF: $!");
                }
                $rv = $cgih->add($outref);
                if ($rv) {
                    my $res = HTTP::Response->new();
                    if ( $cgih->headers->content_type ) {
                        $res->code(200);
                        $res->headers( $cgih->headers );
                        $$outref = $res->as_string . $$outref;
                    }
                    elsif ( $cgih->headers->header('Location') ) {
                        $res->code(302);
                        $res->headers( $cgih->headers );
                        $$outref = $res->as_string . $$outref;
                    }
                    elsif ( $cgih->headers->header('Status') ) {
                        $res->code( $cgih->hedaers->header('Status') );
                        $res->headers( $cgih->headers );
                        $$outref = $res->as_string . $$outref;
                    }
                    else {

                        # Error 500
                    }
                }
            }
        }
        foreach my $fd ( @{$wh} ) {
            if ( fileno $fd == fileno $sock ) {
                $rv = syswrite( $sock, $$outref );
                unless ( defined $rv ) {
                    next if $! == EINTR || $! == EAGAIN || $! == EWOULDBLOCK;
                    throw Error::Simple("EBADF: $!");
                }
                substr( $$outref, 0, $rv, '' );
            }
            else {
                $rv = syswrite( $write, $$inref );
                unless ( defined $rv ) {
                    next if $! == EINTR || $! == EAGAIN || $! == EWOULDBLOCK;
                    throw Error::Simple("EBADF: $!");
                }
                substr( $$inref, 0, $rv, '' );
            }
        }
    }
}

1;
