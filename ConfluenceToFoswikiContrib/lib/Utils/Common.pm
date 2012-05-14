##########################################################################
#
# This software/utility is developed by TWIKI.NET (http://www.twiki.net)
# Copyright (C) 1999-2008  TWIKI.NET, sales@twiki.net
#
##########################################################################

package Utils::Common;

use strict;
use warnings;
use Exporter;
use Archive::Extract;
use File::Basename;
our @ISA     = qw(Exporter);
our @EXPORTS = qw(quote unZip replacesSpaces toFoswikiname);

sub quote($) {
    my ($sStr) = @_;
    my $sMetaChars = "\\[{()}\\].+*?%@#<>";

    $sStr =~ s/(?<!\\)([$sMetaChars])/\\$1/xg;
    return $sStr;
}

sub unZip($$$) {

    my ( $sHomeDir, $zipfile, $logger ) = @_;
    my $unzipdir = basename( $zipfile, ".zip" );
    $logger->info("START:Unzipping $zipfile");
    my $ae = Archive::Extract->new( archive => "$zipfile" );
    my $return = $ae->extract( to => "$sHomeDir/xml/$unzipdir" );

    if ( $return == 1 ) {
        $logger->info("DONE:Unzipping $zipfile");
        $logger->info("Deleting $zipfile");
        unlink($zipfile);
    }
    else {
        $logger->error("Could not unzip $zipfile");
        return 666;
    }
    return $return;
}

sub replaceSpaces {
    my ( $var1, $var2 ) = @_;
    $var1 =~ s/\s+/_/g;
    $var2 =~ s/\s+/_/g;
    return ( $var1, $var2 );
}

sub toFoswikiname {
    my $name = shift;

# first convert all non-alphanumeric characters to underscore
# then capitalize all leading letters
# this needs to be kept in sync with WikiText::Foswiki::Emitter::to_foswikiname
# otherwise the created page and space names will not match the links in the page contents

    $name =~ s/[^a-zA-Z0-9_]/_/g;
    $name =~ s/(\b[a-z]|_[a-z])/uc($1)/eg;
    return $name;
}

1;
