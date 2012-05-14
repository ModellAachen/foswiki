package TWiki::Contrib::CommandSet::Apache::Httpd;

use File::Copy;

use vars qw(@ISA @EXPORT $lastLine);

@ISA    = qw(Exporter);
@EXPORT = qw(
  deleteInstallFromApacheConfig
  addInstallToApacheConfig
);

$lastLine = "#################################################\n";

sub deleteInstallFromApacheConfig {
    my ( $shell, $config, $path ) = @_;
    my $apacheCfgFile = $config->{APACHE}{httpd};
    $shell->printVerbose("Deleting $path from $apacheCfgFile\n");

    if ( !-e $apacheCfgFile ) {
        print "Can't delete $path: $apacheCfgFile not found.\n";
        return;
    }

    my $backupFile = backupCfgFile( $shell, $apacheCfgFile );

    $shell->printVerbose("   * Readig old $apacheCfgFile\n");
    my @lines = readCfgFile($backupFile);
    $shell->printVerbose("   * Writing new $apacheCfgFile\n");

    open OUTBASE, ">$apacheCfgFile";
    my $removeLines = 0;
    my $found       = 0;
    my $basePath    = $path;
    my $firstLine   = firstLine($path);

    foreach my $line (@lines) {
        if ( $line =~ /$firstLine/ ) {
            $removeLines = 1;
        }
        elsif ( ( $line =~ /$lastLine/ ) && $removeLines eq 1 ) {
            $removeLines = 0;
            $found       = 1;
        }
        elsif ( !$removeLines ) {
            print OUTBASE $line;
        }
    }
    close OUTBASE;

    if ($found) {
        $shell->printVerbose("$path removed from $apacheCfgFile\n");
    }
    else {
        $shell->printVerbose("Can't delete $path: not found\n");
    }
}

#--------------------------------------------------------------------------------------------------

sub addInstallToApacheConfig {
    my ( $shell, $config, $path ) = @_;
    my $lowercaseBase = lc $base;

    my $twikiRoot = $config->{TWIKI}{root};

    my $basePath = $path;
    my $baseDir  = $twikiRoot;

    my $apacheCfgFile = $config->{APACHE}{httpd};
    $shell->printVerbose("Deleting $path from $apacheCfgFile\n");

    if ( !-e $apacheCfgFile ) {
        print "Can't add $path: $apacheCfgFile not found\n";
        return;
    }

    my $backupFile = backupCfgFile( $shell, $apacheCfgFile );

    $shell->printVerbose("   * Readig old $apacheCfgFile\n");
    my @lines = readCfgFile($backupFile);
    $shell->printVerbose("   * Writing new $apacheCfgFile\n");

    open OUTBASE, ">$apacheCfgFile";
    my $modAlias    = 0;
    my $firstLine   = firstLine($basePath);
    my $quickFinish = 0;
    foreach my $line (@lines) {
        if ( $line =~ /<IfModule mod_alias.c>/ ) {
            $modAlias = 1;
        }
        elsif ( $line =~ /$firstLine/ ) {
            $shell->printVerbose(
                "Can't add $basePath: Already configured in $apacheCfgFile.\n");
            $quickFinish = 1;
            $modAlias    = 2;
        }
        elsif ( ( $line =~ /\<\/IfModule\>/ ) && $modAlias eq 1 ) {
            $modAlias = 2;
            print OUTBASE "    $firstLine
    alias /$basePath/pub $baseDir/pub

    <Directory \"$baseDir/pub\">
         AllowOverride All
         Allow From All
    </Directory>

    alias /$basePath/bin $baseDir/bin
    
    <Directory \"$baseDir/bin\">
         AllowOverride All
         Allow From All
        Options ExecCGI
        SetHandler cgi-script
    </Directory>
    $lastLine";
        }
        print OUTBASE $line;
    }
    close OUTBASE;

    if ( $modAlias != 2 ) {
        $shell->printVerbose(
"Can't add $path: There is no mod_alias.c section in $apacheCfgFile. Please, create it manually and rerun the process\n"
        );
    }
    elsif ( !$quickFinish ) {
        $shell->printVerbose("Added $basePath\n");
    }
    else {
        $shell->printVerbose("\n");
    }
}

sub firstLine {
    my $path = shift;
    return "##################################BEGIN $path";
}

#TODO: These can go to a central service
sub backupCfgFile {
    my ( $shell, $apacheCfgFile ) = @_;
    $shell->printVerbose("   * Creating  backup of $apacheCfgFile\n");
    my $backupFile = $apacheCfgFile . ".sdk" . time . "~";
    copy( $apacheCfgFile, $backupFile );
    return $backupFile;
}

sub readCfgFile {
    my $file = shift;
    open INBASE, "<$file";
    my @lines = <INBASE>;
    close INBASE;
    return @lines;
}
1;
