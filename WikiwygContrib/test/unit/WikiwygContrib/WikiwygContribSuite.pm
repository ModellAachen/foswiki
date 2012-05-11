package WikiwygContribSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'WikiwygContribSuite' }

sub include_tests { qw(WikiwygContribTests) }

1;
