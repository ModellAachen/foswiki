package WebDAVPluginSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'WebDAVPlugin' }

sub include_tests {
    qw(FileSystemTests )    #ServerTest)
}

1;
