# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2009 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::ClassificationPlugin::Hierarchy;

use strict;
use Foswiki::Plugins::DBCachePlugin::Core ();
use Foswiki::Plugins::ClassificationPlugin::Category ();
use Storable ();
use Foswiki::Prefs ();
use Foswiki::Func ();

use constant OBJECTVERSION => 0.81;
use constant CATWEIGHT => 1.0; # used in computeSimilarity()
use constant DEBUG => 0; # toggle me

use vars qw(%insideInit);

###############################################################################
# static
sub writeDebug {
  #&Foswiki::Func::writeDebug('- ClassificationPlugin - '.$_[0]) if DEBUG;
  print STDERR '- ClassificationPlugin::Hierarchy - '.$_[0]."\n" if DEBUG;
}

################################################################################
# constructor
sub new {
  my $class = shift;
  my $web = shift;

  $web =~ s/\//\./go;
  #writeDebug("new hierarchy for web $web");
  my $this;
  my $cacheFile = Foswiki::Plugins::ClassificationPlugin::Core::getCacheFile($web);
  
  my $session = $Foswiki::Plugins::SESSION;
  my $query = Foswiki::Func::getCgiQuery();
  my $refresh = '';
  $refresh = $query->param('refresh') || '' if defined $session;
  $refresh = ($refresh =~ /on|class|cat/)?1:0;

  unless ($refresh) {
    eval {
      $this = Storable::lock_retrieve($cacheFile);
    };
  }

  if ($this && $this->{_version} == OBJECTVERSION) {
    writeDebug("restored hierarchy object (v$this->{_version}) from $cacheFile");
    #if (DEBUG) {
    #  use Data::Dumper;
    #  writeDebug(Dumper($this));
    #}
    return $this;
  } else {
    writeDebug("creating new object");
  }

  $this = {
    web=>$web,
    idCounter=>0,
    @_
  };

  $this = bless($this, $class);
  $this->init();

  $this->{gotUpdate} = 1;
  $this->{_version} = OBJECTVERSION;

  return $this;
}

################################################################################
# does not invalidate this object; it is kept intact to be cached in memory
# in a mod_perl or speedy-cgi setup; we only store it to disk if we updated it 
sub finish {
  my $this = shift;

  #writeDebug("called finish()");
  my $gotUpdate = $this->{gotUpdate};
  $this->{gotUpdate} = 0;

  if (defined($this->{_categories})) {
    foreach my $cat ($this->getCategories()) {
      $gotUpdate ||= $cat->{gotUpdate};
      $cat->{gotUpdate} = 0;
    }
  }

  #writeDebug("gotUpdate=$gotUpdate");
  if ($gotUpdate) {
    writeDebug("saving hierarchy $this->{web}");
    my $cacheFile = Foswiki::Plugins::ClassificationPlugin::Core::getCacheFile($this->{web});

    # SMELL: don't cache the prefs for now
    undef $this->{_prefs}; 

    #if (DEBUG) {
    #  use Data::Dumper;
    #  writeDebug(Dumper($this));
    #}

    Storable::lock_store($this, $cacheFile);
  }
  writeDebug("done finish()");

}

################################################################################
# mode = 0 -> do nothing
# mode = 1 -> a tagged topic has been saved
# mode = 2 -> a categorized topic has been saved
# mode = 3 -> a classified topic has been saved
# mode = 4 -> a category has been saved
# mode = 5 -> clear all
sub purgeCache {
  my ($this, $mode, $touchedCats) = @_;

  return unless $mode;
  writeDebug("purging hierarchy cache for $this->{web} - mode = $mode");

  if ($mode == 1 || $mode == 3 || $mode > 4) { # tagged and classified topics
    undef $this->{_similarity};
  } 

  if ($mode > 1) { # categorized and classified topics
    foreach my $catName (@$touchedCats) {
      my $cat = $this->getCategory($catName);
      $cat->purgeCache() if $cat;
      undef $this->{_catsOfTopic};
    }
  } 

  if ($mode > 3) { # category topics
    # nuke all categories
    writeDebug("nuke all categories");
    foreach my $cat (values %{$this->{_categories}}) {
      $cat->purgeCache() if $cat;
    }
    undef $this->{_categories};
    undef $this->{_distance};
    undef $this->{_prefs};
    undef $this->{_top};
    undef $this->{_bottom};
    undef $this->{_aclAttribute};
    $this->{idCounter} = 0;
  }

  if ($mode > 4) { # clear all of the rest
    undef $this->{_catFields};
    undef $this->{_tagFields};
  }

  $this->{gotUpdate} = 1;
}

################################################################################
sub init {
  my $this = shift;

  # be anal
  die "recursive call to Hierarchy::init for $this->{web}" if $insideInit{$this->{web}};
  $insideInit{$this->{web}} = 1;

  writeDebug("called Hierarchy::init for $this->{web} ... EXPENSIVE");
  my $session = $Foswiki::Plugins::SESSION;
  $this->{_prefs} = new Foswiki::Prefs($session);

  my $db = Foswiki::Plugins::DBCachePlugin::Core::getDB($this->{web});

  # itterate over all topics and collect categories
  my $seenImport = {};
  foreach my $topicName ($db->getKeys()) {
    my $topicObj = $db->fastget($topicName);
    next unless $topicObj;
    my $form = $topicObj->fastget("form");
    next unless $form;
    $form = $topicObj->fastget($form);
    next unless $form;

    # get topic types
    my $topicType = $form->fastget("TopicType");
    next unless $topicType;

    if ($topicType =~ /\bCategory\b/) {
      # this topic is a category in itself
      #writeDebug("found category '$topicName' in web $this->{web}");
      my $cat = $this->{_categories}{$topicName};
      $cat = $this->createCategory($topicName) unless $cat;

      my $cats = $this->getCategoriesOfTopic($topicObj);
      if ($cats && @$cats) {
        $cat->setParents(@$cats);
      } else {
        $cat->setParents('TopCategory');
      }

      my $summary = $form->fastget("Summary") || '';
      $summary =~ s/<nop>//go;
      $summary =~ s/^\s+//go;
      $summary =~ s/\s+$//go;

      my $order = $form->fastget("Order");
      if (defined($order) && $order =~ /([+-]?\d+(?:\.\d)*)/) {
        $order = $1;
      } else {
        $order = 99999999;
      }

      my $title = $form->fastget("TopicTitle") || $topicName;
      $title =~ s/<nop>//go;
      $title =~ s/^\s+//go;
      $title =~ s/\s+$//go;
      $cat->setSummary($summary);
      $cat->setOrder($order);
      $cat->setTitle($title);
      $cat->setIcon($form->fastget("Icon"));

      #writeDebug("$topicName has got title '$title'");

      # import foregin categories
      $cat->importCategories($form->fastget("ImportedCategory"), $seenImport);
    }
  }

  writeDebug("checking for default categories");
  # every hierarchy has one top node
  my $topCat = 
    $this->{_categories}{'TopCategory'} || 
    $this->createCategory('TopCategory', title=>'Top', origWeb=>'');

  # every hierarchy has one bottom node
  my $bottomCat = 
    $this->{_categories}{'BottomCategory'} ||
    $this->createCategory('BottomCategory', title=>'Bottom', origWeb=>'');

  # remember these
  $this->{_top} = $topCat;
  $this->{_bottom} = $bottomCat;

  # init nested structures
  foreach my $cat (values %{$this->{_categories}}) {
    $cat->init();
  }

  # add categories with no children as a parent to BottomCategory
  my @bottomParents = ();
  foreach my $cat (values %{$this->{_categories}}) {
    next if $cat->getChildren() || $cat == $bottomCat;
    $cat->addChild($bottomCat);
    push @bottomParents, $cat;
  }
  $bottomCat->setParents(@bottomParents);

  # init these again
  foreach my $cat (@bottomParents) {
    $cat->init();
  }

  # reset distances, delay computeDistance til we need it
  undef $this->{_distance};
  if (DEBUG) {
    $this->computeDistance();
  }
  $this->{gotUpdate} = 1;

  if (0) {
    foreach my $cat (values %{$this->{_categories}}) {
      my $text = "$cat->{name}:";
      foreach my $child ($cat->getChildren()) {
	$text .= " $child->{name}";
      }
      writeDebug($text);
    }
    $this->printDistanceMatrix();
  }

  writeDebug("done init $this->{web}");
  delete $insideInit{$this->{web}};
}

################################################################################
sub printDistanceMatrix {
  return unless DEBUG;

  my ($this) = @_;

  my $distance = $this->{_distance} || $this->computeDistance();

  foreach my $catName1 (sort $this->getCategoryNames()) {
    my $cat1 = $this->{_categories}{$catName1};
    my $catId1 = $cat1->{id};
    foreach my $catName2 (sort $this->getCategoryNames()) {
      my $cat2 = $this->{_categories}{$catName2};
      my $catId2 = $cat2->{id};
      my $dist =  $$distance[$catId1][$catId2];
      next unless $dist;
      #writeDebug("distance($catName1/$catId1, $catName2/$catId2) = $dist");
    }
  }
}

################################################################################
# computes the distance between all categories using a Wallace-Kollias
# algorith for transitive closure
sub computeDistance {
  my $this = shift;

  my @distance;

  writeDebug("called computeDistance() Wallace-Kollias");

  my $topId = $this->{_top}->{id};
  $distance[$topId][$topId] = 0;

  my $bottomId = $this->{_bottom}->{id};
  $distance[$bottomId][$bottomId] = 0;

  # root of induction
  my %ancestors = ($topId=>$this->{_top});
  
  writeDebug("propagate");
  foreach my $child ($this->{_top}->getChildren()) {
    $distance[$topId][$child->{id}] = 1;
    $child->computeDistance(\@distance, \%ancestors);
  }

  writeDebug("finit");
  #my $loops = 0;
  my $maxId = $this->{idCounter}-1;
  for my $id1 (0..$maxId) {
    for my $id2 ($id1..$maxId) {
      next if $id1 == $id2;
      my $dist = $distance[$id1][$id2];
      if (defined($dist)) {
        $distance[$id2][$id1] = -$dist;
      } else {
        $dist = $distance[$id2][$id1];
        $distance[$id1][$id2] = -$dist if defined $dist;
      }
      #$loops++;
    }
  }

  #writeDebug("maxId=$maxId, loops=$loops");
  writeDebug("done computeDistance() Wallace-Kollias");

  #if (DEBUG) {
  #  use Data::Dumper;
  #  writeDebug(Dumper(\@distance));
  #}

  $this->{_distance} = \@distance;
  $this->{gotUpdate} = 1;

  return \@distance;
}

################################################################################
# this computes the minimum distance between two categories or a topic
# and a category or between two topics. if a non-category topic is under
# consideration then all of its categories are measured against each other
# while computing the overall minimal distances.  so simplest case
# is measuring the distance between two categories; the most general case is
# computing the min distance between two sets of categories.
sub distance {
  my ($this, $topic1, $topic2) = @_;

  #writeDebug("called distance($topic1, $topic2)");

  my %catSet1 = ();
  my %catSet2 = ();

  # if topic1/topic2 are of type Category then they are the objects themselves
  # to be taken under consideration

  # check topic1
  my $catObj = $this->getCategory($topic1);
  my $firstIsTopic;
  if ($catObj) { # known category
    $firstIsTopic = 0;
    $catSet1{$topic1} = $catObj->{id};
  } else {
    $firstIsTopic = 1;
    my $cats = $this->getCategoriesOfTopic($topic1);
    return undef unless $cats; # no categories, no distance
    foreach my $name (@$cats) {
      $catObj = $this->getCategory($name);
      $catSet1{$name} = $catObj->{id} if $catObj;
    }
  }

  # check topic2
  my $secondIsTopic;
  $catObj = $this->getCategory($topic2);
  if ($catObj) { # known category
    $secondIsTopic = 0;
    $catSet2{$topic2} = $catObj->{id};
  } else {
    $secondIsTopic = 1;
    my $cats = $this->getCategoriesOfTopic($topic2);
    return undef unless $cats; # no categories, no distance
    foreach my $name (@$cats) {
      $catObj = $this->getCategory($name);
      $catSet2{$name} = $catObj->{id} if $catObj
    }
  }
  return 0 if 
    $firstIsTopic == 1 &&
    $secondIsTopic == 1 &&
    $topic1 eq $topic2;

  if (DEBUG) {
    #writeDebug("catSet1 = ".join(',', sort keys %catSet1));
    #writeDebug("catSet2 = ".join(',', sort keys %catSet2));
  }

  # get the min distance between the two category sets
  $this->computeDistance() unless $this->{_distance};
  my $distance = $this->{_distance};
  my $min;
  foreach my $id1 (values %catSet1) {
    foreach my $id2 (values %catSet2) {
      my $dist = $$distance[$id1][$id2];
      next unless defined $dist;
      $min = $dist if !defined($min) || abs($min) > abs($dist);
    }
  }

  # both sets aren't connected
  return undef unless defined($min);

  $min = abs($min) + 2 if $firstIsTopic && $secondIsTopic;
  $min-- if $firstIsTopic;
  $min++ if $secondIsTopic;

  return $min;
}

################################################################################
# fast lookup of the distance between two categories
sub catDistance {
  my ($this, $cat1, $cat2) = @_;

  my $id1;
  my $id2;
  my $cat1Obj = $cat1;
  my $cat2Obj = $cat2;

  if (ref($cat1)) {
    $id1 = $cat1->{id};
  } else {
    $cat1Obj = $this->getCategory($cat1);
    return undef unless defined $cat1Obj;
    $id1 = $cat1Obj->{id};
  }

  if (ref($cat2)) {
    $id2 = $cat2->{id};
  } else {
    $cat2Obj = $this->getCategory($cat2);
    return undef unless defined $cat2Obj;
    $id2 = $cat2Obj->{id};
  }

  $this->computeDistance() unless $this->{_distance};
  my $dist = $this->{_distance}[$id1][$id2];
  #writeDebug("catDistance($cat1Obj->{name}, $cat2Obj->{name})=$dist");
  return $dist;
}

################################################################################
# find all topics that are similar to the given one i nthe current web
# similarity is computed by calculating the weighted matching coefficient (WMC)
# counting matching tags and categories between two topics. matching categorization
# is weighted in a way to matter more, that is two topics correlate more if
# they are categorized similarly than if they do based on tagging information.
# this is an rought adhoc model to reflect the intuitive importance in 
# knowledge management of category information versus tagging information.
# the provided threshold limits the number of topics that are considered similar
#
sub getSimilarTopics {
  my ($this, $topicA, $threshold) = @_;

  my @foundTopics = ();
  my $db = Foswiki::Plugins::DBCachePlugin::Core::getDB($this->{web});
  my $tagsA = $this->getTagsOfTopic($topicA);
  my $catsA = $this->getCategoriesOfTopic($topicA);
  foreach my $topicB ($db->getKeys()) {
    next if $topicB eq $topicA;
    my $similarity = $this->computeSimilarity($topicA, $topicB, $tagsA, $catsA);
    push @foundTopics, $topicB if $similarity >= $threshold;
  }

  return @foundTopics;
}

################################################################################
sub computeSimilarity {
  my ($this, $topicA, $topicB, $tagsA, $catsA, $tagsB, $catsB) = @_;

  #writeDebug("called computeSimilarity($topicA, $topicB)");

  # lookup cache
  my $similarity = $this->{_similarity}{$topicA}{$topicB};
  return $similarity if defined $similarity;

  # get missing info
  $tagsA = $this->getTagsOfTopic($topicA) unless $tagsA;
  $tagsB = $this->getTagsOfTopic($topicB) unless $tagsB;
  $catsA = $this->getCategoriesOfTopic($topicA) unless $catsA;
  $catsB = $this->getCategoriesOfTopic($topicB) unless $catsB;

  # compute
  my %tagsA = map {$_ => 1} @$tagsA;
  my %tagsB = map {$_ => 1} @$tagsB;
  my %catsA = map {$_ => 1} @$catsA;
  my %catsB = map {$_ => 1} @$catsB;

  my $onlyA = 0;
  my $onlyB = 0;
  my $intersection = 0;

  map {defined($tagsB{$_})?$intersection++:$onlyA++} @$tagsA;
  map {$onlyB++ unless defined $tagsA{$_}} @$tagsB;
  map {defined($catsB{$_})?$intersection+=CATWEIGHT:$onlyA+=CATWEIGHT} @$catsA;
  map {$onlyB+=CATWEIGHT unless defined $catsA{$_}} @$catsB;

  my $total = $onlyA + $onlyB + $intersection;
  $similarity = $total?$intersection/$total:0;
  #if (DEBUG && $similarity) {
  #  writeDebug("similarity($topicA, $topicB) = $similarity");
  #  writeDebug("onlyA=$onlyA, onlyB=$onlyB, intersection=$intersection, total=$total");
  #}

  # cache
  $this->{_similarity}{$topicA}{$topicB} = $similarity;
  $this->{gotUpdate} = 1;

  return $similarity;
}

################################################################################
# return true if cat1 subsumes cat2 (is an ancestor of)
sub subsumes {
  my ($this, $cat1, $cat2) = @_;

  my $result = $this->catDistance($cat1, $cat2);
  return (defined($result) && $result >= 0)?1:0;
}

################################################################################
sub getTagsOfTopic {
  my ($this, $topic) = @_;

  #writeDebug("called getTagsOfTopic");
  # allow topicName or topicObj
  my $topicObj;
  if (ref($topic)) {
    $topicObj = $topic;
  } else {
    my $db = Foswiki::Plugins::DBCachePlugin::Core::getDB($this->{web});
    $topicObj = $db->fastget($topic);
  }
  return undef unless $topicObj;

  my $form = $topicObj->fastget("form");
  return undef unless $form;
  $form = $topicObj->fastget($form);
  return undef unless $form;

  my $tags = $form->fastget('Tag');
  return undef unless $tags;

  my @tags = split(/\s*,\s*/, $tags);
  return \@tags;
}

################################################################################
sub getCategoriesOfTopic {
  my ($this, $topic) = @_;

  # allow topicName or topicObj
  my $topicObj;
  if (ref($topic)) {
    $topicObj = $topic;
    $topic = $topicObj->fastget('topic');
  } else {
    my $db = Foswiki::Plugins::DBCachePlugin::Core::getDB($this->{web});
    $topicObj = $db->fastget($topic);
  }
  return undef unless $topicObj;

  my $cats = $this->{_catsOfTopic}{$topic};
  return $cats if defined $cats;

  my $form = $topicObj->fastget("form");
  return undef unless $form;
  $form = $topicObj->fastget($form);
  return undef unless $form;

  #writeDebug("getCategoriesOfTopic()"); 

  # get typed topics
  my $topicType = $form->fastget("TopicType");
  return undef unless $topicType;

  my $catFields = $this->getCatFields(split(/\s*,\s*/,$topicType));
  return undef unless $catFields;
  #writeDebug("catFields=".join(', ', @$catFields));

  # get all categories in all category formfields
  my %cats = ();
  foreach my $catField (@$catFields) {
    # get category formfield
    #writeDebug("looking up '$catField'");
    my $cats = $form->fastget($catField);
    next unless $cats;
    #writeDebug("$catField=$cats");
    foreach my $cat (split(/\s*,\s*/, $cats)) {
      $cat =~ s/^\s+//go;
      $cat =~ s/\s+$//go;
      $cats{$cat} = 1 if $cat;
    }
  }
  @$cats = keys %cats;
  $this->{_catsOfTopic}{$topic} = $cats;
  $this->{gotUpdate} = 1;
  return $cats;
}


################################################################################
# get names of category formfields of a topictype
sub getCatFields {
  my ($this, @topicTypes) = @_;

  #writeDebug("called getCatFields()"); 

  my %allCatFields;
  foreach my $topicType (@topicTypes) {
    # lookup cache
    #writeDebug("looking up '$topicType' in cache");
    my $catFields = $this->{_catFields}{$topicType};
    if (defined($catFields)) {
      foreach my $cat (@$catFields) {
        $allCatFields{$cat} = 1;
      }
      next;
    }
    #writeDebug("looking up form definition for $topicType in web $this->{web}");
    @$catFields = ();
    $this->{_catFields}{$topicType} = $catFields;
    $this->{gotUpdate} = 1;

    # looup form definition -> ASSUMPTION: TopicTypes must be DataForms too
    my $db = Foswiki::Plugins::DBCachePlugin::Core::getDB($this->{web});
    my $formDef = $db->fastget($topicType);
    next unless $formDef;

    # check if this is a TopicStub
    my $formName = $formDef->fastget('form');
    next unless $formName; # woops got no form
    my $form = $formDef->fastget($formName);
    next unless $form;

    my $type = $form->fastget('TopicType') || '';
    #writeDebug("type=$type");

    if ($type =~ /\bTopicStub\b/ || $formName =~ /\bTopicStub\b/) {
      #writeDebug("reading stub");
      # this is a TopicStub, lookup the target
      my ($targetWeb, $targetTopic) = 
        Foswiki::Func::normalizeWebTopicName($this->{web}, $form->fastget('Target'));

      $db = Foswiki::Plugins::DBCachePlugin::Core::getDB($targetWeb);
      $formDef = $db->fastget($targetTopic);
      next unless $formDef;# never reach
    }

    my $text = $formDef->fastget('text');
    my $inBlock = 0;
    $text =~ s/\r//g;
    $text =~ s/\\\n//g; # remove trailing '\' and join continuation lines
    # | *Name:* | *Type:* | *Size:* | *Value:*  | *Description:* | *Attributes:* |
    # Description and attributes are optional
    foreach my $line ( split( /\n/, $text ) ) {
      if ($line =~ /^\s*\|.*Name[^|]*\|.*Type[^|]*\|.*Size[^|]*\|/) {
        $inBlock = 1;
        next;
      }
      if ($inBlock && $line =~ s/^\s*\|\s*//) {
        $line =~ s/\\\|/\007/g; # protect \| from split
        my ($title, $type, $size, $vals) =
          map { s/\007/|/g; $_ } split( /\s*\|\s*/, $line );
        $type ||= '';
        $type = lc $type;
        $type =~ s/^\s*//go;
        $type =~ s/\s*$//go;
        next if !$title or $type ne 'cat';
        $title =~ s/<nop>//go;
        push @$catFields, $title;
      } else {
        $inBlock = 0;
      }
    }

    # cache
    #writeDebug("setting cache for '$topicType' to ".join(',',@$catFields));
    $this->{_catFields}{$topicType} = $catFields;
    foreach my $cat (@$catFields) {
      $allCatFields{$cat} = 1;
    }
  }
  my @allCatFields = sort keys %allCatFields;

  #writeDebug("... result=".join(",",@allCatFields));

  return \@allCatFields;
}

###############################################################################
sub getCategories {
  my $this = shift;

  unless (defined($this->{_categories})) {
    $this->init();
    die "init returned no categories" unless defined $this->{_categories};
  }
  return values %{$this->{_categories}}
}

###############################################################################
sub getCategoryNames {
  my $this = shift;

  unless (defined($this->{_categories})) {
    $this->init();
    die "init returned no categories" unless defined $this->{_categories};
  }
  return keys %{$this->{_categories}}
}


###############################################################################
sub getCategory {
  my ($this, $name) = @_;

  return undef unless $name;

  unless (defined($this->{_categories})) {
    $this->init();
    die "init returned no categories" unless defined $this->{_categories};
  }
  my $cat = $this->{_categories}{$name};

  unless ($cat) {
    # try id
    if ($name =~ /^\d+/) {
      foreach my $cat (values %{$this->{_categories}}) {
        last if $cat->{id} eq $name;
      }
    }
  }

  if ($cat) {
    my $cache = $Foswiki::Plugins::SESSION->{cache} || $Foswiki::Plugins::SESSION->{cache};
    if (defined $cache) {
      #print STDERR "### addDependency($cat->{origWeb}, $cat->{name})\n";
      $cache->addDependency($cat->{origWeb}, $cat->{name})
        if $cat->{origWeb}; # if it has got a physical topic
    }
  }

  return $cat
}

###############################################################################
sub setCategory {
  $_[0]->{_categories}{$_[1]} = $_[2];
}

###############################################################################
sub createCategory {
  return new Foswiki::Plugins::ClassificationPlugin::Category(@_);
}

###############################################################################
# static
sub inlineError {
  return '<span class="foswikiAlert">' . $_[0] . '</span>' ;
}

###############################################################################
sub traverse {
  my ($this, $params) = @_;

  writeDebug("called traverse for hierarchy in '$this->{web}'");

  my $top = $params->{top} || 'TopCategory';
  my $nullFormat = $params->{nullformat} || '';

  my @result;
  my $nrCalls = 0;
  my $seen = {};

  my @cats = 
    sort {
      $a->{order} <=> $b->{order} ||
      $a->{title} cmp $b->{title}
    } map {
      $this->getCategory($_)
    } split(/\s*,\s*/,$top);


  my $nrSiblings = scalar(@cats);
  foreach my $cat (@cats) {
    if ($cat) {
      my $catResult =  $cat->traverse($params, \$nrCalls, 1, $nrSiblings, $seen);
      push @result, $catResult if $catResult;
    }
  }
  return $nullFormat unless @result;

  my $result = '';
  my $separator = $params->{separator} || '';
  my $header = $params->{header} || '';
  my $footer = $params->{footer} || '';

  $separator = Foswiki::Plugins::ClassificationPlugin::Core::expandVariables($separator);
  $result = join($separator, @result);

  $header = Foswiki::Plugins::ClassificationPlugin::Core::expandVariables($header,
    depth=>0,
    indent=>'',
  );
  $footer = Foswiki::Plugins::ClassificationPlugin::Core::expandVariables($footer,
    depth=>0,
    indent=>'',
  );

  writeDebug("done traverse");
  return $header.$result.$footer;
}

###############################################################################
# get preferences of a set of categories
sub getPreferences {
  my ($this, @cats) = @_;

  unless ($this->{_prefs}) {
    my $session = $Foswiki::Plugins::SESSION;

    require Foswiki::Prefs;
    my $prefs = new Foswiki::Prefs($session);

    require Foswiki::Prefs::PrefsCache;
    $prefs = new Foswiki::Prefs::PrefsCache($prefs, undef, 'CAT'); 

    foreach my $cat (@cats) {
      $cat =~ s/^\s+//go;
      $cat =~ s/\s+$//go;
      my $catObj = $this->getCategory($cat);
      $prefs = $catObj->getPreferences($prefs);
    }

    $this->{_prefs} = $prefs;
  }

  return $this->{_prefs};
}

###############################################################################
sub checkAccessPermission {
  my ($this, $mode, $user, $topic, $order) = @_;

  # get acl attribute
  my $aclAttribute = $this->{_aclAttribute};

  unless (defined $aclAttribute) {
    $aclAttribute = 
      Foswiki::Func::getPreferencesValue('CLASSIFICATIONPLUGIN_ACLATTRIBUTE', $this->{web}) || 
      'Category';
    $this->{_aclAttribute} = $aclAttribute;
  }

  # get categories and gather access control lists
  my $db = Foswiki::Plugins::DBCachePlugin::Core::getDB($this->{web});
  my $topicObj = $db->fastget($topic);
  return undef unless $topicObj;

  my $form = $topicObj->fastget('form');
  return undef unless $form;

  $form = $topicObj->fastget($form);
  return undef unless $form;

  my $cats = $form->fastget($aclAttribute);
  return undef unless $cats;

  #my $prefs = $this->getPreferences(split(/\s*,\s*/, $cats));

  my $allowed = 1;

  return $allowed;
}

1;
