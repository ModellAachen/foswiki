package ImgPluginSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'ImgPluginSuite' }

sub include_tests { qw(ImgPluginTests) }

1;
