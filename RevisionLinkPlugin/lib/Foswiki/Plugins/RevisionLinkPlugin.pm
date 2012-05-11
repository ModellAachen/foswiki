# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2003 Richard Baar, richard.baar@centrum.cz
# Copyright (C) 2009 Kenneth Lavrsen, kenneth@lavrsen.dk
# and Foswiki Contributors.
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

=pod

---+ package RevisionLinkPlugin

RevisionLinkPlugin makes links to specified revisions and revisions
relative to current revision.

=cut

# =========================
package Foswiki::Plugins::RevisionLinkPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName );

#$web $topic $user $installWeb

# This should always be $Rev$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '2.2 (27 Jan 2009)';

# Name of this Plugin, only used in this module
$pluginName = 'RevisionLinkPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

REQUIRED

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using Foswiki::Func::writeWarning and return 0. In this case
%FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

You may also call =Foswiki::Func::registerTagHandler= here to register
a function to handle variables that have standard Foswiki syntax - for example,
=%MYTAG{"my param" myarg="My Arg"}%. You can also override internal
Foswiki variable handling functions this way, though this practice is unsupported
and highly dangerous!

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1 ) {
        &Foswiki::Func::writeWarning(
            "Version mismatch between RevisionLinkPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = &Foswiki::Func::getPreferencesFlag("REVISIONLINKPLUGIN_DEBUG");

    Foswiki::Func::registerTagHandler( 'REV', \&handleRevision,
        'context-free' );

    # Plugin correctly initialized
    return 1;
}

sub handleRevision {

    #  my ( $text, $topic, $web ) = @_;
    my ( $session, $params, $topic, $web ) = @_;

    my $tmpWeb        = $params->{'web'}        || $web;
    my $rev           = $params->{'rev'}        || '';
    my $format        = $params->{'format'}     || '';
    my $emptyAttr     = $params->{'_DEFAULT'}   || '';
    my $tmpAttachment = $params->{'attachment'} || '';

    my $tmpTopic = $topic;

    if ( $emptyAttr ne '' ) {
        if ( $rev eq '' ) {
            $rev = $emptyAttr;
        }
        else {
            $tmpTopic = $emptyAttr;
        }
    }

    my $targetTopic = $params->{'topic'} || $tmpTopic;

    if ( $rev < 0 ) {
        my $maxRev = (
            Foswiki::Func::getRevisionInfo(
                $tmpWeb, $targetTopic, undef, $tmpAttachment
            )
        )[2];
        $rev = $maxRev + $rev;
    }

    # Remove 1. prefix in case the Foswiki contains old Cairo topics and they
    # use the plugin the old way
    $rev =~ s/1\.(.*)/$1/;

    if ( $rev ne '' && $rev < 1 ) {
        $rev = 1;
    }

    my ( $revDate, $revUser, $tmpRev, $revComment ) =
      Foswiki::Func::getRevisionInfo( $tmpWeb, $targetTopic, $rev,
        $tmpAttachment );

    if ( $format eq "" ) {
        if ($tmpAttachment) {
            $format = "!$tmpAttachment($rev)!";
        }
        else {
            $format = "!$targetTopic($rev)!";
        }
    }
    else {
        if ( $format =~ /!(.*?)!/ eq "" ) {
            $format = "!$format!";
        }
        $format =~ s/\$topic/$targetTopic/geo;
        $format =~ s/\$web/$tmpWeb/geo;
        $format =~ s/\$attachment/$tmpAttachment/geo;
        $format =~ s/\$rev/$rev/geo;
        $format =~ s/\$date/$revDate/geo;
        $format =~ s/\$user/$revUser/geo;
        $format =~ s/\$comment/$revComment/geo;
    }

    if ($tmpAttachment) {
        $format =~
s/!(.*?)!/[[%SCRIPTURLPATH{"viewfile"}%\/$tmpWeb\/$targetTopic\/$tmpAttachment\?rev=$rev][$1]]/g;
    }
    else {
        $format =~
s/!(.*?)!/[[%SCRIPTURLPATH{"view"}%\/$tmpWeb\/$targetTopic\?rev=$rev][$1]]/g;
    }
    return $format;
}

1;
