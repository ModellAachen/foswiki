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
use TWiki::Func;

package TWiki;

use vars qw($tagname);

$tagname = 'CHILDTOPICS';

sub CHILDTOPICS {
    my ( $session, $params, $topic, $web ) = @_;
    my $format      = $params->{format} || '   * $topic';
    my $join        = $params->{format} || "\n";
    my $searchWeb   = $params->{web}    || $web;
    my $searchTopic = $params->{topic}  || $topic;
    my @eachtopic   = ();
    my @topics      = TWiki::Func::getTopicList($searchWeb);
    my $excludeTopic = $params->{excludetopic};

    if ( defined $excludeTopic ) {
        $excludeTopic =
          TWiki::Contrib::MoreFuncContrib::makeTopicPattern($excludeTopic);
        if ($excludeTopic) {
            @topics = grep( !/$excludeTopic/i, @topics );
        }
    }

    foreach my $t (@topics) {
        my $meta =
          TWiki::Contrib::MoreFuncContrib::readTopicMeta( $searchWeb, $t );
        if ( $meta->getParent() eq $searchTopic ) {
            my $f = $format;
            $f =~ s/\$topic/$t/;
            $f =~ s/\$web/$searchWeb/;
            push @eachtopic, $f;
        }
    }
    return join( $join, @eachtopic );
}

return 1;
