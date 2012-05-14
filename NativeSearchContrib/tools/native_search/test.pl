#!/usr/bin/perl
# Test program for FoswikiNativeSearch
# If it is correctly installed, this program will accept parameters like grep
# e.g.
# perl test.pl -i -l FoswikiNativeSearch test.pl Makefile.PL FoswikiNativeSearch.xs
#
use FoswikiNativeSearch;
die <<MOAN unless scalar(@ARGV);
I need parameters, like grep!
Try:
perl test.pl -i -l FoswikiNativeSearch test.pl Makefile.PL FoswikiNativeSearch.xs
If it returns at least 3 filenames and doesn't crash, it worked.
MOAN
my $result = FoswikiNativeSearch::cgrep( \@ARGV );
print "RESULT\n" . join( "\n", @$result ) . "\n";
