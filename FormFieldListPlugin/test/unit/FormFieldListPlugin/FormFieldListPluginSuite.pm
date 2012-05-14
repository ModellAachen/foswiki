package FormFieldListPluginSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'FormFieldListPluginSuite' }

sub include_tests { qw(FormFieldListPluginTests) }

# run with
# sudo -u www perl ../bin/TestRunner.pl -clean FormFieldListPlugin/FormFieldListPluginSuite.pm

1;
