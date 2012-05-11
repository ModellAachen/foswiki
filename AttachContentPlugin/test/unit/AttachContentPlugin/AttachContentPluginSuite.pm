package AttachContentPluginSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'AttachContentPluginSuite' }

sub include_tests { qw(AttachContentPluginTests) }

1;
