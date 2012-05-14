# See bottom of file for default license and copyright information

=begin TML

---+ package TopicRecursePlugin

=cut

package Foswiki::Plugins::TopicRecursePlugin::Core;
use strict;
use warnings;

use Assert;
use Data::Dumper;
use Foswiki();
use Foswiki::Func();
use Foswiki::Plugins::TopicRecursePlugin();
use Foswiki::Plugins::TopicRecursePlugin::Node();

sub init {

    return;
}

sub extractParams {
    my ( $params, @list ) = @_;
    my %args;

    foreach my $item (@list) {
        $args{$item} = $params->{$item};
    }
    $args{header} ||=
      '*Search: <code class="tml">$rootquery</code> from <nop>$root* $n';
    $args{branchheader} ||= '';
    $args{format}       ||= '$indent* [[$web.$topic][$topic]]';
    $args{branchformat} ||= $args{format};
    $args{leafformat}   ||= $args{format};
    $args{separator}    ||= '$n';
    $args{footer}       ||= '$n*Total: $ntopics*$n';
    $args{branchfooter} ||= '';
    $args{nodelimit}    ||= '50';

    return \%args;
}

sub TOPICRECURSE {
    my ( $session, $params, $baseTopic, $baseWeb, $topicObject ) = @_;
    my $currentWeb   = $session->{webName};
    my $currentTopic = $session->{topicName};
    my %queryArgs    = %{$params};
    my $rootParam    = $params->{root} || $params->{_DEFAULT};
    my ( $rootWeb, $rootTopic ) =
      Foswiki::Func::normalizeWebTopicName( $currentWeb, $rootParam );
    my $rootNode;
    my $result;

    $rootNode = Foswiki::Plugins::TopicRecursePlugin::Node->new(
        undef, undef,
        webtopic  => "$rootWeb.$rootTopic",
        query     => $params->{query} || 'parent.name=\'$supertopic\'',
        queryArgs => \%queryArgs
    );

    if ($rootNode) {
        writeDebug( "rootNode: $rootNode->{webtopic}", 'TOPICRECURSE', 4 );
        my $spec = extractParams(
            $params,
            qw(header format branchformat leafformat separator footer branchheader branchfooter),
            qw(nodelimit depthlimit breadthlimit)
        );
        my @renderednodes = formatNodes( $rootNode, $spec );
        my $separator = Foswiki::expandStandardEscapes( $spec->{separator} );
        writeDebug(
            "Separator: $separator, rendered: " . Dumper( \@renderednodes ),
            'TOPICRECURSE', 4 );

        $result = join( $separator, @renderednodes );
        if ( length( $spec->{header} ) ) {
            $result = renderNode( $rootNode, $spec->{header} ) . $result;
        }
        if ( length( $spec->{footer} ) ) {
            $result .= renderNode( $rootNode, $spec->{footer} );
        }
    }
    else {
        $result =
            '<span class="foswikiInlineAlert">Error executing query: '
          . $params->{query}
          . '</span>';
    }

    return $result;
}

sub formatNodes {
    my ( $node, $spec ) = @_;
    my @renderednodes;

    writeDebug( "$node->{webtopic}: rendering..." . Dumper($spec),
        'TOPICRECURSE', 4 );

    # Is a branch?
    if ( $node->hasNext() ) {
        my $result = renderNode( $node, $spec->{branchformat} );

        if ( not $node->isRoot() ) {
            push( @renderednodes, $result );
        }
        while ( $node->hasNext() ) {
            my $child = $node->next();
            push( @renderednodes, formatNodes( $child, $spec ) );
        }
        if ( not $node->isRoot() && scalar(@renderednodes) ) {
            if ( length( $spec->{branchheader} ) ) {
                $renderednodes[0] =
                  renderNode( $node, $spec->{branchheader} )
                  . $renderednodes[0];
            }
            if ( length( $spec->{branchfooter} ) ) {
                $renderednodes[-1] .=
                  renderNode( $node, $spec->{branchfooter} );
            }
        }
    }
    else {

        # is a leaf.
        my $result = renderNode( $node, $spec->{leafformat} );

        if ( not $node->isRoot() ) {
            push( @renderednodes, $result );
        }
    }
    return @renderednodes;
}

sub renderNode {
    my ( $node, $format ) = @_;
    my %tokens = ( $node->getStandardTokens() );

    return execFormat( $node, \%tokens, $format );
}

sub execFormat {
    my ( $node, $tokens, $format ) = @_;
    my $result = $format;

    writeDebug( "Format: $format", 'execFormat', 4 );
    $result =~
      s/(\$([a-z]+)(\(([^\)]+)\))?)\b/execToken($node, $tokens, $1, $2, $4)/ge;
    $result = Foswiki::expandStandardEscapes($result);

    return $result;
}

sub execToken {
    my ( $node, $tokens, $completetoken, $tokenname, $tokenarg ) = @_;
    my $result;

    if ( exists $tokens->{$tokenname} ) {
        $result = $tokens->{$tokenname};
    }
    elsif ( exists $tokens->{"$tokenname()"} ) {
        $result = $tokens->{"$tokenname()"}->( $node, $tokenarg );
    }
    else {
        $result = $completetoken;
    }
    writeDebug(
        '$'
          . ( $tokenname || '' ) . '('
          . ( $tokenarg  || '' )
          . ') = \''
          . ( $result || '' )
          . '\' depth:'
          . $node->{depth},
        'execToken', 4
    );

    return $result || '';
}

sub writeDebug {
    my ( $message, $method, $level ) = @_;

    return Foswiki::Plugins::TopicRecursePlugin::writeDebug( $message, $method,
        $level, __PACKAGE__ );
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2011 Paul.W.Harvey@csiro.au, TRIN http://trin.org.au/ &
Centre for Australian National Biodiversity Research http://anbg.gov.au/cpbr
Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
