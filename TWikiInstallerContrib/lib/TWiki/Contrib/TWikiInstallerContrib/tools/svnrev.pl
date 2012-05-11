#! /usr/bin/perl -w
use strict;

chomp( my @svnInfo = `svn info . 2>/dev/null` );
print '0' and exit unless @svnInfo;
my ($svnRev) = ( ( grep { /^Revision:\s+(\d+)$/ } @svnInfo )[0] ) =~ /(\d+)$/;
print $svnRev;
