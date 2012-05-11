#
# Copyright (C) Motorola 2003 - All rights reserved
#
package  Foswiki::Plugins::FormQueryPlugin::WebDB;
use Foswiki::Contrib::DBCacheContrib;
our @ISA = qw( Foswiki::Contrib::DBCacheContrib );

use strict;
use Assert;

use Time::ParseDate;

use Foswiki::Contrib::DBCacheContrib         ();
use Foswiki::Contrib::DBCacheContrib::Search ();

use Foswiki::Plugins::FormQueryPlugin::Relation    ();
use Foswiki::Plugins::FormQueryPlugin::TableFormat ();
use Foswiki::Plugins::FormQueryPlugin::TableDef    ();
use Foswiki::Plugins::FormQueryPlugin::TablerowDef ();

# A Web DB is a hash keyed on topic name

my %prefs;
my @relations;
my %queries;    # Map from name to queries
my %webs;       # Map from name to web

# PUBLIC
sub new {
    my ( $class, $web ) = @_;

    my $this = $class->SUPER::new( $web, "_FormQueryCache" );

    $this->{_tables} = undef;

    $this->init($web) if ( defined($web) );

    return $this;
}

sub query {
    my ( $this, $name ) = @_;
    return $queries{$name};
}

# PUBLIC late initialisation of this object, used when serialising
# from a file where the web is not known at the time the object
# is created.
sub init {
    my ( $this, $web ) = @_;

    $this->{_web} = $web;

    my $rtext = Foswiki::Func::getPreferencesValue("FORMQUERYPLUGIN_RELATIONS")
      || "";
    my $tablenames =
      Foswiki::Func::getPreferencesValue("FORMQUERYPLUGIN_TABLES") || "";

    foreach my $relation ( split( /;/, $rtext ) ) {
        push( @relations,
            new Foswiki::Plugins::FormQueryPlugin::Relation($relation) );
    }

    my @tables;

    foreach my $table ( split( /\s*,\s*/, $tablenames ) ) {
        if ( $table =~ s/^all$//i ) {

            # Insert a special flag to indicate all tables should be read
            $this->{_tables}{all} = 1;
            return;
        }
        if ( !( Foswiki::Func::topicExists( $web, $table ) ) ) {
            Foswiki::Func::writeWarning(
                "No such table template topic '$table'");
        }
        else {
            my $text = Foswiki::Func::readTopicText( $web, $table );
            my $ttype = new Foswiki::Plugins::FormQueryPlugin::TableDef($text);
            if ( defined($ttype) ) {
                $this->{_tables}{$table} = $ttype;
                push( @tables, $table );
            }
            else {
                Foswiki::Func::writeWarning(
                    "Error in table template topic '$table'");
            }
        }
    }
}

# Invoked by superclass for each line in a topic.
sub readTopicLine {
    my ( $this, $topic, $meta, $line, $lines ) = @_;

    my $text = $line;

    # Handle tables defined through %EDITTABLE{}% tags
    while (( $line =~ s/%(EDITTABLE){(.*)}%// )
        || ( $line =~ s/%(EDITTABLEROW){(.*)}%// ) )
    {
        my $type  = $1;
        my $attrs = new Foswiki::Attrs($2);
        my $tablename =
          $attrs->{ $type eq 'EDITTABLE' ? 'include' : 'template' };
        next unless $tablename;
        my $ttype = $this->{_tables}{$tablename};
        if ( !defined($ttype) ) {
            if ( $this->{_tables}{all} ) {
                if ( !Foswiki::Func::topicExists( $this->{_web}, $tablename ) )
                {
                    Foswiki::Func::writeWarning(
                        "No such table template topic '$tablename'");
                    return $text;
                }
                else {
                    my $table =
                      Foswiki::Func::readTopicText( $this->{_web}, $tablename );
                    if ( $type eq 'EDITTABLE' ) {
                        $ttype =
                          new Foswiki::Plugins::FormQueryPlugin::TableDef(
                            $table);
                    }
                    else {
                        $ttype =
                          new Foswiki::Plugins::FormQueryPlugin::TablerowDef(
                            $table);
                    }
                    if ( defined($ttype) ) {
                        $this->{_tables}{$tablename} = $ttype;
                    }
                    else {
                        Foswiki::Func::writeWarning(
                            "Error in table template topic '$table'");
                        return $text;
                    }
                }
            }
            else {
                return $text;
            }
        }

        # TimSlidel: collapse multiple instances
        # of the same table type into a single table

        # Read table into temporary structure
        my $lc       = 0;
        my $tmptable = '';
        my $aftertable;
        while ( scalar(@$lines) ) {
            my $line = shift(@$lines);
            if ( $line =~ s/\\\s*$//o ) {
                $text .= $line;

                # This row is continued on the next line
                $tmptable .= $line;
            }
            elsif ( $line =~ m/\|\s*$/o ) {
                $text .= $line;

                # This line terminates a row
                $tmptable .= "$line\n";
                if ( $lc == 0 ) {

                    # It's the header, ignore it
                }
                $lc++;
            }
            elsif ( $line !~ m/^\s*\|/o ) {

                # This is not a valid row start, so must be the
                # end of the table. Put it back.
                unshift( @$lines, $line );
                last;
            }
        }

        # Apply SpreadsheetPlugin to table
        eval {
            require Foswiki::Plugins::SpreadSheetPlugin;
            Foswiki::Plugins::SpreadSheetPlugin::commonTagsHandler($tmptable);
        };

        # ignore if it fails; may not be installed

        # Now read the table into the cache structure
        my $table = $meta->fastget($tablename);
        if ( !defined($table) ) {
            $table = $this->{archivist}->newArray();
        }
        $lc = 0;
        my $row = "";
        foreach $line ( split( /\n/, $tmptable ) ) {
            if ( $line =~ s/\\\s*$//o ) {

                # This row is continued on the next line
                $row .= $line;
            }
            elsif ( $line =~ m/\|\s*$/o ) {

                # This line terminates a row
                $row .= $line;
                if ( $lc == 0 ) {

                    # It's the header, ignore it
                }
                else {

                    # Load the row
                    my $rowmeta = $this->{archivist}->newMap();
                    $ttype->loadRow( $row, $rowmeta );

                    # $rowmeta->set( "topic", $topic );
                    $rowmeta->set( "_up", $meta );
                    $table->add($rowmeta);
                }
                $row = "";
                $lc++;
            }
            elsif ( $line !~ m/^\s*\|/o ) {

                # This is not a valid row start, so must be the
                # end of the table
                last;
            }
        }
        $meta->set( $tablename, $table );
    }

    return $text;
}

# PROTECTED called by superclass when one or more topics had
# to be reloaded from disc.
sub onReload {
    my ( $this, $topics ) = @_;

    # Build relations
    $this->_extractRelations();
}

# PRIVATE Remove a topic from the db, unlinking all the relations
sub remove {
    my ( $this, $topic ) = @_;
    my $meta = $this->SUPER::remove($topic);
    foreach my $relation (@relations) {
        my $rname = $relation->{relation};
        my $f     = $meta->fastget( $relation->childToParent() );
        if ( defined($f) ) {

            # remove back-pointers to this from parent
            my $bp = $f->fastget( $relation->parentToChild() );
            my $i  = $bp->find($meta);
            $bp->remove($i) if ( $i >= 0 );
        }
        my $rlist = $meta->fastget( $relation->parentToChild() );
        if ( defined($rlist) && $rlist->size() > 0 ) {
            foreach my $child ( $rlist->getValues() ) {
                $child->set( $relation->childToParent(), undef );
            }
        }
    }
}

# PRIVATE extract childof relationships. This is done by applying
# the relation to each topic to see if another topic exists that has
# the requested relation to it.
sub _extractRelations {
    my $this  = shift;
    my $cache = $this->cache;

    foreach my $relation (@relations) {
        foreach my $topic ( $cache->getKeys() ) {
            my $parent = $relation->apply($topic);
            if ( defined($parent) ) {
                my $parentMeta = $cache->fastget($parent);
                if ( defined($parentMeta) ) {
                    my $childMeta = $cache->fastget($topic);
                    $childMeta->set( $relation->childToParent(), $parentMeta );
                    my $known =
                      $parentMeta->fastget( $relation->parentToChild() );
                    if ( !defined($known) ) {
                        $known = $this->{archivist}->newArray();
                        $parentMeta->set( $relation->parentToChild(), $known );
                    }
                    if ( $known->find($childMeta) < 0 ) {
                        $known->add($childMeta);
                    }
                }
            }
        }
    }
}

# PUBLIC debug print
sub toString {
    my $this = shift;
    my $text = "WebDB for web " . $this->{_web} . "\n";

    $text .= $this->cache->toString(@_);

    return $text;
}

# PUBLIC
# Run a query on the DB.
# It may optionally have the following field:
# form   Name f the form type to run the query on
# It must has the field
# search Boolean expression for the query
sub formQueryOnQuery {
    my ( $name, $string, $query, $extract, $case ) = @_;

    if ( !defined($name) ) {
        throw Error::Simple "'name' not defined";
    }
    return _search( $webs{$query}, $name, $string, $queries{$query}, $query,
        $extract, $case );
}

sub formQueryOnDB {
    my ( $this, $name, $string, $extract, $case, $multiple ) = @_;

    if ( !defined($name) ) {
        throw Error::Simple "'name' not defined";
    }

    # Make sure the DB is loaded
    my ( $rc, $rf, $r ) = $this->load(0);
    ASSERT( $this->cache ) if DEBUG;

    #print STDERR "Cache: $rc, File: $rf, Removed: $r\n";
    return _search( $this->{_web}, $name, $string, $this->cache, "ROOT",
        $extract, $case, $multiple );
}

# PRIVATE
sub _search {
    my ( $web, $name, $string, $query, $queryname, $extract, $case, $multiple )
      = @_;

    my $search;

    eval { $search = new Foswiki::Contrib::DBCacheContrib::Search($string); };

    if ( $@ || !$search ) {
        throw Error::Simple(
            "'search' not defined, or invalid search expression: $@");
    }

    if ( !defined($query) ) {
        throw Error::Simple "Query '$queryname' not defined";
    }

    if ( $query->size() == 0 ) {
        throw Error::Simple "Query '$queryname' returned no values";
    }

    delete( $queries{$name} ) unless $multiple;
    my $matches = $query->search( $search, $case );
    my $realMatches;
    if ($multiple) {
        $realMatches = $queries{$name};
    }
    $realMatches = new Foswiki::Contrib::DBCacheContrib::MemArray()
      unless $realMatches;

    if ( defined($extract) && $matches->size() > 0 ) {

        # Extract a defined subfield and make the query result an
        # array of the subfield. If the subfield is an array, flatten out
        # the array.
        foreach my $match ( $matches->getValues() ) {

            #print STDERR $match->get('topic')." $extract from "
            #.join(' ',$match->getKeys()),"\n";
            my $subfield = $match->get($extract);
            if ( defined($subfield) ) {
                if ( $subfield->isa('Foswiki::Contrib::DBCacheContrib::Array')
                    && ( $subfield->size() > 0 ) )
                {
                    foreach my $entry ( $subfield->getValues() ) {
                        $realMatches->add($entry);
                    }
                }
                elsif (
                    $subfield->isa('Foswiki::Contrib::DBCacheContrib::Array') )
                {

                    #print STDERR "WARNING: array $extract is empty\n";
                    # Empty array
                }
                else {
                    $realMatches->add($subfield);
                }
            }
        }
        $matches = $realMatches;
    }
    elsif ( $matches->size() > 0 ) {
        foreach my $match ( $matches->getValues() ) {
            $realMatches->add($match);
        }
        $matches = $realMatches;
    }

    if ( !defined($matches) || $matches->size() == 0 ) {
        throw Error::Simple "No values returned";
    }
    $webs{$name}    = $web;
    $queries{$name} = $matches;

    return "";
}

# PUBLIC
sub tableFormat {
    my ( $name, $format, $attrs ) = @_;

    if ( !defined($name) ) {
        throw Error::Simple "'name' not defined";
    }

    if ( !defined($format) ) {
        throw Error::Simple "'format' not defined";
    }

    my $fmt = new Foswiki::Plugins::FormQueryPlugin::TableFormat($attrs);

    $fmt->addToCache($name);

    return "";
}

# PUBLIC show a previously defined query
# sort   Comma-separated list of fields to sort on
# format format of the fields in the table. The format is a text
#        string which is expanded by replacing occurrences of
#        $<fieldname>. The special <fieldname> "topic" is supported
#        to insert the topic name.
# header header of the table
# sort   Comma-separated list of fields to sort on
# start  (optional) Render rows starting from start (1st row == 1)
# limit (optional) Render a maximum of limit rows
sub showQuery {
    my ( $name, $format, $attrs, $topic, $web ) = @_;

    if ( !defined($name) ) {
        throw Error::Simple "'query' not defined";
    }

    if ( !defined($format) ) {
        throw Error::Simple "'format' not defined";
    }
    $format = new Foswiki::Plugins::FormQueryPlugin::TableFormat($attrs);

    if ( !defined($format) ) {
        throw Error::Simple "Table format not defined";
    }

    my $matches = $queries{$name};
    if ( !defined($matches) || $matches->size() == 0 ) {
        throw Error::Simple "Query '$name' is empty";
    }

    ## get finished html or twiki format table as string
    # Patch from SimonHardyFrancis
    return $format->formatTable( $matches, $attrs->{separator},
        $attrs->{newline}, $attrs->{start}, $attrs->{limit}, $topic, $web );
}

# PUBLIC return the sum of all occurrences of a numeric
# field in a query
sub sumQuery {
    my ( $name, $field ) = @_;

    if ( !defined($name) ) {
        throw Error::Simple "'query' not defined";
    }

    if ( !defined($field) ) {
        throw Error::Simple "'field' not defined";
    }

    my $matches = $queries{$name};
    if ( !defined($matches) || $matches->size() == 0 ) {
        throw Error::Simple "Query '$name' has no values";
    }

    return $matches->sum($field);
}

sub getQueryInfo {
    my ( $name, $limit ) = @_;

    if ( defined($name) && !$name eq "" ) {
        my $matches = $queries{$name};
        if ( !defined($matches) || $matches->size() == 0 ) {
            throw Error::Simple "Query '$name' contains no values";
        }
        return $matches->toString($limit);
    }
}

sub getTopicInfo {
    my ( $this, $topic, $limit ) = @_;

    $this->SUPER::load();
    my $text = '';
    if ( defined($topic) && !$topic eq '' ) {
        my $ti = $this->get($topic);
        if ( defined($ti) ) {
            $text = $ti->toString($limit);
        }
        else {
            $text =
              CGI::span( { class => 'twikiAlert' }, $topic . ' not known' );
        }
    }
    else {
        $text = $this->toString();
    }
    return $text;
}

# PUBLIC return the number of matches for the specified query.
sub matchCount {
    my ($name) = @_;

    if ( !defined($name) ) {
        throw Error::Simple "'query' not defined";
    }

    my $matches = $queries{$name};
    if ( defined($matches) ) {
        return $matches->size();
    }
    return 0;
}

sub toTable {
    my ( $name, $format, $attrs, $topic, $web ) = @_;

    if ( !defined($name) ) {
        throw Error::Simple "'query' not defined";
    }

    if ( !defined($format) ) {
        throw Error::Simple "'format' not defined";
    }
    $format = new Foswiki::Plugins::FormQueryPlugin::TableFormat($attrs);

    if ( !defined($format) ) {
        throw Error::Simple "Table format not defined";
    }

    my $matches = $queries{$name};
    if ( !defined($matches) || $matches->size() == 0 ) {
        throw Error::Simple "Query '$name' returned no values";
    }

    return $format->toTable( $matches, $attrs->{start}, $attrs->{limit}, $topic,
        $web );
}

1;
