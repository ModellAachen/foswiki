package TWiki::Contrib::CommandSet::RunTest::Conf;

use TWiki::Contrib::TWikiShellContrib::Common;

use vars qw($config);

use Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(configure cfg);

sub configure {
    my $shell = shift;
    $config = shift;

    my $testDir = $config->{TWIKI}{root} . "/test/unit";

    $config->{RUNTEST}{dir} = askUser(
        $config->{RUNTEST}{dir},  $testDir,
        "Path to the unit tests", \&checkIfDir
    );

    $config->{RUNTEST}{asserts} = $config->{RUNTEST}{asserts} || 1;

    $config->save();

}

sub cfg {
    return $config->{RUNTEST}{ $_[0] };
}

1;
