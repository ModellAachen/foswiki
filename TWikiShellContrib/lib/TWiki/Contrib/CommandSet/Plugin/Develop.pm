package TWiki::Contrib::CommandSet::Plugin::Develop;
use strict;
use TWiki::Contrib::TWikiShellContrib::DirHandling;
use TWiki::Contrib::TWikiShellContrib::Help qw{assembleHelp};
use TWiki::Contrib::TWikiShellContrib::Common;

use TWiki::Contrib::BuildContrib::BaseBuild;

use File::Copy;

use vars qw {$MANIFEST $DEPENDENCIES};

( $MANIFEST, $DEPENDENCIES ) = ( 'MANIFEST', 'DEPENDENCIES' );

my $doco = {
    "SMRY"     => "Prepares the file of a Plugin/Contrib for development",
    "SYNOPSIS" => " plugin develop <Plugin/Contrib>",
    "DESCRIPTION" =>
      " This command will copy all the related files for a Plugin/Contrib
 from the \${TWIKIROOT}/twikiplugins directory to the proper place 
 under the \${TWIKIROOT} directory, while creating a manifest file 
 in the \${TWIKIROOT} with all the files copied.
 This is an alternative to the =mklinks.sh -copy=  command.

",
    "EXAMPLE" => " twikishell plugin develop TWikiShellContrib

    Will copy all the files from twikiplugins/TWihiShellContrib to
    their proper place and create the TWikiShellContrib.MF file 
    under \${TWIKIROOT}.   
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
    my $shell      = shift;
    my $config     = shift;
    my $plugin     = shift;
    my $pluginsDir = $config->{TWIKI}{root} . "/twikiplugins";
    my $srcDir     = $pluginsDir . '/' . $plugin;
    my $targetDir  = $config->{TWIKI}{root};
    my $manifestFile =
      findRelativeTo( $srcDir . '/' . makeExtensionPath($plugin), 'MANIFEST' );
    my $dependenciesFile =
      findRelativeTo( $srcDir . '/' . makeExtensionPath($plugin),
        'DEPENDENCIES' );

    if ($manifestFile) {
        my ( $files, $otherModules ) =
          readManifest( $srcDir, '', $manifestFile );
        return unless $files;

        foreach my $fileData ( @{$files} ) {
            my $file = $fileData->{name};
            next if ( !$file );
            print "processing $file\n";
            my $targetFile = "$targetDir/$file";
            makepath($targetFile);
            copy( "$srcDir/$file", $targetFile );
        }
        copy( $manifestFile, $config->{TWIKI}{root} . '/' . $plugin . '.MF' );
        copy( $dependenciesFile,
            $config->{TWIKI}{root} . '/' . $plugin . '.DEP' )
          if $dependenciesFile;

    }
    else {

#If the manifest file is not found, just process everything in the plugin directory
        $manifestFile = $config->{TWIKI}{root} . '/' . $plugin . '.MF';

        my @files = _processDir(
            $shell,
            $pluginsDir . "/" . $plugin,
            $config->{TWIKI}{root},
            '', $plugin
        );

        $shell->printVerbose('Generating Manifest file');

        open MANIFEST, ">$config->{TWIKI}{root}/$plugin.MF";
        foreach my $file (@files) {
            $file =~ s/$config->{TWIKI}{root}\///;
            print MANIFEST $file . "\n";
        }
        close MANIFEST;
    }

}

sub _processDir {
    my ( $shell, $srcDir, $targetDir, $currentDir, $plugin ) = @_;

    my $currentSrcDir    = $srcDir;
    my $currentTargetDir = $targetDir;

    if ($currentDir) {
        $currentSrcDir    .= "/" . $currentDir;
        $currentTargetDir .= "/" . $currentDir;
    }

    my @files;
    my @entries = dirEntries($currentSrcDir);
    foreach my $entry (@entries) {
        next if ( $entry =~ /^\.+$/ || $entry =~ /\.svn/ );

        my $src = "$currentSrcDir/$entry";

        my $targetEntry = '';
        if ( $entry =~ /$MANIFEST/x ) {
            $targetEntry =
              $shell->{config}->{TWIKI}{root} . '/' . $plugin . '.MF';
        }
        elsif ( $entry =~ /$DEPENDENCIES/x ) {
            $targetEntry =
              $shell->{config}->{TWIKI}{root} . '/' . $plugin . '.DEP';
        }
        elsif ( $entry =~ /^.+?(\.tar\.gz|\.zip|\.tgz|_installer\.pl)/x ) {
            next;
        }
        else {
            $targetEntry = $currentTargetDir . '/' . $entry;
        }

        $shell->printVeryVerbose("Processing $src\n");

        if ( -d $src ) {
            _processDir( $shell, $currentSrcDir, $currentTargetDir, $entry,
                $plugin );
        }
        elsif ( -f $src ) {
            if ( -f $currentTargetDir . '/' . $entry ) {
                unlink $currentTargetDir . '/' . $entry;
            }

            makepath( $currentTargetDir . '/' . $entry );
            $shell->printVerbose(
                'copying ' . $entry . ' to ' . $targetEntry . "\n" );

            copy( $src, $targetEntry )
              || warn "Warning: Failed to copy $src to $currentTargetDir: $!";

            push( @files, $targetEntry )
              unless $entry =~ /($MANIFEST|$DEPENDENCIES)/;
        }
        else {
            warn "Something Happened with $src\n";
        }

    }
    return @files;
}

1;

