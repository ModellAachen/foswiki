package TWiki::Contrib::CommandSet::Plugin::Create;
use strict;

use TWiki::Contrib::TWikiShellContrib::Help qw{assembleHelp};

use File::Copy;
use File::Path;

my $doco = {
    "SMRY"     => "Creates the suggested directory structure for a new plugin",
    "SYNOPSIS" => " plugin create <TWikiExtension>",
    "DESCRIPTION" =>
      " This command will creates the directory twikiplugins/<Plugin/Contrib> 
 with the following structure;
  twikiplugins/
     <TWikiExtension>/
        data/
           TWiki/
              <TWikiExtension>.txt
        lib/
           TWiki/
              [Plugin|Contrib]/
                 <TWikiExtension>.pm
                 <TWikiExtension>/
                    build.pl
        pub/
           TWiki/
              <TWikiExtension>/

 To create the files, this command uses the templates distributed
 in lib/TWiki/Contrib/CommandSet/Plugin/Create and the EmptyPlugin.pm file.

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
    my ( $shell, $config, $project, $option ) = @_;

    my $rootDir = $config->{TWIKI}{root};
    my ( $projectDir, $dataDir, $pubDir, $libDir ) =
      _buildDirNames( $shell, $rootDir, $project, $option );

    mkpath( $libDir . '/' . $project, $config->{verbosity} );
    mkpath( $dataDir,                 $config->{verbosity} );
    mkpath( $pubDir,                  $config->{verbosity} );

    _createBuildScript( $project, $rootDir, $libDir );
    _copyEmptyPlugin( $project, $rootDir, $libDir );
    _createTWikiTopic( $project, $rootDir, $dataDir );

}

sub _buildDirNames {
    my ( $shell, $rootDir, $project, $option ) = @_;

    my $projectDir = $rootDir . '/twikiplugins/' . $project;
    my $dataDir    = $projectDir . '/data/TWiki';
    my $pubDir     = $projectDir . '/pub/TWiki/' . $project;

    my $libDir = $projectDir . '/lib/TWiki/';
    if ( $project =~ /[a-zA-Z]+Contrib$/ ) {
        $libDir .= 'Contrib';
    }
    else {
        $libDir .= 'Plugins';
    }

    $shell->printVerbose("projectDir: $projectDir\n");
    $shell->printVerbose("dataDir: $dataDir\n");
    $shell->printVerbose("pubDir: $pubDir\n");
    $shell->printVerbose("libDir: $libDir\n");

    return ( $projectDir, $dataDir, $pubDir, $libDir );
}

sub _createBuildScript {
    my ( $project, $rootDir, $libDir ) = @_;
    my $buildTemplate =
      'lib/TWiki/Contrib/CommandSet/Plugin/Create/build.pl_template';
    my $inFile    = $rootDir . '/' . $buildTemplate;
    my $outFile   = $libDir . '/' . $project . '/build.pl';
    my $transform = sub {
        my $content = shift;
        $content =~ s/%PLUGIN%/$project/gx;
        return $content;
    };

    _buildFromTemplate( $inFile, $outFile, $transform );
}

sub _copyEmptyPlugin {
    my ( $project, $rootDir, $libDir ) = @_;
    my $inFile    = $rootDir . '/lib/TWiki/Plugins/EmptyPlugin.pm';
    my $outFile   = $libDir . '/' . $project . '.pm';
    my $transform = sub {
        my $content = shift;
        $content =~ s/EmptyPlugin/$project/gx;
        $content =~ s/\$VERSION = '.*?\;/\$VERSION = '1.000';/g;
        return $content;
    };

    _buildFromTemplate( $inFile, $outFile, $transform );

}

sub _createTWikiTopic {
    my ( $project, $rootDir, $dataDir ) = @_;
    my $inFile = $rootDir
      . '/lib/TWiki/Contrib/CommandSet/Plugin/Create/TWikiPlugin.txt_template';
    my $outFile   = $dataDir . '/' . $project . '.txt';
    my $transform = sub {
        my $content = shift;
        my $text    = uc $project;
        $content =~ s/%PLUGIN%/$text/gx;
        return $content;
    };

    _buildFromTemplate( $inFile, $outFile, $transform );
}

sub _buildFromTemplate {
    my ( $inFile, $outFile, $transform ) = @_;

    open IN, "<$inFile";
    my @content = <IN>;
    close IN;
    my $content = join( "", @content );

    $content = &$transform($content);

    open OUT, ">$outFile";
    print OUT $content;
    close OUT;
}

1;

