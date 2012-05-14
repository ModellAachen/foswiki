package CliRunnerContribSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'CliRunnerContribSuite' }

sub include_tests { qw(CliRunnerContribTests) }

1;
