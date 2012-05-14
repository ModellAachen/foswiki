package TWiki::Contrib::TWikiShellContrib::Standard;

use FileHandle;

sub smry_overview {
    return
"Type 'help overview': outlines the purpose of the twikishell and where to find up-to-date help\n";
}

sub help_overview {
    return <<"HERE";
The twikishell is an extensible command line for TWiki.\nPlugins can add their own commands by creating suitably named classes which are 'imported' into the shell.\nThese can be invoked as scripts.\nSee http://twiki.org/cgi-bin/view/Plugins/TWikiShellContrib for details.\n
HERE
}

##############################
# set verbosity
##############################
sub run_verbose {
    my ( $shell, $config, $level ) = @_;

    if ( !$level ) {
        print "verbosity : $config->{verbosity}\n";
        return;
    }

    if ( $level >= 0 && $level <= 2 ) {
        $config->{verbosity} = $level;
        print "verbosity : $config->{verbosity}\n";
    }
    else {
        print "Unknown verbosity level $level\n";
    }
}

sub smry_verbose { return "Sets the verbosity level (1,2)"; }

sub help_verbose {
    return "Sets the verbosity level
 Level    Effect
   0      No output at all.
   1      Minimun information about the run is displayed (Default)
   2      All information about the run is displayed
   
If called without arguments, show the current verbosity level.   
\n";
}

sub print_debug_level {
    my $debug = shift;
    print "Debug ";
    if ($debug) {
        print "On";
    }
    else {
        print "Off";
    }
    print "\n";
}

sub run_debug {
    my ( $shell, $config, $mode ) = @_;

    if ($mode) {
        if ( uc $mode eq "ON" ) {
            $config->{debug} = 1;
        }
        else {
            $config->{debug} = 0;
        }
    }
    print_debug_level( $config->{debug} );

}

sub smry_debug {
    return "Turn on/off the debugging statements";
}

sub help_debug {
    return "syntax: debug [on|off]\n";
}

sub run_import {
    my ( $shell, $config, $cmd ) = @_;
    $shell->importCommand( $config, $cmd );
}

sub smry_import {
    return "Imports the specified CommandSet";
}

sub help_import {
    return &smry_import() . "
usage: import <name>
if name is a single lowercase word, the prefix 
TWiki::Contrib::TWikiShellContrib::Ext will be added
to determine the module to import. ie:
import dump

will import the CommandSet
TWiki::Contrib::TWikiShellContrib::Ext::Dump

The CommandSet can be anywhere in the " . '@INC' . " path

";
}

sub undefined_run {
    print "Undefined action\n";
}

sub undefined_smry {
    return "undocumented - no help available";
}

sub undefined_help {
    return "undocumented - no help available\n";
}

sub run_shorcuts {
    if ( !-f 'cli' ) {
        `ln -s cli twikishell`;
    }

    _createFile('build');
    _createFile('plugin');
    _createFile('package');
}

sub _createFile {
    my $file = shift;
    if ( !-f $file ) {
        open FILE, ">$file";
        print FILE "perl twikishell $file \$*\n";
        close FILE;
        chmod 0755, $file;
    }
}

sub smry_shorcuts {
    return "creates convenience shellscripts (linux/unix only)";
}

sub help_shorcuts {
    return
"Creates useful shellscripts to shorten the calls to the most commonly used modules (build,plugin). ONLY WORKS ON LINUX\n";
}
1;

