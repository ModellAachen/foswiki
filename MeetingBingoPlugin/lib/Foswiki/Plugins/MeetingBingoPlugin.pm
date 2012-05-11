# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Kenneth Lavrsen, kenneth@lavrsen.dk
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

---+ package MeetingBingoPlugin

__NOTE:__ When writing handlers, keep in mind that these may be invoked
on included topics. For example, if a plugin generates links to the current
topic, these need to be generated before the afterCommonTagsHandler is run,
as at that point in the rendering loop we have lost the information that we
the text had been included from another topic.

=cut

package Foswiki::Plugins::MeetingBingoPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package.
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug
  $pluginName $NO_PREFS_IN_TOPIC
);

# This should always be $Rev: 12445$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 12445$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '1.4';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION =
  'Meeting Bingo Plugin is a business game to enhance attention at meetings.';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use preferences
# stored in the plugin topic. This default is required for compatibility with
# older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, use $Foswiki::cfg entries set in LocalSite.cfg, or
# if you want the users to be able to change settings, then use standard TWiki
# preferences that can be defined in your %USERSWEB%.SitePreferences and overridden
# at the web and topic level.
$NO_PREFS_IN_TOPIC = 0;

# Name of this Plugin, only used in this module
$pluginName = 'MeetingBingoPlugin';

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
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Set plugin preferences in LocalSite.cfg
    $debug = $Foswiki::cfg{Plugins}{MeetingBingoPlugin}{Debug} || 0;

    Foswiki::Func::registerTagHandler( 'MEETINGBINGO', \&_MEETINGBINGO );

    # Plugin correctly initialized
    return 1;
}

sub _MEETINGBINGO {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    # $session  - a reference to the TWiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a Foswiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the variable

    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # $params->{sideorder} will be 'onions'

    Foswiki::Func::addToHEAD(
        "MEETINGBINGO", "
<script type=\"text/javascript\"><!--
    function toggleBgColor( elem ) {
        var newstyle = elem.style;
        newstyle.backgroundColor = newstyle.backgroundColor? \"\":\"#FFFF00\";
    }//-->
</script>
"
    );

    my $bingoWordList = Foswiki::Func::getPreferencesValue(
        'MEETINGBINGOPLUGIN_MEETINGBINGOWORDS');
    my $freeSpace = TWiki::Func::getPreferencesValue(
        'MEETINGBINGOPLUGIN_MEETINGBINGOFREESPACE');
    my @bingoArray = split( ',', $bingoWordList );

    use List::Util qw(shuffle);
    @bingoArray = shuffle(@bingoArray);

    my $bingoCard =
"<table width=\"90%\" cellspacing=\"0\" cellpadding=\"0\" class=\"foswikiTable\" rules=\"all\" border=\"1\">\n";

    for ( my $row = 0 ; $row < 5 ; $row++ ) {
        $bingoCard .= "<tr>\n";
        for ( my $column = 0 ; $column < 5 ; $column++ ) {
            my $bingoWord = $bingoArray[ $column * 5 + $row ];
            $bingoWord = $freeSpace
              if defined $freeSpace
                  && $freeSpace ne ''
                  && $row == 2
                  && $column == 2;

            $bingoWord =~ s/^\s+//;
            $bingoWord =~ s/\s+$//;
            $bingoCard .= sprintf(
"<td width=\"20%%\" bgcolor=\"#fcfcfc\" align=\"center\" valign=\"center\" style=\"height: 6em;\"  onclick=\"javascript:toggleBgColor( this );\">%s</td>",
                join "<br>",
                split /\s/,
                $bingoWord
            );
        }
        $bingoCard .= "\n</tr>\n";
    }

    $bingoCard .= "</table>\n";

    return $bingoCard;

}

1;
