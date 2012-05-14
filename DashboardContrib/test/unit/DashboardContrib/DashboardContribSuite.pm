package DashboardContribSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'DashboardContribSuite' }

sub include_tests { qw(DashboardContribTests) }

1;
