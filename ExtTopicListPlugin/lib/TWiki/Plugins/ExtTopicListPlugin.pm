# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
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

---+ package ExtTopicListPlugin

=cut

# change the package name and $pluginName!!!
package TWiki::Plugins::ExtTopicListPlugin;

# Always use strict to enforce variable scoping
use strict;

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
$pluginName = 'ExtTopicListPlugin';

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
a function to handle tags that have standard TWiki syntax - for example,
=%MYTAG{"my param" myarg="My Arg"}%. You can also override internal
TWiki tag handling functions this way, though this practice is unsupported
and highly dangerous!

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    $debug = TWiki::Func::getPluginPreferencesValue('DEBUG');

    # register the _EXTTOPICLIST function to handle %EXTTOPICLIST{...}%
    TWiki::Func::registerTagHandler( 'EXTTOPICLIST', \&_EXTTOPICLIST );

    # Plugin correctly initialized
    return 1;
}

# The function used to handle the %EXTTOPICLIST{...}% tag
# You would have one of these for each tag you want to process.
sub _EXTTOPICLIST {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    # $session  - a reference to the TWiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a TWiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the tag

    # For example, %EXTTOPICLIST{'hamburger' sideorder="onions"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # $params->{sideorder} will be 'onions'
    my $format = $params->{_DEFAULT} || $params->{'format'} || '$name';
    $format ||= '$name';
    my $separator = $params->{separator} || "\n";
    $separator =~ s/\$n/\n/;
    my $web       = $params->{web}       || $session->{webName};
    my $selection = $params->{selection} || '';
    $selection =~ s/\,/ /g;
    $selection = " $selection ";
    my $marker = $params->{marker} || 'selected="selected"';
    my $excludetopic = $params->{excludetopic};
    $excludetopic = _makeTopicPattern($excludetopic);

    $web =~ s#\.#/#go;

    return ''
      if $web ne $session->{webName}
          && $session->{prefs}->getWebPreferencesValue( 'NOSEARCHALL', $web );

    my @items;
    foreach my $item ( $session->{store}->getTopicNames($web) ) {
        unless ( $item =~ $excludetopic ) {
            my $line = $format;
            $line =~ s/\$web\b/$web/g;
            $line =~ s/\$name\b/$item/g;
            $line =~ s/\$qname/"$item"/g;
            my $mark = ( $selection =~ / \Q$item\E / ) ? $marker : '';
            $line =~ s/\$marker/$mark/g;
            push( @items, $line );
        }
    }

    return join( $separator, @items );
}

sub _makeTopicPattern {
    my ($topic) = @_;
    return '' unless ($topic);

    # 'Web*, FooBar' ==> ( 'Web*', 'FooBar' ) ==> ( 'Web.*', "FooBar" )
    my @arr =
      map { s/[^\*\_$TWiki::regex{mixedAlphaNum}]//go; s/\*/\.\*/go; $_ }
      split( /,\s*/, $topic );
    return '' unless (@arr);

    # ( 'Web.*', 'FooBar' ) ==> "^(Web.*|FooBar)$"
    return '^(' . join( '|', @arr ) . ')$';
}

1;
