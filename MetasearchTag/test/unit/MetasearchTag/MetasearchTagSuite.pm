package MetasearchTagSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'MetasearchTagSuite' }

sub include_tests { qw(MetasearchTagTests) }

1;
