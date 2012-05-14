package ImgTagSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'ImgTagSuite' }

sub include_tests { qw(ImgTagTests) }

1;
