package EmptyHeaderArtContribSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'EmptyHeaderArtContribSuite' }

sub include_tests { qw(EmptyHeaderArtContribTests) }

1;
