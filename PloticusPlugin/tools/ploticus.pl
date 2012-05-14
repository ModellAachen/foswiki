#!/usr/bin/perl

# Support script for sandbox security mechanism for PloticusPlugin
# Sets the proper working dir and calls ploticus

my $debug = 0;

# if debug, start the file and show args
#
if ($debug) {
    open( DEBUGFILE, ">/tmp/ploticus.pl.log" );
    print DEBUGFILE "\n----\nCalling ploticus; got parameters:\n";
    print DEBUGFILE join( "\n", @ARGV ) . "\n";
}

# open error output file for writing
#
open( ERRFILE, "$ARGV[5]" );
print ERRFILE "";

# not called the write way - error and die
#
if ( $#ARGV != 5 ) {
    print ERRFILE
"Usage: ploticus.pl ploticus_executable working_dir infile format outfile errfile\n";
    die
"Usage: ploticus.pl ploticus_executable working_dir infile format outfile errfile\n";
}

my $ploticusBin = $ARGV[0];

if ($debug) {
    print "Changing dir to" . $ARGV[1] . "\n";
    print DEBUGFILE "Changing dir to" . $ARGV[1] . "\n";
}
unless ( chdir "$ARGV[1]" ) {
    print ERRFILE "Couldn't change working dir to $ARGV[1]: $!\n";
    die "Couldn't change working dir to $ARGV[1]: $!\n";
}

my $execCmd = "$ARGV[0] -f $ARGV[2] -$ARGV[3] -o $ARGV[4] 2> $ARGV[5] ";

if ($debug) {
    print "Built command line: " . $execCmd . "\n";
    print DEBUGFILE "Built command line: " . $execCmd . "\n";
}

print `$execCmd`;
if ($!) {
    print ERRFILE
      "Problem with executing ploticus command: '$execCmd', got:\n$!";
    die "Problem with executing ploticus command: '$execCmd', got:\n$!";
}

# close the debug file if we started it
#
if ($debug) { close DEBUGFILE; }

# and close the error output file
#
close ERRFILE;

exit 0;
