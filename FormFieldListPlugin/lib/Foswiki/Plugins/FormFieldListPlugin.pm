# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004 Rafael Alvarez, soronthar@flashmail.com
# Copyright (C) 2004 Bernd Raichle, bernd.raichle@gmx.de
# Copyright (C) 2008-2009 Arthur Clemens, arthur@visiblearea.com
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

package Foswiki::Plugins::FormFieldListPlugin;

use strict;
use Foswiki::Func;
use Foswiki::Plugins::TopicDataHelperPlugin;
use Foswiki::Plugins::FormFieldListPlugin::FormFieldData;

use vars qw($VERSION $RELEASE $pluginName
  $debug $defaultFormat $STORE_FILENAME
);

# This should always be $Rev$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '2.2';

our $NO_PREFS_IN_TOPIC = 1;

my $STORE_FILENAME = 'field_data.txt';

my %sortInputTable = (
    'none' => $Foswiki::Plugins::TopicDataHelperPlugin::sortDirections{'NONE'},
    'ascending' =>
      $Foswiki::Plugins::TopicDataHelperPlugin::sortDirections{'ASCENDING'},
    'descending' =>
      $Foswiki::Plugins::TopicDataHelperPlugin::sortDirections{'DESCENDING'},
);

$pluginName = 'FormFieldListPlugin';

=pod

=cut

sub initPlugin {
    my ( $inTopic, $inWeb, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    $defaultFormat = '$value';

    # Get plugin preferences
    $defaultFormat =
      Foswiki::Func::getPreferencesValue('FORMFIELDLISTPLUGIN_DEFAULT_FORMAT')
      || $defaultFormat;
    $defaultFormat =~ s/^[\\n]+//;    # Strip off leading \n

    # Get plugin debug flag
    $debug = Foswiki::Func::getPreferencesFlag('FORMFIELDLISTPLUGIN_DEBUG');

    Foswiki::Func::registerTagHandler( 'FORMFIELDLIST',
        \&_handleFormFieldList );

    # Plugin correctly initialized
    _debug(
        "Foswiki::Plugins::${pluginName}::initPlugin( $inWeb.$inTopic ) is OK");

    return 1;
}

=pod

=cut

sub _handleFormFieldList {
    my ( $inSession, $inParams, $inTopic, $inWeb ) = @_;

    my $webs   = $inParams->{'web'}   || $inWeb   || '';
    my $topics = $inParams->{'topic'} || $inTopic || '';
    my $excludeTopics = $inParams->{'excludetopic'} || '';
    my $excludeWebs   = $inParams->{'excludeweb'}   || '';

    # find all topics except for excluded topics
    my $topicData =
      Foswiki::Plugins::TopicDataHelperPlugin::createTopicData( $webs,
        $excludeWebs, $topics, $excludeTopics );

    my $excludeEmptyValues = $inParams->{'excludeemptyvalue'} || 'off';
    $inParams->{'doExcludeEmptyValues'} =
      Foswiki::Func::isTrue($excludeEmptyValues) ? 1 : 0;
    my $includeMissingFields = $inParams->{'includemissingfields'} || 'off';
    $inParams->{'doIncludeMissingFields'} =
      Foswiki::Func::isTrue($includeMissingFields) ? 1 : 0;

    my $formFields = $inParams->{'field'} || $inParams->{_DEFAULT};

    # pass on the order of the form fields; the order will define how the fields
    # will be sorted and displayed
    # only if more fields are specified
    my $formFieldsHash =
      Foswiki::Plugins::TopicDataHelperPlugin::makeHashFromString( $formFields,
        1 );
    my $properties = {};
    $properties->{includeMissingFields} = $inParams->{'doIncludeMissingFields'},
      $properties->{formFields}         = $formFieldsHash;
    $properties->{sortParam} = $inParams->{'sort'};

    Foswiki::Plugins::TopicDataHelperPlugin::insertObjectData( $topicData,
        \&_createFormFieldData, $properties );

    _filterTopicData( $topicData, $inParams );

    my $fields =
      Foswiki::Plugins::TopicDataHelperPlugin::getListOfObjectData($topicData);

    # always sort
    $fields = _sortFields( $fields, $inParams );

    # limit files if param limit is defined
    if ( defined $inParams->{'limit'} ) {
        splice @$fields, $inParams->{'limit'}
          if ( scalar @$fields > $inParams->{'limit'} );
    }

    # format
    my $formatted = _formatFormFieldData( $fields, $inParams );

    return $formatted;
}

sub _populateOrderingFromFormDefinition {
    my ( $web, $topic, $existing ) = @_;

    my $topicObject =
      Foswiki::Meta->load( $Foswiki::Plugins::SESSION, $web, $topic );
    my $startPosition = 1;
    my %orderedFields = %$existing;

    while ( my ( $field, $order ) = each %$existing ) {
        if ( $order >= $startPosition ) {
            $startPosition = $order + 1;
        }
    }
    my @fields = $topicObject->find('FIELD');
    my $index  = $startPosition;
    foreach my $fieldref (@fields) {
        my %field = %$fieldref;
        $orderedFields{ $field{name} } = $index;
        $index = $index + 1;
    }

    return \%orderedFields;
}

=pod

Called from Foswiki::Plugins::TopicDataHelperPlugin::insertObjectData.
Called with every topic.
Creates a data object for each topic:

topic => {
	'name_of_field_1' => FormFieldData object,
	'name_of_field_2' => FormFieldData object,
	...,
}

=cut

sub _createFormFieldData {
    my ( $inTopicHash, $inWeb, $inTopic, $inProperties ) = @_;

    _debug("FormFieldListPlugin::_createFormFieldData");

    my $formFieldsHash       = $inProperties->{formFields};
    my $includeMissingFields = $inProperties->{includeMissingFields};

    if ( defined $inProperties->{sortParam}
        and ( $inProperties->{sortParam} eq '$fieldDefinition' ) )
    {
        $formFieldsHash = _populateOrderingFromFormDefinition( $inWeb, $inTopic,
            $formFieldsHash );
    }

    # define value for topic key only if topic
    # has META:FIELD data
    my ( $fields, $meta ) = _getFormFieldsInTopic( $inWeb, $inTopic );
    if ( scalar @$fields ) {
        _debug("\t topic '$inTopic' has fields");
        $inTopicHash->{$inTopic} = ();

        foreach my $field (@$fields) {
            my $fd =
              _createFormFieldDataObject( $inWeb, $inTopic, $field,
                $field->{name}, $formFieldsHash );
            $inTopicHash->{$inTopic}{ $field->{name} } = $fd;
        }
    }
    else {

        # no META:FIELD, so remove from hash
        _debug("\t topic '$inTopic' has no META:FIELD, so remove from hash");
        delete $inTopicHash->{$inTopic};
    }

    if ($includeMissingFields) {
        _debug(
            "\t list empty values, even if they are not in the listed FIELDs");

        # list empty values, even if they are not in the listed FIELDs
        # if so, create fields and mark as 'notfound'
        while ( ( my $expectedFieldName, my $expectedOrder ) =
            each %$formFieldsHash )
        {
            my $currentFd = $inTopicHash->{$inTopic}{$expectedFieldName};
            if ( !defined $currentFd ) {
                my $fd = _createFormFieldDataObject( $inWeb, $inTopic, undef,
                    $expectedFieldName, $inProperties );
                $$fd->{notfound}                             = 1;
                $inTopicHash->{$inTopic}                     = ();
                $inTopicHash->{$inTopic}{$expectedFieldName} = $fd;
            }
        }
    }
}

=pod

Returns a reference to a new FormFieldData object.

=cut

sub _createFormFieldDataObject {
    my ( $inWeb, $inTopic, $inField, $inName, $inFormFieldsHash ) = @_;

    my $fd = Foswiki::Plugins::FormFieldListPlugin::FormFieldData->new( $inWeb,
        $inTopic, $inField, $inName );

    my $order = $$inFormFieldsHash{$inName} || 0;
    $fd->{order} = $order;

    my ( $revDate, $author, $rev, $comment ) =
      Foswiki::Func::getRevisionInfo( $inWeb, $inTopic );
    my $wikiUserName = Foswiki::Func::userToWikiName( $author, 1 );

    $fd->{user} = $wikiUserName;
    $fd->setTopicDate($revDate);

    return \$fd;
}

=pod

Filters topic data references in the $inTopicData hash.
Called function remove topic data references in the hash.

=cut

sub _filterTopicData {
    my ( $inTopicData, $inParams ) = @_;

    use Data::Dumper;
    _debug( "FormFieldListPlugin::_filterTopicData - inParams="
          . Dumper($inParams) );

    # ----------------------------------------------------
    # filter included/excluded field names
    my $fields = $inParams->{'field'} || $inParams->{_DEFAULT} || undef;

    if ( defined $fields || defined $inParams->{'excludefield'} ) {
        _debug("\t filter on 'field' or 'excludefield'");
        Foswiki::Plugins::TopicDataHelperPlugin::filterTopicDataByProperty(
            $inTopicData, 'name', 1, $fields, $inParams->{'excludefield'} );
    }
    if (   defined $inParams->{'includefieldpattern'}
        || defined $inParams->{'excludefieldpattern'} )
    {
        _debug("\t filter on 'includefieldpattern' or 'excludefieldpattern'");
        Foswiki::Plugins::TopicDataHelperPlugin::filterTopicDataByRegexMatch(
            $inTopicData, 'name',
            $inParams->{'includefieldpattern'},
            $inParams->{'excludefieldpattern'}
        );
    }

    # exclude fields with no value
    if ( $inParams->{'doExcludeEmptyValues'} ) {
        _debug("\t filter on 'value'");
        Foswiki::Plugins::TopicDataHelperPlugin::filterTopicDataByProperty(
            $inTopicData,
            'value',
            1,
            undef,
            $Foswiki::Plugins::FormFieldListPlugin::FormFieldData::EMPTY_VALUE_PLACEHOLDER
        );
    }

    # ----------------------------------------------------
    # filter included/excluded field VALUES
    if (   defined $inParams->{'includevalue'}
        || defined $inParams->{'excludevalue'} )
    {
        _debug("\t filter on 'includevalue' or 'excludevalue'");
        Foswiki::Plugins::TopicDataHelperPlugin::filterTopicDataByProperty(
            $inTopicData, 'value', 1,
            $inParams->{'includevalue'},
            $inParams->{'excludevalue'}
        );
    }
    if (   defined $inParams->{'includevaluepattern'}
        || defined $inParams->{'excludevaluepattern'} )
    {
        _debug("\t filter on 'includevaluepattern' or 'excludevaluepattern'");
        Foswiki::Plugins::TopicDataHelperPlugin::filterTopicDataByRegexMatch(
            $inTopicData, 'value',
            $inParams->{'includevaluepattern'},
            $inParams->{'excludevaluepattern'}
        );
    }

    # ----------------------------------------------------
    # filter fields by user
    if ( defined $inParams->{'user'} || defined $inParams->{'excludeuser'} ) {
        _debug("\t filter on 'user' or 'excludeuser'");
        Foswiki::Plugins::TopicDataHelperPlugin::filterTopicDataByProperty(
            $inTopicData, 'user', 1, $inParams->{'user'},
            $inParams->{'excludeuser'} );
    }

    # ----------------------------------------------------
    # filter fields by date range
    if ( defined $inParams->{'fromdate'} || defined $inParams->{'todate'} ) {
        _debug("\t filter on 'fromdate' or 'todate'");
        Foswiki::Plugins::TopicDataHelperPlugin::filterTopicDataByDateRange(
            $inTopicData, $inParams->{'fromdate'},
            $inParams->{'todate'} );
    }

    use Data::Dumper;
    _debug( "\t inTopicData==" . Dumper($inTopicData) );
}

=pod

Only when sort="$fieldDate". Compares field values with cache. If a value has not been updated, uses the date of the cached version.

=cut

sub _updateFieldDatesWithCache {
    my ($inFields) = @_;

    _debug("FormFieldListPlugin::_updateFieldDatesWithCache");

    my @cacheList = split( "\n", _readWorkFile($STORE_FILENAME) );
    my $cacheNeedsUpdate = 0;
    if ( !scalar @cacheList ) {

        # no cache file exists yet
        _debug("\t no cache file exists yet");
        $cacheNeedsUpdate = 1;

        foreach my $field ( @{$inFields} ) {
            my $newFieldLine = $field->stringify();
            push @cacheList, $newFieldLine;
        }
    }
    else {

        # cache file exists
        # create quick lookup hash for cache
        my %lookup = ();
        my $index  = 0;
        foreach my $line (@cacheList) {
            my @parts      = split( "\t", $line );
            my $web        = $parts[1];
            my $topic      = $parts[2];
            my $fieldName  = $parts[3];
            my $fieldValue = $parts[4];
            my $topicDate  = $parts[5];
            $lookup{$web}{$topic}{$fieldName}{'value'} = $fieldValue;
            $lookup{$web}{$topic}{$fieldName}{'date'}  = $topicDate;

            # store array index for easy updating the cache
            $lookup{$web}{$topic}{$fieldName}{'index'} = $index;
            $index++;
        }

        # now compare fields with cache
        foreach my $field ( @{$inFields} ) {
            my $web       = $field->{web};
            my $topic     = $field->{topic};
            my $fieldName = $field->{name};

            my $cachedValue = $lookup{$web}{$topic}{$fieldName}{'value'};

            if ( !defined $cachedValue ) {

                # add entry to cache
                _debug(
"\t add entry to cache for topic:$topic, field name:$fieldName"
                );
                $cacheNeedsUpdate = 1;
                my $newFieldLine = $field->stringify();
                push @cacheList, $newFieldLine;
            }
            else {

                # compare values
                if ( $cachedValue ne $field->{'value'} ) {

                    # value has changed, update cache
                    _debug(
"\t value has changed, update cache for topic:$topic, field name:$fieldName, value:$cachedValue; new value:$field->{'value'}"
                    );
                    $field->setFieldDate( $field->{date} );
                    $cacheNeedsUpdate = 1;
                    my $updatedFieldLine = $field->stringify();
                    my $index = $lookup{$web}{$topic}{$fieldName}{'index'};
                    $cacheList[$index] = $updatedFieldLine;
                }
                else {

                    # value unchanged, use cached date
                    _debug(
"\t value unchanged, use cached date for topic:$topic, field name:$fieldName, value:$cachedValue"
                    );
                    my $date = $lookup{$web}{$topic}{$fieldName}{'date'};
                    $field->{fieldDate} = $date;
                }
            }
        }
    }

    if ($cacheNeedsUpdate) {

        # save cache
        my $cacheText = join "\n", sort @cacheList;
        _debug("\t save cache:\n$cacheText");
        _saveWorkFile( $STORE_FILENAME, $cacheText );
    }
}

=pod

=cut

sub _readWorkFile {
    my ($inFileName) = @_;

    my $workarea = Foswiki::Func::getWorkArea($pluginName);
    return Foswiki::Func::readFile( $workarea . '/' . $inFileName );
}

=pod

=cut

sub _saveWorkFile {
    my ( $inFileName, $inText ) = @_;

    my $workarea = Foswiki::Func::getWorkArea($pluginName);
    my $path     = $workarea . '/' . $inFileName;

    Foswiki::Func::saveFile( $path, $inText );
}

=pod

=cut

sub _sortFields {
    my ( $inFields, $inParams ) = @_;

    my $sortMode = $inParams->{'sort'} || '$topicName';

    _updateFieldDatesWithCache($inFields)
      if ( $sortMode eq '$fieldDate' );

    # get the sort key for the $inSortMode
    my $sortKey =
      &Foswiki::Plugins::FormFieldListPlugin::FormFieldData::getSortKey(
        $sortMode);
    my $compareMode =
      &Foswiki::Plugins::FormFieldListPlugin::FormFieldData::getCompareMode(
        $sortMode);

    # translate input to sort parameters
    my $sortOrderParam = $inParams->{'sortorder'} || 'none';
    my $sortOrder = $sortInputTable{$sortOrderParam}
      || $Foswiki::Plugins::TopicDataHelperPlugin::sortDirections{'NONE'};

    # set default sort order for sort modes
    if ( $sortOrder ==
        $Foswiki::Plugins::TopicDataHelperPlugin::sortDirections{'NONE'} )
    {
        if ( defined $sortKey
            && ( $sortKey eq 'date' || $sortKey eq 'fieldDate' ) )
        {

            # exception for dates: newest on top
            $sortOrder =
              $Foswiki::Plugins::TopicDataHelperPlugin::sortDirections{
                'DESCENDING'};
        }
        else {

            # otherwise sort by default ascending
            $sortOrder =
              $Foswiki::Plugins::TopicDataHelperPlugin::sortDirections{
                'ASCENDING'};
        }
    }

    $sortOrder = -$sortOrder
      if ( $sortOrderParam eq 'reverse' );

    # SMELL: order is numeric, while currently the secondary sort key can only
    # be alphabetical. This is bound to break something.
    # Will be fixed when proper sorting is available in TopicDataHelperPlugin.
    my $secondarySortKey = 'order';

    $inFields =
      Foswiki::Plugins::TopicDataHelperPlugin::sortObjectData( $inFields,
        $sortOrder, $sortKey, $compareMode, $secondarySortKey )
      if defined $sortKey;

    return $inFields;
}

=pod

=cut

sub _formatFormFieldData {
    my ( $inFields, $inParams ) = @_;

    # formatting parameters
    my $format = $inParams->{'format'} || $defaultFormat;
    my $header = $inParams->{'header'} || '';
    my $footer = $inParams->{'footer'} || '';
    my $default = $inParams->{'default'} || ''; # when no value is found
    my $alttext = $inParams->{'alttext'} || ''; # when no field is found in form
    my $alt     = $inParams->{'alt'}     || ''; # when no fields are found
    my $separator   = $inParams->{'separator'}   || "\n";
    my $topicHeader = $inParams->{'topicheader'} || undef;

    my @formattedData = ();
    my $topic         = '';    # keep track of topic if $topicHeader is defined

    my $count = 0;

    foreach my $field ( @{$inFields} ) {

        my $s     = "$format";
        my $value = $field->{value};
        $value =~
s/$Foswiki::Plugins::FormFieldListPlugin::FormFieldData::EMPTY_VALUE_PLACEHOLDER/$default/g;

        if ( $field->{'notfound'} ) {
            if ($alttext) {
                $value = '$alttext';
            }
        }
        $s =~ s/\$value/$value/g;
        $s =~ s/\$alttext/$alttext/g;

        # substitution variables
        _substituteFormattingVariables( $field, $s );

        # topicHeader
        # add topic header if we are moving to a different topic
        if ( defined $topicHeader && $topic ne $field->{topic} ) {
            my $sep = $topicHeader;
            _substituteFormattingVariables( $field, $sep );
            push @formattedData, $sep;
            $topic = $field->{topic};
        }
        $topic = $field->{topic};

        push @formattedData, $s;
        $count++;
    }

    my $outText = join $separator, @formattedData;

    if ( $outText eq '' ) {
        $outText = $alt;
    }
    else {
        $header =~ s/(.+)/$1\n/;              # add newline if text
        $footer =~ s/(.+)/\n$1/;              # add newline if text
                                              # fileCount format param
        $header =~ s/\$fieldCount/$count/g;
        $footer =~ s/\$fieldCount/$count/g;

        $outText = "$header$outText$footer";
    }
    $outText = Foswiki::Func::decodeFormatTokens($outText);
    $outText =~ s/\$br/\<br \/\>/g;
    return $outText;
}

=pod

=cut

sub _substituteFormattingVariables {

    # $field = $_[0]
    # $text = $_[1]
    $_[1] =~ s/\$title/$_[0]->{title}/g;
    $_[1] =~ s/\$name/$_[0]->{name}/g;
    $_[1] =~ s/\$topicName/$_[0]->{topic}/g;
    $_[1] =~ s/\$webName/$_[0]->{web}/g;
    $_[1] =~ s/\$topicUser/$_[0]->{user}/g;
    $_[1] =~ s/\$topicDate/_formatDate($_[0]->{date})/ge;
    $_[1] =~ s/\$fieldDate/_formatDate($_[0]->{fieldDate})/ge;
}

=pod

Returns an array of tuples (FILEATTACHMENT object, $meta).

=cut

sub _getFormFieldsInTopic {
    my ( $inWeb, $inTopic ) = @_;

    my ( $meta, $text ) = Foswiki::Func::readTopic( $inWeb, $inTopic );
    my @formFieldData = $meta->find('FIELD');

    use Data::Dumper;
    _debug(
        "FormFieldListPlugin::_getFormFieldsInTopic - $inWeb.$inTopic; fields="
          . Dumper(@formFieldData) );

    return ( \@formFieldData, $meta );
}

=pod

Formats $epoch seconds to the date-time format specified in configure.

=cut

sub _formatDate {
    my ($epoch) = @_;

    return Foswiki::Func::formatTime(
        $epoch,
        $Foswiki::cfg{DefaultDateFormat},
        $Foswiki::cfg{DisplayTimeValues}
    );
}

sub _debug {
    my ($inText) = @_;

    Foswiki::Func::writeDebug($inText)
      if $Foswiki::Plugins::FormFieldListPlugin::debug;
}
1;
