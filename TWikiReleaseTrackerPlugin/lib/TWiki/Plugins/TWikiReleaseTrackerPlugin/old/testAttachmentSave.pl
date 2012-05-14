#! /usr/local/bin/perl -w
use strict;
use diagnostics;

BEGIN {
    chdir "../../../../bin" || die $!;
}

use lib "../lib";

use TWiki;
use TWiki::Store;
use TWiki::Store::RcsWrap;
require "TWiki.cfg";

TWiki::Store::saveAttachment( "System", "TWikiReleaseTracker", "",
    "testAttachmentSave.pl", 0, 0, 0, "test upload", "testAttachmentSave.pl" );

