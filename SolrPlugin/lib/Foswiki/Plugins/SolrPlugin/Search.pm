# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009-2011 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package Foswiki::Plugins::SolrPlugin::Search;
use strict;

use Foswiki::Plugins::SolrPlugin::Base ();
our @ISA = qw( Foswiki::Plugins::SolrPlugin::Base );

use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::Plugins::JQueryPlugin ();
use POSIX ();
use Error qw(:try);

use constant DEBUG => 0; # toggle me

##############################################################################
sub new {
  my ($class, $session) = @_;

  my $this = $class->SUPER::new($session);

  $this->{url} = 
    $Foswiki::cfg{SolrPlugin}{SearchUrl} || $Foswiki::cfg{SolrPlugin}{Url};

  throw Error::Simple("no solr url defined") unless defined $this->{url};

  if (!$this->connect() && $Foswiki::cfg{SolrPlugin}{AutoStartDaemon}) {
    $this->startDaemon();
    $this->connect();
  }

  unless ($this->{solr}) {
    $this->log("ERROR: can't conect solr daemon");
  }

  return $this;
}


##############################################################################
sub handleSOLRSEARCH {
  my ($this, $params, $theWeb, $theTopic) = @_;

  #$this->log("called handleSOLRSEARCH(".$params->stringify.")") if DEBUG;
  return $this->inlineError("can't connect to solr server") unless defined $this->{solr};

  my $theId = $params->{id};
  return '' if defined $theId && defined $this->{cache}{$theId};

  my $theQuery = $params->{_DEFAULT} || $params->{search} || '';;
  $theQuery = $this->entityDecode($theQuery);
  $params->{search} = $theQuery;

  $theQuery = $this->toUtf8($theQuery);

  my $theJump = Foswiki::Func::isTrue($params->{jump});

  if ($theJump && $theQuery) {
    # redirect to topic
    my ($web, $topic) = $this->normalizeWebTopicName($theWeb, $theQuery);

    if (Foswiki::Func::topicExists($web, $topic)) {
      my $url = Foswiki::Func::getScriptUrl($web, $topic, 'view');
      $this->{redirectUrl} = $url;
      return '';
    }
  }

  my $response = $this->doSearch($theQuery, $params);
  return '' unless defined $response;

  if (defined $theId) {
    $this->{cache}{$theId} = {
        response=>$response,
        params=>$params,
    };
  } 

  # I feel lucky: redirect to first result
  my $theLucky = Foswiki::Func::isTrue($params->{'lucky'});
  if ($theLucky) {
    my $url = $this->getFirstUrl($response);
    if ($url) {
      # will redirect in finishPlugin handler
      $this->{redirectUrl} = $url;
      return "";
    }
  }

  return $this->formatResponse($params, $theWeb, $theTopic, $response);
}

##############################################################################
sub handleSOLRFORMAT {
  my ($this, $params, $theWeb, $theTopic) = @_;

  #$this->log("called handleSOLRFORMAT(".$params->stringify.")") if DEBUG;
  return '' unless defined $this->{solr};

  my $theId = $params->{_DEFAULT} || $params->{id};
  return $this->inlineError("unknown query id") unless defined $theId;

  my $cacheEntry = $this->{cache}{$theId};
  return $this->inlineError("unknown query '$theId'") unless defined $cacheEntry;

  $params = {%{$cacheEntry->{params}}, %$params};

  return $this->formatResponse($params, $theWeb, $theTopic, $cacheEntry->{response});
}


##############################################################################
sub formatResponse {
  my ($this, $params, $theWeb, $theTopic, $response) = @_;

  return '' unless $response;

  my $error;
  my $gotResponse = 0;
  try {
    $gotResponse = 1 if $response->content->{response};
  } catch Error::Simple with {
    $this->log("Error parsing solr response") if DEBUG;
    $error = $this->inlineError("Error parsing solr response");
  };
  return $error if $error;
  return '' unless $gotResponse;


  #$this->log("called formatResponse()") if DEBUG;

  Foswiki::Plugins::JQueryPlugin::createPlugin("metadata");
  Foswiki::Plugins::JQueryPlugin::createPlugin("focus");
  Foswiki::Plugins::JQueryPlugin::createPlugin("ui");

  Foswiki::Func::addToZone('head', "SOLRPLUGIN", <<'HERE', "JQUERYPLUGIN::AUTOCOMPLETE, JQUERYPLUGIN::FOCUS, JQUERYPLUGIN::METADATA");
<link rel='stylesheet' href='%PUBURLPATH%/%SYSTEMWEB%/SolrPlugin/solrplugin.css' type='text/css' media='all' />
HERE
  Foswiki::Func::addToZone('script', "SOLRPLUGIN", <<'HERE', "JQUERYPLUGIN::AUTOCOMPLETE, JQUERYPLUGIN::FOCUS, JQUERYPLUGIN::METADATA");
<script type='text/javascript' src='%PUBURLPATH%/%SYSTEMWEB%/SolrPlugin/solrplugin.js'></script>
HERE

  my $theFormat = $params->{format} || '';
  my $theSeparator = $params->{separator} || '';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theCorrection = $params->{correction} || 
    'Did you mean <a href=\'$url\' class=\'solrCorrection\'>%ENCODE{"$correction" type="quote"}%</a>';
  my $theInterestingHeader = $params->{header_interesting} || '';
  my $theInterestingFormat = $params->{format_interesting} || '';
  my $theInterestingSeparator = $params->{separator_interesting} || '';
  my $theInterestingFooter = $params->{footer_interesting} || '';
  my $theInterestingExclude = $params->{exclude_interesting} || '';
  my $theInterestingInclude = $params->{include_interesting} || '';
  my $theFacets = $params->{facets};
  my $theHideSingle = $params->{hidesingle} || '';

  my %hideSingleFacets = map {$_ => 1} split(/\s*,\s*/, $theHideSingle);

  my $hilites;
  if ($theFormat =~ /\$hilite/ || $theHeader =~ /\$hilite/ || $theFooter =~ /\$hilite/) {
    $hilites = $this->getHighlights($response);
  }

  my $moreLikeThis;
  if ($theFormat =~ /\$morelikethis/ || $theHeader =~ /\$morelikethis/ || $theFooter =~ /\$morelikethis/) {
    $moreLikeThis = $this->getMoreLikeThis($response);
  }

  my $spellcheck = '';
  if ($theFormat =~ /\$spellcheck/ || $theHeader =~ /\$spellcheck/ || $theFooter =~ /\$spellcheck/) {
    my $correction = $this->getCorrection($response);
    if ($correction) {
      my $tmp = $params->{search};
      $params->{search} = $correction;
      my $scriptUrl = $this->getScriptUrl($theWeb, $theTopic, $params, $response);
      $spellcheck = $theCorrection;
      $spellcheck =~ s/\$correction/$correction/g;
      $spellcheck =~ s/\$url/$scriptUrl/g;
    }
  }

  my $page = $this->currentPage($response);
  my $limit = $this->entriesPerPage($response);
  my @rows = ();
  my $index = $page * $limit + 1;
  my $from = $index;
  my $to = $index + $limit - 1;
  my $count = $this->totalEntries($response);
  $to = $count if $to > $count;

  #$this->log("page=$page, limit=$limit, index=$index, count=$count") if DEBUG;
  
  if ($theFormat) {
    for my $doc ($response->docs) {
      my $line = $theFormat;
      my $id = '';
      my $type = '';
      my $topic;
      my $web;
      my $summary = '';

      foreach my $field ($doc->fields) {
        my $name = $field->{name};
        next unless $line =~ /\$$name/g;

        my $value = $field->{value};
	$name = $this->fromUtf8($name);
      	$value = $this->fromUtf8($value);

        $id = $value if $name eq 'id';
        $type = $value if $name eq 'type';
        $web = $value if $name eq 'web';
        $topic = $value if $name eq 'topic';
        $summary = $value if $name eq 'summary';

        $value = sprintf('%.02f', $value)
          if $name eq 'score';

        if ($this->isDateField($name)) {
          $line =~ s/\$$name\((.*?)\)/Foswiki::Time::formatTime(Foswiki::Time::parseTime($value), $1)/ge;
          $line =~ s/\$$name\b/Foswiki::Time::formatTime(Foswiki::Time::parseTime($value), '$day $mon $year')/ge;
        } else {
          $value = sprintf("%.02f kb", ($value / 1024))
            if $name eq 'size' && $value =~ /^\d+$/;
          $line =~ s/\$$name\b/$value/g;
        }

      }
      next unless Foswiki::Func::topicExists($web, $topic);

      my $hilite = '';
      $hilite = ($hilites->{$id} || $summary) if $id && $hilites;

      my $mlt = '';
      $mlt = $moreLikeThis->{$id} if $id && $moreLikeThis;
      if ($mlt) {
        # TODO: this needs serious improvements
        #$line =~ s/\$morelikethis/$mlt->{id}/g;
      }

      my $icon = $this->mapToIconFileName($type);
      my $itemFormat = 'attachment';
      $itemFormat = 'image' if $type =~ /^(gif|jpe?g|png|bmp)$/i;
      $itemFormat = 'topic' if $type eq 'topic';
      $itemFormat = 'comment' if $type eq 'comment';
      $line =~ s/\$format/$itemFormat/g;
      $line =~ s/\$id/$id/g;
      $line =~ s/\$icon/$icon/g;
      $line =~ s/\$index/$index/g;
      $line =~ s/\$page/$page/g;
      $line =~ s/\$limit/$limit/g;
      $line =~ s/\$hilite/$hilite/g;
      $index++;
      push(@rows, $line);
    }
  }

  return '' if !@rows && !$theFacets && !$theInterestingFormat;

  my $facets = $this->getFacets($response);
  my $interestingTerms = $this->getInterestingTerms($response);

  # format facets
  my $facetResult = '';
  if ($facets) {

    foreach my $facetSpec (split(/\s*,\s*/, $theFacets)) {
      my ($facetLabel, $facetID) = parseFacetSpec($this->fromUtf8($facetSpec));
      my $theFacetHeader = $params->{"header_$facetID"} || '';
      my $theFacetFormat = $params->{"format_$facetID"} || '';
      my $theFacetFooter = $params->{"footer_$facetID"} || '';
      my $theFacetSeparator = $params->{"separator_$facetID"} || '';
      my $theFacetExclude = $params->{"exclude_$facetID"};
      my $theFacetInclude = $params->{"include_$facetID"};

      next unless defined $theFacetFormat;

      my $shownFacetLabel = $facetLabel;
      $shownFacetLabel =~ s/_/ /g; #revert whitespace workaround

      my @facetRows = ();
      my $facetTotal = 0;

      # query facets
      if ($facetID eq 'facetquery') {
        my $theFacetQuery = $params->{facetquery} || '';
        my @facetQuery = split(/\s*,\s*/, $theFacetQuery);

        # count rows
        my $len = 0;
        foreach my $querySpec (@facetQuery) {
          my ($key, $query) = parseFacetSpec($querySpec);
          my $count = $facets->{facet_queries}{$key};
          next unless $count;
          next if $theFacetExclude && $key =~ /$theFacetExclude/;
          next if $theFacetInclude && $key !~ /$theFacetInclude/;
          $len++;
        }

        unless ($hideSingleFacets{$facetID} && $len <= 1) {
          foreach my $querySpec (@facetQuery) {
            my ($key, $query) = parseFacetSpec($querySpec);
            my $count = $facets->{facet_queries}{$key};
            next unless $count;
            next if $theFacetExclude && $key =~ /$theFacetExclude/;
            next if $theFacetInclude && $key !~ /$theFacetInclude/;
            $facetTotal += $count;
            my $line = $theFacetFormat;
            $key =~ s/_/ /g; #revert whitespace workaround
            $line =~ s/\$key\b/$key/g;
            $line =~ s/\$query\b/$query/g;
            $line =~ s/\$count\b/$count/g;
            push(@facetRows, $line);
          }
        }
      }

      # date facets
      elsif ($this->isDateField($facetID)) {
        my $facet = $facets->{facet_ranges}{$facetLabel};
        next unless $facet;
        $facet = $facet->{counts};

        # count rows
        my $len = 0;
        for(my $i = 0; $i < scalar(@$facet); $i+=2) {
          my $key = $facet->[$i];
          my $count = $facet->[$i+1];
          next unless $count;
          next if $theFacetExclude && $key =~ /$theFacetExclude/;
          next if $theFacetInclude && $key !~ /$theFacetInclude/;
          $len++;
        }

        unless ($hideSingleFacets{$facetID} && $len <= 1) {
          for(my $i = 0; $i < scalar(@$facet); $i+=2) {
            my $key = $facet->[$i];
            my $count = $facet->[$i+1];
            next unless $count;
            $key = $this->fromUtf8($key);
            next if $theFacetExclude && $key =~ /$theFacetExclude/;
            next if $theFacetInclude && $key !~ /$theFacetInclude/;
            $facetTotal += $count;
            my $line = $theFacetFormat;
            $line =~ s/\$key\b/$key/g;
            $line =~ s/\$date\((.*?)\)/Foswiki::Time::formatTime(Foswiki::Time::parseTime($key), $1)/ge;
            $line =~ s/\$date\b/Foswiki::Time::formatTime(Foswiki::Time::parseTime($key), '$day $mon $year')/ge;
            $line =~ s/\$count\b/$count/g;
            push(@facetRows, $line);
          }
        }
      } 
      
      # field facet
      else {
        my $facet = $facets->{facet_fields}{$facetLabel};
        next unless defined $facet;

        # count rows
        my $len = 0;
        my $nrFacetValues = scalar(@$facet);
        for (my $i = 0; $i < $nrFacetValues; $i+=2) {
          my $key = $facet->[$i];
          next unless $key;
          next if $theFacetExclude && $key =~ /$theFacetExclude/;
          next if $theFacetInclude && $key !~ /$theFacetInclude/;
          $len++;
        }

        unless ($hideSingleFacets{$facetID} && $len <= 1) {
          for (my $i = 0; $i < $nrFacetValues; $i+=2) {
            my $key = $facet->[$i];
            next unless $key;

            my $count = $facet->[$i+1];
            $key = $this->fromUtf8($key);

            next if $theFacetExclude && $key =~ /$theFacetExclude/;
            next if $theFacetInclude && $key !~ /$theFacetInclude/;
            my $line = $theFacetFormat;
            $facetTotal += $count;
            $line =~ s/\$key\b/$key/g;
            $line =~ s/\$count\b/$count/g;
            push(@facetRows, $line);
          }
        }
      }
      my $nrRows = scalar(@facetRows);
      if ($nrRows > 0) {
        my $line = $theFacetHeader.join($theFacetSeparator, @facetRows).$theFacetFooter;
        $line =~ s/\$label\b/$shownFacetLabel/g;
        $line =~ s/\$id\b/$facetID/g;
        $line =~ s/\$total\b/$facetTotal/g;
        $line =~ s/\$rows\b/$nrRows/g;
        $facetResult .= $line;
      }
    }
  }

  # format interesting terms
  my $interestingResult = '';
  if ($interestingTerms) {
    my @interestingRows = ();
    while (my $termSpec = shift @$interestingTerms) {
      next unless $termSpec =~ /^(.*):(.*)$/g;
      my $field = $this->fromUtf8($1);
      my $term = $this->fromUtf8($2);
      my $score = shift @$interestingTerms;

      next if $theInterestingExclude && $term =~ /$theInterestingExclude/;
      next if $theInterestingInclude && $term =~ /$theInterestingInclude/;

      my $line = $theInterestingFormat;
      $line =~ s/\$term/$term/g;
      $line =~ s/\$score/$score/g;
      $line =~ s/\$field/$field/g;
      push(@interestingRows, $line);
    }
    if (@interestingRows) {
      $interestingResult = $theInterestingHeader.join($theInterestingSeparator, @interestingRows).$theInterestingFooter;
    }
  }

  my $result = $theHeader.join($theSeparator, @rows).$facetResult.$interestingResult.$theFooter;
  $result =~ s/\$spellcheck/$spellcheck/g;
  $result =~ s/\$count/$count/g;
  $result =~ s/\$from/$from/g;
  $result =~ s/\$to/$to/g;
  $result =~ s/\$name//g; # cleanup
  $result =~ s/\$rows/0/g; # cleanup
  $result =~ s/\$morelikethis//g; # cleanup
  
  if ($params->{fields}) {
    my $cleanupPattern = '('.join('|', split(/\s*,\s*/, $params->{fields})).')';
    $result =~ s/\$$cleanupPattern//g;
  }

  if ($result =~ /\$pager/) {
    my $pager = $this->renderPager($theWeb, $theTopic, $params, $response);
    $result =~ s/\$pager/$pager/g;
  }

  if ($result =~ /\$seconds/) {
    my $seconds = sprintf("%0.3f", ($this->getQueryTime($response) / 1000));
    $result =~ s/\$seconds/$seconds/g;
  }

  # standard escapes
  $result =~ s/\$perce?nt/\%/go;
  $result =~ s/\$nop\b//go;
  $result =~ s/\$n/\n/go;
  $result =~ s/\$dollar/\$/go;

  #$this->log("result=$result");

  return $this->toSiteCharSet($result);
}

##############################################################################
sub renderPager {
  my ($this, $web, $topic, $params, $response) = @_;

  return '' unless $response;

  my $lastPage = $this->lastPage($response);
  return '' unless $lastPage > 0;

  my $currentPage = $this->currentPage($response);
  my $result = '';
  if ($currentPage > 0) {
    my $scriptUrl = $this->getScriptUrl($web, $topic, $params, $response, $currentPage-1);
    $result .= "<a href='$scriptUrl' class='solrPagerPrev'>%MAKETEXT{\"Previous\"}%</a>";
  } else {
    $result .= "<span class='solrPagerPrev foswikiGrayText'>%MAKETEXT{\"Previous\"}%</span>";
  }

  my $startPage = $currentPage - 4;
  my $endPage = $currentPage + 4;
  if ($endPage >= $lastPage) {
    $startPage -= ($endPage-$lastPage+1);
    $endPage = $lastPage;
  }
  if ($startPage < 0) {
    $endPage -= $startPage;
    $startPage = 0;
  }
  $endPage = $lastPage if $endPage > $lastPage;

  if ($startPage > 0) {
    my $scriptUrl = $this->getScriptUrl($web, $topic, $params, $response, 0);
    $result .= "<a href='$scriptUrl'>1</a>";
  }

  if ($startPage > 1) {
    $result .= "<span class='solrPagerEllipsis'>&hellip;</span>";
  }

  #$this->log("currentPage=$currentPage, lastPage=$lastPage, startPage=$startPage, endPage=$endPage") if DEBUG;

  my $count = 1;
  my $marker = '';
  for (my $i = $startPage; $i <= $endPage; $i++) {
    my $scriptUrl = $this->getScriptUrl($web, $topic, $params, $response, $i);
    $marker = $i == $currentPage?'current':'';
    $result .= "<a href='$scriptUrl' class='$marker'>".($i+1)."</a>";
    $count++;
  }

  if ($endPage < $lastPage-1) {
    $result .= "<span class='solrPagerEllipsis'>&hellip;</span>"
  }

  if ($endPage < $lastPage) {
    my $scriptUrl = $this->getScriptUrl($web, $topic, $params, $response, $lastPage);
    $marker = $currentPage == $lastPage?'current':'';
    $result .= "<a href='$scriptUrl' class='$marker'>".($lastPage+1)."</a>";
  }

  if ($currentPage < $lastPage) {
    my $scriptUrl = $this->getScriptUrl($web, $topic, $params, $response, $currentPage+1);
    $result .= "<a href='$scriptUrl' class='solrPagerNext'>%MAKETEXT{\"Next\"}%</a>";
  } else {
    $result .= "<span class='solrPagerNext foswikiGrayText'>%MAKETEXT{\"Next\"}%</span>";
  }

  if ($result) {
    $result = "<div class='solrPager'>$result</div>"
  }

  return $result;
}

##############################################################################
sub restSOLRSEARCH {
  my ($this, $theWeb, $theTopic) = @_;

  return '' unless defined $this->{solr};
  my $query = Foswiki::Func::getCgiQuery();

  $theWeb ||= $this->{session}->{webName};
  $theTopic ||= $this->{session}->{topicName};

  my $theQuery = $query->param('q') || $query->param('search');
  my %params = map {$_ => $query->param($_)} $query->param();
  my $response = $this->doSearch($theQuery, \%params);

  # I feel lucky: redirect to first result
  my $theLucky = Foswiki::Func::isTrue($query->param('lucky'));
  if ($theLucky) {
    my $url = $this->getFirstUrl($response);
    if ($url) {
      # will redirect in finishPlugin handler
      $this->{redirectUrl} = $url;
      return "\n\n";
    }
  }

  my $result = '';
  try {
    $result = $response->raw_response->content();
    $result = $this->fromUtf8($result);
  } catch Error::Simple with {
    $result = "Error parsing response";
  };

  return $result."\n\n";
}

##############################################################################
sub getFirstUrl {
  my ($this, $response) = @_;

  my $url;

  if ($this->totalEntries($response)) {
    for my $doc ($response->docs) {
      $url = $doc->value_for("url");
      last if $url;
    }
  }

  return $url;
}

##############################################################################
sub restSOLRAUTOCOMPLETE {
  my ($this, $theWeb, $theTopic) = @_;

  return '' unless defined $this->{solr};
  my $query = Foswiki::Func::getCgiQuery();

  my $isNewAutocomplete = ($Foswiki::Plugins::JQueryPlugin::RELEASE > 4.10)?1:0;

  my $theRaw = Foswiki::Func::isTrue($query->param('raw'));
  my $theQuery = $query->param($isNewAutocomplete?'term':'q') || '';
  my $theFilter = $query->param('filter');
  my $theEllipsis = Foswiki::Func::isTrue($query->param('ellipsis'));
  my $thePrefix;
  my $foundPrefix = 0;

  my $wikiUser = Foswiki::Func::getWikiName();
  my @filter = $this->parseFilter($theFilter);
  push(@filter, "(access_granted:$wikiUser OR access_granted:all)") 
    unless Foswiki::Func::isAnAdmin($wikiUser);

  # tokenize here as well to separate query and prefix

  $theQuery =~ s/[\!"§\$%&\/\(\)=\?{}\[\]\*\+~#',\.;:\-_]/ /g;
  $theQuery =~ s/([$Foswiki::regex{lowerAlpha}])([$Foswiki::regex{upperAlpha}$Foswiki::regex{numeric}]+)/$1 $2/go;
  $theQuery =~ s/([$Foswiki::regex{numeric}])([$Foswiki::regex{upperAlpha}])/$1 $2/go;

  # work around solr not doing case-insensitive facet queries
  $theQuery = lc($theQuery);

  if ($theQuery =~ /^(.+) (.+?)$/) {
    $theQuery = $1;
    $thePrefix = $2;
    $foundPrefix = 1;
  } else {
    $thePrefix = $theQuery;
    $theQuery = '*:*';
  }

  my $field = $query->param('field') || 'catchall';

  my $solrParams = {
    "facet.prefix" => $thePrefix,
    "facet" => 'true',
    "facet.mincount" => 1,
    "facet.limit" => ($query->param('limit') || 10),
    "facet.field" => $field,
    "indent" => 'true',
    "rows" => 0,
  };
  $solrParams->{"fq"} = \@filter if @filter;

  my $response = $this->solrSearch($theQuery, $solrParams);

  if ($theRaw) {
    my $result = $response->raw_response->content()."\n\n";
    #$result = $this->fromUtf8($result);
    return $result;
  }
  $this->log($response->raw_response->content()) if DEBUG;

  my $facets = $this->getFacets($response);
  return '' unless $facets;

  # format autocompletion
  #$theQuery = $this->fromUtf8($theQuery); 

  my @result = ();
  foreach my $facet (keys %{$facets->{facet_fields}}) {
    my @facetRows = ();
    my @list = @{$facets->{facet_fields}{$facet}};
    while (my $key = shift @list) {
      my $freq = shift @list;
      $key = $this->fromUtf8($key);
      $key = "$theQuery $key" if $foundPrefix;
      my $title = $key;
      if ($theEllipsis) {
        $title = $key;
        $title =~ s/$thePrefix $theQuery/.../;
      }
      my $line;
      if ($isNewAutocomplete) {
        # jquery-ui's autocomplete takes a json
	$line = "{\"value\":\"$key\", \"label\":\"$title\", \"frequency\":$freq}";
      } else {
        # old jquery.autocomplete takes proprietary format
	$line = "$key|$title|$freq";
      }
      push(@result, $line);
    }
  }

  if ($isNewAutocomplete) {
    return "[\n".join(",\n ", @result)."\n]";
  } else {
    return join("\n", @result)."\n\n";
  }
}

##############################################################################
sub restSOLRSIMILAR {
  my ($this, $theWeb, $theTopic) = @_;

  return '' unless defined $this->{solr};
  my $query = Foswiki::Func::getCgiQuery();
  my $theQuery = $query->param('q');
  $theQuery =  "id:$theWeb.$theTopic" unless defined $theQuery;
  my %params = map {$_ => $query->param($_)} $query->param();
  delete $params{'q'};

  my $response = $this->doSimilar($theQuery, \%params);

  my $result = '';
  try {
    $result = $response->raw_response->content();
    $result = $this->fromUtf8($result);
  } catch Error::Simple with {
    $result = "Error parsing result";
  };

  return $result."\n\n";
}

##############################################################################
sub handleSOLRSIMILAR {
  my ($this, $params, $theWeb, $theTopic) = @_;

  return $this->inlineError("can't connect to solr server") unless defined $this->{solr};

  my $theQuery = $params->{_DEFAULT};
  $theQuery = "id:$theWeb.$theTopic" unless defined $theQuery;

  my $response = $this->doSimilar($theQuery, $params);

  #$this->log($response->raw_response->content()) if DEBUG;
  return $this->formatResponse($params, $theWeb, $theTopic, $response);
}


#############################################################################
sub doSimilar {
  my ($this, $query, $params) = @_;

  #$this->log("doSimilar($query)");

  my $theQuery = $query || $params->{'q'} || '*:*';
  my $theLike = $params->{'like'};
  my $theFields = $params->{'fields'};
  my $theFilter = $params->{'filter'};
  my $theInclude = Foswiki::Func::isTrue($params->{'include'});
  my $theStart = $params->{'start'} || 0;
  my $theRows = $params->{'rows'};
  my $theBoost = Foswiki::Func::isTrue($params->{'boost'}, 1);
  my $theMinTermFreq = $params->{'mintermfrequency'};
  my $theMinDocFreq = $params->{'mindocumentfrequency'};
  my $theMinWordLength = $params->{'mindwordlength'};
  my $theMaxWordLength = $params->{'maxdwordlength'};
  my $theLimit = $params->{'maxterms'}; 
  $theLimit = $params->{limit} unless defined $theLimit;
  $theLimit = 100 unless defined $theLimit;

  $theLike = 'category,tag' unless defined $theLike;
  $theFilter = 'type:topic' unless defined $theFilter;
  $theRows = 10 unless defined $theRows;

  $theFields = 'web,topic,title,score' unless defined $theFields;

  my $wikiUser = Foswiki::Func::getWikiName();
  my @filter = $this->parseFilter($theFilter);
  push(@filter, "(access_granted:$wikiUser OR access_granted:all)") 
    unless Foswiki::Func::isAnAdmin($wikiUser);

  my $solrParams = {
    "q" => $theQuery, 
    "fq" => \@filter,
    "fl" => $theFields,
    "rows" => $theRows,
    "start" => $theStart,
    "indent" => 'true',
    "mlt.maxqt" => $theLimit,
  };
  
  my @fields = ();
  my @boosts = ();
  foreach my $like (split(/\s*,\s*/, $theLike)) {
    if ($like =~ /^(.*)\^(.*)$/) {
      push(@fields, $1);
      push(@boosts, $like);
    } else {
      push(@fields, $like);
    }
  }

  $solrParams->{"mlt.fl"} = join(',', @fields) if @fields;
  $solrParams->{"mlt.boost"} = $theBoost?'true':'false';
  $solrParams->{"mlt.qf"} = join(' ', @boosts) if @boosts;
  $solrParams->{"mlt.interestingTerms"} = 'details' if $params->{format_interesting};
  $solrParams->{"mlt.match.include"} = $theInclude?'true':'false';
  $solrParams->{"mlt.mintf"} = $theMinTermFreq if defined $theMinTermFreq;
  $solrParams->{"mlt.mindf"} = $theMinDocFreq if defined $theMinDocFreq;
  $solrParams->{"mlt.minwl"} = $theMinWordLength if defined $theMinWordLength;
  $solrParams->{"mlt.maxwl"} = $theMaxWordLength if defined $theMaxWordLength;

  $this->getFacetParams($params, $solrParams);

  return $this->solrRequest('mlt', $solrParams);
}

##############################################################################
sub restSOLRTERMS {
  my ($this, $theWeb, $theTopic) = @_;

  return '' unless defined $this->{solr};
  my $query = Foswiki::Func::getCgiQuery();

  my $theRaw = Foswiki::Func::isTrue($query->param('raw'));

  # TODO: distinguish new and old autocomplete
  my $isNewAutocomplete = ($Foswiki::Plugins::JQueryPlugin::RELEASE > 4.10)?1:0;
  my $theQuery = $query->param($isNewAutocomplete?'term':'q') || '';

  my $theFields = $query->param('fields') || '';
  my $theField = $query->param('field');
  my $theEllipsis = Foswiki::Func::isTrue($query->param('ellipsis'));
  my $theLength = $query->param('length') || 0;

  if (defined $theLength) {
    $theLength =~ s/[^\d]//g;
  }
  $theLength ||= 0;

  my @fields = split(/\s*,\s*/, $theFields);
  push(@fields, $theField) if defined $theField;
  push(@fields, 'catchall') unless @fields;

  my $wikiUser = Foswiki::Func::getWikiName();
  my $solrParams = {
    "terms" => 'true',
    "terms.fl" => \@fields,
    "terms.mincount" => 1,
    "terms.limit" => ($query->param('limit') || 10),
    "terms.lower" => $theQuery,
    "terms.prefix" => $theQuery,
    "terms.lower.incl" => 'false',
    "indent" => 'true',
  };

  $solrParams->{"fq"} = "(access_granted:$wikiUser OR access_granted:all)" 
    unless Foswiki::Func::isAnAdmin($wikiUser);

  my $response = $this->solrRequest('terms', $solrParams);
  #$this->log($response->raw_response->content()) if DEBUG;

  my %struct = ();
  try {
    %struct = @{$response->content->{terms}};
  } catch Error::Simple with {
    # ignore
  };
  my @result = ();
  foreach my $field (keys %struct) {
    while (my $term = shift @{$struct{$field}}) {
      my $freq = shift @{$struct{$field}};
      my $title = $term;

      my $strip = $theQuery;
      my $hilite = $theQuery;
      if ($theLength) {
        $strip = substr($theQuery, 0, -$theLength);
        $hilite = substr($theQuery, -$theLength);
      }
      $title =~ s/$strip/.../ if $theEllipsis;

      # TODO: use different formats for new and old autocomplete library
      my $line = "$term|$title|$hilite|$freq";
      push(@result, $line);
    }
  }
  if ($theRaw) {
    my $result = '';
    try {
      $result = $response->raw_response->content();
      $result = $this->fromUtf8($result);
    } catch Error::Simple with {
      #
    };
    return $result."\n\n";
  }

  return join("\n", @result)."\n\n";
}


##############################################################################
sub doSearch {
  my ($this, $query, $params) = @_;

  my $theXslt = $params->{xslt} || '';
  my $theOutput = $params->{output} || $theXslt?'xslt':'json';
  my $theRows = $params->{rows};
  my $theFields = $params->{fields} || '*,score';
  my $theQueryType = $params->{type} || 'standard';
  my $theHighlight = Foswiki::Func::isTrue($params->{highlight});
  my $theSpellcheck = Foswiki::Func::isTrue($params->{spellcheck});
  my $theMoreLikeThis = Foswiki::Func::isTrue($params->{morelikethis});
  my $theWeb = $params->{web};
  my $theContributor = $params->{contributor};
  my $theFilter = $params->{filter} || '';
  my $theExtraFilter = $params->{extrafilter};
  my $theDisjunktiveFacets = $params->{disjunctivefacets} || '';
  my $theCombinedFacets = $params->{combinedfacets} || '';
  my $theBoostQuery = $params->{boostquery};
  my $theQueryFields = $params->{queryfields};
  my $thePhraseFields = $params->{phrasefields};

  my %disjunctiveFacets = map {$_ => 1} split(/\s*,\s*/, $theDisjunktiveFacets);
  my %combinedFacets = map {$_ => 1} split(/\s*,\s*/, $theCombinedFacets);

  $theQueryType = Foswiki::Func::expandTemplate("solr::defaultquerytype") unless $theQueryType =~ /^(standard|dismax)$/;
  $theQueryType = 'standard' unless defined $theQueryType;

  my $theStart = $params->{start} || 0;

  my $theReverse = $params->{reverse};
  my $theSort = $params->{sort};
  $theSort = Foswiki::Func::expandTemplate("solr::defaultsort") unless defined $theSort;
  $theSort = "score desc" unless $theSort;

  if ($theSort =~ /^(.*) (.*)$/) {
    $theSort = $1;
    $theReverse = ($2 eq 'desc'?'on':'off');
  }
  unless (defined $theReverse) {
    if ($theSort eq 'score') {
      $theReverse = 'on'; # score desc is default
    } else {
      $theReverse = 'off';
    }
  }
  $theSort .= " ".($theReverse eq 'on'?'desc':'asc');

  $theRows =~ s/[^\d]//g if defined $theRows;
  $theRows = Foswiki::Func::expandTemplate('solr::defaultrows') if !defined($theRows) || $theRows eq '';
  $theRows = 10 if !defined($theRows) || $theRows eq '';

  my $solrParams = {
    "indent" =>'on',
    "start" => ($theStart*$theRows),
    "rows" => $theRows,
    "fl" => $theFields,
    "sort" => $theSort,
    "qt" => $theQueryType, # one of the requestHandlers defined in solrconfig.xml
    "wt" => $theOutput,
  };

  $solrParams->{tr} = $theXslt if $theXslt;
  $solrParams->{bq} = $theBoostQuery if $theBoostQuery;
  $solrParams->{qf} = $theQueryFields if $theQueryFields;
  $solrParams->{pf} = $thePhraseFields if $thePhraseFields;

  if ($theHighlight && $theRows > 0) {
    $solrParams->{"hl"} = 'true';
    $solrParams->{"hl.fl"} = 'catchall';
    $solrParams->{"hl.snippets"} = '2';
    $solrParams->{"hl.fragsize"} = '300';
    $solrParams->{"hl.mergeContignuous"} = 'true';
    $solrParams->{"hl.usePhraseHighlighter"} = 'true';
    $solrParams->{"hl.highlightMultiTerm"} = 'true';
    $solrParams->{"hl.alternateField"} = 'summary';
    $solrParams->{"hl.maxAlternateFieldLength"} = '300';
    $solrParams->{"hl.useFastVectorHighlighter"} = 'true';
#    $solrParams->{"hl.requireFieldMatch"} = 'true';
#    $solrParams->{"hl.fragmenter"} = 'gap';
#    $solrParams->{"hl.fragmentsBuilder"} = 'colored';
  }

  if ($theMoreLikeThis) {
    # TODO: add params to configure this 
    $solrParams->{"mlt"} = 'true';
    $solrParams->{"mlt.mintf"} = '1';
    $solrParams->{"mlt.fl"} = 'web,topic,title,type,category,tag';
    $solrParams->{"mlt.qf"} = 'web^100 category^10 tag^10 type^200';
    $solrParams->{"mlt.boost"} = 'true';
    $solrParams->{"mlt.maxqt"} = '100';
  }

  if ($theSpellcheck) {
    $solrParams->{"spellcheck"} = 'true';
#    $solrParams->{"spellcheck.maxCollationTries"} = 1;
#    $solrParams->{"spellcheck.count"} = 1;
    $solrParams->{"spellcheck.maxCollations"} = 1;
#    $solrParams->{"spellcheck.extendedResults"} = 'true';
    $solrParams->{"spellcheck.collate"} = 'true';
  }

  # get all facet params
  $this->getFacetParams($params, $solrParams);

  my $wikiUser = Foswiki::Func::getWikiName();

  # create filter query
  my @filter;
  my @tmpfilter = $this->parseFilter($theFilter);
  my %seenDisjunctiveFilter = ();
  my %seenCombinedFilter = ();

  # gather different types of filters
  foreach my $item (@tmpfilter) {

    if ($item =~ /^(.*):(.*?)$/) {
      my $facetName = $1;
      my $facetValue = $2;

      # disjunctive
      if ($disjunctiveFacets{$facetName} || $this->isDateField($facetName)) {
	push(@{$seenDisjunctiveFilter{$facetName}}, $facetValue);
	next;
      }

      # combined
      if ($combinedFacets{$facetName}) {
	push(@{$seenCombinedFilter{$facetValue}}, $facetName);
	next;
      }
    }

    # normal
    push(@filter, $item);
  }

  # add filters for disjunctive filters
  foreach my $facetName (keys %seenDisjunctiveFilter) {
    my $expr = "{!tag=$facetName}$facetName:(".join(" OR ", @{$seenDisjunctiveFilter{$facetName}}).")";
    push(@filter, $expr);
  }

  # add filters for combined filters
  foreach my $facetValue (keys %seenCombinedFilter) {
    my @expr = ();
    foreach my $facetName (@{$seenCombinedFilter{$facetValue}}) {
      push @expr, "$facetName:$facetValue";
    }
    push @filter, "(".join(" OR ", @expr).")";
  }

  if ($theWeb && $theWeb ne 'all') {
    $theWeb =~ s/\//\./g;
    push(@filter, "web:$theWeb");
  }

  # extra filter 
  push(@filter, $this->parseFilter($theExtraFilter));
  push(@filter, "(access_granted:$wikiUser OR access_granted:all)") 
    unless Foswiki::Func::isAnAdmin($wikiUser); # add ACLs

  # SMELL: do we really need these special filters
  push(@filter, "contributor:".$theContributor) if $theContributor; # add contributor

  $solrParams->{"fq"} = \@filter if @filter;

  if (DEBUG) {
    foreach my $key (sort keys %$solrParams) {
      my $val = $solrParams->{$key};
      if (ref($val)) {
        $val = join(', ', @$val);
      }
      $this->log("solrParams key=$key val=$val");
    }
  }

  # default query for standard request handler
  if (!$query) {
    if (!$theQueryType || $theQueryType eq 'standard' || $theQueryType eq 'lucene') {
      $query = '*:*';
    }
  }

  #$this->log("query=$query") if DEBUG;
  my $response = $this->solrSearch($query, $solrParams);

  #$this->log("response:\n".$response->raw_response->content()) if DEBUG;

  # DEBUG raw response
  if (0) {
    my $raw = $response->raw_response->content();
    #$raw =~ s/"response":.*$//s;
    $this->log("raw params=$raw");
  }


  return $response;
}

##############################################################################
sub solrSearch {
  my ($this, $query, $params) = @_;

  $params ||= {};
  $params->{'q'} = $query if $query;

  return $this->solrRequest("select", $params);
}

##############################################################################
sub solrRequest {
  my ($this, $path, $params) = @_;

  return $this->{solr}->generic_solr_request($path, $params);
}

##############################################################################
sub getFacetParams {
  my ($this, $params, $solrParams) = @_;

  $solrParams ||= {};

  my $theFacets = $params->{facets};
  my $theFacetQuery = $params->{facetquery} || '';

  return $solrParams unless $theFacets || $theFacetQuery;

  my $theFacetLimit = $params->{facetlimit};
  my $theFacetSort = $params->{facetsort} || '';
  my $theFacetOffset = $params->{facetoffset};
  my $theFacetMinCount = $params->{facetmincount};
  my $theFacetPrefix = $params->{facetprefix};
  my $theContributor = $params->{contributor};

  $theFacetLimit = '' unless defined $theFacetLimit;

  # parse facet limit
  my %facetLimit;
  my $globalLimit;
  foreach my $limitSpec (split(/\s*,\s*/, $theFacetLimit)) {
    if ($limitSpec =~ /^(.*)=(.*)$/) {
      $facetLimit{$1} = $2;
    } else {
      $globalLimit = $limitSpec; 
    }
  }
  $solrParams->{"facet.limit"} = $globalLimit if defined $globalLimit;
  foreach my $facetName (keys %facetLimit) {
    $solrParams->{"f.".$facetName.".facet.limit"} = $facetLimit{$facetName};
  }

  # parse facet sort
  my %facetSort;
  my $globalSort;
  foreach my $sortSpec (split(/\s*,\s*/, $theFacetSort)) {
    if ($sortSpec =~ /^(.*)=(.*)$/) {
      my ($key, $val) = ($1, $2);
      if ($val =~ /^(count|index)$/) { 
        $facetSort{$key} = $val;
      } else {
        $this->log("Error: invalid sortSpec '$sortSpec' ... ignoring");
      }
    } else {
      if ($sortSpec =~ /^(count|index)$/) { 
        $globalSort = $sortSpec; 
      } else {
        $this->log("Error: invalid sortSpec '$sortSpec' ... ignoring");
      }
    }
  }
  $solrParams->{"facet.sort"} = $globalSort if defined $globalSort;
  foreach my $facetName (keys %facetSort) {
    $solrParams->{"f.".$facetName.".facet.sort"} = $facetSort{$facetName};
  }

  # general params
  # TODO: make them per-facet like sort and limit
  $solrParams->{"facet"} = 'true';
  $solrParams->{"facet.mincount"} = (defined $theFacetMinCount)?$theFacetMinCount:1;
  $solrParams->{"facet.offset"} = $theFacetOffset if defined $theFacetOffset;
  $solrParams->{"facet.prefix"} = $theFacetPrefix if defined $theFacetPrefix;
  
  # gather all facets
  my $fieldFacets;
  my $dateFacets;
  my $queryFacets;
  
  foreach my $querySpec (split(/\s*,\s*/, $theFacetQuery)) {
    my ($facetLabel, $facetQuery) = parseFacetSpec($querySpec);
    if ($facetQuery =~ /^(.*?):(.*)$/) {
      push(@$queryFacets, "{!ex=$1 key=$facetLabel}$facetQuery");
    } else {
      push(@$queryFacets, "{!key=$facetLabel}$facetQuery");
    }
  }

  foreach my $facetSpec (split(/\s*,\s*/, $theFacets)) {
    my ($facetLabel, $facetID) = parseFacetSpec($facetSpec);
    #next if $facetID eq 'web' && $params->{web} && $params->{web} ne 'all';
    next if $facetID eq 'contributor' && $theContributor;
    next if $facetID eq 'facetquery';
    if ($facetID =~ /^(tag|category)$/) {
      push(@$fieldFacets, "{!key=$facetLabel}$facetID");
    } elsif ($this->isDateField($facetID)) {
      push(@$dateFacets, "{!ex=$facetID, key=$facetLabel}$facetID");
    } else {
      push(@$fieldFacets, "{!ex=$facetID key=$facetLabel}$facetID");
    }
  }

  # date facets params
  # TODO: provide general interface to range facets
  if ($dateFacets) {
    $solrParams->{"facet.range"} = $dateFacets;
    $solrParams->{"facet.range.start"} = $params->{facetdatestart} || 'NOW/DAY-7DAYS';
    $solrParams->{"facet.range.end"} = $params->{facetdateend} || 'NOW/DAY+1DAYS';
    $solrParams->{"facet.range.gap"} = $params->{facetdategap} || '+1DAY';
    $solrParams->{"facet.range.other"} = $params->{facetdateother} || 'before';
    $solrParams->{"facet.range.hardend"} = 'true'; # TODO
  }

  $solrParams->{"facet.query"} = $queryFacets if $queryFacets;
  $solrParams->{"facet.field"} = $fieldFacets if $fieldFacets;

  return $solrParams;
}


##############################################################################
sub mapToIconFileName {
  my ($this, $type) = @_;

  my $pubUrlPath = $Foswiki::cfg{PubUrlPath}.'/'.$Foswiki::cfg{SystemWebName}.'/FamFamFamSilkIcons/';

  # some specific icons
  return $pubUrlPath.'page_white_edit.png' if $type =~ /topic/i;
  return $pubUrlPath.'comment.png' if $type =~ /comment/i;

  if (Foswiki::Func::getContext()->{MimeIconPluginEnabled}) {
    require Foswiki::Plugins::MimeIconPlugin;
    return Foswiki::Plugins::MimeIconPlugin::getIcon($type, "oxygen", 16);
  } 

  return $pubUrlPath.'picture.png' if $type =~ /(jpe?g)|gif|png/i;
  return $pubUrlPath.'compress.png' if $type =~ /zip|tar|tar|rar/i;
  return $pubUrlPath.'page_white_acrobat.png' if $type =~ /pdf/i;
  return $pubUrlPath.'page_excel.png' if $type =~ /xlsx?/i;
  return $pubUrlPath.'page_word.png' if $type =~ /docx?/i;
  return $pubUrlPath.'page_white_powerpoint.png' if $type =~ /pptx?/i;
  return $pubUrlPath.'page_white_flash.png' if $type =~ /flv|swf/i;

  return $pubUrlPath.'page_white.png';
}

##############################################################################
# replaces buggy Data::Page interface
sub currentPage {
  my ($this, $response) = @_;

  my $rows = 0;
  my $start = 0;
  
  try {
    $rows = $this->entriesPerPage($response);
    $start = $response->content->{response}->{start};
  } catch Error::Simple with {
    # ignore
  };

  return POSIX::floor($start / $rows) if $rows;
  return 0;
}

##############################################################################
sub lastPage {
  my ($this, $response) = @_;
  
  my $rows = 0;
  my $total = 0;
  try {
    $rows = $this->entriesPerPage($response);
    $total = $this->totalEntries($response);
  } catch Error::Simple with {
    # ignore
  };

  return POSIX::ceil($total/$rows)-1 if $rows;
  return 0;
}

##############################################################################
sub entriesPerPage {
  my ($this, $response) = @_;

  my $result = 0;
  try {
    $result = $response->content->{responseHeader}->{params}->{rows} || 0;
  } catch Error::Simple with {
    # ignore
  };

  return $result;
}

##############################################################################
sub totalEntries {
  my ($this, $response) = @_;

  my $result = 0;

  try {
   $result = $response->content->{response}->{numFound};
  } catch Error::Simple with {
    # ignore
  };

  return $result;
}

##############################################################################
sub getQueryTime {
  my ($this, $response) = @_;

  my $result = 0;
  try {
    $result = $response->content->{responseHeader}->{QTime} || 0;
  } catch Error::Simple with {
    # ignore
  };

  return $result;
}


##############################################################################
sub getHighlights {
  my ($this, $response) = @_;

  my %hilites = ();

  my $struct;
  try {
    $struct = $response->content->{highlighting};
  } catch Error::Simple with {
    #ignore
  };

  if ($struct) {
    foreach my $id (keys %$struct) {
      my $hilite = $struct->{$id}{catchall};
      next unless $hilite;
      $hilite = join(" ... ", @{$hilite});

      # bit of cleanup in case we only get half the comment
      $hilite =~ s/<!--//g;
      $hilite =~ s/-->//g;
      $hilites{$id} = $this->fromUtf8($hilite);
    }
  }

  return \%hilites;
}

##############################################################################
sub getMoreLikeThis {
  my ($this, $response) = @_;

  my $moreLikeThis = [];

  try {
    $moreLikeThis = $response->content->{moreLikeThis};
  } catch Error::Simple with {
    #ignore
  };

  return $moreLikeThis;
}


##############################################################################
sub getCorrection {
  my ($this, $response) = @_;

  my $struct;

  try {
    $struct = $response->content->{spellcheck};
  } catch Error::Simple with {
    # ignore
  };

  return '' unless $struct;

  $struct = {@{$struct->{suggestions}}};
  return '' unless $struct;
  return '' if $struct->{correctlySpelled};

  my $correction = $struct->{collation};
  return '' unless $correction;

  #return $correction;
  return $this->fromUtf8($correction);
}

##############################################################################
sub getFacets {
  my ($this, $response) = @_;

  my $struct = '';

  try {
    $struct = $response->content->{facet_counts};
  } catch Error::Simple with {
    # ignore
  };

  return $struct;
}

##############################################################################
sub getInterestingTerms {
  my ($this, $response) = @_;

  my $struct = '';
  
  try {
    $struct = $response->content->{interestingTerms};
  } catch Error::Simple with {
    # ignore
  };

  return $struct;
}


##############################################################################
sub parseFacetSpec {
  my ($spec) = @_;

  $spec =~ s/^\s+//g;
  $spec =~ s/\s+$//g;
  my $key = $spec;
  my $val = $spec;

  if ($spec =~ /^(.+)=(.+)$/) {
    $key = $1;
    $val = $2;
  }
  $key =~ s/ /_/g;

  return ($key, $val);
}

##############################################################################
sub handleSOLRSCRIPTURL {
  my ($this, $params, $theWeb, $theTopic) = @_;

  return '' unless defined $this->{solr};

  my $theId = $params->{_DEFAULT} || $params->{id};
  return $this->inlineError("unknown query id") unless defined $theId;

  my $cacheEntry = $this->{cache}{$theId};
  return $this->inlineError("unknown query '$theId'") unless defined $cacheEntry;

  $params = {%{$cacheEntry->{params}}, %$params};

  my $web = $params->{web} || $theWeb;
  my $topic = $params->{topic} || $theTopic;

  return $this->getScriptUrl($web, $topic, $params, $cacheEntry->{response});
}

##############################################################################
sub getScriptUrl {
  my ($this, $web, $topic, $params, $response, $start) = @_;

  my $theRows = $params->{rows};
  my $theFilter = $params->{filter} || '';
  
  my $theQueryType = $params->{type} || 'standard';
  $theQueryType = Foswiki::Func::expandTemplate("solr::defaultquerytype") unless $theQueryType =~ /^(standard|dismax)$/;
  $theQueryType = 'standard' unless defined $theQueryType;

  $theRows = Foswiki::Func::expandTemplate('solr::defaultrows') unless defined $theRows;
  $theRows = 10 if !defined($theRows) || $theRows eq '';

  my $theSort = $params->{sort};
  $theSort = Foswiki::Func::expandTemplate("solr::defaultsort") unless defined $theSort;
  $theSort = "score desc" unless defined $theSort;
  $theSort =~ s/^\s+//;
  $theSort =~ s/\s+$//;

  $start = $this->currentPage($response)
    unless defined $start;
  $start = 0 unless $start;

  my @urlParams = (
    start=>$start,
    rows=>$theRows,
    sort=>$theSort,
    search=>$params->{search},
    display=>$params->{display}, # list, grid
    type=>$params->{type}, # standard, dismax
    web=>$params->{web},
    origtopic=>$params->{origtopic},
    autosubmit=>$params->{autosubmit},
  );

  # SMELL: duplicates parseFilter 
  $theFilter = $this->urlDecode($this->entityDecode($theFilter));
  while ($theFilter =~ /([^\s:]+?):((?:\[[^\]]+?\])|[^\s",]+|(?:"[^"]+?")),?/g) {
    my $field = $1;
    my $value = $2;
    if (defined $value) {
      $value =~ s/^"//;
      $value =~ s/"$//;
      $value =~ s/,$//;
      my $item;
      if ($value =~ /\s/ && $value !~ /^["\[].*["\]]$/) {
	#print STDERR "... adding quotes\n";
	$item = '$field:"$value"';
      } else {
	#print STDERR "... adding as is\n";
       	$item = '$field:$value';
      }

      $item =~ s/\$field/$field/g;
      $item =~ s/\$value/$value/g;
      push(@urlParams, filter=>$item);
    } else {
      push(@urlParams, filter=>$value); # SMELL what for?
    }
  }

  return Foswiki::Func::getScriptUrl($web, $topic, 'view', @urlParams);
}

##############################################################################
sub parseFilter {
  my ($this, $filter) = @_; 

  my @filter = ();
  $filter ||= '';
  $filter = $this->toUtf8($this->urlDecode($this->entityDecode($filter)));

  #print STDERR "parseFilter($filter)\n";

  while ($filter =~ /([^\s:]+?):((?:\[[^\]]+?\])|[^\s",]+|(?:"[^"]+?")),?/g) {
    my $field = $1;
    my $value = $2;
    $value =~ s/^"//;
    $value =~ s/"$//;
    $value =~ s/,$//;
    $value =~ s/\//\./g if $field eq 'web';
    #print STDERR "field=$field, value=$value\n";
    if ($value) {
      my $item;
      if ($value =~ /\s/ && $value !~ /^["\[].*["\]]$/) {
	#print STDERR "... adding quotes\n";
	$item = '$field:"$value"';
      } else {
	#print STDERR "... adding as is\n";
       	$item = '$field:$value';
      }
      $item =~ s/\$field/$field/g;
      $item =~ s/\$value/$value/g;
      #print STDERR "... adding=$item\n";
      push(@filter, $item);
    }
  }

  return @filter;
}

################################################################################
sub getListOfWebs {
  my $this = shift;

  my @webs = ();

  my $homeTopic = $Foswiki::cfg{HomeTopicName} || 'WebHome';
  my $response = $this->doSearch("*", {
    fields => "none",
    facets => "web",
    facetlimit => "web=100",
  });

  my $facets = $this->getFacets($response);
  return @webs unless $facets;

  my $webFacet = $facets->{facet_fields}{"web"};
  my $len = scalar(@$webFacet);
  for (my $i = 0; $i < $len; $i+=2) {
    my $web = $this->fromUtf8($webFacet->[$i]);
    push @webs, $web;
  }

  return @webs;
}


1;
