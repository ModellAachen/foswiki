package PhpBB3UsersContribSuite;

use Test::Unit::TestSuite;
our @ISA = qw( Test::Unit::TestSuite );

sub name { 'PhpBB3UsersContribSuite' }

sub include_tests { qw(PhpBB3UsersContribTests) }

1;
