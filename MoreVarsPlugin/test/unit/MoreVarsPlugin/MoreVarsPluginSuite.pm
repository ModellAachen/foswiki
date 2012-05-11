package MoreVarsPluginSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'MoreVarsPluginSuite' }

sub include_tests { qw(MoreVarsPluginTests) }

1;
