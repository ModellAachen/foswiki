
package TWiki::Contrib::TWikiShellContrib::TWikiShell;

use TWiki::Contrib::TWikiShellContrib::Standard;
use TWiki::Contrib::TWikiShellContrib::Common;
use TWiki::Contrib::TWikiShellContrib::Zip;
use Data::Dumper;

#use diagnostics;
use Cwd;
use strict;

use Term::Shell;
our @ISA = qw( Term::Shell );
use vars qw {$VERSION $config $prefix $prefixPath};

$VERSION = "2.01";

my @systemModules = qw (TWiki::Contrib::TWikiShellContrib::Standard);

$prefix     = "TWiki::Contrib::CommandSet";
$prefixPath = $prefix;
$prefixPath =~ s/\:\:/\//g;

my $standardModule = "TWiki::Contrib::TWikiShellContrib::Standard";

sub run_ { }    #Do nothing on empty lines

sub alias_exit { return qw{q quit}; }

sub new {
    my $self = shift;
    $config = shift;
    my $new = $self->SUPER::new(@_);
    $new = bless $new, $self;
    $new->init_handlers($config);
    $new->discover($config);
    $new->{config} = $config;
    TWiki::Contrib::TWikiShellContrib::Zip::checkUnzipMechanism( $new,
        $config );
    return $new;
}

sub splash {
    print "TWiki Interactive Shell v$VERSION
Oct 2005 - written by Rafael Alvarez based on a prototype by MartinCleaver
Type \"help\" for a list of available commands

";
}

sub init_handlers {
    my $self   = shift;
    my $config = shift;

    foreach my $systemModule (@systemModules) {
        $self->find_handlers($systemModule);
    }
}

my $prompt = "twiki";

sub prompt {
    my $self = shift;
    $prompt = shift;
}

sub prompt_str() {
    return "$prompt > ";
}

####################### HANDLERS ##############################################

# Add support for multi-level commands
# Called to find the handler to call for a given command
sub handler {
    my $o = shift;
    my ( $command, $type, $args, $preserve_args ) = @_;

    # First try finding the standard handler, then fallback to the
    # catch_$type method. The columns represent "action", "type", and "push",
    # which control whether the name of the command should be pushed onto the
    # args.
    #         [$config->mode." ".$command, $type, 0],

    my @tries = (
        [ $command,                                $type,   0 ],
        [ $o->cmd_prefix . $type . $o->cmd_suffix, 'catch', 1 ],
    );

    my $concat = "";
    foreach my $arg (@$args) {
        $concat .= " " . $arg;
        unshift @tries, [ $command . $concat, $type, 0 ];

        #         unshift @tries, [$config->mode." ".$command.$concat ,$type,0];
    }

    # The user can control whether or not to search for "unique" matches,
    # which means calling $o->possible_actions(). We always look for exact
    # matches.
    my @matches = qw(exact_action);
    push @matches, qw(possible_actions) if $o->{API}{match_uniq};

    for my $try (@tries) {
        my ( $cmd, $type, $add_cmd_name ) = @$try;
        for my $match (@matches) {
            my @handlers = $o->$match( $cmd, $type );
            next unless @handlers;
            unshift @$args, $command if $add_cmd_name and not $preserve_args;
            my $handler = $o->unalias( $handlers[0], $type );

            if ( defined(&$handler) ) {
                return $handler;
            }
            else {
                return $standardModule . "::undefined_" . $type;
            }
        }
    }
    return undef;
}

sub remove_handlers {
    my $self = shift;
    my $pkg = shift || $self->{API}{class};

    my %cmdHandlers = %{ $self->{handlers} };
    my @toRemove    = ();
    foreach my $command ( keys %cmdHandlers ) {
        my %actions = %{ $cmdHandlers{$command} };
        foreach my $action ( keys %actions ) {
            my $handler = $actions{$action};
            my $package = extractPackageFromSub($handler);
            if ( $pkg eq $package ) {
                unshift @toRemove, $command;
            }
        }
    }

    foreach my $toRemove (@toRemove) {
        $self->{handlers}{$toRemove} = undef;
    }
}

#-----------------------------------------------------------------------------
sub find_handlers {
    my $o            = shift;
    my $pkg          = shift || $o->{API}{class};
    my $showHandlers = shift;
    my $count        = 0;

    # Find the handlers in the given namespace:
    {
        no strict 'refs';
        my @r = keys %{ $pkg . "::" };
        $count = $o->add_handlers( $pkg, $showHandlers, @r );
        use strict 'refs';
    }

    # Find handlers in its base classes.
    {
        no strict 'refs';
        my @isa = @{ $pkg . "::ISA" };
        for my $pkg (@isa) {
            $count += $o->find_handlers( $pkg, $showHandlers );
        }
        use strict 'refs';
    }
    return $count;
}

#-----------------------------------------------------------------------------

sub _getBaseCommandPrefix {
    my $pkg           = shift;
    my $commandPrefix = "";
    if ( $pkg =~ /$prefix\:\:(.*)/ ) {
        $commandPrefix =
          join( " ", map { lc } split( "::", $1 ) )
          ;    #My first perlish one-liner :)
    }
    chomp $commandPrefix;
    return $commandPrefix;
}

sub add_handlers {
    my $o            = shift;
    my $pkg          = shift;
    my $showHandlers = shift;

    my $count = 0;

    for my $hnd (@_) {
        my $commandPrefix = _getBaseCommandPrefix($pkg);

        if ( $hnd eq "run" || $hnd eq "help" || $hnd eq "smry" ) {
            if ($commandPrefix) {
                $o->{handlers}{$commandPrefix}{$hnd} = $pkg . "::" . $hnd;
                $count++;
                printVeryVerbose( $config, "$commandPrefix $hnd added.\n" )
                  if $showHandlers;
            }
            next;
        }
        next unless $hnd =~ /^(cli|run|help|smry|comp|catch|alias)_?(.*)/o;
        my $t = $1;

        my $a = $2 || "";
        $a = $commandPrefix . " " . $a if $commandPrefix;

        # Add on the prefix and suffix if the command is defined
        if ( length $a ) {
            substr( $a, 0, 0 ) = $o->cmd_prefix;
            $a .= $o->cmd_suffix;
        }
        if ( $o ne $pkg ) {
            $hnd = $pkg . "::" . $hnd;
        }
        $o->{handlers}{$a}{$t} = $hnd;
        $count++;
        printVeryVerbose( $config, "$a $t added.\n" ) if $showHandlers;

        $o->{packages}{$pkg} = $pkg;

        if ( $o->has_aliases($a) ) {
            my @a = $o->get_aliases($a);
            for my $alias (@a) {
                substr( $alias, 0, 0 ) = $o->cmd_prefix;
                $alias .= $o->cmd_suffix;
                $o->{handlers}{$alias}{$t} = $hnd;
                $count++;
                printVeryVerbose( $config, "$alias $t added.\n" )
                  if $showHandlers;
            }
        }
    }
    return $count;
}

#-----------------------------------------------------------------------------

##############################
# Import an external module
##############################

# TODO: import Some::Command using "import some command "
sub importCommand {
    my $self = shift;
    my ( $config, $cmd ) = @_;
    my $class = $cmd;

    unless ( $cmd =~ /TWiki::/ ) {
        $class = $prefix . "::" . ucfirst $cmd;
    }

    {
        no warnings;
        local $SIG{__WARN__} = sub { $@ .= $_[0]; };
        eval "use $class;";
        if ($@) {
            if ( $@ =~ /Can\'t locate/ ) {
                print "No extension for $cmd found\n";
            }
            else {
                $self->{packages}{$class} = $class;
                print $@
                  . "\nPlease, use the reload command after fixing the above error\n";
                return 0;
            }
        }
        else {
            my $commandCount = keys %{ $self->{handlers} };
            my $handlersCount = $self->find_handlers( $class, 1 );
            $commandCount = ( keys %{ $self->{handlers} } ) - $commandCount;
            $self->printVeryVerbose(
                "$commandCount commands ($handlersCount handlers) imported\n");
            my $importHook = $class . "::onImport";
            no strict 'refs';
            if ( defined &$importHook ) {
                &$importHook( $self, $config );
            }
            use strict 'refs';

            return 1;
        }
    }
}

############################## HOOKS ##############################

sub postloop {
    print "Done.\n";
}

sub precmd {
    my $self = shift;
    my ( $handler, $cmd, $args ) = @_;

    if ( uc $$cmd eq 'HELP' || uc $$cmd eq 'EXIT' ) {
        return;
    }

    # All this mumbo-jumbo is to guarantee
    # that the right args are passed down to the command
    # Because the way Term::Shell works, when handling
    # multi-level commands (like "dump config"), the value
    # of $cmd will be "dump" and the value of @$args
    # will be ("config"), even if there is a handler
    # for the "dump config" command.
    if ( $$handler =~ /$prefix/ ) {
        my $tmp = $$handler;
        $tmp =~ s/$prefix//;
        if ( $tmp =~ /(.*)\:\:[^\:]+/ ) {
            $tmp = lc $1;
            $tmp =~ s/\:\:/ /g;
            my $arg = "";
            do {
                $arg = shift @$args;
            } while ( $arg && $tmp =~ /$arg/ );

            unshift @$args, $arg if ( $arg && !( $$handler =~ /_/ ) );
        }
    }

    #I can't remember why this code is here... :S
    if ( $$handler =~ /(.*)_.*\s+/ ) {
        $$handler =~ s/$$cmd//;
        $$handler =~ s/\s+//;

        my ( $class, @remainingArgs ) =
          $self->findTargetClassForString( $$cmd, @$args );
        @$args = @remainingArgs;

        $$handler = $prefix . "::" . $class . "::" . $$handler;
    }

    unshift @$args, $config;
}

############################### PRINT STUFF ################################

sub printVeryVerbose {
    my ( $self, $text ) = @_;
    print $text unless ( $config->{verbosity} < 2 );
}

sub printNotQuiet {
    printTerse(@_);
}

sub printVerbose {    #verbose == 1 && verbose !=0
    my ( $self, $text ) = @_;
    print $text unless ( $config->{verbosity} < 1 );
}

sub printTerse {
    my ( $self, $text ) = @_;
    print $text if ( $config->{verbosity} > 0 );
}

sub printDebug {
    my ( $self, $text ) = @_;
    print $text unless ( $config->{debug} == 0 );
}

############################### CATCHERS  ################################

sub catch_run() {
    my ( $self, $command, @params ) = @_;
    $self->dispatch( $command, @params );

    #print "I don't know $command with params ".join(",",@params)."\n";
}

#-----------------------------------------------------------------------------

sub dispatch {
    my ( $self, @args ) = @_;

    my ( $class, @remainingArgs ) = $self->findTargetClassForString(@args);
    unless ($class) {
        print
"Couldn't resolve your request; type 'help' to show commands available\n";
        return;
    }

    $self->run_import( $config, $class, @remainingArgs );
    $self->cmd( join( " ", @remainingArgs ) );

}

#-----------------------------------------------------------------------------

sub findTargetClassForString {
    my ( $self, $config, @cli_args ) = @_;

    # e.g. extension dev foo bar
    # we match extension dev, because Extension::Dev exists but
    # neither Extension::Dev::Foo::Bar nor Extension::Dev::Foo nor
    # exists

    # ucfirst shift @args; # eg. extension => Extension
    my $argsSeparator = $#cli_args;
    my $classToTry;
    my @remainingParameters;
    my $remainingParameters;
    while ( $argsSeparator >= 0 ) {

        $classToTry =
          join( "::", map { ucfirst } @cli_args[ 0 .. $argsSeparator ] );
        $argsSeparator--;
        @remainingParameters = @cli_args[ $argsSeparator + 1 .. $#cli_args ];
        $remainingParameters = join( " ", @remainingParameters );

        printDebug( "Trying $prefix" . "::"
              . $classToTry
              . " '$remainingParameters'\n" );
        if ( classExists($classToTry) ) {
            last;
        }
        $classToTry = undef;
    }

    return ( $classToTry, @remainingParameters );
}

#-----------------------------------------------------------------------------
sub classExists {
    my ($class) = @_;
    my $fqClass = $prefix . "::" . $class;
    eval " require $fqClass ";
    if ($@) {
        return 0;
    }
    else {
        return 1;
    }
}

#-----------------------------------------------------------------------------

sub discover {
    my ( $self, $config ) = @_;

    #DIRTY HACK: "Discover" CommandSet::TWiki before the rest.
    # The proper solution is to define dependencies between CommandSets
    foreach my $libDir (@INC) {
        if ( -f "$libDir/$prefixPath/TWiki.pm" ) {
            $self->_discover( $config, 'TWiki' );
        }
    }
    foreach my $libDir (@INC) {
        if ( opendir( DIR, "$libDir/$prefixPath" ) ) {
            foreach my $file ( grep { /\.pm$/ } readdir DIR ) {
                $self->printVeryVerbose("Found CommandSet $file\n");
                $file =~ s/\.pm//;
                $self->_discover( $config, $file );
            }
        }
    }
}

sub _discover {
    my ( $self, $config, $file ) = @_;

    my $module = $prefix . '::' . $file;
    my $method = $module . '::onImport';
    $self->printVeryVerbose(
        "Trying to initialize CommandSet $file using $method\n");
    no strict 'refs';
    eval("require $module");
    if ($@) {
        $self->printVerbose("Error Initializing CommandSet $module:\n$@\n");
    }
    else {
        if ( defined &$method ) {
            &$method( $self, $config );
            $self->printVeryVerbose("CommandSet $file initialized\n");
        }
        else {
            $self->printVeryVerbose(
                "CommandSet $file does not have an onImport method\n");
        }
        $self->importCommand( $config, $module );
    }
    use strict 'refs';
}

1;

