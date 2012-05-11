##########################################################################
#
# This software/utility is developed by TWIKI.NET (http://www.twiki.net)
# Copyright (C) 1999-2008  TWIKI.NET, sales@twiki.net
#
##########################################################################

package Utils::Logger;

use strict;
use warnings;

use CConfig;
use Exporter;
use Log::Log4perl;

our @ISA    = qw(Log::Log4perl);
our @EXPORT = qw(init_logger start_logging get_logger);

=head1 NAME

Utils::Logger - Logging module

=head1 DESCRIPTION

This module implements the Log::Log4perl::Logger interface, for generating
log messages.
Interfaces implemented-
init_logger:This function initliazes logger and set logger level specified in configuration file.
start_logging:This function parses config file and intiliaze logger to required level.
=cut

#######################################################################
#Function Name : init_logger
#Purpose : This function initliazes logger and set logger level
#            specified in configuration file.
#Input : log directory , log level, log file name
#Output : None
#######################################################################
sub init_logger($$$) {

    my ( $sLogDir, $sLogLevel, $sLogFile ) = @_;
    chomp($sLogLevel);

    #We define custom log level
    Log::Log4perl::Logger::create_custom_level( "ERROR_PARSE", "WARN" );
    Log::Log4perl::Logger::create_custom_level( "ERROR_READ",  "WARN" );

    my $debugconf = q(
    
    # Filter to match level ERROR_READ
	log4perl.filter.MatchError_Read  = Log::Log4perl::Filter::LevelMatch
    log4perl.filter.MatchError_Read.LevelToMatch  = ERROR_READ
    log4perl.filter.MatchError_Read.AcceptOnMatch = true

    # ERROR_READ appender
    log4perl.appender.AppError_Read = Log::Log4perl::Appender::File
    log4perl.appender.AppError_Read.filename = dummy
    log4perl.appender.AppError_Read.layout   = SimpleLayout
    log4perl.appender.AppError_Read.Filter   = MatchError_Read


    # Filter to match level ERROR_PARSE
    log4perl.filter.MatchError_Parse  = Log::Log4perl::Filter::LevelMatch
    log4perl.filter.MatchError_Parse.LevelToMatch  = ERROR_PARSE
    log4perl.filter.MatchError_Parse.AcceptOnMatch = true

    # ERROR_PARSE appender
    log4perl.appender.AppError_Parse = Log::Log4perl::Appender::File
    log4perl.appender.AppError_Parse.filename = dummy
    log4perl.appender.AppError_Parse.layout   = SimpleLayout
    log4perl.appender.AppError_Parse.Filter   = MatchError_Parse

    # We use IdAppender which is based on default Logfile appender.
    log4perl.category.check            = DEBUG, Logfile, Screen 
    log4perl.appender.Logfile          = Utils::IdAppender
    log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Logfile.layout.ConversionPattern = [%d],[%p],[%M %L],%m%n

    log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.stderr  = 0
    log4perl.appender.Screen.layout  = Log::Log4perl::Layout::SimpleLayout
    
    );

    my $infoconf = q(

    # Filter to match level ERROR_READ
	log4perl.filter.MatchError_Read  = Log::Log4perl::Filter::LevelMatch
    log4perl.filter.MatchError_Read.LevelToMatch  = ERROR_READ
    log4perl.filter.MatchError_Read.AcceptOnMatch = true

    # ERROR_READ appender
    log4perl.appender.AppError_Read = Log::Log4perl::Appender::File
    log4perl.appender.AppError_Read.filename = dummy
    log4perl.appender.AppError_Read.layout   = SimpleLayout
    log4perl.appender.AppError_Read.Filter   = MatchError_Read


    # Filter to match level ERROR_PARSE
    log4perl.filter.MatchError_Parse  = Log::Log4perl::Filter::LevelMatch
    log4perl.filter.MatchError_Parse.LevelToMatch  = ERROR_PARSE
    log4perl.filter.MatchError_Parse.AcceptOnMatch = true

    # ERROR_PARSE appender
    log4perl.appender.AppError_Parse = Log::Log4perl::Appender::File
    log4perl.appender.AppError_Parse.filename = dummy
    log4perl.appender.AppError_Parse.layout   = SimpleLayout
    log4perl.appender.AppError_Parse.Filter   = MatchError_Parse
    
    log4perl.category.check            = INFO, Logfile, Screen

    log4perl.appender.Logfile          = Utils::IdAppender
    log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Logfile.layout.ConversionPattern = [%d{yyyy-MM-dd HH:mm:ss:SS}],[%p],[%M %L],%m%n
		                                                 

    log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.stderr  = 0
    log4perl.appender.Screen.layout  = Log::Log4perl::Layout::SimpleLayout
    
    );

    # Depending on loglevel configured in configuration file we choose level
    if ( $sLogLevel eq "DEBUG" ) {
        $debugconf .=
          'log4perl.appender.Logfile.filename = ' . $sLogDir . '/' . $sLogFile;
        Log::Log4perl::init( \$debugconf );
    }
    else {
        $infoconf .=
          'log4perl.appender.Logfile.filename = ' . $sLogDir . '/' . $sLogFile;
        Log::Log4perl::init( \$infoconf );
    }

}

##############################################################################
#Function Name : start_logging.
#Purpose : Function parses config file and intiliaze logger to required level.
#Input : log directory , log level, log file name
#Output : None.
##############################################################################

sub start_logging($$) {

    my ( $sLogDir, $sConfFile ) = @_;
    my %hConfig;
    parse_conf( $sLogDir, $sConfFile, \%hConfig );
    my $sLogfilePath = "$sLogDir/" . $hConfig{LogFile};

    if ( $hConfig{Debug} eq "on" ) {
        init_logger( "$sLogDir", "DEBUG", $hConfig{LogFile} );
    }
    else {
        init_logger( "$sLogDir", "INFO", $hConfig{LogFile} );
    }

    #everytime write to clean file.
    open rLF, '>', $sLogfilePath
      or die "Could not create Logfile $sLogfilePath";
    close rLF;
}

1;
