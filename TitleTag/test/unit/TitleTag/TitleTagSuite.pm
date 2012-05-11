package TitleTagSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'TitleTagSuite' }

sub include_tests { qw(TitleTagTests) }

1;
