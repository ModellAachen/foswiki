# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (c) 2006 by Meredith Lesly, Kenneth Lavrsen
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

package TWiki::Plugins::TWikiAjaxPlugin;

# Always use strict to enforce variable scoping
use strict;

use TWiki::Func;

#use TWiki::Plugins::TWikiAjaxPlugin::Validate qw(CheckFormData);
#use CGI::Validate qw(:vars);

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName $installWeb);
use vars qw( $headerDone );

# This should always be $Rev: 11069$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 11069$';
$RELEASE = '1.0.1';

# Name of this Plugin, only used in this module
$pluginName = 'TWikiAjaxPlugin';

$headerDone = 0;

=pod

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG")
      || TWiki::Func::getPreferencesFlag("DEBUG");

    TWiki::Func::registerTagHandler( 'AJAX', \&_handleAjaxTag );

    # Plugin correctly initialized
    return 1;
}

=pod

Read form field tokens and replace them by the field values.
For instance: if a field contains the value '$about', this string is substituted
by the value of the field with name 'about'.

=cut

sub _handleAjaxTag {
    my ( $session, $params, $topic, $web ) = @_;

    _addHeader();
    return '';
}

=pod

=cut

sub _addHeader {

    return if $headerDone;

    my $header = <<'END';
<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/YahooUserInterfaceContrib/build/yahoo/yahoo.js"></script>
<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/YahooUserInterfaceContrib/build/connection/connection.js"></script>
<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/JavascriptFiles/foswikilib.js"></script>
<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/JavascriptFiles/foswikiArray.js"></script>
<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/JavascriptFiles/foswikiHTML.js"></script>
<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/TWikiAjaxContrib/twikiAjaxRequest.compressed.js"></script>
<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/BehaviourContrib/behaviour.compressed.js"></script>
<script type="text/javascript">
// <![CDATA[
	twiki.AjaxRequest.setDefaultIndicatorHtml("<img src='%PUBURL%/%SYSTEMWEB%/TWikiAjaxContrib/indicator.gif' alt='' />");
// ]]>
</script>
END

    TWiki::Func::addToHEAD( 'TWIKIAJAXPLUGIN', $header );
    $headerDone = 1;
}

1;
