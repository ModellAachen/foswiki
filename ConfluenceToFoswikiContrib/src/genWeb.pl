##########################################################################
#
# This software/utility is developed by TWIKI.NET (http://www.twiki.net)
# Copyright (C) 1999-2008  TWIKI.NET, sales@twiki.net
#
##########################################################################

use strict;
use warnings;
use File::Find;
use File::Basename;
use Cwd;
use Getopt::Std;
use Convertor;
use parser;
use Utils::Logger;
use CConfig;
use Utils::Common;
use Confluence;
use XMLExporter;
use XMLRPC::Lite;
use POSIX;

################################ Main ##########################################

my %hConfig = ();
my %hOpts;
my $sHomeDir;
my ($os) = POSIX::uname();
getopts( "h:g:", \%hOpts );

if ( not defined $hOpts{'h'} ) {
    print "NOTE: Home directory not specified on the command line,
                 finding from the current directory.\n";
    $sHomeDir = ( dirname( cwd() ) );
}
else {
    $sHomeDir = $hOpts{'h'};
}

my $zipdir      = "$sHomeDir/xml";
my $logger      = Log::Log4perl->get_logger("check");
my $sConfigFile = 'ConverterConfig.conf';
$Convertor::logger = $logger;
Utils::Logger::start_logging( "$sHomeDir", $sConfigFile );

if ( not defined $hOpts{'g'} ) {
    extractSpaces();
}

parse_conf( $sHomeDir, $sConfigFile, \%hConfig );

$logger->info("START : Foswiki web generation");
$logger->info("Homedir : $sHomeDir");
$logger->info("Foswiki user : $hConfig{User}");

my $session =
  Convertor::createSession( "$hConfig{User}", "$hConfig{Password}" );
my $flag = 0;
if ( !defined $session ) {
    $logger->error("Foswiki Session not created, cannot proceed");
    $logger->error("Check User and Password in $sConfigFile");
}

find( \&isZip, $zipdir );
find( \&isDir, $zipdir );

if ( $flag == 0 ) {
    $logger->error("No entities\.xml found");
}

if ( $os =~ /linux/ig ) {

    my $result = system(
"chown -R $hConfig{ApacheUser}:$hConfig{ApacheGroup} $hConfig{FoswikiPath}"
    );

    if ( $result != 0 ) {
        $logger->error("Could not set hConfig{FoswikiLibPath} permissions");
        $logger->error(
"Manually execute \"chown -R $hConfig{ApacheUser}:$hConfig{ApacheGroup} $hConfig{FoswikiPath}\" "
        );
    }
}

$logger->info("DONE: Foswiki web generation");

###############################################################################

#find zip file and unzip them, if sucessfull delete zip file
sub isZip {
    if ( $_ =~ /\.zip/ ) {
        Utils::Common::unZip( $sHomeDir, $File::Find::name, $logger );
    }
}

#the unzip directories
sub isDir {
    if ( $_ =~ /\.svn|\./gi ) {
        $_ = "not valid dir";
    }
    find( \&checkXML, "$File::Find::name" ) if -d;
}

#check if xml exists and call foswikiEmitter to create pages
sub checkXML {
    my $file = $_;
    if ( $file =~ /entities\.xml/g ) {
        $flag = 1;
        $logger->debug("Using $File::Find::name to parse confluence info\n");
        parser::foswikiEmitter( "$File::Find::name",
            $logger, $session, $sHomeDir );
    }
}

#extract confluence spaces
sub extractSpaces {
    my %h2Config    = ();
    my $sConfigFile = 'ConfluenceConfig.conf';
    parse_conf( $sHomeDir, $sConfigFile, \%h2Config );
    open( FILE, ">$sHomeDir/Exported_URLS" )
      or warn " could not open $sHomeDir/Exported_URLS\n";
    $logger->info("START:XML Extraction");
    my $confluence = XMLRPC::Lite->proxy("$h2Config{ServerURL}/rpc/xmlrpc");
    my $token =
      $confluence->call( "$Confluence::API.login", "$h2Config{User}",
        "$h2Config{Password}" )->result();
    my $xmlpath = "$sHomeDir/xml";

    if ( !$token ) {
        $logger->error("Could not login into confluence server");
        exit(666);
    }

    my $result =
      extractSiteXML( $confluence, $token, $logger, *FILE, $xmlpath,
        $h2Config{'User'}, $h2Config{'Password'} );

    if ( $result != 1 ) {
        $logger->info("XML Extraction failed");
    }
    $logger->info("DONE: XML Extraction");

}

