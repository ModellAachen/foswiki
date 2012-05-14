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

=pod

---+ package MetasearchTag

A better =METASEARCH=

=cut

# Always use strict to enforce variable scoping
use strict;

# Must be in TWiki package
package TWiki;

use TWiki::Contrib::MoreFuncContrib;

use vars qw($tagname);

$tagname = 'METASEARCH';

sub METASEARCH {
    my ( $session, $params, $topic, $web ) = @_;

    my $attrType = $params->{type} || 'FIELD';

    my $searchVal = 'XXX';

    my $attrWeb   = $params->{web} || '';
    my $searchWeb = $attrWeb       || $web;

    if ( $attrType eq 'parent' ) {
        my $attrTopic = $params->{topic} || $topic || 'WebHome';
        $searchVal =
          "%META:TOPICPARENT[{].*name=\\\"($attrWeb\\.)?$attrTopic\\\".*[}]%";
    }
    elsif ( $attrType eq 'topicmoved' ) {
        my $attrTopic = $params->{topic} || '';
        $searchVal =
          "%META:TOPICMOVED[{].*from=\\\"$attrWeb\.$attrTopic\\\".*[}]%";
    }
    else {
        $searchVal = "%META:" . uc($attrType) . "[{].*";
        $searchVal .= "name=\\\"$params->{name}\\\".*"
          if ( defined $params->{name} );
        $searchVal .= "value=\\\"$params->{value}\\\".*"
          if ( defined $params->{value} );
        $searchVal .= "[}]%";
    }

    my $text = '';
    if ( $params->{format} ) {
        $text = $session->{search}->searchWeb(
            format       => $params->{format},
            header       => $params->{header},
            limit        => $params->{limit},
            sortOrder    => $params->{order},
            revSort      => $params->{reverse},
            excludetopic => $params->{excludetopic},
            search       => $searchVal,
            web          => $searchWeb,
            type         => 'regex',
            nosummary    => 'on',
            nosearch     => 'on',
            noheader     => 'on',
            nototal      => 'on',
            noempty      => 'on',
            inline       => 1,
        );
    }
    else {
        my $searchObj = TWiki::Contrib::MoreFuncContrib::getSearchObj($session);
        die "No search object" unless $searchObj;
        $text =
          TWiki::Contrib::MoreFuncContrib::getSearchObj($session)->searchWeb(
            _callback => sub {
                my $ref = shift;
                $$ref .= join( ' ', @_ );
            },
            _cbdata   => \$text,
            search    => $searchVal,
            web       => $searchWeb,
            type      => 'regex',
            nosummary => 'on',
            nosearch  => 'on',
            noheader  => 'on',
            nototal   => 'on',
            noempty   => 'on',
            template  => 'searchmeta',
            inline    => 1,
          );
    }

    my $attrTitle = $params->{title} || '';
    if ($text) {
        $text = $attrTitle . $text;
    }
    else {
        my $attrDefault = $params->{default} || '';
        $text = $attrTitle . $attrDefault;
    }

    return $text;
}

1;
