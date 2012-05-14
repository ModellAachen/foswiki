package InclTagSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'InclTagSuite' }

sub include_tests { qw(InclTagTests) }

1;
