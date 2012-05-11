# See bottom of file for license and copyright information
package SemanticLinksPluginTests;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use strict;
use warnings;

sub set_up {
    my ($this) = @_;

    $this->SUPER::set_up();
    $Foswiki::cfg{Plugins}{SemanticLinksPlugin}{Enabled} = 1;
    $this->createNewFoswikiSession();
    require Foswiki::Plugins::SemanticLinksPlugin::Core;
    Foswiki::Plugins::SemanticLinksPlugin::Core::init();

    return;
}

# SMELL: Why isn't ACRO linking?
sub test_simple_plain_links {
    my $this = shift;
    my $text = <<'HERE';
   * [[Bracketed.Link]]
   * [[Bracketed.LinkWithTitle][with title]]
   * WeblessWikiWord
   * Web.WikiWord
   * ACRO
   * System.ACRONYM
   * Foswiki:System.InterwikiPlugin
   * [[Foswiki:System.BracketedInterwikiPlugin]]
   * [[Foswiki:System.BracketedInterwikiPluginWithTitle][with title]]
   * http://example.com/bare/link
   * [[http://example.com/bracketed/link]]
   * [[http://example.com/bracketed/link/with/title][with title]]
   * [<nop>[nopBracketed.Link]]
   * [<nop>[nopBracketed.LinkWithTitle][with title]]
   * <nop>NopWeblessWikiWord
   * <nop>NopWeb.WikiWord
   * <nop>NOPACRO
   * <nop>NopSystem.ACRONYM
   * <nop>Foswiki:NopSystem.InterwikiPlugin
   * [<nop>[Foswiki:NopSystem.BracketedInterwikiPlugin]]
   * [<nop>[Foswiki:NopSystem.BracketedInterwikiPluginWithTitle][with title]]
   * <nop>http://nopexample.com/bare/link
   * [<nop>[http://nopexample.com/bracketed/link]]
   * [<nop>[http://nopexample.com/bracketed/link/with/title][with title]]
   * ![[ExBracketed.Link]]
   * ![[ExBracketed.LinkWithTitle][with title]]
   * !ExWeblessWikiWord
   * !ExWeb.WikiWord
   * !EXACRO
   * !ExSystem.ACRONYM
   * !Foswiki:ExSystem.InterwikiPlugin
   * ![[Foswiki:ExSystem.BracketedInterwikiPlugin]]
   * ![[Foswiki:ExSystem.BracketedInterwikiPluginWithTitle][with title]]
   * !http://exexample.com/bare/link
   * ![[http://exexample.com/bracketed/link]]
   * ![[http://exexample.com/bracketed/link/with/title][with title]]
HERE

    # There's only 7 entries here, because SLP returns only *unique* web.topic
    # and http:// links
    my %expected_data = (
        'LINK' => [
            {
                'topic'   => 'WikiWord',
                'web'     => 'Web',
                'name'    => 9,
                'type'    => 'autolink',
                'address' => 'Web.WikiWord',
                'scope'   => 'internal'
            },
            {
                'name'    => 6,
                'type'    => 'bracket',
                'address' => 'http://example.com/bracketed/link/with/title',
                'scope'   => 'external'
            },
            {
                'topic' => 'WeblessWikiWord',
                'web'   => 'TemporarySemanticLinksPluginTestsUsersWeb',
                'name'  => 8,
                'type'  => 'autolink',
                'address' =>
                  'TemporarySemanticLinksPluginTestsUsersWeb.WeblessWikiWord',
                'scope' => 'internal'
            },
            {
                'topic'   => 'BracketedInterwikiPluginWithTitle',
                'web'     => 'Foswiki:System',
                'name'    => 4,
                'type'    => 'bracket',
                'address' => 'Foswiki:System.BracketedInterwikiPluginWithTitle',
                'scope'   => 'internal'
            },
            {
                'topic'   => 'BracketedInterwikiPlugin',
                'web'     => 'Foswiki:System',
                'name'    => 3,
                'type'    => 'bracket',
                'address' => 'Foswiki:System.BracketedInterwikiPlugin',
                'scope'   => 'internal'
            },
            {
                'name'    => 7,
                'type'    => 'autolink',
                'address' => 'http://example.com/bare/link',
                'scope'   => 'external'
            },
            {
                'topic'   => 'ACRONYM',
                'web'     => 'System',
                'name'    => 10,
                'type'    => 'autolink',
                'address' => 'System.ACRONYM',
                'scope'   => 'internal'
            },
            {
                'name'    => 5,
                'type'    => 'bracket',
                'address' => 'http://example.com/bracketed/link',
                'scope'   => 'external'
            },
            {
                'topic'   => 'LinkWithTitle',
                'web'     => 'Bracketed',
                'name'    => 2,
                'type'    => 'bracket',
                'address' => 'Bracketed.LinkWithTitle',
                'scope'   => 'internal'
            },
            {
                'topic'   => 'Link',
                'web'     => 'Bracketed',
                'name'    => 1,
                'type'    => 'bracket',
                'address' => 'Bracketed.Link',
                'scope'   => 'internal'
            }
        ]
    );

    foreach my $topic (qw(ACRONYM ACRO NOPACRO EXACRO)) {
        my ($acronymTopicObj) =
          Foswiki::Func::readTopic( $this->{test_web}, $topic );
        $acronymTopicObj->save();
        $acronymTopicObj->finish();
    }

    my %actual_data =
      Foswiki::Plugins::SemanticLinksPlugin::Core::_parse( $text,
        $this->{test_topicObject} );

    $this->assert_deep_equals( \%expected_data, \%actual_data );

    # Check the save handler
    $this->{test_topicObject}->text($text);
    $this->{test_topicObject}->save();
    $this->_check_save( \%expected_data );

    return;
}

sub test_simple_semantic_links {
    my ($this) = @_;
    my $text = <<'HERE';
   * [[Property::Value]]
   * [[:NonProperty::NonValue]]
   * ![[ExProperty::ExValue]]
   * [<nop>[NopProperty::NopValue]]
   * [<nop>[:NopExProperty::NopValue]]
HERE
    my %expected_data = (
        'SLPROPERTYVALUE' => [],
        'SLPROPERTY'      => [
            {
                'num'  => 1,
                'name' => 'Property'
            }
        ],
        'LINK' => [
            {
                'topic' => 'NonProperty::NonValue',
                'web'   => 'TemporarySemanticLinksPluginTestsUsersWeb',
                'name'  => 2,
                'type'  => 'bracket',
                'address' =>
'TemporarySemanticLinksPluginTestsUsersWeb.NonProperty::NonValue',
                'scope' => 'internal'
            },
            {
                'topic'   => 'Value',
                'web'     => 'TemporarySemanticLinksPluginTestsUsersWeb',
                'name'    => 1,
                'type'    => 'semantic',
                'address' => 'TemporarySemanticLinksPluginTestsUsersWeb.Value',
                'scope'   => 'internal'
            }
        ],
        'SLMETAPROPERTY' => [],
        'SLPROPERTIES'   => [],
        'SLVALUE'        => [
            {
                'propertyseq' => 1,
                'valueweb'    => 'TemporarySemanticLinksPluginTestsUsersWeb',
                'value'       => 'Value',
                'name'        => 'Property__1',
                'propertyweb' => 'TemporarySemanticLinksPluginTestsUsersWeb',
                'valuetopic'  => 'Value',
                'valueaddress' =>
                  'TemporarySemanticLinksPluginTestsUsersWeb.Value',
                'propertyaddress' =>
                  'TemporarySemanticLinksPluginTestsUsersWeb.Property',
                'property' => 'Property'
            }
        ],
        'SLMETAVALUE' => []
    );

    # Check the links were processed correctly
    my %actual_data =
      Foswiki::Plugins::SemanticLinksPlugin::Core::_parse( $text,
        $this->{test_topicObject} );
    $this->assert_deep_equals( \%expected_data, \%actual_data );

    # Check the save handler
    $this->{test_topicObject}->text($text);
    $this->{test_topicObject}->save();
    $this->_check_save( \%expected_data );
    $this->{test_topicObject}->text('nothing');
    $this->{test_topicObject}->save();
    $this->_check_save( {} );
    $this->{test_topicObject}
      ->putAll( 'FIELD', { name => 'TestFormfield', value => $text } );
    $this->{test_topicObject}->save();
    $this->_check_save( \%expected_data );

    return;
}

sub _check_save {
    my ( $this, $expected_data ) = @_;
    my $checkObj;

    ($checkObj) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    foreach my $META (
        qw(SLMETAVALUE SLVALUE SLPROPERTIES SLMETAPROPERTY SLPROPERTY SLPROPERTYVALUE LINK)
      )
    {
        my @data = $checkObj->find($META);

        $this->assert_deep_equals( $expected_data->{$META} || [],
            \@data || [] );
    }
    $checkObj->finish();

    return;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

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
