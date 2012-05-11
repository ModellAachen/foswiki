# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/

# LoginNameAliasesPlugin
#
# Copyright (C) 2004 by Carnegie Mellon University
#               2008-2012 Foswiki Contributors
#
# CARNEGIE MELLON ALLOWS FREE USE OF THIS SOFTWARE IN ITS "AS IS"
# CONDITION.  CARNEGIE MELLON DISCLAIMS ANY LIABILITY OF ANY KIND FOR
# ANY DAMAGES WHATSOEVER RESULTING FROM THE USE OF THIS SOFTWARE.
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

# =========================

package Foswiki::Plugins::LoginNameAliasesPlugin;

# =========================
use vars qw($web $topic $user $installWeb $VERSION $RELEASE $pluginName);

# This should always be $Rev$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '1.2';

$pluginName = 'LoginNameAliasesPlugin';    # Name of this Plugin
our $SHORTDESCRIPTION  = 'Modify or alias Login names to simplify User mapping';
our $NO_PREFS_IN_TOPIC = 1;

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.021 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    # Plugin correctly initialized

    # plugin has already done its thing by the time this is called.
    my $debug =
      Foswiki::Func::getPreferencesFlag("LOGINNAMEALIASESPLUGIN_DEBUG");
    Foswiki::Func::writeDebug(
        "- Foswiki::Plugins::${pluginName}::initPlugin($web.$topic ) is OK")
      if ($debug);
    return 1;
}

# =========================

# Plugin preferences are not yet  read when initializeUserHandler is called,
# so we can't use the usual  Func.pm calls.  It seems like the important thing
# is to have preferences get parsed "as expected" (i.e. exactly like they do
# on other topic pages),  so we'll take the risk of something changing out
# from under us and use functions in the Pref module to do much of the
# dirty work.

sub initializeUserHandler {
    my $logFile =
      $Foswiki::cfg{WorkingDir} . '/' . $pluginName . '_logfile.txt';

    my $loginName = $_[0];

    # $_[0] is very possibly undef. If so, set our $loginName to "", so we can
    # print debugging info w/o generating warnings.

    $loginName = "" unless defined($loginName);
    $original_loginName = $loginName;    # will need this later on

    Foswiki::Func::writeDebug(
        "- $pluginName prefs read. user: $original_loginName")
      if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'DEBUG'} );

    if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'DEBUG'} ) {
        Foswiki::Func::writeDebug("- $pluginName prefs: ");
        foreach my $p ( keys %prefs ) {
            Foswiki::Func::writeDebug(
"- $pluginName  pref $p is  $Foswiki::cfg{LoginNameAliasesPlugin}{$p}"
            );
        }
        Foswiki::Func::writeDebug("- logFile: $logFile");
    }

    # take care of case where $loginName is blank

    my $tmpName = $loginName;
    unless ($tmpName) {
        my $u = $Foswiki::cfg{LoginNameAliasesPlugin}{'MAP_BLANK_USER'};
        if ($u) {
            _dologging( $logFile, $original_loginName, $u )
              if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'LOGGING'} );
            return $u;
        }
        else {
            _dologging( $logFile, $original_loginName, "" )
              if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'LOGGING'} );
            return "";
        }
    }

    #   now process aliases if necessary

    if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'USE_ALIASES'} ) {

       #   an alias entry is a single line with the following form:
       #   <multiple of 3 spaces>*<space>ALIAS:<space>alias_value<space>username
        my ( $meta, $text ) =
          Foswiki::Func::readTopic( '%SYSTEMWEB%', $pluginName );

        foreach my $l ( split( /\n/, $text ) ) {
            my ( $a, $u ) = ( $l =~ m/^\t+\*\sALIAS:\s(\S+)\s(\S+)\s*$/ );
            if ( ( $a && $u ) && ( $a eq $loginName ) ) {
                Foswiki::Func::writeDebug("ALIAS found:  $a -->  $u")
                  if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'DEBUG'} );
                _dologging( $logFile, $loginName, $u )
                  if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'LOGGING'} );
                return $u;
            }
        }
    }

    # Remove prefixes and suffixes if set

    if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'REMOVE_PREFIX'} ) {
        my $p =
          quotemeta( $Foswiki::cfg{LoginNameAliasesPlugin}{'REMOVE_PREFIX'} );
        my $tmp = $loginName
          if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'DEBUG'} );
        $loginName =~ s/^$p//;
        Foswiki::Func::writeDebug("REMOVE_PREFIX  $tmp -->  $loginName")
          if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'DEBUG'} );
    }

    if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'REMOVE_SUFFIX'} ) {
        my $s =
          quotemeta( $Foswiki::cfg{LoginNameAliasesPlugin}{'REMOVE_SUFFIX'} );
        my $tmp = $loginName
          if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'DEBUG'} );
        $loginName =~ s/$s$//;
        Foswiki::Func::writeDebug("REMOVE_SUFFIX  $tmp -->  $loginName")
          if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'DEBUG'} );
    }

    if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'CHANGE_CASE'} ne 'none' ) {
        my $tmp = $loginName
          if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'DEBUG'} );

        if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'CHANGE_CASE'} eq 'upper' ) {
            $loginName = uc($loginName);
        }
        elsif (
            $Foswiki::cfg{LoginNameAliasesPlugin}{'CHANGE_CASE'} eq 'lower' )
        {
            $loginName = lc($loginName);
        }
        elsif ( $Foswiki::cfg{LoginNameAliasesPlugin}{'CHANGE_CASE'} eq
            'uppercasefirst' )
        {
            $loginName = ucfirst($loginName);
        }

        Foswiki::Func::writeDebug("CHANGE_CASE  $tmp -->  $loginName")
          if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'DEBUG'} );
    }

    # If our substitutions nuked the entire loginName, do the MAP_BLANK_USER
    # thing again

    $tmpName = $loginName;
    unless ($tmpName) {
        my $u = $Foswiki::cfg{LoginNameAliasesPlugin}{'MAP_BLANK_USER'};
        if ($u) {
            _dologging( $logFile, $original_loginName, $u )
              if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'LOGGING'} );
            return $u;
        }
        else {
            _dologging( $logFile, $original_loginName, "" )
              if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'LOGGING'} );
            return "";
        }
    }

    # Do registration check and return if found
    # This assumes that $doMapUserToWikiName is true in Foswiki.cfg.
    # Looks for key in %Foswiki::userToWikiList

    if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'MAP_UNREGISTERED'} ) {
        unless ( exists( $Foswiki::userToWikiList{$loginName} ) ) {
            $loginName =
              $Foswiki::cfg{LoginNameAliasesPlugin}{'MAP_UNREGISTERED'};
            _dologging( $logFile, $original_loginName, $loginName )
              if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'LOGGING'} );
            return $loginName;
        }
    }

    #
    # at this point, we have a non-blank login-name, either unchanged from the
    # original or transformed by one or more of the PREFIX/SUFFIX removals.
    #

    if (
        (
            $Foswiki::cfg{LoginNameAliasesPlugin}{'RETURN_NOTHING_IF_UNCHANGED'}
        )
        && ( $loginName eq $original_loginName )
      )
    {
        _dologging( $logFile, $original_loginName, "" )
          if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'LOGGING'} );
        return "";
    }
    else {
        _dologging( $logFile, $original_loginName, $loginName )
          if ( $Foswiki::cfg{LoginNameAliasesPlugin}{'LOGGING'} );
        return $loginName;
    }

}

# Optional logging of user information before and after plugin is run.
# This can be useful to track down authorization issues, since the Foswiki
# logs only have the user information after it has been changed by the
# plugin

sub _dologging {
    my ( $logfile, $orig_name, $new_name ) = @_;
    my $ip       = $ENV{'REMOTE_ADDR'}            ? $ENV{'REMOTE_ADDR'} : "";
    my $rem_user = defined( $ENV{'REMOTE_USER'} ) ? $ENV{'REMOTE_USER'} : "";
    my $now = Foswiki::Func::formatTime( time(), 'http', 'servertime' );
    local *ALIASPLUGINLOG;

    # log a warning if we can't open the logfile
    unless ( open( ALIASPLUGINLOG, ">>$logfile" ) ) {
        Foswiki::Func::writeWarning(
            "- $pluginName: Unable to open logfile: $logfile");
        return 0;
    }
    print( ALIASPLUGINLOG
          "| $now  |  $ip  |  $rem_user  |  $orig_name  |  $new_name  |\n" );
    close ALIASPLUGINLOG;
    return 1;
}

1;
