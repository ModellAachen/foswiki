# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2006 Meredith Lesly, msnomer@spamcop.net
#
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

package TWiki::Plugins::ImgPlugin;

use strict;

use vars qw( $VERSION $RELEASE );

$VERSION = '$Rev$';
$RELEASE = 'Dakar';

###############################################################################
sub initPlugin {
    my ( $baseTopic, $baseWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between ImgPlugin and Plugins.pm");
        return 0;
    }

    # register the tag handlers
    TWiki::Func::registerTagHandler( 'IMG', \&_IMG );

    # Plugin correctly initialized
    return 1;
}

# The function used to handle the %IMG{...}% tag
# You would have one of these for each tag you want to process.
sub _IMG {
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

    my $imgName          = $params->{name} || $params->{_DEFAULT};
    my $path             = TWiki::Func::getPubUrlPath();
    my $imgTopic         = $params->{topic} || $theTopic;
    my $imgWeb           = $params->{web} || $theWeb;
    my $altTag           = $params->{alt} || '';
    my $caption          = $params->{caption};
    my $captionplacement = $params->{captionplacement} || 'right';
    my $res;

    my @attrs = ( 'align', 'border', 'height', 'width', 'id', 'class' );

    my $txt = "<img src='$path/$imgWeb/$imgTopic/$imgName' ";
    $txt .= " alt='$altTag'";
    while ( my $key = shift @attrs ) {
        if ( my $val = $params->{$key} ) {
            $txt .= " $key='$val'";
        }
    }
    $txt .= " />";

    if ( defined($caption) && $caption ) {
        $res = <<HERE;
<table>
   <tr>
HERE
        if ( $captionplacement == 'right' ) {
            $res .= "<td>$txt</td>\n";
            $res .= "<td>$caption</td>\n";
        }
        elsif ( $captionplacement == 'left' ) {
            $res .= "<td>$caption</td>\n";
            $res .= "<td>$txt</td>\n";
        }
        elsif ( $captionplacement == 'top' ) {
            $res .= "<td>$caption</td></tr>\n";
            $res .= "<tr><td>$txt</td></tr>\n";
        }
        elsif ( $captionplacement == 'bottom' ) {
            $res .= "<td>$txt</td></tr>\n";
            $res .= "<tr><td>$caption</td></tr>\n";
        }
        $res .= <<HERE;
    </tr>
</table>
HERE
    }
    else {
        $res = $txt;
    }

    return $res;
}

return 1;
