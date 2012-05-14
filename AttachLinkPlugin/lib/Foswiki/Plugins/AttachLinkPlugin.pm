# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2006 Meredith Lesly, msnomer@spamcop.net
# Copyright (C) 2008 Timothe Litt, litt@acm.ort
#
# and Foswiki Contributors. All Rights Reserved. Foswiki Contributors
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
# For licensing info read LICENSE file in the Foswiki root.

package Foswiki::Plugins::AttachLinkPlugin;

use strict;

use vars qw( $VERSION $RELEASE );

$VERSION = '$Rev: 10608$';
$RELEASE = '1.001';

###############################################################################
sub initPlugin {
    my ( $baseTopic, $baseWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between AttachLinkPlugin and Plugins.pm");
        return 0;
    }

    # register the tag handlers
    Foswiki::Func::registerTagHandler( 'ATTACHMENT', \&_ATT );

    # Plugin correctly initialized
    return 1;
}

# The function used to handle the %ATTACHMENT{...}% tag
#
# %ATTACHMENT returns a hyperlink to the specified attachment:
#  name= filename as stored
#  topic = topic where stored, defaults to this one
#  web = web where stored, defaults to this one
#  Text that you want for the hyperlink - which may be an IMG tag!

sub _ATT {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    # $session  - a reference to the Foswiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a Foswiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the tag

    my $attName  = $params->{name} || $params->{_DEFAULT};
    my $path     = Foswiki::Func::getPubUrlPath();
    my $attTopic = $params->{topic} || $theTopic;
    my $attWeb   = $params->{web} || $theWeb;
    my $label    = $params->{label};

    my $txt = "<a href='$path/$attWeb/$attTopic/$attName'>";

    if ($label) {
        $txt .= $label;
    }
    else {
        $txt .= $attName;
    }
    $txt .= '</a>';

    return $txt;
}

return 1;
