# Copyright (C) 2007-2011 Michael Daum http://michaeldaumconsulting.com
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
package Foswiki::Plugins::SetVariablePlugin::Core;

use strict;
use constant DEBUG => 0; # toggle me
use constant ACTION_UNSET => 0;
use constant ACTION_SET => 1;
use Foswiki ();

###############################################################################
# constructor
sub new {
  my $class = shift;

  return bless({}, $class);
}

###############################################################################
# static
sub writeDebug {
  #Foswiki::Func::writeDebug("- SetVariablePlugin - ".$_[0]) if DEBUG;
  print STDERR "- SetVariablePlugin - ".$_[0]."\n" if DEBUG;
}

###############################################################################
sub addRule {
  my $this = shift;
  my $action = shift;

  my $record = {
    action => $action,
    @_
  };

  push @{$this->{rules}}, $record;

  return $record;
}

###############################################################################
sub applyRules {
  my ($this, $web, $topic, $meta, $text) = @_;

  return unless $this->{rules};

  $text ||= '';

#  if (DEBUG) {
#    require Data::Dumper;
#    writeDebug(Data::Dumper->Dump([$this->{rules}]));
#  }

  my @fields = $meta->find('FIELD');

  # itterate over all rules in the given order 
  foreach my $record (sort {$b->{prio} <=> $a->{prio}} @{$this->{rules}}) {

    # check conditions
    if ($record->{field}) {
      next unless defined $record->{regex}; # illegal rule
      my $found = 0;
      foreach my $field (@fields) {
        my $name = $field->{name} || '';
        my $value = $field->{value} || '';
        if ($name eq $record->{field} && $value =~ /^($record->{regex})$/) {
          # MODAC : If the value isn´t set take the value of the formfield
          if (!$record->{value}){
          	$record->{value} = $field->{value};
          }
          
          $found = 1;
          last;
        }
      }
      next unless $found;
    } else {
      if ($record->{regex}) { # check against topic text
        next unless $text =~ /$record->{regex}/;
      }
    }

    # get settings 
    my $var = $record->{var};
    my $type = $record->{type} || 'Local';
    my $value = expandVariables($record->{value});
    if (defined $value) {
      $value = Foswiki::Func::expandCommonVariables($value, $topic, $web);
    }

    if ($record->{action} eq ACTION_SET && defined($value)) {
      writeDebug("... setting preference $var to $value, type=$type, prio=$record->{prio}");
      $meta->putKeyed('PREFERENCE', {name=>$var, title => $var, value => $value, type => $type});
    } else { # unset
      writeDebug("... unsetting preference $var, prio=$record->{prio}");
      $meta->remove('PREFERENCE', $record->{var});
    }
  }

  return $meta;
}

###############################################################################
sub handleSetVar {
  my ($this, $session, $params, $topic, $web) = @_;

  writeDebug("handleSetVar(".$params->stringify().")");

  $this->addRule(ACTION_SET,
    var => ($params->{_DEFAULT} || $params->{var}),
    value => ($params->{value} || ''),
    type => ($params->{type} || 'Local'),
    field => $params->{field},
    regex => ($params->{match} || $params->{matches} || $params->{regex} || '.*'),
    prio => 1,
  );

  return '';
}

###############################################################################
sub handleGetVar {
  my ($this, $session, $params, $topic, $web) = @_;

  my $theTopic = $params->{topic} || $topic;
  my $theWeb = $params->{web} || $web;
  my $theVar = $params->{_DEFAULT};
  my $theFormat = $params->{format};
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theSep = $params->{separator};
  my $theType = $params->{type} || 'PREFERENCE';
  my $theSort = $params->{sort} || 'off';
  my $theDefault = $params->{default} || '';
  my $theScope = $params->{scope} || 'topic'; # web, user, session
  
  $theFormat = '$value' unless defined $theFormat;
  $theSep = ', ' unless defined $theSep;

  ($theWeb, $theTopic) = Foswiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  my @result;
  my @metas;
  my $wikiName = Foswiki::Func::getWikiName();

  #writeDebug("handleGetVar - topic=$theWeb.$theTopic, wikiName=$wikiName, scope=$theScope, type=$theType, var=$theVar");

  # get meta
  if ($theScope eq 'user') {
    ($theWeb, $theTopic) = Foswiki::Func::normalizeWebTopicName($Foswiki::cfg{UsersWebName}, $wikiName);
    $theScope = 'topic';
  }
  if ($theScope eq 'topic') {
    my ($meta, $text) = Foswiki::Func::readTopic($theWeb, $theTopic);
    
    if (!Foswiki::Func::checkAccessPermission("VIEW", $wikiName, $text, $topic, $web, $meta)) {
      writeDebug("no view access");
      return '';
    }
    @metas = $meta->find($theType);
    #writeDebug("found ".scalar(@metas)." metas");
  } elsif ($theScope eq 'web') {
    my $value = Foswiki::Func::getPreferencesValue($theVar, $theWeb);
    if (defined $value) {
      my $meta = {
        name=> $theVar,
        title=> $theVar,
        value=> $value,
        type => 'Web',
      };
      push @metas, $meta;
    }
  } elsif ($theScope eq 'session') {
    my @keys = Foswiki::Func::getSessionKeys();
    foreach my $key (@keys) {
      next if $key =~ /^_/;
      my $value = Foswiki::Func::getSessionValue($key);
      next unless defined $value;
      push @metas, {
        name=> $key,
        title=> $key,
        value=> $value,
        type=> 'Session',
      };
    }
  }

  return $theDefault unless @metas;

  # preprocess
  if ($theSort eq 'on') {
    @metas = sort {$a->{name} cmp $b->{name}} @metas;
  }

  # filter and format
  foreach my $meta (@metas) {
    if ($theVar && $meta->{name} =~ /$theVar/) {
      push @result, expandVariables($theFormat, %$meta);
    }
  }
  return $theDefault unless @result;

  return $theHeader.join($theSep, @result).$theFooter;
}

###############################################################################
sub handleUnsetVar {
  my ($this, $session, $params, $topic, $web) = @_;

  writeDebug("handleUnsetVar(".$params->stringify().")");

  $this->addRule(ACTION_UNSET,
    var => ($params->{_DEFAULT} || $params->{var}),
    field => $params->{field},
    regex => ($params->{match} || $params->{matches} || $params->{regex} || '.*'),
    prio => 1,
  );

  return '';
}

###############################################################################
sub handleDebugRules {
  my ($this, $session, $params, $topic, $web) = @_;

  #writeDebug("handleDebugRules(".$params->stringify().")");
  
  my $result = '| *Action* | *Type* | *Variable* | *Value* | *Property* | *Match* |'."\n";
  foreach my $record (@{$this->{rules}}) {
    $result .= '|'.($record->{action}?'set':'unset');
    $result .= '|'.$record->{type},
    $result .= '|'.$record->{var};
    $result .= '|'.($record->{value}?$record->{value}:'&nbsp;');
    $result .= '|'.($record->{field}?$record->{field}:'text');
    $result .= '|'.$record->{regex};
    $result .= "|\n";
  }

  return $result;
}

###############################################################################
sub handleBeforeSave {
  my ($this, $text, $topic, $web, $meta) = @_;

  return if $this->{_insideBeforeSaveHandler};
  $this->{_insideBeforeSaveHandler} = 1;
  writeDebug("handleBeforeSave($web.$topic)");

  # get the rules NOW
  my $template = Foswiki::Func::getPreferencesValue('VIEW_TEMPLATE') || 'view';
  my $tmpl = Foswiki::Func::readTemplate($template);
  $tmpl =~ s/\%TEXT%/$text/g;

  # Disable most macros in the text... we only care about those that probably bring in a [GET,SET,UNSET,DEL]VAR
  # TODO: can we perform all INCLUDEs and DBCALLs only before disabling everything else?
  $text =~ s/%((?!(GETVAR|SETVAR|DELVAR|UNSETVAR))$Foswiki::regex{tagNameRegex}({.*?})?)%/%<nop>$1%/gms;
  $text = Foswiki::Func::expandCommonVariables($tmpl, $topic, $web);

  # create rules from Set+VARNAME, Local+VARNAME, Unset+VARNAME and Default+VARNAME urlparams
  my $request = Foswiki::Func::getCgiQuery();
  foreach my $key ($request->param()) {

    next unless $key =~ /^(Local|Set|Unset)\+(.*)$/;
    my $type = $1;
    my $name = $2;
    my @values = $request->param($key);
    next unless @values;
    @values = grep {!/^$/} @values if @values > 1;
    my $value = join(", ", @values);
    writeDebug("key=$key, value=$value");

    # convert a set to an unset if that's already default
    if ($type =~ /Local|Set/) {
      my @defaultValues = $request->param("Default+$name");
      if (@defaultValues) {
        @defaultValues = grep {!/^$/} @defaultValues if @defaultValues > 1;
        my $defaultValue = join(', ', @defaultValues);
        if ($defaultValue eq $value) {
          $type = 'Unset';
          #writeDebug("found set to default/undef ... unsetting ".$name);
        }
      }
    }

    # create a rule
    if ($type eq 'Unset') {
      $this->addRule(ACTION_UNSET,
        var => $name,
        prio => 2,
      );
    } else {
      $this->addRule(ACTION_SET,
        var => $name,
        value => $value,
        type => $type,
        prio => 2,
      );
    }
  }

  # execute rules in the given order
  $this->applyRules($web, $topic, $meta, $text);

  $this->{_insideBeforeSaveHandler} = 0;
}

###############################################################################
# static
sub expandVariables {
  my ($theFormat, %params) = @_;

  return '' unless $theFormat;

  my $mixedAlphaNum = Foswiki::Func::getRegularExpression('mixedAlphaNum');
  
  foreach my $key (keys %params) {
    next if $key =~ /^_/;
    my $val = $params{$key} || '';
    $theFormat =~ s/\$$key\b/$val/g;
  }
  $theFormat =~ s/\$percnt/\%/go;
  $theFormat =~ s/\$dollar/\$/go;
  $theFormat =~ s/\$nop//go;
  $theFormat =~ s/\$n([^$mixedAlphaNum]|$)/\n$1/go;

  return $theFormat;
}

1;
