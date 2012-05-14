#! /bin/perl -w

use strict;
use FileDigest;

#FileDigest::loadIndexes("test"); # should print loading indexes

FileDigest::loadIndexes("/home/mrjc/mbawiki.com/twiki/pub/TWiki/TRTTestSuite/");
print FileDigest::dataOutline();
