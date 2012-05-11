package FreeMarkerPluginSuite;
use strict;

use Unit::TestSuite;
our @ISA = 'Unit::TestSuite';

sub include_tests {
    qw(FreeMarkerParserTests FreeMarkerPluginTests AttributeParserTests ConfigureTemplateTests);
}

1;
