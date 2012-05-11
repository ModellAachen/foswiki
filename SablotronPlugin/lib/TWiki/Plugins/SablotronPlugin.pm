#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional.
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name.
#
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

package TWiki::Plugins::SablotronPlugin;

use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
  $exampleCfgVar);
use XML::Sablotron;

my ( $self, $processor, $code, $level, @fields, $error );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between SablotronPlugin and Plugins.pm");
        return 0;
    }

 # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $exampleCfgVar =
      &TWiki::Func::getPreferencesValue("SABLOTRONPLUGIN_EXAMPLE") || "default";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("SABLOTRONPLUGIN_DEBUG") || 0;

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::SablotronPlugin::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug(
        "- SablotronPlugin::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/geo;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/geo;
    $_[0] =~
      s/%XSLTRANSFORM{xsl="(.*?)",xml=(.*?)}%/&applySablotron($1, $2)/gseo;
}

sub applySablotron {
    my $xsl = $_[0];
    my $xml = $_[1];

    my $sab = new XML::Sablotron;
    my $sit = new XML::Sablotron::Situation();
    $sab->RegHandler(
        0,
        {
            MHMakeCode => \&myMHMakeCode,
            MHLog      => \&myMHLog,
            MHError    => \&myMHError
        }
    );

    $xml =~ s/^\s+//;    # trim leading white space
    $xml =~ s/\s+$//;    # trim trailing white space
    $sab->addArg( $sit, 'input', $xml );

    #get the web name and the topic name
    my ( $xslWeb, $xslTopic ) = getWebTopic($xsl);

    #check if the topic exists
    if ( &TWiki::Func::topicExists( $xslWeb, $xslTopic ) ) {

        #the topic does exist so read from the file
        my ( $xslMeta, $xslText ) =
          &TWiki::Func::readTopic( $xslWeb, $xslTopic );
        $xslText =~ s/^\s+//;    # trim leading white space
        $xslText =~ s/\s+$//;    # trim trailing white space
        $sab->addArg( $sit, 'template', $xslText );
    }
    else {
        return
            "<verbatim>XSL source: " 
          . $xsl
          . " does not exist.\n"
          . $xml
          . "\n</verbatim>";
    }

    $error = 0;
    $sab->process( $sit, 'arg:/template', 'arg:/input', 'arg:/output' );

    return
        "<verbatim>Sablotron Plugin Error Report:\n"
      . join( "\n", "level:$level", @fields )
      . "\n</verbatim>"
      if $error;
    return $sab->getResultArg('arg:/output');
}

sub myMHMakeCode {
    my ( $self, $processor, $severity, $facility, $code ) = @_;
    return $code if $severity;    # I can deal with internal numbers
}

sub myMHLog {
    ( $self, $processor, $code, $level, @fields ) = @_;
    $error = 1 if $level > 1;
}

sub myMHError {
    ( $self, $processor, $code, $level, @fields ) = @_;
    $error = 1;
}

# get the web and topic name from fully qualified topic name
# This needs to be added to TWiki::Func
sub getWebTopic {
    return &TWiki::Store::getWebTopic(@_);
}

1;
