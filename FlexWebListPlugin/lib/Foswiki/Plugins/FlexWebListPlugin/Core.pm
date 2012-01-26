# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2012 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::FlexWebListPlugin::Core;

use strict;

use Foswiki::Func ();
use Foswiki::Plugins ();
use constant DEBUG => 0; # toggle me
our $homeTopic;

###############################################################################
# static
sub writeDebug {
  print STDERR '- FlexWebListPlugin - '.$_[0]."\n" if DEBUG;
}

###############################################################################
# constructor
sub new {
  my $class = shift;
  my $this = bless({}, $class);

  #writeDebug("new FlexWebListPlugin::Core");

  $this->{webCache} = ();
  $this->{session} = $Foswiki::Plugins::SESSION;
  $homeTopic = Foswiki::Func::getPreferencesValue('HOMETOPIC') 
    || $Foswiki::cfg{HomeTopicName} || 'WebHome';

  return $this;
}

###############################################################################
sub handler {
  my ($this, $session, $params, $currentTopic, $currentWeb) = @_;

  #writeDebug("*** called %FLEXWEBLIST{".$params->stringify."}%");

  # extract parameters
  $this->{format} = $params->{_DEFAULT};
  $this->{format} = $params->{format} unless defined $this->{format};
  $this->{format} = '$web ' unless defined $this->{format};
  $this->{webs} = $params->{webs} || 'public';
  $this->{header} = $params->{header} || '';
  $this->{footer} = $params->{footer} || '';
  $this->{separator} = $params->{separator} || '';
  $this->{separator} = '' if $this->{separator} eq 'none';

  $this->{subHeader} = $params->{subheader};
  $this->{subHeader} = $this->{header} unless defined $this->{subHeader};

  $this->{subFormat} = $params->{subformat};
  $this->{subFormat} = $this->{format} unless defined $this->{subFormat};

  $this->{subFooter} = $params->{subfooter};
  $this->{subFooter} = $this->{footer} unless defined $this->{subFooter};

  $this->{subSeparator} = $params->{subseparator};
  $this->{subSeparator} = $this->{separator} unless defined $this->{subSeparator};
  $this->{subSeparator} = '' if $this->{subSeparator} eq 'none';

  $this->{markerFormat} = $params->{markerformat};
  $this->{markerFormat} = $this->{format} unless defined $this->{markerFormat};

  $this->{selection} = $params->{selection} || '';
  $this->{marker} = $params->{marker} || '';
  $this->{exclude} = $params->{exclude} || '';
  $this->{include} = $params->{include} || '';
  $this->{subWebs} = $params->{subwebs} || 'all';
  $this->{adminwebs} = $params->{adminwebs} || '';
  $this->{ignorecase} = $params->{ignorecase} || 'off';

  if ($this->{adminwebs}) {
    $this->{isAdmin} = isAdmin();
  } else {
    $this->{isAdmin} = '';
  }

  $this->{selection} =~ s/\,/ /go;
  $this->{selection} = ' '.$this->{selection}.' ';

  $this->{include} =~ s/\//\\\//g;
  writeDebug("include filter=/^($this->{include})\$/") if $this->{include};
  #writeDebug("exclude filter=/^($this->{exclude})\$/") if $this->{exclude};

  
  # compute map
  my $theMap = $params->{map} || '';
  $this->{map} = ();
  foreach my $entry (split(/\s*,\s*/, $theMap)) {
    if ($entry =~ /^(.*)=(.*)$/) {
      $this->{map}{$1} = $2;
    }
  }
  
  # compute list
  my %seen;
  my @list = ();
  my @websList = map {s/^\s+//go; s/\s+$//go; s/\./\//go; $_} split(/\s*,\s*/, $this->{webs});
  #writeDebug("websList=".join(',', @websList));
  my $allWebs = $this->getWebs();

  # collect the list in preserving the given order in webs parameter
  foreach my $aweb (@websList) {
    if ($aweb =~ /^(public|webtemplate)(current)?$/) {
      $aweb = $1;
      my @webs;
      if (defined $2 && Foswiki::Func::webExists($currentWeb)) {
	push @webs, $currentWeb
      }
      push @webs, keys %{$this->getWebs($aweb)};
      foreach my $bweb (sort @webs) {
	next if $seen{$bweb};
	$seen{$bweb} = 1;
	push @list, $bweb;
      }

    } else {
      next if $seen{$aweb};
      $seen{$aweb} = 1;
      push @list, $aweb if defined $allWebs->{$aweb}; # only add if it exists
    }
  }
  #writeDebug("list=".join(',', @list));

  # filter webs by setting the 'enabled' flag
  foreach my $aweb (@list) {
    my $web = $allWebs->{$aweb};
    next unless $web;
    $web->{enabled} = 0;
    next if $web->{isSubWeb} && $this->{subWebs} eq 'none';
    if ($this->{ignorecase} eq 'on') {
      next if $this->{exclude} ne '' && $web->{key} =~ /^($this->{exclude})$/i;
      next if $this->{include} ne '' && $web->{key} !~ /^($this->{include})$/i;
    } else {
      next if $this->{exclude} ne '' && $web->{key} =~ /^($this->{exclude})$/;
      next if $this->{include} ne '' && $web->{key} !~ /^($this->{include})$/;
    }
    next if $this->{adminwebs} ne '' && !$this->{isAdmin} &&
      $web->{key} =~ /^($this->{adminwebs})$/;
    $web->{enabled} = 1;
  }

  # format result
  my @result;
  foreach my $aweb (@list) {
    my $web = $allWebs->{$aweb};

    # filter explicite subwebs
    next if $this->{subWebs} !~ /^(all|none|only)$/ && $web->{key} !~ /$this->{subWebs}\/[^\/]*$/;

    # start recursion
    my $line = $this->formatWeb($web, $this->{format});
    push @result, $line if $line;
  }

  # reset 'done' flag
  foreach my $aweb (keys %$allWebs) {
    $allWebs->{$aweb}{done} = 0;
  }

  return '' unless @result;

  my $result = join($this->{separator},@result);
  $result = $this->{header}.$result.$this->{footer};
  $result =~ s/\$marker//g;
  escapeParameter($result);
  #writeDebug("result=$result");
  $result = Foswiki::Func::expandCommonVariables($result, $currentTopic, $currentWeb);

  #writeDebug("*** handler done");

  return $result;
}

###############################################################################
sub formatWeb {
  my ($this, $web, $format) = @_;

  # check conditions to format this web
  return '' if $web->{done} || !$web->{enabled};
  $web->{done} = 1;

  #writeDebug("formatWeb($web->{key})");

  # format all subwebs recursively
  my $subWebResult = '';
  my @lines;
  foreach my $subWeb (@{$web->{children}}) {
    # filter explicite subwebs
    next if $this->{subWebs} !~ /^(all|none|only)$/ && $subWeb->{key} !~ /$this->{subWebs}\/[^\/]*$/;
    my $line = $this->formatWeb($subWeb, $this->{subFormat}); # recurse
    push @lines, $line if $line;
  }
  if (@lines) {
    my $header = $this->{subHeader};
    my $footer = $this->{subFooter};
    if ($this->{selection} =~ / \Q$web->{key}\E /) {
      $header =~ s/\$marker/$this->{marker}/g;
      $footer =~ s/\$marker/$this->{marker}/g;
    }
    $subWebResult = $this->{subHeader}.join($this->{subSeparator},@lines).$this->{subFooter};
  }

  my $result = '';
  if (!$web->{isSubWeb} && $this->{subWebs} eq 'only') {
    $result = $subWebResult;
  } else {
    if ($this->{selection} =~ / \Q$web->{key}\E /) {
      $format = $this->{markerFormat};
      $format =~ s/\$marker/$this->{marker}/g;
    }
    $result = $format.$subWebResult;
  }
  my $nrSubWebs = @{$web->{children}};
  my $name = $this->{map}{$web->{name}} || $web->{name};

  my $url = '';
  if ($result =~ /\$url/) {
    $url = $this->{session}->getScriptUrl(0, 'view', $web->{key}, $homeTopic);
  }

  my $sitemapUseTo = '';
  if ($result =~ /\$sitemapuseto/) {
    $sitemapUseTo = 
      Foswiki::Func::getPreferencesValue('SITEMAPUSETO', $web->{key}) || '';

    $sitemapUseTo =~ s/"/&quot;/g;
    $sitemapUseTo =~ s/<nop>/#nop#/g;
    $sitemapUseTo =~ s/<[^>]*>//g;
    $sitemapUseTo =~ s/#nop#/<nop>/g;
  }

  my $sitemapWhat = '';
  if ($result =~ /\$sitemapwhat/) {
    $sitemapWhat = 
      Foswiki::Func::getPreferencesValue('SITEMAPWHAT', $web->{key}) || '';

    $sitemapWhat =~ s/"/&quot;/g;
    $sitemapWhat =~ s/<nop>/#nop#/g;
    $sitemapWhat =~ s/<[^>]*>//g;
    $sitemapWhat =~ s/#nop#/<nop>/g;
  }

  my $color = '';
  if ($result =~ /\$color/) {
    $color =
      Foswiki::Func::getPreferencesValue('WEBBGCOLOR', $web->{key}) || '';
  }

  $result =~ s/\$parent/$web->{parentName}/go;
  $result =~ s/\$name/$name/go;
  $result =~ s/\$origname/$web->{name}/go;
  $result =~ s/\$qname/"$web->{key}"/g;# historical
  $result =~ s/\$web/$web->{key}/go;
  $result =~ s/\$depth/$web->{depth}/go;
  $result =~ s/\$indent\((.+?)\)/$1 x $web->{depth}/ge;
  $result =~ s/\$indent/'   ' x $web->{depth}/ge;
  $result =~ s/\$nrsubwebs/$nrSubWebs/g;
  $result =~ s/\$url/$url/g;
  $result =~ s/\$sitemapuseto/$sitemapUseTo/g;
  $result =~ s/\$sitemapwhat/$sitemapWhat/g;
  $result =~ s/\$color/$color/g;

  #writeDebug("result=$result");
  #writeDebug("done formatWeb($web->{key})");

  return $result;
}

###############################################################################
# get a hash of all webs, each web points to its subwebs, each subweb points
# to its parent
sub getWebs {
  my ($this,$filter) = @_;

  $filter ||= '';

  #writeDebug("getWebs($filter)");

  # lookup cache 
  return $this->{webCache}{$filter} if defined $this->{webCache}{$filter};

  my @webs = ();
  
  if ($filter eq 'public') {
    @webs = Foswiki::Func::getListOfWebs('user,public,allowed');
  } elsif ($filter eq 'webtemplate') {
    @webs = Foswiki::Func::getListOfWebs('template,allowed');
  } else {
    @webs = Foswiki::Func::getListOfWebs($filter);
  }
  my $webs = $this->hashWebs(@webs);

  # cache weblist
  $this->{webCache}{$filter} = $webs;

  #writeDebug("result=".join(',',@webs));
  return $webs;
}

###############################################################################
# convert a flat list of webs to a structured parent-child structure;
# the returned hash contains elements of the form
# {
#   key => the full webname (e.g. Main/Foo/Bar)
#   name => the tail of the webname (e.g. Bar)
#   isSubWeb => 1 if the web is a subweb, 0 if it is a top-level web
#   parentName => only defined for subwebs
#   parent => pointer to parent web structure
#   children => list of pointers to subwebs
# }
sub hashWebs {
  my $this = shift;
  my @webs = @_;

  #writeDebug("hashWebs(".join(',', sort @webs));

  my %webs;
  # collect all webs
  foreach my $key (@webs) {
    $webs{$key}{key} = $key;
    if ($key =~ /^(.*)\/(.*?)$/) {
      $webs{$key}{isSubWeb} = 1;
      $webs{$key}{parentName} = $1;
      $webs{$key}{name} = $2;
    } else {
      $webs{$key}{name} = $key;
      $webs{$key}{isSubWeb} = 0;
      $webs{$key}{parentName} = '';
    }
    $webs{$key}{depth} = ($key =~ tr/\///);
  }

  # establish parent-child relation
  foreach my $key (@webs) {
    my $parentName = $webs{$key}{parentName};
    if ($parentName) {
      $webs{$key}{parent} = $webs{$parentName};
      push @{$webs{$parentName}{children}}, $webs{$key}
        if defined $webs{$parentName};
    }
  }
  #writeDebug("keys=".join(',',sort keys %webs));

  return \%webs;
}

###############################################################################
# compatibility wrapper
sub isAdmin { 

  if ($Foswiki::Plugins::VERSION >= 1.2) {
    return Foswiki::Func::isAnAdmin();
  }

  my $user = $Foswiki::Plugins::SESSION->{user};
  if ($user) {
    return $user->isAdmin();
  }

  # do we need to support more legacy apis

  return 0;
}

###############################################################################
sub escapeParameter {
  return '' unless $_[0];

  $_[0] =~ s/\$nop//g;
  $_[0] =~ s/\$n/\n/g;
  $_[0] =~ s/\$percnt/%/g;
  $_[0] =~ s/\$dollar/\$/g;
}



###############################################################################
1;
