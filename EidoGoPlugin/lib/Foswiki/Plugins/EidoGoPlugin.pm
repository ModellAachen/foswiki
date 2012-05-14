# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
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

=pod

---+ package Foswiki::Plugins::EidoGoPlugin

When developing a plugin it is important to remember that

Foswiki is tolerant of plugins that do not compile. In this case,
the failure will be silent but the plugin will not be available.
See %SYSTEMWEB%.InstalledPlugins for error messages.

__NOTE:__ Foswiki:Development.StepByStepRenderingOrder helps you decide which
rendering handler to use. When writing handlers, keep in mind that these may
be invoked

on included topics. For example, if a plugin generates links to the current
topic, these need to be generated before the =afterCommonTagsHandler= is run.
After that point in the rendering loop we have lost the information that
the text had been included from another topic.

=cut

package Foswiki::Plugins::EidoGoPlugin;

# Always use strict to enforce variable scoping
use strict;

require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version

use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $INSTALL_INSTRUCTIONS $debug $pluginName $NO_PREFS_IN_TOPIC );

$VERSION           = '$Rev: 2957 $';
$RELEASE           = '$Date: 2009-03-10 19:21:06 +0100 (Tue, 10 Mar 2009) $';
$SHORTDESCRIPTION  = 'Plugin to enable the Eidogo Javascript viewer in FosWiki';
$NO_PREFS_IN_TOPIC = 1;
$INSTALL_INSTRUCTIONS = 'instructions...';
$pluginName           = 'EidoGoPlugin';

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

*REQUIRED*

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using =Foswiki::Func::writeWarning= and return 0. In this case
%<nop>FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

__Note:__ Please align macro names with the Plugin name, e.g. if
your Plugin is called !FooBarPlugin, name macros FOOBAR and/or
FOOBARSOMETHING. This avoids namespace issues.

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    $debug = $TWiki::cfg{Plugins}{EidoGoPlugin}{Debug} || 0;

    TWiki::Func::registerTagHandler( 'EIDOGO',   \&_EIDOGO );
    TWiki::Func::registerTagHandler( 'FILELIST', \&_FILELIST );

    # Plugin correctly initialized
    return 1;
}

=begin TML
---++ private handlers
=cut

sub _EIDOGO {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    my $mode = $Foswiki::cfg{Plugins}{EidoGoPlugin}{DefaultMode};
    $mode = $params->{mode} if ( $params->{mode} =~ /\S+/ );

    my $game = $params->{_DEFAULT};
    $game = $params->{game} if ( $params->{game} =~ /\S+/ );

    my $config = $Foswiki::cfg{Plugins}{EidoGoPlugin}{Config};
    $config = $params->{config} if ( $params->{config} =~ /\S+/ );

    my $EIDOGOROOT = $Foswiki::cfg{Plugins}{EidoGoPlugin}{RootDir};

    Foswiki::Func::writeDebug(
        "- ${pluginName}::_EIDOGO( ) mode($mode) game($game) config($config) ")
      if $debug;

    Foswiki::Func::addToHEAD( "eidogohead",
"<script type=\"text/javascript\"> eidogoConfig = {${config}};</script>\n<script type=\"text/javascript\" src=\"${EIDOGOROOT}/player/js/all.compressed.js\"></script>"
    );

    return "<div class=\"${mode}\" sgf=\"${game}\"></div>";
}

sub _FILELIST {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    TWiki::Func::writeDebug("- ${pluginName}::filelist( ) for $params->{path} ")
      if $debug;

    open( FILE,
            "cd "
          . $params->{path}
          . " && /usr/bin/find . -type f -name '*sgf' |" );
    my $formattedlist;

    while ( my $buffer = <FILE> ) {
        TWiki::Func::writeDebug(
            "- ${pluginName}::filelist( ) read line $buffer")
          if $debug;
        my $line = $params->{format};
        TWiki::Func::writeDebug(
            "- ${pluginName}::filelist( ) read parameter $line")
          if $debug;
        $buffer = trim($buffer);
        $buffer =~ s/^\.\///g;
        $line   =~ s/\$file/$buffer/g;
        TWiki::Func::writeDebug(
            "- ${pluginName}::filelist( ) read sub line $buffer")
          if $debug;
        $formattedlist .= "\n" . $line;
        TWiki::Func::writeDebug(
            "- ${pluginName}::filelist( ) new list $formattedlist")
          if $debug;
    }

    return $formattedlist;
}

sub trim($) {
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}
1;
__END__
This copyright information applies to the EidoGoPlugin:

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# EidoGoPlugin is # This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.
