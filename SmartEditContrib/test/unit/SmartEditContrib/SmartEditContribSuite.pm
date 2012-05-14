package SmartEditContribSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'SmartEditContribSuite' }

sub include_tests { qw(SmartEditContribTests) }

1;
