#!/usr/bin/perl -w
# Copyright (C) 2005,2009 Michael Daum http://michaeldaumconsulting.com
#
# This file is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read COPYING in the root of this distribution.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY, to the extent permitted by law; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

# wrapper script for the BibtexPlugin

use strict;

require "Foswiki.cfg";
require "LocalSite.cfg";

my $bibtoolPrg = $Foswiki::cfg{Plugins}{BibtexPlugin}{bibtool} || 
    "/usr/bin/bibtool";
my $bib2bibPrg = $Foswiki::cfg{Plugins}{BibtexPlugin}{bib2bib} || 
    "/usr/bin/bib2bib";
my $bibtex2htmlPrg = $Foswiki::cfg{Plugins}{BibtexPlugin}{bibtex2html} || 
    "/usr/bin/bibtex2html";
my $bibtexPrg = $Foswiki::cfg{Plugins}{BibtexPlugin}{bibtex} || 
    "/usr/bin/bibtex";

my $mode = shift(@ARGV);
my $bibtoolRsc = shift(@ARGV);
my $bib2bibSelect = shift(@ARGV);

my $t = shift(@ARGV);
my $bibtex2htmlArgs = "-c '$bibtexPrg -terse -min-crossrefs=1000' $t";
my $errorFile = shift(@ARGV);

my @bibfiles = @ARGV;

# my @bibfiles = scalar(@ARGV);

my $cmd1 = "$bibtoolPrg -r $bibtoolRsc @bibfiles | $bib2bibPrg -q -oc /dev/null $bib2bibSelect";
my $cmd2 = "$cmd1 | $bibtex2htmlPrg $bibtex2htmlArgs";

if ("x$mode" eq "xraw") {

  # print $cmd1."<br>";
  system($cmd1 );
} else {

  # print $cmd2."<br>";
  system($cmd2 );
}

1;
