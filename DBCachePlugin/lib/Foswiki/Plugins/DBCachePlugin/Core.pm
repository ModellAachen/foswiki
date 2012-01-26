# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2012 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::DBCachePlugin::Core;

use strict;
use warnings;

use POSIX ();

our %webDB;
our %webDBIsModified;
our $wikiWordRegex;
our $webNameRegex;
our $defaultWebNameRegex;
our $linkProtocolPattern;
our $tagNameRegex;
our $baseWeb;
our $baseTopic;
our $dbQueryCurrentWeb;
our $doRefresh;
our $TranslationToken = "\0";
our $TranslationToken2 = "\1"; 

use constant DEBUG => 0; # toggle me

use Foswiki::Contrib::DBCacheContrib ();
use Foswiki::Contrib::DBCacheContrib::Search ();
use Foswiki::Plugins::DBCachePlugin::WebDB ();
use Foswiki::Sandbox ();
use Foswiki::Time ();
use Cwd;

###############################################################################
sub writeDebug {
  #Foswiki::Func::writeDebug('- DBCachePlugin - '.$_[0]) if DEBUG;
  print STDERR "- DBCachePlugin::Core - $_[0]\n" if DEBUG;
}

###############################################################################
sub init {
  ($baseWeb, $baseTopic) = @_;

  %webDBIsModified = ();

  my $query = Foswiki::Func::getCgiQuery();
  my $memoryCache = $Foswiki::cfg{DBCachePlugin}{MemoryCache};

  # deprecated
  $memoryCache = $Foswiki::cfg{DBCache}{MemoryCache} unless defined $memoryCache;
  $memoryCache = 1 unless defined $memoryCache;

  if ($memoryCache) {
    $doRefresh = $query->param('refresh') || '';
    if ($doRefresh eq 'this') {
      $doRefresh = 1;
    }
    elsif ($doRefresh =~ /^(on|dbcache)$/) {
      $doRefresh = 2;
      %webDB = ();
      writeDebug("found refresh in urlparam");
    } else {
      $doRefresh = 0;
    }
  } else {
    %webDB = ();
  }

  $wikiWordRegex = Foswiki::Func::getRegularExpression('wikiWordRegex');
  $webNameRegex  = Foswiki::Func::getRegularExpression('webNameRegex');
  $defaultWebNameRegex = Foswiki::Func::getRegularExpression('defaultWebNameRegex');
  $linkProtocolPattern = Foswiki::Func::getRegularExpression('linkProtocolPattern');
  $tagNameRegex = Foswiki::Func::getRegularExpression('tagNameRegex');
}

###############################################################################
sub renderWikiWordHandler {
  my ($theLinkText, $hasExplicitLinkLabel, $theWeb, $theTopic) = @_;

  return if $hasExplicitLinkLabel;

  #writeDebug("called renderWikiWordHandler($theLinkText, ".($hasExplicitLinkLabel?'1':'0').", $theWeb, $theTopic)");

  return if !defined($theWeb) and !defined($theTopic);

  # normalize web name
  $theWeb =~ s/\//./g;

  $theWeb = Foswiki::Sandbox::untaintUnchecked($theWeb);    # woops why is theWeb tainted
  my $topicTitle = getTopicTitle($theWeb, $theTopic);

  #writeDebug("topicTitle=$topicTitle");

  $theLinkText = $topicTitle if $topicTitle;

  return $theLinkText;
}

###############################################################################
sub afterSaveHandler {
  my ($web, $topic, $newWeb, $newTopic, $attachment, $newAttachment) = @_;

  #writeDebug("called afterSaveHandler($web, $topic, $newWeb, $newTopic, ..., ...)");

  my $doFullUpdate = $Foswiki::cfg{DBCacheContrib}{AlwaysUpdateCache};
  $doFullUpdate = 1 unless defined $doFullUpdate;

  $newWeb ||= $baseWeb;
  $newTopic ||= $baseTopic;

  if ($doFullUpdate) {
    my $db = getDB($newWeb);
    $db->touch();

    # move/rename from one web to the other
    if ($newWeb ne $web) {
      $db = getDB($web); 
      $db->touch();
    }
  } else {
    my $db = getDB($web);
    $db->loadTopic($web, $topic);

    # move/rename 
    if ($newWeb eq $web) {
      if ($topic eq $newTopic) {
        if ($attachment && $attachment ne $newAttachment) {
          $db->loadTopic($web, $topic)
        }
      } else {
        $db->loadTopic($web, $newTopic)
      }
    } else { # crossing webs
      $db = getDB($newWeb); 
      $db->loadTopic($newWeb, $topic);
      if ($topic ne $newTopic) {
        $db->loadTopic($newWeb, $newTopic)
      }
    }
  }
}

###############################################################################
sub loadTopic {
  my ($web, $topic) = @_;

  my $db = getDB($web);
  return $db->loadTopic($web, $topic);
}

###############################################################################
sub handleNeighbours {
  my ($mode, $session, $params, $topic, $web) = @_;

  #writeDebug("called handleNeighbours($web, $topic)");

  my ($theWeb, $theTopic) = Foswiki::Func::normalizeWebTopicName($params->{web} || $baseWeb, $params->{topic} || $baseTopic);

  my $theSearch = $params->{_DEFAULT};
  $theSearch = $params->{search} unless defined $theSearch;

  my $theFormat = $params->{format} || '$web.$topic';
  my $theOrder = $params->{order} || 'created';
  my $theReverse = $params->{reverse} || 'off';

  return inlineError("ERROR: no \"search\" parameter in DBPREV/DBNEXT") unless $theSearch;

  #writeDebug('theFormat='.$theFormat);
  #writeDebug('theSearch='. $theSearch) if $theSearch;

  
  my $db = Foswiki::Plugins::DBCachePlugin::getDB($theWeb);
  return inlineError("ERROR: DBPREV/DBNEXT unknown web $theWeb") unless $db;

  my ($prevTopic, $nextTopic) = $db->getNeighbourTopics($theTopic, $theSearch, $theOrder, $theReverse);

  my $result = $theFormat;

  if ($mode) {
    # DBPREV
    return '' unless $prevTopic;
    $result =~ s/\$topic/$prevTopic/g;
  } else {
    # DBNEXT
    return '' unless $nextTopic;
    $result =~ s/\$topic/$nextTopic/g;
  }

  $result =~ s/\$web/$theWeb/g;
  $result =~ s/\$perce?nt/\%/go;
  $result =~ s/\$nop//g;
  $result =~ s/\$n/\n/go;
  $result =~ s/\$dollar/\$/go;

  return $result;
}

###############################################################################
sub handleTOPICTITLE {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;
  my $thisWeb = $params->{web} || $baseWeb;
  my $theEncoding = $params->{encode} || '';
  my $theDefault = $params->{default};
  my $theHideAutoInc = $params->{hideautoinc} || 'off';

  $thisTopic =~ s/^\s+//go;
  $thisTopic =~ s/\s+$//go;

  ($thisWeb, $thisTopic) =
    Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  my $topicTitle = getTopicTitle($thisWeb, $thisTopic);

  if ($topicTitle eq $thisTopic && defined($theDefault)) {
    $topicTitle = $theDefault;
  }

  return '' if $theHideAutoInc eq 'on' && $topicTitle =~ /X{10}|AUTOINC\d/;

  return urlEncode($topicTitle) if $theEncoding eq 'url';
  return entityEncode($topicTitle) if $theEncoding eq 'entity';

  return $topicTitle;
}

###############################################################################
sub getTopicTitle {
  my ($theWeb, $theTopic) = @_;

  ($theWeb, $theTopic) = Foswiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  my $db = getDB($theWeb);
  return $theTopic unless $db;

  my $topicObj = $db->fastget($theTopic);
  return $theTopic unless $topicObj;

  if ($Foswiki::cfg{SecureTopicTitles}) {
    my $wikiName = Foswiki::Func::getWikiName();
    return $theTopic
      unless Foswiki::Func::checkAccessPermission('VIEW', $wikiName, undef, $theTopic, $theWeb);
  }

  my $topicTitle = $topicObj->fastget('topictitle');
  return $topicTitle if $topicTitle;

  return $theTopic;
}

###############################################################################
sub handleDBQUERY {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleDBQUERY(" . $params->stringify() . ")");

  # params
  my $theSearch = $params->{_DEFAULT} || $params->{search};
  my $thisTopic = $params->{topic} || '';
  my $thisWeb = $params->{web} || $baseWeb;
  my $theTopics = $params->{topics} || '';
  my $theFormat = $params->{format};
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theInclude = $params->{include};
  my $theExclude = $params->{exclude};
  my $theSort = $params->{sort} || $params->{order} || 'name';
  my $theReverse = $params->{reverse} || 'off';
  my $theSep = $params->{separator};
  my $theLimit = $params->{limit} || '';
  my $theSkip = $params->{skip} || 0;
  my $theHideNull = $params->{hidenull} || 'off';
  my $theRemote = $params->remove('remote') || 'off';
  $theRemote = ($theRemote =~ /^(on|force|1|yes)$/)?1:0;
  $theRemote = ($theRemote eq 'on')?1:0;

  $theFormat = '$topic' unless defined $theFormat;
  $theFormat = '' if $theFormat eq 'none';
  $theSep = $params->{sep} unless defined $theSep;
  $theSep = '$n' unless defined $theSep;
  $theSep = '' if $theSep eq 'none';

  # get web and topic(s)
  my @topicNames = ();
  if ($thisTopic) {
    ($thisWeb, $thisTopic) = Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);
    push @topicNames, $thisTopic;
  } else {
    $thisTopic = $baseTopic;
    if ($theTopics) {
      @topicNames = split(/\s*,\s*/, $theTopics);
    }
  }

  # normalize 
  unless ($theSkip =~ /^[\d]+$/) {
    $theSkip = expandVariables($theSkip, $thisWeb, $thisTopic);
    $theSkip = Foswiki::Func::expandCommonVariables($theSkip, $thisTopic, $thisWeb);
  }
  $theSkip =~ s/[^-\d]//go;
  $theSkip = 0 if $theSkip eq '';
  $theSkip = 0 if $theSkip < 0;

  my $theDB = getDB($thisWeb);
  return '' unless $theDB;

  # flag the current web we evaluate this query in, used by web-specific operators
  $dbQueryCurrentWeb = $thisWeb;

  my ($topicNames, $hits, $msg) = $theDB->dbQuery($theSearch, 
    \@topicNames, $theSort, $theReverse, $theInclude, $theExclude);

  return inlineError($msg) if $msg;

  my $count = scalar(@$topicNames);
  return '' if ($count <= $theSkip) && $theHideNull eq 'on';

  unless ($theLimit =~ /^[\d]+$/) {
    $theLimit = expandVariables($theLimit, $thisWeb, $thisTopic);
    $theLimit = Foswiki::Func::expandCommonVariables($theLimit, $thisTopic, $thisWeb);
  }
  $theLimit =~ s/[^\d]//go;
  $theLimit = scalar(@$topicNames) if $theLimit eq '';
  $theLimit += $theSkip;

  # format
  my $text = '';
  if ($theFormat && $theLimit) {
    my $index = 0;
    my $isFirst = 1;
    foreach my $topicName (@$topicNames) {
      #writeDebug("topicName=$topicName");
      $index++;
      next if $index <= $theSkip;
      my $topicObj = $hits->{$topicName};
      my $topicWeb = $topicObj->fastget('web');
      my $format = '';
      $format = $theSep unless $isFirst;
      $isFirst = 0;
      $format .= $theFormat;
      $format =~ s/\$pattern\((.*?)\)/extractPattern($topicObj, $1)/geo;
      $format =~ s/\$formfield\((.*?)\)/
        my $temp = $theDB->getFormField($topicName, $1);
	$temp =~ s#\)#${TranslationToken}#g;
	$temp/geo;
      $format =~ s/\$expand\((.*?)\)/
        my $temp = $1;
        $temp = expandVariables($temp, $topicWeb, $topicName,
          topic=>$topicName, web=>$topicWeb, index=>$index, count=>$count);
        $temp = $theDB->expandPath($topicObj, $temp);
	$temp =~ s#\)#${TranslationToken}#g;
	$temp/geo;
      $format =~ s/\$formatTime\((.*?)(?:,\s*'([^']*?)')?\)/formatTime($theDB->expandPath($topicObj, $1), $2)/geo; # single quoted
      $format = expandVariables($format, $topicWeb, $topicName,
	topic=>$topicName, web=>$topicWeb, index=>$index, count=>$count);
      $format =~ s/${TranslationToken}/)/go;
      $format = Foswiki::Func::expandCommonVariables($format, $topicName, $topicWeb);
      $text .= $format;

      $Foswiki::Plugins::DBCachePlugin::addDependency->($topicWeb, $topicName);

      last if $index == $theLimit;
    }
  }

  $theHeader = expandVariables($theHeader, $thisWeb, $thisTopic, count=>$count, web=>$thisWeb)
    if $theHeader;
  $theFooter = expandVariables($theFooter, $thisWeb, $thisTopic, count=>$count, web=>$thisWeb)
    if defined $theFooter;

  $text = Foswiki::Func::expandCommonVariables($theHeader.$text.$theFooter, $thisTopic, $thisWeb);

  fixInclude($session, $thisWeb, $text) if $theRemote;

  return $text;
}

###############################################################################
# finds the correct topicfunction for this object topic.
# this is constructed by checking for the existance of a topic derived from
# the type information of the objec topic.
sub findTopicMethod {
  my ($session, $theWeb, $theTopic, $theObject) = @_;

  #writeDebug("called findTopicMethod($theWeb, $theTopic, $theObject)");

  return undef unless $theObject;

  my ($thisWeb, $thisObject) = Foswiki::Func::normalizeWebTopicName($theWeb, $theObject);

  #writeDebug("object web=$thisWeb, topic=$thisObject");

  # get form object
  my $baseDB = getDB($thisWeb);
  unless ($baseDB) {
    print STDERR "can't get dbcache for '$thisWeb'\n";
    return undef;
  }

  #writeDebug("1");

  my $topicObj = $baseDB->fastget($thisObject);
  return undef unless $topicObj;

  #writeDebug("2");

  my $form = $topicObj->fastget('form');
  return undef unless $form;

  #writeDebug("3");

  my $formObj = $topicObj->fastget($form);
  return undef unless $formObj;

  #writeDebug("4");

  # get type information on this object
  my $topicTypes = $formObj->fastget('TopicType');
  return undef unless $topicTypes;

  #writeDebug("topicTypes=$topicTypes");

  foreach my $topicType (split(/\s*,\s*/, $topicTypes)) {
    $topicType =~ s/^\s+//o;
    $topicType =~ s/\s+$//o;

    #writeDebug("1");

    # if not found in the current web, try to 
    # find it in the web where this type is implemented
    my $topicTypeObj = $baseDB->fastget($topicType);
    next unless $topicTypeObj;

    #writeDebug("2");

    $form = $topicTypeObj->fastget('form');
    next unless $form;

    #writeDebug("3");

    $formObj = $topicTypeObj->fastget($form);
    next unless $formObj;

    #writeDebug("4");

    my $targetWeb;
    my $target = $formObj->fastget('Target');
    if ($target) {
      $targetWeb = $1 if $target =~ /^(.*)[.\/](.*?)$/;
    } 
    $targetWeb = $thisWeb unless defined $targetWeb;


    #writeDebug("5");

    my $theMethod = $topicType.$theTopic;
    my $targetDB = getDB($targetWeb);
    #writeDebug("checking $targetWeb.$theMethod");
    return ($targetWeb, $theMethod) if $targetDB->fastget($theMethod);

    #writeDebug("6");
  }


  #writeDebug("5");
  return undef;
}

###############################################################################
sub handleDBCALL {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $thisTopic = $params->remove('_DEFAULT');
  return '' unless $thisTopic;

  #writeDebug("called handleDBCALL()");

  # check if this is an object call
  my $theObject;
  if ($thisTopic =~ /^(.*)->(.*)$/) {
    $theObject = $1;
    $thisTopic = $2;
  }

  my $thisWeb = $baseWeb; # Note: default to $baseWeb and _not_ to $theWeb
  ($thisWeb, $thisTopic) = Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  # find the actual implementation
  if ($theObject) {
    my ($methodWeb, $methodTopic) = findTopicMethod($session, $thisWeb, $thisTopic, $theObject);
    if (defined $methodWeb) {
      #writeDebug("found impl at $methodWeb.$methodTopic");
      $params->{OBJECT} = $theObject;
      $thisWeb = $methodWeb;
      $thisTopic = $methodTopic;
    } else {
      # last resort: lookup the method in the Applications web
      #writeDebug("last resort check for Applications.$thisTopic");
      my $appDB = getDB('Applications');
      if ($appDB && $appDB->fastget($thisTopic)) {
        $params->{OBJECT} = $theObject;
        $thisWeb = 'Applications';
      }
    }
  }

  $Foswiki::Plugins::DBCachePlugin::addDependency->($thisWeb, $thisTopic);

  # remember args for the key before mangling the params
  my $args = $params->stringify();

  my $section = $params->remove('section') || 'default';
  my $warn = $params->remove('warn') || 'on';
  $warn = ($warn eq 'on')?1:0;
  my $remote = $params->remove('remote') || 'off';
  $remote = ($remote =~ /^(on|force|1|yes)$/)?1:0;

  #writeDebug("thisWeb=$thisWeb thisTopic=$thisTopic baseWeb=$baseWeb baseTopic=$baseTopic");

  # get web and topic
  my $thisDB = getDB($thisWeb);
  return inlineError("ERROR: DBALL can't find web $thisWeb") unless $thisDB;

  my $topicObj = $thisDB->fastget($thisTopic);
  unless ($topicObj) {
    if ($warn) {
      if ($theObject) {
        return inlineError("ERROR: DBCALL can't find method <nop>$thisTopic for object $theObject");
      } else {
        return inlineError("ERROR: DBCALL can't find topic <nop>$thisTopic in <nop>$thisWeb");
      }
    } else {
      return '';
    }
  }

  my %saveTags;
  if ($Foswiki::Plugins::VERSION >= 2.1) {
    Foswiki::Func::pushTopicContext($baseWeb, $baseTopic);
    foreach my $key (keys %$params) {
      my $val = $params->{$key};
      # SMELL: working around issue in the Foswiki parse 
      # where an undefined %VAR% in SESSION_TAGS is expanded to VAR instead of
      # leaving it to %VAR%
      unless ($val =~ /^\%$tagNameRegex\%$/) {
        Foswiki::Func::setPreferencesValue($key, $val)
      }
    }
  } else {
    %saveTags  = %{$session->{SESSION_TAGS}};
    # copy params into session tags
    foreach my $key (keys %$params) {
      my $val = $params->{$key};
        # SMELL: working around issue in the Foswiki parse 
      # where an undefined %VAR% in SESSION_TAGS is expanded to VAR instead of
      # leaving it to %VAR%
      unless ($val =~ /^\%$tagNameRegex\%$/) { 
        $session->{SESSION_TAGS}{$key} = $val;
      }
    }
  }

  # check access rights
  my $wikiName = Foswiki::Func::getWikiName();
  unless (Foswiki::Func::checkAccessPermission('VIEW', $wikiName, undef, $thisTopic, $thisWeb)) {
    if ($warn) {
      return inlineError("ERROR: DBCALL access to '$thisWeb.$thisTopic' denied");
    } 
    return '';
  }

  # get section
  my $sectionText = $topicObj->fastget("_section$section") if $topicObj;
  if (!defined $sectionText) {
    if($warn) {
      return inlineError("ERROR: DBCALL can't find section '$section' in topic '$thisWeb.$thisTopic'");
    } else {
      return '';
    }
  }

  # prevent recursive calls
  my $key = $thisWeb.'.'.$thisTopic;
  my $count = grep($key, keys %{$session->{dbcalls}});
  $key .= $args;
  if ($session->{dbcalls}->{$key} || $count > 99) {
    if($warn) {
      return inlineError("ERROR: DBCALL reached max recursion at '$thisWeb.$thisTopic'");
    }
    return '';
  }
  $session->{dbcalls}->{$key} = 1;

  # substitute variables
  $sectionText =~ s/%INCLUDINGWEB%/$theWeb/g;
  $sectionText =~ s/%INCLUDINGTOPIC%/$theTopic/g;
  foreach my $key (keys %$params) {
    $sectionText =~ s/%$key%/$params->{$key}/g;
  }

  # expand
  my $context = Foswiki::Func::getContext();
  $context->{insideInclude} = 1;
  $sectionText = Foswiki::Func::expandCommonVariables($sectionText, $thisTopic, $thisWeb);
  delete $context->{insideInclude};

  # fix local linx
  fixInclude($session, $thisWeb, $sectionText) if $remote;

  # cleanup
  delete $session->{dbcalls}->{$key};

  if ($Foswiki::Plugins::VERSION >= 2.1) {
    Foswiki::Func::popTopicContext();
  } else {
    %{$session->{SESSION_TAGS}} = %saveTags;
  }

    #writeDebug("done handleDBCALL");

  return $sectionText;
  #return "<verbatim>\n$sectionText\n</verbatim>";
}

###############################################################################
sub handleDBSTATS {
  my ($session, $params, $theTopic, $theWeb) = @_;

  writeDebug("called handleDBSTATS");

  # get args
  my $theSearch = $params->{_DEFAULT} || $params->{search} || '';
  my $thisWeb = $params->{web} || $baseWeb;
  my $thisTopic = $params->{topic} || $baseTopic;
  my $thePattern = $params->{pattern} || '^(.*)$';
  my $theSplit = $params->{split} || '\s*,\s*';
  my $theHeader = $params->{header} || '';
  my $theFormat = $params->{format};
  my $theFooter = $params->{footer} || '';
  my $theSep = $params->{separator};
  my $theFields = $params->{fields} || $params->{field} || 'text';
  my $theSort = $params->{sort} || $params->{order} || 'alpha';
  my $theReverse = $params->{reverse} || 'off';
  my $theLimit = $params->{limit} || 0;
  my $theHideNull = $params->{hidenull} || 'off';
  my $theExclude = $params->{exclude};
  my $theInclude = $params->{include};
  my $theCase = $params->{casesensitive} || 'off';
  $theLimit =~ s/[^\d]//go;

  $theFormat = '   * $key: $count' unless defined $theFormat;
  $theSep = $params->{sep} unless defined $theSep;
  $theSep = '$n' unless defined $theSep;

  $theCase = ($theCase eq 'on'?1:0);

  #writeDebug("theSearch=$theSearch");
  #writeDebug("thisWeb=$thisWeb");
  #writeDebug("thePattern=$thePattern");
  #writeDebug("theSplit=$theSplit");
  #writeDebug("theHeader=$theHeader");
  #writeDebug("theFormat=$theFormat");
  #writeDebug("theFooter=$theFooter");
  #writeDebug("theSep=$theSep");
  #writeDebug("theFields=$theFields");

  # build seach object
  my $search = new Foswiki::Contrib::DBCacheContrib::Search($theSearch);
  unless ($search) {
    return "ERROR: can't parse query $theSearch";
  }

  # compute statistics
  my $wikiName = Foswiki::Func::getWikiName();
  my %statistics = ();
  my $theDB = getDB($thisWeb);
  my @topicNames = $theDB->getKeys();
  foreach my $topicName (@topicNames) { # loop over all topics
    my $topicObj = $theDB->fastget($topicName);
    next unless $search->matches($topicObj); # that match the query
    next unless Foswiki::Func::checkAccessPermission('VIEW', 
      $wikiName, undef, $topicName, $thisWeb);

    #writeDebug("found topic $topicName");
    my $createdate = $topicObj->fastget('createdate');
    foreach my $field (split(/\s*,\s*/, $theFields)) { # loop over all fields
      my $fieldValue = $topicObj->fastget($field);
      if (!$fieldValue || ref($fieldValue)) {
	my $topicForm = $topicObj->fastget('form');
	#writeDebug("found form $topicForm");
	if ($topicForm) {
	  $topicForm = $topicObj->fastget($topicForm);
	  $fieldValue = $topicForm->fastget($field);
	}
      }
      next unless $fieldValue; # unless present
      $fieldValue = formatTime($fieldValue) if $field =~ /created(ate)?|modified/;
      writeDebug("reading field $field found $fieldValue");

      foreach my $item (split(/$theSplit/, $fieldValue)) {
        while ($item =~ /$thePattern/g) { # loop over all occurrences of the pattern
          my $key1 = $1;
          my $key2 = $2 || '';
          my $key3 = $3 || '';
          my $key4 = $4 || '';
          my $key5 = $5 || '';
          if ($theCase) {
            next if $theExclude && $key1 =~ /$theExclude/;
            next if $theInclude && $key1 !~ /$theInclude/;
          } else {
            next if $theExclude && $key1 =~ /$theExclude/i;
            next if $theInclude && $key1 !~ /$theInclude/i;
          }
          my $record = $statistics{$key1};
          if ($record) {
            $record->{count}++;
            $record->{from} = $createdate if $record->{from} > $createdate;
            $record->{to} = $createdate if $record->{to} < $createdate;
            push @{$record->{topics}}, $topicName;
          } else {
            my %record = (
              count=>1,
              from=>$createdate,
              to=>$createdate,
              keyList=>[$key1, $key2, $key3, $key4, $key5],
              topics=>[$topicName],
            );
            $statistics{$key1} = \%record;
          }
          $Foswiki::Plugins::DBCachePlugin::addDependency->($thisWeb, $topicName);
        }
      }
    }
  }
  my $min = 99999999;
  my $max = 0;
  my $sum = 0;
  foreach my $key (keys %statistics) {
    my $record = $statistics{$key};
    $min = $record->{count} if $min > $record->{count};
    $max = $record->{count} if $max < $record->{count};
    $sum += $record->{count};
  }
  my $numkeys = scalar(keys %statistics);
  my $mean = 0;
  $mean = (($sum+0.0) / $numkeys) if $numkeys;
  return '' if $theHideNull eq 'on' && $numkeys == 0;

  # format output
  my $result = '';
  my @sortedKeys;
  if ($theSort =~ /^created(from)?$/) {
    @sortedKeys = sort {
      $statistics{$a}->{from} <=> $statistics{$b}->{from}
    } keys %statistics
  } elsif ($theSort eq 'createdto') {
    @sortedKeys = sort {
      $statistics{$a}->{to} <=> $statistics{$b}->{to}
    } keys %statistics
  } elsif ($theSort eq 'count') {
    @sortedKeys = sort {
      $statistics{$a}->{count} <=> $statistics{$b}->{count}
    } keys %statistics
  } else {
    @sortedKeys = sort keys %statistics;
  }
  @sortedKeys = reverse @sortedKeys if $theReverse eq 'on';
  my $index = 0;
  foreach my $key (@sortedKeys) {
    $index++;
    my $record = $statistics{$key};
    my $text;
    my ($key1, $key2, $key3, $key4, $key5) =
      @{$record->{keyList}};
    $text = $theSep if $result;
    $text .= $theFormat;
    $result .= expandVariables($text, 
      $thisWeb,
      $thisTopic,
      'web'=>$thisWeb,
      'topics'=>join(', ', @{$record->{topics}}),
      'key'=>$key,
      'key1'=>$key1,
      'key2'=>$key2,
      'key3'=>$key3,
      'key4'=>$key4,
      'key5'=>$key5,
      'count'=>$record->{count}, 
      'index'=>$index,
    );

    last if $theLimit && $index == $theLimit;
  }
  $result = expandVariables($theHeader.$result.$theFooter, $thisWeb, $thisTopic,
    'min'=>$min,
    'max'=>$max,
    'sum'=>$sum,
    'mean'=>$mean,
    'keys'=>$numkeys,
  );
  $result = Foswiki::Func::expandCommonVariables($result, $thisTopic, $thisWeb);

  return $result;
}

###############################################################################
sub handleDBDUMP {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleDBDUMP");

  my $thisTopic = $params->{_DEFAULT} || $baseTopic;
  my $thisWeb = $params->{web} || $baseWeb;
  ($thisWeb, $thisTopic) = Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  $Foswiki::Plugins::DBCachePlugin::addDependency->($thisWeb, $thisTopic);

  return dbDump($thisWeb, $thisTopic);
}

###############################################################################
sub restDBDUMP {
  my $session = shift;

  my $web = $session->{webName};
  my $topic = $session->{topicName};

  return dbDump($web, $topic);
}

###############################################################################
sub dbDump {
  my ($web, $topic) = @_;

  my $theDB = getDB($web);

  my $topicObj = $theDB->fastget($topic) || '';
  unless ($topicObj) {
    return inlineError("DBCachePlugin: $web.$topic not found");
  }
  my $result = "\n<noautolink>\n";
  $result .= "---++ [[$web.$topic]]\n$topicObj\n";

  # read all keys
  $result .= "<table class='foswikiTable'>\n";
  foreach my $key (sort $topicObj->getKeys()) {
    my $value = $topicObj->fastget($key);
    $value = 'undef' unless defined $value;
    $result .= "<tr><th>$key</th>\n<td><verbatim>\n$value\n</verbatim></td></tr>\n";
  }
  $result .= "</table>\n";

  # read info
  my $topicInfo = $topicObj->fastget('info');
  $result .= "<p/>\n---++ Info = $topicInfo\n";
  $result .= "<table class='foswikiTable'>\n";
  foreach my $key (sort $topicInfo->getKeys()) {
    my $value = $topicInfo->fastget($key);
    $result .= "<tr><th>$key</th><td>$value</td></tr>\n" if defined $value;
  }
  $result .= "</table>\n";

  # read form
  my $topicForm = $topicObj->fastget('form');
  if ($topicForm) {
    $result .= "<p/>\n---++ Form = $topicForm\n";
    $result .= "<table class='foswikiTable'>\n";
    $topicForm = $topicObj->fastget($topicForm);
    foreach my $key (sort $topicForm->getKeys()) {
      my $value = $topicForm->fastget($key);
      $result .= "<tr><th>$key</th><td>$value</td>\n" if defined $value;
    }
    $result .= "</table>\n";
  }

  # read attachments
  my $attachments = $topicObj->fastget('attachments');
  if ($attachments) {
    $result .= "<p/>\n---++ Attachments = $attachments\n";
    $result .= "<table class='foswikiTable'>\n";
    foreach my $attachment (sort $attachments->getValues()) {
      $result .= "<tr><th valign='top'>".$attachment->fastget('name')."</th>";
      $result .= '<td><table>';
      foreach my $key (sort $attachment->getKeys()) {
        next if $key eq 'name';
        my $value = $attachment->fastget($key);
        $result .= "<tr><th>$key</th><td>$value</td></tr>\n" if defined $value;
      }
      $result .= '</table></td></tr>';
    }
    $result .= "</table>\n";
  }

  # read preferences
  my $prefs = $topicObj->fastget('preferences');
  if ($prefs) {
    $result .= "<p/>\n---++ Preferences = $prefs\n";
    $result .= "<table class='foswikiTable'>\n";
    $result .= '<tr><th>type</th><th>name</th><th>title</th><th>value</th><th>_up</th><th>_web</th></tr>'."\n";
    foreach my $pref (sort {$a->fastget('name') cmp $b->fastget('name')} $prefs->getValues()) {
      $result .= "<tr><td>".$pref->fastget('type')."</td>\n";
      $result .= "<td>".$pref->fastget('name')."</td>\n";
      $result .= "<td>".$pref->fastget('title')."</td>\n";
      $result .= "<td>".$pref->fastget('value')."</td>\n";
      $result .= "<td>".$pref->fastget('_up')."</td>\n";
      $result .= "<td>".$pref->fastget('_web')."</td>\n";
      $result .= "</tr>\n";
    }
    $result .= "</table>\n";
  }

  # read comments
  my $comments = $topicObj->fastget('comments');
  if ($comments) {
    $result .= "<p/>\n---++ Comments = $comments\n";
    $result .= "<table class='foswikiTable'>\n";
    foreach my $comment (sort $comments->getValues()) {
      $result .= "<tr><th valign='top'>".$comment->fastget('name')."</th>";
      $result .= '<td><table>';
      foreach my $key (sort $comment->getKeys()) {
        next if $key eq 'name';
        my $value = $comment->fastget($key);
        $result .= "<tr><th>$key</th><td>$value</td></tr>\n" if defined $value;
      }
      $result .= '</table></td>';
    }
    $result .= "</tr></table>\n";
  }

  return $result."\n</noautolink>\n";
}

###############################################################################
sub handleDBRECURSE {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleDBRECURSE(" . $params->stringify() . ")");

  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;
  my $thisWeb = $params->{web} || $baseWeb;

  ($thisWeb, $thisTopic) = 
    Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  $params->{format} ||= '   $indent* [[$web.$topic][$topic]]';
  $params->{single} ||= $params->{format};
  $params->{separator} ||= $params->{sep} || "\n";
  $params->{header} ||= '';
  $params->{subheader} ||= '';
  $params->{singleheader} ||= $params->{header};
  $params->{footer} ||= '';
  $params->{subfooter} ||= '';
  $params->{singlefooter} ||= $params->{footer};
  $params->{hidenull} ||= 'off';
  $params->{filter} ||= 'parent=\'$name\'';
  $params->{sort} ||= $params->{order} || 'name';
  $params->{reverse} ||= 'off';
  $params->{limit} ||= 0;
  $params->{skip} ||= 0;
  $params->{depth} ||= 0;

  $params->{format} = '' if $params->{format} eq 'none';
  $params->{single} = '' if $params->{single} eq 'none';
  $params->{header} = '' if $params->{header} eq 'none';
  $params->{footer} = '' if $params->{footer} eq 'none';
  $params->{subheader} = '' if $params->{subheader} eq 'none';
  $params->{subfooter} = '' if $params->{subfooter} eq 'none';
  $params->{singleheader} = '' if $params->{singleheader} eq 'none';
  $params->{singlefooter} = '' if $params->{singlefooter} eq 'none';
  $params->{separator} = '' if $params->{separator} eq 'none';

  # query topics
  my $theDB = getDB($thisWeb);
  $params->{_count} = 0;
  my $result = formatRecursive($theDB, $thisWeb, $thisTopic, $params);
  return '' unless $result;

  # render result
  return '' if $params->{hidenull} eq 'on' && $params->{_count} == 0;

  return 
    expandVariables(
      ($params->{_count} == 1)?$params->{singleheader}:$params->{header}, 
      $thisWeb, $thisTopic, 
      count=>$params->{_count}).
    join($params->{separator},@$result).
    expandVariables(
      ($params->{_count} == 1)?$params->{singlefooter}:$params->{footer}, 
      $thisWeb, $thisTopic, 
      count=>$params->{_count});
}

###############################################################################
sub formatRecursive {
  my ($theDB, $theWeb, $theTopic, $params, $seen, $depth, $number) = @_;

  # protection agains infinite recursion
  my %thisSeen;
  $seen ||= \%thisSeen;
  return if $seen->{$theTopic};
  $seen->{$theTopic} = 1;
  $depth ||= 0;
  $number ||= '';

  return if $params->{depth} && $depth >= $params->{depth};
  return if $params->{limit} && $params->{_count} >= $params->{limit};

  #writeDebug("called formatRecursive($theWeb, $theTopic)");
  return unless $theTopic;

  # search sub topics
  my $queryString = $params->{filter};
  $queryString =~ s/\$ref\b/$theTopic/g; # backwards compatibility
  $queryString =~ s/\$name\b/$theTopic/g;

  #writeDebug("queryString=$queryString");
  my ($topicNames, $hits, $errMsg) = $theDB->dbQuery($queryString, undef, 
    $params->{sort},
    $params->{reverse},
    $params->{include},
    $params->{exclude});
  die $errMsg if $errMsg; # never reach

  # format this round
  my @result = ();
  my $index = 0;
  my $nrTopics = scalar(@$topicNames);
  foreach my $topicName (@$topicNames) {
    next if $topicName eq $theTopic; # cycle, kind of
    $params->{_count}++;
    next if $params->{_count} <= $params->{skip};

    # format this
    my $numberString = ($number)?"$number.$index":$index;

    my $text = ($nrTopics == 1)?$params->{single}:$params->{format};
    $text = expandVariables($text, $theWeb, $theTopic,
      'web'=>$theWeb,
      'topic'=>$topicName,
      'number'=>$numberString,
      'index'=>$index,
      'count'=>$params->{_count},
    );
    $text =~ s/\$indent\((.+?)\)/$1 x $depth/ge;
    $text =~ s/\$indent/'   ' x $depth/ge;

    # from DBQUERY
    my $topicObj = $hits->{$topicName};
    $text =~ s/\$formfield\((.*?)\)/
      my $temp = $theDB->getFormField($topicName, $1);
      $temp =~ s#\)#${TranslationToken}#g;
      $temp/geo;
    $text =~ s/\$expand\((.*?)\)/
      my $temp = $theDB->expandPath($topicObj, $1);
      $temp =~ s#\)#${TranslationToken}#g;
      $temp/geo;
    $text =~ s/\$formatTime\((.*?)(?:,\s*'([^']*?)')?\)/formatTime($theDB->expandPath($topicObj, $1), $2)/geo; # single quoted

    push @result, $text;

    # recurse
    my $subResult = 
      formatRecursive($theDB, $theWeb, $topicName, $params, $seen, 
        $depth+1, $numberString);
    

    if ($subResult && @$subResult) {
      push @result, 
        expandVariables($params->{subheader}, $theWeb, $topicName, 
          'web'=>$theWeb,
          'topic'=>$topicName,
          'number'=>$numberString,
          'index'=>$index,
          'count'=>$params->{_count},
        ).
        join($params->{separator},@$subResult).
        expandVariables($params->{subfooter}, $theWeb, $topicName, 
          'web'=>$theWeb,
          'topic'=>$topicName,
          'number'=>$numberString,
          'index'=>$index,
          'count'=>$params->{_count},
        );
    }

    last if $params->{limit} && $params->{_count} >= $params->{limit};
  }

  return \@result;
}

###############################################################################
sub getDB {
  my ($theWeb, $refresh) = @_;

  writeDebug("called getDB($theWeb)");

  unless(Foswiki::Sandbox::validateWebName($theWeb, 1)) {
    if (DEBUG) {
      require Devel::StackTrace;
      my $trace = Devel::StackTrace->new;
      writeDebug($trace->as_string);
    }

    #die "invalid webname $theWeb";
    return;
  }

  # We do not need to reload the cache if we run on mod_perl or fastcgi or
  # whatever perl accelerator that keeps our global variables and 
  # the database wasn't modified!

  $theWeb =~ s/\//\./go;
  my $webKey = Cwd::abs_path($Foswiki::cfg{DataDir} . '/' . $theWeb);

  #writeDebug("webKey=$webKey");

  my $isModified = 0;
  unless (defined $webDB{$webKey}) {
    # never loaded
    $isModified = 1;
    writeDebug("fresh reload of '$theWeb'");
  } else {
    unless (defined $webDBIsModified{$webKey}) {
      # never checked
      $webDBIsModified{$webKey} = $webDB{$webKey}->isModified();
      if (DEBUG) {
        if ($webDBIsModified{$webKey}) {
          writeDebug("reloading modified $theWeb");
        } else {
          writeDebug("don't need to load webdb for $theWeb");
        }
      }
    }
    $isModified = $webDBIsModified{$webKey};
  }

  if ($isModified || $refresh) {
    my $impl = Foswiki::Func::getPreferencesValue('WEBDB', $theWeb)
      || 'Foswiki::Plugins::DBCachePlugin::WebDB';
    $impl =~ s/^\s+//go;
    $impl =~ s/\s+$//go;
    writeDebug("loading new webdb for '$theWeb'");
    #writeDebug("impl='$impl'");
    $webDB{$webKey} = new $impl($theWeb);
    $webDB{$webKey}->load($doRefresh, $baseWeb, $baseTopic);
    $webDBIsModified{$webKey} = 0;
  }

  if (DEBUG) {
    #require Data::Dumper;
    #my $db = $webDB{$webKey};
    #print STDERR "=====================\n";
    #print STDERR Data::Dumper->Dump([$db], [ref $db]);
    #print STDERR "=====================\n";
  }

  return $webDB{$webKey};
}

###############################################################################
sub DESTROY_ALL {
  foreach my $web (keys %webDB) {
    #writeDebug("closing db for $web");
    $webDB{$web}->touch();
    delete $webDB{$web};
  }
  %webDB = ();
  %webDBIsModified = ();
}


###############################################################################
# from Foswiki::_INCLUDE
sub fixInclude {
  my $session = shift;
  my $thisWeb = shift;
  # $text next

  my $removed = {};

  # Must handle explicit [[]] before noautolink
  # '[[TopicName]]' to '[[Web.TopicName][TopicName]]'
  $_[0] =~ s/\[\[([^\]]+)\]\]/fixIncludeLink($thisWeb, $1)/geo;
  # '[[TopicName][...]]' to '[[Web.TopicName][...]]'
  $_[0] =~ s/\[\[([^\]]+)\]\[([^\]]+)\]\]/fixIncludeLink($thisWeb, $1, $2)/geo;

  $_[0] = takeOutBlocks($_[0], 'noautolink', $removed);

  # 'TopicName' to 'Web.TopicName'
  $_[0] =~ s/(^|[\s(])($webNameRegex\.$wikiWordRegex)/$1$TranslationToken$2/go;
  $_[0] =~ s/(^|[\s(])($wikiWordRegex)/$1\[\[$thisWeb\.$2\]\[$2\]\]/go;
  $_[0] =~ s/(^|[\s(])$TranslationToken/$1/go;

  putBackBlocks( \$_[0], $removed, 'noautolink');
}

###############################################################################
# from Foswiki::fixIncludeLink
sub fixIncludeLink {
  my( $theWeb, $theLink, $theLabel ) = @_;

  # [[...][...]] link
  if($theLink =~ /^($webNameRegex\.|$defaultWebNameRegex\.|$linkProtocolPattern\:|\/)/o) {
    if ( $theLabel ) {
      return "[[$theLink][$theLabel]]";
    } else {
      return "[[$theLink]]";
    }
  } elsif ( $theLabel ) {
    return "[[$theWeb.$theLink][$theLabel]]";
  } else {
    return "[[$theWeb.$theLink][$theLink]]";
  }
}

###############################################################################
sub expandVariables {
  my ($theFormat, $web, $topic, %params) = @_;

  return '' unless defined $theFormat;
  
  foreach my $key (keys %params) {
    my $val = $params{$key};
    next unless defined $val;
    if($theFormat =~ s/\$$key\b/${TranslationToken2}$params{$key}${TranslationToken2}/g) {
      #writeDebug("expanding $key->$params{$key}");
    }
  }
  $theFormat =~ s/\$perce?nt/\%/go;
  $theFormat =~ s/\$nop//g;
  $theFormat =~ s/\$n/\n/go;
  $theFormat =~ s/\$flatten\((.*?)\)/flatten($1, $web, $topic)/ges;
  $theFormat =~ s/\$rss\((.*?)\)/rss($1, $web, $topic)/ges;
  $theFormat =~ s/\$encode\((.*?)\)/entityEncode($1)/ges;
  $theFormat =~ s/\$trunc\((.*?),\s*(\d+)\)/substr($1,0,$2)/ges;
  $theFormat =~ s/\$t\b/\t/go;
  $theFormat =~ s/\$dollar/\$/go;
  $theFormat =~ s/\$quot/"/go;
  $theFormat =~ s/${TranslationToken2}//go;

  return $theFormat;
}

###############################################################################
# fault tolerant wrapper
sub formatTime {
  my ($time, $format) = @_;

  $time ||= 0;

  unless ($time =~ /^-?\d+$/) {
    $time = Foswiki::Time::parseTime($time);
  }

  $time ||= 0;

  return Foswiki::Func::formatTime($time, $format)
}


###############################################################################
# used to encode rss feeds
sub rss {
  my ($text, $web, $topic) = @_;

  $text = "\n<noautolink>\n$text\n</noautolink>\n";
  $text = Foswiki::Func::expandCommonVariables($text, $topic, $web);
  $text = Foswiki::Func::renderText($text);
  $text =~ s/\b(onmouseover|onmouseout|style)=".*?"//go; # TODO filter out more not validating attributes
  $text =~ s/<nop>//go;
  $text =~ s/[\n\r]+/ /go;
  $text =~ s/\n*<\/?noautolink>\n*//go;
  $text =~ s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|])/'&#'.ord($1).';'/ge;
  $text =~ s/^\s*(.*?)\s*$/$1/gos;

  return $text;
}

###############################################################################
sub entityEncode {
  my $text = shift;

  $text =~ s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|])/'&#'.ord($1).';'/ge;

  return $text;
}

###############################################################################
sub entityDecode {
  my $text = shift;

  $text =~ s/&#(\d+);/chr($1)/ge;
  return $text;
}

###############################################################################
sub urlEncode {
  my $text = shift;

  $text =~ s/([^0-9a-zA-Z-_.:~!*'\/%])/'%'.sprintf('%02x',ord($1))/ge;

  return $text;
}

###############################################################################
sub urlDecode {
  my $text = shift;

  $text =~ s/%([\da-f]{2})/chr(hex($1))/gei;

  return $text;
}

###############################################################################
sub flatten {
  my ($text, $web, $topic) = @_;

  my $session = $Foswiki::Plugins::SESSION;
  my $topicObject = Foswiki::Meta->new($session, $web, $topic);
  $text = $session->renderer->TML2PlainText($text, $topicObject);

  $text =~ s/(https?)/<nop>$1/go;
  $text =~ s/[\r\n\|]+/ /gm;
  return $text;
}

sub OLDflatten {
  my $text = shift;

  $text =~ s/&lt;/</g;
  $text =~ s/&gt;/>/g;

  $text =~ s/^---\++.*$//gm;
  $text =~ s/\<[^\>]+\/?\>//g;
  $text =~ s/<\!\-\-.*?\-\->//gs;
  $text =~ s/\&[a-z]+;/ /g;
  $text =~ s/[ \t]+/ /gs;
  $text =~ s/%//gs;
  $text =~ s/_[^_]+_/ /gs;
  $text =~ s/\&[a-z]+;/ /g;
  $text =~ s/\&#[0-9]+;/ /g;
  $text =~ s/[\r\n\|]+/ /gm;
  $text =~ s/\[\[//go;
  $text =~ s/\]\]//go;
  $text =~ s/\]\[//go;
  $text =~ s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|])/'&#'.ord($1).';'/ge;
  $text =~ s/(https?)/<nop>$1/go;
  $text =~ s/\b($wikiWordRegex)\b/<nop>$1/g;
  $text =~ s/^\s+//;

  return $text;
}

###############################################################################
sub extractPattern {
  my ($topicObj, $pattern) = @_;

  my $text = $topicObj->fastget('text') || '';
  my $result = '';
  while ($text =~ /$pattern/gs) {
    $result .= ($1 || '');
  }
  
  return $result;
}


###############################################################################
sub inlineError {
  return "<div class='foswikiAlert'>$_[0]</div>";
}

###############################################################################
# compatibility wrapper 
sub takeOutBlocks {
  return Foswiki::takeOutBlocks(@_) if defined &Foswiki::takeOutBlocks;
  return $Foswiki::Plugins::SESSION->renderer->takeOutBlocks(@_);
}

###############################################################################
# compatibility wrapper 
sub putBackBlocks {
  return Foswiki::putBackBlocks(@_) if defined &Foswiki::putBackBlocks;
  return $Foswiki::Plugins::SESSION->renderer->putBackBlocks(@_);
}


###############################################################################
1;
