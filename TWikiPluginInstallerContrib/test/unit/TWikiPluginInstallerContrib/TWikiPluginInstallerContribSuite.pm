package TWikiPluginInstallerContribSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'TWikiPluginInstallerContribSuite' }

sub include_tests { qw(TWikiPluginInstallerContribTests) }

1;
