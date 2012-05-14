package HideInEditModePluginSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'HideInEditModePluginSuite' }

sub include_tests { qw(HideInEditModePluginTests) }

1;
