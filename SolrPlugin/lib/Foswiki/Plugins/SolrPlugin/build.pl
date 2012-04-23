#!/usr/bin/perl -w
BEGIN { 
	$ENV{FOSWIKI_LIBS} = 'C:/Users/Alexander/git/foswiki/core/lib';
	unshift @INC, split( /;/, "C:/Users/Alexander/git/foswiki/core/lib" ) 
}
use Foswiki::Contrib::Build;

# Create the build object
$build = new Foswiki::Contrib::Build('SolrPlugin');

# (Optional) Set the details of the repository for uploads.
# This can be any web on any accessible Foswiki installation.
# These defaults will be used when expanding tokens in .txt
# files, but be warned, they can be overridden at upload time!

# name of web to upload to
$build->{UPLOADTARGETWEB} = 'Extensions';
# Full URL of pub directory
$build->{UPLOADTARGETPUB} = 'http://extensions.open-quality.com/pub';
# Full URL of bin directory
$build->{UPLOADTARGETSCRIPT} = 'http://extensions.open-quality.com/bin';
# Script extension
$build->{UPLOADTARGETSUFFIX} = '';

$build->build($build->{target});

