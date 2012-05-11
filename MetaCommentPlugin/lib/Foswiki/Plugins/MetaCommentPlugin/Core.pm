# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009-2012 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package Foswiki::Plugins::MetaCommentPlugin::Core;

use strict;
use warnings;
use Foswiki::Plugins ();
use Foswiki::Plugins::JQueryPlugin ();
use Foswiki::Contrib::JsonRpcContrib::Error ();
use Foswiki::Time ();
use Foswiki::Func ();
use Error qw( :try );

use constant DEBUG => 1; # toggle me
use constant DRY => 0; # toggle me

# Error codes for json-rpc response
# 1000: comment does not exist
# 1001: approval not allowed

###############################################################################
sub new {
  my ($class, $session) = @_;

  my $this = {
    session => $session,
    baseWeb => $session->{webName},
    baseTopic => $session->{topicName},
  };

  return bless($this, $class);
}

##############################################################################
sub jsonRpcGetComment {
  my ($this, $request) = @_;

  my $web = $this->{baseWeb};
  my $topic = $this->{baseTopic};
  my $wikiName = Foswiki::Func::getWikiName();

  throw Foswiki::Contrib::JsonRpcContrib::Error(404, "Topic $web.$topic does not exist") 
    unless Foswiki::Func::topicExists($this->{baseWeb}, $this->{baseTopic});

  throw Foswiki::Contrib::JsonRpcContrib::Error(401, "Access denied")
    unless Foswiki::Func::checkAccessPermission("VIEW", $wikiName, undef, $web, $topic);

  my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);

  my $id = $request->param('comment_id') || '';
  my $comment = $meta->get('COMMENT', $id);

  throw Foswiki::Contrib::JsonRpcContrib::Error(1000, "Comment not found")
    unless $comment;

  return $comment;
}

##############################################################################
sub jsonRpcSaveComment {
  my ($this, $request) = @_;

  my $web = $this->{session}{webName};
  my $topic = $this->{session}{topicName};
  my $wikiName = Foswiki::Func::getWikiName();

  throw Foswiki::Contrib::JsonRpcContrib::Error(404, "Topic $web.$topic does not exist") 
    unless Foswiki::Func::topicExists($this->{baseWeb}, $this->{baseTopic});

  throw Foswiki::Contrib::JsonRpcContrib::Error(401, "Access denied")
    unless Foswiki::Func::checkAccessPermission("VIEW", $wikiName, undef, $web, $topic);

  throw Foswiki::Contrib::JsonRpcContrib::Error(401, "Access denied")
    unless Foswiki::Func::checkAccessPermission('COMMENT', $wikiName, undef, $topic, $web) ||
           Foswiki::Func::checkAccessPermission('CHANGE', $wikiName, undef, $topic, $web);

  my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);

  my $author = $request->param('author') || $wikiName;
  my $title = $request->param('title') || '';
  my $cmtText = $request->param('text') || '';
  my $ref = $request->param('ref') || '';
  my $id = getNewId($meta);
  my $date = time();

  $meta->putKeyed(
    'COMMENT',
    {
      author => $author,
      state => "new, unapproved",
      date => $date,
      modified => $date,
      name => $id,
      ref => $ref,
      text => $cmtText,
      title => $title,
    }
  );

  Foswiki::Func::saveTopic($web, $topic, $meta, $text, {ignorepermissions=>1}) unless DRY;
  writeEvent("comment", "state=(new, unapproved) title=".($title||'').' text='.substr($cmtText, 0, 200)); # SMELL: does not objey approval state

  return;
}

##############################################################################
sub jsonRpcApproveComment {
  my ($this, $request) = @_;

  my $web = $this->{session}{webName};
  my $topic = $this->{session}{topicName};
  my $wikiName = Foswiki::Func::getWikiName();

  throw Foswiki::Contrib::JsonRpcContrib::Error(404, "Topic $web.$topic does not exist") 
    unless Foswiki::Func::topicExists($this->{baseWeb}, $this->{baseTopic});

  throw Foswiki::Contrib::JsonRpcContrib::Error(401, "Access denied")
    unless Foswiki::Func::checkAccessPermission("VIEW", $wikiName, undef, $web, $topic);

  throw Foswiki::Contrib::JsonRpcContrib::Error(401, "Access denied")
    unless Foswiki::Func::checkAccessPermission('CHANGE', $wikiName, undef, $topic, $web);

  my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);

  my $id = $request->param('comment_id') || '';
  my $comment = $meta->get('COMMENT', $id);

  throw Foswiki::Contrib::JsonRpcContrib::Error(1000, "Comment not found")
    unless $comment;

  # check if this is a moderator
  throw Foswiki::Contrib::JsonRpcContrib::Error(1001, "Approval not allowed")
    unless isModerator($wikiName, $web, $topic);

  # set the state
  $comment->{state} = "approved";

  Foswiki::Func::saveTopic($web, $topic, $meta, $text, {ignorepermissions=>1}) 
    unless DRY;

  writeEvent("commentapprove", "state=($comment->{state}) title=".($comment->{title}||'').' text='.substr($comment->{text}, 0, 200)); 

  return;
}

##############################################################################
sub jsonRpcUpdateComment {
  my ($this, $request) = @_;

  my $web = $this->{session}{webName};
  my $topic = $this->{session}{topicName};
  my $wikiName = Foswiki::Func::getWikiName();

  throw Foswiki::Contrib::JsonRpcContrib::Error(404, "Topic $web.$topic does not exist") 
    unless Foswiki::Func::topicExists($this->{baseWeb}, $this->{baseTopic});

  throw Foswiki::Contrib::JsonRpcContrib::Error(401, "Access denied")
    unless Foswiki::Func::checkAccessPermission("VIEW", $wikiName, undef, $web, $topic);

  throw Foswiki::Contrib::JsonRpcContrib::Error(401, "Access denied")
    unless Foswiki::Func::checkAccessPermission('COMMENT', $wikiName, undef, $topic, $web) ||
           Foswiki::Func::checkAccessPermission('CHANGE', $wikiName, undef, $topic, $web);

  my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);

  my $id = $request->param('comment_id') || '';
  my $comment = $meta->get('COMMENT', $id);

  throw Foswiki::Contrib::JsonRpcContrib::Error(1000, "Comment not found")
    unless $comment;

  my $title = $request->param('title') || '';
  my $cmtText = $request->param('text') || '';
  my $author = $comment->{author};
  my $date = $comment->{date};
  my $state = $comment->{state};
  my $modified = time();
  my $ref = $request->param('ref');
  $ref = $comment->{ref} unless defined $ref;

  my @new_state = ();
  push (@new_state, "updated") if $state =~ /\b(new|updated)\b/;
  push (@new_state, "approved") if $state =~ /\bapproved\b/;
  push (@new_state, "unapproved") if $state =~ /\bunapproved\b/;
  $state = join(", ", @new_state);

  $meta->putKeyed(
    'COMMENT',
    {
      author => $author,
      state => $state,
      date => $date,
      modified => $modified,
      name => $id,
      text => $cmtText,
      title => $title,
      ref => $ref,
    }
  );

  Foswiki::Func::saveTopic($web, $topic, $meta, $text, {ignorepermissions=>1}) unless DRY;
  writeEvent("commentupdate", "state=($state) title=".($title||'')." text=".substr($cmtText, 0, 200)); 

  return;
}

##############################################################################
sub jsonRpcDeleteComment {
  my ($this, $request) = @_;

  my $web = $this->{session}{webName};
  my $topic = $this->{session}{topicName};
  my $wikiName = Foswiki::Func::getWikiName();

  throw Foswiki::Contrib::JsonRpcContrib::Error(404, "Topic $web.$topic does not exist") 
    unless Foswiki::Func::topicExists($this->{baseWeb}, $this->{baseTopic});

  throw Foswiki::Contrib::JsonRpcContrib::Error(401, "Access denied")
    unless Foswiki::Func::checkAccessPermission("VIEW", $wikiName, undef, $web, $topic);

  throw Foswiki::Contrib::JsonRpcContrib::Error(401, "Access denied")
    unless Foswiki::Func::checkAccessPermission('COMMENT', $wikiName, undef, $topic, $web) ||
           Foswiki::Func::checkAccessPermission('CHANGE', $wikiName, undef, $topic, $web);

  my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);

  my $id = $request->param('comment_id') || '';
  my $comment = $meta->get('COMMENT', $id);

  throw Foswiki::Contrib::JsonRpcContrib::Error(1000, "Comment not found")
    unless $comment;

  # relocate replies by assigning them to the parent
  my $parentId = $comment->{ref} || '';
  my $parentComment = $meta->get('COMMENT', $parentId);
  my $parentName = $parentComment?$parentComment->{name}:'';

  foreach my $reply ($meta->find('COMMENT')) {
    next unless $reply->{ref} && $reply->{ref} eq $comment->{name};
    $reply->{ref} = $parentName;
  }

  # remove this comment
  $meta->remove('COMMENT', $id);

  Foswiki::Func::saveTopic($web, $topic, $meta, $text, {ignorepermissions=>1}) unless DRY;
  writeEvent("commentdelete", "state=($comment->{state}) title=".($comment->{title}||'')." text=".substr($comment->{text}, 0, 200)); 

  return;
}

###############################################################################
sub writeDebug {
  print STDERR "- MetaCommentPlugin - $_[0]\n" if DEBUG;
}

##############################################################################
sub isModerator {
  my ($wikiName, $web, $topic) = @_;
  
  $wikiName = Foswiki::Func::getWikiName()
    unless defined $wikiName;

  return 1 if Foswiki::Func::checkAccessPermission("MODERATE", $wikiName, undef, $topic, $web);
  return 0;
}

##############################################################################
sub METACOMMENTS {
  my ($this, $params, $topic, $web) = @_;

  my $context = Foswiki::Func::getContext();
  if ($context->{"preview"} || $context->{"save"} ||  $context->{"edit"}) {
    return;
  }

  Foswiki::Func::readTemplate("metacomments");

  # sanitize params
  $params->{topic} ||= $topic;
  $params->{web} ||= $web;
  my ($theWeb, $theTopic) = Foswiki::Func::normalizeWebTopicName($params->{web}, $params->{topic});
  $params->{topic} = $theTopic;
  $params->{web} = $theWeb;
  $params->{format} = '<h3>$title</h3>$text' 
    unless defined $params->{format};
  $params->{format} = Foswiki::Func::expandTemplate($params->{template})
    if defined $params->{template};
  $params->{subformat} = $params->{format}
    unless defined $params->{subformat};
  $params->{subformat} = Foswiki::Func::expandTemplate($params->{subtemplate})
    if defined $params->{subtemplate};
  unless (defined $params->{subheader}) {
    $params->{subheader} = "<div class='cmtSubComments'>";
    $params->{subfooter} = "</div>";
  }
  $params->{subfooter} ||= '';
  $params->{header} ||= '';
  $params->{footer} ||= '';
  $params->{separator} ||= '';
  $params->{ref} ||= '';
  $params->{skip} ||= 0;
  $params->{limit} ||= 0;
  $params->{moderation} ||= 'off';
  $params->{reverse} ||= 'off';
  $params->{sort} ||= 'name';
  $params->{singular} = 'One comment' 
    unless defined $params->{singular};
  $params->{plural} = '$count comments' 
    unless defined $params->{plural};
  $params->{mindate} = Foswiki::Time::parseTime($params->{mindate})
    if defined $params->{mindate} && $params->{mindate} !~ /^\d+$/;
  $params->{maxdate} = Foswiki::Time::parseTime($params->{maxdate}) 
    if defined $params->{maxdate} && $params->{mindate} !~ /^\d+$/;
  $params->{threaded} = 'off'
    unless defined $params->{threaded};
  $params->{isclosed} = ((Foswiki::Func::getPreferencesValue("COMMENTSTATE")||'open') eq 'closed')?1:0;

  # get all comments data
  my $comments = getComments($theWeb, $theTopic, $params);

  return '' unless $comments;
  my $count = scalar(keys %$comments);
  return '' unless $count;

  $params->{count} = ($count > 1)?$params->{plural}:$params->{singular};
  $params->{count} =~ s/\$count/$count/g;
  $params->{ismoderator} = isModerator(undef, $theWeb, $theTopic);

  # format the results
  my @topComments;
  if ($params->{threaded} eq 'on') {
    @topComments = grep {!$_->{ref}} values %$comments;
  } else {
    @topComments = values %$comments;
  }
  my @result = formatComments(\@topComments, $params);

  return 
    expandVariables($params->{header}, 
      count=>$params->{count},
      ismoderator=>$params->{ismoderator},
    ).
    join(expandVariables($params->{separator}), @result).
    expandVariables($params->{footer}, 
      count=>$params->{count},
      ismoderator=>$params->{ismoderator},
    );
}

##############################################################################
sub getComments {
  my ($web, $topic, $params) = @_;

  my $wikiName = Foswiki::Func::getWikiName();
  my $isModerator = isModerator($wikiName, $web, $topic);

  #writeDebug("called getComments");

  my @topics = ();
  if (defined $params->{search}) {
    @topics = getTopics($web, $params->{search}, $params);
  } else {
    return undef unless Foswiki::Func::checkAccessPermission('VIEW', $wikiName, undef, $topic, $web);
    push @topics, $topic;
  }

  my %comments = ();
  foreach my $thisTopic (@topics) {
    my ($meta) = Foswiki::Func::readTopic($web, $thisTopic);

    my @comments = $meta->find('COMMENT');
    foreach my $comment (@comments) {
      my $id = $comment->{name};
      #writeDebug("id=$id, moderation=$params->{moderation}, isModerator=$isModerator, author=$comment->{author}, wikiName=$wikiName, state=$comment->{state}, isclosed=$params->{isclosed}");
      next if $params->{author} && $comment->{author} !~ /$params->{author}/;
      next if $params->{mindate} && $comment->{date} < $params->{mindate};
      next if $params->{maxdate} && $comment->{date} > $params->{maxdate};
      next if $params->{id} && $id ne $params->{id};
      next if $params->{ref} && $params->{ref} ne $comment->{ref};
      next if $params->{state} && (!$comment->{state} || $comment->{state} !~ /^($params->{state})$/);
      next if $params->{moderation} eq 'on' && !($isModerator || $comment->{author} eq $wikiName) && (!$comment->{state} || $comment->{state} !~ /\bapproved\b/);
      next if $params->{moderation} eq 'on' && $params->{isclosed} && (!$comment->{state} || $comment->{state} !~ /\bapproved\b/);

      next if $params->{include} && !(
        $comment->{author} =~ /$params->{include}/ ||
        $comment->{title} =~ /$params->{include}/ ||
        $comment->{text} =~ /$params->{include}/
      );

      next if $params->{exclude} && (
        $comment->{author} =~ /$params->{exclude}/ ||
        $comment->{title} =~ /$params->{exclude}/ ||
        $comment->{text} =~ /$params->{exclude}/
      );

      $comment->{topic} = $thisTopic;
      $comment->{web} = $web;

      #writeDebug("adding $id");
      $comments{$thisTopic.'::'.$id} = $comment;
    }
  }

  # gather children
  if ($params->{threaded} && $params->{threaded} eq 'on') {
    while (my ($key, $cmt) = each %comments) {
      next unless $cmt->{ref};
      my $parent = $comments{$cmt->{topic}.'::'.$cmt->{ref}};
      if ($parent) {
        push @{$parent->{children}}, $cmt;
      } else {
        #writeDebug("parent $cmt->{ref} not found for $cmt->{name}");
        delete $comments{$key};
      }
    }
    # mark all reachable children and remove the unmarked
    while (my ($key, $cmt) = each %comments) {
      $cmt->{_tick} = 1 unless $cmt->{ref};
      next unless $cmt->{children};
      foreach my $child (@{$cmt->{children}}) {
        $child->{_tick} = 1;
      }
    }
    while (my ($key, $cmt) = each %comments) {
      next if $cmt->{_tick};
      #writeDebug("found unticked comment $cmt->{name}");
      delete $comments{$key};
    }
  }

  return \%comments;
}

##############################################################################
sub getTopics {
  if ($Foswiki::cfg{Plugins}{DBCachePlugin}{Enabled}) {
    require Foswiki::Plugins::DBCachePlugin;
    return getTopics_DBQUERY(@_);
  } else {
    return getTopics_SEARCH(@_);
  }
}

##############################################################################
sub getTopics_DBQUERY {
  my ($web, $where, $params) = @_;

  my $search = new Foswiki::Contrib::DBCacheContrib::Search($where);
  return unless $search;

  my $wikiName = Foswiki::Func::getWikiName();

  my $db = Foswiki::Plugins::DBCachePlugin::getDB($web);
  my @topicNames = $db->getKeys();
  my @selectedTopics = ();

  foreach my $topic (@topicNames) { # loop over all topics
    my $topicObj = $db->fastget($topic);
    next unless $search->matches($topicObj); # that match the query
    next unless Foswiki::Func::checkAccessPermission('VIEW', 
      $wikiName, undef, $topic, $web);
    my $commentDate = $topicObj->fastget("commentdate");
    next unless $commentDate;
    push @selectedTopics, $topic;
  }

  return @selectedTopics;
}

##############################################################################
sub getTopics_SEARCH {
  my ($web, $where, $params) = @_;

  $where .= ' and comment';

  #print STDERR "where=$where, web=$web\n";

  my $matches = Foswiki::Func::query($where, undef, { 
    web => $web,
    casesensitive => 0, 
    files_without_match => 1 
  });

  my @selectedTopics = ();
  while ($matches->hasNext) {
    my $topic = $matches->next;
    (undef, $topic) = Foswiki::Func::normalizeWebTopicName('', $topic);
    push @selectedTopics, $topic;
  }

  #print STDERR "topics=".join(', ', @selectedTopics)."\n";
  return @selectedTopics;
}

##############################################################################
sub formatComments {
  my ($comments, $params, $parentIndex, $seen) = @_;

  my $session = $Foswiki::Plugins::SESSION;

  $parentIndex ||= '';
  $seen ||= {};
  my @result = ();
  my $index = $params->{index} || 0;
  my @sortedComments;

  if ($params->{sort} eq 'name') {
    @sortedComments = sort {$a->{name} <=> $b->{name}} @$comments;
  } elsif ($params->{sort} eq 'date') {
    @sortedComments = sort {$a->{date} <=> $b->{date}} @$comments;
  } elsif ($params->{sort} eq 'modified') {
    @sortedComments = sort {$a->{modifed} <=> $b->{modified}} @$comments;
  } elsif ($params->{sort} eq 'author') {
    @sortedComments = sort {$a->{author} cmp $b->{author}} @$comments;
  }

  @sortedComments = reverse @sortedComments if $params->{reverse} eq 'on';
  my $count = scalar(@sortedComments);
  foreach my $comment (@sortedComments) {
    next if $seen->{$comment->{name}};

    $index++;
    next if $params->{skip} && $index <= $params->{skip};
    my $indexString = ($params->{reverse} eq 'on')?($count - $index +1):$index;
    $indexString = "$parentIndex.$indexString" if $parentIndex;

    # insert subcomments
    my $subComments = '';
    if ($params->{format} =~ /\$subcomments/ && $comment->{children}) {
      my $oldFormat = $params->{format};
      $params->{format} = $params->{subformat};
      $subComments = join(expandVariables($params->{separator}),
        formatComments($comment->{children}, $params, $indexString, $seen));
      $params->{format} = $oldFormat;
      if ($subComments) {
        $subComments =
          expandVariables($params->{subheader}, 
            count=>$params->{count}, 
            index=>$indexString,
            ismoderator=>$params->{ismoderator},
          ).$subComments.
          expandVariables($params->{subfooter}, 
            count=>$params->{count}, 
            ismoderator=>$params->{ismoderator},
            index=>$indexString)
      };
    }

    my $title = $comment->{title};

    my $summary = '';
    if ($params->{format} =~ /\$summary/) {
      $summary = substr($comment->{text}, 0, 100);
      $summary =~ s/^\s*\-\-\-\++//g; # don't remove heading, just strip tml
      $summary = $session->renderer->TML2PlainText($summary, undef, "showvar") . " ...";
      $summary =~ s/\n/<br \/>/g;
    }

    my $permlink = Foswiki::Func::getScriptUrl($comment->{web},
      $comment->{topic}, "view", "#"=>"comment".($comment->{name}||0));

    my $line = expandVariables($params->{format},
      author=>$comment->{author},
      state=>$comment->{state},
      count=>$params->{count},
      ismoderator=>$params->{ismoderator},
      timestamp=>$comment->{date} || 0,
      date=>Foswiki::Time::formatTime(($comment->{date}||0)),
      modified=>Foswiki::Time::formatTime(($comment->{modified}||0)),
      isodate=> Foswiki::Func::formatTime($comment->{modified} || $comment->{date}, 'iso', 'gmtime'),
      evenodd=>($index % 2)?'Odd':'Even',
      id=>($comment->{name}||0),
      index=>$indexString,
      ref=>($comment->{ref}||''),
      text=>$comment->{text},
      title=>$title,
      subcomments=>$subComments,
      topic=>$comment->{topic},
      web=>$comment->{web},
      summary=>$summary,
      permlink=>$permlink,
    );

    next unless $line;
    push @result, $line;
    last if $params->{limit} && $index >= $params->{limit};
  }

  return @result;
}

##############################################################################
sub getNewId {
  my $meta = shift;

  my @comments = $meta->find('COMMENT');
  my $maxId = 0;
  foreach my $comment (@comments) {
    my $id = int($comment->{name});
    $maxId = $id if $id > $maxId;
  }

  $maxId++;

  return "$maxId.".time();
}

##############################################################################
sub expandVariables {
  my ($text, %params) = @_;

  return '' unless $text;

  foreach my $key (keys %params) {
    my $val = $params{$key};
    $val = '' unless defined $val;
    $text =~ s/\$$key\b/$val/g;
  }

  $text =~ s/\$perce?nt/\%/go;
  $text =~ s/\$nop//go;
  $text =~ s/\$n/\n/go;
  $text =~ s/\$dollar/\$/go;

  return $text;
}

##############################################################################
sub writeEvent {
  return unless defined &Foswiki::Func::writeEvent;
  return Foswiki::Func::writeEvent(@_);
}

##############################################################################
sub indexTopicHandler {
  my ($this, $indexer, $doc, $web, $topic, $meta, $text) = @_;

  # delete all previous comments of this topic
  #$indexer->deleteByQuery("type:comment web:$web topic:$topic");

  my @comments = $meta->find('COMMENT');
  return unless @comments;


  foreach my $comment (@comments) {

    # set doc fields
    my $createDate = Foswiki::Func::formatTime($comment->{date}, 'iso', 'gmtime' );
    my $date = defined($comment->{modified})?Foswiki::Func::formatTime($comment->{modified}, 'iso', 'gmtime' ):$createDate;
    my $webtopic = "$web.$topic";
    $webtopic =~ s/\//./g;
    my $id = $webtopic.'#'.$comment->{name};
    my $url = Foswiki::Func::getScriptUrl($web, $topic, 'view', '#'=>'comment'.$comment->{name});
    my $title = $comment->{title};
    $title = substr $comment->{text}, 0, 20 unless $title;

    my $collection = $Foswiki::cfg{SolrPlugin}{DefaultCollection} || "wiki";
    my $language = Foswiki::Func::getPreferencesValue('CONTENT_LANGUAGE') || "en"; # SMELL: standardize

    # reindex this comment
    my $commentDoc = $indexer->newDocument();
    $commentDoc->add_fields(
      'id' => $id,
      'collection' => $collection,
      'language' => $language,
      'name' => $comment->{name},
      'type' => 'comment',
      'web' => $web,
      'topic' => $topic,
      'webtopic' => $webtopic,
      'author' => $comment->{author},
      'contributor' => $comment->{author},
      'date' => $date,
      'createdate' => $createDate,
      'title' => $title,
      'text' => $comment->{text},
      'url' => $url,
      'state' => ($comment->{state}||'null'),
      'container_id' => $web.'.'.$topic,
      'container_url' => Foswiki::Func::getViewUrl($web, $topic),
      'container_title' => $indexer->getTopicTitle($web, $topic, $meta),
    );
    $doc->add_fields('catchall' => $title);
    $doc->add_fields('catchall' => $comment->{text});
    $doc->add_fields('contributor' => $comment->{author});

    # add the document to the index
    try {
      $indexer->add($commentDoc);
      $indexer->commit();
    } catch Error::Simple with {
      my $e = shift;
      $indexer->log("ERROR: ".$e->{-text});
    };
  }
}

1;
