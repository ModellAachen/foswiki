# See bottom of file for license and copyright information
use strict;
use warnings;

package TopicRecursePluginTests;
use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki::Func();

my %topics = (
    'Parent'  => undef,
    'Child1'  => { 'TOPICPARENT' => { name => 'Parent' } },
    'Child2'  => { 'TOPICPARENT' => { name => 'Parent' } },
    'Child21' => { 'TOPICPARENT' => { name => 'Child2' } },
    'Child22' => { 'TOPICPARENT' => { name => 'Child2' } },
    'Child3'  => { 'TOPICPARENT' => { name => 'Parent' } },
);

sub set_up {
    my ($this) = @_;

    $this->SUPER::set_up();
    $Foswiki::cfg{Plugins}{TopicRecursePlugin}{Enabled} = 1;
    $this->createNewFoswikiSession();
    while ( my ( $topic, $meta ) = each %topics ) {
        my ($topicObj) = Foswiki::Func::readTopic( $this->{test_web}, $topic );

        if ($meta) {
            while ( my ( $field, $data ) = each %{$meta} ) {
                $topicObj->putAll( $field, $data );
            }
        }

        $topicObj->save();
    }

    return;
}

sub test_default {
    my $this   = shift;
    my $actual = Foswiki::Func::expandCommonVariables(<<"HERE");
%TOPICRECURSE{"$this->{test_web}.Parent"}%
HERE
    my $expected = <<'HERE';
*Search: <code class="tml">parent.name='$supertopic'</code> from <nop>TemporaryTopicRecursePluginTestsTestWebTopicRecursePluginTests.Parent* 
   * [[TemporaryTopicRecursePluginTestsTestWebTopicRecursePluginTests.Child1][Child1]]
   * [[TemporaryTopicRecursePluginTestsTestWebTopicRecursePluginTests.Child2][Child2]]
      * [[TemporaryTopicRecursePluginTestsTestWebTopicRecursePluginTests.Child21][Child21]]
      * [[TemporaryTopicRecursePluginTestsTestWebTopicRecursePluginTests.Child22][Child22]]
   * [[TemporaryTopicRecursePluginTestsTestWebTopicRecursePluginTests.Child3][Child3]]
*Total: 5*
HERE

    chomp($actual);
    $this->assert_str_equals( $expected, $actual );

    return;
}

sub test_branch_header_footer {
    my $this   = shift;
    my $actual = Foswiki::Func::expandCommonVariables(<<"HERE");
%TOPICRECURSE{
    "$this->{test_web}.Parent"
    branchheader="\$indent* BRANCH HEAD\$n"
    branchfooter="\$n\$indent* BRANCH FOOT"
}%
HERE
    my $expected = <<'HERE';
*Search: <code class="tml">parent.name='$supertopic'</code> from <nop>TemporaryTopicRecursePluginTestsTestWebTopicRecursePluginTests.Parent* 
   * [[TemporaryTopicRecursePluginTestsTestWebTopicRecursePluginTests.Child1][Child1]]
   * BRANCH HEAD
   * [[TemporaryTopicRecursePluginTestsTestWebTopicRecursePluginTests.Child2][Child2]]
      * [[TemporaryTopicRecursePluginTestsTestWebTopicRecursePluginTests.Child21][Child21]]
      * [[TemporaryTopicRecursePluginTestsTestWebTopicRecursePluginTests.Child22][Child22]]
   * BRANCH FOOT
   * [[TemporaryTopicRecursePluginTestsTestWebTopicRecursePluginTests.Child3][Child3]]
*Total: 5*
HERE

    chomp($actual);
    $this->assert_str_equals( $expected, $actual );

    return;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: Foswiki:Main.PaulHarvey

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
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
