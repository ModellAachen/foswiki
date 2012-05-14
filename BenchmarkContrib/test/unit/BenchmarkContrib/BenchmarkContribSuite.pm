package BenchmarkContribSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'BenchmarkContribSuite' }

sub include_tests { qw(BenchmarkContribTests) }

1;
