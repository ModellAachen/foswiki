#
# Copyright (C) Motorola 2003 - All rights reserved
#
use strict;

use Time::ParseDate;
use Benchmark;

use TWiki::Contrib::DBCacheContrib;
use TWiki::Contrib::DBCacheContrib::Search;

use TWiki::Plugins::XpTrackerPlugin::HiddenTableDef;

package  TWiki::Plugins::XpTrackerPlugin::WebDB;

# A DB is a hash keyed on topic name

@TWiki::Plugins::XpTrackerPlugin::WebDB::ISA =
  ("TWiki::Contrib::DBCacheContrib");

my %prefs;
my %webs;    # Map from name to web
use TWiki::Plugins::XpTrackerPlugin;

# PUBLIC
sub new {

    #    my ( $class, $web, @rels ) = @_;
    my $class = shift;
    my $web   = shift;

    # Make this a managed store (i.e., no files will be manipulated externally)
    my $this = bless( $class->SUPER::new( $web, '_xpcache', 1 ), $class );

    $this->init( $web, @_ );
    return $this;
}

# PUBLIC late initialisation of this object, used when serialising
# from a file where the web is not known at the time the object
# is created.
sub init {
    my ( $this, $web, @rels ) = @_;

    $this->{_web} = $web;
    $this->{_tables}{'all'} = 1;

    $this->{_relations} = ();
    foreach my $relation (@rels) {
        $relation =~ s/\s//go;
        my ( $child2parent, $parent2child ) = split( /,/, $relation );
        push @{ $this->{_relations} }, [ $child2parent, $parent2child ];
    }

}

# Invoked by superclass for each line in a topic.
sub readTopicLine {
    my ( $this, $topic, $meta, $line, $fh ) = @_;

    my $text = $line;

    # Handle tables defined through %EDITHIDDENTABLE{}% tags
    if ( $line =~ s/^%META:TABLE{(.*?)}%//o ) {
        my $attrs     = new TWiki::Attrs($1);
        my $tablename = $attrs->{template};
        my $ttype     = $this->{_tables}{$tablename};
        if ( !defined($ttype) ) {
            if ( !( TWiki::Func::topicExists( $this->{_web}, $tablename ) ) ) {
                TWiki::Func::writeWarning(
                    "No such table template topic '$tablename'");
                return $text;
            }
            else {
                my $table =
                  TWiki::Func::readTopicText( $this->{_web}, $tablename );
                $ttype =
                  new TWiki::Plugins::XpTrackerPlugin::HiddenTableDef($table);
                if ( defined($ttype) ) {
                    $this->{_tables}{$tablename} = $ttype;
                }
                else {
                    TWiki::Func::writeWarning(
                        "Error in table template topic '$table'");
                    return $text;
                }
            }
        }

        # Now read the table into the cache structure
        my $table = $meta->fastget($tablename);
        if ( !defined($table) ) {
            $table = new TWiki::Contrib::DBCacheContrib::Array();
        }

        # Load the row
        my $rowmeta =
          $ttype->loadRow( $attrs, "TWiki::Contrib::DBCacheContrib::Map" );

        #            $rowmeta->set( "topic", $topic );
        $rowmeta->set( "_up", $meta );
        $table->add($rowmeta);
        $meta->set( $tablename, $table );
    }

    return $line;
}

sub onReload {
    my ( $this, $topics ) = @_;

    $this->_extractRelations();
}

sub _extractRelations {
    my $this = shift;

    foreach my $relation ( @{ $this->{_relations} } ) {
        foreach my $topic ( $this->getKeys() ) {
            my ( $parent, $child ) = apply( $this, $relation->[0], $topic );
            if ( defined($parent) ) {
                $child->set( $relation->[0], $parent );
                my $known = $parent->fastget( $relation->[1] );
                if ( !defined($known) ) {
                    $known = new TWiki::Contrib::DBCacheContrib::Array();
                    $parent->set( $relation->[1], $known );
                }
                if ( !$known->contains($child) ) {
                    $known->add($child);
                }
            }
        }
    }
}

# PUBLIC apply the relation to derive a new topic name
sub apply {
    my ( $db, $childToParent, $topic ) = @_;
    my $it = $db->fastget($topic);
    my $form = $it->fastget('form') if $it;
    $form = $it->fastget($form) if $form;
    my $parent = $form->fastget($childToParent) if $form;
    my $parentMeta;
    if ($parent) {
        if ( $parent eq 'ROOT' ) {
            $parentMeta = $db;
        }
        else {
            $parentMeta = $db->fastget($parent);
        }
        return ( $parentMeta, $it );
    }
    else {
        return ( undef, undef );
    }
}

1;
