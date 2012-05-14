package LoadTagsPluginSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'LoadTagsPluginSuite' }

sub include_tests { qw(LoadTagsPluginTests) }

1;
