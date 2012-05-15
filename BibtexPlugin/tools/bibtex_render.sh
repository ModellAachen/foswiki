#!/bin/sh
# wrapper script for the BibtexPlugin
# See bottom of file for license and copyright information

# get args
mode="$1"
shift
os="$1"
shift
bibtexCmd="$1"
shift
bibtoolCmd="$1"
shift
bib2bibCmd="$1"
shift
bibtex2htmlCmd="$1"
shift
bibtoolRsc="$1"
shift
bib2bibSelect="$1"
shift
bibtex2htmlArgs="-c '$bibtexCmd -terse -min-crossrefs=1000' $1"
shift
errorFile="$1"
shift
bibfiles="$*"

# build command
cmd1="$bibtoolCmd -r $bibtoolRsc $bibfiles | $bib2bibCmd -q -oc /dev/null $bib2bibSelect"
cmd2="$cmd1 | $bibtex2htmlCmd $bibtex2htmlArgs"

if [ "$os" == "darwin" ]; then
	# Note for Mac OSX users: TeXlive 2010 prevents bibtex2html to run bibtex in a temporary directory
	# http://www.lri.fr/~filliatr/bibtex2html/
	# A workaround consists in telling bibtex2html to use the current directory for temporary files, using the following shell command before running bibtex2html:
	export TMPDIR=.
fi

# execute
(
  if test "x$mode" = "xraw"; then
    eval $cmd1
  else
    eval $cmd2
  fi
) 2>$errorFile

# Copyright (C) 2012 Foswiki contributors
# Copyright (C) 2005 Michael Daum <micha@nats.informatik.uni-hamburg.de>
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