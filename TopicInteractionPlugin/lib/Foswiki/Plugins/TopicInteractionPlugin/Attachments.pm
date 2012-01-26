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

package Foswiki::Plugins::TopicInteractionPlugin::Attachments;

use strict;
use warnings;
use POSIX ();

###############################################################################
sub handle {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleATTACHMENTS($theTopic, $theWeb)");
  #writeDebug("params=".$params->stringify());

  # get parameters
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $session->{topicName};
  my $thisWeb = $params->{web} || $session->{webName};

  ($thisWeb, $thisTopic) = Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  my $theNames = $params->{names} || $params->{name} || '.*';
  my $theAttr = $params->{attr} || '.*';
  my $theAutoAttached = $params->{autoattached} || 2;
  $theAutoAttached = 0 if $theAutoAttached =~ /^(no|off)$/o;
  $theAutoAttached = 1 if $theAutoAttached =~ /^(yes|on)$/o;
  $theAutoAttached = 2 if $theAutoAttached eq 'undef';
  my $theMinDate = $params->{mindate};
  $theMinDate = Foswiki::Time::parseTime($theMinDate) if $theMinDate;
  my $theMaxDate = $params->{maxdate};
  $theMaxDate = Foswiki::Time::parseTime($theMaxDate) if $theMaxDate;
  my $theMinSize = $params->{minsize} || 0;
  my $theMaxSize = $params->{maxsize} || 0;
  my $theUser = $params->{user} || '.*';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theFormat = $params->{format};
  my $theSeparator = $params->{separator};
  my $theSort = $params->{sort} || $params->{order} || 'name';
  my $theReverse = $params->{reverse} || 'off';
  my $theHideNull = $params->{hidenull} || 'off';
  my $theNullFormat = $params->{nullformat} || '';
  my $theComment = $params->{comment} || '.*';
  my $theLimit = $params->{limit} || 0;
  my $theSkip = $params->{skip} || 0;
  my $theWarn = $params->{warn} || 'on';
  my $theInclude = $params->{include};
  my $theCase = $params->{casesensitive} || 'on';

  $theLimit =~ s/[^\d]//go;
  $theLimit = 0 unless $theLimit;
  $theSkip =~ s/[^\d]//go;
  $theSkip = 0 unless $theSkip;

  $params->{limit} = $theLimit;
  $params->{skip} = $theSkip;

  $theFormat = '| [[$url][$name]] |  $sizeK | <nobr>$date</nobr> | $wikiuser | $comment |'
    unless defined $theFormat;
  $theSeparator = $params->{sep} unless defined $theSeparator;
  $theSeparator = "\n" unless defined $theSeparator;

  # sort attachments
  my ($meta) = Foswiki::Func::readTopic($thisWeb, $thisTopic );
  my @attachments = $meta->find("FILEATTACHMENT");
  return '' unless @attachments;

  #%META:FILEATTACHMENT{name="cross06.jpg" attachment="cross06.jpg" attr="" comment="" date="1287484667" size="30247" user="micha" version="1"}%

  my $isNumeric;
  my %sorting = ();
  if ($theSort eq 'name') {
    %sorting = map {$_ => lc($_->{name})} @attachments;
    $isNumeric = 0;
  } elsif ($theSort eq 'date') {
    %sorting = map {$_ => ($_->{date}||0)} @attachments;
    $isNumeric = 1;
  } elsif ($theSort eq 'size') {
    %sorting = map {$_ => ($_->{size}||0)} @attachments;
    $isNumeric = 1;
  } elsif ($theSort eq 'user') {
    %sorting = map {$_ => lc($_->{user}||'')} @attachments;
    $isNumeric = 0;
  } elsif ($theSort eq 'comment') {
    %sorting = map {$_ => lc($_->{comment}||'')} @attachments;
    $isNumeric = 0;
  } elsif ($theSort eq 'comment:name') {
    %sorting = map {$_ => lc($_->{comment}||$_->{name})} @attachments;
    $isNumeric = 0;
  }
  if (defined $isNumeric) {
    if ($isNumeric) {
      @attachments = sort { $sorting{$a} <=> $sorting{$b} } @attachments;
    } else {
      @attachments = sort { $sorting{$a} cmp $sorting{$b} } @attachments;
    }
  }
  @attachments = reverse @attachments if $theReverse eq 'on';

  # collect result
  my @result;

  my $index = 0;
  my @selectedAttachments = ();
  foreach my $attachment (@attachments) {
    my $info = getAttachmentInfo($attachment);

    next unless $info->{name} =~ /^($theNames)$/;
    next unless $info->{attr} =~ /^($theAttr)$/;
    next if $theAutoAttached == 0 && $info->{autoattached} != 0;
    next if $theAutoAttached == 1 && $info->{autoattached} != 1;
    next if $theMinDate && $info->{date} < $theMinDate;
    next if $theMaxDate && $info->{date} > $theMaxDate;
    next unless $info->{user} =~ /^($theUser)$/;
    next if $theMinSize && $info->{size} < $theMinSize;
    next if $theMaxSize && $info->{size} > $theMaxSize;
    next unless $info->{comment} =~ /^($theComment)$/;

    if ($theInclude) {
      if ($theCase eq 'on') {
        next unless
          $info->{name} =~ /^($theInclude)$/ ||
          $info->{user} =~ /^($theInclude)$/ ||
          $info->{comment} =~ /^($theInclude)$/ ||
          $info->{attr} =~ /^($theInclude)$/;
      } else {
        next unless
          $info->{name} =~ /^($theInclude)$/i ||
          $info->{user} =~ /^($theInclude)$/i ||
          $info->{comment} =~ /^($theInclude)$/i ||
          $info->{attr} =~ /^($theInclude)$/i;
      }
    }

    $index++;
    push @selectedAttachments, $attachment;
  }

  $params->{_count} = $index;
  return '' if $theHideNull eq 'on' && $index == 0;
  $theSkip = 0 if $theSkip > $index;
  $index = 0;
  my $webDAVLinkPluginEnabled = Foswiki::Func::getContext()->{WebDAVLinkPluginEnabled};
  my $webDAVFilter = $Foswiki::cfg{TopicInteractionPlugin}{WebDAVFilter} || qr/((xlt|xls|ppt|pps|pot|doc|dot)(x|m)?)|odc|odb|odf|odg|otg|odi|odp|otp|ods|ots|odt|odm|ott|oth|mpp/;

  foreach my $attachment (@selectedAttachments) {

    $index++;
    next if $theSkip >= $index;
    next if $theLimit && ($index-$theSkip) > $theLimit;
    $params->{_first} = $index unless defined $params->{_first};

    my $info = getAttachmentInfo($attachment);

    my $iconUrl = '%ICONURL{"' . $info->{name} . '" alt="else"}%';
    my $icon = '%ICON{"' . $info->{name} . '" alt="else"}%';

    my $encName = urlEncode($info->{name});

    # actions
    my $webDavUrl = '%WEBDAVFOLDERURL%/' . $thisWeb . '/' . $thisTopic . '_files/' . $encName;
    my $webDavAction = '<a rel="nofollow" href="' . $webDavUrl . '" ' . 'title="%MATETEXT{"edit this attachment" args="<nop>' . $info->{name} . '"}%">' . '%MAKETEXT{"edit"}%</a>';

    my $propsUrl = '%SCRIPTURLPATH{"attach"}%/' . $thisWeb . '/' . $thisTopic . '?filename=' . $encName . '&revInfo=1';
    my $propsAction = '<a rel="nofollow" href="' . $propsUrl . '" ' . 'title="%MAKETEXT{"manage properties of [_1]" args="<nop>' . $info->{name} . '"}%">' . '%MAKETEXT{"props"}%</a>';

    my $moveUrl = '%SCRIPTURLPATH{"rename"}%/' . $thisWeb . '/' . $thisTopic . '?attachment=' . $encName;
    my $moveAction = '<a rel="nofollow" href="' . $moveUrl . '" ' . 'title="%MAKETEXT{"move or delete [_1]" args="<nop>' . $info->{name} . '"}%">' . '%MAKETEXT{"move"}%</a>';

    my $deleteUrl = '%SCRIPTURLPATH{"rename"}%/' . $thisWeb . '/' . $thisTopic . '?attachment=' . $encName . '&newweb=Trash';
    my $deleteAction = '<a rel="nofollow" href="' . $deleteUrl . '" ' . 'title="%MAKETEXT{"delete [_1]" args="<nop>' . $info->{name} . '"}%">' . '%MAKETEXT{"delete"}%</a>';

    my $url = '%PUBURL%'."/$thisWeb/$thisTopic/$encName";
    my $urlPath = '%PUBURLPATH%'."/$thisWeb/$thisTopic/$encName";

    my $oldVersions = '';
    if ($theFormat =~ /\$oldversions/ && $info->{version} > 1) {
      my @oldVersions;
      for (my $i = $info->{version} - 1; $i > 0; $i--) {
        my ($date, $user, $rev, $comment) = Foswiki::Func::getRevisionInfo($thisWeb, $thisTopic, $i, $info->{name});
        $date = Foswiki::Func::formatTime($date);
        push @oldVersions, "$date;$user;$rev;$comment";
      }
      $oldVersions = join("\n", @oldVersions);
    }

    # use webdav urls for document types that are webdav-enabled via WebDAVLinkPlugin
    if ($webDAVLinkPluginEnabled && $info->{name} =~ /\.($webDAVFilter)$/i) {
      # switch normal pubUrls to webdavUrls
      $url = $webDavUrl;
    }

    my $text = $theFormat;
    $text =~ s/\$date\(([^\)]+)\)/_formatTile($info->{date}, $1)/ge;
    $text =~ s/\$webdav\b/$webDavAction/g;
    $text =~ s/\$webdavUrl\b/$webDavUrl/g;
    $text =~ s/\$propsUrl/$propsUrl/g;
    $text =~ s/\$props\b/$propsAction/g;
    $text =~ s/\$moveUrl\b/$moveUrl/g;
    $text =~ s/\$move\b/$moveAction/g;
    $text =~ s/\$delete\b/$deleteAction/g;
    $text =~ s/\$deleteUrl\b/$deleteUrl/g;
    $text =~ s/\$icon\b/$icon/g;
    $text =~ s/\$iconUrl\b/$iconUrl/g;
    $text =~ s/\$iconurl\b/$iconUrl/g;
    $text =~ s/\$attr\b/$info->{attr}/g;
    $text =~ s/\$autoattached\b/$info->{autoattached}/g;
    $text =~ s/\$comment\b/$info->{comment}/g;
    $text =~ s/\$date\b/Foswiki::Func::formatTime($info->{date})/ge;
    $text =~ s/\$index\b/$index/g;
    $text =~ s/\$name\b/$info->{name}/g;
    $text =~ s/\$path\b/$info->{path}/g;
    $text =~ s/\$size\b/$info->{size}/g;
    $text =~ s/\$sizeK\b/$info->{sizeK}K/g;
    $text =~ s/\$sizeM\b/$info->{sizeM}M/g;
    $text =~ s/\$url\b/$url/g;
    $text =~ s/\$urlpath\b/$urlPath/g;
    $text =~ s/\$user\b/$info->{userTopic}/g;
    $text =~ s/\$wikiuser\b/$info->{userWeb}.$info->{userTopic}/g;
    $text =~ s/\$version\b/$info->{version}/g;
    $text =~ s/\$oldversions\b/$oldVersions/g;
    $text =~ s/\$web\b/$thisWeb/g;
    $text =~ s/\$topic\b/$thisTopic/g;
    $text =~ s/\$encode\((.*?)\)/urlEncode($1)/ges;

    push @result, $text if $text;
  }
  $params->{_first} ||= 0;

  my $result = '';
  if ($params->{_count} == 0) {
    $result = $theHeader.$theNullFormat.$theFooter;
  } else {
    $result = $theHeader.join($theSeparator, @result).$theFooter;
  }

  $result =~ s/\$count\b/$params->{_count}/g;
  $result =~ s/\$web\b/$thisWeb/g;
  $result =~ s/\$topic\b/$thisTopic/g;
  $result =~ s/\$pager/renderPager($thisWeb, $thisTopic, $params)/ge;

  return Foswiki::Func::decodeFormatTokens($result);
}

##############################################################################
# slightly different version as Foswiki::urlEncode: also encodes single quotes
sub urlEncode {
  my $text = shift;

  $text =~ s/([^0-9a-zA-Z-_.:~!*\/])/'%'.sprintf('%02X',ord($1))/ge;

  return $text;
}

##############################################################################
sub getAttachmentInfo {
  my $attachment = shift;

  my $size = $attachment->{size} || 0;
  my %info = (
    name => $attachment->{name},
    attr => ($attachment->{attr} || ''),
    autoattached => $attachment->{autoattached} || 0,
    date => $attachment->{date},
    user => ($attachment->{user} || $attachment->{author} || 'UnknownUser'),
    size => $size,
    sizeK => sprintf("%.2f", $size / 1024),
    sizeM => sprintf("%.2f", $size / (1024 * 1024)),
    comment => (defined $attachment->{comment}) ? $attachment->{comment} : '',
    path => ($attachment->{path} || ''),
    version => ($attachment->{version} || 1),
  );

  if ($Foswiki::Plugins::VERSION >= 1.2) { # new Foswikis
    $info{user} = Foswiki::Func::getWikiName($info{user});
  }

  ($info{userWeb}, $info{userTopic}) = Foswiki::Func::normalizeWebTopicName('', $info{user});

  return \%info;
}

##############################################################################
sub renderPager {
  my ($web, $topic, $params) = @_;

  # compute current and last page
  my $entriesPerPage = $params->{limit};
  $entriesPerPage = 10 unless defined $entriesPerPage;

  my $totalEntries = $params->{_count};
  my $lastPage = 0;
  my $currentPage = 0;
  my $firstEntry = $params->{_first};
  $lastPage = POSIX::ceil($totalEntries / $entriesPerPage)-1 if $entriesPerPage;
  $currentPage = POSIX::floor($firstEntry / $entriesPerPage) if $entriesPerPage;

  #print STDERR "entriesPerPage=$entriesPerPage, totalEntries=$totalEntries, currentPage=$currentPage, firstEntry=$firstEntry, lastPage=$lastPage\n";
  return '' unless $lastPage > 0;


  my $result = '';
  if ($currentPage > 0) {
    my $skip = ($currentPage - 1) * $entriesPerPage;
    $result .= "<a href='#skip$skip' class='natAttachmentsPagerPrev {skip:$skip}'>%MAKETEXT{\"Previous\"}%</a>";
  } else {
    $result .= "<span class='natAttachmentsPagerPrev foswikiGrayText'>%MAKETEXT{\"Previous\"}%</span>";
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
    $result .= "<a href='#' class='{skip:0}'>1</a>";
  }

  if ($startPage > 1) {
    $result .= "<span class='natAttachmentsPagerEllipsis'>&hellip;</span>";
  }

  my $count = 1;
  my $marker = '';
  for (my $i = $startPage; $i <= $endPage; $i++) {
    $marker = $i == $currentPage?'current':'';
    my $skip = $i * $entriesPerPage;
    $result .= "<a href='#skip$skip' class='$marker {skip:$skip}'>".($i+1)."</a>";
    $count++;
  }

  if ($endPage < $lastPage-1) {
    $result .= "<span class='natAttachmentsPagerEllipsis'>&hellip;</span>"
  }

  if ($endPage < $lastPage) {
    $marker = $currentPage == $lastPage?'current':'';
    my $skip = $lastPage * $entriesPerPage;
    $result .= "<a href='#skip$skip' class='$marker {skip:$skip}'>".($lastPage+1)."</a>";
  }

  if ($currentPage < $lastPage) {
    my $skip = ($currentPage + 1) * $entriesPerPage;
    $result .= "<a href='#skip$skip' class='natAttachmentsPagerNext {skip:$skip}'>%MAKETEXT{\"Next\"}%</a>";
  } else {
    $result .= "<span class='natAttachmentsPagerNext foswikiGrayText'>%MAKETEXT{\"Next\"}%</a>";
  }

  return $result;
}

1;

