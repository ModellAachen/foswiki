#!/usr/bin/perl -wT

use Cwd            ();
use File::Spec     ();
use File::Basename ();

BEGIN {
    $Foswiki::cfg{Engine} = 'Foswiki::Engine::HTTP';
    my $coreDir = Cwd::abs_path(
        File::Spec->catdir( File::Basename::dirname(__FILE__), '..' ) );
    my ($setLibCfg) =
      File::Spec->catdir( $coreDir, 'bin', 'setlib.cfg' ) =~ /^(.*)$/;
    do $setLibCfg;
}

use strict;

use Foswiki::Engine::HTTP::Server;

my $http = Foswiki::Engine::HTTP::Server->new(
    server_type      => 'Single',
    no_client_stdout => 1,
    log_level        => 0,
);
$http->run( host => '127.0.0.1', port => 8080, proto => 'tcp' );
