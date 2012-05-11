package TWiki::Contrib::TWikiShellContrib::Zip;

use Exporter;
use TWiki::Contrib::TWikiShellContrib::Common;

@ISA    = (Exporter);
@EXPORT = qw(checkUnzipMechanism unzip zip);

use strict;

=pod
---++ TWiki::Contrib::TWikiShellContrib::Zip

Provides services to manipulate zip files.

=cut

=pod

---+++ unzip($config,$sourceFile,$targetDir)

Unzips $sourceFile to $targetDir. It's uses ==Archive::Zip== if installed, or the configured unzip program if not.

=cut

sub unzip {
    my ( $config, $sourceFile, $destDir ) = @_;

    $config->printVeryVerbose("--> Inflating $sourceFile to $destDir\n");

    if ( $config->{ZIP}{useArchiveZip} ) {

# Wrapped in eval to prevent a compilation error if Archive::Zip is not installed.
        eval("use Archive::Zip;");
        eval {
            my $zip     = Archive::Zip->new($sourceFile);
            my @members = $zip->members();
            foreach my $member (@members) {
                $zip->extractMember( $member->fileName(),
                    $destDir . "/" . $member->fileName() );
                $config->printVeryVerbose(
                    "   --> Inflating " . $member->fileName() . "\n" );
            }
        };
    }
    else {
        system( $config->{ZIP}{unzipPath}
              . " $sourceFile "
              . $config->{ZIP}{unzipParams}
              . " $destDir" );
    }
    print "\n";
}

sub _useArchiveZip {
    my $config = shift;
    return ( defined $config->{ZIP}{useArchiveZip}
          && $config->{ZIP}{useArchiveZip} eq 1 );
}

sub _useUnzip {
    my $config = shift;
    return ( defined $config->{ZIP}{unzipPath}
          && defined $config->{ZIP}{unzipParams} );
}

sub checkUnzipMechanism {
    my $shell  = shift;
    my $config = $shell->{config};
    if (   _useArchiveZip($config)
        || _useUnzip($config) )
    {
        $shell->printVeryVerbose("**** Zip file services installed ****\n");
        return;
    }

    $shell->printNotQuiet("**** Configuring Zip files service ****\n");

    $shell->printNotQuiet(" * Checking if Archive::Zip is installed .... ");

    eval "use Archive::Zip";
    if ($@) {
        $shell->printNotQuiet("NOT INSTALLED\n");
        $config->{ZIP}{useArchiveZip} = 0;
        _checkUnzipPath($shell);
    }
    else {
        $shell->printNotQuiet("INSTALLED \n");
        $config->{ZIP}{useArchiveZip} = 1;
    }
    $config->save();
    $shell->printNotQuiet("**** Zip files service Configured  ****\n");

}

sub _checkUnzipPath {
    my $shell     = shift;
    my $config    = $shell->{config};
    my $unzipPath = shift || "";        #"/usr/bin/unzip"; # Reasonable Default

    $shell->printNotQuiet(" * Searching an unzip program at $unzipPath .... ");

    if ( $unzipPath && -f $unzipPath ) {
        $shell->printNotQuiet("FOUND\n");
    }
    else {
        $shell->printNotQuiet("NOT FOUND\n");
        $unzipPath = _findUnzipPath($config);
    }
    $config->{ZIP}{unzipPath}   = $unzipPath;
    $config->{ZIP}{unzipParams} = askDirectoryParameter($config);
}

sub askDirectoryParameter {
    my $config = shift;

    my $unzipParam = askUser(
        undef, '-d',
        'Parameter to specify the target directory to unzip',
        sub { return ( $_[0] =~ /^\-\-*[a-zA-Z]+/ ) }, 1
    );

    return $unzipParam;
}

sub _findUnzipPath {
    my $config    = shift;
    my $unzippath = askUser(
        undef, "/usr/bin/unzip",
        "Absolute path to the unzip program",
        sub { return ( -f shift ) }
    );

    return $unzippath;
}

1;
