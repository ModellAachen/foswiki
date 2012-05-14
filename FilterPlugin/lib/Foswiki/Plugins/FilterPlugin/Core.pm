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

package Foswiki::Plugins::FilterPlugin::Core;

use strict;
use warnings;

use POSIX qw(ceil);
use Foswiki::Plugins();
use Foswiki::Func();

use constant DEBUG => 0; # toggle me

###############################################################################
sub new {
  my ($class, $session) = @_;

  $session ||= $Foswiki::Plugins::SESSION;

  my $this = bless({
    session => $session,
    seenAnchorNames => {},
    makeIndexCounter => 0,
    filteredTopic => {},
  }, $class);

  return $this;
}

###############################################################################
sub handleFilterArea {
  my ($this, $theAttributes, $theMode, $theText, $theWeb, $theTopic) = @_;

  $theAttributes ||= '';
  #writeDebug("called handleFilterArea($theAttributes)");

  my %params = Foswiki::Func::extractParameters($theAttributes);
  return $this->handleFilter(\%params, $theMode, $theText, $theWeb, $theTopic);
}

###############################################################################
# filter a topic or url thru a regular expression
# attributes
#    * pattern
#    * format
#    * hits
#    * topic
#    * expand
#
sub handleFilter {
  my ($this, $params, $theMode, $theText, $theWeb, $theTopic) = @_;

  #writeDebug("called handleFilter(".$params->stringify.")");
  #writeDebug("theMode = '$theMode'");

  # get parameters
  my $thePattern = $params->{pattern} || '';
  my $theFormat = $params->{format} || '';
  my $theNullFormat = $params->{null} || '';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theLimit = $params->{limit} || $params->{hits} || 100000; 
  my $theSkip = $params->{skip} || 0;
  my $theExpand = $params->{expand} || 'on';
  my $theSeparator = $params->{separator};
  my $theExclude = $params->{exclude} || '';
  my $theInclude = $params->{include} || '';
  my $theSort = $params->{sort} || 'off';
  my $theReverse = $params->{reverse} || '';

  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $theTopic;
  ($theWeb, $theTopic) = Foswiki::Func::normalizeWebTopicName($theWeb, $thisTopic);
  $theWeb =~ s/\//\./g;
  
  $theText ||= $params->{text};

  $theSeparator = '' unless defined $theSeparator;

  # get the source text
  my $text = '';
  if (defined $theText) { # direct text
    $text = $theText;
  } else { # topic text
    return '' if $this->{filteredTopic}{"$theWeb.$theTopic"};
    $this->{filteredTopic}{"$theWeb.$theTopic"} = 1;
    (undef, $text) = Foswiki::Func::readTopic($theWeb, $theTopic);
    $text = '' unless defined $text;
    if ($text =~ /^No permission to read topic/) {
      return inlineError("$text");
    }
    if ($text =~ /%STARTINCLUDE%(.*)%STOPINCLUDE%/gs) {
      $text = $1;
      if ($theExpand eq 'on') {
	$text = Foswiki::Func::expandCommonVariables($text);
	$text = Foswiki::Func::renderText($text);
      }
    }
  }
  #writeDebug("text = '$text'");

  my $result = '';
  my $hits = $theLimit;
  my $skip = $theSkip;
  if ($theMode == 0) {
    # extraction mode

    my @result = ();
    while($text =~ /$thePattern/gms) {
      my $arg1 = $1;
      my $arg2 = $2;
      my $arg3 = $3;
      my $arg4 = $4;
      my $arg5 = $5;
      my $arg6 = $6;
      my $arg7 = $7;
      my $arg8 = $8;
      my $arg9 = $9;
      my $arg10 = $10;

      $arg1 = '' unless defined $arg1;
      $arg2 = '' unless defined $arg2;
      $arg3 = '' unless defined $arg3;
      $arg4 = '' unless defined $arg4;
      $arg5 = '' unless defined $arg5;
      $arg6 = '' unless defined $arg6;
      $arg7 = '' unless defined $arg7;
      $arg8 = '' unless defined $arg8;
      $arg9 = '' unless defined $arg9;
      $arg10 = '' unless defined $arg10;

      my $match = $theFormat;
      $match =~ s/\$10/$arg10/g;
      $match =~ s/\$1/$arg1/g;
      $match =~ s/\$2/$arg2/g;
      $match =~ s/\$3/$arg3/g;
      $match =~ s/\$4/$arg4/g;
      $match =~ s/\$5/$arg5/g;
      $match =~ s/\$6/$arg6/g;
      $match =~ s/\$7/$arg7/g;
      $match =~ s/\$8/$arg8/g;
      $match =~ s/\$9/$arg9/g;
      next if $theExclude && $match =~ /^($theExclude)$/;
      next if $theInclude && $match !~ /^($theInclude)$/;
      next if $skip-- > 0;
      push @result,$match;
      $hits--;
      last if $theLimit > 0 && $hits <= 0;
    }
    if ($theSort ne 'off') {
      if ($theSort eq 'alpha' || $theSort eq 'on') {
	@result = sort {uc($a) cmp uc($b)} @result;
      } elsif ($theSort eq 'num') {
	@result = sort {$a <=> $b} @result;
      }
    }
    @result = reverse @result if $theReverse eq 'on';
    $result = join($theSeparator, @result);
  } elsif ($theMode == 1) {
    # substitution mode
    $result = '';
    while($text =~ /(.*?)$thePattern/gcs) {
      my $prefix = $1;
      my $arg1 = $2;
      my $arg2 = $3;
      my $arg3 = $4;
      my $arg4 = $5;
      my $arg5 = $6;
      my $arg6 = $7;
      my $arg7 = $8;
      my $arg8 = $9;
      my $arg9 = $10;
      my $arg10 = $11;

      $arg1 = '' unless defined $arg1;
      $arg2 = '' unless defined $arg2;
      $arg3 = '' unless defined $arg3;
      $arg4 = '' unless defined $arg4;
      $arg5 = '' unless defined $arg5;
      $arg6 = '' unless defined $arg6;
      $arg7 = '' unless defined $arg7;
      $arg8 = '' unless defined $arg8;
      $arg9 = '' unless defined $arg9;
      $arg10 = '' unless defined $arg10;

      my $match = $theFormat;
      $match =~ s/\$10/$arg10/g;
      $match =~ s/\$1/$arg1/g;
      $match =~ s/\$2/$arg2/g;
      $match =~ s/\$3/$arg3/g;
      $match =~ s/\$4/$arg4/g;
      $match =~ s/\$5/$arg5/g;
      $match =~ s/\$6/$arg6/g;
      $match =~ s/\$7/$arg7/g;
      $match =~ s/\$8/$arg8/g;
      $match =~ s/\$9/$arg9/g;
      next if $theExclude && $match =~ /^($theExclude)$/;
      next if $theInclude && $match !~ /^($theInclude)$/;
      next if $skip-- > 0;
      #writeDebug("match=$match");
      $result .= $prefix.$match;
      #writeDebug("($hits) result=$result");
      $hits--;
      last if $theLimit > 0 && $hits <= 0;
    }
    if ($text =~ /\G(.*)$/s) {
      $result .= $1;
    }
  }
  $result = $theNullFormat unless $result;
  $result = $theHeader.$result.$theFooter;
  expandVariables($result);

  delete $this->{filteredTopic}{"$theWeb.$theTopic"};

  #writeDebug("result='$result'");
  return $result;
}

###############################################################################
sub handleSubst {
  my ($this, $params, $theTopic, $theWeb) = @_;
  return $this->handleFilter($params, 1, undef, $theWeb, $theTopic);
}

###############################################################################
sub handleExtract {
  my ($this, $params, $theTopic, $theWeb) = @_;
  return $this->handleFilter($params, 0, undef, $theWeb, $theTopic);
}

###############################################################################
sub handleMakeIndex {
  my ($this, $params, $theTopic, $theWeb) = @_;

  #writeDebug("### called handleMakeIndex(".$params->stringify.")");
  my $theList = $params->{_DEFAULT} || $params->{list} || '';
  my $theCols = $params->{cols} || 3;
  my $theFormat = $params->{format};
  my $theSort = $params->{sort} || 'on';
  my $theSplit = $params->{split};
  $theSplit = '\s*,\s*' unless defined $theSplit;

  my $theUnique = $params->{unique} || '';
  my $theExclude = $params->{exclude} || '';
  my $theInclude = $params->{include} || '';
  my $theReverse = $params->{reverse} || '';
  my $thePattern = $params->{pattern} || '';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theGroup = $params->{group};
  my $theAnchorThreshold = $params->{anchorthreshold} || 0;


  # sanitize params
  $theAnchorThreshold =~ s/[^\d]//go;
  $theAnchorThreshold = 0 unless $theAnchorThreshold;
  $theUnique = ($theUnique eq 'on')?1:0;
  $theGroup = " \$anchor<h3>\$group</h3>\n" unless defined $theGroup;

  $theFormat = '$item' unless defined $theFormat;

  my $maxCols = $theCols;
  $maxCols =~ s/[^\d]//go;
  $maxCols = 3 if $maxCols eq '';
  $maxCols = 1 if $maxCols < 1;

  # compute the list
  $theList = Foswiki::Func::expandCommonVariables($theList, $theTopic, $theWeb)
    if expandVariables($theList);

  #writeDebug("theList=$theList");

  # create the item descriptors for each list item
  my @theList = ();
  my %seen = ();
  foreach my $item (split(/$theSplit/, $theList)) {
    next if $theExclude && $item =~ /^($theExclude)$/;
    next if $theInclude && $item !~ /^($theInclude)$/;

    $item =~ s/<nop>//go;
    $item =~ s/^\s+//go;
    $item =~ s/\s+$//go;
    next unless $item;

    #writeDebug("item='$item'");

    if ($theUnique) {
      next if $seen{$item};
      $seen{$item} = 1;
    }

    my $crit = $item;
    if ($crit =~ /\((.*?)\)/) {
      $crit = $1;
    }
    if ($theSort eq 'nocase') {
      $crit = uc($crit);
    }
    $crit =~ s/[^$Foswiki::regex{'mixedAlphaNum'}]//go;

    my $group = $crit;
    $group = substr($crit, 0, 1) unless $theSort eq 'num';

    my $itemFormat = $theFormat;
    if ($thePattern && $item =~ m/$thePattern/) {
      my $arg1 = $1;
      my $arg2 = $2;
      my $arg3 = $3;
      my $arg4 = $4;
      my $arg5 = $5;
      my $arg6 = $6;
      my $arg7 = $7;
      my $arg8 = $8;
      my $arg9 = $9;
      my $arg10 = $10;

      $arg1 = '' unless defined $arg1;
      $arg2 = '' unless defined $arg2;
      $arg3 = '' unless defined $arg3;
      $arg4 = '' unless defined $arg4;
      $arg5 = '' unless defined $arg5;
      $arg6 = '' unless defined $arg6;
      $arg7 = '' unless defined $arg7;
      $arg8 = '' unless defined $arg8;
      $arg9 = '' unless defined $arg9;
      $arg10 = '' unless defined $arg10;

      $item = $arg1 if $arg1;
      $itemFormat =~ s/\$10/$arg10/g;
      $itemFormat =~ s/\$1/$arg1/g;
      $itemFormat =~ s/\$2/$arg2/g;
      $itemFormat =~ s/\$3/$arg3/g;
      $itemFormat =~ s/\$4/$arg4/g;
      $itemFormat =~ s/\$5/$arg5/g;
      $itemFormat =~ s/\$6/$arg6/g;
      $itemFormat =~ s/\$7/$arg7/g;
      $itemFormat =~ s/\$8/$arg8/g;
      $itemFormat =~ s/\$9/$arg9/g;
    }

    my %descriptor = (
      crit=>$crit,
      item=>$item,
      group=>$group,
      format=>$itemFormat,
    );
    #writeDebug("group=$descriptor{group}, item=$descriptor{item} crit=$descriptor{crit}");
    push @theList, \%descriptor;
  }

  my $listSize = scalar(@theList);
  return '' unless $listSize;

  # sort it
  @theList = sort {$a->{crit} cmp $b->{crit}} @theList if $theSort =~ /nocase|on/;
  @theList = sort {$a->{crit} <=> $b->{crit}} @theList if $theSort eq 'num';
  @theList = reverse @theList if $theReverse eq 'on';

  my $result = "<table class='fltLayoutTable' cellspacing='0' cellpadding='0'>\n<tr>\n";

  # - a col should at least contain a single group letter and one additional row 
  my $colSize = ceil($listSize / $maxCols);
  #writeDebug("maxCols=$maxCols, colSize=$colSize, listSize=$listSize");

  my $listIndex = 0;
  my $insideList = 0;
  my $itemIndex = 0;
  my $group = '';
  my @anchors = ();

  foreach my $colIndex (1..$maxCols) {
    $result .= "  <td valign='top'>\n";

    #writeDebug("new col");
    my $rowIndex = 1;
    while (1) {
      my $descriptor = $theList[$listIndex];
      my $format = $$descriptor{format};
      my $item = $$descriptor{item};
      #writeDebug("listIndex=$listIndex, itemIndex=$itemIndex, colIndex=$colIndex, rowIndex=$rowIndex, item=$item, format=$format");

      # construct group format
      my $thisGroup = $$descriptor{group};
      my $cont = '';
      if (($theGroup && $group ne $thisGroup) || $rowIndex == 1) {
        #last if $itemIndex % $colSize < 2 && $colIndex < $maxCols; # prevent schusterjunge

        if ($thisGroup eq $group && $rowIndex == 1) {
          $cont = " <span class='fltCont'>(cont.)</span>";
        } else {
          $group = $thisGroup;
        }

        if ($insideList) {
          $result .= "</ul>\n";
          $insideList = 0;
        }

        # create an anchor to this group
        my $anchor = '';
        if ($theGroup =~ /\$anchor/) {
          $anchor = $this->getAnchorName($group);
          if ($anchor)  {
            push @anchors, {
              name=>$anchor,
              title=>$group,
            };
            $anchor = "<a class='fltAnchor' name='$anchor'></a>";
          }
        }

        my $groupFormat = $theGroup;
        expandVariables($groupFormat,
          anchor=>$anchor,
          group=>$group,
          cont=>$cont,
          index=>$listIndex+1,
          count=>$listSize,
          col=>$colIndex,
          row=>$rowIndex,
          item=>$item,
        );
        $result .= $groupFormat;
      }

      # construct line
      my $text = "  <li>$format</li>\n";
      expandVariables($text,
        group=>$group,
        cont=>'',
        index=>$listIndex+1,
        count=>$listSize,
        col=>$colIndex,
        row=>$rowIndex,
        item=>$item,
      );

      unless ($insideList) {
        $insideList = 1;
        $result .= "  <ul>\n";
      }

      # add to result
      $result .= $text;

      # keep track if indexes
      $listIndex++;
      $itemIndex++;
      $rowIndex++;
      last unless $itemIndex % $colSize && $listIndex < $listSize;
    }
    if ($insideList) {
      $result .= "  </ul>\n";
      $insideList = 0;
    }
    $result .= "</td>\n";
    last unless $listIndex < $listSize;
  }
  $result .= "</tr>\n</table>";

  my $anchors = '';
  if (@anchors > $theAnchorThreshold) {
    if ($theHeader =~ /\$anchors/ || $theFooter =~ /\$anchors/) {
      $anchors = 
        "<div class='fltAnchors'>".
        join(' ', 
          map("<a href='#$_->{name}'>$_->{title}</a>", @anchors)
        ).
        '</div>';
    }
  }
  #writeDebug("anchors=$anchors");
  expandVariables($theHeader, count=>$listSize, anchors=>$anchors);
  expandVariables($theFooter, count=>$listSize, anchors=>$anchors);

  $result = 
    "<div class='fltMakeIndexWrapper'>".
      $theHeader.
      $result.
      $theFooter.
    "</div>";
  #writeDebug("result=$result");

  # count MAKEINDEX calls
  $this->{makeIndexCounter}++;

  return $result;
}

###############################################################################
sub handleFormatList {
  my ($this, $params, $theTopic, $theWeb) = @_;
  
  #writeDebug("handleFormatList(".$params->stringify().")");

  my $theList = $params->{_DEFAULT};
  $theList = $params->{list} unless defined $theList;
  $theList = '' unless defined $theList;

  my $thePattern = $params->{pattern} || '^\s*(.*?)\s*$';
  my $theFormat = $params->{format};
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theSplit = $params->{split};
  my $theSeparator = $params->{separator};
  my $theLimit = $params->{limit} || -1; 
  my $theSkip = $params->{skip} || 0; 
  my $theSort = $params->{sort} || 'off';
  my $theUnique = $params->{unique} || '';
  my $theExclude = $params->{exclude} || '';
  my $theInclude = $params->{include} || '';
  my $theReverse = $params->{reverse} || '';
  my $theSelection = $params->{selection};
  my $theMarker = $params->{marker};
  my $theMap = $params->{map};
  my $theNullFormat = $params->{null} || '';
  my $theTokenize = $params->{tokenize};
  my $theHideEmpty = Foswiki::Func::isTrue($params->{hideempty}, 1);
  my $theReplace = $params->{replace};

  $theFormat = '$1' unless defined $theFormat;
  $theSplit = '\s*,\s*' unless defined $theSplit;
  $theMarker = ' selected ' unless defined $theMarker;
  $theSeparator = ', ' unless defined $theSeparator;

  $theList = Foswiki::Func::expandCommonVariables($theList, $theTopic, $theWeb)
    if expandVariables($theList);

  #writeDebug("theList='$theList'");
  #writeDebug("thePattern='$thePattern'");
  #writeDebug("theFormat='$theFormat'");
  #writeDebug("theSplit='$theSplit'");
  #writeDebug("theSeparator='$theSeparator'");
  #writeDebug("theLimit='$theLimit'");
  #writeDebug("theSkip='$theSkip'");
  #writeDebug("theSort='$theSort'");
  #writeDebug("theUnique='$theUnique'");
  #writeDebug("theExclude='$theExclude'");
  #writeDebug("theInclude='$theInclude'");

  my %map = ();
  if ($theMap) {
    %map = map {$_ =~ /^(.*)=(.*)$/, $1=>$2} split(/\s*,\s*/, $theMap);
  }

  my %tokens = ();
  my $tokenNr = 0;
  if ($theTokenize) {
    $theList =~ s/($theTokenize)/$tokenNr++; $tokens{'token_'.$tokenNr} = $1; 'token_'.$tokenNr/gems;
  }

  my @theList = split(/$theSplit/, $theList);

  if ($theReplace) {
    my %replace = map {$_ =~ /^(.*)=(.*)$/, $1=>$2} split(/\s*,\s*/, $theReplace);
    
    foreach my $item (@theList) {
      foreach my $pattern (keys %replace) {
        $item =~ s/$pattern/$replace{$pattern}/g;
      }
    }
  }


  if ($theTokenize && $tokenNr) {
    foreach my $item (@theList) {
      foreach my $token (keys %tokens) {
        $item =~ s/$token/$tokens{$token}/g;
      }
    }
  }

  if ($theSort ne 'off') {
    if ($theSort eq 'alpha' || $theSort eq 'on') {
      @theList = sort {uc($a) cmp uc($b)} @theList;
    } elsif ($theSort eq 'num') {
      @theList = sort {$a <=> $b} @theList;
    }
  }
  @theList = reverse @theList if $theReverse eq 'on';

  my %seen = ();
  my @result;
  my $count = 0;
  my $skip = $theSkip;
  foreach my $item (@theList) {
    #writeDebug("found '$item'");
    next if $theExclude && $item =~ /^($theExclude)$/;
    next if $theInclude && $item !~ /^($theInclude)$/;
    next if $item =~ /^$/; # skip empty elements
    my $arg1 = '';
    my $arg2 = '';
    my $arg3 = '';
    my $arg4 = '';
    my $arg5 = '';
    my $arg6 = '';
    my $arg7 = '';
    my $arg8 = '';
    my $arg9 = '';
    my $arg10 = '';
    if ($item =~ m/$thePattern/) {
      $arg1 = $1;
      $arg2 = $2;
      $arg3 = $3;
      $arg4 = $4;
      $arg5 = $5;
      $arg6 = $6;
      $arg7 = $7;
      $arg8 = $8;
      $arg9 = $9;
      $arg10 = $10;

      $arg1 = '' unless defined $arg1;
      $arg2 = '' unless defined $arg2;
      $arg3 = '' unless defined $arg3;
      $arg4 = '' unless defined $arg4;
      $arg5 = '' unless defined $arg5;
      $arg6 = '' unless defined $arg6;
      $arg7 = '' unless defined $arg7;
      $arg8 = '' unless defined $arg8;
      $arg9 = '' unless defined $arg9;
      $arg10 = '' unless defined $arg10;
    } else {
      next;
    }
    my $line = $theFormat;
    $line =~ s/\$10/$arg10/g;
    $line =~ s/\$1/$arg1/g;
    $line =~ s/\$2/$arg2/g;
    $line =~ s/\$3/$arg3/g;
    $line =~ s/\$4/$arg4/g;
    $line =~ s/\$5/$arg5/g;
    $line =~ s/\$6/$arg6/g;
    $line =~ s/\$7/$arg7/g;
    $line =~ s/\$8/$arg8/g;
    $line =~ s/\$9/$arg9/g;
    $line =~ s/\$map\((.*?)\)/($map{$1}||$1)/ge;
    #writeDebug("after susbst '$line'");
    if ($theUnique eq 'on') {
      next if $seen{$line};
      $seen{$line} = 1;
    }

    $line =~ s/\$index/$count+1/ge;
    if ($theSelection && $item =~ /$theSelection/) {
      $line =~ s/\$marker/$theMarker/g 
    } else {
      $line =~ s/\$marker//go;
    }
    if ($skip-- <= 0) {
      push @result, $line unless ($theHideEmpty && $line eq '');
      $count++;
      last if $theLimit - $count == 0;
    }
  }
  #writeDebug("count=$count");
  my $result = '';
  if ($count == 0) {
    return '' unless $theNullFormat;
    $result = $theNullFormat;
  } else {
    $result = join($theSeparator, @result);
  }

  $result = $theHeader.$result.$theFooter;
  $result =~ s/\$count/$count/g;

  expandVariables($result);
  return $result;
}

###############################################################################
sub getAnchorName {
  my ($this, $text) = @_;

  $text = $text.'_'.$this->{makeIndexCounter};
  return '' if $this->{seenAnchorNames}{$text};
  $this->{seenAnchorNames}{$text} = 1;

  if ($Foswiki::Plugins::VERSION > 2.0) {
    require Foswiki::Render::Anchors;
    my $anchor = Foswiki::Render::Anchors::make($text);
    return Foswiki::urlEncode($anchor);
  } else {
    return $this->{session}->renderer->makeAnchorName($text);
  }
}

###############################################################################
sub expandVariables {
  my ($text, %params) = @_;

  return 0 unless $text;

  my $found = 0;

  foreach my $key (keys %params) {
    $found = 1 if $text =~ s/\$$key\b/$params{$key}/g;
  }

  $found = 1 if $text =~ s/\$perce?nt/\%/go;
  $found = 1 if $text =~ s/\$nop//go;
  $found = 1 if $text =~ s/\$n/\n/go;
  $found = 1 if $text =~ s/\$dollar/\$/go;

  $_[0] = $text if $found;

  return $found;
}

###############################################################################
sub inlineError {
  return "<span class='foswikiAlert'>".$_[0]."</span>";
}

###############################################################################
sub writeDebug {
  print STDERR "- FilterPlugin - $_[0]\n" if DEBUG;
}


1;
