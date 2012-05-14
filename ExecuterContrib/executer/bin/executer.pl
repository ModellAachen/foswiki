#
#That script runs on the Executer machine
#

use strict;
use warnings;
use Config::Simple;

#Do some find bin
my $bindir;
use FindBin ();

BEGIN {

    #chdir($dir = $FindBin::Bin);
    $bindir = $FindBin::Bin;

    #Include our own module dirs
    @INC = ( @INC, "$bindir/../lib" );

    #Initialize globals
}

require Slion::TWiki::Executer;

my $topicDetermined = 0;

#my $startFile=$ENV{TEMP}.'\exestart.txt';

my $startFile;
my $outputFile;
my $outputFilePrep;

#Some specific code for MS windows
if ( $^O eq 'MSWin32' ) {
    $startFile      = 'C:\executer\exestart.txt';
    $outputFile     = 'C:\executer\exeoutput.txt';
    $outputFilePrep = 'C:\executer\exeoutputprep.txt';
}
else {
    $startFile      = '/tmp/exestart.txt';
    $outputFile     = '/tmp/exeoutput.txt';
    $outputFilePrep = '/tmp/exeoutputprep.txt';
}

#Loop forever waiting for tasks
#We basically check if $startFile exists
while (1) {
    if ( -f $startFile ) {
        sleep(2);    #just to make sure the file is in stable state
        print "Starting!!!\n";

        #open FILE, "< $startFile";
        #my ($url,$web,$topic)=<FILE>;
        #close FILE;

        #$url=trim($url);
        #$web=trim($web);
        #$topic=trim($topic);

        #Open config file read the value
        #my $cfg = new Config::Simple($startFile);
        #my %config = $cfg->vars();

        my %config = ();
        Config::Simple->import_from( $startFile, \%config )->close();

        my $url   = $config{bin};
        my $web   = $config{web};
        my $topic = $config{topic};

        my $starttext = <<StartText;
Task specification:
URL: 	$url
Web: 	$web
Topic:	$topic
StartText

        print "$starttext";

        StartTask( $url, $web, $topic, \%config );
        die "Can't delete \"$startFile\" !!"
          unless unlink $startFile
        ;    #Dying to prevent looping over and over on the same task
        unlink $outputFile;    # ignore error

        $topicDetermined = 0;
    }
    else {
        sleep(2);
        my $time = time;
        print "Waiting $time...\n";
    }
}

exit(0);

sub StartTask {

    #$config = hash ref
    my ( $url, $web, $topic, $config ) = @_;
    my $res = 0;
    my $twiki;
    $twiki = Slion::TWiki::Executer->new();

    #TODO: testing remove that return
    #return;

    #Set script URL
    $twiki->ScriptUrl($url);

    #Read credentials from cfg file
    my %config = ();
    Config::Simple->import_from( "$bindir/../cfg/executer.cfg", \%config )
      ->close();

    #Set credentials
    my $username = $config{username};
    my $password = $config{password};
    my $smtphost = $config{smtphost};
    $twiki->User($username);
    $twiki->Password($password);
    $twiki->SmtpHost($smtphost);

    $twiki->Web($web);
    $twiki->Topic($topic);

#Now login, for TWiki template login, TODO: does it have side effect when template login is disabled?
    my $response;
    my %sriptParam = ();

    %sriptParam = (
        'username' => "$username",
        'password' => "$password"
    );
    $res = $twiki->Login( \%sriptParam, \$response );
    print "Could not login!\n" unless $res == 1;    #keep going anyway

    $twiki->OutputTopicDetermined( \&OutputTopicDetermined );
    $res = $twiki->DoTask($config);
    if ( $res == 0 ) {
        print "Task failed!\n";
    }
    else {
        print "Task completed!\n";
    }

    #exit(0);
}

sub OutputTopicDetermined {
    my $self = shift;
    unless ($topicDetermined) {
        print "Location: "
          . $self->ScriptUrl
          . "/view/"
          . $self->OutputWeb . "/"
          . $self->OutputTopic . "\n\n";

#Write information about our output topic to a file so that exestatus CGI can retrieve it
        open FILE, "> $outputFilePrep"
          or die "ERROR: Can't open $outputFilePrep!\n";
        print FILE $self->ScriptUrl . "\n";
        print FILE $self->OutputWeb . "\n";
        print FILE $self->OutputTopic . "\n";
        close FILE;

        rename( $outputFilePrep, $outputFile );

        #close (STDOUT);
        #close (STDERR);
    }
    $topicDetermined = 1;
}

sub trim {
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}
