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

=pod

---+ package LoadTagsPlugin

=cut

# change the package name and $pluginName!!!
package TWiki::Plugins::LoadTagsPlugin;

# Always use strict to enforce variable scoping
use strict;
use TWiki::Func;

use vars qw( $VERSION $RELEASE $debug $pluginName );
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Name of this Plugin, only used in this module
$pluginName = 'LoadTagsPlugin';

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
    _loadTags();

    return 1;
}

sub _loadTags() {
    foreach my $libDir (@INC) {
        if ( opendir( DIR, "$libDir/TWiki/Tags" ) ) {
            foreach
              my $module ( grep { /^([A-Za-z0-9_]+Tag).pm$/ } readdir DIR )
            {
                $module =~ /^(.*)Tag\.pm$/;
                my $tag = $1;
                $module =
                  'TWiki/Tags/' . TWiki::Sandbox::untaintUnchecked($module);
                $module =~ /^(.*)\.pm$/;
                my $stripped = $module;

                if ( do $module ) {
                    $tag = $TWiki::tagname if $TWiki::tagname;

                    if ($tag) {

                        package TWiki;
                        if ($tag) {
                            TWiki::Func::registerTagHandler( $tag, \&$tag );
                        }
                        else {
                            die $tag;
                        }
                    }
                }
            }
            closedir(DIR);
        }
    }
    return 1;
}

1;
