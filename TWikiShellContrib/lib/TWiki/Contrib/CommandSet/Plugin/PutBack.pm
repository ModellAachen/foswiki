package TWiki::Contrib::CommandSet::Plugin::PutBack;

use TWiki::Contrib::TWikiShellContrib::DirHandling;
use TWiki::Contrib::BuildContrib::BaseBuild;
use TWiki::Contrib::TWikiShellContrib::Help qw{assembleHelp};

use File::Copy;

my $doco = {
    "SMRY"     => "Put back Plugin/Contrib files into their checkout area",
    "SYNOPSIS" => " plugin putback <Plugin/Contrib>",
    "DESCRIPTION" =>
      " This command will copy the files listed in the <PLUGINNAME>.MF file
 back to the twikiplugins/<PLUGINNAME> directory, to be able to 
 update the sources in the repository and/or run the build.pl 
 script from there.
",
    "EXAMPLE" => " twikishell plugin putback TWikiShellContrib

    Will copy all the files listed in TWikiShellContrib.MF to
    the from twikiplugins/TWihiShellContrib directory.
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
    my $srcDir = $config->{TWIKI}{root};
    my $tmpDir = "$srcDir/twikiplugins/$project";

    my $manifestFile = $srcDir . '/' . $project . '.MF';
    my ( $files, $otherModules ) = readManifest( $srcDir, '', $manifestFile );

    return unless $files;
    foreach my $fileData ( @{$files} ) {
        my $file = $fileData->{name};
        handleFile( $srcDir, $tmpDir, $file );
    }
    handleFile( $srcDir, $tmpDir, $project . '.DEP' );
    handleFile( $srcDir, $tmpDir, $project . '.MF' );

    #TODO: Filter build.pl from the manifest file

}

sub handleFile {
    my ( $srcDir, $tmpDir, $file ) = @_;
    return if ( !$file );
    print "processing $file\n";

    my $targetFile = "$tmpDir/$file";
    if ( $targetFile =~ /(.+\/)?(.+\.DEP)/ ) {
        $targetFile =~ s/$2/DEPENDENCIES/;
    }
    elsif ( $targetFile =~ /(.+\/)?(.+\.MF)/ ) {
        $targetFile =~ s/$2/MANIFEST/;
    }

    makepath($targetFile);

    copy( "$srcDir/$file", $targetFile );
}

1;

