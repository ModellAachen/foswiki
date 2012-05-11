#! perl -w
# TWiki redirect script.
# Written by Martin Cleaver

use strict;
use vars
  qw($viewTopic $redirectsTopic %redirectsHash $viewTopic $fallbackWeb $debug);

my $serverName = lc( $ENV{'SERVER_NAME'} || $ARGV[0] );
my $redirectsTopic = "d:/twikiroot/data/TWiki/RedirectBySubDomain.txt";
my %redirectsHash =
  ( "codev.twiki.org" => "Codev.WebHome", "support.twiki.org" => "Support" );
my $viewTopic   = 'http://www.twiki.org/twiki/bin/view/';
my $fallbackWeb = 'Main';
my $debug =
  0;    # would be nice to take off the URL but IIS makes this hard so I won't

writeDebug("\n\n$serverName\n");

writeDebug("Content-type: text/html\n\n");

readTopicForRedirects();

if ( $redirectsHash{$serverName} ) {
    writeDebug("Found by looking at hash\n");
    redirectToWeb( $redirectsHash{$serverName} );
    exit;
}
else {
    writeDebug("Trying slow matching\n");
    redirectToWeb( searchForMatchInRedirects($serverName) )
      || redirectToWeb($fallbackWeb);
    exit;
}

# to the value
sub searchForMatchInRedirects {
    my ($servername) = @_;
    foreach my $entry ( keys %redirectsHash ) {
        writeDebug("Does '$entry' match '$servername'?");
        if ( $servername =~ m/$entry/ )
        {    # as an expression, so can have wildcards
            writeDebug(" YES\n");
            return $redirectsHash{$entry};
        }
        else {
            writeDebug(" NO\n");
        }
    }
}

sub redirectToWeb {
    my ($webName) = @_;
    print "HTTP/1.1 302 Object Moved\n";
    print "Location: $viewTopic$webName\n\n";
}

sub writeDebug {
    print "$_[0]" if $debug;
}

sub readTopicForRedirects {
    if ( open( FILE, "<$redirectsTopic" ) ) {
        writeDebug("Reading $redirectsTopic\n");
        while ( my $line = <FILE> ) {
            if (
                $line =~ m/\s*
			\|
			\s*
			(.+?)
			\s*
			\|
			\s*
			(.+?)
			\s*
			\|
			\s*(.*)/x
              )
            {
                my ( $siteexpression, $dest, $ignored ) = ( lc $1, $2, $3 );
                $siteexpression =~ s|http://||;
                $redirectsHash{$siteexpression} = $dest;
                writeDebug(
"caching '$siteexpression' => '$dest' (ignoring '$ignored')\n"
                );
            }
        }
        close(FILE);
    }
    else {
        writeDebug("Not reading $redirectsTopic - $!\n");
    }
}
