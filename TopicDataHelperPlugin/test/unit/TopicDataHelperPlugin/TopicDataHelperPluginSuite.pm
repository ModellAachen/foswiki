package TopicDataHelperPluginSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'TopicDataHelperPluginSuite' }

sub include_tests { qw(TopicDataHelperPluginTests) }

# run with
# sudo -u www perl ../bin/TestRunner.pl -clean TopicDataHelperPlugin/TopicDataHelperPluginSuite.pm

1;
