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
# =========================
#
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see %SYSTEMWEB%.Plugins for details.
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

# =========================
package TWiki::Plugins::TopicReferencePlugin;

use strict;

# =========================
use vars qw( $VERSION $RELEASE $debug $pluginName );

$VERSION    = '1.001';
$RELEASE    = 'Dakar';
$pluginName = 'TopicReferencePlugin';

# =========================
sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between TopicReferencePlugin and Plugins.pm");
        return 0;
    }

# Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
# $exampleCfgVar = &TWiki::Prefs::getPreferencesValue( "EMPTYPLUGIN_EXAMPLE" ) || "default";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("TOPICREFERENCEPLUGIN_DEBUG");

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
"- TWiki::Plugins::TopicReferencePlugin::initPlugin( $web.$topic ) is OK"
    ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug(
        "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # Find code tag and replace
    $_[0] =~ s/%TOPICREFERENCELIST{(.*?)}%/&handleTopicRefList($_[2], $1)/ge;

}

# =========================
sub handleTopicRefList {
    my $currweb = shift;
    my $tag     = shift;
    my $type    = "orphans";
    my $web     = $currweb;
    my %params;
    my $out = "";
    my $key;
    my $topic;

    %params = TWiki::Func::extractParameters($tag);

    if ( exists( $params{_DEFAULT} ) ) {
        $type = $params{_DEFAULT};
    }

    $type =~ s/['"]//g;

    if ( exists( $params{web} ) ) {
        $web = $params{web};
    }
    $web =~ s/['"]//g;

    if ( !TWiki::Func::webExists($web) ) {
        $out = "Web does not exist. Can't create reference list.";
        return $out;
    }

    # get list of topics in the web
    my @topics = TWiki::Func::getTopicList($web);
    my %topicrefs;

    # init the reference counts
    foreach $topic (@topics) {
        $topicrefs{$topic} = 0;
    }

    # count the references
    foreach $topic (@topics) {
        my $topictext = TWiki::Func::readTopicText( $web, $topic, "", 1 );

        foreach $key ( keys(%topicrefs) ) {
            if ( $key ne $topic ) {
                if ( $topictext =~ /$key/gs ) {
                    $topicrefs{$key} += 1;
                }
            }
        }
    }

    my $text = 'return "   * [[$key]] ($topicrefs{$key})\n"';
    if ( $web ne $currweb ) {
        $text = 'return "   * [[$web.$key]] ($topicrefs{$key})\n"';
    }

    # print the results
    if ( $type eq "all" ) {
        foreach $key ( keys(%topicrefs) ) {
            $out .= eval $text;
        }
    }
    elsif ( $type eq "orphans" ) {
        foreach $key ( keys(%topicrefs) ) {
            if ( $topicrefs{$key} == 0 ) {
                $out .= eval $text;
            }
        }
    }
    elsif ( $type eq "hasref" ) {
        foreach $key ( keys(%topicrefs) ) {
            if ( $topicrefs{$key} > 0 ) {
                $out .= eval $text;
            }
        }
    }
    else {
        $out = "Unsupported type: '$type'\n";
    }

    return $out;
}

# =========================
1;

