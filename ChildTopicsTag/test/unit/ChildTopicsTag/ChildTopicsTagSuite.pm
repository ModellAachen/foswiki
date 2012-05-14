package ChildTopicsTagSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'ChildTopicsTagSuite' }

sub include_tests { qw(ChildTopicsTagTests) }

1;
