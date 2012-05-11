# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
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
#
# '$Rev$'

# Always use strict to enforce variable scoping
use strict;
use TWiki::Contrib::MoreFuncContrib;

package TWiki;

use vars qw($tagname);

$tagname = 'TITLE';

sub TITLE {
    my ( $session, $params, $topic, $web ) = @_;
    my $title;
    my $type = $params->{type} || $params->{_DEFAULT} || 'simple';
    my $spacify = $params->{spacify} || 'off';
    my $tool      = TWiki::Func::getWikiToolName();
    my $topicpart = $topic;
    my $specifiedtitle;

    $topic = '%SPACEOUT{"' . $topic . '"}%' if $spacify eq 'on';

    return $topic if ( $type eq 'simple' );

    if (
        ( $type eq 'specified' )
        && (
            $specifiedtitle =
            TWiki::Contrib::MoreFuncContrib::getTopicPreferenceValue(
                $web, $topic, 'USETITLE'
            )
        )
      )
    {
        return $specifiedtitle;
    }

    my $skin = $params->{skin} || TWiki::Func::getSkin() || 'unspecified';

    if ( $skin =~ 'pattern' ) {
        return "$topic < $web < $tool";
    }

    return "$topic < $web < $tool";
}

return 1;
