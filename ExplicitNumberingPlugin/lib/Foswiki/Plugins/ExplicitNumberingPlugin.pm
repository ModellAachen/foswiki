# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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

# =========================
package Foswiki::Plugins::ExplicitNumberingPlugin;

# =========================
use strict;
use warnings;

our $NO_PREFS_IN_TOPIC = 1;

# This should always be $Rev$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
our $VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
our $RELEASE = '1.6.2';

# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION =
"Use the ==#<nop>#.,== ==#<nop>#..== etc. notation to insert outline numbering sequences (1, 1.1, 2, 2.1) in topic's text. Also support numbered headings.";

my $web;
my $topic;
my $user;
my $installWeb;
my $debug;    # Debug setting
my $bold;     # Configuration flag for bold numbers
my $maxLevels = 6;    # Maximum number of levels
my %Sequences;        # Numberings, addressed by the numbering name
my $lastLevel = $maxLevels - 1;    # Makes the code more readable
my @alphabet  = (
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
    'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
);

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

#Foswiki::Func::writeDebug('ExplicitNumbering  - Entering initialization routine');

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    $debug = Foswiki::Func::getPreferencesFlag("EXPLICITNUMBERINGPLUGIN_DEBUG")
      || 0;
    $bold = Foswiki::Func::getPreferencesFlag("EXPLICITNUMBERINGPLUGIN_BOLD")
      || 0;

    my $alphaseq =
      Foswiki::Func::getPreferencesValue("EXPLICITNUMBERINGPLUGIN_ALPHASEQ")
      || "";

    if ($alphaseq) {
        $alphaseq =~ s/^\s+//;    #Remove leading spaces
        $alphaseq =~ s/\s+$//;    #Remove trailing spaces
        @alphabet = split( ',', $alphaseq );
    }

    Foswiki::Func::writeDebug('ExplicitNumberingPlugin Initialzed ')
      if ($debug);

    return 1;
}

# =========================
# Need to move =makeExplicitNumber= into =commonTagsHandler= to support
# auto-numbering of heading levels, otherwise the TOC lines will have
# different number than the heading line (must be done before TOC).

sub commonTagsHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead
    Foswiki::Func::writeDebug(
        'ExplicitNumbering  - Entering common tags handler')
      if ($debug);

    return if $_[3];    # Called in an include; do not number yet.

    #  Disable the plugin if context not view
    if (
        !(
               Foswiki::Func::getContext()->{'view'}
            || Foswiki::Func::getContext()->{'diff'}
        )
      )
    {
        {
            Foswiki::Func::writeDebug(
                'ExplicitNumbering  - Disabled  - not view  context')
              if $debug;
            return;
        }
    }

    my $removedTextareas = {};

    %Sequences = ();

    $_[0] = takeOutBlocks( $_[0], 'textarea', $removedTextareas );
    $_[0] =~
      s/(^---+\+*)(\#+)([[:digit:]]*)/$1.&makeHeading(length($2), $3)/gem;
    $_[0] =~
s/\#\#(\w+\#)?([[:digit:]]+)?\.(\.*)([[:alpha:]]?)/&makeExplicitNumber($1,$2,length($3),$4)/ge;
    putBackBlocks( \$_[0], $removedTextareas, 'textarea', 'textarea' );
}

# =========================

sub makeHeading {
    my ( $level, $init ) = @_;

    $init = '' unless defined $init;

    my $result   = '';
    my $numlevel = '';
    for ( my $i = 0 ; $i < $level ; $i++ ) {
        $result   .= '+';
        $numlevel .= '.';
    }

    return $result . '##' . $init . $numlevel . ' ';
}

# Build the explicit outline number
sub makeExplicitNumber {
    my ( $name, $init, $level, $alist ) = @_;

    ##Foswiki::Func::writeDebug( "- ${pluginName}::makeExplicitNumber( $_[0], $_[1], $_[2], $_[3] )" ) if $debug;

    $name  = '-default-' unless defined $name;
    $alist = ''          unless defined $alist;
    $level++ if $alist ne '';

    #...Truncate the level count to maximum allowed
    if ( $level > $lastLevel ) { $level = $lastLevel; }

    #...Initialize a new, or get the current, numbering from the Sequences
    my @Numbering = ();
    if ( !defined( $Sequences{$name} ) ) {
        for my $i ( 0 .. $lastLevel ) { $Numbering[$i] = 0; }
    }
    else {
        @Numbering = @{ $Sequences{$name} };

        #...Re-initialize the sequence
    }

    if ( defined $init ) {
        $init = ( int $init );
        $Numbering[$level] = $init - 1;
    }

    #...Increase current level number
    $Numbering[$level] += 1;

    #...Reset all higher level counts
    if ( $level < $lastLevel ) {
        for my $i ( ( $level + 1 ) .. $lastLevel ) { $Numbering[$i] = 0; }

    }

    #...Save the altered numbering
    $Sequences{$name} = \@Numbering;

    #...Construct the number
    my $text = '';
    if ( $alist eq '' ) {
        for my $i ( 0 .. $level ) {
            $text .= "$Numbering[$i]";
            $text .= '.' if ( $i < $level );
        }
    }
    else {

        #...Level is 1-origin, indexing is 0-origin
        if ( $alist =~ /[[:upper:]]/ ) {
            $text .=
              uc $alphabet[ ( $Numbering[$level] - 1 ) % scalar @alphabet ];
        }
        else {
            $text .= $alphabet[ ( $Numbering[$level] - 1 ) % scalar @alphabet ];
        }
    }

    # do we want it bold or not?
    if ($bold) {
        $text =~ (s/$text/\*$text\*/);
    }
    return $text;
}

# =========================
# SMELL:  Use the renderer to remove textarea blocks so that numbers inside of
#         textarea tags don't increment.   Required to prevent conflicts with the
#         EditChapterPlugin.  This has been requested to be added to Foswiki::Func

# compatibility wrapper
sub takeOutBlocks {
    return Foswiki::takeOutBlocks(@_) if defined &Foswiki::takeOutBlocks;
    return $Foswiki::Plugins::SESSION->{renderer}->takeOutBlocks(@_);
}

# =========================
# compatibility wrapper
sub putBackBlocks {
    return Foswiki::putBackBlocks(@_) if defined &Foswiki::putBackBlocks;
    return $Foswiki::Plugins::SESSION->{renderer}->putBackBlocks(@_);
}

1;
