# Copyright (C) 2006-2012 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Contrib::MediaWikiToFoswikiContrib::Converter;

use strict;
use vars qw(%language $attachmentTemplate
  $translationToken0 $translationToken1 $translationToken2);

use utf8;
use Encode ();

BEGIN {
  %language = (
    en => {
      Image=>'Image',
      Media=>'Media',
      Template=>'Template',
      MainPage=>'Main Page',
      Category=>'Category',
      Help=>'Help',
      Discussion=>'Discussion',
    },
    de => {
      Image=>'Bild',
      Media=>'Media',
      Template=>'Vorlage',
      MainPage=>'Hauptseite',
      Category=>'Kategorie',
      Help=>'Hilfe',
      Discussion=>'Diskussion',
    },
  );
}

use Foswiki::Time;
use Digest::MD5 qw(md5_hex);
use File::Copy;
use Parse::MediaWikiDump;
use Carp;

$SIG{__DIE__} = \&Carp::confess;
$Carp::Verbose = 3;

# global vars
$translationToken0 = "\0";
$translationToken1 = "\1";
$translationToken2 = "\2";
$attachmentTemplate = '%META:FILEATTACHMENT{name="%file%" attachment="%file%" attr="" comment="%comment%" date="%date%" path="%file%" size="%size%" stream="%file%" user="%user%" version="1"}%';

##############################################################################
sub new {
  my $class = shift;

  my $this = {
    debug => 0,
    fileName => '', # stdin
    quiet => 0,
    maxPages=> '',
    targetWeb => 'MediaWiki',
    warning=> 1,
    excludePattern=>'',
    includePattern=>'',
    matchPattern=> '',
    catPattern=> '',
    namespace=>'',
    topicMapString=>'',
    webMapString=>'',
    language=>'en',
    images=>'',
    defaultWeb=>'_default',
    plugin=>'',
    @_
  };
  $this->{fileName} = '' if $this->{fileName} eq '-';
  $this->{seenPage} = {};
  $this->{templates} = {};
  $this->{namespaces} = {};
  $this->{externalLinkCounter} = 0;
  $this->{language} = $language{$this->{language}};
  $this->{genTOC} = {};
  $this->{callbacks} = {};
  $this->{categories} = {};
  $this->{titleCache} = {};
  #$this->{session} = new Foswiki;

  $this = bless($this, $class);

  # register plugin
  if ($this->{plugin}) {
    eval "use $this->{plugin};";
    die "error reading $this->{plugin}: $@" if $@;
    my $sub = $this->{plugin}.'::registerHandlers';
    no strict 'refs';
    &{$sub}($this);
    use strict 'refs';
  }

  # open dump
  if ($this->{fileName}) {
    die "ERROR: file '$this->{fileName}' not found" unless -f $this->{fileName};
    $this->writeDebug("opening $this->{fileName}");
    $this->{pages} = Parse::MediaWikiDump::Pages->new($this->{fileName});
  } else {
    $this->writeDebug("reading from STDIN");
    $this->{pages} = Parse::MediaWikiDump::Pages->new(\*STDIN);
  }

  # read known namespaces
  foreach my $namespace (@{$this->{pages}->namespaces}) {
    $this->{namespaces}{$namespace->[1]} = 1; #$namespace->[0];
  }
  # add intrinsic namespaces
  foreach my $lang ('bs', 'da', 'de', 'el', 'es', 'fr', 'gl', 'hr', 'it',
    'lt', 'hu', 'nl', 'ja', 'no', 'pl', 'pt', 'sq', 'simple', 'sr', 'fi',
    'sv', 'th', 'zh', 'tr', 'eo', 'he') {
    $this->{namespaces}{$lang} = 1;
  }


  # create maps
  foreach my $map (split(',', $this->{topicMapString})) {
    if ($map =~ /^(.*)=(.*)$/) {
      $this->{topicMap}{$1} = $2;
      #$this->writeDebug("mapping topic '$1' to '$2'");
    }
  }
  foreach my $map (split(',', $this->{webMapString})) {
    if ($map =~ /^(.*)=(.*)$/) {
      $this->{webMap}{$1} = $2;
    }
  }

  # create target web
  $this->createWeb($this->{targetWeb});

  # call init handler
  $this->execHandler('init');

  return $this;
}

##############################################################################
# known handlers:
#   * init($this): called in class constructor
#   * before($this, $page, $text): called before converting one page
#   * title($this, $page, $title): called when converting a page title
#   * afer($this, $page, $text): called after converting, before saving
#   * final($this): called before ending
#   * category($this, $page, $category): called when finding a category
#
# '$this' is a pointer to the Converter object
# '$page' is the pointer to the Page object, see manual Parse::MediaWikiDump
# '$text' is the text to be converted
sub registerHandler {
  my ($this, $name, $proc) = @_;

  push (@{$this->{callbacks}{$name}}, $proc);
}

##############################################################################
sub execHandler {
  my $this = shift;
  my $name = shift;

  foreach my $handler (@{$this->{callbacks}{$name}}) {
    &{$handler}($this, @_);
  }
}

##############################################################################
sub createWeb {
  my ($this, $webName) = @_;

  # create parent webs first
  $webName =~ s/\./\//go;
  my @parentWebs = split(/\//, $webName);
  $webName = pop @parentWebs;
  my $parentWeb = '';
  foreach my $web (@parentWebs) {
    $parentWeb .= "/$web";
    my $parentWebDir = $Foswiki::cfg{DataDir}.$parentWeb;
    unless (-d $parentWebDir) {
      $this->createWeb($parentWeb);
    }
  }

  # create data dir
  my $dataDir = $Foswiki::cfg{DataDir}.$parentWeb.'/'.$webName;
  unless (-d $dataDir) {
    if ($this->{dry}) {
      #$this->writeDebug("would create directory $dataDir");
    } else {
      mkdir $dataDir or die "can't create $dataDir: $!";
    }
  }

  # create pub dir
  my $pubDir = $Foswiki::cfg{PubDir}.'/'.$parentWeb.'/'.$webName;
  unless (-d $pubDir) {
    if ($this->{dry}) {
      #$this->writeDebug("would create directory $pubDir");
    } else {
      mkdir $pubDir or die "can't create $pubDir: $!";
    }
  }

  my $defaultWeb = $Foswiki::cfg{DataDir}.'/'.$this->{defaultWeb};
  opendir (DIR,$defaultWeb) or die "can't open default web $defaultWeb: $!"; 
  my @defaultTopics = grep { /\.txt$/ && ! -f "$dataDir/$_" } readdir(DIR);
  closedir DIR;
  foreach my $source (@defaultTopics) {
    my $target = $dataDir.'/'.$source;
    $source = $defaultWeb.'/'.$source;
    unless ($this->{dry}) {
      #$this->writeDebug("copying $source to $target");
      copy($source, $target) or die "can't copy $source to $target: $!";
    } else {
      #$this->writeDebug("would copy $source to $target");
    }
  }
}

##############################################################################
sub writeInfo {
  my $this = shift;

  my $pages = $this->{pages};
  $this->writeOut("sitename: ".$pages->sitename);
  $this->writeOut("namespaces:\n".join("\n", sort keys %{$this->{namespaces}}));
  $this->writeOut("base: ".$pages->base);
  $this->writeOut("case: ".$pages->case);
  #$this->writeOut("size: ".$pages->size);
}


##############################################################################
sub writeOut {
  my $this = shift;
  print $_[0]."\n" unless $this->{quiet};
}

##############################################################################
sub writeDebug {
  my $this = shift;
  print STDERR 'DEBUG: '.$_[0]."\n" if $this->{debug};
}

##############################################################################
sub writeWarning {
  my $this = shift;
  print STDERR 'WARNING: '.$_[0]."\n" if $this->{warning};
}

##############################################################################
# entry to this module
sub convert {
  my $this = shift;
                              
  # loop over all pages
  my $i = 1;
  while(defined(my $page = $this->{pages}->next)) {
    my $mwTitle = $page->title;

    if ($page->redirect) {
      #$this->writeDebug("skipping redirect");
      next;
    }

    # handle category topics
    if ($mwTitle =~ /^$this->{language}{Category}/) {
      $this->handleCategory($page);
      next;
    }

    # try en as a default language
    if ($mwTitle =~ /^$language{en}{Category}/) {
      $this->handleCategory($page);
      next;
    }

    my $isAllowed = 0;

    if ($this->{includePattern} && $mwTitle =~ /$this->{includePattern}/) {
      $isAllowed = 1;
    }

    if ($this->{excludePattern} && $mwTitle =~ /$this->{excludePattern}/) {
      #$this->writeDebug("disallowed title '$mwTitle'");
      next;
    }

    if (!$isAllowed && $this->{namespace}) {
      my $namespace = $page->namespace || '';
      if ($namespace eq $this->{namespace}) {
        $this->writeDebug("allowed namespace '$namespace'");
	$isAllowed = 1;
      }
    }
    my $text = $this->getPageText($page);
    if (!$isAllowed && $this->{matchPattern}) {
      if ($text =~ /$this->{matchPattern}/) {
        $this->writeDebug("allowed text");
	$isAllowed = 1;
      }
    }

    if (!$isAllowed && $this->{catPattern}) {
      my $categories = $page->categories;
      if ($categories) {
        $categories = join(',', sort(@$categories));
        if ($categories =~ /$this->{catPattern}/) {
        $this->writeDebug("allowed category '$categories'");
          $isAllowed = 1;
        }
      }
    }

    if (!$this->{includePattern} &&
        !$this->{excludePattern} &&
        !$this->{catPattern} &&
        !$this->{matchPatter}) {
      $this->writeDebug("allowed by default rule");
      $isAllowed = 1;
    }
    unless ($isAllowed) {
      #print STDERR "skipping '$mwTitle'                           \r"
      #  if $this->{debug};
      next;
    }

    my ($twWeb, $twTopic) = $this->getTitle($page);
    my $webTopicName = "$twWeb.$twTopic";

    $this->writeDebug("### processing $webTopicName");
    my $origText = $text;

    # create directories for namespaces
    $this->createWeb($twWeb);

    # execute beforeConvert handler
    $this->execHandler('before', $page, $text);

    # create 
    next unless $this->createPage($page, $text) || $this->createRedirect($page, $text);

    # execute afterConvert handler
    $this->execHandler('after', $page, $text);

    if ($this->{debug}) {
      $text .= "---++ Original Source \n<verbatim>\n$origText\n</verbatim>\n";
    }

    # save
    $this->saveTopic($page, $text, $twWeb, $twTopic) if defined $text;

    $i++;
    last if $this->{maxPages} && $i > $this->{maxPages};
  }
  $i--;
  if ($this->{dry}) {
    $this->writeOut("would have created $i page(s)");
  } else {
    $this->writeOut("created $i page(s)");
  }

  # check integrity of categories
  #    * are all parent categories present
  foreach my $cat (values %{$this->{categories}}) {
    foreach my $parent (@{$cat->{categories}}) {
      unless (defined($this->{categories}{$parent})) {
        my $parentCategory = {
          title=>$parent,
          web=>$this->{targetWeb},
          topic=>$parent,
        };
        $this->{categories}{$parent} = $parentCategory;
        $this->writeWarning("created missing category $parent");
      }
    }
  }

  # exec finalize handler
  $this->execHandler('final');
}

##############################################################################
sub createRedirect {
  my $this = shift;
  my $page = shift;

  my $mwTo = $page->redirect;
  return 0 unless $mwTo;

  my $mwFrom = $page->title;
  my ($twToWeb, $twToTopic) = $this->getTitle($page, $mwTo);
  my $twToWebTopic = "$twToWeb.$twToTopic";

  $_[0] = 
    "---+!! [[%TOPIC%][$mwFrom]]\n".
    "Redirect to [[$twToWebTopic][$mwTo]]\n".
    "---\n".
    "\%INCLUDE{\"$twToWebTopic\"}\%\n";

  return 1;
}

##############################################################################
sub createPage {
  my $this = shift;
  my $page = shift;

  # analyse the title
  my ($twWeb, $twTopic) = $this->getTitle($page);
  my $webTopicName = "$twWeb.$twTopic";

  my $mwTitle = $page->title;
  if ($this->{seenPage}{$webTopicName}) {
    $this->writeWarning("'$mwTitle' clashes with '$this->{seenPage}{$webTopicName}' on '$webTopicName'");
  }
  $this->{seenPage}{$webTopicName} = $mwTitle;
  #$this->writeDebug("creating page '$webTopicName'");

  # process text
  $this->convertMarkup($page, 1, $_[0]);

  # only add a TOPIC title if there's no other first level heading
  # and we aren't in the Template namespace
  if ($page->namespace ne $this->{language}{Template} &&
    $_[0] !~ /(^|[\n\r])---\+[^\+]/) {
    #$this->writeDebug("adding TOPIC title");
    my $pageTitle = $mwTitle;
    $pageTitle =~ s/^.*://o;
    $_[0] = "---+!! [[%TOPIC%][$pageTitle]]\n".$_[0]."\n";
  }

  # add TOC before first headline
  my $genTOC = 0;
  if (defined $this->{genTOC}{$page->id}) {
    $genTOC = $this->{genTOC}{$page->id};
  } else {
    # count headings
    my $nrHeadings = 0;
    while ($_[0] =~ /(?:^|[\n\r])(---\+\+.*)/g) {
      $nrHeadings++;
    }
    $genTOC = 1 if $nrHeadings > 3;
  }
  if ($genTOC) {
    #$this->writeDebug("found $nrHeadings headings");
    $_[0] =~ s/(^|[\n\r])(---\+\+)/\n\%TOC\%\n$2/o;
  }

  # append metadata (attachments and forms)
  $_[0] .= "\n".join("\n",@{$page->{_attachments}})."\n" if $page->{_attachments};

  return 1;
}


##############################################################################
sub saveTopic {
  my ($this, $page, $text, $web, $topic) = @_;

  $web ||= $this->{targetWeb};

  #$this->writeDebug("called saveTopic(page, text, $web, $topic)");
  my $author;
  my $date;
  if ($page) {
    $date = Foswiki::Time::parseTime($page->timestamp);
    $author = $page->username || 'UnknownUser';
  } else {
    $author = 'UnknownUser';
    $date = time();
  }
  (undef, $author) = $this->getTitle($page, $author);
  # TODO: apply topic and web maps



  $text =~ s/$translationToken0//go; # unless $debug;
  $text = '%META:TOPICINFO{'.
    'author="'.$author.'" '.
    'date="'.$date.'" '.
    'format="1.1" reprev="1.1" version="1.1"}%'."\n".
    $text;

  # create file
  $web =~ s/\./\//go;
  $web =~ s/\/$//go;
  my $topicFileName = $Foswiki::cfg{DataDir}.'/'.$web.'/'.$topic.'.txt';

  my $defaultWebFileName = $Foswiki::cfg{DataDir}.'/'.$this->{defaultWeb}.'/'.$topic.'.txt';

  if (-f $topicFileName && ! -f $defaultWebFileName && ! $this->{cummulative}) { # overwriting default topics is ok
    my $index = 0;
    my $newTopicFileName;
    $topicFileName =~ s/\.txt$//o;
    do  {
      $index++;
      $newTopicFileName = $topicFileName.'_DOUBLE_'.$index.'.txt';
    } while (-f $newTopicFileName);
    $this->writeWarning("woops $topicFileName.txt already exists ... renaming it to $newTopicFileName");
    $topicFileName = $newTopicFileName;
    if ($page) {
      if ($page->redirect) {
        $this->writeWarning("this is a redirect page");
      } else {
        $this->writeWarning("this is NO redirect page");
      }
    }
  }

  if ($this->{dry}) {
    #$this->writeDebug("would create file '$topicFileName'");
  } else {
    #$this->writeDebug("creating file '$topicFileName'");
    unless (open(FILE, ">$topicFileName")) {
      die "Can't create file $topicFileName - $!\n";
    }
    $text = $this->toSiteCharSet($text);
    print FILE $text;
    close( FILE);
  }
}

##############################################################################
# tables: use Foswiki:Extensions.MediaWikiTablePlugin
# TODO: argh, what about ParserFunctions: http://meta.wikimedia.org/wiki/ParserFunctions
sub convertMarkup {
  my $this = shift;
  my $page = shift;
  my $mode = shift; # 0: page mode; 1: line mode

  # refs (aka footnotes) 
  $_[0] =~ s/<ref name="(.+?)">(.+?)<\/ref>/$this->handleFootNote($page, $2, $1)/ges;
  $_[0] =~ s/<ref>(.+?)<\/ref>/$this->handleFootNote($page, $1)/ges;

  # gallery
  $_[0] =~ s/<gallery(.*?)?>(.*?)<\/gallery>/$this->handleGallery($page, $1, $2)/ges;

  # multimedia
  $_[0] =~ s/\[\[$this->{language}{Image}:(.+)\]\]/$this->handleImage($page, $1)/ge;
  $_[0] =~ s/\[\[$this->{language}{Media}:(.+)\]\]/$this->handleMedia($page, $1)/ge;
  $_[0] =~ s/\[\[$language{en}{Image}:(.+)\]\]/$this->handleImage($page, $1)/ge;
  $_[0] =~ s/\[\[$language{en}{Media}:(.+)\]\]/$this->handleMedia($page, $1)/ge;

  # mailto
  $_[0] =~ s/\[mailto:([^\s]+?)\]/$1/g;
  $_[0] =~ s/\[mailto:(.*?) (.*?)\]/\[${translationToken0}\[mailto:$1\]\[$2\]\]/g;

  # exteral link
  $_[0] =~ s/\[?\[((?:https?|ftp)\:.+?)(?:[ \|]+(.+?))?\]\]?/$this->handleExternalLink($page, $1, $2)/ge;

  # file
  $_[0] =~ s/\[?\[(file\:.+?)(?:[ \|]+(.+?))?\]\]?/$this->handleExternalLink($page, $1, $2)/ge;

  # internal links
  $_[0] =~ s/\[\[(.+?)\]\]/$this->handleInternalLink($page, $1)/ge; 

  # templates
  $_[0] =~ s/{{{\b([^\}]+?)\b}}}/$this->handleTemplateVariable($page, $1)/ge; # variables
  1 while $_[0] =~ s/{{(?!.*{{)(.+?)}}/$this->handleTemplateCall($page, $1)/ges; # includes

  # page mode
  if ($mode) {
    # spaces at the beginning of the line are open a verbatim section
    $this->handleVerbatim($page, $_[0]) if $mode && $_[0] =~ /(^|[\n\r]) /;
    # indentation
    $this->handleIndentation($page, $_[0]) if $mode && $_[0] =~ /(^|[\n\r]):/;
  }

  # TOC
  if ($_[0] =~ s/__NOTOC__//go) {
    $this->{genTOC}{$page->id} = 0;
  }
  if ($_[0] =~ s/__TOC__//go) {
    $this->{genTOC}{$page->id} = 1;
  }

  # horizontal ruler
  $_[0] =~ s/(^|[\n\r])----/$1---/go;

  # bullets
  $_[0] =~ s/(^|[\n\r])[\#\*;]{9}\# ?/$1                              1. /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{8}\# ?/$1                           1. /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{7}\# ?/$1                        1. /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{6}\# ?/$1                     1. /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{5}\# ?/$1                  1. /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{4}\# ?/$1               1. /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{3}\# ?/$1            1. /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{2}\# ?/$1         1. /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{1}\# ?/$1      1. /go;
  $_[0] =~ s/(^|[\n\r])\# ?/$1   1. /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{9}\* ?/$1                              \* /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{8}\* ?/$1                           \* /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{7}\* ?/$1                        \* /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{6}\* ?/$1                     \* /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{5}\* ?/$1                  \* /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{4}\* ?/$1               \* /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{3}\* ?/$1            \* /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{2}\* ?/$1         \* /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{1}\* ?/$1      \* /go;
  $_[0] =~ s/(^|[\n\r])\* ?/$1   \* /go;


  # definition lists
  $_[0] =~ s/(^|[\n\r])[\#\*;]{9}\; *([^:]*):/$1                              $2: /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{8}\; *([^:]*):/$1                           $2: /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{7}\; *([^:]*):/$1                        $2: /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{6}\; *([^:]*):/$1                     $2: /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{5}\; *([^:]*):/$1                  $2: /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{4}\; *([^:]*):/$1               $2: /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{3}\; *([^:]*):/$1            $2: /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{2}\; *([^:]*):/$1         $2: /go;
  $_[0] =~ s/(^|[\n\r])[\#\*;]{1}\; *([^:]*):/$1      $2: /go;
  $_[0] =~ s/(^|[\n\r])\; *([^:]*?)[\n\r]:/$1   $2: /go;
  $_[0] =~ s/(^|[\n\r])\; *(.*?)([\n\r]|$)/$1   $2: $3/go;

  # headings
  $_[0] =~ s/(^|[\n\r])====== ?(.*?) ?======\s*(?=[\n\r]|$)/$1---\+\+\+\+\+\+ $2\n/go;
  $_[0] =~ s/(^|[\n\r])====== ?(.*?) ?======\s*(?=[\n\r]|$)/$1---\+\+\+\+\+\+ $2\n/go;
  $_[0] =~ s/(^|[\n\r])===== ?(.*?) ?=====\s*(?=[\n\r]|$)/$1---\+\+\+\+\+ $2\n/go;
  $_[0] =~ s/(^|[\n\r])==== ?(.*?) ?====\s*(?=[\n\r]|$)/$1---\+\+\+\+ $2\n/go;
  $_[0] =~ s/(^|[\n\r])=== ?(.*?) ?===\s*(?=[\n\r]|$)/$1---\+\+\+ $2\n/go;
  $_[0] =~ s/(^|[\n\r])== ?(.*?) ?==\s*(?=[\n\r]|$)/$1---\+\+ $2\n/go;
  $_[0] =~ s/(^|[\n\r])= ?(.*?) ?=\s*(?=[\n\r]|$)/$1---\+ $2\n/go;

  # nowiki
#  $_[0] =~ s/''''<nowiki>\s*(.+?)\s*<\/nowiki>''''/<em> ==$1== <\/em> /go; # verbatim bold italic
#  $_[0] =~ s/'''<nowiki>\s*(.+?)\s*<\/nowiki>'''/ ==$1== /go;  # verbatim bold
#  $_[0] =~ s/''<nowiki>\s*(.+?)\s*<\/nowiki>''/<em> =$1= <\/em>/go; # verbatim italic
#  $_[0] =~ s/<nowiki>\s*(.+?)\s*<\/nowiki>/ =$1= /go; 
  $_[0] =~ s/(<\/?)nowiki>/$1verbatim>/go; 

  # mediawiki markup
  $_[0] =~ s/(^|[^'])'''<tt>(.+?)<\/tt>''' ?/$1 ==$2== /go; # monospaced bold
  $_[0] =~ s/<tt>(.+?)<\/tt>/ =$1= /go; # monospaced
#  $_[0] =~ s/<tt>(.+?)<\/tt>/s#[\n\r]# #go;" =$1= "/ges; # multi_[0] monospaced
  $_[0] =~ s/(^|[^'])'''''\s*(.+?)\s*''''' ?/$1 __$2__ /go; # bold italic
  $_[0] =~ s/(^|[^'])'''\s*(.+?)\s*''' ?/$1 *$2* /go; # bold
  $_[0] =~ s/(^|[^'])''\s*(.+?)\s*'' ?/$1 _$2_ /go; # italic

  # misc
  $_[0] =~ s/<references *\/>/\%ENDNOTES\%/go;

  # math
  $_[0] =~ s/(<\/?)math>/$1latex>/go;

  #$this->writeDebug("out '$_[0]'");
}

##############################################################################
sub handleIndentation {
  my $this = shift;
  my $page = shift;

  #$this->writeDebug("### called handleIndentation");
  my $found = 0;
  my $state = 0;
  my @result;
  foreach my $line (split(/[\n\r]/, $_[0])) {
    if ($line =~ /^:(:*)(.+)$/) {
      # state 1: continue block
      if ($state == 1) {
	push (@result, $1.$2." <br />");
	#$this->writeDebug("state=$state - $line");
	next;
      }
      # state 0: start new block
      if ($state == 0) {
	push (@result, "<blockquote>\n$1$2 <br />");
	$found = 1;
	$state = 1;
	#$this->writeDebug("state=$state - $line");
	next;
      }
    } 

    # state 2: close block
    if ($state) {
      push (@result, "</blockquote>\n$line");
      $state = 0;
      #$this->writeDebug("state=$state - $line");
      next;
    }

    #$this->writeDebug("state=$state - $line");
    push (@result, $line);
  }
  return 0 unless $found;

  # more indentation
  my $result = join("\n", @result);
  $this->handleIndentation($page, $result);
  $_[0] = $result;
  return $found;
}

##############################################################################
sub handleVerbatim {
  my $this = shift;
  my $page = shift;

  my $found = 0;
  my $state = 0;
  my @result;
  #$this->writeDebug("handling verbatims in '$_[0]'");
  foreach my $line (split(/[\n\r]/, $_[0])) {

    # state 0: outside of a verbatim section
    if ($state == 0) {
      # exceptions: tables
      unless ($line =~ /^ +({\||\||\|)/) {
	if ($line =~ /^ +([^ <]|<nowiki)/) {
	  # open
	  $state = 1;
	  $line = "<pre>$line";
	}
      }
    } 
    
    # state 1: inside a verbatim section
    elsif ($state == 1) {
      unless ($line =~ /^ /) {
	# close
	$state = 0;
	$line = "</pre>\n$line";
      }
    }

    if ($state == 1) {
      $line =~ s/<nowiki>(.*?)<\/nowiki>/
	my $val = $1;
	$val =~ s#\%([A-Za-z0-9])#%<nop>$1#g;
	$val
      /geo;
      $line =~ s/<\/?nowiki>//go;
    }

    #$this->writeDebug("state=$state : '$line'");
    push (@result, $line);
  }
  if ($state == 1) {
    push (@result, "</pre>\n");
  }

  my $result = join("\n", @result);
  $_[0] = $result;
  return $found;
}

##############################################################################
# TODO use Foswiki:Extensions.EndNotePlugin
sub handleFootNote {
  my ($this, $page, $text, $name) = @_;

  #return "($text)";
  $this->convertMarkup($page, 0, $text); # recursive call 

  # SMELL whatever the syntax is
  my $result = '%STARTENDNOTE';
  $result .= '{"'.$name.'"}' if $name;
  $result .= '%'; 
  $result .= $text;
  $result .= '%STOPENDNOTE%';

  #$result = '<!-- '.$result.'-->'; # disable me

  return $result;
}

##############################################################################
# see http://meta.wikimedia.org/wiki/Help:Template 
sub handleTemplateCall {
  my ($this, $page, $text) = @_;

  my $templateName = $text;

  # special templates, see http://meta.wikimedia.org/wiki/Help:Variable
  # TODO list
  # * ns:Media
  # * ns:Special
  # * ns:Talk
  # * ns:User
  # * ns:Project
  # * ns:Image
  # * ns:MediaWiki
  # * ns:Template
  # * ns:Help
  # * ns:Category
  #
  # * localurl:page
  # * localurl:page|query=x
  #
  # * TALKSPACE(E)
  # * ARTICLESPACE(E)
  # * PAGENAMEE
  # * NANESPACEE
  # * FULLPAGENAMEE
  # * REVISIONID
  #
  # * CURRENTVERSION
  my %variables = (
    PAGENAME => '%TOPIC%',
    SITENAME => '%WIKITOOLNAME%',
    SERVERNAME => '%HTTPHOST%',
    SERVER => 'http://%HTTPHOST%',
    NAMESPACE => '%WEB%',
    FULLPAGENAME => '%WEB%.%TOPIC%',
    BASEPAGENAME => '%BASETOPIC%',
    'localurl:fullpagename' => '%SCRIPTURLPATH{"view"}%/%WEB%/%TOPIC%',
    'fullurl:fullpagename' => '%SCRIPTURL{"view"}%/%WEB%/%TOPIC%',
    'CURRENTYEAR' => '%DISPLAYTIME{"$year"}%',
    'CURRENTMONTH' => '%DISPLAYTIME{"$mo"}%',
    'CURRENTMONTHNAME' => '%DISPLAYTIME{"$month"}%', # N/A
    'CURRENTMONTHNAMEGEN' => '%DISPLAYTIME{"$month"}%', # N/A
    'CURRENTMONTHABBREV' => '%DISPLAYTIME{"$month"}%',
    'CURRENTWEEK' => '%DISPLAYTIME{"$week"}%',
    'CURRENTDAY' => '%DISPLAYTIME{"$day"}%',
    'CURRENTDAY2' => '%DISPLAYTIME{"$day"}%', # N/A
    'CURRENTNAME' => '%DISPLAYTIME{"$wday"}%', # N/A
    'CURRENTDOW' => '%DISPLAYTIME{"$dow"}%',
    'CURRENTTIME' => '%DISPLAYTIME{"$hour:$minutes"}%',
    'CURRENTTIMESTAMP' => '%DISPLAYTIME{"$year$month$day$hour$minutes$seconds"}%',
    'CURRENTHOUR' => '%DISPLAYTIME{"$hour"}%',
    'CURRENTMINUTE' => '%DISPLAYTIME{"$minutes"}%',
  );
  return $variables{$templateName} if $variables{$templateName};

  my $params;
  my %params;

  #$this->writeDebug("converting tempalte call '$text'");

  # collect params
  if ($templateName =~ /^(.+?)\|\s*(.+)\s*$/s) {
    $templateName = $1;
    $params = $2;
    $params =~ s/(%[a-zA-Z0-9_]+{.*?)\|(.*?}%)/$1$translationToken1$2/g;
    my $i = 1;
    foreach my $param (split(/\s*\|\s*/,$params)) {
      my $name;
      my $value;
      if ($param =~ /^\s*(.*?)\s*=\s*(.*?)\s*$/) {
	$name = $1;
	$value = $2;
      } else {
	$name = 'PARAM'.$i;
	$value = $param;
      }
      $value =~ s/^\s+//go;
      $value =~ s/\s+$//go;
      $value =~ s/$translationToken1/\|/g;
      $this->convertMarkup($page, 0, $value);
      $value =~ s/\%/\$percnt/go;
      $value =~ s/"/\\"/go;
      $params{$name} = $value;
      #$this->writeDebug("param $name=$value");
    }
  }
  $templateName =~ s/<!--.*?-->//gos;
  my ($webName, $topicName) = $this->getTitle($page, $templateName);
  $webName ||= $this->{language}{Template};
  my $webTopicName = "$webName.$topicName";

  # OUTCH: convert links in template as they are handled differently in MediaWiki and Foswiki:
  # links in a transcluded page are resolved locally/early in TW while resolved lately
  # in MW. Example: Given you have a transclusion in an article in the Main namespace/web
  # of another article called 'Template:A'. Now Template:A has a link [[B]] in it. In MW it
  # will create a link to Main:B while linking to Template:B in Foswiki

  # build (parametrized) INCLUDE
  my $result = '%INCLUDE{"'.$webTopicName.'"'; # TODO: how do we get the templates
  foreach my $name (sort keys %params) {
    my $value = $params{$name};
    $result .= " $name=\"$value\"";
  }
  #$result .= "  warn=\"[[$webTopicName]]\"\n"
  $result .= "}%";

  #$this->writeDebug("transcluding '$text' becomes '$result'");
  $this->{templates}{$templateName} = $page->title;

  return $result;
}

##############################################################################
sub handleTemplateVariable {
  my ($this, $page, $text) = @_;

  my $origText = $text;

  # anon params
  $text =~ s/^(\d+)$/PARAM$1/;

  # TODO 
  # * defaults
  # * conditionals #if..:

  my $result = '%'.$text.'%';

  #$this->writeDebug("template variable '$origText' -> '$result'");
  return $result;
}

##############################################################################
sub handleGallery {
  my ($this, $page, $args, $text) = @_;

  my $result = '';
  #$result = "<!-- DEBUG: $text -->\n";
  my $imageTag = "$this->{language}{Image}";
  my @images;
  foreach my $line (split(/[\n\r]/, $text)) {
    $line =~ s/^\s*(.*?)\s*$/$1/;
    $line =~ s/^Image://go;
    $line =~ s/^$imageTag://go;
    next unless $line;
    if ($line =~ /^(.*?)(?:\|(.*))?$/) {
      my $file = ucfirst($1);
      my $comment = $2;
      $file =~ s/^\s+//g;
      $file =~ s/\s+$//g;
      $file =~ s/ +/_/g;
      # attach the image
      $file = $this->attachMedia($page, $file, $comment);
      push @images, $file if $file;
    }
  }
  $result .= '%IMAGEGALLERY{include="'.join('|',@images).'"}%'."\n"
    if @images;

  return $result;
}

##############################################################################
sub handleImage {
  my ($this, $page, $text) = @_;

  #$this->writeDebug("called handleImage($text)");

  my $result = '';
  my $file = $text;
  my $args = '';
  if ($file =~ /^(.*?)\|(.*)$/) {
    $file = $1;
    $args = $2;
  }
  $file = ucfirst($file);
  $file =~ s/^\s+//g;
  $file =~ s/\s+$//g;
  $file =~ s/ +/_/g;

  # attach the image
  $file = $this->attachMedia($page, $file);

  return '' unless $file;

  # recursive call for the caption
  if ($args) {
    $this->convertMarkup($page, 0, $args);
    $args =~ s/"/\\"/go;
    $args =~ s/%/\$percnt/go;
    $result = "\%IMAGE{\"$file|$args\" align=\"right\"}%";
  } else {
    $result = "\%IMAGE{\"$file\" align=\"right\"}%";
  }

  return $result;
}

##############################################################################
sub handleMedia {
  my ($this, $page, $text) = @_;

  my $file = $text;
  my $args = '';
  if ($file =~ /^(.*?)\|(.*)$/) {
    $file = $1;
    $args = $2;
  }
  $file = ucfirst($file);
  $file =~ s/^\s+//g;
  $file =~ s/\s+$//g;
  $file =~ s/ +/_/g;

  # attach the media file
  $this->attachMedia($page, $file);

  # recursive call for the caption
  my $result = "\[$translationToken0\[\%ATTACHURLPATH\%/$file]";
  if ($args) {
    $this->convertMarkup($page, 0, $args);
    $result .= "[$args]";
  }
  $result .= ']';

  return $result;
}


##############################################################################
sub attachMedia {
  my ($this, $page, $file, $comment) = @_;

  return unless $this->{images}; # did we say ...

  # find out where the image is
  $file =~ s/^\s+//go;
  $file =~ s/\s+$//go;

  $comment ||= '';

  # cope with attachments that have umlauts in their name
  my $utf8file = $this->toUtf8($file);
  my $key = md5_hex($utf8file);
  my $source = $this->{images}.'/'.substr($key,0,1).'/'.substr($key,0,2).'/'.$utf8file;

  return $source if $source =~ /^https?:\/\//; # remote image / deep link

  if (-f $source) {
    #$this->writeDebug("found $source");
  } else {
    $this->writeWarning("image $source not found in ".$page->title);
    return '';
  }

  # find out where to put the image
  my $web = '';
  my $topic = '';
  ($web, $topic) = $this->getTitle($page);
  my $webTopicName = "$web.$topic";
  $webTopicName =~ s/\./\//g;

  my $pubDir = $Foswiki::cfg{PubDir}.'/'.$webTopicName;
  unless (-d $pubDir) {
    if ($this->{dry}) {
      #$this->writeDebug("would create directory $pubDir");
    } else {
      unless (mkdir $pubDir) {
        $this->writeWarning("failed to attach data to topic $webTopicName");
        $this->writeWarning("can't create $pubDir: $!");
        return '';
      }
    }
  }
  my $target = $pubDir.'/'.$file;
  $target = $this->fromUtf8(string=>$target);

  if ($this->{dry}) {
    $this->writeDebug("would copy media file $source to $target");
  } else {
    unless (-f $target)  {
      #$this->writeDebug("copying media file from $source to $target");
      copy($source, $target);
    }
  }

  # create attachment
  my $attachmentText = $attachmentTemplate;
  my $author = $page->username || 'UnknownUser';
  my $size = `du -b $source`;
  $size =~ s/^(\d+).*$/$1/s;
  my $time = time();
  $attachmentText =~ s/%file%/$file/g;
  $attachmentText =~ s/%date%/$time/g;
  $attachmentText =~ s/%user%/$author/g;
  $attachmentText =~ s/%size%/$size/g;
  $attachmentText =~ s/%comment%/$comment/g;

  $page->{_attachments} ||= ();

  push(@{$page->{_attachments}},$attachmentText);

  return $file;
}


##############################################################################
# see http://meta.wikimedia.org/wiki/Help:Link
sub handleInternalLink {
  my ($this, $page, $text) = @_;

  #$this->writeDebug("handleInternalLink(".$page->title.", $text)");

  my $linkText = $text;
  my $topicName = $text;
  my $webName;
  if ($topicName =~ /^\s*(.*)\s*\|\s*(.*)\s*$/) {
    $topicName = $1;
    $linkText = $2;
  }
  ($webName, $topicName) = $this->getTitle($page, $topicName);
  my $webTopicName = "$webName.$topicName";
  $this->convertMarkup($page, 0, $linkText);

  # links have to be full qualified to cope with semantic differences properly
  my $result = "\[$translationToken0\[$webTopicName][$linkText]]";

  #$this->writeDebug("internal link [[$text]] -> $result");
  return $result;
}

##############################################################################
sub handleExternalLink {
  my ($this, $page, $link, $label) = @_;

  $label ||= '';
  #$this->writeDebug("handleExternalLink(".$page->title.", $link, $label)");
  my $result = '['.$translationToken0.'['.$link.'][';
  if ($label) {
    $this->convertMarkup($page, 0, $label);
    $result .= $label;
  } else {
    $this->{externalLinkCounter}++;
    $result .= '&#91;'.$this->{externalLinkCounter}.'&#93;';
  }
  $result .= ']]';

  #$this->writeDebug("external link [[$link $label]] -> $result");

  return $result;
}

##############################################################################
sub getTitle {
  my ($this, $page, $title) = @_;

  $title ||= $page->title if $page;

  my $webName = '';
  my $topicName = '';

  my $cacheEntry = $this->{titleCache}{$title};
  if (defined $cacheEntry) {
    return @$cacheEntry;
  }

  # exec title handler
  $this->execHandler('title', $page, $title);

  $topicName = $title;
  my $anchor = '';

  if ($topicName =~ /^(.*)#(.*?)$/) {
    $topicName = $1 || '';
    $anchor = $2;
  }

  if ($topicName =~ /^(.+?):(.*)$/) {
#    if (defined $this->{namespaces}{$1}) {
      $webName = $1;
      $topicName = $2;
#    } else {
#      unless ($this->{warnedNamespace}{$1}) {
#	$this->writeWarning("unknown namespace '$1'");
#	$this->{warnedNamespace}{$1} = 1;
#      }
#    }
    #$this->writeDebug("found explicite webName=$webName");
  }

  $topicName = $this->getCamelCase($topicName);
  #print STDERR "topicName=$topicName\n";

  # check topic map for the full web.topic
  if ($this->{topicMap}{"$webName.$topicName"}) {
    my $webTopicName = $this->{topicMap}{"$webName.$topicName"};
    $webName = '';
    $topicName = $webTopicName;
    if ($webTopicName =~ /^(.*)\.(.*?)$/) {
      $webName = $1;
      $topicName = $2;
    }
  } 
 
  # check the topic map for the topic only
  $topicName = $this->{topicMap}{$topicName} if $this->{topicMap}{$topicName};

  # convert anchor, at least try to
  $anchor = $this->convertAnchor($anchor);
  $topicName .= '#'.$anchor if $anchor;

  # get the web name
  $webName ||= $this->{targetWeb};
  my $mappedWebName = $this->{webMap}{$webName};
  if ($mappedWebName) {
    #$this->writeDebug("found web '$webName' in mapping ... renaming it to '$mappedWebName'");
    $webName = $mappedWebName;
  } else {
    $webName = $this->{targetWeb}.'.'.$webName
      if $webName ne $this->{targetWeb};
  }

  #$this->writeDebug("converting title '$title' -> webName=$webName, topicName=$topicName");
  
  $this->{titleCache}{$title} = [$webName, $topicName];
  return ($webName, $topicName);
}

##############################################################################
sub convertAnchor {
  my ($this, $anchor) = @_;

  return '' unless $anchor;

  #$this->writeDebug("before anchor=$anchor");

  $anchor =~ s/\.[A-F0-9][A-F0-9]\.[A-F0-9][A-F0-9]/_/go;
  $anchor =~ s/[^$Foswiki::regex{mixedAlphaNum}]+/_/g;
  $anchor =~ s/__+/_/g;
  $anchor = substr($anchor, 0, 32);

  #$this->writeDebug("after anchor=$anchor");

  return $anchor;
}

##############################################################################
sub getPageText {
  my ($this, $page) = @_;

  my $text = ${$page->text};
  $text = $this->fromUtf8($text);
  $text = $this->toUtf8($text);

  return $text;
}

##############################################################################
sub getCamelCase {
  my ($this, $name) = @_;

  # transliterate umlaute
  $name =~ s/ä/ae/go;
  $name =~ s/ö/oe/go;
  $name =~ s/ü/ue/go;
  $name =~ s/Ä/Ae/go;
  $name =~ s/Ö/Oe/go;
  $name =~ s/Ü/Ue/go;
  $name =~ s/ß/ss/go;

  my $result = '';
  foreach my $part (split(/[^$Foswiki::regex{mixedAlphaNum}]/, $name)) {
    $result .= ucfirst($part);
  }
  
  return $result;
}

##############################################################################
sub getCategoryName {
  my ($this, $name) = @_;

  my $result = '';
  foreach my $part (split(/[^$Foswiki::regex{mixedAlphaNum}]/, $name)) {
    $result .= ucfirst(lc($part));
  }

  return $result.'Category';
}

##############################################################################
sub handleCategory {
  my ($this, $page) = @_;

  $this->writeDebug("called handleCategory(".$page->title.")");

  # create a category object
  my $title = $page->title;
  my $topic = $title;
  if ($title =~ /^(.*):(.*)$/) {
    $title = $2;
    $topic = $2;
  }
  $topic = $this->getCategoryName($topic);
  my $parentCategories = $page->categories;
  my @parentCategories = ();
  if ($parentCategories) {
    for my $parentCat (sort @$parentCategories) {
      push @parentCategories, $this->getCategoryName($parentCat);
    }
  }
  @parentCategories = sort @parentCategories;
  my $text = $this->getPageText($page);
  $text =~ s/\[\[$this->{language}{Category}:.+?\]\]//g;
  $text =~ s/\[\[$language{en}{Category}:.+?\]\]//g;
  my $summary = '';
  if ($text =~ s/^\s*==\s*(.*?)\s*==\s*$//m) {
    $summary = $1;
    $summary =~ s/^\s*\[\[.*?\]\[(.*)\]\]\s*$/$1/g;
  }
  $this->convertMarkup($page, 0, $text);
  $text =~ s/^\s+//gs;
  $text =~ s/\s+$//gs;

  #$this->writeDebug("topic=$topic");
  #$this->writeDebug("title=$title");
  #$this->writeDebug("summary=$summary");
  #$this->writeDebug("parents=".join(',',@parentCategories));
  #$this->writeDebug("text='$text'");

  my $category = {
    title=>$title,
    topic=>$topic,
    categories=>\@parentCategories,
    summary=>$summary,
    text=>$text,
    page=>$page,
  };

  $this->execHandler('category', $page, $category);

  # save it
  $this->{categories}{$category->{topic}} = $category;
}

##############################################################################
sub fromUtf8 {
  my ($this, $string) = @_;

  return Encode::decode_utf8($string);
}

##############################################################################
sub toUtf8 {
  my ($this, $string) = @_;

  my $charset = $Foswiki::cfg{Site}{CharSet};
  return $string if $charset =~ /^utf-?8$/i;


  my $octets = Encode::decode($charset, $string);
  $octets = Encode::encode('utf-8', $octets);
  return $octets;
}

##############################################################################
sub toSiteCharSet {
  my ($this, $string) = @_;

  return Encode::encode($Foswiki::cfg{Site}{CharSet}, $string);
}


1;
