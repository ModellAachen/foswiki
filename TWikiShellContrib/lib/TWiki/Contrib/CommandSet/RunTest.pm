package TWiki::Contrib::CommandSet::RunTest;
use TWiki::Contrib::CommandSet::RunTest::Conf;

use Test::Unit::Debug qw(debug_pkgs);
use Test::Unit::TestRunner;

use strict;

sub run_assert {
    my $shell  = shift;
    my $config = shift;
    my $assert = shift;
    $config->{RUNTEST}{assert} = $assert if $assert;

    my $assertStatus = 'Off';
    $assertStatus = 'On' if $config->{RUNTEST}{assert};

    $shell->printVerbose( 'Assert ' . $assertStatus . "\n" );
}

sub help_assert {
    return 'Not implemented';
}

sub smry_assert {
    return 'Not implemented';
}

sub help {
    return 'Not implemented';
}

sub smry {
    return 'Not implemented';
}

sub run {
    my $shell  = shift;
    my $config = shift;
    my @argv   = shift;

#cases:
#
# a) Name Alone ($test=TWikiShellContrib) or a path ($test=TWikiShellContrib/SomeTest);
#    a.1) Is a module
#    a.2) Is a directory
#    a.3) Both
# b) A .pm ($test=TWikiShellContrib/SomeTest.pm)
#    This is the compatible Support, and the only case covered
#
    my $unitTests = $config->{RUNTEST}{dir};
    my $bin       = $config->{TWIKI}{bin};
    my $lib       = $config->{TWIKI}{lib};

    foreach my $arg (@argv) {
        if ( $arg =~ m!(.+)/([^/]+.pm)! ) {
            unshift @INC, $unitTests . '/' . $1;
        }
    }
    unshift @INC, "$unitTests";
    unshift @INC, "$bin";
    unshift @INC, "$lib";

    $ENV{TWIKI_HOME} = $config->{TWIKI}{root};

    if ( defined $ENV{TWIKI_ASSERTS} ) {
        print "TWIKI_ASSERTS is defined, overriding twikishell configuration\n";
    }

    $ENV{TWIKI_ASSERTS} = $ENV{TWIKI_ASSERTS} || $config->{RUNTEST}{asserts};

    if ( $ENV{TWIKI_ASSERTS} == 1 ) {
        print "Assert checking on\n";
    }
    else {
        print "Assert checking off\n";
    }

    # Uncomment and edit to debug individual packages.
    #debug_pkgs(qw/Test::Unit::TestCase/);

    my $testrunner = Test::Unit::TestRunner->new();
    $testrunner->start(@argv);
}

sub onImport {
    my ($shell) = @_;
    configure(@_);
}

1;
