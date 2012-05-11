package EmptyContribSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'EmptyContribSuite' }

sub include_tests { qw(EmptyContribTests) }

1;
