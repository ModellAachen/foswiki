package TWiki::Contrib::CommandSet::Build;

use TWiki::Contrib::TWikiShellContrib::Help qw{assembleHelp};
use TWiki::Contrib::TWikiShellContrib::DirHandling;
use TWiki::Contrib::TWikiShellContrib::Common;

use File::Copy;

my $doco = {
    'SMRY'     => 'Interfaces with the build.pl script',
    'SYNOPSIS' => " build <TExtension> <target>  - 
    executes build.pl for the given plugin passing the specified <target> ",
    'DESCRIPTION' =>
      " This command provides an interface to the build.pl script. It assumes
that the script is in the standard directory:

\${TROOT}/twikiplugins/<TExtension>/lib/TWiki/[Plugin|Contrib]/<TExtension>

The parameter <target> can be any valid target for the build.pl script. 

"
};

sub help {
    my $shell  = shift;
    my $config = shift;
    return assembleHelp( $doco, "SYNOPSIS", "DESCRIPTION" );
}

sub smry {
    return $doco->{'SMRY'};
}

sub run {
    my ( $shell, $config, $plugin, $target ) = @_;
    my $isContrib = 0;
    $target = $target || 'test';

    my $rootDir = $config->{TWIKI}{root};
    $ENV{TWIKI_LIBS} = $rootDir . '/lib';
    $ENV{TWIKI_ROOT} = $rootDir;
    my $targetDir = $rootDir . '/twikiplugins/' . $plugin . '/lib/TWiki/';
    if ( $plugin =~ /Plugin/ ) {
        $targetDir .= 'Plugins';
    }
    else {
        $targetDir .= 'Contrib';
    }
    $targetDir .= '/' . $plugin;
    $targetDir = findRelativeTo( $targetDir, 'build.pl' );
    $targetDir =~ s/build\.pl//;

    cd($targetDir);
    system("perl build.pl $target");
    cd($rootDir);
}
1;

