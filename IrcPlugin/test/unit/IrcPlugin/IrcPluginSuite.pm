package IrcPluginSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'IrcPluginSuite' }

sub include_tests { qw(IrcPluginTests) }

1;
