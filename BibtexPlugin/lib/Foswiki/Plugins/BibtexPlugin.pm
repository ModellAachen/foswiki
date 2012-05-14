###############################################################################
# Plugin for Foswiki Collaboration Platform, http://foswiki.org/
#
# Copyright (C) 2003 Michael Daum <micha@nats.informatik.uni-hamburg.de>
#
# Based on parts of the EmbedBibPlugin by TWiki:Main/DonnyKurniawan
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

### for custom .bst styles, bibtex processing needs to know where to
### find them.  The easiest way is to use a texmf tree below 'HOME'
$ENV{'HOME'} = $Foswiki::cfg{Plugins}{BibtexPlugin}{home}
  || '/home/nobody';

package Foswiki::Plugins::BibtexPlugin;

use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $defaultTopic $defaultSearchTemplate $pubUrlPath $hostUrl $pubDir
  $isInitialized $currentBibWeb $currentBibTopic
  $cmdTemplate $render_script
  %bibliography $script
  $bibtexPrg $citeno $bibcite
);

# use vars qw( %TWikiCompatibility );

use File::Basename;

use strict;
$VERSION = '$Rev$';
$RELEASE = '1.5';
$pluginName = 'BibtexPlugin';
$debug = 0;    # toggle me

my %bibliography = ();
my $citefile = "";
my $citeno = 1;

eval "use TWiki::Plugins::BibliographyPlugin;";
my $bibcite = ($TWiki::Plugins::BibliographyPlugin::VERSION) ? 1 : 0;

###############################################################################
sub writeDebug {
  &Foswiki::Func::writeDebug("$pluginName - " . $_[0]) if $debug;

  # print STDERR "$pluginName - $_[0]\n" if $debug;
}

###############################################################################
sub initPlugin {
  ($topic, $web, $user, $installWeb) = @_;

  # check for Plugins.pm versions
  if ($Foswiki::Plugins::VERSION < 1) {
    Foswiki::Func::writeWarning("Version mismatch between $pluginName and Plugins.pm");
    return 0;
  }

  $script = basename($0);

  $isInitialized = 0;

  return 1;
}

###############################################################################
sub doInit {
  return if $isInitialized;

  writeDebug("called doInit");

  $render_script = $Foswiki::cfg{Plugins}{BibtexPlugin}{render}
    || '../tools/render.sh';

  # get configuration
  $defaultTopic =
       Foswiki::Func::getPreferencesValue("\U${pluginName}\E_DEFAULTTOPIC", $web)
    || Foswiki::Func::getPreferencesValue("\U${pluginName}\E_DEFAULTTOPIC")
    || "System.BibtexPlugin";
  $defaultSearchTemplate =
       Foswiki::Func::getPreferencesValue("\U${pluginName}\E_DEFAULTSEARCHTEMPLATE", $web)
    || Foswiki::Func::getPreferencesValue("\U${pluginName}\E_DEFAULTSEARCHTEMPLATE")
    || "System.BibtexSearchTemplate";

  $hostUrl = &Foswiki::Func::getUrlHost();
  $pubUrlPath = &Foswiki::Func::getPubUrlPath();
  $pubDir = &Foswiki::Func::getPubDir();

  #  $cmdTemplate = $pubDir .  '/System/BibtexPlugin/bibtex_render.sh ' .
  $cmdTemplate = $render_script . ' %MODE|U%' . ' %BIBTOOLRSC|F%' . ' %SELECT|U%' . ' %BIBTEX2HTMLARGS|U%' . ' %STDERR|F%' . ' %BIBFILES|F%';

  $currentBibWeb = $web;    # "";
  $currentBibTopic = $topic;    # "";

  &writeDebug("doInit( ) is OK");
  $isInitialized = 1;

  return '';
}

sub beforeCommonTagsHandler {
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

  Foswiki::Func::writeDebug("- ${pluginName}::beforeCommonTagsHandler( $_[1] )")
    if $debug;

  # This handler is called by getRenderedVersion just before the line loop

  ######################################################

  &doInit() if ($_[0] =~ m/%BIBTEXREF{.*?}%/);

}

###############################################################################
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

  Foswiki::Func::writeDebug("- ${pluginName}::CommonTagsHandler( $_[1] )")
    if $debug;

  # bail out if latex=tml
  return if (Foswiki::Func::getContext()->{'LMPcontext'}->{'alltexmode'});

  $_[0] =~ s/%(BIBCITE|CITE){(.*?)}%/&handleCitation2($2,$1)/ge;

  $_[0] =~ s/%BIBTEXREF{([^}]*)}%/&handleBibtexBibliography($1)/ge;

  $_[0] =~ s/%BIBTEX%/&handleBibtex()/ge;
  $_[0] =~ s/%BIBTEX{(.*?)}%/&handleBibtex($1)/ge;
  $_[0] =~ s/%STARTBIBTEX%(.*?)%STOPBIBTEX%/&handleInlineBibtex("", $1)/ges;
  $_[0] =~ s/%STARTBIBTEX{(.*?)}%(.*?)%STOPBIBTEX%/&handleInlineBibtex($1, $2)/ges;

}

# $TWikiCompatibility{endRenderingHandler} = 1.1;
# sub endRenderingHandler
# {
#     # for backwards compatibility with Cairo
#     postRenderingHandler($_[0]);
# }

# =========================
sub postRenderingHandler {

  # need to go back and clean up the citations, to correct for cases such
  # as when a cited bibtex entry is not found or the keys are not numeric.

  foreach my $key (keys %bibliography) {
    if ($_[0] =~ m!<a name=\"$key\">(.*?)</a>!) {
      my $newno = $1;
      $_[0] =~ s!(<a href=\"\#$key\".*?>)[^\<\+]*?(</a>)!$1$newno$2!g;
    } else {
      $_[0] =~ s!<a href=\"\#$key\".*?>[^\<\+]*?</a>!?? $key not found ??!g;
    }
  }
  unlink($citefile) unless ($debug);

}

######################################################################
#
# the next three functions are derived from the BibliographyPlugin
# by Antonio Terceiro, adapted to use bibtex data sources
#
######################################################################
sub handleCitation2 {
  my ($input, $type) = @_;

  my $errMsg = &doInit();

  return '%' . $type . '{' . $input . '}%'
    if (($bibcite) and ($type = 'CITE'));

  my $txt = '[';
  foreach my $cit (split(/,/, $input)) {
    $bibliography{$cit}{"cited"} = 1;
    $bibliography{$cit}{"order"} = $citeno++
      unless defined($bibliography{$cit}{"order"});

    # print STDERR "found CITE:$cit $citeno\n";
    $txt .= (length($txt) > 1) ? ',' : '';
    $txt .= '<a href="#' . $cit . '" title="' . $cit . '">' . $bibliography{$cit}{"order"} . "</a>";
  }
  $txt .= ']';

  if ($script =~ m/genpdflatex/) {
    return ("<latex>\\cite{$input}</latex>");
  } else {
    return ($txt);
  }
}

sub bibliographyOrderSort {
  return $bibliography{$a}{"order"} <=> $bibliography{$b}{"order"};
}

sub handleBibtexBibliography {
  my ($args) = @_;

  my %opts = Foswiki::Func::extractParameters($args);

  my $header = "\n\n---+ References\n";

  my $style = $opts{'bibstyle'} || 'plain';
  my $files = $opts{'file'} || '.*\.bib';
  my $web = $opts{'web'} || $currentBibWeb;
  my $reqtopic = $opts{'topic'} || $currentBibTopic;

  my $text = "";

  my @cites = sort bibliographyOrderSort (keys %bibliography);

  if ($script =~ m/genpdflatex/) {

    my $bibtexPrg = $Foswiki::cfg{Plugins}{BibtexPlugin}{bibtex}
      || '/usr/bin/bibtex';

    my $errMsg = &doInit();
    return $errMsg if $errMsg;

    $currentBibWeb = $web;
    $currentBibTopic = $reqtopic;

    my @bibfiles = &getBibfiles($currentBibWeb, $currentBibTopic, $files);
    if (!@bibfiles) {
      my ($webName, $topicName) = &scanWebTopic($defaultTopic);
      &writeDebug("... trying $webName.$topicName now");
      return &showError("topic '$defaultTopic' not found")
        if !&Foswiki::Func::topicExists($webName, $topicName);
      @bibfiles = &getBibfiles($webName, $topicName, $files);
    }

    my $stdErrFile = &getTempFileName("BibtexPlugin");

    ### need to process the .bib files through bibtool before
    ### inclusion in the latex file
    my $theSelect = join(' or ', map { "(\$key : \"$_\")" } @cites);

    my ($result, $code) = Foswiki::Sandbox->sysCommand(
      undef, $cmdTemplate,
      MODE => 'raw',
      BIBTOOLRSC => $pubDir . '/System/BibtexPlugin/bibtoolrsc',
      BIBFILES => \@bibfiles,
      SELECT => $theSelect ? "-c '$theSelect'" : "",
      BIBTEX2HTMLARGS => '',
      STDERR => $stdErrFile,
    );
    &writeDebug("bib2bib: result code $code");

    # output result to a temporary bibtex file...
    my $tmpbib = getTempFileName("bib") . '.bib';

    # print STDERR $tmpbib . "\n";
    open(T, ">$tmpbib");
    print T $result;
    close(T);

    # construct temporary .aux file
    my $auxfile = getTempFileName("bib") . '.aux';
    open(T, ">$auxfile");
    print T "\\relax\n\\bibstyle{$style}\n";
    print T map { "\\citation{$_}\n" } @cites;

    # print T "\\bibdata{".join(',',@bibfiles)."}\n";
    print T "\\bibdata{" . $tmpbib . "}\n";
    close(T);

    # run bibtex
    if (-f $auxfile) {
      ($result, $code) = Foswiki::Sandbox->sysCommand("$bibtexPrg %BIBFILE|F%", BIBFILE => $auxfile), &writeDebug("result code $code");
    }
    $auxfile =~ s/\.aux$/.bbl/;
    if (-f $auxfile) {
      $text .= "<noautolink><latex>\n";
      open(F, "$auxfile");
      while (<F>) {
        $text .= $_;
      }
      close(F);
      $text .= "</latex></noautolink>\n";
    } else {
      $text .= "<pre>error in bibtex generation\n$auxfile\n$result</pre>";
    }

    $auxfile =~ s/\.bbl$//;
    foreach my $c ('.aux', '.bbl', '.blg') {
      unlink($auxfile . $c) unless ($debug);
    }
    unlink($tmpbib) unless ($debug);
    unlink($stdErrFile) unless ($debug);

  } else {
    $text .= $header . "\n";

    $citefile = getTempFileName("bibtex-citefile");
    open(F, ">$citefile");
    foreach my $key (@cites) {

      # $text .= "$key ".$bibliography{$key}{"order"}." <br>";
      print F "$key\n";
    }
    close F;

    $text .= '%BIBTEX{select="';
    $text .= join(' or ', map { "\$key : '$_'" } @cites);
    $text .= '"';
    $text .= " bibstyle=\"$style\"";
    $text .= " file=\"$files\"" if ($files);
    $text .= " web=\"$web\"" if ($web ne '');
    $text .= " topic=\"$reqtopic\"" if ($reqtopic);
    $text .= " citefile=\"on\"";
    $text .= '}%';
  }
  return ($text);

}
###############################################################################

###############################################################################
sub handleBibtex {
  my $errMsg = &doInit();
  return $errMsg if $errMsg;

  # get all attributes
  my $theAttributes = shift;
  $theAttributes = "" if !$theAttributes;

  &writeDebug("handleBibtex - theAttributes=$theAttributes");

  my $theSelect = &Foswiki::Func::extractNameValuePair($theAttributes, "select");
  my $theBibfile = &Foswiki::Func::extractNameValuePair($theAttributes, "file");
  my $theTopic = &Foswiki::Func::extractNameValuePair($theAttributes, "topic");
  $theTopic = &Foswiki::Func::extractNameValuePair($theAttributes, "web") . '.' . $theTopic
    if length(&Foswiki::Func::extractNameValuePair($theAttributes, "web")) > 0;

  my $theStyle = &Foswiki::Func::extractNameValuePair($theAttributes, "bibstyle");
  my $theSort = &Foswiki::Func::extractNameValuePair($theAttributes, "sort");
  my $theErrors = &Foswiki::Func::extractNameValuePair($theAttributes, "errors");
  my $theReverse = &Foswiki::Func::extractNameValuePair($theAttributes, "rev");
  my $theMixed = &Foswiki::Func::extractNameValuePair($theAttributes, "mix");
  my $theForm = &Foswiki::Func::extractNameValuePair($theAttributes, "form");
  my $theAbstracts = &Foswiki::Func::extractNameValuePair($theAttributes, "abstracts")
    || &Foswiki::Func::extractNameValuePair($theAttributes, "abstract");
  my $theKeywords = &Foswiki::Func::extractNameValuePair($theAttributes, "keywords")
    || &Foswiki::Func::extractNameValuePair($theAttributes, "keyword");
  my $theTotal = &Foswiki::Func::extractNameValuePair($theAttributes, "total");
  my $theDisplay = &Foswiki::Func::extractNameValuePair($theAttributes, "display");
  my $usecites = &Foswiki::Func::extractNameValuePair($theAttributes, "citefile");

  return &bibSearch($theTopic, $theBibfile, $theSelect, $theStyle, $theSort, $theReverse, $theMixed, $theErrors, $theForm, $theAbstracts, $theKeywords, $theTotal, $theDisplay, $usecites);
}

###############################################################################
sub handleInlineBibtex {
  my ($theAttributes, $theBibtext) = @_;

  my $errMsg = &doInit();
  return $errMsg if $errMsg;

  &writeDebug("handleInlineBibtex: attributes=$theAttributes")
    if $theAttributes;

  #&writeDebug("handleInlineBibtex: bibtext=$theBibtext");

  my $theSelect = &Foswiki::Func::extractNameValuePair($theAttributes, "select");
  my $theStyle = &Foswiki::Func::extractNameValuePair($theAttributes, "bibstyle");
  my $theSort = &Foswiki::Func::extractNameValuePair($theAttributes, "sort");
  my $theErrors = &Foswiki::Func::extractNameValuePair($theAttributes, "errors");
  my $theReverse = &Foswiki::Func::extractNameValuePair($theAttributes, "rev");
  my $theMixed = &Foswiki::Func::extractNameValuePair($theAttributes, "mix");
  my $theForm = &Foswiki::Func::extractNameValuePair($theAttributes, "form");
  my $theAbstracts = &Foswiki::Func::extractNameValuePair($theAttributes, "abstracts")
    || &Foswiki::Func::extractNameValuePair($theAttributes, "abstract");
  my $theKeywords = &Foswiki::Func::extractNameValuePair($theAttributes, "keywords")
    || &Foswiki::Func::extractNameValuePair($theAttributes, "keyword");
  my $theTotal = &Foswiki::Func::extractNameValuePair($theAttributes, "total");
  my $theDisplay = &Foswiki::Func::extractNameValuePair($theAttributes, "display");

  #$theBibtext =~ s/%INCLUDE{(.*?)}%/&handleIncludeFile($1, $topic, $web)/ge;

  return &bibSearch("", "", $theSelect, $theStyle, $theSort, $theReverse, $theMixed, $theErrors, $theForm, $theAbstracts, $theKeywords, $theTotal, $theDisplay, "", $theBibtext);
}

###############################################################################
sub handleCitation {
  my $theAttributes = shift;

  my $errMsg = &doInit();
  return $errMsg if $errMsg;

  my $theKey = &Foswiki::Func::extractNameValuePair($theAttributes)
    || &Foswiki::Func::extractNameValuePair($theAttributes, "key");

  my $theTopic = &Foswiki::Func::extractNameValuePair($theAttributes, "topic");
  if ($theTopic) {
    ($currentBibWeb, $currentBibTopic) = &scanWebTopic($theTopic);
  } elsif (!$currentBibWeb || !$currentBibTopic) {
    ($currentBibWeb, $currentBibTopic) = &scanWebTopic($defaultTopic);
  }

  return "[[$currentBibWeb.$currentBibTopic#$theKey][$theKey]]";
}

###############################################################################
# use a pipe of three programs:
# 1. bibtool to normalize the bibfile(s)
# 2. bib2bib to select
# 3. bibtex2html to render
sub bibSearch {
  my ($theTopic, $theBibfile, $theSelect, $theStyle, $theSort, $theReverse, $theMixed, $theErrors, $theForm, $theAbstracts, $theKeywords, $theTotal, $theDisplay, $usecites, $theBibtext) = @_;

  my $errMsg = &doInit();
  return $errMsg if $errMsg;

  my $result = "";
  my $code;

  &writeDebug("called bibSearch()");

  # fallback to default values
  do {
    $theTopic = $topic;

    # $theTopic = $web.'.'.$theTopic unless ($web == '');
  } unless $theTopic;
  $theStyle = 'bibtool' unless $theStyle;
  $theSort = 'year' unless $theSort;
  $theReverse = 'on' unless $theReverse;
  $theMixed = 'off' unless $theMixed;
  $theErrors = 'on' unless $theErrors;
  $theSelect = '' unless $theSelect;
  $theAbstracts = 'off' unless $theAbstracts;
  $theKeywords = 'off' unless $theKeywords;
  $theTotal = 'off' unless $theTotal;
  $theForm = 'off' unless $theForm;
  $theDisplay = 'on' unless $theDisplay;
  $usecites = 'off' unless $usecites;
  $theBibfile = '.*\.bib' unless $theBibfile;

  # replace single quote with double quote in theSelect
  $theSelect =~ s/'/"/go;

  &writeDebug("theTopic=$theTopic");
  &writeDebug("theSelect=$theSelect");
  &writeDebug("theStyle=$theStyle");
  &writeDebug("theSort=$theSort");
  &writeDebug("theReverse=$theReverse");
  &writeDebug("theMixed=$theMixed");
  &writeDebug("theErrors=$theErrors");
  &writeDebug("theForm=$theForm");
  &writeDebug("theAbstracts=$theAbstracts");
  &writeDebug("theKeywords=$theKeywords");
  &writeDebug("theTotal=$theTotal");
  &writeDebug("theDisplay=$theDisplay");
  &writeDebug("theBibfile=$theBibfile");
  &writeDebug("usecites=$usecites");
  &writeDebug("$defaultSearchTemplate;");

  # extract webName and topicName
  my $formTemplate = "";
  if ($theForm eq "off") {
    $formTemplate = "";
  } elsif ($theForm eq "on") {
    $formTemplate = $defaultSearchTemplate;
  } elsif ($theForm eq "only") {
    $formTemplate = $defaultSearchTemplate;
    $theSelect = '(author : "(null)")';
    $theErrors = "off";
  } else {
    $formTemplate = $theForm;
  }

  my ($formWebName, $formTopicName) = &scanWebTopic($formTemplate)
    if $formTemplate;
  &writeDebug("formWebName=$formWebName") if $formTemplate;
  &writeDebug("formTopicName=$formTopicName") if $formTemplate;

  my ($webName, $topicName) = &scanWebTopic($theTopic) if $theTopic;
  &writeDebug("webName=$webName") if $theTopic;
  &writeDebug("topicName=$topicName") if $theTopic;

  # check for error
  return &showError("topic '$theTopic' not found")
    if !$theBibtext && !&Foswiki::Func::topicExists($webName, $topicName);
  return &showError("topic '$formTemplate' not found")
    if $formTemplate
      && !&Foswiki::Func::topicExists($formWebName, $formTopicName);

  # get bibtex database
  my @bibfiles = ();
  if (!$theBibtext) {
    @bibfiles = &getBibfiles($webName, $topicName, $theBibfile);
    &writeDebug("@bibfiles = getBibfiles($webName, $topicName, $theBibfile);");
    if (!@bibfiles) {
      &writeDebug("no bibfiles found at $webName.$topicName");
      &writeDebug("... trying inlined $webName.$topicName now");
      my ($meta, $text) = &Foswiki::Func::readTopic($webName, $topicName);
      if ($text =~ /%STARTBIBTEX.*?%(.*?)%STOPBIBTEX%/gs) {
        $theBibtext = $1;
        &writeDebug("found inline bibtex database at $webName.$topicName");
      } else {
        ($webName, $topicName) = &scanWebTopic($defaultTopic);
        &writeDebug("... trying $webName.$topicName now");
        return &showError("topic '$defaultTopic' not found")
          if !&Foswiki::Func::topicExists($webName, $topicName);
        @bibfiles = &getBibfiles($webName, $topicName, $theBibfile);

        if (!@bibfiles) {
          &writeDebug("no bibfiles found at $webName.$topicName");
          &writeDebug("... trying inlined $webName.$topicName now");
          ($meta, $text) = &Foswiki::Func::readTopic($webName, $topicName);
          if ($text =~ /%STARTBIBTEX.*?%(.*)%STOPBIBTEX%/gs) {
            $theBibtext = $1;
            &writeDebug("found inline bibtex database at $webName.$topicName");
          }
        }
      }
    }
    return &showError("no bibtex database found.")
      if !@bibfiles && !$theBibtext;

    &writeDebug("bibfiles=<" . join(">, <", @bibfiles) . ">")
      if @bibfiles;
  }

  &writeDebug("webName=$webName, topicName=$topicName");

  # set the current bib topic used in CITE
  $currentBibWeb = $webName;
  $currentBibTopic = $topicName;

  if ($theDisplay eq "on") {

    # generate a temporary bibfile for inline stuff
    my $tempBibfile;
    if ($theBibtext) {
      $tempBibfile = &getTempFileName("bibfile") . '.bib';
      open(BIBFILE, ">$tempBibfile");
      print BIBFILE "$theBibtext\n";
      close BIBFILE;
      push @bibfiles, $tempBibfile;
    }

    my $stdErrFile = &getTempFileName("BibtexPlugin");

    # raw mode
    if ($theStyle eq "raw") {
      &writeDebug("reading from process $cmdTemplate");
      ($result, $code) = Foswiki::Sandbox->sysCommand(
        $cmdTemplate,
        MODE => 'raw',
        BIBTOOLRSC => $pubDir . '/System/BibtexPlugin/bibtoolrsc',
        BIBFILES => \@bibfiles,
        SELECT => $theSelect ? "-c '$theSelect'" : "",
        BIBTEX2HTMLARGS => '',
        STDERR => $stdErrFile,
      );
      &writeDebug("result code $code");
      &writeDebug("result $result");
      &processBibResult(\$result, $webName, $topicName);
      $result = "<div class=\"bibtex\"><pre>\n" . $result . "\n</pre></div>"
        if $result;
      $result .= &renderStderror($stdErrFile)
        if $theErrors eq "on";
    } else {

      # bibtex2html command
      my $bibtex2HtmlArgs = '-nodoc -nobibsource ' .

        #  	'-nokeys ' .
        '-noheader -nofooter ' . '-q ';

      # . '-note annote '
      $bibtex2HtmlArgs .= "-citefile $citefile "
        if ((-f $citefile) and ($usecites eq 'on'));

      if ($theStyle ne 'bibtool') {
        $bibtex2HtmlArgs .= "";    # "-s $theStyle -a ";
      } else {
        $bibtex2HtmlArgs .= ' -dl --use-keys ';
      }
      do {
        $bibtex2HtmlArgs .= '-a ' if $theSort =~ /^(author|name)$/;
        $bibtex2HtmlArgs .= '-d ' if $theSort =~ /^(date|year)$/;
        $bibtex2HtmlArgs .= '-u '
          if $theSort !~ /^(author|name|date|year)$/;
        $bibtex2HtmlArgs .= '-r ' if $theReverse eq 'on';
      } unless ($usecites eq 'on');

      $bibtex2HtmlArgs .= '-single ' if $theMixed eq 'on';

      $bibtex2HtmlArgs .= '--no-abstract ' if $theAbstracts eq 'off';
      $bibtex2HtmlArgs .= '--no-keywords ' if $theKeywords eq 'off';

      &writeDebug("bibtex2HtmlArgs = $bibtex2HtmlArgs");

      # do it
      &writeDebug("reading from process $cmdTemplate");
      my %h = (
        MODE => 'html',
        BIBTOOLRSC => $pubDir . "/System/BibtexPlugin/bibtoolrsc",
        BIBFILES => \@bibfiles,
        SELECT => $theSelect ? "-c '$theSelect'" : '',
        BIBTEX2HTMLARGS => "$bibtex2HtmlArgs",
        STDERR => $stdErrFile
      );
      &writeDebug(join("\n\t", map { "$_ => $h{$_}" } keys %h));

      ($result, $code) = Foswiki::Sandbox->sysCommand($cmdTemplate, %h);

      &writeDebug("result code $code");
      &processBibResult(\$result, $webName, $topicName);
      $result = '<div class="bibtex">' . $result . '</div>'
        if $result;
      $result .= &renderStderror($stdErrFile)
        if $theErrors eq 'on';

    }

    my $count = () = $result =~ /<dt>/g if $theTotal eq "on";
    $result = "<!-- \U$pluginName\E BEGIN --><noautolink>" . $result;
    $result .= "<br />\n<b>Total</b>: $count<br />\n" if $theTotal eq "on";
    $result .= "<!-- \U$pluginName\E END --></noautolink>";

    unlink($stdErrFile) unless ($debug);
    unlink($tempBibfile) if ($tempBibfile and !($debug));
  }

  # insert into the bibsearch form
  if ($formTemplate) {
    my ($meta, $text) = &Foswiki::Func::readTopic($formWebName, $formTopicName);
    writeDebug("reading formTemplate $formWebName.$formTopicName");
    $text =~ s/.*?%STARTINCLUDE%//s;
    $text =~ s/%STOPINCLUDE%.*//s;
    $text =~ s/%BIBFORM%/$formWebName.$formTopicName/g;
    $text =~ s/%BIBTOPIC%/$webName.$topicName/g;
    $text =~ s/%BIBERRORS%/$theErrors/g;
    $text =~ s/%BIBABSTRACT%/$theAbstracts/g;
    $text =~ s/%BIBKEYWORDS%/$theKeywords/g;
    $text =~ s/%BIBTOTAL%/$theTotal/g;
    $text =~ s/%BIBTEXRESULT%/$result/o;
    $text =~ s/%BIBSTYLE%/$theStyle/o;
    $result = $text;
  }

  # add style
  my $styleUrl = Foswiki::Func::getPreferencesValue("BIBTEXPLUGIN_STYLE")
    || $hostUrl . $pubUrlPath . "/" . $Foswiki::cfg{SystemWebName} . "/BibtexPlugin/style.css";
  $result .= "<style type=\"text/css\">\@import url(\"$styleUrl\");</style>\n";

  #&writeDebug("result='$result'");
  &writeDebug("handleBibtex( ) done");
  return $result;
}

###############################################################################
sub processBibResult {
  my ($result, $webName, $topicName) = @_;
  while ($$result =~ s/<\/dl>.+\n/<\/dl>/o) { };    # strip bibtex2html disclaimer

  $$result =~ s/<dl>\s*<\/dl>//go;
  $$result =~ s/\@COMMENT.*\n//go;                  # bib2bib comments
  $$result =~ s/Keywords: (<b>Keywords<\/b>.*?)(<(?:b|\/dd)>)/<div class="bibkeywords">$1<\/div>$2/gso;
  $$result =~ s/(<b>Abstract<\/b>.*?)(<(?:b|\/dd)>)/<div class="bibabstract">$1<\/div>$2/gso;
  $$result =~ s/(<b>Comment<\/b>.*?)(<(?:b|\/dd)>)/<div class="bibcomment">$1<\/div>$2/gso;
  $$result =~ s/<\/?(p|blockquote|font)\>.*?>//go;
  $$result =~ s/<br \/>\s*\[\s*(.*)\s*\]/ <nobr>($1)<\/nobr>/g;    # remove br before url
  $$result =~ s/a href=".\/([^"]*)"/a href="$pubUrlPath\/$webName\/$topicName\/$1"/g;    # link to the pubUrlPath
  $$result =~ s/\n\s*\n/\n/g;                                                            # emtpy lines
  $$result =~ s/^\s+//go;
  $$result =~ s/\s+$//go;
}

###############################################################################
sub renderStderror {

  my $errors;

  foreach my $file (@_) {
    next if !$file;
    $errors .= &Foswiki::Func::readFile($file);
  }
  if ($errors) {

    # strip useless stuff
    $errors =~ s/BibTool ERROR: //og;
    $errors =~ s/condition/select/go;    # rename bib2bib condition to select
    $errors =~ s/^Fatal error.*Bad file descriptor.*$//gom;
    $errors =~ s/^Sorting\.\.\.done.*$//mo;
    $errors =~ s/^\s+//mo;
    $errors =~ s/\s+$//mo;
    $errors =~ s/\n\s*\n/\n/og;
    $errors =~ s/ in \/tmp\/bibfile.*\)/)/go;
    $errors =~ s/$pubDir\/(.*)\/(.*)\/(.*)/$1.$2:$3/g;

    if ($errors) {
      return "<font color=\"red\"><b>BibtexPlugin Errors:</b><br/>\n<pre>\n" . $errors . "\n</pre>\n</font>";
    }
  }

  return "";
}

###############################################################################
sub getTempFileName {
  my $name = shift;
  $name = "" unless $name;

  my $temp_dir = -d '/tmp' ? '/tmp' : $ENV{TMPDIR} || $ENV{TEMP};
  my $base_name = sprintf("%s/$name-%d-%d-0000", $temp_dir, $$, time());
  my $count = 0;
  while (-e $base_name && $count < 100) {
    $count++;
    $base_name =~ s/-(\d+)$/"-" . (1 + $1)/e;
  }

  if ($count == 100) {
    return undef;
  } else {
    return Foswiki::Sandbox::normalizeFileName($base_name);
  }
}

###############################################################################
sub scanWebTopic {
  my $webTopic = shift;

  my $topicName = $topic;    # default to current topic
  my $webName = $web;        # default to current web

  my $topicRegex = &Foswiki::Func::getRegularExpression('mixedAlphaNumRegex');
  my $webRegex = &Foswiki::Func::getRegularExpression('webNameRegex');

  if ($webTopic) {
    $webTopic =~ s/^\s+//o;
    $webTopic =~ s/\s+$//o;
    if ($webTopic =~ /^($topicRegex)$/) {
      $topicName = $1;
    } elsif ($webTopic =~ /^($webRegex)\.($topicRegex)$/) {
      $webName = $1;
      $topicName = $2;
    }
  }

  return ($webName, $topicName);
}

###############################################################################
sub getBibfiles {
  my ($webName, $topicName, $bibfile) = @_;
  my @bibfiles = ();

  $bibfile = ".*\.bib" if !$bibfile;

  my ($meta, $text) = &Foswiki::Func::readTopic($webName, $topicName);

  my @attachments = $meta->find('FILEATTACHMENT');
  foreach my $attachment (@attachments) {
    if ($attachment->{name} =~ /^$bibfile$/) {
      push @bibfiles, Foswiki::Sandbox::normalizeFileName("$pubDir/${webName}/${topicName}/$attachment->{name}");
    }
  }

  return @bibfiles;
}

###############################################################################
sub showError {
  my $msg = shift;
  return "<span class='foswikiAlert'>Error: $msg</span>";
}

1;
