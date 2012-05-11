#!/bin/sh
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

# config
bibtoolPrg="/usr/bin/bibtool"
bib2bibPrg="/usr/bin/bib2bib"
bibtex2htmlPrg="/usr/bin/bibtex2html"
bibtexPrg="/usr/bin/bibtex"

# get args
mode="$1"
shift
bibtoolRsc="$1"
shift
bib2bibSelect="$1"
shift
bibtex2htmlArgs="-c '$bibtexPrg -terse -min-crossrefs=1000' $1"
shift
errorFile="$1"
shift
bibfiles="$*"

# build command
cmd1="$bibtoolPrg -r $bibtoolRsc $bibfiles | $bib2bibPrg -q -oc /dev/null $bib2bibSelect"
cmd2="$cmd1 | $bibtex2htmlPrg $bibtex2htmlArgs"

# execute
(
  if test "x$mode" = "xraw"; then
    eval $cmd1
  else
    eval $cmd2
  fi
) 2>$errorFile
