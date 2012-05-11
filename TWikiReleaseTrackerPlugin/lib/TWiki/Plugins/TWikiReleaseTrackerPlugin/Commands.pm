package TWiki::Plugins::TWikiReleaseTrackerPlugin::Commands;

use strict;
use diagnostics;
use vars qw($testDir $twikiBin);
use Cwd;
use FileHandle;

use lib "lib/TWiki/Plugins/TWikiReleaseTrackerPlugin"
  ;    # SMELL - this package needs moving into the twikiheirarchy

my %settings;

# TODO: printIfVerbose has to pass config because this is not an object
# TODO: fix TWikiPrefix in the settings.
# TODO: DIFFWIKI should be printIfTerse
# TODO: consider File::Glob for filter results

my $EMPTY = "FILTERMEOUT";

# In new, NB fscdFormat should not be necessary - it should not be returning this as a result as this is not an FSCD query!
# NB2 can't set a parameter to "" so we end up with crap results.

# In changed,  NB fdcdFormat should not be necessary - it should not be returning this as a result as this is not an FDCD query!

BEGIN {
    print "Start directory = " . cwd() . "\n";

}

%settings = (
    from => 'localInstallation',
    to   => 'TWiki20040901',
);

# Quick hack
my %addThese = (
        new => 'from="'
      . $settings{from} . '"' . ' to="'
      . $settings{to} . '"'
      . ' statusFilter="FDCD" fdcdFormat="$relativeFile"'
      . ' fscdFormat="'
      . $EMPTY
      . '" headerFormat="'
      . $EMPTY . '"',

    changed => 'from="'
      . $settings{from} . '"' . ' to="'
      . $settings{to} . '"'
      . ' statusFilter="FSCD" fscdFormat="$relativeFile"'
      . ' fdcdFormat="'
      . $EMPTY
      . '" headerFormat="'
      . $EMPTY . '"',

    different => 'from="'
      . $settings{from} . '"' . ' to="'
      . $settings{to} . '"'
      . ' statusFilter="FSCD,FDCD" fscdFormat="M $relativeFile"'
      . ' fdcdFormat="A $relativeFile" headerFormat="'
      . $EMPTY . '"',

    fileDiffParams => '-u',

    zipname  => "new.zip",
    diffname => "new.diff",

    debug => 0,

    shellwd  => cwd(),
    pluginwd => cwd() . "/bin",

);

%settings = ( %settings, %addThese );

use Data::Dumper;

use TWiki::Plugins::TWikiReleaseTrackerPlugin::FileDigest;
use TWiki::Plugins::TWikiReleaseTrackerPlugin::TRTConfig;

use TWiki;
use TWiki::Plugins;
use TWiki::Func;

$Common::installationDir =
  $settings{shellwd};    # SMELL - hack til have env var for this

unless ( eval "use TWiki::Plugins::TWikiReleaseTrackerPlugin" ) {
    print "$@\n";
}
TWiki::Plugins::TWikiReleaseTrackerPlugin::initPlugin( "WebHome", "TWiki",
    "Main.WikiGuest", "TWiki" );

sub loadIndexes {
    TWiki::Plugins::TWikiReleaseTrackerPlugin::FileDigest::loadIndexes(
        "pub/TWiki/TWikiReleaseTrackerPlugin");
}

BEGIN {
    mkdir("pub/TWiki/DistributionContrib/");
    loadIndexes();
}

sub smry_diff {
    return "show a diff of installation, using to= and from= parameters";
}

sub help_diff {
    print <<'EOM';
You must supply parameters. e.g.
    from="localInstallation" to="TWiki20040901" statusFilter="FDCD" fdcdFormat="$relativeFile" headerFormat=""
Full list:
    http://www.twiki.org/cgi-bin/view/Plugins/TWikiReleaseTrackerPlugin#Parameters_to_the_DIFFWIKI_
EOM
}

=pod
$fh must exist
=cut

sub diff {
    my ( $self, $config, $resultFilter, $fh ) = @_;
    printIfDebug( "FH = " . $fh );

    my @files = doDiffWiki( $settings{changed} );

    printIfVerbose( $config, "filtering by regex $resultFilter\n" );
    my @filtered = grep { $_ =~ $resultFilter } @files;

    foreach my $file (@filtered) {
        print $fh ( doDiffFile( $self, $config, $file ) );
    }
    printIfVerbose( $config,
        ( $#filtered + 1 ) . " file(s) written to diff\n" );
}

sub run_diff {
    my ( $self, $config ) = ( shift, shift );
    my $resultFilter = shift;

    diff( $self, $config, $resultFilter, \*STDOUT );

    printIfVerbose( $config,
"DANGER!: You must turn off verbose if you intend to use the above output with patch (better to use savediff)!"
    );
}

sub smry_savediff {
    return "savediff filename regex-pattern - saves diff to filename";

}

sub run_savediff {
    my ( $self, $config ) = ( shift, shift );
    my $filename = shift || $settings{diffname};
    my $resultFilter = shift;

    my $backupMessage;
    if ( -f $filename ) {
        my $backup = $filename . ".trtbackup";
        rename( $filename, $backup );
        $backupMessage = "Moved existing $filename to $backup";
    }

    my $fh = new FileHandle( $filename, "w" ) || "die can't write to $filename";
    diff( $self, $config, $resultFilter, $fh );
    $fh->close();

    printIfTerse( $config, "Written $filename" );
    printIfTerse( $config, $backupMessage ) if ($backupMessage);
}

#####################################

sub smry_diffwiki {
    return "Access to the TRT's raw diffwiki command";
}

sub run_diffwiki {
    my ( $self, $config, $params, $resultFilter ) = @_;
    doDiffWiki( $params, $resultFilter );
}

# Interface to the plugin

sub doDiffWiki {
    my ( $params, $resultFilter ) = @_;

    chdir( $settings{pluginwd} ) || warn "Can't cd to $settings{pluginwd}";
    my @diffWikiAns =
      TWiki::Plugins::TWikiReleaseTrackerPlugin::handleDiffWiki($params);
    chdir( $settings{shellwd} ) || warn "Can't cd to $settings{shellwd}";

    printIfDebug("Prefiltered results:");
    printIfDebug( join( "\n", @diffWikiAns ) );

    my @ans = sortAndFilterAnswer( @diffWikiAns, $resultFilter );

    printIfDebug("\n\nSorted and filtered results:");
    printIfDebug( join( "\n", @ans ) . "\n\n" );

    print "DIFFWIKI{$params}\n";
    return wantarray
      ? @ans
      : join( "\n", @ans );

}

##############################################

# cant Set Empty Parameter

sub sortAndFilterAnswer {
    my ( $nlBuffer, $resultFilter ) = @_;
    my @nlList = split /\n/, $nlBuffer;
    s!twiki/!! for @nlList;    ### SMELL HACK TWikiPrefix
    my @unbroken =
      grep { $_ !~ $EMPTY } @nlList;    ## SMELL HACK Params cant be set empty

    my @filtered;
    if ($resultFilter) {
        print "filtering by regex $resultFilter\n"
          ;                             #TODO: printIfVerbose, but no config
        @filtered = grep { $_ =~ $resultFilter } @unbroken;
    }
    else {
        @filtered = @unbroken;
    }

    my @ans = sort @filtered;

}

=pod
TODO: remove assumption that there is a common base dir.
=cut

sub smry_zipnew {
    return "zip up all files in installation but not in distribution";
}

sub run_zipnew {
    my $self         = shift;
    my $config       = shift;
    my $filename     = shift || $settings{zipname};
    my $resultFilter = shift;

    my @files = doDiffWiki( $settings{new}, $resultFilter );
    printIfVerbose( $config, "Changing to " . cwd() );
    unlink $filename;
    my $cmd = "zip " . $filename . " " . join( " ", @files );

    #my $ans = `$cmd`;
    my ($ans) = $sandbox->sysCommand($cmd);
    printIfVerbose( $config, "$cmd:\n " . $ans );
    printIfVerbose( $config, "File saved as " . $filename );
}

sub smry_status {
    return
      "status of what is different: i.e. changed or new files in installation";
}

sub run_status {
    my $self         = shift;
    my $config       = shift;
    my $resultFilter = shift;
    my $different    = $settings{different};

    my @different = doDiffWiki( $different, $resultFilter );

    print join( "\n", @different ) . "\n";

}

sub smry_listnew {
    return "list only files in installation not in distribution";
}

#=pod
#Shows what has been added
#=cut
sub run_listnew {
    my $self         = shift;
    my $config       = shift;
    my $resultFilter = shift;

    my $new = $settings{new};

    print scalar doDiffWiki( $new, $resultFilter );

}

sub smry_listchanged {
    return "list only changed files in installation";
}

sub run_listchanged {
    my $self         = shift;
    my $config       = shift;
    my $resultFilter = shift;
    my $changed      = $settings{changed};

    print scalar doDiffWiki( $changed, $resultFilter );
}

sub disabled_run_diffall {
    my $self   = shift;
    my $config = shift;
    my $params = shift;

    my @new     = doDiffWiki( $settings{new} );
    my @changed = doDiffWiki( $settings{changed} );

    print "Not implemented";

    # diff -N
}

sub smry_indexlocal {
    return "creates the checksum index for your localInstallation";
}

sub run_indexlocal {
    my $self   = shift;
    my $config = shift;

    print IndexDistributions::indexLocalInstallation()
      ;    # SMELL - should we be going through DIFFWIKI?

}

#belongs in Ext::Unix or Ext::CLI?
sub smry__ {
    return "Shell escape";

}

sub run__ {
    my $self    = shift;
    my $config  = shift;
    my $command = join( " ", @_ );

    #my $ans = `$command`;
    my ($ans) = $sandbox->sysCommand($command);
    print $ans;

}

sub run_cwd {
    print cwd() . "\n";
}

sub doDiffFile {
    my ( $self, $config ) = ( shift, shift );
    my $file = shift;

    chdir( $settings{pluginwd} ) || warn "Can't cd to $settings{pluginwd}";

    my ( $output, $changeExpression, $cmd ) =
      TWiki::Plugins::TWikiReleaseTrackerPlugin::diffFiles( $file,
        $settings{from}, $settings{to}, $settings{fileDiffParams} );

    chdir( $settings{shellwd} ) || warn "Can't cd to $settings{shellwd}";

    printIfVerbose( $config, "Change Expression: $changeExpression" );
    printIfVerbose( $config, "Cmd: $cmd" );
    return $output;

    #  return ( $output, $changeExpression, $cmd );
}

sub smry_settings {
    return "see the TRT parameter settings";
}

sub run_settings {
    my ( $self, $config, $key, $value ) = @_;

    if ( !$key ) {
        print Dumper( \%settings ) . "\n";
        return;
    }

    if ( !defined $value ) {
        print "$key = " . $settings{$key} . "\n";
        return;
    }
    $settings{$key} = $value;

    print "$key = " . $settings{$key} . "\n";
    printIfDebug( "" . Dumper( \%settings ) ) . "\n";

}

sub smry_swap {
    return "swap the to= and from= parameters";
}

sub run_swap {
    my ( $self, $config, $key, $value ) = @_;

    ( $settings{from}, $settings{to} ) = ( $settings{to}, $settings{from} );
    printIfTerse( $config,
        "from = " . $settings{from} . ", to = " . $settings{to} );
}

sub smry_to {
    return "set the to= parameter setting";
}

sub run_to {
    my ( $self, $config ) = ( shift, shift );
    my $dist = shift;
    if ($dist) {
        $settings{to} = $dist;
    }
    printIfVerbose( $config, "to: " . $settings{to} );
}

sub smry_from {
    return "set the from= parameter setting";

}

sub run_from {
    my ( $self, $config ) = ( shift, shift );
    my $dist = shift;
    if ($dist) {
        $settings{from} = $dist;
    }
    printIfVerbose( $config, "from: " . $settings{from} );
}

sub printIfVerbose {
    my ( $config, $message ) = @_;

    if ( $config->{verbosity} > 1 ) {
        print $message. "\n";
    }

}

=pod 
---++ message ($config, $level, $message)
if (level > current verbosity) then print message + NL

=cut 

sub printIfTerse {
    my ( $config, $message ) = @_;

    if ( $config->{verbosity} > 0 ) {
        print $message. "\n";
    }

}

sub printIfDebug {
    my ($message) = @_;

    if ( $settings{debug} > 0 ) {
        print $message. "\n";
    }

}

1;

