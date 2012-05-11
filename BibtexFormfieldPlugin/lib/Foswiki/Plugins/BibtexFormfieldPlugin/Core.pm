# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::BibtexFormfieldPlugin::Core

=cut

package Foswiki::Plugins::BibtexFormfieldPlugin::Core;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Assert;
use Error;
use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version
use Foswiki::Form();
use Text::BibTeX();         # library for parsing bibtex files
use Data::Dumper;           # library for debugging

# How to debug:
#    writeDebug("MESSAGE: SCRIPT CALLED!!!";
# writeDebug("This debug message goes to working/logs/debug.log");

sub TRACE     { 0 }
sub TRACESAVE { 0 }

sub beforeSaveHandler {
    my ( $text, $topic, $web, $topicObject ) = @_;
    my $formData = $topicObject->get('FORM');

    if ( defined $formData and $formData->{name} ) {
        my ( $formWeb, $formTopic ) =
          Foswiki::Func::normalizeWebTopicName( $web, $formData->{name} );
        my $formDef = Foswiki::Form->new( $Foswiki::Plugins::SESSION, $formWeb,
            $formTopic );

        if ($formDef) {
            my ( $bibtexCodeFieldName, @bibtexFieldNames ) =
              getBibtexFieldNames($formDef);

            if ($bibtexCodeFieldName) {
                my ($origTopicObject) =
                  Foswiki::Func::readTopic( $web, $topic );
                my %origData = writeBibtexFieldsToHash( $origTopicObject,
                    @bibtexFieldNames );
                my %currentData =
                  writeBibtexFieldsToHash( $topicObject, @bibtexFieldNames );
                my $origString =
                  $origTopicObject->get( 'FIELD', $bibtexCodeFieldName );
                my $currentString =
                  $topicObject->get( 'FIELD', $bibtexCodeFieldName );
                my $type = getBibtexType( $topicObject, $formDef );
                my $key = getBibtexKey($topicObject);
                my $finalString;

                writeDebug("Found bibtexCode field!") if TRACE;
                $origString = $origString->{value} if defined $origString;
                $currentString = $currentString->{value}
                  if defined $currentString;

                $origString    =~ s/[\r\n]+/\n/g;
                $currentString =~ s/[\r\n]+/\n/g;
                ### new currentString has changed? parse it
                if ( ( defined $origString ? $origString : '' ) ne
                    ( defined $currentString ? $currentString : '' ) )
                {
                    my %currentStringData = parseStringToHash($currentString);

                    writeDebug( "Different strings, was: \n'"
                          . ( $origString || '' ) . '\'/'
                          . length( $origString || '' )
                          . ", now: \n'"
                          . ( $currentString || '' ) . '\'/'
                          . ( length( $currentString || '' ) ) . "\n"
                          . Data::Dumper->Dump( [ \%currentStringData ] ) )
                      if TRACESAVE;
                    if ( scalar( keys %currentStringData ) ) {
                        $finalString = createNewStringFromData(
                            type => $type,
                            key  => $key,
                            %currentStringData
                        );
                    }
                    else {
                        $finalString = '';
                    }
                }
                else {
                    delete $origData{key};
                    delete $origData{type};
                    delete $currentData{key};
                    delete $currentData{type};
                    my $ncurrent = scalar( keys %currentData );
                    my $norig    = scalar( keys %origData );
                    if ( $ncurrent != $norig ) {
                        writeDebug(
                            "Different No. keys, was $norig, now $ncurrent: "
                              . Data::Dumper->Dump( [ \%origData ] ) . ' vs '
                              . Data::Dumper->Dump( [ \%currentData ] ) )
                          if TRACESAVE;
                        $finalString = createNewStringFromData(
                            type => $type,
                            key  => $key,
                            %currentData
                        );
                    }
                    else {
                        my @origKeys = keys %origData;

                        while ( !$finalString && scalar(@origKeys) ) {
                            my $origKey      = pop(@origKeys);
                            my $origValue    = $origData{$origKey};
                            my $currentValue = $currentData{$origKey};

                            if ( ( defined $origValue ? $origValue : '' ) ne
                                ( defined $currentValue ? $currentValue : '' ) )
                            {
                                writeDebug(
"Different key, $origKey => was:\n'$origValue', now:\n'$currentValue'\n"
                                ) if TRACESAVE;
                                $finalString = createNewStringFromData(
                                    type => $type,
                                    key  => $key,
                                    %currentData
                                );
                            }
                        }
                    }
                }

                if ( defined $finalString ) {
                    require Encode if TRACESAVE;
                    writeDebug( "FINAL, was:\n'"
                          . ( Encode::encode( 'utf8', $origString ) || 'undef' )
                          . "', now:\n'"
                          . ( Encode::encode( 'utf8', $finalString ) ) . "', "
                          . length( $origString || '' ) . '/'
                          . length($finalString)
                          . "\n" )
                      if TRACESAVE;
                    my %finalData = parseStringToHash($finalString);
                    foreach my $field (@bibtexFieldNames) {
                        if ( defined $finalData{$field} ) {
                            writeDebug(
                                "PUTTING $field = "
                                  . (
                                    defined $finalData{$field}
                                    ? $finalData{$field}
                                    : 'undef'
                                  )
                                  . "\n"
                            ) if TRACESAVE;
                        }
                        $topicObject->putKeyed(
                            'FIELD',
                            {
                                name => $field,

                     #value => Encode::encode('utf8', $finalData{$field} || ''),
                                value => $finalData{$field},
                                title => $field
                            },
                        );
                    }
                    $topicObject->putKeyed(
                        'FIELD',
                        {
                            name  => $bibtexCodeFieldName,
                            title => $bibtexCodeFieldName,

                            #value => Encode::encode('utf8', $finalString)
                            value => $finalString
                        },
                    );
                }
            }
        }
    }
    else {
        writeDebug("No bibtex fields detected in '$web.$topic'") if TRACESAVE;
    }

    return;
}

sub getBibtexType {
    my ( $topicObj, $formDef ) = @_;
    ASSERT($topicObj);
    ASSERT($formDef);
    my $type = $formDef->get( 'FIELD', 'Type' );

    $type = $type->{value} if $type;
    if ( !$type ) {
        $type = $formDef->topic();
        $type =~ s/Form$//g;
        $type = lc($type);
    }

    return $type;
}

sub getBibtexKey {
    my ( $topicObj, $formDef ) = @_;
    my $key = $topicObj->get( 'FIELD', 'key' );

    $key = $key->{value} if $key;
    if ( !$key ) {
        $key = $topicObj->topic();
    }

    return $key;
}

sub createNewStringFromData {
    my (%data) = @_;
    my $bibtexCodeString;
    my $field;
    my $fieldValue;
    my $key;
    my $currentKey;
    writeDebug("Creating bibtexCodeString from bibtex atom fields!") if TRACE;

    my $entryType = $data{'type'};
    my $entryKey  = $data{'key'};

    $bibtexCodeString = "\@$entryType\{$entryKey,\n";
    delete $data{key};
    delete $data{type};
    $bibtexCodeString .=
      join( ",\n", map { "    $_ = {$data{$_}}" } keys %data );
    $bibtexCodeString .= "\n}";

    writeDebug("Value of \$bibtexCodeString:\n $bibtexCodeString");

    return $bibtexCodeString;
}

sub parseStringToHash {
    my ($bibtexCodeString) = @_;

    my %parsedFields = ();

    #~ ASSERT( exists $topicObject and defined( $topicObject ) ) if DEBUG;
    #~ ASSERT( exists $bibtexCodeFieldName and $bibtexCodeFieldName ) if DEBUG;
    #~ ASSERT( exists $bibtexFieldNames and $bibtexFieldNames ) if DEBUG;
    #my $bibtexCodeString =
    #  getBibtexCodeString( $topicObject, $bibtexCodeFieldName );

    #~ ASSERT( exists $bibtexCodeString and $bibtexCodeString ) if DEBUG;

    if ($bibtexCodeString) {
        my $entry = Text::BibTeX::Entry->new();
        my @fieldList;
        my $fieldValue;
        my $fieldName;
        my $type;
        my $key;

        writeDebug("In detection loop, got code string: '$bibtexCodeString'")
          if TRACE;

        $entry->parse_s($bibtexCodeString);

        if ( $entry->parse_ok ) {
            writeDebug("bibtexCodeString parsed correctly.") if TRACE;
        }
        else {
            writeDebug("bibtexCodeString parsed *incorrectly*.") if TRACE;
        }
        @fieldList = $entry->fieldlist;
        foreach my $fieldName (@fieldList) {

            my $fieldValue = $entry->get($fieldName);

            # DOI fields often contain an annoying DOI: prefix on the
            # value. Perhaps there's a good reason for this (Eg. non-DOI
            # things going into DOI fields), so double-check that RHS
            # of this junk looks roughly as if it could be a DOI.
            if ( $fieldName && lc($fieldName) eq 'doi' ) {
                $fieldValue =~ s/^doi:\s*(\d+\..*)$/$1/ig if $fieldValue;
            }

            $parsedFields{$fieldName} = $fieldValue;
            writeDebug(
"The hash field '$fieldName' of '\%parsedFields' has the value: "
                  . $parsedFields{$fieldName} )
              if TRACE;
        }
        $parsedFields{'type'} = $entry->type;
        $parsedFields{'key'}  = $entry->key;
    }

    return %parsedFields;
}

sub getBibtexCodeString {
    my ( $topicObject, $bibtexCodeFieldName ) = @_;

    my $field = $topicObject->get( 'FIELD', $bibtexCodeFieldName );
    my $bibtexCodeString = $field->{value};

    return $bibtexCodeString;
}

sub writeBibtexFieldsToHash {
    my ( $topicObject, @bibtexFieldNames ) = @_;
    my $bibtexCodeString;
    my $field;
    my $fieldValue;
    my %parsedFields = ();

    foreach my $fieldName (@bibtexFieldNames) {
        $field = $topicObject->get( 'FIELD', $fieldName );
        $fieldValue = $field->{value};

        if ($fieldValue) {
            $parsedFields{$fieldName} = $fieldValue;
            writeDebug(
"In *writeBibtexFieldsToHash* : The field $fieldName in \%parsedFields has the value: "
                  . $parsedFields{$fieldName} )
              if TRACE;
        }
    }

    return %parsedFields;
}

sub createBibtexCodeString {
    my ( $topicObject, @bibtexFieldNames ) = @_;
    my $bibtexCodeString;
    my $field;
    my $fieldValue;
    writeDebug("Creating bibtexCodeString from bibtex atom fields!") if TRACE;

    $field            = $topicObject->get( 'FIELD', "key" );
    $fieldValue       = $field->{value};
    $bibtexCodeString = "\@ARTICLE{$fieldValue,\n";
    foreach my $fieldName (@bibtexFieldNames) {
        $field = $topicObject->get( 'FIELD', $fieldName );
        $fieldValue = $field->{value};
        if ( $fieldValue =~ "" ) {
            $bibtexCodeString = "$bibtexCodeString  $fieldName=$fieldValue,\n";
        }
    }
    $bibtexCodeString = "$bibtexCodeString}";

  #    writeDebug("Created bibtexCodeString from bibtex atom fields!") if TRACE;
  #    writeDebug("bibtexCodeString:\n$bibtexCodeString") if TRACE;
    return $bibtexCodeString;
}

sub getBibtexFieldNames {
    my ($formDef) = @_;
    my ( $bibtexCodeFieldName, @bibtexFieldNames );

    ASSERT( $formDef->can('getFields') ) if DEBUG;
    my $fields = $formDef->getFields();
    ASSERT( ref($fields) eq 'ARRAY' ) if DEBUG;
    ASSERT( scalar( @{$fields} ) ) if DEBUG;

    if ( $fields and ref($fields) eq 'ARRAY' and scalar( @{$fields} ) )
    {    # form definition found, if not the formfields aren't indexed
        writeDebug("Got form field definitions!") if TRACE;
        foreach my $fieldDef ( @{$fields} ) {
            writeDebug("Start 1") if TRACE;
            if ( $fieldDef->{type} and $fieldDef->{name} ) {
                writeDebug("Start 2: $fieldDef->{type} is $fieldDef->{name}")
                  if TRACE;
                if ( $fieldDef->{type} =~ /^bibtex\+code\b/ ) {
                    writeDebug(
"In bibtexCode IF-clause, got type $fieldDef->{type} in $fieldDef->{name}"
                    ) if TRACE;
                    $bibtexCodeFieldName = $fieldDef->{name};
                }
                elsif ( $fieldDef->{type} =~ /^bibtex\b/ ) {
                    writeDebug(
"In bibtex IF-clause, got type $fieldDef->{type} in $fieldDef->{name}"
                    ) if TRACE;
                    push( @bibtexFieldNames, $fieldDef->{name} );
                }
            }
        }
    }

    return ( $bibtexCodeFieldName, @bibtexFieldNames );
}

sub writeDebug {
    my ($message) = @_;

    Foswiki::Func::writeDebug( 'BibtexFormfieldsPlugin: ' . $message );

    return;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2011-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
