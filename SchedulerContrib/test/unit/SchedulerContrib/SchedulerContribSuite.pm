package SchedulerContribSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'SchedulerContribSuite' }

sub include_tests { qw(SchedulerContribTests) }

1;
