# Plugin for mediawiki2foswiki
#
# Copyright (C) 2007-2012 Michael Daum http://michaeldaumconsulting.com

package Foswiki::Contrib::MediaWikiToFoswikiContrib::FoswikiPedia;
use strict;
use utf8;

use vars qw(%seenCategories 
  $topicFormTemplate $categoryTemplate 
  %knownUsers %unknownUsers
  $wikipediaLink
);

## add known users here, 
%knownUsers = (
  # example:
  #  'AR-ADMIN'=>'MelanieGrifith',
  #  'Tim'=>'TimCurry',
);

$wikipediaLink = 'http://en.wikipedia.org/wiki';

# variables:
#   * %cat%
#   * %summary%
#   * %title%
$topicFormTemplate = <<'HERE';
%META:FORM{name="Applications.ClassificationApp.ClassifiedTopic"}%
%META:FIELD{name="TopicType" attributes="" title="TopicType" value="ClassifiedTopic, CategorizedTopic, TaggedTopic"}%
%META:FIELD{name="TopicTitle" attributes="" title="<nop>TopicTitle" value="%title%"}%
%META:FIELD{name="Summary" attributes="" title="Summary" value="%summary%"}%
%META:FIELD{name="Tag" attributes="" title="Tag" value=""}%
%META:FIELD{name="Category" attributes="" title="Category" value="%cats%"}%
HERE

# variables:
#   * %date%
#   * %author%
#   * %parent%
#   * %title%
#   * %summary%
#   * %categories%
#   * %text%
$categoryTemplate = <<'HERE';
%META:TOPICPARENT{name="%parent%"}%
%DBCALL{"Applications.ClassificationApp.RenderCategory"}%

%META:FORM{name="Applications.ClassificationApp.Category"}%
%META:FIELD{name="TopicType" attributes="" title="TopicType" value="Category, CategorizedTopic"}%
%META:FIELD{name="TopicTitle" attributes="" title="Title" value="%title%"}%
%META:FIELD{name="Summary" attributes="" title="Summary" value="%summary%"}%
%META:FIELD{name="Category" attributes="" title="Category" value="%categories%"}%
%META:FIELD{name="Usage" attributes="" title="Usage" value="ALL"}%
HERE


##############################################################################
sub registerHandlers {
  my $converter = shift;

  #$converter->writeDebug("registering callbacks");
  #$converter->registerHandler('init', \&handleInit);
  $converter->registerHandler('before', \&handleBefore);
  $converter->registerHandler('title', \&handleTitle);
  $converter->registerHandler('after', \&handleAfter);
  $converter->registerHandler('final', \&handleFinal);
}

##############################################################################
# called after the converter has been constructed
sub handleInit {
  my $converter = shift;
}

##############################################################################
# called when the title of a mediawiki is converted to a TopicTitle 
sub handleTitle {
  my $converter = shift;
  my $page = shift;

  #$converter->writeDebug("called handleTitle");
  #$converter->writeDebug("before, title=$_[0]");

  # remove umlaute
  $_[0] =~ s/ä/ae/go;
  $_[0] =~ s/ö/oe/go;
  $_[0] =~ s/ü/ue/go;
  $_[0] =~ s/Ä/Ae/go;
  $_[0] =~ s/Ö/Oe/go;
  $_[0] =~ s/Ü/Ue/go;
  $_[0] =~ s/ß/ss/go;

  #$converter->writeDebug("after, title=$_[0]");
}

##############################################################################
# called before one page is converted
sub handleBefore {
  my $converter = shift;
  my $page = shift;
  #my $text = shift; # use $_[0];

  #$converter->writeDebug("called handleBefore");

  # map authors
  my $name = $page->username || 'UnknownUser';
  if ($knownUsers{$name}) {
    $page->{DATA}{username} = $knownUsers{$name};
    $_[0] =~ s/Benutzer:$name/Benutzer:$knownUsers{$name}/g;
  } else {
    unless ($unknownUsers{$name}) {
      $unknownUsers{$name} = $name;
      #$converter->writeWarning("unknown user $name");
    }
  }
  
  # remove internal category links
  $_[0] =~ s/\[\[$converter->{language}{Category}:.+?\]\]//g;
  $_[0] =~ s/\[\[$Foswiki::Contrib::MediaWikiToFoswikiContrib::Converter::language{en}{Category}:.+?\]\]//g;

  # own image handler
  $_[0] =~ s/\[\[$converter->{language}{Image}:(.+?)\]\]/$converter->handleImage($page, $1)/ge;
  $_[0] =~ s/\[\[$Foswiki::Contrib::MediaWikiToFoswikiContrib::Converter::language{en}{Image}:(.+?)\]\]/$converter->handleImage($page, $1)/ge;
}

##############################################################################
sub handleImage {
  my ($this, $page, $text) = @_;

  $this->writeDebug("called handleImage($text)");

  my $result = '';
  my $args = '';
  if ($text =~ /^(.*?)\|(.*)$/) {
    $text = $1;
    $args = $2;
  }
  my $key = md5_hex($text);
  my $file = $this->{images}.'/'.substr($key,0,1).'/'.substr($key,0,2).'/'.$text;

  #$file = ucfirst($file);
  #$file =~ s/^\s+//g;
  #$file =~ s/\s+$//g;
  #$file =~ s/ +/_/g;

  # recursive call for the caption
  if ($args) {
    $this->convertMarkup($page, 0, $args);
    $args =~ s/"/\\"/go;
    $args =~ s/%/\$percnt/go;
    $result = "\%IMAGE{\"$file|$args\"}%";
  } else {
    $result = "\%IMAGE{\"$file\"}%";
  }

  $this->writeDebug("result = $result");

  return $result;
}

##############################################################################
# called after a page has been converted to a wiki topic
sub handleAfter {
  my $converter = shift;
  my $page = shift;
  #my $text = shift; # use $_[0];


  my $pageTitle = join('.',$converter->getTitle($page));

#print STDERR "DEBUG: postprocessing $pageTitle\n";

  #$converter->writeDebug("called handleAfter");
  my $catNames = '';
  my $topicParent = '';
  my $categories = $page->categories;
  if ($categories) {

    # get category names
    my @catNames;
    foreach my $cat (@$categories) {
      my $catName = $converter->getCategoryName($cat);
      $seenCategories{$catName} = 1;
      push @catNames, $catName;
    }
    $catNames = join(",", sort @catNames);

    # find a better topicparent
    foreach my $cat (sort @$categories) {
      my $catName = $converter->getCategoryName($cat);
      $topicParent = $catName;
    }
  } else {
    #print STDERR "no categories at $pageTitle\n";
  }

  # move h1 to title
  my $title = '';
  if ($_[0] =~ s/^\s*---\++(?:!!)?\s*(.*?)\s*$//m) {
    $title = $1;
    $title =~ s/\[\[.*?\]\[(.*)\]\]/$1/g;
  }

  # summary
  my $summary = ''; # TODO

  # encode the formfield values
  my $form = $topicFormTemplate;
  $form =~ s/%cats%/$catNames/g;
  $form =~ s/%title%/$title/g;
  $form =~ s/%summary%/$summary/g;
  $_[0] .= "\n".$form;

  # add backlink to origin
  if (0) {
    my $mwTitle = $page->title;
    $_[0] = 
      '<div style="float:right;margin:10px">'.
      "([[$wikipediaLink/$mwTitle][WikiPedia]])".
      '</div>'."\n".
      '%STARTINCLUDE%'.
      $_[0];
  }

  # add topic parent
  $_[0] = "%META:TOPICPARENT{name=\"$topicParent\"}%\n".$_[0];

  # bit of cleanup extensive <br/>-ing
  $_[0] =~ s/(<br *\/?>)+/$1/go; # repeated br's
  $_[0] =~ s/^\s*<br *\/?>\s*$//gom; # br on a single line

}

##############################################################################
# called after all pages have been converted
sub handleFinal {
  my $converter = shift;

  #$converter->writeDebug("called handleFinal");

  # check categories seen in topics
  foreach my $catName (keys %seenCategories) {
    if (!defined($converter->{categories}{$catName})) {
      $converter->writeWarning("seen $catName ... but not defined ... creating it");
      my $cat = {
        title=>$catName,
        web=>$converter->{targetWeb},
        topic=>$catName,
      };
      $converter->{categories}{$catName} = $cat;
    }
  }
  

  foreach my $cat (values %{$converter->{categories}}) {
    createCategory($converter, $cat);
  }

}

##############################################################################
sub createCategory {
  my ($converter, $cat) = @_;


  # get date and author
  my $date;
  my $author;
  if ($cat->{page}) {
    $date = Foswiki::Time::parseTime($cat->{page}->timestamp);
    $author = $cat->{page}->username || 'UnknownUser';
  } else {
    $date = time();
    $author = 'UnknownUser';
  }
  $author = $knownUsers{$author} if $knownUsers{$author};

  # get category and topic parent
  my $categories = '';
  my $topicParent = '';
  if ($cat->{categories}) {
    $categories = join(',', @{$cat->{categories}});
    $topicParent = @{$cat->{categories}}[0] || '';
  }
  $categories ||= 'TopCategory';

  # get summary
  my $summary = $cat->{summary} || '';
  $summary = $converter->fromUtf8($summary);
  $summary = $converter->toUtf8($summary);
  $summary =~ s/^\s*==\s*(.*?)\s*==\s*$/$1/m;
  $summary =~ s/\<br\>\s*$//g;
  $summary =~ s/:\s*$//g;

  # get title
  my $title = $cat->{title} || $cat->{topic};
  $title = $converter->fromUtf8($title);
  $title = $converter->toUtf8($title);
  $title =~ s/Category$//;

  # get text
  my $text = $cat->{text} || '';

  # insert it into the template
  my $template = $categoryTemplate;
  $template =~ s/%parent%/$topicParent/g;
  $template =~ s/%date%/$date/g;
  $template =~ s/%author%/$author/g;
  $template =~ s/%title%/$title/g;
  $template =~ s/%summary%/$summary/g;
  $template =~ s/%categories%/$categories/g;
  $template =~ s/%text%/$text/g;

  # allow view access to all
  $template .= '%META:PREFERENCE{name="DENYTOPICVIEW" title="DENYTOPICVIEW" type="Set" value=""}%'."\n"
    if $cat->{topic} eq 'PublicCategory';

  # save it
  $converter->saveTopic($cat->{page}, $template, $converter->{targetWeb}, $cat->{topic});

}

1;
