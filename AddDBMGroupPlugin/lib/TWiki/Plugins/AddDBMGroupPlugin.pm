# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004 Cloyce D. Spradling <cloyce@spec.org>
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
# This is an plugin that allows newly-registered users to be added to
# an Apache (_NOT_ TWiki) group for access control.
#

# =========================
package TWiki::Plugins::AddDBMGroupPlugin;

# =========================
use strict;
use Fcntl;
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug @wikiGroups $groupFile
);

$VERSION    = '$Rev$';
$pluginName = 'AddDBMGroupPlugin';

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    # For some reason, getPluginPreferencesFlag doesn't work
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");
    TWiki::Func::writeDebug(
"- TWiki::Plugins::${pluginName}::initPlugin( $topic, $web, $user, $installWeb ) started"
    ) if $debug;

    @wikiGroups =
      split( /[[:space:],]+/,
        TWiki::Func::getPluginPreferencesValue("WIKI_GROUP") || undef );
    TWiki::Func::writeDebug(
            "- TWiki::Plugins::${pluginName}::initPlugin: wikiGroups is ( "
          . join( ' | ', @wikiGroups )
          . " )" )
      if $debug;

    $groupFile = TWiki::Func::getPluginPreferencesValue("GROUP_FILE") || undef;
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin: groupFile is $groupFile")
      if $debug;

    my $moduleList = TWiki::Func::getPluginPreferencesValue("DBM_MODULES")
      || undef;
    my @moduleList =
      ( defined($moduleList) && $moduleList ne '' )
      ? split( /[[:space:],]+/, $moduleList )
      : @TWiki::dbmmanageModules;
    TWiki::Func::writeDebug(
            "- TWiki::Plugins::${pluginName}::initPlugin: moduleList is ( "
          . join( ' | ', @moduleList )
          . " )\n" )
      if $debug;

    # Load up the AnyDBM module
    eval {
        @AnyDBM_File::ISA = @moduleList;
        use AnyDBM_File ();
    };
    if ($@) {
        TWiki::Func::writeWarning("Error using AnyDBM_File: $@");
        return 1;
    }

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;

    return 1;
}

# =========================
sub registrationHandler {
    ### my ( $web, $wikiName, $loginName ) = @_;
    my %groups;

    if ( !defined( $_[1] ) || $_[1] eq '' ) {
        TWiki::Func::writeWarning(
            "- ${pluginName}::registrationHandler: wikiName ($_[1]) is empty!");
        return;
    }

    TWiki::Func::writeDebug(
"- TWiki::Plugins::${pluginName}::registrationHandler( $_[0], $_[1], $_[2] ) called"
    ) if $debug;

    # There's nothing to do if @wikiGroups is empty
    return unless @wikiGroups;

    # There's nothing to do if $groupFile isn't specified
    return unless defined($groupFile);

    if ( $groupFile eq '' ) {

        # This shouldn't happen
        TWiki::Func::writeWarning(
"- TWiki::Plugins::${pluginName}::registrationHandler: empty WIKI_GROUP_FILE specified\n"
        );
        return;

    }
    elsif ( !-e $groupFile ) {

        TWiki::Func::writeWarning(
"- TWiki::Plugins::${pluginName}::registrationHandler: WIKI_GROUP_FILE doesn't exist!\n"
        );
        return;

    }
    else {

        if ( tie %groups, 'AnyDBM_File', $groupFile, 0644, O_RDWR | O_CREAT ) {

            # Get a local copy of @wikiGroups, with modifications if necessary
            my %groupList = map { s/USER!/$_[1]/g; $_ => 1 } @wikiGroups;

            if ( exists( $groups{ $_[1] } ) && $groups{ $_[1] } ne '' ) {
                foreach my $group ( split( /,+/, $groups{$user} ) ) {
                    $groupList{$group} = 1;
                }
            }

            $groups{ $_[1] } = join( ',', sort keys %groupList );
            untie %groups;
        }
    }
}

# =========================

1;
