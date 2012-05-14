package FallbackPluginSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'FallbackPluginSuite' }

sub include_tests { qw(FallbackPluginTests) }

1;
