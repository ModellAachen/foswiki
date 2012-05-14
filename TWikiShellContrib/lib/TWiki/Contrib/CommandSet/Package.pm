package TWiki::Contrib::CommandSet::Package;

use TWiki::Contrib::TWikiShellContrib::Common;
use TWiki::Contrib::TWikiShellContrib::DirHandling;
use TWiki::Contrib::TWikiShellContrib::Help;
use TWiki::Contrib::TWikiShellContrib::Zip;

use File::Copy;

=pod

---++ TWiki::Contrib::CommandSet::Package

Generates a tarball from all the files in the  TWikiExtension directory.

| *Command* | *Description* |
| package | Generates a tarball for the TWikiExtension|

=cut

my $excludePattern = '(\.svn|\/CVS|\.bak)';

my $doco = {
    "SMRY" =>
      "Generates a tarball from all files in the  TWikiExtension directory.",
    "SYNOPSIS" => " package <TWikiExtension>",
    "DESCRIPTION" =>
      "Generates a tarball from all files in the  TWikiExtension directory",
    "EXAMPLE" => "twikishell package TWikiShellContrib

    Will package all the files under twikiplugins/TWikiShellContrib
    in a tar file..
"
};

sub help {
    my $shell  = shift;
    my $config = shift;
    return assembleHelp( $doco, "SYNOPSIS", "DESCRIPTION", "EXAMPLE" );
}

sub smry {
    return $doco->{'SMRY'};
}

sub run {
    my ( $shell, $config, $project ) = @_;
    print "Packaging $project\n";
    my $srcDir = $config->{TWIKI}{root} . '/twikiplugins';
    my $tmpDir = "$srcDir/$project.tmp." . time();
    mkdir($tmpDir);

    handleDir( $srcDir, $tmpDir, $project );

    cd($tmpDir);
    sys_action( 'tar -cvzf ' . $srcDir . '/' . $project . '.tar.gz *' );
    cd($srcDir);
    sys_action( 'rm -rf ' . $tmpDir );

}

sub handleFile {
    my ( $srcDir, $tmpDir, $file ) = @_;
    return if ( !$file );
    return if $file =~ /$excludePattern/x;
    print "processing $file\n";

    my $targetFile = "$tmpDir/$file";
    makepath($targetFile);

    copy( "$srcDir/$file", $targetFile );
}

sub handleDir {
    my ( $srcDir, $tmpDir, $dir ) = @_;

    return if $dir =~ /$excludePattern/x;
    print "processing $dir\n";

    if ( opendir( DIR, "$srcDir/$dir" ) ) {
        foreach my $file ( readdir DIR ) {
            if ( -f "$srcDir/$dir/$file" ) {
                handleFile( $srcDir, $tmpDir, "$dir/$file" );
            }
            elsif ( -d "$srcDir/$dir/$file" && $file ne '.' && $file ne '..' ) {
                handleDir( $srcDir, $tmpDir, "$dir/$file" );
            }
        }
    }
}

sub readFile {
    my $file = shift;
    print "->$file\n";
    open INBASE, "<$file";
    my @lines = <INBASE>;
    close INBASE;
    return @lines;
}

1;
