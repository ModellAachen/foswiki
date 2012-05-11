package WorkflowReportsContribSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'WorkflowReportsContribSuite' }

sub include_tests { qw(WorkflowReportsContribTests) }

1;
