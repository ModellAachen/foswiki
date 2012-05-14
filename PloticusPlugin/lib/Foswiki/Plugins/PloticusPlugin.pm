# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
# and Foswiki Contributors. All Rights Reserved.
# Copyright (C) 2008-2009 Foswiki Contributors
# Foswiki Contributors are listed in the AUTHORS file in the root of this
# distribution.
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
# For licensing info read LICENSE file in the Foswiki root.

# change the package name and $pluginName
package Foswiki::Plugins::PloticusPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName );

# This should always be $Rev: 9964$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 1.2$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Name of this Plugin, only used in this module
$pluginName = 'PloticusPlugin';

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
a function to handle tags that have standard Foswiki syntax - for example,
=%MYTAG{"my param" myarg="My Arg"}%. You can also override internal
Foswiki tag handling functions this way, though this practice is unsupported
and highly dangerous!

=cut

sub initPlugin {

#Foswiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
    my ( $topic, $web, $user, $installWeb ) = @_;
    $debug = Foswiki::Func::getPreferencesValue('PLOTICUSPLUGIN_DEBUG');
    $debug = 1;
    Foswiki::Func::writeDebug("Initialising PloticusPlugin....") if $debug;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # register the handlePloticusTag function to handle %PLOTICUSPLOT{...}% tag
    Foswiki::Func::registerTagHandler( 'PLOTICUSPLOT', \&handlePloticusTag );

    # Allow a sub to be called from the REST interface
    # using the provided alias
    Foswiki::Func::registerRESTHandler( 'Ploticus', \&restPloticus );

    # Plugin correctly initialized
    return 1;
}

sub handlePloticusTag {
    my ( $session, $params, $topic, $web ) = @_;

    # $session  - not used.
    # $params=  - _DEFAULT is the name of the plot
    # $topic    - name of the topic in the query
    # $web      - name of the web in the query
    # Return: rendered text for the plugin

    Foswiki::Func::writeDebug(
"PloticusPlugin::handlePloticusTag for $web - $topic Name=$params->{_DEFAULT}"
    ) if $debug;
    my $plotName = $params->{_DEFAULT};
    unless ($plotName) { return showError('Plot must have a name.'); }

    # get what action we are called with
    #
    my $query  = Foswiki::Func::getCgiQuery();
    my $action = $query->param('ploticusPlotAction');

    # if no action, show the plot
    #
    unless ($action) { return showPlot( $web, $topic, $plotName ); }

    # otherwise, we're trying to edit or save - so, first check permissions
    #
    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
    my ( $url, $mess );
    if (
        !Foswiki::Func::checkAccessPermission(
            'CHANGE', Foswiki::Func::getWikiName(),
            $text, $topic, $web, $meta
        )
      )
    {

        $url = Foswiki::Func::getScriptUrl(
            $web, $topic, 'oops',
            template => 'oopsaccessdenied',
            def      => 'topic_access',
            param1   => 'CHANGE',
            param2   => 'access not allowed on topic'
        );
        $mess = "FOSWIKI ACCESS DENIED";
    }
    else {
        my $queryTarget = $query->param('ploticusPlotName');
        if ( $action eq 'edit' and $queryTarget eq $plotName ) {
            return editPlotSettings( $web, $topic, $plotName );
        }
        if ( $action eq 'save' and $queryTarget eq $plotName ) {
            return savePlotSettings( $web, $topic, $plotName,
                $query->param('ploticusPlotSettingsText') );
        }
    }

    unless ( $query->param('erp_noredirect') ) {
        Foswiki::Func::redirectCgiQuery( undef, $url );
    }
    elsif ($mess) {
        print CGI::header( -status => "500 $mess" );
    }
    else {
        print CGI::header( -status => 200 );
    }

    return 0;    # Suppress standard redirection mechanism

}

sub showError {
    my $error = shift;
    Foswiki::Func::writeDebug("PloticusPlugin showError") if $debug;
    return "Error: $error\n";
}

sub showPlot {
    my ( $web, $topic, $name ) = @_;

    # have permission to see the edit button?
    #
    my $displayOnly = 0;
    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
    if (
        !Foswiki::Func::checkAccessPermission(
            'CHANGE', Foswiki::Func::getWikiName(),
            $text, $topic, $web, $meta
        )
      )
    {
        $displayOnly = 1;
    }

    Foswiki::Func::writeDebug(
        "PloticusPlugin::showPlot  - showPlot for $web, $topic, $name")
      if $debug;
    require Foswiki::Plugins::PloticusPlugin::Plot;
    my $plot =
      Foswiki::Plugins::PloticusPlugin::Plot->new( $web, $topic, $name );
    if ($displayOnly) {
        return $plot->renderForShow();
    }
    else {
        return $plot->renderForEdit();
    }
}

sub editPlotSettings {
    my ( $web, $topic, $name ) = @_;
    Foswiki::Func::writeDebug(
        "PloticusPlugin::editPlotSettings for $web, $topic, $name")
      if $debug;
    require Foswiki::Plugins::PloticusPlugin::PlotSettings;
    my $settings =
      Foswiki::Plugins::PloticusPlugin::PlotSettings->fromFile( $web, $topic,
        $name );
    return $settings->render();
}

sub savePlotSettings {
    my ( $web, $topic, $name, $text ) = @_;
    Foswiki::Func::writeDebug(
        "PloticusPlugin::savePlotSettings $web, $topic, $name, $text")
      if $debug;
    require Foswiki::Plugins::PloticusPlugin::PlotSettings;
    Foswiki::Func::writeDebug(
"PloticusPlugin::savePlotSettings ----------------------------------------------------"
    ) if $debug;
    Foswiki::Plugins::PloticusPlugin::PlotSettings::writeFile( $web, $topic,
        $name, $text );
    Foswiki::Func::writeDebug(
"PloticusPlugin::savePlotSettings OOOOO----------------------------------------------------"
    ) if $debug;
    Foswiki::Func::redirectCgiQuery( {},
        Foswiki::Func::getScriptUrl( $web, $topic, "view" )
          . "\#ploticusplot$name" );
}

=pod


---++ restExample($session) -> $text

This is an example of a sub to be called by the =rest= script. The parameter is:
   * =$session= - The Foswiki object associated to this session.

Additional parameters can be recovered via de query object in the $session.

For more information, check Foswiki:System.CommandAndCGIScripts#rest

=cut

sub restPloticus {

    #my ($session) = @_;
    return "This is an example of a REST invocation\n\n";
}

1;
