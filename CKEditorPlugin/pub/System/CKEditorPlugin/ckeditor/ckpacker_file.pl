#! /bin/perl -w

use strict;
use warnings;

use File::Temp ();

my $in = $ARGV[0];

if ($in) {

exec "java -jar ckpackager.jar $in";


} else {
	print "$in\nDiese Datei befindet sich nicht im Source Ordner! Auf ein Neues!";
}