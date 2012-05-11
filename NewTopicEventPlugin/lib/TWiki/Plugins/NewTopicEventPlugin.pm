# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright 2005 Will Norris.  All Rights Reserved.
# License: GPL

=pod

---+ package NewTopicEventPlugin

=cut

package TWiki::Plugins::NewTopicEventPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName );

# This should always be $Rev: 7463$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Name of this Plugin, only used in this module
$pluginName = 'NewTopicEventPlugin';

use LWP::Simple qw();

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Plugin correctly initialized
    return 1;
}

=pod

---++ beforeSaveHandler($text, $topic, $web, $meta )
   * =$text= - text _with embedded meta-data tags_
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - the metadata of the topic being saved, represented by a TWiki::Meta object.

This handler is called each time a topic is saved.

__NOTE:__ meta-data is embedded in $text (using %META: tags)

__Since:__ TWiki::Plugins::VERSION = '1.010'

=cut

sub beforeSaveHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;
    my ( $topic, $web ) = @_[ 1, 2 ];

    my $MATCH = TWiki::Func::getPluginPreferencesValue('MATCH');

    if ( my @a = "$web.$topic" =~ qr/$MATCH/ )
    {    # SMELL: . vs / (should be using something from the core)
            # trigger-level activation (when creating a NEW TOPIC)
        if ( !TWiki::Func::topicExists( $web, $topic ) ) {
            my $EXECUTE = TWiki::Func::getPluginPreferencesValue('EXECUTE');
            $EXECUTE =~ s/\$(\d)/$a[$1-1]/g;    # $1 - $9 only
            $EXECUTE =
              TWiki::Func::expandCommonVariables( $EXECUTE, $topic, $web );

            foreach my $execute ( split( /\s+/, $EXECUTE ) ) {
                my $content = LWP::Simple::head($execute);

                #		my $content = LWP::Simple::get( $execute );
            }

        }
    }

    TWiki::Func::writeDebug("- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )")
      if $debug;
}

1;
