# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# MetaDataPlugin is Copyright (C) 2011-2012 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::MetaDataPlugin::Core;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Meta ();
use Foswiki::Form ();
use Foswiki::Time ();
use Foswiki::Form::Label ();
use Error qw( :try );
#use Data::Dumper();

use constant DEBUG => 0; # toggle me

##############################################################################
sub writeDebug {
  print STDERR "MetaDataPlugin::Core - $_[0]\n" if DEBUG;
}

##############################################################################
sub new {
  my ($class, $session) = @_;

  my $this = bless({
    baseWeb => $session->{webName},
    baseTopic => $session->{topicName},
    session => $session,
  }, $class);

  return $this;
}

##############################################################################
sub init {
  my $this = shift;

  writeDebug("called MetaDataPlugin::Core::init()");
  
  my $result = Foswiki::Func::readTemplate("metadataplugin");
  Foswiki::Func::expandCommonVariables($result);
}

##############################################################################
sub registerDeleteHandler {
  my ($this, $metaData, $function, $options) = @_;

  writeDebug("registerDeleteHandler($this, $metaData, $function)");

  push @{$this->{deleteHandler}{$metaData}}, {
    function => $function,
    options => $options,
  };
}
##############################################################################
sub NEWMETADATA {
  my ($this, $params) = @_;

  my $theMetaData = lc($params->{_DEFAULT} || $params->{meta} || '');
  my $theTitle = $params->{title};
  my $theFormat = $params->{format};
  my $theTemplate = $params->{template} || 'metadata::new';
  my $theTopic = $params->{topic} || $this->{baseWeb}.'.'.$this->{baseTopic};

  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($this->{baseWeb}, $theTopic);
  $theTopic = "$web.$topic";

  $theTitle = "New ".ucfirst($theMetaData) unless defined $theTitle;

  $theFormat = Foswiki::Func::expandTemplate($theTemplate) unless defined $theFormat;
  $theFormat =~ s/%topic%/$theTopic/g;
  $theFormat =~ s/%meta%/$theMetaData/g;
  $theFormat =~ s/%title%/$theTitle/g;
  
  return $theFormat;
}

##############################################################################
sub RENDERMETADATA {
  my ($this, $params) = @_;

  #writeDebug("called RENDERMETADATA{".$params->stringify."}");

  my $metaData  = $params->{_DEFAULT};
  my $topic = $params->{topic} || $this->{baseTopic};
  my $web = $params->{web} || $this->{baseWeb};

  ($web, $topic) = Foswiki::Func::normalizeWebTopicName($web, $topic);
  my $topicObj = getTopicObject($this, $web, $topic); 


  my $result = '';
  if (defined $metaData) {
    $result = $this->renderMetaData($topicObj, $params, $metaData);
  } else {
    foreach $metaData ($this->getKnownMetaData) {
      next unless $topicObj->find($metaData);
      $result .= $this->renderMetaData($topicObj, $params, $metaData);
    }
  }

  return $result;
}

##############################################################################
sub renderMetaData {
  my ($this, $topicObj, $params, $metaData) = @_;

  my $query = Foswiki::Func::getCgiQuery();

  my $theAction = $params->{action} || 'view';
  my $theFields = $params->{field} || $params->{fields};
  my $theFormat = $params->{format};
  my $theHeader = $params->{header};
  my $theFooter = $params->{footer};
  my $theSep = $params->{separator} || '';
  my $theValueSep = $params->{valueseparator} || ', ';
  my $theInclude = $params->{include};
  my $theExclude = $params->{exclude};
  my $theIncludeAttr = $params->{includeattr};
  my $theExcludeAttr = $params->{excludeattr};
  my $theMandatory = $params->{mandatory};
  my $theHiddenFormat = $params->{hiddenformat};
  my $theHideEmpty = Foswiki::Func::isTrue($params->{hideempty}, 0);
  my $theSort = $params->{sort};
  my $theReverse = Foswiki::Func::isTrue($params->{reverse});
  my $theAutolink = Foswiki::Func::isTrue($params->{autolink}, 1);
  my $theFieldFormat = $params->{fieldformat};

  $theMandatory = " <span class='foswikiAlert'>**</span> " unless defined $theMandatory;
  $theHiddenFormat = '<input type="hidden" name="$name" value="$value" />' unless defined $theHiddenFormat; 

  $theSort = 'name' unless defined $theSort;
  $theSort = '' if $theSort eq 'off';

  my $metaDataKey = uc($metaData);
  my $metaDataDef = $Foswiki::Meta::VALIDATE{$metaDataKey};
  return inlineError("meta data $metaDataKey not found") unless defined $metaDataDef;

  my $formWeb = $this->{baseWeb};
  my $formTopic = $metaDataDef->{form};

  $formTopic = $Foswiki::cfg{SystemWebName}.'.'.ucfirst(lc($metaData)).'Form' 
    unless defined $formTopic;

# unless (defined $formTopic) {
#   print STDERR "error: no form definition found for metadata $metaDataKey\n";
#   return inlineError("no form definition found for metadata $metaDataKey");
# }

  ($formWeb, $formTopic) = Foswiki::Func::normalizeWebTopicName($formWeb, $formTopic);

  #writeDebug("formWeb=$formWeb, formTopic=$formTopic");

  unless (Foswiki::Func::topicExists($formWeb, $formTopic)) {
    return inlineError("form definition for <nop>$metaDataKey not found");
  }
  
  my $formDef = new Foswiki::Form($this->{session}, $formWeb, $formTopic);
  unless (defined $formDef) {
    return inlineError("can't parse form definition at $formWeb.$formTopic");
  }

  my @selectedFields = ();
  if ($theFields) {
    foreach my $fieldName (split(/\s*,\s*/, $theFields)) {
      $fieldName =~ s/\s*$//;
      $fieldName =~ s/^\s*//;
      my $field;
      if ($fieldName eq 'name') {
        $field = new Foswiki::Form::Label(
          session    => $this->{session},
          name       => 'name',
          title      => '#',
          attributes => 'h',
          description => '',
        );
      }  else {
        $field = $formDef->getField($fieldName);
      }
      push @selectedFields, $field if $field;
    }
  } else {
    my $nameField = new Foswiki::Form::Label(
        session    => $this->{session},
        name       => 'name',
        title      => '#',
        attributes => 'h',
        description => '',
    );
    push @selectedFields, $nameField;
    foreach my $field (@{$formDef->getFields()}) {
      next if $field->{attributes} =~ /h/i;
      push @selectedFields, $field;
    }
  }

  # default formats
  unless (defined $theHeader) {
    if ($theAction eq 'view') {
      $theHeader = '<div class=\'metaDataView\'>$n| *'.join('* | *', 
        map {
          my $title = $_->{title}; defined($params->{$title.'_title'})?$params->{$title.'_title'}:$title
        } 
        grep {$_->{name} ne 'name'}
        @selectedFields).'* |$n';
    } else {
      $theHeader = '<div class=\'metaDataEdit foswikiFormSteps\'>$n';
    }
  }

  unless (defined $theFormat) {
    if ($theAction eq 'view') {
      $theFormat = '| '.join(' | ', 
        map {
          '$'.$_->{name}
        } 
        grep {$_->{name} ne 'name'}
        @selectedFields).' $actions |$n';
    } else {
      $theFormat = '<div class=\'foswikiFormStep $metadata\'>$n<table class=\'foswikiLayoutTable\'>$n'.
        join('$n', map {'$'.$_->{name}} @selectedFields).
        '$n</table></div>';
    }
  }

  unless (defined $theFieldFormat) {
    if ($theAction eq 'view') {
      $theFieldFormat = '$value';
    } else {
      $theFieldFormat = '  <tr class="$metadata $name">$n'.
        '    <th>$title:</th>$n'.
        '    <td>$n$edit$n</td>'.
        '    <td><div class=\'foswikiFormDescription foswikiHidden\'>$description</div></td>$n'.
        '  </tr>';
    }
  }

  unless (defined $theFooter) {
    if ($theAction eq 'view') {
      $theFooter = '</div>';
    } else {
      $theFooter = '</div>';
    }
  }

  unless (defined $theSep) {
    if ($theAction eq 'view') {
      $theSep = '';
    } else {
      $theSep = '$n<hr />$n';
    }
  }

  my @result = ();
  my $name = $params->{name};
  my @metaDataRecords;
  if (defined $name) {
    my $record;
    if ($name eq 'id') { # create a new record
      $record = {
        name => 'id'
      };
    } else {
      # get it from the store
      $record = $topicObj->get($metaDataKey, $name);
    }
    push @metaDataRecords, $record if defined $record;
  } else {
    push @metaDataRecords, $topicObj->find($metaDataKey);
  }

  # sort and reverse
  sortRecords(\@metaDataRecords, $theSort) if $theSort;
  @metaDataRecords = reverse @metaDataRecords if $theReverse;

  # loop over all meta data records
  my $index = 1;
  foreach my $record (@metaDataRecords) {
    my $row = $theFormat;
    my $name = $record->{name};
    my $title = $name;

    next if $theInclude && $name !~ /^($theInclude)$/;
    next if $theExclude && $name =~ /^($theExclude)$/;

    # loop over all fields of a record
    foreach my $field (@selectedFields) {
      next unless $field;

      my $fieldName = $field->{name};
      my $fieldType = $field->{type};
      my $fieldSize = $field->{size};
      my $fieldAttrs = $field->{attributes};
      my $fieldDescription = $field->{tooltip} || $field->{description};
      my $fieldTitle = $field->{title};
      my $fieldDefiningTopic = $field->{definingTopic};
      my $fieldFormat = $theFieldFormat;

      my $origFieldName = $field->{name};
      if ($theAction eq 'edit') {
        $field->{name} = 'META:'.$metaDataKey.':'.$name.':'.$fieldName;
      }

      my $fieldAllowedValues = '';
      # CAUTION: don't use field->getOptions() on a +values field as that won't return the full valueMap...only the value part, but not the title map
      if ($field->can('getOptions') && $field->{type} !~ /\+values/) {
        #writeDebug("can getOptions");
        my $options = $field->getOptions();
        if ($options) {
          #writeDebug("options=$options");
          $fieldAllowedValues = join($theValueSep, @$options);
        }
      } else {
        #writeDebug("can't getOptions ... fallback to field->{value}");
        # fallback to field->value
        my $options = $field->{value};
        if ($options) {
          $fieldAllowedValues = join($theValueSep, split(/\s*,\s*/, $options));
        }
      }
      #writeDebug("fieldAllowedValues=$fieldAllowedValues");

      # get the list of all allowed values without any +values mapping applied
      my $fieldOrigAllowedValues = '';
      if ($field->can('getOptions')) {
        #writeDebug("can getOptions");
        my $options = $field->getOptions();
        if ($options) {
          #writeDebug("options=$options");
          $fieldOrigAllowedValues = join($theValueSep, @$options);
        }
      } else {
        #writeDebug("can't getOptions ... fallback to field->{value}");
        # fallback to field->value
        my $options = $field->{value};
        if ($options) {
          $fieldOrigAllowedValues = join($theValueSep, split(/\s*,\s*/, $options));
        }
      }
      #writeDebug("fieldOrigAllowedValues=$fieldOrigAllowedValues");

      # get the default value
      my $fieldDefault = '';
      if ($field->can('getDefaultValue')) {
        $fieldDefault = $field->getDefaultValue() || '';
      } 

      my $fieldValue = $record->{$fieldName};

      # try not to break foswiki tables
      if ($theAction eq 'view') {
        $fieldValue =~ s/\n/<br \/>/g;
      }

      $fieldSize = $params->{$fieldName.'_size'} if defined $params->{$fieldName.'_size'};
      $fieldAttrs = $params->{$fieldName.'_attributes'} if defined $params->{$fieldName.'_attributes'};
      $fieldDescription = $params->{$fieldName.'_tooltip'} if defined $params->{$fieldName.'_tooltip'};
      $fieldDescription = $params->{$fieldName.'_description'} if defined $params->{$fieldName.'_description'};
      $fieldTitle = $params->{$fieldName.'_title'} if defined $params->{$fieldName.'_title'}; 
      $fieldAllowedValues = $params->{$fieldName.'_values'} if defined $params->{$fieldName.'_values'};
      $fieldType = $params->{$fieldName.'_type'} if defined $params->{$fieldName.'_type'};
      $fieldValue = $params->{$fieldName.'_value'} if defined $params->{$fieldName.'_value'}; # or get value from macro invocation
      $fieldFormat = $params->{$fieldName.'_format'} if defined $params->{$fieldName.'_format'};
      $fieldDefault = $params->{$fieldName.'_default'} if defined $params->{$fieldName.'_default'};

      my $fieldIsHidden = Foswiki::Func::isTrue($params->{$fieldName.'_hidden'}, 0);
      my $fieldMandatory = $field->isMandatory?$theMandatory:'';

      if ($theAction eq 'edit') { # or get value from url (highest prio)
        my $urlValue;
        if ($field->isMultiValued) {
          my @urlValue = $query->param('META:'.$metaData.':'.$fieldName);
          $urlValue = join(", ", @urlValue) if @urlValue;
        } else {
          $urlValue = $query->param('META:'.$metaData.':'.$fieldName);
        }
        $fieldValue = $urlValue if defined $urlValue;
      }

      my $fieldAutolink = Foswiki::Func::isTrue($params->{$fieldName.'_autolink'}, $theAutolink);
      my $fieldSort = Foswiki::Func::isTrue($params->{$fieldName.'_sort'});
#      $fieldAllowedValues = sortValues($fieldAllowedValues, $fieldSort) if $fieldSort;

      next if $theIncludeAttr && $fieldAttrs !~ /^($theIncludeAttr)$/;
      next if $theExcludeAttr && $fieldAttrs =~ /^($theExcludeAttr)$/;

      $fieldValue = $fieldDefault unless defined $fieldValue;
      $fieldDescription = '' unless defined $fieldDescription;
      #writeDebug("metaData=$metaData, fieldName=$fieldName, fieldValue=$fieldValue");

      next if $theHideEmpty && $theAction eq 'view' && (!defined($fieldValue) || $field eq '');

      # temporarily remap field to another type
      my $fieldClone;
      if (defined($params->{$fieldName.'_type'}) || 
          defined($params->{$fieldName.'_size'}) ||
          $fieldSort) {
        $fieldClone = $formDef->createField(
          $fieldType,
          name          => $field->{name},
          title         => $fieldTitle,
          size          => $fieldSize,
          value         => $fieldAllowedValues,
          tooltip       => $fieldDescription,
          attributes    => $fieldAttrs,
          definingTopic => $fieldDefiningTopic,
          web           => $topicObj->web,
          topic         => $topicObj->topic,
        );
        $field = $fieldClone;
      } 

      my $line = $fieldFormat;
      $line = $theHiddenFormat if $fieldIsHidden;

      $line = '<noautolink>'.$line.'</noautolink>' unless $fieldAutolink;

      # some must be expanded before renderForDisplay/renderForEdit
      $line =~ s/\$values\b/$fieldAllowedValues/g;
      $line =~ s/\$origvalues\b/$fieldOrigAllowedValues/g;
      $line =~ s/\$title\b/$fieldTitle/g;

      my $fieldExtra = '';
      my $fieldEdit = '';

      unless ($fieldIsHidden) {
        $fieldValue = "\0" unless defined $fieldValue; # prevent dropped value attr in CGI.pm

        if ($theAction eq 'edit') {
          if ($Foswiki::Plugins::VERSION > 2.0) {
            ($fieldExtra, $fieldEdit) = 
              $field->renderForEdit($topicObj, $fieldValue);
          } else {
            # pre-TOM
            ($fieldExtra, $fieldEdit) = 
              $field->renderForEdit($topicObj->web, $topicObj->topic, $fieldValue);
          }
        } else {
          $line = $field->renderForDisplay($line, $fieldValue, {
            bar=>'|', # SMELL: keep bars
            newline=>'$n', # SMELL: keep newlines
          }); # SMELL what about the attrs param in Foswiki::Form; wtf is this attr anyway
        }

        $fieldEdit =~ s/\0//g;
        $fieldValue =~ s/\0//g;

      }

      # escape %VARIABLES inside input values
      $fieldEdit =~ s/(<input.*?value=["'])(.*?)(["'])/
        my $pre = $1;
        my $tmp = $2;
        my $post = $3;
        $tmp =~ s#%#%<nop>#g;
        $pre.$tmp.$post;
      /ge;

      $line =~ s/\$mandatory/$fieldMandatory/g;
      $line =~ s/\$edit\b/$fieldEdit/g;
      $line =~ s/\$name\b/$fieldName/g;
      $line =~ s/\$type\b/$fieldType/g;
      $line =~ s/\$size\b/$fieldSize/g;
      $line =~ s/\$attrs\b/$fieldAttrs/g;
      $line =~ s/\$default\b/$fieldDefault/g;
      $line =~ s/\$(tooltip|description)\b/$fieldDescription/g;
      $line =~ s/\$title\b/$fieldTitle/g;
      $line =~ s/\$extra\b/$fieldExtra/g;
      $line =~ s/\$origvalue\b/$fieldValue/g;

      $title = $fieldValue if $fieldName =~ /^(Topic)?Title/i;

      $row =~ s/\$$fieldName/$line/g;
      $row =~ s/\$orig$fieldName/$fieldValue/g;

      # cleanup
      $fieldClone->finish() if defined $fieldClone;
      $field->{name} = $origFieldName;
    }
    
    #writeDebug("row=$row");

    $title = $name unless $title;

    my $fieldEditAction = Foswiki::Func::expandTemplate("metadata::edit");
    my $fieldDeleteAction = Foswiki::Func::expandTemplate("metadata::delete");
    my $fieldDuplicateAction = Foswiki::Func::expandTemplate("metadata::duplicate");
    $fieldDuplicateAction = ''; # TODO: disabled

    my $fieldActions = '<span class="metaDataActions">'.$fieldEditAction.$fieldDuplicateAction.$fieldDeleteAction.'</div>';
    my $topic = $topicObj->getPath;
    $fieldActions =~ s/\%title\%/$title/g;
    $fieldActions =~ s/\%name\%/$name/g;
    $fieldActions =~ s/\%meta\%/$metaData/g;
    $fieldActions =~ s/\%topic\%/$topic/g;

    $row =~ s/\$actions\b/$fieldActions/g;
    $row =~ s/\$index\b/$index/g;

    push @result, $row;
    $index++;
  }

  return '' if $theHideEmpty && !@result;

  my $result = $theHeader.join($theSep, @result).$theFooter;

  $index--;
  $result =~ s/\$count/$index/g;
  $result =~ s/\$metadata\b/$metaData/g; # the meta data name
  $result =~ s/\$form\b/$formWeb.$formTopic/g; # the meta data name
  $result =~ s/\$nop//g;
  $result =~ s/\$n/\n/g;
  $result =~ s/\$perce?nt/%/g;
  $result =~ s/\$dollar/\$/g;

  return $result;
}

##############################################################################
sub getTopicObject {
  my ($this, $web, $topic) = @_;

  $web ||= '';
  $topic ||= '';
  
  $web =~ s/\//\./go;
  my $key = $web.'.'.$topic;
  my $topicObj = $this->{_topicObjs}{$key};
  
  unless ($topicObj) {
    ($topicObj, undef) = Foswiki::Func::readTopic($web, $topic);
    $this->{_topicObjs}{$key} = $topicObj;
  }

  return $topicObj;
}

##############################################################################
sub getKnownMetaData {
  my $this = shift;

  unless (defined $this->{_knownMetaData}) {
    $this->{_knownMetaData} = [];
    foreach my $name (sort keys %Foswiki::Meta::VALIDATE) {
      next if $name =~ /^(TOPICINFO|VERSIONS|CREATEINFO|STORAGE|TOPICMOVED|FIELD|FORM|FILEATTACHMENT|TOPICPARENT)$/;
      push @{$this->{_knownMetaData}}, $name;
    }
  };

  return @{$this->{_knownMetaData}};
}

##############################################################################
sub beforeSaveHandler {
  my ($this, $text, $topic, $web, $meta) = @_;

  writeDebug("beforeSaveHandler($web.$topic)");

  my $request = Foswiki::Func::getCgiQuery();
  my %records = ();

  my $knownMetaDataPattern = join('|', $this->getKnownMetaData);
  #writeDebug("knownMetaDataPattern=$knownMetaDataPattern");

  my $explicitName;
  foreach my $urlParam ($request->param()) {
    unless ($urlParam =~ /^META:($knownMetaDataPattern):(id\d*):(.+)$/) {
      #writeDebug("urlParam does not match: $urlParam");
      next;
    }
    #writeDebug("got urlParam=$urlParam"); 
    my $metaDataName = $1;
    my $name = $2;
    my $field = $3;

    #writeDebug("metaDataName=$metaDataName, name=$name, $field=$field"); 

    # look up cache
    my $record = $records{$metaDataName.':'.$name};

    # first hit
    unless (defined $record) {
    
      if ($name eq 'id') {
        # a new one 
        $record = { 
          name => 'id'.($this->getMaxId($metaDataName, $meta)+1),
        };
      } else {
        # go fetch from store
        $record = $meta->get($metaDataName, $name);
      }
    }

    my $value;

    my @value = $request->param($urlParam);
    if (@value) {
      $value = join(", ", @value);
      $value =~ s/,\s*$//g;
    }
    $value = '' unless defined $value;

    writeDebug("$urlParam=$value");

    # when duplicating a field, the name parameter will have a dummy 'id'
    # to flag that we need to create a new record based on the give one
    # SMELL: doesn't work
    if ($field eq 'name' && $value eq 'id') {
      $value = 'id'.($this->getMaxId($metaDataName, $meta)+1);
    }

    $record->{$field} = $value;
    $records{$metaDataName.':'.$name} = $record;
  }

  #writeDebug("records=".Data::Dumper->Dump([\%records]));

  foreach my $item (keys %records) {
    if ($item =~ /^(.*):(id\d*)$/) {
      my $metaData = $1;
      #my $name = $2;
      my $record = $records{$item};
      $meta->putKeyed($metaData, $record);
    } else {
      die "what's that record: $item"; # never reach
    }
  }
}

##############################################################################
sub getMaxId {
  my ($this, $name, $meta) = @_;

  my $maxId = 0;

  foreach my $record ($meta->find($name)) {
    my $id = $record->{name};
    $id =~ s/^id//;
    $maxId = $id if $id > $maxId;
  }

  #writeDebug("getMaxId($name) = $maxId");

  return $maxId;
}


##############################################################################
sub jsonRpcDelete {
  my ($this, $request) = @_;

  my $wikiName = Foswiki::Func::getWikiName();
  my $web = $this->{baseWeb};
  my $topic = $this->{baseTopic};

  throw Foswiki::Contrib::JsonRpcContrib::Error(404, "Topic $web.$topic does not exist") 
    unless Foswiki::Func::topicExists($web, $topic);

  throw Foswiki::Contrib::JsonRpcContrib::Error(401, "Access denied")
    unless Foswiki::Func::checkAccessPermission("CHANGE", $wikiName, undef, $web, $topic);

  my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);

  my $name = $request->param('metadata::name') || '';
  my $metaData = $request->param('metadata') || '';

  my $metaDataKey = uc($metaData);

  throw Foswiki::Contrib::JsonRpcContrib::Error(1000, "unknown meta $metaData")
    unless defined $Foswiki::Meta::VALIDATE{$metaDataKey};

  my $record = $meta->get($metaDataKey, $name);

  throw Foswiki::Contrib::JsonRpcContrib::Error(1001, "$metaData name=$name not found")
    unless $record;

  writeDebug("$this, checking deleteHandler for $metaDataKey ... ".$this->{deleteHandler}{$metaDataKey});
  if (defined $this->{deleteHandler}{$metaDataKey}) {
    foreach my $deleteHandler (@{$this->{deleteHandler}{$metaDataKey}}) {
      my $function = $deleteHandler->{function};
      my $result;
      my $error;

      writeDebug("executing $function for $metaDataKey");
      try {
        no strict 'refs';
        $result = &$function($web, $topic, $record, $deleteHandler->{options});
        use strict 'refs';
      } catch Error::Simple with {
        $error = shift;
      };

      print STDERR "error executing deleteHandler $function: ".$error."\n" if defined $error;
    }
  }

  # remove this record
  $meta->remove($metaDataKey, $name);

  Foswiki::Func::saveTopic($web, $topic, $meta, $text, {ignorepermissions=>1});

  return 'ok';
}


##############################################################################
sub inlineError {
  my $msg = shift;
  return "<span class='foswikiAlert'>$msg</span>";
}

##############################################################################
sub sortRecords {
  my ($records, $crit) = @_;

  my $isNumeric = 1;
  my $isDate = 1;
  my %sortCrits = ();
  foreach my $rec (@$records) {
    my $item = $rec->{$crit};
    next unless defined $item;

    $item =~ s/\s*$//;
    $item =~ s/^\s*//;

    if ($isNumeric && $item !~ /^(\s*[+-]?\d+(\.?\d+)?\s*)$/) {
      $isNumeric = 0;
    }

    if ($isDate && ! defined Foswiki::Time::parseTime($item)) {
      $isDate = 0;
    }

    $sortCrits{$rec->{name}} = $item;
  }

  if ($isDate) {
    # convert to epoch seconds if we sort per date
    foreach my $item (keys %sortCrits) {
      $sortCrits{$item} = Foswiki::Time::parseTime($sortCrits{$item});
    }
    $isNumeric = 1;
  }

  #print STDERR "crit=$crit, isNumeric=$isNumeric, isDate=$isDate\n";

  if ($isNumeric) {
    @{$records} = sort {($sortCrits{$a->{name}}||0) <=> ($sortCrits{$b->{name}}||0)} @$records;
  } else {
    @{$records} = sort {lc($sortCrits{$a->{name}}||'') cmp lc($sortCrits{$b->{name}}||'')} @$records;
  }
}

1;
