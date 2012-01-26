# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2011 Michael Daum http://michaeldaumconsulting.com
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
package Foswiki::Plugins::BlogPlugin::Converter;

use strict;
use warnings;
use Error qw(:try);
use Foswiki::Func ();
use Foswiki::Meta ();
use Foswiki::Form ();

###############################################################################
sub new {
  my $class = shift;

  return bless({@_}, $class);
}

###############################################################################
sub convert {
  my ($this, $session, $subject, $verb, $response) = @_;

  my $request = $session->{request};
  my $sourceWeb = $request->param("source");

  $this->{session} = $session || $Foswiki::Plugins::SESSION;

  throw Error::Simple("no source web specified") 
    unless $sourceWeb;

  throw Error::Simple("no such web $sourceWeb") 
    unless Foswiki::Func::webExists($sourceWeb);

  $this->{sourceWeb} = $sourceWeb;

  my $targetWeb = $request->param("target");
  throw Error::Simple("no target web specified")
    unless $targetWeb;

  throw Error::Simple("target web must be different from source web")
    if $sourceWeb eq $targetWeb;

  my $doOverride = Foswiki::Func::isTrue($request->param("override"), 0);

  throw Error::Simple("target web $targetWeb already exists")
    if !$doOverride && Foswiki::Func::webExists($targetWeb);

  $this->{targetWeb} = $targetWeb;

  my $templateWeb = $request->param("template") || '_BlogTemplate';
  throw Error::Simple("tempalte web $templateWeb does not exists")
    unless Foswiki::Func::webExists($templateWeb);

  $this->{templateWeb} = $templateWeb;

  #print STDERR "### sourceWeb=$sourceWeb\n";
  #print STDERR "### targetWeb=$targetWeb\n";
  
  # 1. create the target web
  $this->createTargetWeb();

  # 2. convert SubjectCategory topics
  $this->convertCategories;

  # 3. convert BlogEntry topics
  $this->convertBlogEntries;

  # 4. convert BlogPage topics
#  $this->convertBlogPages;

  # 5. copy the BlogImages topic
  $this->copyBlogImages;

  # 6. merge BlogComment topics
  $this->convertBlogComments
}

###############################################################################
sub createTargetWeb {
  my $this = shift;

  my $webSummary = 
    Foswiki::Func::getPreferencesValue("SITEMAPUSETO", $this->{sourceWeb}) ||
    Foswiki::Func::getPreferencesValue("SITEMAPWHAT", $this->{sourceWeb}) ||
    Foswiki::Func::getPreferencesValue("WEBSUMMARY", $this->{sourceWeb}) || '';

  my $targetWebObj = new Foswiki::Meta($this->{session}, $this->{targetWeb});
  $targetWebObj->populateNewWeb($this->{templateWeb},
    {
      WEBSUMMARY => $webSummary,
      WEBBGCOLOR => Foswiki::Func::getPreferencesValue("WEBBGCOLOR", $this->{sourceWeb}),
      BLOGIMAGES => Foswiki::Func::getPreferencesValue("BLOGIMAGES", $this->{sourceWeb}) || '%PUBURLPATH%/%WEB%/BlogImages',
      IMAGEALBUM => Foswiki::Func::getPreferencesValue("IMAGEALBUM", $this->{sourceWeb}) || '%WEB%/BlogImages',
      NOAUTOLINK => Foswiki::Func::getPreferencesValue("NOAUTOLINK", $this->{sourceWeb}) || 'on',
      SITEMAPLIST => Foswiki::Func::getPreferencesValue("SITEMAPLIST", $this->{sourceWeb}) || 'on',
    }
  );
}

###############################################################################
sub convertCategories {
  my $this = shift;

  # search all SubjectCategory topics in the source web
  my $matches = Foswiki::Func::query('TopicType=~".*SubjectCategory.*"', undef, {
    type => 'query',
    web => $this->{sourceWeb},
  });

  my $count = 0;
  while ($matches->hasNext) {
    my $webTopic = $matches->next;
    my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($this->{sourceWeb}, $webTopic);
    $this->convertCategory($web, $topic);
    $count++;
    print STDERR "### $count: $web.$topic\n";
  }

  print STDERR "### converted $count categories\n";
}

###############################################################################
sub convertCategory {
  my ($this, $web, $topic) = @_;

  my ($oldTopic, $text) = Foswiki::Func::readTopic($web, $topic);


  my $newTopicTitle = $topic;
  $newTopicTitle =~ s/^(.+)(Category)?$/$1/g;
  my $newTopicName = $newTopicTitle . 'Category';

  # remember mapping of old category to new name
  $this->{renamedCategories}{$topic} = $newTopicName;

  my $newText = '%DBCALL{"Applications.ClassificationApp.RenderCategory"}%';
  my $newTopic = new Foswiki::Meta($this->{session}, $this->{targetWeb}, $newTopicName, $newText);

  $newTopic->putKeyed('FORM', { name => "Applications.ClassificationApp.Category" } );

  my @fields = ();

  push @fields, {
    name => "TopicType",
    title => "TopicType",
    value => "Category, CategorizedTopic",
  };

  my $topicTitle =  $oldTopic->get("FIELD", "TopicTitle");
  $topicTitle = defined( $topicTitle)?$topicTitle->{value}:$newTopicTitle;

  push @fields, {
    name => "TopicTitle",
    title => "<nop>TopicTitle",
    value => $topicTitle,
  };

  push @fields, {
    name => "Summary",
    title => "Summary",
    value => $oldTopic->get("FIELD", "Summary")->{value},
  };

  $newTopic->putAll("FIELD", @fields);
  $newTopic->save;
}

###############################################################################
sub copyBlogImages {
  my $this = shift;

  return unless Foswiki::Func::topicExists($this->{sourceWeb}, "BlogImages");
  my $sourceObj = new Foswiki::Meta($this->{session}, $this->{sourceWeb}, "BlogImages");
  my $targetObj = new Foswiki::Meta($this->{session}, $this->{targetWeb}, "BlogImages", "---+!! %TOPIC%\n");
  $targetObj->save;

  print STDERR "### copying BlogImages from $this->{sourceWeb} to $this->{targetWeb}\n";
  $sourceObj->load();

  foreach my $attachment ($sourceObj->find('FILEATTACHMENT')) {
    print STDERR "### copying attachment $attachment->{name}\n";
    delete $attachment->{autoattached};
    $attachment->{attr} = '';
    $sourceObj->copyAttachment($attachment->{name}, $targetObj);
  }

}

###############################################################################
sub convertBlogComments {
  my $this = shift;

  my $matches = Foswiki::Func::query('TopicType=~".*BlogComment.*"', undef, {
    type => 'query',
    web => $this->{sourceWeb},
  });

  my $count = 0;
  my @comments = ();
  while ($matches->hasNext) {
    my $webTopic = $matches->next;
    my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($this->{sourceWeb}, $webTopic);
    push @comments, {
      web => $web,
      topic => $topic,
    };
    my ($comment) = Foswiki::Func::readTopic($web, $topic);
    my $number = $comment->get('FIELD', 'Nr');
    if ($number) {
      $this->{nameOfComment}{$topic} = convertCommentNumberToName($number->{value});
    }
  }

  foreach my $comment (@comments) {
    my $web = $comment->{web};
    my $topic = $comment->{topic};
    if ($this->convertBlogComment($web, $topic)) {
      $count++;
      print STDERR "### $count: $web.$topic\n";
    }
  }

  print STDERR "### converted $count blog comments\n";
}

###############################################################################
sub convertBlogComment {
  my ($this, $web, $topic) = @_;

  my ($comment) = Foswiki::Func::readTopic($web, $topic);
  my $baseRef = $comment->get('FIELD', 'BaseRef');

  return unless $baseRef;
  $baseRef = $baseRef->{value};

  #return if $baseRef ne "TestBlogEntry0";

  #### FROM
  # | TopicType | label | 1 | BlogComment | classifies this as a blog comment |  |
  # | <nop>TopicTitle | text | 75 | | title of this topic | |
  # | Name | text | 78 | | your name | M |
  # | Text | textarea | 80x10 | | your comment | M |
  # | BlogRef | label | 1 | | refering BlogEntry or BlogComment | |
  # | BaseRef | label | 1 | | basic BlogEntry where a thread started | |
  # | Nr | label | 1 | | running comment number |  |

  ### TO
  # %META:COMMENT{name="4.1304698367" author="AdminUser" date="1304698367" modified="1304698367" ref="" state="new, unapproved" text="Amet egestas ultrices, turpis, vut aenean, mattis facilisis natoque, magna, hac integer ac tincidunt! Mauris dis adipiscing, cras, lorem, phasellus dapibus, ridiculus scelerisque natoque cras penatibus? Adipiscing cras. Enim turpis rhoncus diam ut scelerisque porta nisi et pid mattis sit velit duis. Rhoncus montes, natoque elit eros dapibus natoque lorem turpis, vut aliquet urna, nisi augue, dictumst non cras pulvinar, platea hac enim nec, elit sit! Phasellus risus, sagittis purus nec et! Enim sed facilisis velit? Rhoncus! Auctor, penatibus ultrices vut hac mus et, eu enim enim cursus scelerisque mauris scelerisque placerat lectus magna porttitor elementum, parturient! Duis pulvinar turpis nec! Aenean sed nascetur? Velit, eu vut enim? Aliquam egestas etiam scelerisque, rhoncus mus, lundium dapibus eu cum odio dis." title=""}%
  #print STDERR "### ...baseRef=$baseRef\n";

  unless (Foswiki::Func::topicExists($this->{targetWeb}, $baseRef)) {
    print STDERR "ERROR: can't find topic for baseRef $baseRef\n";
    return;
  }

  my ($baseMeta) = Foswiki::Func::readTopic($this->{targetWeb}, $baseRef);

  my $name = $comment->get('FIELD', 'Nr');
  $name = convertCommentNumberToName($name?$name->{value}:'0');

  my $title = $comment->get('FIELD', 'TopicTitle');
  $title = $title?$title->{value}:"";

  my $text = $comment->get('FIELD', 'Text');
  $text = $text?$text->{value}:"";
  $text =~ s/\%CITEBLOG{\"?(.*?)\"}\%/[[$1]]/g;

  my ($date, $revAuthor) = $comment->getRevisionInfo();

  my $author => $comment->get('FIELD', 'Name');
  $author = Foswiki::Func::getWikiName($author?$author->{value}:$revAuthor);
  
  $author = 'WikiGuest' if $author eq 'TWikiGuest';
  $author = 'AdminUser' if $author eq 'TWikiAdmin';

  my $ref = $comment->get('FIELD', 'BlogRef');
  $ref = $ref?$ref->{value}:'';

  $ref = '' if $ref eq $topic;
  if ($this->{nameOfComment}{$ref}) {
    $ref = $this->{nameOfComment}{$ref};
  } else {
    $ref = '';
  }

  $baseMeta->putKeyed('COMMENT', {
    name => $name,
    ref => $ref,
    author => $author,
    date => $date,
    text => $text,
    title => $title,
    state => "approved", #default
  });

  $baseMeta->save();

  return 1; # success
}

###############################################################################
sub convertCommentNumberToName {
  my $number = shift;

  # name must be numeric, at least a proper float with only one decimal point
  my @parts = split(/\./, $number);
  my $name = shift(@parts);
  $name .= "." . join("", @parts) if @parts;

  return $name;
}

###############################################################################
sub convertBlogEntries {
  my $this = shift;

  # search all BlogEntry topics in the source web
  my $matches = Foswiki::Func::query('TopicType=~".*BlogEntry.*"', undef, {
    type => 'query',
    web => $this->{sourceWeb},
  });

  my $count = 0;
  while ($matches->hasNext) {
    my $webTopic = $matches->next;
    my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($this->{sourceWeb}, $webTopic);
    $this->convertBlogEntry($web, $topic);
    $count++;
    print STDERR "### $count: $web.$topic\n";
  }

  print STDERR "### converted $count blog entries\n";
}

###############################################################################
sub convertBlogEntry {
  my ($this, $web, $topic) = @_;

  my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);

  my $newText = $meta->get("FIELD", "Teaser")->{value} . "\n\n" . $meta->get("FIELD", "Text")->{value};
  $newText =~ s/\r//g;
  $newText =~ s/\bTWiki\./System\./g;
  $newText =~ s/\%CITEBLOG{\"?(.*?)\"}\%/[[$1]]/g;

  my $newTopic = new Foswiki::Meta($this->{session}, $this->{targetWeb}, $topic, $newText);
  $newTopic->putKeyed('FORM', { name => "Applications.BlogApp.BlogEntry" } );

  my @fields = ();

  push @fields, {
    name => "TopicType",
    title => "TopicType",
    value => "BlogEntry, ClassifiedTopic, CategorizedTopic, TaggedTopic",
  };
  
  push @fields, {
    name => "TopicTitle",
    title => "<nop>TopicTitle",
    value => $meta->get("FIELD", "TopicTitle")->{value},
  };

  my $tags = join(", ", split(/[\s,]+/, $meta->get("FIELD", "BlogTag")->{value}));
  print STDERR "### ... tags=$tags\n";

  push @fields, {
    name => "Tag",
    title => "Tag",
    value => $tags,
  };

  my $categories = join(", ", map($_ = (defined $this->{renamedCategories}{$_})?$this->{renamedCategories}{$_}:$_, split(/\s*,\s*/, $meta->get("FIELD", "SubjectCategory")->{value})));

  print STDERR "### ... categories = $categories\n";

  push @fields, {
    name => "Category",
    title => "Category",
    value => $categories,
  };

  my $blogState = $meta->get("FIELD", "State")->{value};
  push @fields, {
    name => "State",
    title => "State",
    value => $blogState,
  };

  if ($blogState ne 'published') {
    $newTopic->putAll("PREFERENCE", 
      { name => "ALLOWTOPICVIEW", title => "ALLOWTOPICVIEW", type => "Set", value => "BlogAuthorGroup" },
      { name => "PERMSET_VIEW", title => "PERMSET_VIEW", type => "Local", value => "details" },
      { name => "PERMSET_VIEW_DETAILS", title => "PERMSET_VIEW_DETAILS", type => "Local", value => "BlogAuthorGroup" },
    );
  }

  $newTopic->putKeyed("PREFERENCE", 
      { name => "DISPLAYCOMMENTS", title => "DISPLAYCOMMENTS", type => "Local", value => "on" }
  );

  $newTopic->putAll("FIELD", @fields);

  my $author = $meta->get("FIELD", "BlogAuthor")->{value};
  $author =~ s/^.*\.//g; # strip web
  $author = Foswiki::Func::getCanonicalUserID($author) || $author;

  #print STDERR "author=$author\n";

  my $date = $meta->get("FIELD", "Date")->{value};
  $date = Foswiki::Time::parseTime($date);

  # save it once, and then ...
  $newTopic->save(forcedate=>$date, author=>$author);

  # ... force a second revision to freeze the create time and author
  $newTopic->save(forcedate=>$date, author=>$author, forcenewrevision=>1);

  foreach my $attachment ($meta->find('FILEATTACHMENT')) {
    print STDERR "### copying attachment $attachment->{name}\n";
    $meta->copyAttachment($attachment->{name}, $newTopic, user => $author);
  }
}

1;
