# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2012 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
###############################################################################

package Foswiki::Plugins::DBCachePlugin::WebDB;

use strict;
use Foswiki::Contrib::DBCacheContrib ();
use Foswiki::Contrib::DBCacheContrib::Search ();
use Foswiki::Plugins::DBCachePlugin ();
use Foswiki::Attrs ();
use Foswiki::Time ();
use Error qw(:try);

use constant DEBUG => 0; # toggle me

@Foswiki::Plugins::DBCachePlugin::WebDB::ISA = ("Foswiki::Contrib::DBCacheContrib");

###############################################################################
sub new {
  my ($class, $web, $cacheName) = @_;

  $cacheName = 'DBCachePluginDB' unless $cacheName;

  writeDebug("new WebDB for $web");

  my $this = bless($class->SUPER::new($web, $cacheName), $class);
  $this->{_loadTime} = 0;
  $this->{web} = $this->{_web};
  $this->{web} =~ s/\./\//go;

  $this->{prevTopicCache} = ();
  $this->{nextTopicCache} = ();

  return $this;
}

###############################################################################
sub writeDebug {
  print STDERR "- DBCachePlugin::WebDB - $_[0]\n" if DEBUG;
}


###############################################################################
# cache time we loaded the cacheFile
sub load {
  my ($this, $refresh, $web, $topic) = @_;

  $refresh ||= 0;
  writeDebug("called load() for $this->{web}, refresh=$refresh");

  if ($refresh == 1) {
    # refresh a single topic
    $this->loadTopic($web, $topic);
    $refresh = 0;
  }

  # load the rest of the database 
  $this->SUPER::load($refresh);

  # then get the time stamp
  $this->{_loadTime} = $this->_getModificationTime();
}

###############################################################################
# WARNING: this breaks on Archivists that are not file-based
sub _getCacheFile {
  my $this = shift;

  my $cacheFile = $this->getArchivist()->{_file};
  writeDebug("cacheFile=$cacheFile");
  return $cacheFile if -f $cacheFile;

  writeDebug("cacheFile $cacheFile not found");

  return undef;
}

###############################################################################
sub _getModificationTime {
  my $this = shift;

  my $filename = $this->_getCacheFile();
  return 0 unless $filename;
  my @stat = stat($filename);

  return $stat[9] || $stat[10] || 0;
}

###############################################################################
sub touch {
  my $this = shift;

  my $filename = $this->_getCacheFile();
  return 0 unless $filename;

  return utime undef, undef, $filename;
}

###############################################################################
sub isModified {
  my $this = shift;

  return 1 if $this->_getModificationTime() == 0 || $this->{_loadTime} < $this->_getModificationTime();
  return 0;
}

###############################################################################
# called by superclass when one or more topics had
# to be reloaded from disc.
sub onReload {
  my ($this, $topics) = @_;

  writeDebug("called onReload()");

  foreach my $topicName (@$topics) {
    my $topic = $this->fastget($topicName);

    # anything we get to see here should be in the dbcache already.
    # however we still check for odd topics that did not make it into the cache
    # for some odd reason
    unless ($topic) {
      writeDebug("trying to load topic '$topicName' in web '$this->{web}' but it wasn't found in the cache");
      next;
    }

    # get meta object
    my ($meta, $text) = Foswiki::Func::readTopic($this->{web}, $topicName);
    my $origText = $text;

    # SMELL: call getRevisionInfo to make sure the latest revision is loaded
    # for get('TOPICINFO') further down the code
    $meta->getRevisionInfo();

    writeDebug("reloading $topicName");

    # createdate
    my ($createDate, $createAuthor) = Foswiki::Func::getRevisionInfo($this->{web}, $topicName, 1);
    $topic->set('createdate', $createDate);
    $topic->set('createauthor', $createAuthor);

    # get default section
    my $defaultSection = $text;
    $defaultSection =~ s/.*?%STARTINCLUDE%//s;
    $defaultSection =~ s/%STOPINCLUDE%.*//s;

    #applyGlue($defaultSection);
    $topic->set('_sectiondefault', $defaultSection);

    # get named sections

    # CAUTION: %SECTION will be deleted in the near future.
    # so please convert all %SECTION to %STARTSECTION

    while ($text =~ s/%(?:START)?SECTION{(.*?)}%(.*?)%ENDSECTION{[^}]*?"(.*?)"}%//s) {
      my $attrs = new Foswiki::Attrs($1);
      my $name = $attrs->{name} || $attrs->{_DEFAULT} || '';
      my $sectionText = $2;
      $topic->set("_section$name", $sectionText);
    }

    # get topic title
    my $topicTitle;

    # 1. get from preferences
    my $prefs = $topic->fastget('preferences');
    if ($prefs) {

      #print STDERR "trying prefs\n";
      foreach my $pref ($prefs->getValues()) {
        my $name = $pref->fastget('name');
        if ($name eq 'TOPICTITLE') {
          $topicTitle = $pref->fastget('value');
          $topicTitle = urlDecode($topicTitle);
          last;
        }
      }
    }

    # 2. get inline preferences
    unless (defined $topicTitle) {

      #print STDERR "trying inline prefs\n";
      $origText =~ tr/\r//d;
      if ($origText =~ /(?:^|\n)(?:\t|   )+\*\s+(?:Set|Local)\s+TOPICTITLE\s*=\s*(.*)(?:$|\n)/o) {
        $topicTitle = $1;
      }
    }

    # 3. get from form
    unless (defined $topicTitle) {
      my $form = $topic->fastget('form');
      if ($form) {

        #print STDERR "trying form\n";
        $form = $topic->fastget($form);
        $topicTitle = $form->fastget('TopicTitle') || '';
        $topicTitle = urlDecode($topicTitle);
      }
    }

    # 4. get from h1
    #    unless (defined $topicTitle) {
    #      #print STDERR "trying h1\n";
    #      #print STDERR "origText=\n$origText\n";
    #      if ($origText =~ /(?:^|\n)(?:(?:---+\+(?!\+)(?:!!)?\s*(.*?)\s*)|(?:<h1[^>]*>\s*(.*?)\s*<\/h1>))(?:\n|$)/o) {
    #        #print STDERR "found in heading\n";
    #        $topicTitle = $1 || $2;
    #        if ($topicTitle =~ /\%TOPICTITLE({.*})?\%/o ||
    #            $topicTitle =~ /\%WIKI(USER)NAME\%/o ||
    #            $topicTitle =~ /\%USERINFO({.*})?\%/o) {
    #          $topicTitle = undef; # not this time
    #        }
    #
    #        # strip some
    #        if (defined $topicTitle) {
    #          $topicTitle =~ s/\%TOPIC\%/$topicName/g;
    #          $topicTitle =~ s/\[\[.*\]\[(.*)\]\]/$1/go;
    #          $topicTitle =~ s/\[\[(.*)\]\]/$1/go;
    #          $topicTitle =~ s/<a[^>]*>(.*)<\/a>/$1/go;
    #          $topicTitle = Foswiki::Func::expandCommonVariables($topicTitle, $topicName, $this->{web});
    #        }
    #      }
    #    }

    # 5. use topic name
    unless ($topicTitle) {

      #print STDERR "defaulting to topic name\n";
      $topicTitle = $topicName;
    }

    #print STDERR "found topictitle=$topicTitle\n" if $topicTitle;
    $topic->set('topictitle', $topicTitle);

    # cache comments
    my @comments = $meta->find('COMMENT');
    my $commentDate = 0;
    my $cmts;
    my $archivist = $this->getArchivist();
    foreach my $comment (@comments) {
      my $cmt = $archivist->newMap(initial => $comment) ;
      my $cmtDate = $comment->{date};
      if ($cmtDate > $commentDate) {
        $commentDate = $cmtDate;
      }
      $cmt->set('_up', $topic);
      $cmt->set('_web', $this->{_cache});
      $cmts = $topic->get('comments');
      if (!defined($cmts)) {
        $cmts = $archivist->newArray();
        $topic->set('comments', $cmts);
      }
      $cmts->add($cmt);
    }
    if ($commentDate) {
      $topic->set('commentdate', $commentDate);
    }
  }

  #print STDERR "DEBUG: DBCachePlugin::WebDB - done onReload()\n";
}

###############################################################################
sub getFormField {
  my ($this, $theTopic, $theFormField) = @_;

  my $topicObj = $this->fastget($theTopic);
  return '' unless $topicObj;

  my $form = $topicObj->fastget('form');
  return '' unless $form;

  $form = $topicObj->fastget($form);
  return '' unless $form;

  my $fieldName = $theFormField;

  # FIXME: regexes copied from Foswiki::Form::fieldTitle2FieldName
  $fieldName =~ s/!//g;
  $fieldName =~ s/<nop>//g;
  $fieldName =~ s/[^A-Za-z0-9_\.]//g;

  my $formfield = $form->fastget($fieldName);
  $formfield = '' unless  defined $formfield;

  return urlDecode($formfield);
}

###############################################################################
sub getNeighbourTopics {
  my ($this, $theTopic, $theSearch, $theOrder, $theReverse) = @_;

  my $key = $this->{web}.'.'.$theTopic.':'.$theSearch.':'.$theOrder.':'.$theReverse;
  my $prevTopic = $this->{prevTopicCache}{$key};
  my $nextTopic = $this->{nextTopicCache}{$key};

  unless ($prevTopic && $nextTopic) {

    my ($resultList) = $this->dbQuery($theSearch, undef, $theOrder, $theReverse);
    my $state = 0;
    foreach my $t (@$resultList) {
      if ($state == 1) {
        $state = 2;
        $nextTopic = $t;
        last;
      }
      $state = 1 if $t eq $theTopic;
      $prevTopic = $t if $state == 0;
      #writeDebug("t=$t, state=$state");
    }

    $prevTopic = '_notfound' if !$prevTopic || $state == 0;
    $nextTopic = '_notfound' if !$nextTopic || !$state == 2;
    $this->{prevTopicCache}{$key} = $prevTopic;
    $this->{nextTopicCache}{$key} = $nextTopic;

    #writeDebug("prevTopic=$prevTopic, nextTopic=$nextTopic");

  }

  $prevTopic = '' if $prevTopic eq '_notfound';
  $nextTopic = '' if $nextTopic eq '_notfound';

  return ($prevTopic, $nextTopic);
}

###############################################################################
sub dbQuery {
  my ($this, $theSearch, $theTopics, $theSort, $theReverse, $theInclude, $theExclude) = @_;

  # TODO return empty result on an emtpy topics list

  $theSort ||= '';
  $theReverse ||= '';
  $theSearch ||= '';

  #print STDERR "DEBUG: called dbQuery($theSearch, $theTopics, $theSort, $theReverse) in $this->{web}\n";

  # get max hit set
  my @topicNames;
  if ($theTopics && @$theTopics) {
    @topicNames = @$theTopics;
  } else {
    @topicNames = $this->getKeys();
  }
  @topicNames = grep(/$theInclude/, @topicNames) if $theInclude;
  @topicNames = grep(!/$theExclude/, @topicNames) if $theExclude;

  # parse & fetch
  my $wikiName = Foswiki::Func::getWikiName();
  my %hits = ();
  my %sorting = ();
  my $search;
  if ($theSearch) {
    try {
      $search = new Foswiki::Contrib::DBCacheContrib::Search($theSearch);
    }
    catch Error::Simple with {
      my $error = shift;
    };
    unless ($search) {
      return (undef, undef, "ERROR: can't parse query \"$theSearch\"");
    }
  }

  my $webViewPermission = Foswiki::Func::checkAccessPermission('VIEW', $wikiName, undef, undef, $this->{web});

  my $doNumericalSort = 1;
  foreach my $topicName (@topicNames) {
    my $topicObj = $this->fastget($topicName);
    next unless $topicObj;    # never

    if (!$search || $search->matches($topicObj)) {

      # TODO: re-code DBCacheContrib to add '   * Set ALLOW... perms into the
      # META 'preferences', then recode to just use that.
      my $cachedText = $topicObj->fastget('text');

      #die "no text in $topicName\n" unless defined $cachedText;# never reach

      my $topicHasPerms = $cachedText =~ /(ALLOW|DENY)/;
      my $cachedPrefsMap = $topicObj->fastget('preferences');
      if (defined($cachedPrefsMap)) {

        #print STDERR "-----------------$topicName----$cachedPrefsMap";
        my @cachedPrefs = $cachedPrefsMap->getValues();
        $topicHasPerms ||= (grep('DENY', @cachedPrefs))
          || (grep('ALLOW', @cachedPrefs));
      }

      # don't check access perms on a topic that does not contain any
      # WARNING: this is hardcoded to assume Foswiki-Core permissions - anyone
      # doing pluggable Permissions need to
      # work out howto abstract this concept - or to disable it (its worth about 400mS per topic in the set. (if you're not WikiAdmin))
      if ((!$topicHasPerms && $webViewPermission)
        || Foswiki::Func::checkAccessPermission('VIEW', $wikiName, undef, $topicName, $this->{web}))
      {

        $hits{$topicName} = $topicObj;

        # pre-fetch the sorting key - thus we only do it N times
        if ($theSort =~ /^(on|name)$/) {
          $sorting{$topicName} = $topicName;
          $doNumericalSort = 0;
        } elsif ($theSort =~ /^created/) {
          $sorting{$topicName} = $topicObj->fastget('createdate');
        } elsif ($theSort =~ /^(modified|info\.date)/) {
          my $info = $topicObj->fastget('info');
          $sorting{$topicName} = $info ? $info->fastget('date') : 0;
        } elsif ($theSort ne 'off') {
          my $format = $theSort;
          $format =~ s/\$web/$this->{web}/g;
          $format =~ s/\$topic/$topicName/g;
          $format =~ s/\$perce?nt/\%/go;
          $format =~ s/\$nop//go;
          $format =~ s/\$n/\n/go;
          $format =~ s/\$dollar/\$/go;
          my @sorting = ();
          foreach my $item (split(/\s*,\s*/, $format)) {
            push @sorting, $item;
          }
          $sorting{$topicName} = $this->expandPath($topicObj, join(" and ", @sorting));
          $doNumericalSort = 0 
            if ($doNumericalSort == 1) && $sorting{$topicName} && !($sorting{$topicName} =~ /^[+-]?\d+(\.\d+)?$/);
          #print STDERR "topicName=$topicName - sorting=$sorting{$topicName} - doNumericalSort=$doNumericalSort\n";
        }
      }
    }
  }

  @topicNames = keys %hits;
  if (@topicNames > 1) {
    if ($theSort ne 'off') {
      if ($doNumericalSort == 1) {
        @topicNames =
          sort { ($sorting{$a}||0) <=> ($sorting{$b}||0) } @topicNames;
      } else {
        @topicNames =
          sort { $sorting{$a} cmp $sorting{$b} } @topicNames;
      }
    }
    @topicNames = reverse @topicNames if $theReverse eq 'on';
  }

  #print STDERR "DEBUG: result topicNames=@topicNames\n";

  return (\@topicNames, \%hits, undef);
}

###############################################################################
sub expandPath {
  my ($this, $theRoot, $thePath) = @_;

  return '' if !defined($thePath) || !defined($theRoot);
  $thePath =~ s/^\.//o;
  $thePath =~ s/\[([^\]]+)\]/$1/o;

  #print STDERR "DEBUG: expandPath($theRoot, $thePath)\n";

  if ($thePath =~ /^info.author$/) {
    my $info = $theRoot->fastget('info');
    return '' unless $info;
    my $author = $info->fastget('author');
    return Foswiki::Func::getWikiName($author);
  }
  if ($thePath =~ /^(.*?) and (.*)$/) {
    my $first = $1;
    my $tail = $2;
    my $result1 = $this->expandPath($theRoot, $first);
    return '' unless defined $result1 && $result1 ne '';
    my $result2 = $this->expandPath($theRoot, $tail);
    return '' unless defined $result2 && $result2 ne '';
    return $result1 . $result2;
  }
  if ($thePath =~ /^d2n\((.*)\)$/) {
    my $result = $this->expandPath($theRoot, $1);
    return 0 unless defined $result;
    return Foswiki::Time::parseTime($result);
  }
  if ($thePath =~ /^uc\((.*)\)$/) {
    my $result = $this->expandPath($theRoot, $1);
    return uc($result);
  }
  if ($thePath =~ /^lc\((.*)\)$/) {
    my $result = $this->expandPath($theRoot, $1);
    return lc($result);
  }
  if ($thePath =~ /^'([^']*)'$/) {

    #print STDERR "DEBUG: result=$1\n";
    return $1;
  }
  if ($thePath =~ /^[+-]?\d+(\.\d+)?$/) {
    #print STDERR "DEBUG: result=$thePath\n";
    return $thePath;
  }
  if ($thePath =~ /^(.*?) or (.*)$/) {
    my $first = $1;
    my $tail = $2;
    my $result = $this->expandPath($theRoot, $first);
    return $result if (defined $result && $result ne '');
    return $this->expandPath($theRoot, $tail);
  }
  if ($thePath =~ m/^(\w+)(.*)$/o) {
    my $first = $1;
    my $tail = $2;
    my $root;
    my $form = $theRoot->fastget('form');
    $form = $theRoot->fastget($form) if $form;
    $root = $form->fastget($first) if $form;
    $root = $theRoot->fastget($first) unless defined $root;
    return $this->expandPath($root, $tail) if ref($root);
    return '' unless defined $root;
    return $root if $first eq 'text';    # not url encoded
    my $field = urlDecode($root);

    #print STDERR "DEBUG: result=$field\n";
    return $field;
  }

  if ($thePath =~ /^@([^\.]+)(.*)$/) {
    my $first = $1;
    my $tail = $2;
    my $result = $this->expandPath($theRoot, $first);
    my $root;
    if (ref($result)) {
      $root = $result;
    } else {
      if ($result =~ /^(.*)\.(.*?)$/) {
        my $db = Foswiki::Plugins::DBCachePlugin::Core::getDB($1);
        $root = $db->fastget($2);
        return $db->expandPath($root, $tail);
      } else {
        $root = $this->fastget($result);
      }
    }
    return $this->expandPath($root, $tail);
  }

  if ($thePath =~ /^%/) {
    $thePath = &Foswiki::Func::expandCommonVariables($thePath, '', $this->{web});
    $thePath =~ s/^%/<nop>%/o;
    return $this->expandPath($theRoot, $thePath);
  }

  #print STDERR "DEBUG: result is empty\n";
  return '';
}

###############################################################################
# from Foswiki.pm
sub urlDecode {
  my $text = shift;

  $text =~ s/%([\da-f]{2})/chr(hex($1))/gei;

  return $text;
}

1;
