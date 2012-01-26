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

package Foswiki::Plugins::ClassificationPlugin::Core;

use strict;

use vars qw(
  %hierarchies 
  %loadTimeStamps 
  %modTimeStamps 
  %cachedIndexFields
  $baseWeb $baseTopic 
  $purgeMode
  @changedCats
);

use constant DEBUG => 0; # toggle me
use constant FIXFORMFIELDS => 1; # work around a bug in Foswiki
use constant MEMORYCACHE => 0; # set to 1 for experimental memory cache
use Foswiki::Plugins::DBCachePlugin::Core ();
use Foswiki::Form ();
use Foswiki::OopsException ();
use Error qw( :try );

###############################################################################
sub writeDebug {
  print STDERR '- ClassificationPlugin::Core - '.$_[0]."\n" if DEBUG;
  #Foswiki::Func::writeDebug('- ClassificationPlugin::Core - '.$_[0]) if DEBUG;
}

###############################################################################
sub init {
  ($baseWeb, $baseTopic) = @_;

  $purgeMode = 0;
  @changedCats = ();
  %modTimeStamps = ();
  %cachedIndexFields = ();

  unless (MEMORYCACHE) {
    %hierarchies = ();
    %loadTimeStamps = ();
  }
}

###############################################################################
sub finish {

  #writeDebug("called finish()");
  foreach my $hierarchy (values %hierarchies) {
    next unless defined $hierarchy;
    my $web = $hierarchy->{web};
    $hierarchy->finish();
    undef $modTimeStamps{$web};
    unless (MEMORYCACHE) {
      undef $hierarchies{$web};
      undef $loadTimeStamps{$web};
    }
  }
  #writeDebug("done finish()");
}

###############################################################################
sub OP_subsumes {
  my ($r, $l, $map) = @_;
  my $lval = $l->matches( $map );
  my $rval = $r->matches( $map );
  return 0 unless ( defined $lval  && defined $rval);

  my $web = $Foswiki::Plugins::DBCachePlugin::Core::dbQueryCurrentWeb || $baseWeb;
  my $hierarchy = getHierarchy($web);
  return $hierarchy->subsumes($lval, $rval);
}

###############################################################################
sub OP_isa {
  my ($r, $l, $map) = @_;
  my $lval = $l->matches( $map );
  my $rval = $r->matches( $map );

  return 0 unless ( defined $lval  && defined $rval);

  my $web = $Foswiki::Plugins::DBCachePlugin::Core::dbQueryCurrentWeb || $baseWeb;
  my $hierarchy = getHierarchy($web);
  my $cat = $hierarchy->getCategory($rval);
  return 0 unless $cat;

  return ($cat->contains($lval))?1:0;
}

###############################################################################
sub OP_distance {
  my ($r, $l, $map) = @_;
  my $lval = $l->matches( $map );
  my $rval = $r->matches( $map );

  return 0 unless ( defined $lval  && defined $rval);

  my $web = $Foswiki::Plugins::DBCachePlugin::Core::dbQueryCurrentWeb || $baseWeb;
  my $hierarchy = getHierarchy($web);
  my $dist = $hierarchy->distance($lval, $rval);
  return $dist || 0;
}

###############################################################################
sub handleSIMILARTOPICS {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleSIMILARTOPICS()");
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;
  my $thisWeb = $params->{web} || $baseWeb;
  my $theFormat = $params->{format} || '$topic';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theSep = $params->{separator};
  my $theLimit = $params->{limit};
  my $theSkip = $params->{skip};
  my $theThreshold = $params->{threshold} || 0.3;

  $theThreshold =~ s/[^\d\.]//go;
  $theThreshold = 0.3 unless $theThreshold;
  $theThreshold = $theThreshold/100 if $theThreshold > 1.0;
  $theSep = ', ' unless defined $theSep;
  $theLimit = 10 unless defined $theLimit;

  my $hierarchy = getHierarchy($thisWeb);
  my @similarTopics = $hierarchy->getSimilarTopics($thisTopic, $theThreshold);
  return '' unless @similarTopics;

  my %wmc = ();
  map {$wmc{$_} = $hierarchy->computeSimilarity($thisTopic, $_)} @similarTopics;
  @similarTopics = sort {$wmc{$b} <=> $wmc{$a}} @similarTopics;

  # format result
  my @lines;
  my $index = 0;
  foreach my $topic (@similarTopics) {
    $index++;
    next if $theSkip && $index <= $theSkip;
    last if $theLimit && $index > $theLimit;
    push @lines, expandVariables($theFormat,
      'topic'=>$topic,
      'web'=>$thisWeb,
      'index'=>$index,
      'similarity'=> int($wmc{$topic}*1000)/10,
    );
  }

  return '' unless @lines;
  $theHeader = expandVariables($theHeader, count=>$index);
  $theFooter = expandVariables($theFooter, count=>$index);
  $theSep = expandVariables($theSep);

  return $theHeader.join($theSep, @lines).$theFooter;
}

###############################################################################
sub handleHIERARCHY {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleHIERARCHY(".$params->stringify().")");

  my $thisWeb = $params->{_DEFAULT} || $params->{web} || $baseWeb;
  $thisWeb =~ s/\./\//go;

  my $hierarchy = getHierarchy($thisWeb);
  return $hierarchy->traverse($params);
}

###############################################################################
sub handleISA {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleISA()");
  my $thisWeb = $params->{web} || $baseWeb;
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;
  my $theCategory = $params->{cat} || 'TopCategory';

  #writeDebug("topic=$thisTopic, theCategory=$theCategory");

  return 1 if $theCategory =~ /^(Top|TopCategory)$/oi;
  return 0 if $theCategory =~ /^(Bottom|BottomCategory)$/oi;
  return 0 unless $theCategory;

  ($thisWeb, $thisTopic) =
    Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  my %lookingForCategory = map {$_=>1} split(/\s*,\s*/,$theCategory);
  my $hierarchy = getHierarchy($thisWeb);

  #writeDebug("hierarchy=$hierarchy");

  foreach my $catName (keys %lookingForCategory) {
    #writeDebug("testing $catName");
    my $cat = $hierarchy->getCategory($catName);
    next unless $cat;
    return 1 if $cat->contains($thisTopic);
  }
  #writeDebug("not found");

  return 0;
}

###############################################################################
sub handleSUBSUMES {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $thisWeb = $params->{web} || $baseWeb;
  my $theCat1 = $params->{_DEFAULT} || $baseTopic;
  my $theCat2 = $params->{cat} || '';

  #writeDebug("called handleSUBSUMES($theCat1, $theCat2)");

  return 0 unless $theCat2;

  my $hierarchy = getHierarchy($thisWeb);
  my $cat1 = $hierarchy->getCategory($theCat1);
  return 0 unless $cat1;

  my $result = 0;
  foreach my $catName (split(/\s*,\s*/,$theCat2)) {
    $catName =~ s/^\s+//g;
    $catName =~ s/\s+$//g;
    next unless $catName;
    my $cat2 = $hierarchy->getCategory($catName);
    next unless $cat2;
    $result = $cat1->subsumes($cat2) || 0;
    last if $result;
  }

  #writeDebug("result=$result");

  return $result;
}

###############################################################################
sub handleDISTANCE {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $thisWeb = $params->{web} || $baseWeb;
  my $theFrom = $params->{_DEFAULT} || $params->{from} || $baseTopic;
  my $theTo = $params->{to} || 'TopCategory';
  my $theAbs = $params->{abs} || 'off';
  my $theFormat = $params->{format} || '$dist';
  my $theUndef = $params->{undef} || '';

  #writeDebug("called handleDISTANCE($theFrom, $theTo)");

  my $hierarchy = getHierarchy($thisWeb);
  my $distance = $hierarchy->distance($theFrom, $theTo);

  return $theUndef unless defined $distance;

  $distance = abs($distance) if $theAbs eq 'on';

  #writeDebug("distance=$distance");

  my $result = $theFormat;
  $result =~ s/\$dist/$distance/g;

  return $result;
}

###############################################################################
sub handleCATINFO {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleCATINFO(".$params->stringify().")");
  my $theCat = $params->{cat};
  my $theFormat = $params->{format} || '$link';
  my $theSep = $params->{separator};
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $thisWeb = $params->{web} || $baseWeb;
  my $thisTopic = $params->{_DEFAULT} || $params->{topic};
  my $theSubsumes = $params->{subsumes} || '';
  my $theParentSubsumes = $params->{parentsubsumes} || '';
  my $theSortChildren = $params->{sortchildren} || 'off';
  my $theMaxChildren = $params->{maxchildren} || 0;
  my $theHideNull = $params->{hidenull} || 'off';
  my $theNull = $params->{null} || '';
  my $theExclude = $params->{exclude} || '';
  my $theInclude = $params->{include} || '';
  my $theTruncate = $params->{truncate} || '';
  my $theMatchAttr = $params->{matchattr} || 'name';
  my $theMatchCase = $params->{matchcase} || 'on';
  my $theLimit = $params->{limit};
  my $theSkip = $params->{skip};

  $theLimit =~ s/[^\d]//g if defined $theLimit;
  $theSkip =~ s/[^\d]//g if defined $theSkip;

  $theMatchAttr = 'name' unless $theMatchAttr =~ /^(name|title)$/;

  $theSep = ', ' unless defined $theSep;
  $theMaxChildren =~ s/[^\d]//go;
  $theMaxChildren = 0 unless defined $theMaxChildren;

  my $hierarchy;
  my $categories;
  if ($theCat) { # cats mode
    if ($thisWeb eq 'any') {
      $hierarchy = findHierarchy($theCat);
      return '' unless $hierarchy;
      $thisWeb = $hierarchy->{web};
    } else {
      ($thisWeb, $theCat) = 
        Foswiki::Func::normalizeWebTopicName($thisWeb, $theCat);
      $hierarchy = getHierarchy($thisWeb);
    }
    push @$categories, $theCat;
  } elsif ($thisTopic) { # topic mode
    ($thisWeb, $thisTopic) = 
      Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);
    $hierarchy = getHierarchy($thisWeb);
    $categories = $hierarchy->getCategoriesOfTopic($thisTopic) if $hierarchy;
  } else { # find mode
    $hierarchy = getHierarchy($thisWeb);
    @$categories = $hierarchy->getCategoryNames();
  }

  return expandVariables($theNull) unless $hierarchy;
  return expandVariables($theNull)  unless $categories;
  #writeDebug("categories=".join(', ', @$categories));

  my @result;
  my $doneBreadCrumbs = 0;
  my $index = 0;
  $theSubsumes =~ s/^\s+//go;
  $theSubsumes =~ s/\s+$//go;
  $theParentSubsumes =~ s/^\s+//go;
  $theParentSubsumes =~ s/\s+$//go;
  my $subsumesCat = $hierarchy->getCategory($theSubsumes);
  my $parentSubsumesCat = $hierarchy->getCategory($theParentSubsumes);

  foreach my $catName (sort @$categories) {
    next if $catName =~ /BottomCategory|TopCategory/;
    my $category = $hierarchy->getCategory($catName);
    next unless $category;

    if ($theMatchCase eq 'on') {
      next if $theExclude && $category->{$theMatchAttr} =~ /^($theExclude)$/;
      next if $theInclude && $category->{$theMatchAttr} !~ /^($theInclude)$/;
    } else {
      next if $theExclude && $category->{$theMatchAttr} =~ /^($theExclude)$/i;
      next if $theInclude && $category->{$theMatchAttr} !~ /^($theInclude)$/i;
    }

    #writeDebug("found $catName");

    # skip catinfo from another branch of the hierarchy
    next if $subsumesCat && !$hierarchy->subsumes($subsumesCat, $category);

    $index++;
    next if $theSkip && $index <= $theSkip;

    my $line = $theFormat;

    my $parents = '';
    my @parents;
    if ($line =~ /\$parent/) {
      @parents = sort {uc($a->{title}) cmp uc($b->{title})} $category->getParents($parentSubsumesCat);

    }

    if ($line =~ /\$parents?\b/) {
      my @links = ();
      foreach my $parent (@parents) {
        push @links, $parent->getLink();
      }
      $parents = join($theSep, @links);
    }

    my $parentsName = '';
    if ($line =~ /\$parents?names?/) {
      my @names = ();
      foreach my $parent (@parents) {
        push @names, $parent->{name};
      }
      $parentsName = join($theSep, @names);
    }

    my $parentsTitle = '';
    if ($line =~ /\$parents?title/) {
      my @titles = ();
      foreach my $parent (@parents) {
        push @titles, $parent->{title};
      }
      $parentsTitle = join($theSep, @titles);
    }

    my $parentLinks = '';
    if ($line =~ /\$parents?links?/) {
      my @links = ();
      foreach my $parent (@parents) {
        push @links, $parent->getLink();
      }
      $parentLinks = join($theSep, @links);
    }

    my $parentUrls = '';
    if ($line =~ /\$parents?urls?/) {
      my @urls = ();
      foreach my $parent (@parents) {
        push @urls, $parent->getUrl();
      }
      $parentUrls = join($theSep, @urls);
    }

    my $breadCrumbs = '';
    my $breadCrumbNames = '';
    if ($line =~ /\$(breadcrumb(name)?)s?/ && !$doneBreadCrumbs) {
      my @breadCrumbs = ();
      my @breadCrumbNames = ();
      my %seen = ();
      my $parent = $category;
      unless ($theCat) {
        if (Foswiki::Func::topicExists($thisWeb, $thisTopic)) {
          push @breadCrumbs, "[[$thisWeb.$thisTopic]]";
          push @breadCrumbNames, $thisTopic;
          $seen{$thisTopic} = 1;
        }
      }
      while ($parent) {
        last if $seen{$parent->{name}};
        $seen{$parent->{name}} = 1;
        next if $theExclude && $parent->{name} =~ /^($theExclude)$/;
        push @breadCrumbs, $parent->getLink();
        push @breadCrumbNames, $parent->{name};
        my @parents = $parent->getParents();
        last unless @parents;
        $parent = shift @parents;
        last if $parent eq $parent->{hierarchy}{_top};
      }
      $breadCrumbs = join($theSep, reverse @breadCrumbs);
      $breadCrumbNames = join($theSep, reverse @breadCrumbNames);
      $doneBreadCrumbs = 1;
    }

    my @children;
    my $moreChildren = '';
    if ($line =~ /\$children/) {
      @children = sort {uc($a->{title}) cmp uc($b->{title})} $category->getChildren();
      @children = grep {$_->{name} ne 'BottomCategory'} @children;

      if ($theHideNull eq 'on') {
        @children = grep {$_->countLeafs() > 0} 
          @children;
      }

      if ($theSortChildren eq 'on') {
        @children = 
          sort {$b->countLeafs() <=> $a->countLeafs() || 
                $a->{title} cmp $b->{title}} 
            @children;
      }

      if ($theMaxChildren && $theMaxChildren < @children) {
        if (splice(@children, $theMaxChildren)) {
          $moreChildren = $params->{morechildren} || '';
        }
      }
    }

    my $children = '';
    if ($line =~ /\$children?\b/) {
      my @links = ();
      foreach my $child (@children) {
        push @links, $child->getLink();
      }
      $children = join($theSep, @links);
    }

    my $childrenName = '';
    if ($line =~ /\$children?names?/) {
      my @names = ();
      foreach my $child (@children) {
        push @names, $child->{name};
      }
      $childrenName = join($theSep, @names);
    }

    my $childrenTitle = '';
    if ($line =~ /\$children?title/) {
      my @titles = ();
      foreach my $child (@children) {
        push @titles, $child->{title};
      }
      $childrenTitle = join($theSep, @titles);
    }

    my $childrenLinks = '';
    if ($line =~ /\$children?links?/) {
      my @links = ();
      foreach my $child (@children) {
        push @links, $child->getLink();
      }
      $childrenLinks = join($theSep, @links);
    }

    my $childrenUrls = '';
    if ($line =~ /\$children?urls?/) {
      my @urls = ();
      foreach my $child (@children) {
        push @urls, $child->getUrl();
      }
      $childrenUrls = join($theSep, @urls);
    }

    my $tags = '';
    if ($line =~ /\$tags/) {
      $tags = join($theSep, sort $category->getTagsOfTopics());
    }


    my $isCyclic = 0;
    $isCyclic = $category->isCyclic() if $theFormat =~ /\$cyclic/;

    my $countLeafs = '';
    $countLeafs = $category->countLeafs() if $theFormat=~ /\$leafs/;

    my $nrTopics = '';
    $nrTopics = $category->countTopics() if $theFormat=~ /\$count/;

    my $title = $category->{title} || $catName;
    my $link = $category->getLink();
    my $url = $category->getUrl();
    my $summary = $category->{summary} || '';

    my $iconUrl = $category->getIconUrl();

    my $truncTitle = $title;
    $truncTitle =~ s/$theTruncate// if $theTruncate;

    $line =~ s/\$more/$moreChildren/g;
    $line =~ s/\$index/$index/g;
    $line =~ s/\$link/$link/g;
    $line =~ s/\$url/$url/g;
    $line =~ s/\$web/$thisWeb/g;
    $line =~ s/\$origweb/$category->{origWeb}/g;
    $line =~ s/\$order/$category->{order}/g;
    $line =~ s/\$(name|topic)/$catName/g;
    $line =~ s/\$title/$title/g;
    $line =~ s/\$trunctitle/$truncTitle/g;
    $line =~ s/\$summary/$summary/g;
    $line =~ s/\$parents?name/$parentsName/g;
    $line =~ s/\$parents?title/$parentsTitle/g;
    $line =~ s/\$parents?links?/$parentLinks/g;
    $line =~ s/\$parents?urls?/$parentUrls/g;
    $line =~ s/\$parents?/$parents/g;
    $line =~ s/\$cyclic/$isCyclic/g;
    $line =~ s/\$leafs/$countLeafs/g;
    $line =~ s/\$count/$nrTopics/g;
    $line =~ s/\$breadcrumbnames?/$breadCrumbNames/g;
    $line =~ s/\$breadcrumbs?/$breadCrumbs/g;
    $line =~ s/\$children?name/$childrenName/g;
    $line =~ s/\$children?title/$childrenTitle/g;
    $line =~ s/\$children?links?/$childrenLinks/g;
    $line =~ s/\$children?urls?/$childrenUrls/g;
    $line =~ s/\$children?/$children/g;
    $line =~ s/\$icon/$iconUrl/g;
    $line =~ s/\$tags/$tags/g;
    $line =~ s/,/&#44;/g; # hack around MAKETEXT where args are comma separated accidentally
    push @result, $line if $line;
    last if $theLimit && $index >= $theLimit;
  }
  return expandVariables($theNull) unless @result;
  my $result = $theHeader.join($theSep, @result).$theFooter;
  $result = expandVariables($result, 'count'=>scalar(@$categories));

  #writeDebug("result=$result");
  return $result;
}

###############################################################################
sub handleTAGINFO {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleTAGINFO(".$params->stringify().")");
  my $theCat = $params->{cat};
  my $theFormat = $params->{format} || '$link';
  my $theSep = $params->{separator};
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $thisWeb = $params->{web} || $baseWeb;
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;
  my $theExclude = $params->{exclude} || '';
  my $theInclude = $params->{include} || '';
  my $theLimit = $params->{limit};
  my $theSkip = $params->{skip};

  $theLimit =~ s/[^\d]//g if defined $theLimit;
  $theSkip =~ s/[^\d]//g if defined $theSkip;

  $theSep = ', ' unless defined $theSep;

  ($thisWeb, $thisTopic) = 
    Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  # get tags
  my $db = Foswiki::Plugins::DBCachePlugin::Core::getDB($thisWeb);
  return '' unless $db;
  my $topicObj = $db->fastget($thisTopic);
  return '' unless $topicObj;
  my $form = $topicObj->fastget('form');
  return '' unless $form;
  my $formObj = $topicObj->fastget($form);
  return '' unless $formObj;
  my $tags = $formObj->fastget('Tag');
  return '' unless $tags;
  my @tags = split(/\s*,\s*/, $tags);

  my @result;
  my $context = Foswiki::Func::getContext();
  my $index = 0;
  foreach my $tag (sort @tags) {
    $tag =~ s/^\s+//go;
    $tag =~ s/\s+$//go;
    next if $theExclude && $tag =~ /^($theExclude)$/;
    next if $theInclude && $tag !~ /^($theInclude)$/;
    $index++;
    next if $theSkip && $index <= $theSkip;
    my $line = $theFormat;
    my $url;
    if ($context->{SolrPluginEnabled}) {
      $url = Foswiki::Func::getScriptUrl($thisWeb, "WebSearch", "view", 
        filter=>"tag:\"$tag\"",
        origtopic=>$baseWeb.".".$baseTopic,
      );
    } else {
      $url = Foswiki::Func::getScriptUrl($thisWeb, "WebTagCloud", "view", tag=>$tag);
    }
    my $class = $tag;
    $class =~ s/["' ]/_/g;
    $class = "tag_".$class;
    my $link = "<a href='$url' rel='tag' class='\$class'><noautolink>$tag</noautolink></a>";
    $line =~ s/\$index/$index/g;
    $line =~ s/\$url/$url/g;
    $line =~ s/\$link/$link/g;
    $line =~ s/\$class/$class/g;
    $line =~ s/\$name/$tag/g;
    push @result, $line;
    last if $theLimit && $index >= $theLimit;
  }

  my $count = scalar(@tags);
  my $result = $theHeader.join($theSep, @result).$theFooter;
  $result = expandVariables($result, 
    'web'=>$thisWeb,
    'count'=>$count,
    'index'=>$index,
  );

  #writeDebug("result='$result'");
  return $result;
}

###############################################################################
# reparent based on the category we are in
# takes the first category in alphabetic order
sub beforeSaveHandler {
  my ($text, $topic, $web, $meta) = @_;

  #writeDebug("beforeSaveHandler($web, $topic)");

  my $doAutoReparent = Foswiki::Func::getPreferencesFlag('CLASSIFICATIONPLUGIN_AUTOREPARENT', $web);

  my $session = $Foswiki::Plugins::SESSION;
  unless ($meta) {
    $meta = new Foswiki::Meta($session, $web, $topic, $text);
    #writeDebug("creating a new meta object");
  }

  my $formName = $meta->getFormName();
  my ($theFormWeb, $theForm) = Foswiki::Func::normalizeWebTopicName($web, $formName);
  my $formDef;
  my %isCatField = ();
  my %isTagField = ();
  #writeDebug("form definition at $theFormWeb, $theForm");
  if (Foswiki::Func::topicExists($theFormWeb, $theForm)) {
    try {
      $formDef = new Foswiki::Form($session, $theFormWeb, $theForm);
    } catch Foswiki::OopsException with {
      my $e = shift;
      print STDERR "ERROR: can't read form definition $theForm in ClassificationPlugin::Core::beforeSaveHandler\n";
    };
    if ($formDef) {
      foreach my $fieldDef (@{$formDef->getFields()}) {
        writeDebug("formDef field $fieldDef->{name} type=$fieldDef->{type}");
        $isCatField{$fieldDef->{name}} = 1 if $fieldDef->{type} eq 'cat';
        $isTagField{$fieldDef->{name}} = 1 if $fieldDef->{type} eq 'tag';
      }
    }
  }

  # There's a serious bug in all Foswiki's that it rewrites all of the
  # topic text - including the meta data - if a topic gets moved to
  # a different web. In an attempt to keep linking WikiWords intact,
  # it rewrites the DataForm, i.e. the names and titles of the
  # formfields. This however breaks mostly every code that relies
  # on the formfields to be named like they where in the beginning.
  # AFAICS, there's no case where renaming the formfield names is
  # desired.
  #
  # What we do here is to loop pre-process the topic being saved right here
  # and remove any leading webname from the those formfields
  # playing a central role in this plugin, TopicType and Category.
  # 
  if (FIXFORMFIELDS) {
    #if (DEBUG) {
    #  use Data::Dumper;
    #  $Data::Dumper::Maxdepth = 3;
    #  writeDebug("BEFORE FIXFORMFIELDS");
    #  writeDebug(Dumper($meta));
    #}

    foreach my $field ($meta->find('FIELD')) {
      if ($field->{name} =~ /TopicType|Category/) {
        $field->{name} =~ s/^.*[\.\/](.*?)$/$1/;
        $field->{title} =~ s/^.*[\.\/](.*?)$/$1/;
      }
      if ($isCatField{$field->{name}}) {
        writeDebug("before, value=$field->{value}");
        $field->{value} =~ s/^top=.*$//; # clean up top= in value definition
        my $item;
        $field->{value} = join(', ', 
            map { 
              $item = $_;
              $item =~ s/^.*[\.\/](.*?)$/$1/; 
              $_ = $item;
            }
            split(/\s*,\s*/, $field->{value})
        ); # remove accidental web part from categories
        writeDebug("after, value=$field->{value}");
      }
    }

    #if (DEBUG) {
    #  use Data::Dumper;
    #  $Data::Dumper::Maxdepth = 3;
    #  writeDebug("AFTER FIXFORMFIELDS");
    #  writeDebug(Dumper($meta));
    #}
  }

  my $trashWeb = $Foswiki::cfg{TrashWebName};
  if ($web eq $trashWeb) {
    writeDebug("detected a move from $baseWeb to trash");
    $web = $baseWeb;# operations are on the baseWeb
  }

  # get topic type info
  my $topicType = $meta->get('FIELD', 'TopicType');
  return unless $topicType;
  $topicType = $topicType->{value};

  # fix topic type depending on the form
  writeDebug("old TopicType=$topicType");
  my @topicType = split(/\s*,\s*/, $topicType);
  my $index = scalar(@topicType)+3;
  my %newTopicType = map {$_ =~ s/^.*\.//; $_ => $index--} @topicType;

  if ($formName =~ /^Applications[\.\/]ClassificationApp[\.\/]Category$/) {
    $newTopicType{Category} = 2;
    $newTopicType{CategorizedTopic} = 1;
    $newTopicType{WikiTopic} = 0;
  } 
  elsif ($formName =~ /^Applications[\.\/]ClassificationApp[\.\/]CategorizedTopic$/) {
    $newTopicType{CategorizedTopic} = 1;
    $newTopicType{WikiTopic} = 0;
  }
  elsif ($formName =~ /^Applications[\.\/]ClassificationApp[\.\/]TaggedTopic$/) {
    $newTopicType{TaggedTopic} = 1;
    $newTopicType{WikiTopic} = 0;
  }
  elsif ($formName =~ /^Applications[\.\/]ClassificationApp[\.\/]ClassifiedTopic$/) {
    $newTopicType{ClassifiedTopic} = 3;
    $newTopicType{CategorizedTopic} = 2;
    $newTopicType{TaggedTopic} = 1;
    $newTopicType{WikiTopic} = 0;
  }
  if ($formName !~ /^Applications[\.\/]TopicStub$/) {
    delete $newTopicType{TopicStub};
  }

  if (keys %newTopicType) {
    my @newTopicType;
    foreach my $item (sort {$newTopicType{$b} <=> $newTopicType{$a}} keys %newTopicType) {
      push @newTopicType, $item;
    }
    my $newTopicType = join(', ', @newTopicType);
    writeDebug("new TopicType=$newTopicType");
    $meta->putKeyed('FIELD', {name =>'TopicType', title=>'TopicType', value=>$newTopicType});
  }

  # get categories of this topic,
  # must get it from current meta data

  return unless $topicType =~ /ClassifiedTopic|CategorizedTopic|Category|TaggedTopic/;

  my $hierarchy = getHierarchy($web);
  my $catFields = $hierarchy->getCatFields(split(/\s*,\s*/,$topicType));

  # get old categories from store 
  my $db = Foswiki::Plugins::DBCachePlugin::Core::getDB($web);
  my $topicObj = $db->fastget($topic);
  my %oldCats;
  if (!$topicObj) {
    $purgeMode = 2; # new topic
  } else {
    my $form = $topicObj->fastget("form");

    if (!$form) {
      $purgeMode = 2; # new form
    } else {
      $form = $topicObj->fastget($form);
      
      foreach my $field (@$catFields) {
        my $cats = $form->fastget($field);
        next unless $cats;
        foreach my $cat (split(/\s*,\s*/,$cats)) {
          $cat =~ s/^\s+//go;
          $cat =~ s/\s+$//go;
          $oldCats{$cat} = 1;
        }
      }
    }
  }

  # get new categories from meta data
  my %newCats;
  foreach my $field (@$catFields) {
    my $cats = $meta->get('FIELD',$field);
    next unless $cats;

    my $title = $cats->{title};
    $cats = $cats->{value};
    next unless $cats;

    # assigning TopCategory only empties the cat field
    if ($cats eq 'TopCategory') {
      #writeDebug("found TopCategory assignment");
      $meta->putKeyed('FIELD', {name =>$field, title=>$title, value=>''});
      next;
    }

    foreach my $cat (split(/\s*,\s*/,$cats)) {
      $cat =~ s/^\s+//go;
      $cat =~ s/\s+$//go;
      $newCats{$cat} = 1;
    }
  }

  # set the new parent topic
  if ($doAutoReparent) {
    writeDebug("autoreparenting");
    my $newParentCat;
    foreach my $cat (sort keys %newCats) {
      if ($cat ne 'TopCategory') {
        $newParentCat = $cat;
        last;
      }
    }
    my $homeTopicName = $Foswiki::cfg{HomeTopicName};
    $newParentCat = $homeTopicName unless defined $newParentCat;
    writeDebug("newParentCat=$newParentCat");
    $meta->remove('TOPICPARENT');
    $meta->putKeyed('TOPICPARENT', {name=>$newParentCat});
  } else {
    writeDebug("not autoreparenting");
  }

  # get changed categories
  my %changedCats = ();
  foreach my $cat (keys %oldCats) {
    $changedCats{$cat} = 1 unless $newCats{$cat};
  }
  foreach my $cat (keys %newCats) {
    $changedCats{$cat} = 1 unless $oldCats{$cat};
  }
  @changedCats = keys %changedCats; #remember 

  # add self
  if (@changedCats && !$changedCats{$topic} && $topicType =~ /\bCategory\b/) {
    push @changedCats, $topic;
    #writeDebug("adding self to changedCats");
  }

  # cache invalidation: compute the purgeMode to be executed after save
  $purgeMode = 1 if $topicType =~ /\bTaggedTopic\b/;
  $purgeMode = 2 if $topicType =~ /\bCategorizedTopic\b/;
  $purgeMode = 3 if $topicType =~ /\bClassifiedTopic\b/;
  $purgeMode = 4 if $topicType =~ /\bCategory\b/;

  # try even harder if it missing the CategorizedTopic TopicType but
  # still uses categories
  if ($purgeMode < 2) { 
    my $hierarchy = getHierarchy($web); 
    my $catFields = $hierarchy->getCatFields(split(/\s*,\s*/,$topicType));
    if ($catFields && @$catFields) {
      $purgeMode = ($purgeMode < 1)?2:3;
    }
  }

  #writeDebug("purgeMode=$purgeMode");
  #writeDebug("changedCats=".join(',', @changedCats));
}

###############################################################################
sub afterSaveHandler {
  #my ($text, $topic, $web, $meta) = @_;
  my $topic = $_[1];
  my $web = $_[2];

  #writeDebug("afterSaveHandler($web, $topic)");

  my $trashWeb = $Foswiki::cfg{TrashWebName};
  if ($web eq $trashWeb) {
    #writeDebug("detected a move from $baseWeb to trash");
    $web = $baseWeb;# operations are on the baseWeb
  }
  $web =~ s/\//./go;
 
  if ($purgeMode) {
    #writeDebug("purging hierarchy $web");
    my $hierarchy = getHierarchy($web);

    # delete the cached html page 
    my $cache = $Foswiki::Plugins::SESSION->{cache} || $Foswiki::Plugins::SESSION->{cache};
    if (defined $cache) {
      foreach my $catName (@changedCats) {
        my $cat = $hierarchy->getCategory($catName);
        next unless $cat;
        if ($cat->{origWeb} eq $web) {
          # category is a topic in this web
          $cache->deletePage($web, $catName);
        } else {
          # category is displayed via the Category topic as it is imported
          $cache->deletePage($web, 'Category');
        }
      }
    }
    #writeDebug("purging \@changedCats");

    $hierarchy->purgeCache($purgeMode, \@changedCats);
  }

  finish(); # not called by modifyHeaderHandler
}

###############################################################################
sub getTopicTypes {
  my ($web, $topic) = @_;

  my $db = Foswiki::Plugins::DBCachePlugin::Core::getDB($web);
  return undef unless $db;

  my $topicObj = $db->fastget($topic);
  return undef unless $topicObj;

  my $form = $topicObj->fastget("form");
  return undef unless $form;

  $form = $topicObj->fastget($form);
  return undef unless $form;

  my $topicTypes = $form->fastget('TopicType');
  return undef unless $topicTypes;

  my @topicTypes = split(/\s*,\s*/, $topicTypes);

  return \@topicTypes;
}

################################################################################
sub getCacheFile {
  my $web = shift;

  $web =~ s/^\s+//go;
  $web =~ s/\s+$//go;
  $web =~ s/[\/\.]/_/go;

  return Foswiki::Func::getWorkArea("ClassificationPlugin").'/'.$web.'.hierarchy';
}

###############################################################################
sub getModificationTime {
  my $web = shift;

  unless ($modTimeStamps{$web}) {
    my $cacheFile = getCacheFile($web);
    my @stat = stat($cacheFile);
    $modTimeStamps{$web} = ($stat[9] || $stat[10] || 1);
  }

  return $modTimeStamps{$web};
}

###############################################################################
# returns the hierarchy object for a given web; construct a new one if
# not already done
sub getHierarchy {
  my $web = shift;

  $web =~ s/\//\./go;
  if (!$loadTimeStamps{$web} || $loadTimeStamps{$web} < getModificationTime($web)) {
    #writeDebug("constructing hierarchy for $web");
    require Foswiki::Plugins::ClassificationPlugin::Hierarchy;
    $hierarchies{$web} = new Foswiki::Plugins::ClassificationPlugin::Hierarchy($web);
    $loadTimeStamps{$web} = time();
    #writeDebug("DONE constructing hierarchy for $web");
  }

  return $hierarchies{$web};
}

###############################################################################
# get the hierarchy that implements the given category; this traverses all
# webs and loads their hierarchy to see if it exists
sub findHierarchy {
  my $catName = shift;

  # try baseweb first
  my $hierarchy = getHierarchy($baseWeb);
  my $cat = $hierarchy->getCategory($catName);

  unless ($cat) {
    foreach my $web (Foswiki::Func::getListOfWebs('user')) {
      $hierarchy = getHierarchy($web);
      $cat = $hierarchy->getCategory($catName);
      last if $cat;
    }
  }

  return $hierarchy;
}

###############################################################################
sub expandVariables {
  my ($theFormat, %params) = @_;

  return '' unless $theFormat;

  #writeDebug("called expandVariables($theFormat)");

  foreach my $key (keys %params) {
    #die "params{$key} undefined" unless defined($params{$key});
    $theFormat =~ s/\$$key\b/$params{$key}/g;
  }
  $theFormat =~ s/\$percnt/\%/go;
  $theFormat =~ s/\$nop//go;
  $theFormat =~ s/\$n/\n/go;
  $theFormat =~ s/\$t\b/\t/go;
  $theFormat =~ s/\$dollar/\$/go;

  #writeDebug("result='$theFormat'");

  return $theFormat;
}

###############################################################################
sub renameTag {
  my ($from, $to, $web, $topics) = @_;

  my $hierarchy = Foswiki::Plugins::ClassificationPlugin::getHierarchy($web);
  my $db = Foswiki::Plugins::DBCachePlugin::Core::getDB($web);

  $topics = [$db->getKeys()] unless $topics;
  my @from = ();

  if (ref($from)) {
    @from = @$from;
  } else {
    @from = split(/\s*,s\*/, $from);
  }

  my $user = Foswiki::Func::getWikiName();
  my $count = 0;
  my $gotAccess;
  foreach my $topic (@$topics) {

    my $tags = $hierarchy->getTagsOfTopic($topic);
    next unless $tags;
    my %tags = map {$_ => 1} @$tags;
    my $found = 0;

    foreach my $from (@from) {
      if ($tags{$from}) {
        $gotAccess = Foswiki::Func::checkAccessPermission('change', $user, undef, $web, $topic)
          unless defined $gotAccess;
        next unless $gotAccess;
        delete $tags{$from};
        $tags{$to} = 1 if $to;
        $found = 1;
      }
    }
    if ($found) {
      my $newTags = join(', ', keys %tags);

      if (DEBUG) {
        print STDERR "\n$topic: old=".join(", ", sort @$tags)."\n";
        print STDERR "$topic: new=$newTags\n";
      } 

      my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);
      $meta->putKeyed( 'FIELD', { name => 'Tag', title => 'Tag', value =>$newTags});
      Foswiki::Func::saveTopic($web, $topic, $meta, $text);
      #print STDERR "saved $web.$topic\n";

      $count++;
    }
  }

  return $count;
}

###############################################################################
sub getIndexFields {
  my ($web, $topic, $meta) = @_;

  my $indexFields = $cachedIndexFields{"$web.$topic"};
  return $indexFields if $indexFields;

  @$indexFields = ();

  ($meta) = Foswiki::Func::readTopic($web, $topic) unless $meta;

  my $session = $Foswiki::Plugins::SESSION;
  my $formName = $meta->getFormName();
  my $formDef;

  try {
    $formDef = new Foswiki::Form($session, $web, $formName) if $formName;
  } catch Foswiki::OopsException with {
    my $e = shift;
    print STDERR "ERROR: can't read form definition $formName in ClassificationPlugin::Core::getIndexFields\n";
  };

  if ($formDef) {

    my %seenFields = ();
    my %categories;
    my %tags;
    my $hierarchy = getHierarchy($web);
    foreach my $fieldDef (@{$formDef->getFields()}) {
      my $name = $fieldDef->{name};
      my $type = $fieldDef->{type};
      my $field = $meta->get('FIELD', $name);
      my $value = $field->{value} || '';

      next if $seenFields{$name};
      $seenFields{$name} = 1;

       # categories
      if ($type eq 'cat') {
        my %thisCategories = ();
        foreach my $item (split(/\s*,\s*/, $value)) {
          $thisCategories{$item} = 1; # this cat field
          $categories{$item} = 1; # all cat fields
        }

	# first, add categories as is
	foreach my $category (keys %thisCategories) {
	  push @$indexFields, ['field_'.$name.'_flat_lst' => $category];
	}

        # then, gather all parent categories for this cat field
        if ($hierarchy) {
          foreach my $category (keys %thisCategories) {
            my $cat = $hierarchy->getCategory($category);
            next unless $cat;
            foreach my $parent ($cat->getAllParents()) {
              $thisCategories{$parent} = 1;
            }
          }
        }

        # create a field specific category facet
	my $fieldName = 'field_'.$name.'_lst'; # Note, there's a field_..._s as well
	foreach my $category (keys %thisCategories) {
	  push @$indexFields, [$fieldName => $category];
	}
      }

      # tags
      elsif ($type eq 'tag') {
        foreach my $item (split(/\s*,\s*/, $value)) {
          $tags{$item} = 1; 
        }
      }
    }

    # gather all parents of all cat fields
    if ($hierarchy) {
      foreach my $category (keys %categories) {
	my $cat = $hierarchy->getCategory($category);
	next unless $cat;
	foreach my $parent ($cat->getAllParents()) {
	  $categories{$parent} = 1;
	}
      }
    }

    # create common fields
    foreach my $category (keys %categories) {
      push @$indexFields, ['category' => $category];
    }
    foreach my $tag (keys %tags) {
      push @$indexFields, ['tag' => $tag];
    }
  }

  $cachedIndexFields{"$web.$topic"} = $indexFields;
  return $indexFields;
}

###############################################################################
sub indexAttachmentHandler {
  my ($indexer, $doc, $web, $topic, $attachment) = @_;

  my $indexFields = getIndexFields($web, $topic);
  $doc->add_fields(@$indexFields) if $indexFields;
}

###############################################################################
sub indexTopicHandler {
  my ($indexer, $doc, $web, $topic, $meta, $text) = @_;

  my $indexFields = getIndexFields($web, $topic, $meta);
  $doc->add_fields(@$indexFields) if $indexFields;
}

1;

