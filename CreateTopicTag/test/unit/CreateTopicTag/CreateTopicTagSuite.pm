package CreateTopicTagSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'CreateTopicTagSuite' }

sub include_tests { qw(CreateTopicTagTests) }

1;
