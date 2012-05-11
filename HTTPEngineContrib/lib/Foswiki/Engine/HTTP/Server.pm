package Foswiki::Engine::HTTP::Server;

use Net::Server::MultiType ();
@ISA = qw(Net::Server::MultiType);

use strict;
use Cwd                           ();
use File::Spec                    ();
use File::Basename                ();
use HTTP::Message                 ();
use HTTP::Status                  ();
use Foswiki::Engine::HTTP::Util   ();
use Foswiki::Engine::HTTP::CGI    ();
use Foswiki::Engine::HTTP::Static ();
use Foswiki::Engine::HTTP::Native ();

use Error qw(:try);

BEGIN {
    no warnings 'redefine';
    my $param_ref = \&HTTP::Body::param;
    *HTTP::Body::param = sub {
        my ( $this, $p, $v ) = @_;
        if ( defined $p && defined $v ) {
            push @{ $this->{plist} }, $p unless exists $this->{param}{$p};
        }
        $param_ref->(@_);
    };
    my $upload_ref = \&HTTP::Body::upload;
    *HTTP::Body::upload = sub {
        my ( $this, $p, $v ) = @_;
        $this->param( $p, $v->{filename} ) if defined $p && defined $v;
        $upload_ref->(@_);
    };
    *HTTP::Body::compat_param = sub {
        my $this = shift;
        $this->{plist} ||= [];
        return @{ $this->{plist} } unless @_ > 0;
        my $name = shift;
        return $this->{param}{$name};
    };
}

sub options {
    my $this = shift;
    my $prop = $this->{'server'};
    my $ref  = shift;

    ### setup options in the parent classes
    $this->SUPER::options($ref);

    foreach (
        qw(read_headers_timeout limit_request_line
        limit_headers read_body_timeout limit_body
        puburlpath scripturlpath scriptdir pubdir)
      )
    {
        $prop->{$_} ||= undef;
        $ref->{$_} = \$prop->{$_};
    }

    $prop->{log_file} = '';
}

sub default_values {
    my $this = shift;
    my $opts = $this->SUPER::default_values(@_);
    $opts->{read_headers_timeout} = 30;
    $opts->{read_body_timeout}    = 30 * 60;
    $opts->{limit_request_line}   = 8192;
    $opts->{limit_headers}        = 8192;
    $opts->{limit_body}           = 10 * ( 2**20 );
    $opts->{puburlpath}           = '/pub';
    $opts->{scripturlpath}        = '/bin';
    $opts->{pubdir}               = Cwd::abs_path(
        File::Spec->catdir( File::Basename::dirname($0), qw(.. pub) ) );
    $opts->{scriptdir} = Cwd::abs_path(
        File::Spec->catdir( File::Basename::dirname($0), qw(.. bin) ) );
    return $opts;
}

sub process_request {
    my $this = shift;

    my ( $method, $uri_ref, $proto, $headers, $input_ref );
    $SIG{PIPE} = 'IGNORE';
    try {
        ( $headers, $input_ref, $method, $uri_ref, $proto ) =
          Foswiki::Engine::HTTP::Util::readHeader( $this->{server}{client},
            $this->{server}, 1 );
    }    #TODO: add more error handling
    catch Error::Simple with {
        my $e = shift;
    };

    unless ( defined $method && $method =~ /(?:POST|GET|HEAD)/i ) {
        Foswiki::Engine::HTTP::Util::sendResponse( $this->{server}{client},
            501 );
        return;
    }

    if ( !defined($proto) || $proto =~ m!HTTP/0.9!i ) {
        $proto = 0.9;
    }
    elsif ( $proto =~ m!HTTP/(1\.[01])!i ) {
        $proto = $1;
    }
    else {
        Foswiki::Engine::HTTP::Util::sendResponse( $this->{server}{client},
            505 );
        return;
    }

    # Check what resource was requested:
    #   - Static file from pub
    #   - Foswiki action or CGI script (without Shorter URLs)
    #   - Foswiki action as a short URL
    # Give up if none of these.
    my ( $handler, @args );
    @args = (
        method  => $method,
        uri_ref => $uri_ref,
        proto   => $proto,
        headers => $headers,
    );

    if ( index( $$uri_ref, $this->{server}{puburlpath} ) == 0 ) {
        $handler = 'Static';
    }
    elsif ( index( $$uri_ref, $this->{server}{scripturlpath} ) == 0 )
    {    # Foswiki action or CGI script
        my $path = $this->{server}{scripturlpath};

        my ( $action, $path_info, $query_string ) =
          $$uri_ref =~ m#^\Q$path\E/+([^/\?]+)([^\?]*)(?:\?(.*))?#;
        $path_info  =~ s/%(..)/chr(hex($1))/ge;

        unless ( defined $action ) {
            Foswiki::Engine::HTTP::Util::sendResponse( $this->{server}{client},
                403 );
            return;    # Abort the connection
        }

        push @args,
          (
            action           => $action,
            path_info_ref    => \$path_info,
            query_string_ref => \$query_string,
            server_port      => $this->{server}{sockport},
            input_ref        => $input_ref,
            timeleft         => $this->{server}{read_body_timeout},
          );
        unless ( Foswiki::Engine::HTTP::Native::existsAction($action) ) {
            $handler = 'CGI';
            push @args,
              (
                scriptdir => $this->{server}{scriptdir},
                opts      => $this->{server},
              );
        }
        else {
            $handler = 'Native';
        }
    }
    elsif ( my @actions = Foswiki::Engine::HTTP::Native::shorterUrlPaths() )
    {    # Try shorter URLs before giving up
        foreach my $entry (@actions) {
            next unless $$uri_ref =~ m#^\Q$entry->{path}\E(/[^\?]*)(?:\?(.*))?#;
            my ( $path_info, $query_string ) = ( $1, $2 );
            $path_info =~ s/%(..)/chr(hex($1))/ge;
            $handler = 'Native';
            push @args,
              (
                action           => $entry->{action},
                path_info_ref    => \$path_info,
                query_string_ref => \$query_string,
                server_port      => $this->{server}{port},
              );
            last;
        }
    }
    if ( defined $handler ) {
        my $worker = ( 'Foswiki::Engine::HTTP::' . $handler )->new(@args);
        $worker->send_response( $this->{server}{client} );
        $worker->finish();
    }
    else {
        Foswiki::Engine::HTTP::Util::sendResponse( $this->{server}{client},
            404 );
    }
}

1;
