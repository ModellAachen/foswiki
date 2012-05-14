package ExampleHeaderArtContribSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'ExampleHeaderArtContribSuite' }

sub include_tests { qw(ExampleHeaderArtContribTests) }

1;
