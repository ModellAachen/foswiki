# See bottom of file for default license and copyright information

package Foswiki::Plugins::RemoveTrashPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

use File::Find;

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package. This should always be in the format
# $Rev$ so that Foswiki can determine the checked-in status of the
# extension.
our $VERSION = '$Rev$';

# $RELEASE is used in the "Find More Extensions" automation in configure.
# It is a manually maintained string used to identify functionality steps.
our $RELEASE = '0.1.0';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION = 'A simple plugin for \'emptying\' the Trash web.';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use
# preferences set in the plugin topic. This is required for compatibility
# with older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, leave $NO_PREFS_IN_TOPIC at 1 and use
# =$Foswiki::cfg= entries, or if you want the users
# to be able to change settings, then use standard Foswiki preferences that
# can be defined in your %USERSWEB%.SitePreferences and overridden at the web
# and topic level.
our $NO_PREFS_IN_TOPIC = 1;

# Foswiki root directory.
my $foswikidir;

# Current Foswiki user.
my $user;

# Items successfully removed.
my @removed_items;

# Set this to a non-false value to enable debugging.
use constant DEBUG => 0;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

=cut

sub initPlugin {

    $user = $_[2];

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Always provide a default in case the setting is not defined in
    # LocalSite.cfg.
    $foswikidir = $Foswiki::cfg{Plugins}{RemoveTrashPlugin}{FoswikiRoot}
      || '/var/www/foswiki';

    # Register the _REMOVETRASH function to handle %REMOVETRASH{...}%
    Foswiki::Func::registerTagHandler( 'REMOVETRASH', \&_REMOVETRASH );

    # Register the removetrash REST alias
    Foswiki::Func::registerRESTHandler( 'removetrash', \&remove_trash,
        http_allow => 'GET' );

    # Plugin correctly initialized
    return 1;
}

sub remove_trash {

    if ( defined $user ) {
        if (
            !Foswiki::Func::isGroupMember(
                "AdminGroup", $user, { expand => 0 }
            )
          )
        {
            if (DEBUG) {
                Foswiki::Func::writeDebug(
                    "Current user not a member of AdminGroup, exiting.");
            }
            return "Unable to empty Trash; you are not a member of AdminGroup.";
        }
    }

    if ( !defined $foswikidir ) {
        $foswikidir = '/var/www/foswiki';
    }

    my @directories =
      ( $foswikidir . '/data/Trash', $foswikidir . '/pub/Trash/' );

    finddepth( { wanted => \&remove_item, untaint => 1 }, @directories );

    my $report;

    if (@removed_items) {
        $report = "Removed the following items from Trash:<br/><br/>";
        foreach my $item (@removed_items) {
            $report = $report . "   * $item<br/>";
        }
    }
    else {
        $report = 'No items were removed.';
    }

    return $report;

}

sub remove_item {

    my $file = $File::Find::name;

    # Don't remove certain files and directories.
    if (   $file =~ m|Trash/Web[^/]+$|
        || $file =~ m|Trash/.changes$|
        || $file =~ m|Trash$|
        || $file =~ m|TrashAttachment$| )
    {
        return;
    }

    # Untaint filename+filepath.
    $file =~ m{^(.+(?:data/Trash|pub/Trash).+)$};
    $file = $1;

    if (DEBUG) {
        Foswiki::Func::writeDebug("Removing $file ....");
    }

    undef $!;

    if ( -f $file ) {
        unlink $file;
    }
    elsif ( -d $file ) {
        rmdir $file;
    }

    if ( $! && DEBUG ) {
        Foswiki::Func::writeDebug("Couldn't remove $file; error was '$!'");
    }
    else {
        push @removed_items, $file;
    }

}

# The function used to handle the %REMOVETRASH{...}% macro.

sub _REMOVETRASH {
    my ( $session, $params, $topic, $web, $topicObject ) = @_;

    # $session  - a reference to the Foswiki session object
    #             (you probably won't need it, but documented in Foswiki.pm)
    # $params=  - a reference to a Foswiki::Attrs object containing
    #             parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             (unnamed) parameter.
    # $topic    - name of the topic in the query
    # $web      - name of the web in the query
    # $topicObject - a reference to a Foswiki::Meta object containing the
    #             topic the macro is being rendered in (new for foswiki 1.1.x)
    # Return: the result of processing the macro. This will replace the
    # macro call in the final text.
    #
    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # $params->{sideorder} will be 'onions'

    my $button =
"<a class='foswikiButton' href='$Foswiki::cfg{ScriptUrlPath}/rest/RemoveTrashPlugin/removetrash'>Remove trash</a>";

    return $button;

}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: AlexisHazell

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
