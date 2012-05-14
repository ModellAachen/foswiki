# See bottom of file for default license and copyright information

=begin TML

---+ package TopicRecursePlugin::Node

=cut

package Foswiki::Plugins::TopicRecursePlugin::Node;
use strict;
use warnings;

use Assert;
use Data::Dumper;
use Foswiki::Func();
use Foswiki::Plugins::TopicRecursePlugin();

use Foswiki::Iterator();
our @ISA = ('Foswiki::Iterator');

sub new {
    my ( $class, $rootNode, $superNode, %args ) = @_;
    my $this = bless( \%args, $class );

    #    writeDebug("args: " . Dumper(\%args), 'new', 4);
    ASSERT( defined $this->{webtopic} ) if DEBUG;
    ( $this->{web}, $this->{topic} ) =
      Foswiki::Func::normalizeWebTopicName( '', $this->{webtopic} );
    ASSERT( $this->{web} and $this->{topic} ) if DEBUG;

    $this->{superNode} = $superNode;
    $this->{rootNode}  = $rootNode;
    if ( not defined $this->{rootNode} ) {
        ASSERT( not defined $this->{superNode} ) if DEBUG;
        $this->{rootNode}     = $this;
        $this->{superNode}    = $this;
        $this->{isRoot}       = 1;
        $this->{depth}        = 0;
        $this->{nodecount}    = 0;
        $this->{nodeindex}    = 0;
        $this->{siblingindex} = 0;
    }
    else {
        ASSERT( defined $this->{superNode} ) if DEBUG;
        $this->{isRoot} = 0;
        ASSERT( not defined $this->{nodecount} ) if DEBUG;
        $this->{nodeindex} = $this->{rootNode}->{nodecount};
        $this->{rootNode}->{nodecount} += 1;
        $this->{depth} ||= $this->{superNode}->{depth} + 1;
        writeDebug( "$this->{webtopic} has depth $this->{depth}", 'new', 4 );
    }

    # Only root node has the initial query
    # Only root node has the query args
    # Only root node has a total nodecount
    # Root node = zero depth, nodeindex, siblingindex; subsequent nodes non-zero
    writeDebug( <<"HERE", 'new', 4 );
$this->{superNode}->{webtopic} now has child \@depth,siblingindex,nodeindex=$this->{depth},$this->{siblingindex},$this->{nodeindex}:\t$this->{webtopic}
HERE
    if ( $this->{isRoot} ) {
        ASSERT( $this->{query} )             if DEBUG;
        ASSERT( defined $this->{queryArgs} ) if DEBUG;
        ASSERT( defined $this->{nodecount} ) if DEBUG;
        ASSERT(
            not( $this->{depth} or $this->{nodeindex} or $this->{siblingindex} )
        );
    }
    else {
        ASSERT( not defined $this->{query} )     if DEBUG;
        ASSERT( not defined $this->{queryArgs} ) if DEBUG;
        ASSERT( not defined $this->{nodecount} ) if DEBUG;
        ASSERT( $this->{depth} > 0 )             if DEBUG;
        ASSERT( defined $this->{nodeindex} )     if DEBUG;
        ASSERT( defined $this->{siblingindex} )  if DEBUG;
    }
    ASSERT( not defined $this->{childnodes} ) if DEBUG;
    $this->{childNodes} = [];
    ASSERT( not defined $this->{childCursor} ) if DEBUG;

    # -1 because we have to ->next() to populate the first child
    $this->{childCursor} = 0 - 1;

    #Lazily build query string when we call getQueryIterator()
    $this->{ourQuery} ||= '';
    $this->{queryIterator}          = undef;
    $this->{queryIteratorExhausted} = 0;

    return $this;
}

sub destroy {
    my ($this) = @_;

    if ( $this->{topicObject} ) {
        $this->{topicObject}->finish();
    }
    $this->{topicObject}            = undef;
    $this->{topicObjectFirstRev}    = undef;
    $this->{web}                    = undef;
    $this->{topic}                  = undef;
    $this->{webtopic}               = undef;
    $this->{superNode}              = undef;
    $this->{rootNode}               = undef;
    $this->{isRoot}                 = undef;
    $this->{childNodes}             = undef;
    $this->{childCursor}            = undef;
    $this->{depth}                  = undef;
    $this->{nodecount}              = undef;
    $this->{nodeindex}              = undef;
    $this->{siblingindex}           = undef;
    $this->{query}                  = undef;
    $this->{ourQuery}               = undef;
    $this->{queryArgs}              = undef;
    $this->{queryIterator}          = undef;
    $this->{queryIteratorExhausted} = undef;

    return;
}

###############################################################################
# Foswiki::Iterator interface to the child nodes.
# Is there a next child node?
sub hasNext {
    my ($this)            = @_;
    my $haveNext          = 0;
    my $populatedChildren = scalar( @{ $this->{childNodes} } );

    ASSERT( $this->{childCursor} < $populatedChildren ) if DEBUG;

    # Are we at the end of our copy of the query resultset already?
    if ( $this->{childCursor} == $populatedChildren - 1 ) {

        # And does the query resultset have more to give us?
        if ( not $this->{queryIteratorExhausted} ) {
            my $queryArgs = $this->{rootNode}->{queryArgs};
            if (
                $this->getQueryIterator()->hasNext()
                and (
                    (
                        not $queryArgs->{nodelimit}
                        or $this->{rootNode}->{nodecount} <
                        $queryArgs->{nodelimit}
                    )
                    and ( not $queryArgs->{depthlimit}
                        or $this->{depth} < $queryArgs->{depthlimit} )
                )
              )
            {
                $haveNext = 1;
                writeDebug(
                    "$this->{webtopic} has more than "
                      . ( $this->{childCursor} + 1 )
                      . " children",
                    'hasNext', 4
                );
            }
            else {

                # We were already on the last element of the resultset.
                $this->{queryIteratorExhausted} = 1;
                writeDebug(
                    "$this->{webtopic} has "
                      . ( $this->{childCursor} + 1 )
                      . " children, no more left",
                    'hasNext', 4
                );
            }
        }
    }
    else {
        $haveNext = 1;
    }

    return $haveNext;
}

# Get the next child node
sub next {
    my ($this) = @_;
    my $populatedChildren = scalar( @{ $this->{childNodes} } );
    my $nextNode;

    ASSERT( $this->{childCursor} < $populatedChildren ) if DEBUG;

    # We work on the assumption that there is a next node either in our list or
    # in the query iterator. So, do we need to add to list from query iterator?
    if ( $this->{childCursor} == $populatedChildren - 1 ) {
        my $nextWebTopic = $this->getQueryIterator()->next();

        ASSERT($nextWebTopic) if DEBUG;
        $this->{childCursor} += 1;
        $nextNode = Foswiki::Plugins::TopicRecursePlugin::Node->new(
            $this->{rootNode},
            $this->{superNode},
            webtopic     => $nextWebTopic,
            siblingindex => $this->{childCursor},
            depth        => $this->{depth} + 1
        );
        push( @{ $this->{childNodes} }, $nextNode );
        ASSERT(
            ( $this->{childCursor} + 1 ) == scalar( @{ $this->{childNodes} } ) )
          if DEBUG;
    }
    else {

        # We already have this node
        $nextNode = $this->{childNodes}->[ $this->{childCursor} ];
        $this->{childCursor} += 1;
        writeDebug( "$this->{webtopic} already had child $nextNode->{webtopic}",
            'next', 4 );
    }
    ASSERT($nextNode) if DEBUG;

    return $nextNode;
}

# Reset the child node cursor to the start
sub reset {
    my ($this) = @_;

    # minus one because the first node needs a ->next(), *then* the cursor is @0
    $this->{childCursor} = 0 - 1;

    return;
}
###############################################################################

sub getQueryString {
    my ($this)    = @_;
    my $rootNode  = $this->{rootNode};
    my $superNode = $this->{superNode};

    if ( not $this->{ourQuery} ) {
        my $query = $rootNode->{query};

        ASSERT($query) if DEBUG;
        $query =~ s/\$root\b/$rootNode->{webtopic}/g;
        $query =~ s/\$rootweb\b/$rootNode->{web}/g;
        $query =~ s/\$roottopic\b/$rootNode->{topic}/g;
        $query =~ s/\$super\b/$this->{webtopic}/g;
        $query =~ s/\$superweb\b/$this->{web}/g;
        $query =~ s/\$supertopic\b/$this->{topic}/g;
        $query =~ s/\$depth\b/$this->{depth}/g;
        $query =~ s/\$nodeindex\b/$this->{nodeindex}/g;
        $query =~ s/\$siblingindex\b/$this->{siblingindex}/g;
        $this->{ourQuery} = $query;
        writeDebug( "$this->{webtopic} now has query: '$this->{ourQuery}'",
            'getQueryString', 4 );
    }
    ASSERT( $this->{ourQuery} ) if DEBUG;

    return $this->{ourQuery};
}

sub getQueryIterator {
    my ($this) = @_;

    if ( not $this->{queryIterator} ) {
        my %queryArgs = %{ $this->{rootNode}->{queryArgs} };

        $queryArgs{web} = $this->{web};
        $this->{queryIterator} =
          Foswiki::Func::query( $this->getQueryString(), undef, \%queryArgs );
        writeDebug( "$this->{webtopic} created queryIterator",
            'getQueryIterator', 4 );
    }
    ASSERT( $this->{queryIterator} ) if DEBUG;

    return $this->{queryIterator};
}

sub depth {
    my ($this) = @_;

    return $this->{depth};
}

sub siblingindex {
    my ($this) = @_;

    return $this->{siblingindex};
}

sub nodeindex {
    my ($this) = @_;

    return $this->{nodeindex};
}

sub web {
    my ($this) = @_;

    return $this->{web};
}

sub topic {
    my ($this) = @_;

    return $this->{topic};
}

sub webtopic {
    my ($this) = @_;

    return $this->{webtopic};
}

sub super {
    my ($this) = @_;

    return $this->{superNode};
}

sub root {
    my ($this) = @_;

    return $this->{rootNode};
}

sub isRoot {
    my ($this) = @_;

    return $this->{isRoot};
}

sub getStandardTokens {
    my ($this) = @_;
    my ( $createdate, $createcuid ) =
      Foswiki::Func::getRevisionInfo( $this->{web}, $this->{topic}, 1 ),

      return (
        super        => $this->{superNode}->{webtopic},
        superweb     => $this->{superNode}->{web},
        supertopic   => $this->{superNode}->{topic},
        root         => $this->{rootNode}->{webtopic},
        rootweb      => $this->{rootNode}->{web},
        roottopic    => $this->{rootNode}->{topic},
        web          => $this->{web},
        topic        => $this->{topic},
        depth        => $this->{depth},
        rootquery    => $this->{rootNode}->{query},
        siblingindex => $this->{siblingindex},
        nodeindex    => $this->{nodeindex},
        indent       => $this->buildIndent('   '),
        'indent()' => sub { $this->buildIndent(@_) },
        'parent()' => sub {
            my $topicObj = $this->getTopicObject();

            if ($topicObj) {
                $topicObj->getParent();
            }
        },
        'date()' => sub {
            my $topicObj = $this->getTopicObject();

            if ($topicObj) {
                $topicObj->getRevisionInfo()->{date};
            }
        },
        index   => $this->{nodeindex},
        item    => $this->{webtopic},
        'rev()' => sub {
            my $topicObj = $this->getTopicObject();

            if ($topicObj) {
                $topicObj->getLoadedRev();
            }
        },
        'username()' => sub {
            my $topicObj = $this->getTopicObject();

            if ($topicObj) {
                $topicObj->getRevisionInfo()->{author};
            }
        },
        'wikiname()' => sub {
            my $topicObj = $this->getTopicObject();

            if ($topicObj) {
                Foswiki::Func::getWikiName(
                    $topicObj->getRevisionInfo()->{author} );
            }
        },
        'wikiusername()' => sub {
            my $topicObj = $this->getTopicObject();

            if ($topicObj) {
                Foswiki::Func::getWikiUserName(
                    $topicObj->getRevisionInfo()->{author} );
            }
        },
        'createdate()' => sub {
            my $topicObj = $this->getTopicObject(1);

            if ($topicObj) {
                $topicObj->getRevisionInfo()->{date};
            }
        },
        'createusername()' => sub {
            my $topicObj = $this->getTopicObject(1);

            if ($topicObj) {
                $topicObj->getRevisionInfo()->{author};
            }
        },
        'createwikiname()' => sub {
            my $topicObj = $this->getTopicObject(1);

            if ($topicObj) {
                Foswiki::Func::getWikiName(
                    $topicObj->getRevisionInfo()->{author} );
            }
        },
        'createwikiusername()' => sub {
            my $topicObj = $this->getTopicObject(1);

            if ($topicObj) {
                Foswiki::Func::getWikiUserName(
                    $topicObj->getRevisionInfo()->{author} );
            }
        },
        'formname()' => sub {
            my $topicObj = $this->getTopicObject();

            if ($topicObj) {
                $topicObj->getFormName();
            }
        },

       # TODO: Make this actually do the SEARCH equivalent (bypassing renderFor)
        'formfield()' => sub {
            my $topicObj = $this->getTopicObject();

            if ($topicObj) {
                $topicObj->get( 'FIELD', $_[0] );
            }
        },
        ntopics => $this->{rootNode}->{nodecount},

        # SMELL: What the...
        nhits => $this->{rootNode}->{nodecount},
      );
}

sub getTopicObject {
    my ( $this, $rev ) = @_;
    my $theTopic;

    if ($rev) {
        if ( not $this->{topicObjectFirstRev} ) {
            $this->{topicObjectFirstRev} =
              Foswiki::Func::Meta->new( $Foswiki::Plugins::SESSION,
                $this->{web}, $this->{topic} );
            $this->{topicObjectFirstRev}->load($rev);
        }
        $theTopic = $this->{topicObjectFirstRev};
    }
    elsif ( not $this->{topicObject} ) {
        ( $this->{topicObject} ) =
          Foswiki::Func::readTopic( $this->{web}, $this->{topic} );
        $theTopic = $this->{topicObject};
    }

    return $theTopic;
}

sub buildIndent {
    my ( $this, $string ) = @_;
    my $result = '';

    foreach ( 1 .. ( $this->{depth} ) ) {
        $result .= $string;
    }
    writeDebug( "Did string indent: '$result'", 'buildIndent', 4 );

    return $result;
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
