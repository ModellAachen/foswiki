# Contrib for of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004 Wind River Systems Inc.
# Copyright (C) 1999-2006 TWiki Contributors.
# All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---++!! Package TWiki::Contrib::CliRunnerContrib

This package is intended to be used by TWiki developers.  It contains
helper functions to fire off daughter processes which invoke one of
TWiki's scripts, with a variety of parameters.  This covers the usual
parameters to TWiki scripts as they are available as URL parameters,
but in addition parameters to the Perl interpreter itself, for example
to add extra libraries or modules.

---+++ Synopsis

<verbatim>
sub test_someUnitTest {
    my $this = shift;
    my $runner  =  TWiki::Contrib::CliRunner->new();
    $runner->topic('TestCases.MySpecialTestTopic');
    $runner->twikiCfg(LogFileName => '/dev/null');
    $runner->no('My::Optional::Module');
    $runner->addScriptOptions(skin => 'plain');
    my $output  =  $runner->run();
    $this->assert_matches(qr/Hey! Where is My::Optional::Module\?/,$output);
}
</verbatim>

---+++ The !CliRunner object

---++++!! Object Attributes

#AttributeCallingConvention
---+++++!! Calling Convention

TWiki scripts can be called from the command line using two different
calling conventions:

   1 The "usual" command line convention passes parameters as
     space-separated key value pairs, indicated by a value of ='CLI'=.
   2 The =CGI.pm= convention for calls to the command line passes
     parameters in a query-string syntax, e.g. =?key=value=, appended 
     to the path (topic in case of TWiki).  This is indicated
     by an attribute value of ='CGI'=.

Usually TWiki scripts discover their calling convention themselves,
depending on the existence of the environment variable
=$ENV{GATEWAY_INTERFACE}=.  One known exception is =configure=, which
does not support TWiki's usual command line convention.

If you chose ='CGI'= as calling convention, you have to take care
yourself for setting the environment variables which may be needed by
the script. =$ENV{GATEWAY_INTERFACE}= is a _must_ for all scripts,
with exception of =configure= which always assumes ='CGI'= conventions.
Others to check out are
=$ENV{REMOTE_USER}= for running the script under a defined user id, or
=$ENV{PATH_INFO}= and =$ENV{SCRIPT_NAME}=.
   * Note to self: Or are they being set by =CGI.pm= correctly?  Must
     check.

The calling convention can be queried, and set, with the method
[[#MethodCallingConvention][callingConvention]].


---+++ TODO

   * The defaults configuration hash is a crude mixture of site
     configuration items and mere object defaults - that should be
     decoupled.
   * Documentation and code have gotten slightly out of sync since
     I've discovered how to use the =Config.spec= file.

=cut

package TWiki::Contrib::CliRunnerContrib;

use strict;

our $VERSION = '$Rev$';

use Carp;
use Cwd;
use Data::Dumper;
use File::Temp;

use TWiki::Configure::Load;

# static variables
my $start_directory       = cwd();
my $twikibindir_indicator = 'setlib.cfg';

# set the defaults

TWiki::Configure::Load::readConfig();
my $cfg            = $TWiki::cfg{Contrib}{CliRunnerContrib};
my %default_config = (
    'perl'        => $cfg->{perl}        || 'perl',
    'perlOptions' => $cfg->{PerlOptions} || '-T',
    'lib_path'    => $cfg->{LibPath}     || '../lib',
    'output_options' => '2>&1',
);
my $default_topic             = 'Main.WebHome';
my $default_script            = 'view';
my $default_callingConvention = 'CLI';

# ======================================================================

=pod

#MethodNew
---+++ ClassMethod new([$config]) -> !CliRunner object

*Purpose:* Create a !CliRunner object, intended to be fired off one
time, or multiple times, with command line parameters derived from the
object's attributes.

---++++!! Parameters

#MethodNewParams
---+++++!! =$config= (optional)

The one and optional parameter to this routine is a reference to a
hash containing parameters to be used for the command line invocation.
The keys, their defaults and meanings are described in the following
table.

| *Key* | *Default* | *Description* |
| =perl= | ='perl'= | \
Location of the Perl interpreter. \
The default should have been automatically (or manually) set by =configure=. \
Otherwise it is assumed that the interpreter is accessible as =perl=, \
somewhere on the PATH. |
| =perlOptions=  | '-T' | \
Options to pass to the Perl interpreter. \
The default just switches on taint checking, \
which is mandatory for most TWiki scripts. |
| =develOptions= | [] | \
Special developer options to pass to the Perl interpreter.  |
| =script= | 'view' | \
Which of the programs to call |
| =callingConvention= | 'CLI' | \
Calling conventions for parameter passing.  See [[#AttributeCallingConvention]]. |
| =scriptOptions= | [] | \
Options to pass to the script, e.g. an alternate user id.  |
| =topic= | 'Main.WebHome' | \
The web and topic to act on. |
| =output_options= | '2>&1' | \
Redirection options, e.g. to save output files |

=cut

sub new {
    my $proto    = shift;
    my $class    = ref($proto) || $proto;
    my ($config) = @_;

    $config ||= {};
    if ( ref $config ne 'HASH' ) {
        Carp::croak("Parameter to $class->new must be a HASH reference");
    }

    my %config = ( %default_config, %$config );

    my $topic  = delete $config{topic}  || $default_topic;
    my $script = delete $config{script} || $default_script;
    my $perlOptions       = delete $config{perlOptions};
    my $callingConvention = delete $config{callingConvention}
      || $default_callingConvention;

    my $self = {
        config            => \%config,
        callingConvention => $callingConvention,
        twikiCfg          => [],
        perlOptions       => $perlOptions,
        develOptions      => [],
        script            => $script,
        scriptOptions     => [],
        topic             => $topic,
    };

    bless $self, $class;
}

# ======================================================================

=pod

#MethodCommand

---+++ ObjectMethod command -> command_string

Return the command which would be run with the current object (in
fact, the =run= method has its command generated with this routine)

=cut

sub command {
    my $self = shift;
    my ($params) = @_;

    $params ||= {};
    if ( ref $params ne 'HASH' ) {
        my $class = ref $self;
        Carp::croak("Parameter to $class->run must be a HASH reference");
    }

    my %params = ( %{ $self->{config} }, %$params );
    return join( " ",
        $params{perl},
        $self->{perlOptions},
        "-I" . $params{lib_path},
        @{ $self->{develOptions} },
        $self->_twikiCfgExpand( $params{doCreateFile} ),
        $self->{script},
        $self->_expandScriptParameters(),
        $params{output_options},
    );
}

# ======================================================================

=pod

#MethodErrorMissingModule
---+++ Class Method error_missing_module($module) => error_regex

Return a regex suitable for use in an assertion after a module has
been "hidden" using the [[#MethodNo][no]] method.

Use in test cases where you do deliberately do not catch errors thrown
as a result of a missing module.

---++++!! Parameters <!-- error_missing_module -->

| *Parameter*       | *Type*      | *Description*                      |
| =$module=         | scalar      | \
Name of the module for which the error message is to be asserted.      |

=cut

sub error_missing_module {
    my $class = shift;
    my ($missing) = @_;
    return qr/Can't locate $missing.*BEGIN failed/s;
}

# ======================================================================

=pod

#MethodNo
---+++ Object Method no(@modules) -> (void)

For the current runner object, pretend that the CPAN module(s) given
in the parameter list are not available.

---++++!! Parameters <!-- no -->

| *Parameter*       | *Type*      | *Description*                      |
| =@modules=        | array       | \
=@modules= is a list of strings containing module names as you would \
use them in a =use= statement, i.e. with =::= as separator, and \
without =.pm=. |

---++++!! Example
<verbatim>
    $runner->no('CGI','Pretty::Strange::Module');
</verbatim>

---++++!! Bugs <!-- no -->

The method can not hide modules which are in TWiki's own lib
directories, i.e. those activated in =bin/setlib.cfg= and
=bin/LocalLib.cfg=.

=cut

sub no {
    my $self = shift;
    my $modules = join ',', @_;

    push @{ $self->{develOptions} },
      "-MTWiki::Contrib::CliRunnerContrib::HideModule=$modules";
}

# ======================================================================

=pod

#MethodAddScriptOptions
---+++ ObjectMethod addScriptOptions(%options) = arrayref to options

---++++!! Parameters
| *Parameter*       | *Type*      | *Description*                      |
| =%options=        | hash        | \
Hash of options to add to the script.  They usually come in "key \
value" pairs and are described in %SYSTEMWEB%.TWikiScripts for every script. |

---++++!! Bugs/Todo

You can not remove, nor change script options right now.

=cut

sub addScriptOptions {
    my $self = shift;
    push @{ $self->{scriptOptions} }, @_;
}

# ======================================================================

=pod

#MethodCallingConvention
---+++ ObjectMethod callingConvention([$cC]) -> current cC

Gets/sets the calling convention for the runner object (see
[[#AttributeCallingConvention]] for a description of the attribute).

---++++!! Parameters
| *Parameter*       | *Type*      | *Description*                      |
| =$cC=             | scalar      | Optional. \
  New calling convention to be used by the script.  If missing, \
  the calling convention remains unchanged.  Valid values are 'CLI' \
  (for command line style) and 'CGI' (for =CGI.pm= style).             |
| =$currentcC=      | scalar      | \
  The current calling convention of the runner object.                 |

=cut

sub callingConvention {
    my $self = shift;
    if ( scalar @_ ) {
        $self->{callingConvention} = $_[0];
    }
    else {
        $self->{callingConvention};
    }
}

# ======================================================================

=pod

#MethodPerlOptions
---+++ ObjectMethod perlOptions([$optionString]) -> $currentOptions

---++++!! Parameters

| *Parameter*       | *Type*      | *Description*                      |
| =$optionString=   | scalar      | Optional. \
  New options to be passed to the Perl interpreter.  If missing, \
  the options remain unchanged.                                        |
| =$currentOptions= | scalar      | \
  The current perl options of the runner object.                       |

=cut

sub perlOptions {
    my $self = shift;
    if ( scalar @_ ) {
        $self->{perlOptions} = $_[0];
    }
    else {
        $self->{perlOptions};
    }
}

# ======================================================================

=pod

#MethodRun
---+++ ObjectMethod run([$params]) -> output

Run the current object and capture and return the
intermingled results from both STDOUT and STDERR.

---++++!! Parameters

---+++++!! =$params= (optional)

See the =$config= parameter of #MethodNew.

---++++!! TODO

   * Separate the output streams for STDOUT and STDERR using =IPC::Open3=
   * Allow to extend, and not just replace, the configuration options

=cut

sub run {
    my $self = shift;
    my ($params) = @_;
    $params->{doCreateFile} = 1;
    my $command = $self->command($params);

    warn $command if $cfg->{Debug};

    chdir _twiki_bin_dir();
    my $result = `$command`;
    chdir $start_directory;

    return $result;
}

# ======================================================================

=pod

#MethodScript
---+++ ObjectMethod script([$script]) -> current script

Gets/sets the script name for the runner object

---++++!! Parameters
| *Parameter*       | *Type*      | *Description*                      |
| =$script=         | scalar      | Optional.                          \
  script to be called.  If missing,                                    \
  the script remains unchanged.  Defaults to ='view='.                 |
| =$current=        | scalar      | The current script to be run.      |

=cut

sub script {
    my $self = shift;
    if ( scalar @_ ) {
        $self->{script} = $_[0];
    }
    else {
        $self->{script};
    }
}

# ======================================================================

=pod

#MethodTopic
---+++ ObjectMethod topic([$topic]) -> $current

Gets/sets the topic for the runner object

---++++!! Parameters
| *Parameter*       | *Type*      | *Description*                      |
| =$topic=          | scalar      | Optional.                          \
  topic to be operated upon  If missing,                               \
  the topic remains unchanged.  Defaults to ='Main.WebHome'=.          |
| =$current=        | scalar      | The current topic to be run.       |

=cut

sub topic {
    my $self = shift;
    if ( scalar @_ ) {
        $self->{topic} = $_[0];
    }
    else {
        $self->{topic};
    }
}

# ======================================================================

=pod

#MethodTWikiCfg

---+++ ObjectMethod twikiCfg(@config_array) -> $merged_config_arrayref

Define configuration items to change in the runner object.  Note that,
in contrast to the finalized =%TWiki::cfg= _hash_, our deltas are
_lists_.  This is due to the fact that we need to change individual
entries in multi-level configuration settings, and we need to have
cumulative changes where the ordering matters.

The parameters with even indices (starting with 0) must be array
references, consisting of the keys for each level in the =%TWiki::cfg=
hash.  The elements with odd indices (starting with 1) are the values
to be used for these configuration items.

Too complicated?  Incomprehensible?  Yes, of course.  Please make a
better description if you can.  Or a better code.  Or both.  Let me
try to explain the current behaviour with some examples:

   $ Replace a simple configuration item: &nbsp;
    <verbatim>
    $runner->twikiCfg(MapUserToWikiName => 1);
    </verbatim>
     Note that the ==&gt;= operator is just syntactic Perl sugar to
     make the first parameter being automatically interpreted as a
     (bareword) string, or a hash key.  Do *not* try to use this for
     complex configuration items.
   $ Enable a plugin: &nbsp;
    <verbatim>
    $runner->twikiCfg([qw(Plugins TestFixturePlugin Enabled)],1);
    </verbatim>
     Note that in this case the first parameter _must not_ be stringified!
   $ Equivalent to the previous method, provided that the !TestFixturePlugin
     has no other keys but =Enabled=:
    <verbatim>
    $runner->twikiCfg([qw(Plugins TestFixturePlugin)],{Enabled=>1});
    </verbatim>

=cut

sub twikiCfg {
    my $self = shift;

    while ( scalar @_ ) {
        my $key = shift;
        if ( ref $key eq 'ARRAY' ) {
            push @{ $self->{twikiCfg} }, [ $key, shift ];
        }
        else {
            push @{ $self->{twikiCfg} }, [ [$key], shift ];
        }
    }
}

# ======================================================================

=pod

#MethodTwikiCfgFile
---+++ ObjectMethod twikiCfgFile([$twikiCfgFile]) -> current twikiCfgFile

Gets/sets the twikiCfgFile to be used for the runner object

=cut

sub twikiCfgFile {
    my $self = shift;
    if ( scalar @_ ) {
        $self->{twikiCfgFile} = $_[0];
    }
    else {
        $self->{twikiCfgFile};
    }
}

# ======================================================================
# Non serviceable parts
# ======================================================================

# ----------------------------------------------------------------------
# Purpose: return the directory where TWiki's scripts reside, as
#          determined by heuristics (should be a config item)
sub _twiki_bin_dir {
    my $dir = $INC{$twikibindir_indicator};
    $dir =~ s/\W+$twikibindir_indicator$//;
    return $dir;
}

# ----------------------------------------------------------------------
# Purpose: Expand parameters to be passed to the script,
#          according to the object's callingConvention property
# Parameters: none
# Returns: string containing script parameters
sub _expandScriptParameters {
    my $self = shift;
    if ( $self->callingConvention() eq 'CLI' ) {
        return join( " ", @{ $self->{scriptOptions} }, $self->{topic} );
    }
    elsif ( $self->callingConvention() eq 'CGI' ) {
        my %options = @{ $self->{scriptOptions} };    # make key/value pairs
                                                      # escape for shell
        return
            "'"
          . $self->topic . '?'
          . join( ";", map { "$_=$options{$_}" } keys %options ) . "'";
    }
    else {
        Carp::Croak( 'Invalid calling convention: ',
            $self->callingConvention() );
    }
}

# ----------------------------------------------------------------------
# Purpose: Expand the object attributes regarding TWiki configuration
#          items into a option string which can be passed to perl.
# Parameters:
#     $doCreateFile
#        If true, create a temporary file to actually store the
#        values.  Otherwise just return the appropriate command line
#        option.
sub _twikiCfgExpand {
    my $self = shift;
    my ($doCreateFile) = @_;

    my $cfgExists = 0;
    my $cfgText   = '';

    if ( $self->{twikiCfgFile} ) {
        $cfgExists = 1;
        $cfgText .= "do '" . $self->{twikiCfgFile} . "';\n";
    }
    if ( scalar @{ $self->{twikiCfg} } ) {
        $cfgExists = 1;
        my @cfg = @{ $self->{twikiCfg} };
        for my $cfg (@cfg) {
            my ( $key, $value ) = @$cfg;  # Note that $key is an array reference
            $key = q($TWiki::cfg{') . join( q('}{'), @$key ) . q('}=);
            my $dumper = Data::Dumper->new( [$value] );
            $dumper->Terse(1);
            $dumper->Indent(1);
            $cfgText .= $key . $dumper->Dump() . ";\n";
        }
    }

    if ($cfgExists) {
        if ($doCreateFile) {
            my ( $cfgHandle, $cfgFileName ) = File::Temp::tempfile();
            print $cfgHandle $cfgText;
            print $cfgHandle "\n1;\n";
            close $cfgHandle;
            return (
                "-MTWiki::Contrib::CliRunnerContrib::TWikiCfg=$cfgFileName");
        }
        else {
            return ("-MTWiki::Contrib::CliRunnerContrib::TWikiCfg=tempfile");
        }
    }
    else {
        return ();
    }
}

1;

