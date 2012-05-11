# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2009-2012 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::FlexFormPlugin::Core;

use strict;
use Foswiki::Func ();    # The plugins API
use Foswiki::Form ();
use Foswiki::Plugins ();

our $baseWeb;
our $baseTopic;
our %topicObjs;

use constant DEBUG => 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR "- FlexFormPlugin - $_[0]\n" if DEBUG;
}

##############################################################################
sub init {
  ($baseWeb, $baseTopic) = @_;
  %topicObjs = ();
}

##############################################################################
sub finish {
  undef %topicObjs;
}

##############################################################################
# create a new topic object, reuse already created ones
sub getTopicObject {
  my ($session, $web, $topic) = @_;

  $web ||= '';
  $topic ||= '';
  
  $web =~ s/\//\./go;
  my $key = $web.'.'.$topic;
  my $topicObj = $topicObjs{$key};
  
  unless ($topicObj) {
    ($topicObj, undef) = Foswiki::Func::readTopic($web, $topic);
    $topicObjs{$key} = $topicObj;
  }

  return $topicObj;
}

##############################################################################
sub handleRENDERFORDISPLAY {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleRENDERFORDISPLAY($theTopic, $theWeb)");

  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $theTopic;
  my $theFields = $params->{field} || $params->{fields};
  my $theForm = $params->{form};
  my $theFormat = $params->{format};
  my $theHeader = $params->{header};
  my $theFooter = $params->{footer};
  my $theSep = $params->{separator} || '';
  my $theValueSep = $params->{valueseparator} || ', ';
  my $theInclude = $params->{include};
  my $theExclude = $params->{exclude};
  my $theIncludeAttr = $params->{includeattr};
  my $theExcludeAttr = $params->{excludeattr};
  my $theMap = $params->{map} || '';
  my $theLabelFormat = $params->{labelformat} || '';
  my $theAutolink = Foswiki::Func::isTrue($params->{autolink}, 1);
  my $theSort = Foswiki::Func::isTrue($params->{sort}, 0);
  my $theHideEmpty = Foswiki::Func::isTrue($params->{hideempty}, 0);

  # get defaults from template
  if (!defined($theFormat) && !defined($theHeader) && !defined($theFooter)) {
    my $templates = $session->templates;
    $theHeader = '<div class=\'foswikiFormSteps\'><table class=\'foswikiLayoutTable\'>';
    $theFooter = '</table></div>';
    $theFormat = '<tr>
      <th class="foswikiTableFirstCol"> %A_TITLE%: </th>
      <td class="foswikiFormValue"> %A_VALUE% </td>
    </tr>'
  }

  $theHeader ||= '';
  $theFooter ||= '';
  $theFormat ||= '';

  # make it compatible
  $theHeader =~ s/%A_TITLE%/\$title/g;
  $theFormat =~ s/%A_TITLE%/\$title/g;
  $theFormat =~ s/%A_VALUE%/\$value/g;
  $theFooter =~ s/%A_TITLE%/\$title/g;
  $theLabelFormat =~ s/%A_TITLE%/\$title/g;
  $theLabelFormat =~ s/%A_VALUE%/\$value/g;

  my $thisWeb = $theWeb;
  ($thisWeb, $thisTopic) = Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);
  my $topicObj = getTopicObject($session, $thisWeb, $thisTopic); 

  $theForm = $session->{request}->param('formtemplate') unless defined $theForm;
  $theForm = $topicObj->getFormName unless defined $theForm;
  return '' unless $theForm;

  #writeDebug("theForm=$theForm");

  my $theFormWeb = $thisWeb;
  ($theFormWeb, $theForm) = Foswiki::Func::normalizeWebTopicName($theFormWeb, $theForm);

  if (!Foswiki::Func::topicExists($theFormWeb, $theForm)) {
    return '';
  }
  #writeDebug("theFormWeb=$theFormWeb");

  my $form = new Foswiki::Form($session, $theFormWeb, $theForm);
  return '' unless $form;

  my $formTitle;
  if ($form->can('getPath')) {
    $formTitle = $form->getPath;
  } else {
    $formTitle = $form->{web}.'.'.$form->{topic};
  }
  $formTitle =~ s/\//./g; # normalize web names

  $theHeader =~ s/\$title/$formTitle/g;
  $theFooter =~ s/\$title/$formTitle/g;

  my $fieldTitles;
  foreach my $map (split(/\s*,\s*/, $theMap)) {
    $map =~ s/\s*$//;
    $map =~ s/^\s*//;
    if ($map =~ /^(.*)=(.*)$/) {
      $fieldTitles->{$1} = $2;
    }
  }

  my @selectedFields = ();
  if ($theFields) {
    foreach my $fieldName (split(/\s*,\s*/, $theFields)) {
      $fieldName =~ s/\s*$//;
      $fieldName =~ s/^\s*//;
      my $field = $form->getField($fieldName);
      writeDebug("WARNING: no field for '$fieldName' in $theFormWeb.$theForm") unless $field;
      push @selectedFields, $field if $field;
    }
  } else {
    @selectedFields = @{$form->getFields()};
  }

  my @result = ();
  foreach my $field (@selectedFields) { 
    next unless $field;

    my $fieldName = $field->{name};
    my $fieldType = $field->{type};
    my $fieldSize = $field->{size};
    my $fieldAttrs = $field->{attributes};
    my $fieldDescription = $field->{tooltip};
    my $fieldTitle = $field->{title};
    my $fieldDefiningTopic = $field->{definingTopic};

    #writeDebug("fieldName=$fieldName, fieldType=$fieldType");

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

    my $fieldDefault = '';
    if ($field->can('getDefaultValue')) {
      $fieldDefault = $field->getDefaultValue() || '';
    } 

    my $metaField = $topicObj->get('FIELD', $fieldName);
    unless ($metaField) {
      # Not a valid field name, maybe it's a title.
      $fieldName = Foswiki::Form::fieldTitle2FieldName($fieldName);
      $metaField = $topicObj->get('FIELD', $fieldName );
    }
    my $fieldValue = $metaField?$metaField->{value}:undef;

    $fieldSize = $params->{$fieldName.'_size'} if defined $params->{$fieldName.'_size'};
    $fieldAttrs = $params->{$fieldName.'_attributes'} if defined $params->{$fieldName.'_attributes'};
    $fieldDescription = $params->{$fieldName.'_tooltip'} if defined $params->{$fieldName.'_tooltip'};
    $fieldDescription = $params->{$fieldName.'_description'} if defined $params->{$fieldName.'_description'};
    $fieldTitle = $params->{$fieldName.'_title'} if defined $params->{$fieldName.'_title'}; # see also map
    $fieldAllowedValues = $params->{$fieldName.'_values'} if defined $params->{$fieldName.'_values'};
    $fieldDefault = $params->{$fieldName.'_default'} if defined $params->{$fieldName.'_default'};
    $fieldType = $params->{$fieldName.'_type'} if defined $params->{$fieldName.'_type'};
    $fieldValue = $params->{$fieldName.'_value'} if defined $params->{$fieldName.'_value'};

    my $fieldAutolink = Foswiki::Func::isTrue($params->{$fieldName.'_autolink'}, $theAutolink);

    my $fieldSort = Foswiki::Func::isTrue($params->{$fieldName.'_sort'}, $theSort);
    $fieldAllowedValues = sortValues($fieldAllowedValues, $fieldSort) if $fieldSort;

    my $fieldFormat = $params->{$fieldName.'_format'} || $theFormat;

    # temporarily remap field to another type
    my $fieldClone;
    if (defined($params->{$fieldName.'_type'}) || 
	defined($params->{$fieldName.'_size'}) ||
        $fieldSort) {
      $fieldClone = $form->createField(
	$fieldType,
	name          => $fieldName,
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

    next if $theHideEmpty && (!defined($fieldValue) || $fieldValue eq '');
    $fieldValue = $fieldDefault unless defined $fieldValue;
    
    next if $theInclude && $fieldName !~ /^($theInclude)$/;
    next if $theExclude && $fieldName =~ /^($theExclude)$/;
    next if $theIncludeAttr && $fieldAttrs !~ /^($theIncludeAttr)$/;
    next if $theExcludeAttr && $fieldAttrs =~ /^($theExcludeAttr)$/;

    my $line = $fieldFormat;
    unless ($fieldName) { # label
      next unless $theLabelFormat;
      $line = $theLabelFormat;
    }
    $line = '<noautolink>'.$line.'</noautolink>' unless $fieldAutolink;

    $fieldTitle = $fieldTitles->{$fieldName} if $fieldTitles && $fieldTitles->{$fieldName};

    # some must be expanded before renderForDisplay
    $line =~ s/\$values\b/$fieldAllowedValues/g;
    $line =~ s/\$origvalues\b/$fieldOrigAllowedValues/g;
    $line =~ s/\$title\b/$fieldTitle/g;

    $line = $field->renderForDisplay($line, $fieldValue, {
      bar=>'|', # SMELL: keep bars
      newline=>'$n', # SMELL: keep newlines
    }); # SMELL what about the attrs param in Foswiki::Form
        # SMELL wtf is this attr anyway

    $line =~ s/\$name\b/$fieldName/g;
    $line =~ s/\$type\b/$fieldType/g;
    $line =~ s/\$size\b/$fieldSize/g;
    $line =~ s/\$attrs\b/$fieldAttrs/g;
    $line =~ s/\$(orig)?value\b/$fieldValue/g;
    $line =~ s/\$default\b/$fieldDefault/g;
    $line =~ s/\$(tooltip|description)\b/$fieldDescription/g;
    $line =~ s/\$title\b/$fieldTitle/g;
    $line =~ s/\$form\b/$formTitle/g;

    push @result, $line;

    # cleanup
    $fieldClone->finish() if defined $fieldClone;
  }

  return '' if $theHideEmpty && !@result;

  my $result = $theHeader.join($theSep, @result).$theFooter;
  $result =~ s/\$nop//g;
  $result =~ s/\$n/\n/g;
  $result =~ s/\$perce?nt/%/g;
  $result =~ s/\$dollar/\$/g;

  return $result;
}

##############################################################################
sub handleRENDERFOREDIT {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleRENDERFOREDIT($theTopic, $theWeb)");

  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $theTopic;
  my $theFields = $params->{field} || $params->{fields};
  my $theForm = $params->{form};
  my $theValue = $params->{value};
  my $theFormat = $params->{format};
  my $theHeader = $params->{header};
  my $theFooter = $params->{footer};
  my $theSep = $params->{separator} || '';
  my $theValueSep = $params->{valueseparator} || ', ';
  my $theInclude = $params->{include};
  my $theExclude = $params->{exclude};
  my $theIncludeAttr = $params->{includeattr};
  my $theExcludeAttr = $params->{excludeattr};
  my $theMap = $params->{map} || '';
  my $theMandatory = $params->{mandatory};
  my $theHidden = $params->{hidden};
  my $theHiddenFormat = $params->{hiddenformat};
  my $theSort = Foswiki::Func::isTrue($params->{sort}, 0);
  my $thePrefix = $params->{prefix};

  if (!defined($theFormat) && !defined($theHeader) && !defined($theFooter)) {
    $theHeader = '<div class=\'foswikiFormSteps\'>';
    $theFooter = '</div>';
    $theFormat = '<div class=\'foswikiFormStep\'>
      <h3> $title: </h3>
      $edit 
      <div class=\'foswikiFormDescription\'>$description</div>
    </div>';
  } else {
    $theFormat = '$edit$mandatory' unless defined $theFormat;
    $theHeader = '' unless defined $theHeader;
    $theFooter = '' unless defined $theFooter;
  }
  $theMandatory = " <span class='foswikiAlert'>**</span> " unless defined $theMandatory;
  $theHiddenFormat = '$edit' unless defined $theHiddenFormat;
  
  my $thisWeb = $theWeb;

  ($thisWeb, $thisTopic) = Foswiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);
  my $topicObj = getTopicObject($session, $thisWeb, $thisTopic); 

  # give beforeEditHandlers a chance
  # SMELL: watch out for the fix of Item1965; it must be applied here as well; for now
  # we mimic the core behaviour here
  my $text = $topicObj->text();
  $session->{plugins}->dispatch('beforeEditHandler', $text, $thisTopic, $thisWeb, $topicObj);
  $topicObj->text($text);

  $theForm = $session->{request}->param('formtemplate') unless defined $theForm;
  $theForm = $topicObj->getFormName unless defined $theForm;
  return '' unless $theForm;

  my $theFormWeb = $thisWeb;
  ($theFormWeb, $theForm) = Foswiki::Func::normalizeWebTopicName($theFormWeb, $theForm);

  #writeDebug("theForm=$theForm"); 

  if (!Foswiki::Func::topicExists($theFormWeb, $theForm)) {
    return '';
  }

  my $form = new Foswiki::Form($session, $theFormWeb, $theForm);
  return '' unless $form;
  #writeDebug("form=$form");

  my $fieldTitles;
  foreach my $map (split(/\s*,\s*/, $theMap)) {
    $map =~ s/\s*$//;
    $map =~ s/^\s*//;
    if ($map =~ /^(.*)=(.*)$/) {
      $fieldTitles->{$1} = $2;
    }
  }

  my @selectedFields = ();
  if ($theFields) {
    foreach my $fieldName (split(/\s*,\s*/, $theFields)) {
      $fieldName =~ s/\s*$//;
      $fieldName =~ s/^\s*//;
      my $field = $form->getField($fieldName);
      writeDebug("WARNING: no field for '$fieldName' in $theFormWeb.$theForm") unless $field;
      push @selectedFields, $field if $field;
    }
  } else {
    @selectedFields = @{$form->getFields()};
  }

  #writeDebug("theFields=$theFields");
  #writeDebug("selectedFields=@selectedFields");

  my @result = ();
  foreach my $field (@selectedFields) {
    next unless $field;

    my $fieldExtra = '';
    my $fieldEdit = '';

    my $fieldName = $field->{name};
    my $origFieldName = $field->{name};
    if (defined $thePrefix) {
      $field->{name} = $thePrefix.$fieldName;
    }

    my $fieldType = $field->{type};
    my $fieldSize = $field->{size};
    my $fieldAttrs = $field->{attributes};
    my $fieldDescription = $field->{tooltip};
    my $fieldTitle = $field->{title};
    my $fieldDefiningTopic = $field->{definingTopic};

    # get the list of all allowed values
    my $fieldAllowedValues = '';
    # CAUTION: don't use field->getOptions() on a +values field as that won't return the full valueMap...only the value part, but not the title map
    if ($field->can('getOptions') && $field->{type} !~ /\+values/) {
      #writeDebug("can getOptions for $fieldName");
      my $options = $field->getOptions();
      if ($options) {
        writeDebug("options=$options");
        $fieldAllowedValues = join($theValueSep, @$options);
      }
    } else {
      #writeDebug("can't getOptions ... fallback to field->{value} for $fieldName");
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
      writeDebug("can getOptions for $fieldName");
      my $options = $field->getOptions();
      if ($options) {
        #writeDebug("options=".join(";", @$options));
        $fieldOrigAllowedValues = join($theValueSep, @$options);
      }
    } else {
      writeDebug("can't getOptions ... fallback to field->{value} for $fieldName");
      # fallback to field->value
      my $options = $field->{value};
      if ($options) {
        $fieldOrigAllowedValues = join($theValueSep, split(/\s*,\s*/, $options));
      }
    }
    writeDebug("fieldOrigAllowedValues=$fieldOrigAllowedValues");

    # get the default value
    my $fieldDefault = '';
    if ($field->can('getDefaultValue')) {
      $fieldDefault = $field->getDefaultValue() || '';
    } 

    $fieldSize = $params->{$fieldName.'_size'} if defined $params->{$fieldName.'_size'};
    $fieldAttrs = $params->{$fieldName.'_attributes'} if defined $params->{$fieldName.'_attributes'};
    $fieldDescription = $params->{$fieldName.'_tooltip'} if defined $params->{$fieldName.'_tooltip'};
    $fieldDescription = $params->{$fieldName.'_description'} if defined $params->{$fieldName.'_description'};
    $fieldTitle = $params->{$fieldName.'_title'} if defined $params->{$fieldName.'_title'}; # see also map
    $fieldAllowedValues = $params->{$fieldName.'_values'} if defined $params->{$fieldName.'_values'};
    $fieldDefault = $params->{$fieldName.'_default'} if defined $params->{$fieldName.'_default'};
    $fieldType = $params->{$fieldName.'_type'} if defined $params->{$fieldName.'_type'};

    my $fieldFormat = $params->{$fieldName.'_format'} || $theFormat;

    my $fieldSort = Foswiki::Func::isTrue($params->{$fieldName.'_sort'}, $theSort);
    $fieldAllowedValues = sortValues($fieldAllowedValues, $fieldSort) if $fieldSort;

    # temporarily remap field to another type
    my $fieldClone;
    if (defined($params->{$fieldName.'_type'}) || 
	defined($params->{$fieldName.'_size'}) ||
        $fieldSort) {
      $fieldClone = $form->createField(
	$fieldType,
	name          => $fieldName,
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


    #writeDebug("reading fieldName=$fieldName");

    my $fieldValue;
    if (defined $theValue) {
      $fieldValue = $theValue;
    } else {
      $fieldValue = $params->{$fieldName.'_value'};
    }

    unless (defined $fieldValue) {
      my $query = Foswiki::Func::getCgiQuery();
      $fieldValue = $query->param($fieldName);
    }

    unless (defined $fieldValue) {
      my $metaField = $topicObj->get('FIELD', $fieldName);
      unless ($metaField) {
        # Not a valid field name, maybe it's a title.
        $fieldName = Foswiki::Form::fieldTitle2FieldName($fieldName);
        $metaField = $topicObj->get('FIELD', $fieldName );
      }
      $fieldValue = $metaField->{value} if $metaField;
    }

    $fieldValue = $fieldDefault unless defined $fieldValue;

    next if $theInclude && $fieldName !~ /^($theInclude)$/;
    next if $theExclude && $fieldName =~ /^($theExclude)$/;
    next if $theIncludeAttr && $fieldAttrs !~ /^($theIncludeAttr)$/;
    next if $theExcludeAttr && $fieldAttrs =~ /^($theExcludeAttr)$/;

    unless (defined $fieldValue) {
      $fieldValue = "\0"; # prevent dropped value attr in CGI.pm
    }

    $fieldEdit = $session->{plugins}->dispatch(
      'renderFormFieldForEditHandler', $fieldName, $fieldType, $fieldSize,
        $fieldValue, $fieldAttrs, $fieldAllowedValues
    );

    my $isHidden = ($theHidden && $fieldName =~ /^($theHidden)$/)?1:0;
    unless ($fieldEdit) {
      if ($isHidden) {
	# sneak in the value into the topicObj
        my $metaField = $topicObj->get('FIELD', $fieldName);
        if ($metaField) {
          $metaField->{value} = $fieldValue;
        } else {
          # temporarily add metaField for rendering it as hidden field
          $metaField = { 
            name => $fieldName, 
            title => $fieldName, 
            value => $fieldValue
          }; 
          $topicObj->putKeyed('FIELD', $metaField);
        }
	$fieldEdit = $field->renderHidden($topicObj);
      } else {
	if ($Foswiki::Plugins::VERSION > 2.0) {
	  ($fieldExtra, $fieldEdit) = 
	    $field->renderForEdit($topicObj, $fieldValue);
	} else {
	  # pre-TOM
	  ($fieldExtra, $fieldEdit) = 
	    $field->renderForEdit($thisWeb, $thisTopic, $fieldValue);
	}
      }
    }

    $fieldEdit =~ s/\0//g;
    $fieldValue =~ s/\0//g;

    # escape %VARIABLES inside input values
    $fieldEdit =~ s/(<input.*?value=["'])(.*?)(["'])/
      my $pre = $1;
      my $tmp = $2;
      my $post = $3;
      $tmp =~ s#%#%<nop>#g;
      $pre.$tmp.$post;
    /ge;

    my $line = $isHidden?$theHiddenFormat:$fieldFormat;
    $fieldTitle = $fieldTitles->{$fieldName} if $fieldTitles && $fieldTitles->{$fieldName};
    my $fieldMandatory = '';
    $fieldMandatory = $theMandatory if $field->isMandatory();

    $line =~ s/\$mandatory/$fieldMandatory/g;
    $line =~ s/\$edit\b/$fieldEdit/g;
    $line =~ s/\$name\b/$fieldName/g;
    $line =~ s/\$type\b/$fieldType/g;
    $line =~ s/\$size\b/$fieldSize/g;
    $line =~ s/\$attrs\b/$fieldAttrs/g;
    $line =~ s/\$values\b/$fieldAllowedValues/g;
    $line =~ s/\$origvalues\b/$fieldOrigAllowedValues/g;
    $line =~ s/\$(orig)?value\b/$fieldValue/g;
    $line =~ s/\$default\b/$fieldDefault/g;
    $line =~ s/\$tooltip\b/$fieldDescription/g;
    $line =~ s/\$description\b/$fieldDescription/g;
    $line =~ s/\$title\b/$fieldTitle/g;
    $line =~ s/\$extra\b/$fieldExtra/g;

    push @result, $line;

    # cleanup
    $fieldClone->finish() if defined $fieldClone;
    $field->{name} = $origFieldName if defined $origFieldName;
  }


  my $result = $theHeader.join($theSep, @result).$theFooter;
  $result =~ s/\$nop//g;
  $result =~ s/\$n/\n/g;
  $result =~ s/\$perce?nt/%/g;
  $result =~ s/\$dollar/\$/g;

  #print STDERR "result=$result\n";

  return '<literal><noautolink>'.$result.'</noautolink></literal>';
}

##############################################################################
sub sortValues {
  my ($values, $sort) = @_;

  my @values = split(/\s*,\s*/, $values);
  my $isNumeric = 1;
  foreach my $item (@values) {
    $item =~ s/\s*$//;
    $item =~ s/^\s*//;
    unless ($item =~ /^(\s*[+-]?\d+(\.?\d+)?\s*)$/) {
      $isNumeric = 0;
      last;
    }
  }

  if ($isNumeric) {
    @values = sort {$a <=> $b} @values;
  } else {
    @values = sort {lc($a) cmp lc($b)} @values;
  }

  @values = reverse @values if $sort =~ /(rev(erse)?)|desc(end(ing)?)?/;

  return join(', ', @values);
}

1;
