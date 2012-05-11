package MacrosPluginSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'MacrosPlugin' }

sub include_tests { qw(MacrosTest) }

1;
