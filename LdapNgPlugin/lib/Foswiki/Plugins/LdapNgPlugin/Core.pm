# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2011 Michael Daum http://michaeldaumconsulting.com
# Portions Copyright (C) 2006 Spanlink Communications
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

package Foswiki::Plugins::LdapNgPlugin::Core;

use strict;
use Foswiki::Contrib::LdapContrib ();
use Digest::MD5 ();
use Cache::FileCache();

use constant DEBUG => 0; # toggle me

###############################################################################
sub new {
  my ($class, $session) = @_;

  my $this = bless({
    session => $session
  }, $class);

  $this->{cache} = new Cache::FileCache({
    'namespace'  => 'LdapNgPlugin',
    'cache_root' => Foswiki::Func::getWorkArea('LdapNgPlugin').'/cache/',
    'cache_depth'     => 3,
    'directory_umask' => 077,
  });


  return $this;
}

###############################################################################
sub writeDebug {
  # comment me in/out
  #&Foswiki::Func::writeDebug('- LdapNgPlugin - '.$_[0]) if DEBUG;
  print STDERR 'LdapNgPlugin - '.$_[0]."\n" if DEBUG;
}

###############################################################################
sub handleLdap {
  my ($this, $params, $topic, $web) = @_;

  #writeDebug("called handleLdap($web, $topic)");
  my $fingerPrint = $params->stringify;
  $fingerPrint = Digest::MD5::md5_hex($fingerPrint);
  writeDebug("fingerPrint=$fingerPrint");

  my $data = $this->{cache}->get($fingerPrint);
  if ($data) {
    writeDebug("found response in cache");
    return $data;
  }

  # get args
  my $theCache = $params->{cache} || $Foswiki::cfg{Ldap}{DefaultCacheExpire};
  my $theFilter = $params->{'filter'} || $params->{_DEFAULT} || '';
  my $theBase = $params->{'base'} || $Foswiki::cfg{Ldap}{Base} || '';
  my $theHost = $params->{'host'} || $Foswiki::cfg{Ldap}{Host} || 'localhost';
  my $thePort = $params->{'port'} || $Foswiki::cfg{Ldap}{Port} || '389';
  my $theVersion = $params->{version} || $Foswiki::cfg{Ldap}{Version} || 3;
  my $theSSL = $params->{ssl} || $Foswiki::cfg{Ldap}{SSL} || 0;
  my $theScope = $params->{scope} || 'sub';
  my $theFormat = $params->{format} || '$dn';
  my $theHeader = $params->{header} || ''; 
  my $theFooter = $params->{footer} || '';
  my $theSep = $params->{separator};
  my $theSort = $params->{sort} || '';
  my $theReverse = $params->{reverse} || 'off';
  my $theLimit = $params->{limit} || 0;
  my $theSkip = $params->{skip} || 0;
  my $theHideNull = $params->{hidenull} || 'off';
  my $theClear = $params->{clear} || '';
  my $theExclude = $params->{exclude} || '';
  my $theInclude = $params->{include} || '';
  my $theCasesensitive = $params->{casesensitive} || 'on';

  $theSep = $params->{sep} unless defined $theSep;
  $theSep = '$n' unless defined $theSep;
  my $query = Foswiki::Func::getCgiQuery();
  my $theRefresh = $query->param('refresh') || 0;
  $theRefresh = ($theRefresh eq 'on')?1:0;

  # fix args
  $theSkip =~ s/[^\d]//go;
  $theLimit =~ s/[^\d]//go;
  my @theSort = split(/[\s,]+/, $theSort);
  $theBase = $1.','.$Foswiki::cfg{Ldap}{Base} if $theBase =~ /^\((.*)\)$/;
  #writeDebug("base=$theBase");
  #writeDebug("format=$theFormat");

  # new connection
  my $ldap = new Foswiki::Contrib::LdapContrib(
    $this->{session},
    base=>$theBase,
    host=>$theHost,
    port=>$thePort,
    version=>$theVersion,
    ssl=>$theSSL,
  );

  # search 
  my $search = $ldap->search(
    filter=>$theFilter, 
    base=>$theBase, 
    scope=>$theScope, 
    sizelimit=>($theReverse eq 'on')?0:$theLimit
  );
  unless (defined $search) {
    return &inlineError('ERROR: '.$ldap->getError());
  }

  my $count = $search->count() || 0;
  return '' if ($count <= $theSkip) && $theHideNull eq 'on';

  # format
  my $result = '';
  my @entries = $search->sorted(@theSort);
  @entries = reverse @entries if $theReverse eq 'on';
  my $index = 0;
  foreach my $entry (@entries) {
    my $dn = $entry->dn();
    
    if ( $theCasesensitive eq 'off' ) {
    	next if $theExclude && $dn =~ /$theExclude/i;
    	next if $theInclude && $dn !~ /$theInclude/i;
    } else {
    	next if $theExclude && $dn =~ /$theExclude/;
    	next if $theInclude && $dn !~ /$theInclude/;
    }

    $index++;
    next if $index <= $theSkip;

    my %data;
    $data{dn} = $dn;
    $data{index} = $index;
    $data{count} = $count;
    foreach my $attr ($entry->attributes()) {
      if ($attr =~ /jpegPhoto/) { # TODO make blobs configurable 
	$data{$attr} = $ldap->cacheBlob($entry, $attr, $theRefresh);
      } else {
	$data{$attr} = $entry->get_value($attr, asref=>1);
      }
    }
    my $text = '';
    $text .= $theSep if $result;
    $text .= $theFormat;
    $text = expandVars($text, %data);
    $result .= $text;
    last if $index == $theLimit;
  }
  $ldap->disconnect();

  $theHeader = expandVars($theHeader,count=>$count) if $theHeader;
  $theFooter = expandVars($theFooter,count=>$count) if $theFooter;

  $result = $ldap->fromUtf8($result);
  $result = $theHeader.$result.$theFooter;

  #writeDebug("done handleLdap()");
  #writeDebug("result=$result");

  if ($theClear) {
    $theClear =~ s/\$/\\\$/g;
    my $regex = join('|',split(/[\s,]+/,$theClear));
    $result =~ s/$regex//g;
  }

  if ($theCache) {
    $this->{cache}->set($fingerPrint, $result, $theCache);
  }

  return $result;
}

###############################################################################
sub handleLdapUsers {
  my ($this, $params, $topic, $web) = @_;

  #writeDebug("called handleLdapUsers($web, $topic)");

  my $ldap = Foswiki::Contrib::LdapContrib::getLdapContrib($this->{session});
  my $theHeader = $params->{header} || ''; 
  my $theFormat = $params->{format} || '   1 $displayName';
  my $theFooter = $params->{footer} || '';
  my $theSep = $params->{separator};
  my $theLimit = $params->{limit} || 0;
  my $theSkip = $params->{skip} || 0;
  my $theInclude = $params->{include};
  my $theExclude = $params->{exclude};
  my $theCasesensitive = $params->{casesensitive} || 'on';
  my $theHideUnknownUsers = $params->{hideunknown} || 'on';
  $theHideUnknownUsers = ($theHideUnknownUsers eq 'on')?1:0;

  $theSep = $params->{sep} unless defined $theSep;
  $theSep = '$n' unless defined $theSep;

  my $mainWeb = Foswiki::Func::getMainWebname();
  my $wikiNames = $ldap->getAllWikiNames();
  my $result = '';
  $theSkip =~ s/[^\d]//go;
  $theLimit =~ s/[^\d]//go;

  my $index = 0;
  foreach my $wikiName (sort @$wikiNames) {
    
    if ( $theCasesensitive eq 'off' ) {
    	next if $theExclude && $wikiName =~ /$theExclude/i;
    	next if $theInclude && $wikiName !~ /$theInclude/i;
    } else {
    	next if $theExclude && $wikiName =~ /$theExclude/;
    	next if $theInclude && $wikiName !~ /$theInclude/;
    }

    my $loginName = $ldap->getLoginOfWikiName($wikiName);
    my $emailAddrs = $ldap->getEmails($loginName);
    my $distinguishedName = $ldap->getDnOfLogin($loginName) || '';
    my $displayName;
    if (Foswiki::Func::topicExists($mainWeb, $wikiName)) {
      $displayName = "[[$mainWeb.$wikiName][$wikiName]]";
    } else {
      next if $theHideUnknownUsers;
      $displayName ="<nop>$wikiName";
    }
    $index++;
    next if $index <= $theSkip;
    my $line;
    $line = $theSep if $result;
    $line .= $theFormat;
    $line = expandVars($line,
      index=>$index,
      wikiName=>$wikiName,
      displayName=>$displayName,
      dn=>$distinguishedName,
      loginName=>$loginName,
      emails=>$emailAddrs);
    $result .= $line;
    last if $index == $theLimit;
  }

  return expandVars($theHeader).$result.expandVars($theFooter);
}

###############################################################################
sub handleEmailToWikiName {
  my ($this, $params, $topic, $web) = @_;


  my $theFormat = $params->{format} || '$wikiname';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theSep = $params->{separator};
  my $theEmail = $params->{_DEFAULT} || $params->{email} || '';

  $theSep = ', ' unless defined $theSep;

  my @wikiNames = Foswiki::Func::emailToWikiNames($theEmail, 1);
  my $mainWeb = Foswiki::Func::getMainWebname();
  my @result = ();
  my $count = scalar(@wikiNames);
  my $index = 0;
  foreach my $wikiName (sort @wikiNames) {
    $index++;
    my $line = $theFormat;
    my $wikiUserName = $mainWeb.'.'.$wikiName;
    $line =~ s/\$wikiname/$wikiName/g;
    $line =~ s/\$wikiusername/$wikiUserName/g;
    $line =~ s/\$index/$index/g;
    $line =~ s/\$count/$count/g;
    push @result, $line;
  }
  return '' unless @result;

  $theHeader =~ s/\$count/$count/g;
  $theFooter =~ s/\$count/$count/g;

  return $theHeader.join($theSep, @result).$theFooter;
}

###############################################################################
sub inlineError {
  return "<div class=\"foswikiAlert\">$_[0]</div>";
}

###############################################################################
sub expandVars {
  my ($format, %data) = @_;

  #writeDebug("called expandVars($format, '".join(',',keys %data).")");

  foreach my $key (keys %data) {
    my $value = $data{$key};
    next unless defined $value;
    $value = join(', ', sort @$value) if ref($data{$key}) eq 'ARRAY';

    # Format list values using the '$' delimiter in multiple lines; see rfc4517
    $value =~ s/([^\\])\$/$1<br \/>/go; 
    $value =~ s/\\\$/\$/go;
    $value =~ s/\\\\/\\/go;

    $format =~ s/\$$key\b/$value/gi;
    #writeDebug("$key=$value");
  }

  $format =~ s/\$nop//go;
  $format =~ s/\$n/\n/go;
  $format =~ s/\$quot/\"/go;
  $format =~ s/\$percnt/\%/go;
  $format =~ s/\$dollar/\$/go;

  #writeDebug("done expandVars()");
  return $format;
}

1;
