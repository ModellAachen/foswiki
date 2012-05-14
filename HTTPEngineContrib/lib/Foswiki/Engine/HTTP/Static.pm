package Foswiki::Engine::HTTP::Static;
use strict;

use File::Spec    ();
use HTTP::Headers ();
use HTTP::Status qw(status_message);
use HTTP::Date qw(time2str str2time);
use LWP::MediaTypes qw(guess_media_type);

my $CRLF = "\x0D\x0A";
LWP::MediaTypes::read_media_types( $Foswiki::cfg{MimeTypesFileName} );

sub new {
    my $class = shift;
    my $this = bless {@_}, ref($class) || $class;
    $this->{method} = uc( $this->{method} );
    return $this;
}

sub send_response {
    my ( $this, $sock ) = @_;

    my $headers = HTTP::Headers->new();
    $headers->header( 'Date' => time2str(time) );

    if ( $this->{method} !~ /^(?:GET|HEAD)$/o ) {
        if ( $this->{proto} eq '1.1' ) {
            $headers->header( Allow => 'GET, HEAD' );
            $this->_write( $sock, 405, $headers );
            return 405;
        }
        $this->_write( $sock, 400, $headers );
        return 400;
    }

    $this->_translateUri();
    if ( -e $this->{file} && -r _ && !-d _ ) {
        my ( $size, $mtime ) = ( stat(_) )[ 7, 9 ];

        guess_media_type( $this->{file}, $headers );

        my $lmtime = str2time( $this->{headers}->header('If-Modified-Since') );
        if ( $this->{method} eq 'GET' && $lmtime && $mtime <= $lmtime ) {
            $this->_write( $sock, 304, $headers );
            return 304;
        }

        $headers->header( 'Last-Modified' => time2str($mtime) );
        $headers->content_length($size);
        $headers->header( Connection => 'close' )
          if $this->{proto} eq '1.1';
        $this->_write( $sock, 200, $headers );
    }
    else {
        $this->_write( $sock, 404, $headers );
        return 404;
    }
}

sub _translateUri {
    my $this = shift;

    $this->{file} = ${ $this->{uri_ref} };
    delete $this->{uri_ref};

    substr( $this->{file}, 0, length( $Foswiki::cfg{PubUrlPath} ), '' );
    $this->{file} =~ s/\?.*//;

    my @path = File::Spec->no_upwards( split m!/+!, $this->{file} );
    $this->{file} = File::Spec->catfile( $Foswiki::cfg{PubDir}, @path );
}

sub _write {
    my ( $this, $sock, $code, $headers ) = @_;
    my $chunk = '';
    my $fh;
    if ( $code == 200 && !open( $fh, '<', $this->{file} ) ) {
        $code = 404;
        $headers->remove_header($_)
          foreach
          qw(Content-Type Content-Length Content-Encoding Last-Modified);
    }
    if ( $this->{proto} > 0.9 ) {
        $chunk = 'HTTP/'
          . $this->{proto} . ' '
          . $code . ' '
          . status_message($code)
          . $CRLF
          . $headers->as_string($CRLF)
          . $CRLF;
    }
    if ( $code == 200 && $this->{method} eq 'GET' ) {
        binmode $fh;
        while ( sysread( $fh, my ($buffer), 4096 ) ) {
            last
              unless syswrite( $sock, $chunk . $buffer ) > 0;
            $chunk = '';
        }
        close $fh;
    }
    else {
        syswrite( $sock, $chunk );
    }
}

1;
