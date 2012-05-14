# See bottom of file for default license and copyright information

=begin TML

---+ package FortunePlugin

Fortune Plugin will run either the Unix fortune_mod program "fortune" to access
the traditional fortune database, or alternatively will use the CPAN Fortune 
module to access fortunes.

=cut

package Foswiki::Plugins::FortunePlugin;

# Always use strict to enforce variable scoping
use strict;

require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package.
# This should always be $Rev$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
our $VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
our $RELEASE = '0.9';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION =
  'Fortune Plugin - Displays a random fortune from Unix/Linux fortune file';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use
# preferences set in the plugin topic. This is required for compatibility
# with older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, leave $NO_PREFS_IN_TOPIC at 1 and use
# =$Foswiki::cfg= entries set in =LocalSite.cfg=, or if you want the users
# to be able to change settings, then use standard Foswiki preferences that
# can be defined in your %USERSWEB%.SitePreferences and overridden at the web
# and topic level.
our $NO_PREFS_IN_TOPIC = 1;

my $fortune_db;
my $fortune_bin;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeDebug( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    $fortune_bin = $Foswiki::cfg{Plugins}{FortunePlugin}{FortuneProgram}
      || "";    # If not set, use Perl Fortune from CPAN

    unless ($fortune_bin) {
        eval "require Fortune";
        if ($@) {
            Foswiki::Func::writeDebug(
'Perl CPAN module \"Fortune\" could not be found and FortuneProgram not set in LocalSite.cfg - assuming fortune in path'
            );
            $fortune_bin = 'fortune';
        }
    }

    $fortune_db = $Foswiki::cfg{Plugins}{FortunePlugin}{FortuneDBPath};
    if ( !length($fortune_db) ) {
        $fortune_db =
            Foswiki::Func::getPubDir()
          . "/$Foswiki::cfg{SystemWebName}"
          . "/FortunePlugin/";
    }
    elsif ( $fortune_db eq 'system' ) {
        $fortune_db = '';
    }

    Foswiki::Func::writeDebug("FortuneDBPath set to $fortune_db ");

    if ( $fortune_db && !( -d $fortune_db ) ) {
        Foswiki::Func::writeDebug('provided FortuneDBPath not found ');
        return 0;
    }

    Foswiki::Func::registerTagHandler( 'FORTUNE',         \&_FORTUNE );
    Foswiki::Func::registerTagHandler( 'FORTUNE_LIST',    \&_FORTUNE_LIST );
    Foswiki::Func::registerTagHandler( 'FORTUNE_DB_LIST', \&_FORTUNE_DB_LIST );

    # Plugin correctly initialized
    return 1;
}

=begin TML

---++ _FORTUNE 
Primary macro for the FortunePlugin.  Returns a single random fortune 
from a random database.  

  %<nop>FORTUNE{}%
  %<nop<FORTUNE{"foswiki"}%

=cut

sub _FORTUNE {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    my $db  = $params->{_DEFAULT} || "foswiki";
    my $len = $params->{LENGTH}   || "";

    if ($len) {
        if ( $len =~ m/^(SHORT|S)$/o ) {
            $len = "-s";
        }
        else {
            if ( $len =~ m/^(LONG|L)$/o ) {
                $len = "-l";
            }
            else {
                return
"<font color=\"red\"><nop>Fortune Error: Length paremater must be SHORT, LONG, S or L. (was: $len)</font>";
            }
        }
    }

    if ($fortune_bin) {
        my $cdb = $fortune_db . $db;
        my ( $output, $exit ) =
          Foswiki::Sandbox->sysCommand( "$fortune_bin %DATABASE|U% $len ",
            DATABASE => "$cdb" );
        Foswiki::Func::writeDebug("$fortune_bin Length $len Database ^$cdb^");
        return $output;
    }
    else {
        my $ffile = undef;
        eval { $ffile = new Fortune( "$fortune_db" . "$db" ); };
        if ($@) {
            return " *Error - Problem handling $fortune_db $db* \n";
        }
        $ffile->read_header();
        return ( $ffile->get_random_fortune() );
    }

}

=begin TML

---++ _FORTUNE_LIST 
Returns a formatted list of the fortunes from the specified database.
Requires a single parameter of the database to list.           

 %<nop>FORTUNE_LIST{"scifi"}%                                

Implementation:

Unix =fortune= - issue =fortune -m . database=  (List fortunes matching regular expression)

Perl Fortune - Get fortune count and loop through database listing fortunes

=cut

sub _FORTUNE_LIST {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    my $db = $params->{_DEFAULT} || "foswiki";

    if ($fortune_bin) {
        my $cdb = $fortune_db . $db;
        my ( $output, $exit ) =
          Foswiki::Sandbox->sysCommand( "$fortune_bin -m \".*\"  %DATABASE|F% ",
            DATABASE => "$cdb" );
        $output =~ s/\n/<br \/>/g;                # Newlines become breaks
        $output =~ s/<br \/>%<br \/>/\n<li>/g;    # Percents become list entries
        $output =~ s/<li>$//g;                    # Remove trailing entry
        return "<ul><li>" . $output . "\n </ul>\n";
    }
    else {
        my $ffile = undef;
        eval { $ffile = new Fortune( "$fortune_db" . "$db" ); };
        if ($@) {
            return " *Error - Problem handling $fortune_db $db* \n";
        }
        $ffile->read_header();
        my $num_fortunes = $ffile->num_fortunes();
        &Foswiki::Func::writeDebug(
            "FortunePlugin  - " . $num_fortunes . $fortune_db . $db );
        my $output = "<ul>";
        for ( my $i = 0 ; $i < $num_fortunes ; $i++ ) {
            &Foswiki::Func::writeDebug(
                "FortunePlugin  - " . $i . " = " . $ffile->read_fortune($i) );
            $output .= "<li>" . $ffile->read_fortune($i);
        }
        $output .= "\n</ul>\n";
        return $output;
    }

}

=begin TML

---++ _FORTUNE_DB_LIST 
Returns a formatted list of the fortune files found in the path specfied 
in the configuration file. No parameters supported.           

 %<nop>FORTUNE_DB_LIST{}%

Uses perl functions to list the =.dat= files in the fortune database directory.

For each file, either use fortune -m . , and count % delimiters,  or use Fortune module 
to count the number of fortunes in the file.

=cut

sub _FORTUNE_DB_LIST {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

  #SMELL:  "fortune -f" sends the results to stderr.  So Sandbox cannot be used.

    my $output = undef;
    if ($fortune_bin) {
        $output = `$fortune_bin -f $fortune_db 2>&1`;
        $output =~ s/^100.*+$//m
          ;   #Remove the file path statement.  Don't reveal system information.
        return "<pre>" . $output . "\n </pre>\n";
    }
    else {
        opendir( DIR, $fortune_db )
          || die "<ERR> Can't find directory --> $fortune_db !";
        my @fdbs = grep { /\.dat$/ } readdir(DIR);
        @fdbs   = sort (@fdbs);
        $output = "\n| *Fortune Count* | *Database Name* |\n";
        foreach my $fdb (@fdbs) {
            $fdb = substr( $fdb, 0, -4 );
            my $ffile = undef;
            eval { $ffile = new Fortune( "$fortune_db" . "$fdb" ); };
            if ($@) {
                return " *Error - Problem handling $fortune_db.$fdb* \n";
            }
            $ffile->read_header();
            $output .= "| " . $ffile->num_fortunes() . " | " . $fdb . " |\n";
        }
        $output .= "\n</ul>\n";
        return $output;
    }
}

1;
__END__
This copyright information applies to the FortunePlugin:

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# FortunePlugin is Copyright (C) 2008 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
# Additional copyrights apply to some or all of the code as follows:
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
#
# This license applies to FortunePlugin *and also to any derivatives*
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
# For licensing info read LICENSE file in the Foswiki root.
