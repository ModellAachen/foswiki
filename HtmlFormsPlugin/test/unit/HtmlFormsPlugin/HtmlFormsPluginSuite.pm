package HtmlFormsPluginSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'HtmlFormsPluginSuite' }

sub include_tests { qw(HtmlFormsPluginTests) }

1;
