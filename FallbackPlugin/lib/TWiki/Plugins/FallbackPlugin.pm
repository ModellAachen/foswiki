# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006 Meredith Lesly, msnomer@spamcop.net
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
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
# For licensing info read LICENSE file in the TWiki root.
#
# This plugin is not to be modified without the permission of the author. If you
# need it modified and I'm unavailable or unwilling to make the changes, please
# create a new plugin.

=pod

---+ package FallbackPlugin

=cut

# change the package name and $pluginName!!!
package TWiki::Plugins::FallbackPlugin;

# Always use strict to enforce variable scoping
use strict;

use TWiki::Func;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Name of this Plugin, only used in this module
$pluginName = 'FallbackPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

REQUIRED

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using TWiki::Func::writeWarning and return 0. In this case
%FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

You may also call =TWiki::Func::registerTagHandler= here to register
a function to handle variables that have standard TWiki syntax - for example,
=%MYTAG{"my param" myarg="My Arg"}%. You can also override internal
TWiki variable handling functions this way, though this practice is unsupported
and highly dangerous!

__Note:__ Please align variables names with the Plugin name, e.g. if 
your Plugin is called FooBarPlugin, name variables FOOBAR and/or 
FOOBARSOMETHING. This avoids namespace issues.


=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # register the _EXAMPLETAG function to handle %EXAMPLETAG{...}%
    TWiki::Func::registerTagHandler( 'FALLBACK', \&_FALLBACK );

    # Plugin correctly initialized
    return 1;
}

# The function used to handle the %EXAMPLETAG{...}% variable
# You would have one of these for each variable you want to process.
sub _FALLBACK {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    # $session  - a reference to the TWiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a TWiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the variable

    my $topic      = $params->{topic}      || $params->{_DEFAULT};
    my $returntype = $params->{returntype} || 'fullname';

    my $weblist = $params->{otherwebs};
    $weblist = $theWeb . ',' . $weblist if $weblist;
    $weblist ||= $theWeb;
    $weblist =~ tr/ //d;
    my @webs = split( ',', $weblist );

    my $othertopics = $params->{othertopics};
    my $topiclist;
    my @topiclist;
    if ($othertopics) {
        $topiclist = $topic . ',' . $othertopics;
        $topiclist =~ tr/ //d;
        @topiclist = split( ',', $topiclist );
    }
    else {
        $topiclist[0] = $topic;
    }

    foreach my $aTopic (@topiclist) {
        foreach my $web (@webs) {
            if ( TWiki::Func::topicExists( $web, $aTopic ) ) {
                return "$web.$aTopic";
            }
        }
    }

    return '';
}

1;
