#!/usr/bin/perl
use lib '../bin';
require 'setlib.cfg';

use TDB_File;
use TWiki;

my $t = new TWiki();    # to force read of the config hash

print "Dumping $TWiki::cfg{Plugins}{WebDAVPlugin}{DAVLockDB}/TWiki\n";

tie( %hash, 'TDB_File',
    $TWiki::cfg{Plugins}{WebDAVPlugin}{DAVLockDB} . '/TWiki',
    TDB_File::TDB_DEFAULT, Fcntl::O_RDONLY, 0666 )
  || die "open failed $!";
foreach $key ( keys %hash ) {
    print "$key => $hash{$key}\n";
}
untie(%hash);
