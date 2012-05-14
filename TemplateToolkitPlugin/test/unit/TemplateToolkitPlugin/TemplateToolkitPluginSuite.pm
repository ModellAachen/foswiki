package TemplateToolkitPluginSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'TemplateToolkitPluginSuite' }

sub include_tests { qw(TemplateToolkitPluginTests) }

1;
