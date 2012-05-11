# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2012 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::EditChapterPlugin::Core;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::Plugins::JQueryPlugin ();
use Foswiki::Contrib::JsonRpcContrib::Error ();
use Error qw(:try);

use constant DEBUG => 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR "- EditChapterPlugin - $_[0]\n" if DEBUG;
}

###############################################################################
sub new {
  my $class = shift;
  my $session = shift;

  my $minDepth = 
    Foswiki::Func::getPreferencesValue("EDITCHAPTERPLUGIN_MINDEPTH") || 1;
  my $maxDepth = 
    Foswiki::Func::getPreferencesValue("EDITCHAPTERPLUGIN_MAXDEPTH") || 6;
  my $editImg = 
    Foswiki::Func::getPreferencesValue("EDITCHAPTERPLUGIN_EDITIMG") || 
    '<img src="%PUBURLPATH%/%SYSTEMWEB%/EditChapterPlugin/pencil.png" height="16" width="16" border="0" />';
  my $editLabelFormat = 
    Foswiki::Func::getPreferencesValue("EDITCHAPTERPLUGIN_EDITLABELFORMAT") || 
    '<span id="$id" class="ecpHeading"> $heading <a href="$url" class="ecpEdit {web:\'$web\', topic:\'$topic\'}">$img</a></span>';

  my $wikiName = Foswiki::Func::getWikiName();

  my $this = {
    minDepth => $minDepth,
    maxDepth => $maxDepth,
    editLabelFormat => $editLabelFormat,
    editImg => $editImg,
    session => $session,
    baseWeb => $session->{webName},
    baseTopic => $session->{topicName},
    translationToken => "<span class='tok'></span>",
    wikiName => $wikiName,
    @_,
  };

  my $enabled = 
    Foswiki::Func::getPreferencesValue("EDITCHAPTERPLUGIN_ENABLED") || 'on';

  $enabled = ($enabled eq 'on')?1:0;
  $this->{enabled}{$this->{baseWeb}.'.'.$this->{baseTopic}} = $enabled;

  Foswiki::Func::addToZone('head', 'EDITCHAPTERPLUGIN', <<'HERE', 'JQUERYPLUGIN::FOSWIKI');
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/EditChapterPlugin/ecpstyles.css" type="text/css" media="all" />
HERE
  Foswiki::Func::addToZone('script', 'EDITCHAPTERPLUGIN', <<'HERE', 'JQUERYPLUGIN::FOSWIKI, JQUERYPLUGIN::HOVERINTENT');
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/EditChapterPlugin/ecpjavascript.js"></script>
HERE

  if ($Foswiki::cfg{Validation}{Method} eq 'strikeone') {
    # make sure strikeone.js is loaded even though there isn't a form on the page yet.
    Foswiki::Func::addToZone( 'script', 'JavascriptFiles/strikeone', <<JS );
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JavascriptFiles/strikeone.js"></script>
JS
  }

  Foswiki::Plugins::JQueryPlugin::createPlugin("hoverintent");
  Foswiki::Plugins::JQueryPlugin::createPlugin("ui::dialog");
  Foswiki::Plugins::JQueryPlugin::createPlugin("jsonrpc");
  Foswiki::Plugins::JQueryPlugin::createPlugin("natedit");


  return bless($this, $class);
}

###############################################################################
sub handleEnableEditChapter {
  my ($this, $web, $topic, $flag) = @_;

  $this->{enabled}{$web.'.'.$topic} = ($flag eq 'EN')?1:0;

  #writeDebug("called handleEnableEditChapter($web, $topic, $flag)");

  return '';
}

###############################################################################
sub jsonRpcLockTopic {
  my ($this, $request) = @_;

  my $web = $this->{baseWeb};
  my $topic = $this->{baseTopic};
  my (undef, $loginName, $unlockTime) = Foswiki::Func::checkTopicEditLock($web, $topic);

  my $wikiName = Foswiki::Func::getWikiName($loginName);
  my $currentWikiName = Foswiki::Func::getWikiName();

  # TODO: localize
  if ($loginName && $wikiName ne $currentWikiName) {
    my $time = int($unlockTime);
    if ($time > 0) {
      throw Foswiki::Contrib::JsonRpcContrib::Error(423, 
        "Topic is locked by $wikiName for another $time minute(s). Please try again later.");
    }
  }

  Foswiki::Func::setTopicEditLock($web, $topic, 1);

  return 'ok';
}

###############################################################################
sub jsonRpcUnlockTopic {
  my ($this, $request) = @_;

  my $web = $this->{baseWeb};
  my $topic = $this->{baseTopic};
  my (undef, $loginName, $unlockTime) = Foswiki::Func::checkTopicEditLock($web, $topic);

  return 'ok' unless $loginName; # nothing to unlock

  my $wikiName = Foswiki::Func::getWikiName($loginName);
  my $currentWikiName = Foswiki::Func::getWikiName();

  if ($wikiName ne $currentWikiName) {
    throw Foswiki::Contrib::JsonRpcContrib::Error(500, "Can't clear lease of user $wikiName")
      if $request->param("warn") ne 'off';
  } else {
    Foswiki::Func::setTopicEditLock($web, $topic, 0);
  }

  return 'ok';
}

###############################################################################
sub commonTagsHandler {
  my $this = shift;
  ### my ( $text, $topic, $web, $include, $meta ) = @_;

  my $text = $_[0];
  my $topic = $_[1];
  my $web = $_[2];

  return unless $topic;

  my $insideInclude = $_[3] || Foswiki::Func::getContext()->{insideInclude} || 0;
  my $key = $web.'.'.$topic;

  #writeDebug("called commonTagsHandler($web, $topic)");

  my $blocks = {};
  my $renderer = $Foswiki::Plugins::SESSION->renderer;
  $text = takeOutBlocks($text, 'verbatim', $blocks);
  $text = takeOutBlocks( $text, 'pre', $blocks);

  $text =~ s/%(EN|DIS)ABLEEDITCHAPTER%/
    $this->handleEnableEditChapter($web, $topic, $1)
  /ge;

  unless (defined $this->{enabled}{$key}) {
    my $access = 
      Foswiki::Func::checkAccessPermission('edit', $this->{wikiName}, undef, $topic, $web, undef);

    # disable edit if we have no access
    $this->{enabled}{$key} = 0 unless $access;
  }

  my $enabled = $this->{enabled}{$key};
  $enabled = 1 unless defined $enabled;

  # prohibit edit on self-includes
  $enabled = 0 if $insideInclude && 
    $this->{baseWeb} eq $web && $this->{baseTopic} eq $topic;

  #writeDebug("enabled=$enabled");

  # loop over all lines
  my $chapterNumber = 0;
  $text =~ s/(^)(---+[\+#]{$this->{minDepth},$this->{maxDepth}}[0-9]*(?:!!)?)(?!$this->{translationToken})([^\+#!].+?)($)/
    $1.
    $this->handleSection($web, $topic, \$chapterNumber, $3, $2, $4, $enabled)
  /gme;

  putBackBlocks( \$text, $blocks, 'pre' );
  putBackBlocks( \$text, $blocks, 'verbatim' );

  $_[0] = $text;
}

###############################################################################
sub handleSection {
  my ($this, $web, $topic, $chapterNumber, $heading, $before, $after, $enabled) = @_;

  #writeDebug("called handleSection($web, $topic, '$heading')");

  my $result;

  unless ($enabled) {
    $result = $heading;
  } else {

    $$chapterNumber++;

    #writeDebug("chapterNumber=$$chapterNumber");

    my $from = $$chapterNumber;
    my $to = $$chapterNumber;

    #$from = 0 if $from == 1; # include chapter 0 in chapter 1

    my $title = $heading;
    $title =~ s/['"]//g;
    $title =~ s/^\s+//;
    $title =~ s/\s+$//;

    my $id = lc($web.'_'.$topic);
    $id =~ s/\//_/go;
    $id = 'chapter_'.$id.'_'.$$chapterNumber;

    my %args = (
      name => "edit.chapter",
      expand => "dialog",
      topic => "$web.$topic",
      from => $from,
      to => $to,
      title => $title,
      id => $id,
      t => time(),
    );

    my $query = Foswiki::Func::getCgiQuery();
    my $queryString = $query->query_string();
    $queryString = $queryString?"?$queryString":"";

    $args{redirectto} = 
      Foswiki::Func::getScriptUrl($this->{baseWeb}, $this->{baseTopic}, 'view').
      $queryString.
      "#$id";

    my $url = Foswiki::Func::getScriptUrl('RenderPlugin', 'template', 'rest', %args);

    my $anchor = '<a name="'.$id.'"></a>';

    # format
    $result = $this->{editLabelFormat};
    $result =~ s/\$from\b/$from/g;
    $result =~ s/\$to\b/$to/g;
    $result =~ s/\$id\b/$id/g;
    $result =~ s/\$anchor\b/$anchor/g;
    $result =~ s/\$url\b/$url/g;
    $result =~ s/\$web\b/$web/g;
    $result =~ s/\$topic\b/$topic/g;
    $result =~ s/\$baseweb\b/$this->{baseWeb}/g;
    $result =~ s/\$basetopic\b/$this->{baseTopic}/g;
    $result =~ s/\$heading\b/$heading/g;
    $result =~ s/\$title\b/$title/g;
    $result =~ s/\$index\b/$$chapterNumber/g;
    $result =~ s/\$img\b/$this->{editImg}/g;
  }

  $result = $before.$this->{translationToken}.$result.$after;
  #writeDebug("result=$result");
  return $result;
}

###############################################################################
sub handleEXTRACTCHAPTER {
  my ($this, $params, $theTopic, $theWeb) = @_;

  writeDebug("called handleEXTRACTCHAPTER()");

  my $theFrom = $params->{from} || 0;
  my $theTo = $params->{to} || 9999999;
  my $theNumber = $params->{nr};
  my $theBefore = $params->{before};
  my $theAfter = $params->{after};
  my $theEncode = $params->{encode} || 'off';

  # keep track of the extraction mode. 
  # STARTCHAPTER and STOPCHAPTER marks are handled differently per mode
  # 1: extract a fragment defined by nr/from/to
  # 2: extract the fragment defined by before
  # 3: extract the fragment defined by after
  my $extractionMode = 1; 

  $theFrom =~ s/[^\d]//go;
  $theTo =~ s/[^\d]//go;

  if (defined($theNumber)) {
    $theNumber =~ s/[^\d]//go;
    $theFrom = $theNumber;
    $theTo = $theNumber;
  }
  if (defined($theBefore)) {
    $theBefore =~ s/[^\d]//go;
    $theBefore ||= 0;
    $theTo = $theBefore - 1;
    $extractionMode = 2;
  }
  if (defined($theAfter)) {
    $theAfter =~ s/[^\d]//go;
    $theAfter ||= 0;
    $theFrom = $theAfter + 1;
    $extractionMode = 3;
  }

  return '' if $theTo < 0;

  writeDebug("extractionMode=$extractionMode");

  my $thisWeb = $params->{web} || $this->{baseWeb};
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $this->{baseTopic};

  ($thisWeb, $thisTopic) = 
    Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  writeDebug("thisWeb=$thisWeb, thisTopic=$thisTopic, theFrom=$theFrom, theTo=$theTo");

  my ($meta, $text) = Foswiki::Func::readTopic($thisWeb, $thisTopic);

  # check access permissions
  my $access = 
    Foswiki::Func::checkAccessPermission('view', $this->{wikiName}, $text, $thisTopic, $thisWeb, $meta);
  return '' unless $access;

  #writeDebug("BEGIN TEXT\n$text\nEND TEXT");

  # translate chapter span to text positions
  my $chapterNumber = 0;
  my $fromPos; $fromPos = 0 if $theFrom == 0;
  my $toPos;
  my $startChapterPos; # last occurence of a STARTCHAPTER 
  my $stopChapterPos; # last occurence of a STOPCHAPTER 
  my $insidePre = 0;
  my $insideChapter = 0;

  # CHAPTER parser
  while ($text =~ /(^.*$)/gm) {
    my $line = $1;
    writeDebug("line='$line'");

    # skip pre's and verbatims
    $insidePre++ if $line =~ /<(pre|verbatim)[^>]*>/goi;
    $insidePre-- if $line =~ /<\/(pre|verbatim)>/goi;
    next if $insidePre > 0;

    # track STARTCHAPTER
    if ($line =~ /^%STARTCHAPTER%$/m) {
      if ($insideChapter) {
        # adjust fromPos 
        if ($extractionMode == 1) { # normal mode
          $fromPos = pos($text) + 1;
          writeDebug("found STARTCHAPTER, starting at $fromPos");
        }
      } else {
        # remember STARTCHAPTER to adjust toPos in before-mode
        $startChapterPos = pos($text) + 1; # remember previous STARTCHAPTER
        writeDebug("found STARTCHAPTER at $startChapterPos");

        # stop at STARTCHAPTER mark when toPos already found
        if ($extractionMode == 2 && defined($toPos)) {
          writeDebug("stopping at STARTMARK as we are in before-mode");
          last;
        }
      }
    }

    # track STOPCHAPTER
    if ($line =~ /^%(STOP|END)CHAPTER%$/m) {
      if ($insideChapter) {
        # adjust toPos and bail out
        if ($extractionMode == 1) { # normal mode
          $toPos = pos($text) - length($line);
          writeDebug("found STOPCHAPTER, stopping at $toPos");
          last;
        }
      } else {
        # remember STOPCHAPTER to adjust toPos in after-mode
        $stopChapterPos = pos($text) - length($line); # remember previous STOPCHAPTER
        writeDebug("found STOPCHAPTER at $stopChapterPos");
        next;
      }
    }

    # detect chapter headlines
    if ($line =~ /^---+[\+#]{$this->{minDepth},$this->{maxDepth}}(?:!!)?\s*(.+?)$/m) {
      $chapterNumber++;

      # begin of chapter
      if ($chapterNumber == $theFrom) {
        $fromPos = pos($text) - length($line);
        $insideChapter = 1;

        writeDebug("found start at $fromPos");

        # in 'after' extractionMode use the stopChapterPos for this fragment when:
        # 1. a STOPCHAPTER mark was found
        # 2. this is after-mode
        # 3. the fragment normally starts later
        if ($extractionMode == 3 && defined $stopChapterPos && $fromPos > $stopChapterPos) {
          writeDebug("using stopChapterPos in after-mode");
          $fromPos = $stopChapterPos;
          $stopChapterPos = undef;
        }

        next;
      } 
      
      # end of chapter
      if ($chapterNumber > $theTo) {

        # in-before mode stop at next chapter 
        if ($extractionMode == 2 && defined $toPos) {
          writeDebug("got next chapter ... bailing out");
          last;
        }

        last unless defined $fromPos;

        $toPos = pos($text) - length($line);
        $insideChapter = 0;

        writeDebug("found end at $toPos");

        # continue in before-mode; instead scan til end of text or STARTCHAPTER mark
        if ($extractionMode == 2) {
          writeDebug("... continuing searching for the next STARTCHAPTER");
        } else {
          writeDebug("bailing out");
          last; 
        }
      }

      # reset the last STOPCHAPTER mark as we passed another chapter further down
      if ($chapterNumber < $theFrom) {
        writeDebug("resetting stopChapterPos");
        $stopChapterPos = undef;
      }
    }
  }

  # if we did not find the chapter headline but a STOPCHAPTER marker then use this
  if (!defined($fromPos) && defined ($stopChapterPos)) {
    writeDebug("using STOPCHAPTER marker for undefined fromPos");
    $fromPos = $stopChapterPos;
    $stopChapterPos = undef;
  }

  # if we did not find end of chapter, then set it to end of text
  my $length = length($text);
  $toPos = $length unless defined $toPos;


  # no start found: get me out of here
  return '' unless defined $fromPos;

  # in before-mode append the part to the following STARTCHAPTER mark
  if ($extractionMode == 2 && defined($startChapterPos) && $toPos < $startChapterPos) {
    writeDebug("moving toPos=$toPos to startChapterPos=$startChapterPos");
    $toPos = $startChapterPos;
  }

  # in after-mode prepend the part to the previous STOPCHAPTER mark
  if ($extractionMode == 3 && defined($stopChapterPos)) {
    writeDebug("moving toPos=$toPos to stopChapterPos=$stopChapterPos");
    $toPos = $stopChapterPos;
  }

  # now set the length of the extracted chunk
  $length = $toPos - $fromPos;

  writeDebug("fromPos=$fromPos, toPos=$toPos, length=$length");
  return '' if $length <= 0;

  my $result = substr($text, $fromPos, $length);

  $result = entityEncode( $result, "\n" ) if $theEncode eq 'on';
  $result = '<verbatim>'.$result.'</verbatim>' if $theEncode eq 'verbatim';
  #writeDebug("BEGIN RESULT\n$result\nEND RESULT");
  return $result;
}

###############################################################################
sub entityEncode {
  my ( $text, $extra ) = @_;
  $extra ||= '';

  $text =~
    s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|$extra])/'&#'.ord($1).';'/ge;

  return $text;
}

###############################################################################
# compatibility wrapper 
sub takeOutBlocks {
  return Foswiki::takeOutBlocks(@_) if defined &Foswiki::takeOutBlocks;
  return $Foswiki::Plugins::SESSION->{renderer}->takeOutBlocks(@_);
}

###############################################################################
# compatibility wrapper 
sub putBackBlocks {
  return Foswiki::putBackBlocks(@_) if defined &Foswiki::putBackBlocks;
  return $Foswiki::Plugins::SESSION->{renderer}->putBackBlocks(@_);
}

1;
