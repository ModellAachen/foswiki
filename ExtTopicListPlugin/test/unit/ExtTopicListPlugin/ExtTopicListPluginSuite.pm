package ExtTopicListPluginSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'ExtTopicListPluginSuite' }

sub include_tests { qw(ExtTopicListPluginTests) }

1;
