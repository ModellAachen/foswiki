# See bottom of file for license and copyright information
package MongoDBPluginTests;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use constant TRACE => 0;

use Data::Dumper();
use Foswiki::Plugins::MongoDBPlugin qw(writeDebug);
use Foswiki::Plugins::MongoDBPlugin::DB();

# Set up the test fixture
sub set_up {
    my ($this) = @_;

    $this->SUPER::set_up();

    return;
}

sub _topicObjectTooManyFields {
    my ($this) = @_;
    my $test_toomany_web = "$this->{test_web}/TooManyFieldsWeb";
    my $num_fields =
      Foswiki::Plugins::MongoDBPlugin::DB->_MAX_NUM_INDEXES() + 10;

    writeDebug("Creating a topic with $num_fields formfields\n") if TRACE;
    $this->assert(
        $Foswiki::cfg{Store}{Listeners}
          {'Foswiki::Plugins::MongoDBPlugin::Listener'},
        'MongoDBPlugin is listening to Foswiki store events'
    );
    $this->{session}{store}
      ->setListenerPriority( 'Foswiki::Plugins::MongoDBPlugin::Listener', 0 );
    Foswiki::Func::createWeb( $test_toomany_web, '_default' );
    my ($topicObject) =
      Foswiki::Func::readTopic( $test_toomany_web, $this->{test_topic} );

    $topicObject->putAll( 'FIELD',
        map { { name => "Field$_", value => "value $_" } }
          ( 1 .. $num_fields ) );
    writeDebug("Before save...\n") if TRACE;
    $topicObject->save();
    writeDebug("After save.\n") if TRACE;
    $this->{session}{store}
      ->setListenerPriority( 'Foswiki::Plugins::MongoDBPlugin::Listener', 1 );

    return $topicObject;
}

# Item10944: when loading a web which has too many formfields, MongoDBPlugin was
# using up all its 64 indexes on them before it got a chance to set indexes on
# the *critical* (minimum) fields needed for reliable operation, Eg. topic, web,
# address, etc.
sub test_too_many_indexes {
    my ($this)          = @_;
    my $topicObject     = $this->_topicObjectTooManyFields();
    my $MongoDBPluginDB = Foswiki::Plugins::MongoDBPlugin->getMongoDB();

    # Drop the web from mongo, this simulates the situation where we are
    # importing a web into an empty MongoDB, where the web has a topic with
    # 'too many' formfields.
    $MongoDBPluginDB->remove( $topicObject->web() );
    Foswiki::Plugins::MongoDBPlugin::updateWebCache( $topicObject->web() );
    my $mongo_collection =
      $MongoDBPluginDB->_getCollection( $topicObject->web(), 'current' );
    my %indexed = map { %{ $_->{key} || {} } } $mongo_collection->get_indexes();

    foreach my $field (
        qw(_topic address TOPICINFO.rev TOPICINFO.author TOPICINFO.date TOPICPARENT.name CREATEINFO.date CREATEINFO.author)
      )
    {
        $this->assert( $indexed{$field}, "Field '$field' is indexed" );
    }

    return;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012 Foswiki Contributors. Foswiki Contributors
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
