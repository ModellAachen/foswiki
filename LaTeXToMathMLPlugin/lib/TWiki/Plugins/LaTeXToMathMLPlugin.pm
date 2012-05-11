# LaTeXToMathMLPlugin.pm
#
# Copyright (C) 2003 Simon Clift, ssclift@math.uwaterloo.ca
#
# Very, very heavily derived from MathModePlugin.pm by
#
# Graeme Lufkin, gwl@u.washington.edu
#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# =========================
#
# This is the LaTeX To MathML TWiki plugin.
#
# See TWiki.LaTeXToMathMLPlugin for details on syntax, markup and installation.

# Basically anything inside %$ ... $% or $\[ ... \]% or %MATHMODE{ ... }% is
# formatted from LaTeX to MathML using the itex2MML program.  We do need to
# assert the text/xhtml header or Mozilla will ignore the math mode stuff.

# =========================
package TWiki::Plugins::LaTeXToMathMLPlugin;

use strict;
use English;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug $pluginName
  $equationNumber $equationList $hasAnyMarkup
);

#this is the first release of this plugin
# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'LaTeXToMathMLPlugin';    # Name of this Plugin

#We'll use IPC::Open2 to wrap the itex2MML program
use IO::Handle;
use IPC::Open2;

#If the program is not on the path then this should be changed.
my $itex2MML = '/home/Wiki/lib/TWiki/Plugins/itex2MML';

# For the first pass we number the equations in outsidePREHandler, inserting an
# easily found tag.  We then process the list of equations as a batch, split it
# up and do a replace again.  This is done this way mostly because of the
# ornery behaviour of itex2MML.  There doesn't seem to be a good way to put
# this Flex program in a pipe.

my $hasAnyMarkup;
my $equationNumber;
my $equationList;

#these variables are used by the plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between LaTeXToMathMLPlugin and Plugins.pm");
        return 0;
    }

    $hasAnyMarkup   = 0;
    $equationList   = [];
    $equationNumber = 0;

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("LATEXTOMATHMLPLUGIN_DEBUG");

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::LaTeXToMathMLPlugin::initPlugin( $web.$topic ) is OK"
    ) if $debug;

    return 1;
}

# =========================
# We'll check first if there is any markup at all, otherwise we'll set a flag
# and skip the more detailed work.

sub startRenderingHandler {
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    $hasAnyMarkup = (
             ( $_[0] =~ /%\$(.*?)\$%/mgs )
          or ( $_[0] =~ /%\\\[(.*?)\\\]%/mgs )
          or ( $_[0] =~ /%MATHMODE{(.*?)}%/mgs )
    );

    $_[0] =~ s/%MATHMODE{(.*?)}%/&replaceMath($1,1)/mgseo;

    $_[0];
}

# =========================
# This does nothing if there is no markup.
sub outsidePREHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead
    return $_[0] if ( not $hasAnyMarkup );

    $_[0] =~ s/%\$(.*?)\$%/&replaceMath($1,0)/gseo;
    $_[0] =~ s/%\\\[(.*?)\\\]%/&replaceMath($1,1)/gseo;
    $_[0] =~ s/%MATHMODE{(.*?)}%/&replaceMath($1,1)/gseo;

    return $_[0];
}

sub replaceMath {
    my $placeHolder = sprintf( '%%ITEXMATHMLEQUATION%08d%%', $equationNumber );

    if ( $_[1] ) {
        $equationList->[$equationNumber] = '\[' . $_[0] . '\]' . "\n";
    }
    else {
        $equationList->[$equationNumber] = '$' . $_[0] . '$' . "\n";
    }

    $equationNumber++;

    $placeHolder;
}

# =========================
# After processing the equations into tags, we process the equation set using
# itex2MML.

sub endRenderingHandler {

    # This does nothing if, throughout, no markup was found.

    if ( $equationNumber > 0 ) {
        &TWiki::Func::writeDebug( "- TWiki::Plugins::LaTeXToMathMLPlugin::"
              . "endRenderingHandler ( $web.$topic ) has "
              . "found markup" )
          if $debug;

        # Do something intelligent ought something to go awry.

        my $oldSigAlrm = $SIG{ALRM};
        my $oldSigPipe = $SIG{PIPE};

        alarm(5);    # Longer and something is very wrong.

        $SIG{ALRM} = sub { die "SIGALRM: itex2MML seems to have hung."; };
        $SIG{PIPE} = sub { die "SIGALRM: itex2MML seems to have died."; };

        # Fire up the child process.

        my $childPID;

        eval { $childPID = open2( *ITEXREAD, *ITEXWRITE, $itex2MML ); };

        if ($EVAL_ERROR) {
            &TWiki::Func::writeDebug(
                "open2 failed for itex2MML: " . $EVAL_ERROR )
              if $debug;
        }

        # Feed the child everything at once, pull off the results.

        my $transText;

        eval {
            print ITEXWRITE join( "THISISNOTANEQ__XXX\n", @{$equationList} );
            close ITEXWRITE;
            $transText = join '', <ITEXREAD>;
            close ITEXREAD;
            waitpid $childPID, 0;
        };

        if ($EVAL_ERROR) {
            &TWiki::Func::writeDebug( "itex2MML failed: " . $EVAL_ERROR )
              if $debug;
        }

        # Tidy up.

        alarm(0);
        $SIG{PIPE} = $oldSigPipe;
        $SIG{ALRM} = $oldSigAlrm;

        # Parse out the results into the text.

        my @transArr = split /THISISNOTANEQ__XXX/m, $transText;

        for ( my $i = 0 ; $i < $equationNumber ; $i++ ) {
            my $tag = sprintf( '%%ITEXMATHMLEQUATION%08d%%', $i );

            $_[0] =~ s/$tag/$transArr[$i]/m;
        }

        &TWiki::Func::writeDebug(
"- TWiki::Plugins::LaTeXToMathMLPlugin::startRenderingHandler( $web.$topic ) has finished."
        ) if $debug;
    }

    $_[0];
}

# =========================
#
# Basically we just feed the line to the write handler, and wait until we
# see a </math> token back from the read handler.
#
sub handleMath {

    # Spit math at the translation program.
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::LaTeXToMathMLPlugin::handleMath does $_[0] ")
      if $debug;

    if ( $_[1] )    # The equation is set on its own line
    {
        $_[3]->print( '\[' . $_[0] . '\]' . "\n" );
    }
    else {
        $_[3]->print( '$' . $_[0] . '$' . "\n" );
    }

    # The program is a flex script so shouldn't block.

    my $mathML = '';
    my $mathLine;

    while ( $mathLine = <$_[2]> ) {

        &TWiki::Func::writeDebug(
            "- TWiki::Plugins::LaTeXToMathMLPlugin::handleMath receives $_ ")
          if $debug;

        $mathML .= $_;
        last if ( $mathLine =~ /<\/math>/ );
    }

    return $mathML;
}

# Benedictimus Larry

1;
