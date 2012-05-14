package TWiki::Contrib::CommandSet::TWiki::Conf;

use TWiki::Contrib::TWikiShellContrib::Common;

use Cwd qw( abs_path );
use Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(configure get);

sub configure {
    my ( $shell, $config ) = @_;

    my ($twikiRoot) = ( $twikiRoot = Cwd::abs_path(".") ) =~ /(.*)/;

    $config->{TWIKI}{root} = askUser(
        $config->{TWIKI}{root},     $twikiRoot,
        "Absolute TWiki root path", \&_checkIfDir
    );
    my $root = $config->{TWIKI}{root};

    $config->{TWIKI}{bin} = askUser(
        $config->{TWIKI}{bin},     "$root/bin",
        "Absolute TWiki bin path", \&_checkIfDir
    );

    $config->{TWIKI}{lib} = askUser(
        $config->{TWIKI}{lib},     "$root/lib",
        "Absolute TWiki lib path", \&_checkIfDir
    );

    $config->{TWIKI}{pub} = askUser(
        $config->{TWIKI}{pub},     "$root/pub",
        "Absolute TWiki pub path", \&_checkIfDir
    );

    $config->save();

}

sub _checkIfDir {
    return ( -d shift );
}

1;
