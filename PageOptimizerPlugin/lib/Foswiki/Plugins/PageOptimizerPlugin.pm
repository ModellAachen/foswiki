# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2012 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 2 as published by the Free Software Foundation.
# For more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

package Foswiki::Plugins::PageOptimizerPlugin;

use strict;
use warnings;

use Foswiki::Func ();    # The plugins API
use Foswiki::Plugins (); # For the API version
use Digest::MD5 ();
use URI ();
use Compress::Zlib ();

our $VERSION = '$Rev$';
our $RELEASE = '0.04';
our $SHORTDESCRIPTION = 'Optimize html markup, as well as js and css';
our $NO_PREFS_IN_TOPIC = 1;
our $pluginName = 'PageOptimizerPlugin';

use constant DEBUG => 0;    # toggle me

###############################
sub initPlugin {

  Foswiki::Func::registerRESTHandler('statistics', sub {
    require Foswiki::Plugins::PageOptimizerPlugin::Stats;
    return Foswiki::Plugins::PageOptimizerPlugin::Stats::restStatistics(@_);
  });

  return 1;
}

###############################
sub writeDebug {
  return unless DEBUG;
  print STDERR "- $pluginName - " . $_[0] . "\n";
}

###############################
sub completePageHandler {
  my $text = $_[0];
  my $header = $_[1];

  return unless $header =~ /Content-type: text\/html/;

  writeDebug("completePageHandler()");

  # clean up
  if ($Foswiki::cfg{PageOptimizerPlugin}{CleanUpHTML}) {
    $text =~ s/<!--.*?-->//g;
    $text =~ s/^\s*$//gms;
    $text =~ s/(<\/html>).*?$/$1/gs;
    
    # EXPERIMENTAIL: make at least some <p>s real paragraphs
    if (1) {
      $text =~ s/<p><\/p>\s*([^<>]+?)\s*(?=<p><\/p>)/<p class='p'>$1<\/p>\n\n/gs;
    }
    $text =~ s/\s*<\/p>(?:\s*<p><\/p>)*/<\/p>\n/gs; # remove useless <p>s

    # clean up %{<verbatim>}% ...%{</verbatim>}%
    $text =~ s/\%{(<pre[^>]*>)}&#37;\s*/$1/g;
    $text =~ s/\s*&#37;{(<\/pre>)}\%/$1/g;

    $text =~ s/<script +type=["']text\/javascript["']/<script/g;
    $text =~ s/<style +type=["']text\/css["']/<style/g;
    $text =~ s/<link (.*?rel=["']stylesheet["'].*?)\/>/_processLinkStyle($1)/ge;
  }

  my $query = Foswiki::Func::getCgiQuery();
  my $refresh = $query->param("refresh") || '';
  purgeCache() if $refresh =~ /\ball\b/;

  $text = optimizeJavaScript($text) if $Foswiki::cfg{PageOptimizerPlugin}{OptimizeJavaScript};
  $text = optimizeStylesheets($text) if $Foswiki::cfg{PageOptimizerPlugin}{OptimizeStylesheets};

  $text =~ s/^\s+$//gms;    # remove a few empty lines

  # return the changed text
  $_[0] = $text;
}

###############################
sub _processLinkStyle {
  my $args = shift;
  $args =~ s/type=["'].*?["']//g;
  return "<link $args/>";
}


###############################
sub preRenderingHandler {
  # better cite markup
  $_[0] =~ s/[\n\r](>.*?)([\n\r][^>])/_processCite($1).$2/ges;
}

###############################
sub _processCite {
  my $block = shift;

  $block =~ s/^>/<span class='foswikiCiteChar'>&gt;<\/span>/gm;
  $block =~ s/\n/<br \/>\n/g;

  my $class = ($block =~ /<br \/>/)?'foswikiBlockCite':'foswikiCite';

  return "<div class='$class'>".$block."</div>";
}

###############################
sub optimizeJavaScript {
  my $text = shift;

  # take out ie stuff
  my @ieConditionals = ();
  my $index = 0;
  while ($text =~ s/(<!\-\- +\[if.*?<!\[endif\]\-\->)/\0ie$index/s) {

    writeDebug("found ie conditional: $1");
    push @ieConditionals, $1;
    $index++;
  }

  # collect all javascript
  my @jsUrls = ();
  my $excludePattern = '';
  $excludePattern = '(?!.*'.$Foswiki::cfg{PageOptimizerPlugin}{ExcludeJavaScript}.')'
    if defined $Foswiki::cfg{PageOptimizerPlugin}{ExcludeJavaScript};

  while ($text =~ s/<script .*?src=["'](\/$excludePattern[^"']+)["'].*><\/script>/\0js\0/) {
    push @jsUrls, $1;
  }

  # put back ie stuff
  $index = 0;
  foreach my $cond (@ieConditionals) {
    $text =~ s/\0ie$index/$cond/;
  }

  return $text unless @jsUrls;

  # check if there's a cache file already
  my ($cacheFileName, $cacheUrl) = getCacheEntry("js", \@jsUrls);

  my $query = Foswiki::Func::getCgiQuery();
  my $refresh = $query->param("refresh") || '';

  if (DEBUG || $refresh =~ /\b(on|all|cache|js)\b/ || !-f $cacheFileName) {    
    # TODO: compare timestamps of files
    writeDebug("creating cache at $cacheFileName");

    my $cachedData = '';

    foreach my $url (@jsUrls) {
      writeDebug("url=$url");
      my $fileName = url2FileName($url);
      if (-f $fileName) {
        my $data = Foswiki::Func::readFile($fileName);
        if ($data) {
          $cachedData .= "\n\n/* DEBUG: fileName=$fileName */\n"
            if DEBUG;
          $cachedData .= $data;
        }
      } else {
        print STDERR "woops $fileName does not exist\n";
      }
    }

    # save the cached javascript
    Foswiki::Func::saveFile($cacheFileName, $cachedData);

    # create a gzip'ed version as well
    $cachedData = Compress::Zlib::memGzip($cachedData);
    Foswiki::Func::saveFile($cacheFileName . '.gz', $cachedData);

    logJavaScript(\@jsUrls);
  }


  # insert the cached javascript at the first position we've found a js url
  $text =~ s/\0js\0/<script src='$cacheUrl'><\/script>/;

  # remove the rest
  $text =~ s/\0js\0//g;

  return $text;
}

###############################
sub optimizeStylesheets {
  my $text = shift;

  # collect all css
  my @cssUrls = ();

  $text =~ s/(?:<(link)\s+rel=["']stylesheet["']\s+href=["'](\/[^"']+)["']\s+media=["']all["'][^\/>]*?\/?>)|(?:<(style)\s+.*?media=["']all["'][^>]*?>(.*?)<\/style>)/_gatherCssUrls(\@cssUrls, $1||$3, $2||$4)/ges;

  return $text unless @cssUrls;

  my ($cacheFileName, $cacheUrl) = getCacheEntry("css", \@cssUrls);

  my $query = Foswiki::Func::getCgiQuery();
  my $refresh = $query->param("refresh") || '';

  if (DEBUG || $refresh =~ /\b(on|all|cache|css)\b/ || !-f $cacheFileName) {    
    # TODO: compare timestamps of files
    writeDebug("creating cache at $cacheFileName");

    my $cachedData = '';

    foreach my $url (@cssUrls) {
      my $data = parseStylesheet($url);
      $cachedData .= $data if $data;
    }

    Foswiki::Func::saveFile($cacheFileName, $cachedData);
    $cachedData = Compress::Zlib::memGzip($cachedData);
    Foswiki::Func::saveFile($cacheFileName . '.gz', $cachedData);

    logStylesheet(\@cssUrls);
  }

  $text =~ s/\0css\0/<link rel='stylesheet' href='$cacheUrl' media='all' \/>/;
  $text =~ s/\0css\0//g;

  return $text;
}

###############################
sub _gatherCssUrls {
  my ($cssUrls, $type, $data) = @_;

  # link tag
  if ($type eq 'link') {
    my $excludePattern;
    $excludePattern = $Foswiki::cfg{PageOptimizerPlugin}{ExcludeCss}
      if defined $Foswiki::cfg{PageOptimizerPlugin}{ExcludeCss};

    if (defined($excludePattern) && $data =~ /$excludePattern/) {
      return "<style media='all'>$data</style>";
    }

    #writeDebug("found url $data in link tag");
    push @$cssUrls, $data;
    return "\0css\0";
  }

  # style block
  while ($data =~ s/\@import +url\(["']?(.*?)["']?\);//) {
    push @$cssUrls, $1;
    writeDebug("found url $1 in style block");
  }

  # test for an empty style block
  if ($data =~ /^\s*$/s) {
    return "\0css\0";
  }

  # return the rest of the style block
  return "\0css\0<style media='all'>$data</style>";
}

###############################
sub parseStylesheet {
  my ($url, $baseUrl) = @_;

  $baseUrl ||= $url;
  $baseUrl =~ s/\?.*?$//;

  my $fileName = url2FileName($url);

  #writeDebug("baseUrl=$baseUrl");
  #writeDebug("fileName=$fileName");

  my $data = '';

  if (-f $fileName) {
    $data = Foswiki::Func::readFile($fileName);

    $data =~ s/url\(["']?(.*?)["']?\)/"url(".rewriteUrl($1, $baseUrl).")"/ge;
    $data =~ s/\@import +url\(["']?(.*?)["']?\);/parseStylesheet($1)/ge;

  } else {
    print STDERR "woops $fileName does not exist\n";
  }

  return $data;
}

###############################
sub purgeCache {

  my $cacheDir = $Foswiki::cfg{PubDir} . '/' . $Foswiki::cfg{SystemWebName} . '/' . $pluginName . '/cache/';

  opendir(my $dh, $cacheDir);
  my @files = map { Foswiki::Sandbox::normalizeFileName($cacheDir . '/' . $_) } grep { !/^(\.|README)/ } readdir $dh;
  closedir $dh;

  #writeDebug("cleaning up @files");
  unlink @files;
}

###############################
sub getCacheEntry {
  my ($type, $urls) = @_;

  my $fileName = Digest::MD5::md5_hex(@$urls) . '.' . $type;

  my $cacheDir = $Foswiki::cfg{PubDir} . '/' . $Foswiki::cfg{SystemWebName} . '/' . $pluginName . '/cache/';

  mkdir $cacheDir unless -d $cacheDir;

  my $cachePath = $Foswiki::cfg{PubUrlPath} . '/' . $Foswiki::cfg{SystemWebName} . '/' . $pluginName . '/cache/';

  return ($cacheDir . $fileName, $cachePath . $fileName);
}

###############################
sub url2FileName {
  my $url = shift;

  my $fileName = $url;
  $fileName =~ s/$Foswiki::cfg{PubUrlPath}/$Foswiki::cfg{PubDir}/;
  $fileName =~ s/^$Foswiki::cfg{DefaultUrlHost}//;
  $fileName =~ s/\?.*$//;

  return $fileName;
}

###############################
sub rewriteUrl {
  my ($url, $baseUrl) = @_;

  return $url if $url =~ /^(data|https?):/;

  #writeDebug("rewriteUrl($url, $baseUrl)");

  my $uri = URI->new($url);
  $url = $uri->abs($baseUrl);

  #writeDebug("... url=$url");

  return $url;
}

###############################
sub logJavaScript {

  return unless $Foswiki::cfg{PageOptimizerPlugin}{GatherStatistics};

  require Foswiki::Plugins::PageOptimizerPlugin::Stats;
  Foswiki::Plugins::PageOptimizerPlugin::Stats::logJavaScript(@_);
}

###############################
sub logStylesheet {

  return unless $Foswiki::cfg{PageOptimizerPlugin}{GatherStatistics};
  
  require Foswiki::Plugins::PageOptimizerPlugin::Stats;
  Foswiki::Plugins::PageOptimizerPlugin::Stats::logStylesheet(@_);
}


1;
