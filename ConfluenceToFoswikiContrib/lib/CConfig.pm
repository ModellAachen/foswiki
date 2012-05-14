##########################################################################
#
# This software/utility is developed by TWIKI.NET (http://www.twiki.net)
# Copyright (C) 1999-2008  TWIKI.NET, sales@twiki.net
#
##########################################################################

package CConfig;

use strict;
use warnings;

our @ISA    = qw(Exporter);
our @EXPORT = qw(parse_conf);

=head1 NAME

Config - Configuration module

=head1 DESCRIPTION

This module implements Configuration interface .
Interfaces implemented-
parse_conf:This function parses configuration file and populates %hConfig.
=cut

############################################################################
# FUNCTION NAME: parse_conf
# PURPOSE:	This function parses the configuration file and populates %hConfig.
# INPUT:	The home directory , Config file, hconfig refrence
# OUTPUT:	None - the outputs are handled by the individual stages.
############################################################################

sub parse_conf {

    my $sHomeDir      = shift;
    my $sConfigFile   = shift;
    my $rhConfigList  = shift;
    my $sConfFilePath = "$sHomeDir" . "/conf/" . "$sConfigFile";
    open my $rFileHandle, '<', $sConfFilePath
      or die "Couldn't open $sConfFilePath.\n";

    while (<$rFileHandle>) {
        next if /^(#|\s)+/;    # Skip comments and blank lines.
        my @aKeyVal = split( "=", $_ );
        chomp(@aKeyVal);
        ${$rhConfigList}{ $aKeyVal[0] } = $aKeyVal[1];
    }

    close $rFileHandle;
}

1;
