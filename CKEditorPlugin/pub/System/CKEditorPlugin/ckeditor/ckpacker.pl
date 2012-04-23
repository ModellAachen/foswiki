#! /bin/perl -w

use strict;
use warnings;

use File::Temp ();

my $in = $ARGV[0];

$in =~ s/\\/\//g;

if ($in =~ m#ckeditor[\\/](_source[\\/])(.+)([\\/])(.+)#) {

my $src = "$4";
my $pfad = "$1$2$3";
my $pfad2 = "$2$3";

my $ergebnis = <<PACK;
/*

 * CKPackager - Sample Package file

 */

 

header :

      '/*'                                                                   + '\\n' +

      ' * This file has been compressed with CKPackager'   + '\\n' +

      ' */'                                                                  + '\\n' +

      '\\n',

 

packages :

      [

            {

                  output : '$pfad2$src',

 

                  renameGlobals : false,

                  compactJavascript : true,

                  files :

                        [

                             '$pfad$src'

                        ]

            }

      ]
PACK

open FILE, '+>' , "helper.pack" or die "Kann Datei helper.pack nicht oeffnen: $!";
print FILE $ergebnis;
close FILE;

exec "java -jar ckpackager.jar helper.pack";


} else {
	print "$in\nDiese Datei befindet sich nicht im Source Ordner! Auf ein Neues!";
}