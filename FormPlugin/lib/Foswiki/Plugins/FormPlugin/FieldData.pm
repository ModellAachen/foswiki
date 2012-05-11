# See bottom of file for license and copyright information

package Foswiki::Plugins::FormPlugin::FieldData;

use strict;
use warnings;

use Foswiki::Plugins::FormPlugin::Constants;

=pod

=cut

sub new {
    my ( $class, $params, $formData, $error ) = @_;
    my $this = {};

    my ( $options, $initErrors ) = _parseOptions( $params, $formData );
    $this->{options}        = $options;
    $this->{initErrors}     = $initErrors;
    $this->{error}          = $error;        # we show one error at a time
    $this->{submittedValue} = undef
      ;   # entered value that is send with a request, then read and stored here
    $this->{substitutedValue} = undef;    # substituted submittedValue
    bless $this, $class;
}

=pod

=cut

sub _parseOptions {
    my ( $params, $formData ) = @_;

    my $options = {};

    ##### type

    $options->{type} = $params->{type};

    if ( $options->{type} =~ m/^(.*?)multi$/ ) {
        $options->{type}     = $1;
        $options->{hasMulti} = 1;
    }

    $options->{initError} |=
      $Foswiki::Plugins::FormPlugin::Constants::MISSING_PARAMS
      ->{MISSING_FORMELEMENT_PARAM_TYPE}
      if !$options->{type};

    ##### name

    $options->{name} = $params->{name};

    # backward compatibility
    # if type is submit, and name is missing, use action as name
    if ( !$options->{name} && lc( $options->{type} ) eq 'submit' ) {
        $options->{name} = 'action';
    }

    $options->{initError} |=
      $Foswiki::Plugins::FormPlugin::Constants::MISSING_PARAMS
      ->{MISSING_FORMELEMENT_PARAM_NAME}
      if !$options->{name};

    ##### id

    $options->{id} = $params->{id} if defined $params->{id};

    ##### format

    $options->{format} = $params->{format}
      || $formData->{options}->{elementformat}    # for older versions
      || $formData->{options}->{fieldformat}      # for older versions
      || $Foswiki::Plugins::FormPlugin::Constants::DEFAULT_ELEMENT_FORMAT;

    $options->{format} =
      $Foswiki::Plugins::FormPlugin::Constants::DEFAULT_HIDDEN_FIELD_FORMAT
      if $options->{type} && $options->{type} eq 'hidden';

    $options->{value} = $params->{value} if defined $params->{value};
    $options->{value} = $params->{default}
      if !defined $params->{value} && defined $params->{default};
    $options->{value} = $params->{buttonlabel}
      if !defined $params->{value} && defined $params->{buttonlabel};

    $options->{titleFormat} = $params->{titleformat}
      || $Foswiki::Plugins::FormPlugin::Constants::DEFAULT_TITLE_FORMAT;

    $options->{dateFormat} = $params->{dateformat};

    ##### multi select

    (
        $options->{optionList},
        $options->{labelList}, $options->{selectedOptionList}
      )
      = _parseOptionsAndLabels( $params->{options}, $params->{labels},
        $options->{value} );

    ##### javascript options
    $options->{javascript}                = {};
    $options->{javascript}->{onFocus}     = $params->{onFocus};
    $options->{javascript}->{onBlur}      = $params->{onBlur};
    $options->{javascript}->{onClick}     = $params->{onClick};
    $options->{javascript}->{onChange}    = $params->{onChange};
    $options->{javascript}->{onSelect}    = $params->{onSelect};
    $options->{javascript}->{onMouseOver} = $params->{onMouseOver};
    $options->{javascript}->{onMouseOut}  = $params->{onMouseOut};
    $options->{javascript}->{onKeyUp}     = $params->{onKeyUp};
    $options->{javascript}->{onKeyDown}   = $params->{onKeyDown};
    Foswiki::Plugins::FormPlugin::Util::deleteEmptyHashFields(
        $options->{javascript} );
    delete $options->{javascript} if ( !keys %{ $options->{javascript} } );

    ##### size

    $options->{size} = $params->{size}
      || ( $options->{type} && $options->{type} eq 'date' ? '15' : '40' );
    $options->{size} = 1 if $options->{type} eq 'dropdown';

    ##### other options

    $options->{rows}       = $params->{rows};
    $options->{cols}       = $params->{cols};
    $options->{dateformat} = $params->{dateformat};
    $options->{mandatory}  = Foswiki::Func::isTrue( $params->{mandatory}, 0 )
      if defined $params->{mandatory};
    $options->{hint}      = $params->{hint};
    $options->{title}     = $params->{title};
    $options->{condition} = $params->{condition};
    $options->{validate}  = $params->{validate};
    $options->{maxlength} = $params->{maxlength};
    if ( $options->{type} !~ m/\b(textonly|hidden)\b/ ) {
        $options->{tabindex} = $Foswiki::Plugins::FormPlugin::tabIndex++;
    }

    $options->{class} = $params->{cssclass};
    $options->{placeholder} = $params->{placeholder} || $params->{beforeclick};
    $options->{spellcheck} =
      Foswiki::Func::isTrue( $params->{spellcheck}, 0 ) ? 'true' : 'false'
      if $params->{spellcheck};

    if ( Foswiki::Func::isTrue( $params->{focus} ) ) {
        $options->{focus} = 1;
        $options->{class} .=
          ' ' . $Foswiki::Plugins::FormPlugin::Constants::FOCUS_CSS_CLASS;
    }

    # disabled
    if ( $formData->{options}->{disabled} ) {
        if ( $options->{optionList} ) {
            $options->{disabled} = $options->{optionList};
        }
        else {
            $options->{disabled} = 'disabled';
        }
    }
    if ( defined $params->{disabled} ) {
        if ( $params->{disabled} eq 'on' ) {
            if ( $options->{optionList} ) {

                # disable all
                $options->{disabled} = $options->{optionList};
            }
            else {
                $options->{disabled} = 'disabled';
            }
        }
        elsif ( Foswiki::Func::isTrue( $params->{disabled} || 'off' ) ) {
            my @items = split( /\s*,\s*/, $params->{disabled} );
            $options->{disabled} = \@items;
        }
        else {
            delete $options->{disabled};
        }
    }

    # readonly
    if ( defined $params->{readonly} ) {
        if ( $params->{readonly} eq 'on' ) {
            $options->{readonly} = '1';
        }
    }

    # field options set with form parameters
    $options->{fieldCssClass} = $formData->{options}->{elementcssclass};
    $options->{sep}           = $formData->{options}->{sep};

    # clean up
    Foswiki::Plugins::FormPlugin::Util::deleteEmptyHashFields($options);
    my $initErrors = _handleErrors($options);

    return ( $options, $initErrors );
}

=pod

=cut

sub _handleErrors {
    my ($options) = @_;

    my $initErrors;
    if ( $options->{initError} ) {

        # shorthand
        my $missingName =
          $Foswiki::Plugins::FormPlugin::Constants::MISSING_PARAMS
          ->{MISSING_FORMELEMENT_PARAM_NAME};
        my $missingType =
          $Foswiki::Plugins::FormPlugin::Constants::MISSING_PARAMS
          ->{MISSING_FORMELEMENT_PARAM_TYPE};
        my $message = '';

        if (   ( $options->{initError} & $missingName )
            && ( $options->{initError} & $missingType ) )
        {
            $message = Foswiki::Func::expandTemplate(
                'formplugin:message:author:missing_element_name_and_type');
            $message =~ s/\$type/$options->{type}/go;
            $message =~ s/\$name/$options->{name}/go;
            push( @{$initErrors}, $message );
        }
        elsif ( $options->{initError} & $missingName ) {
            $message = Foswiki::Func::expandTemplate(
                'formplugin:message:author:missing_element_name');
            $message =~ s/\$type/$options->{type}/go;
            $message =~ s/\$name/$options->{name}/go;
            push( @{$initErrors}, $message );
        }
        elsif ( $options->{initError} & $missingType ) {
            $message = Foswiki::Func::expandTemplate(
                'formplugin:message:author:missing_element_type');
            $message =~ s/\$type/$options->{type}/go;
            $message =~ s/\$name/$options->{name}/go;
            push( @{$initErrors}, $message );
        }
    }
    return $initErrors;
}

=pod

_parseOptionsAndLabels( $optionsString, $labelsString, $valuesString ) -> ( \@optionList, \@labelList, \@selectedOptionList )

Parses strings of options and labels.
		
=cut

sub _parseOptionsAndLabels {
    my ( $options, $labels, $values ) = @_;

    return ( undef, undef, undef ) if !defined $options;

    my @optionList;
    my @labelList;
    my @selectedOptionList;

    Foswiki::Plugins::FormPlugin::Util::trimSpaces($options);
    Foswiki::Plugins::FormPlugin::Util::trimSpaces($labels);
    Foswiki::Plugins::FormPlugin::Util::trimSpaces($values);

    my @optionPairs = split( /\s*,\s*/, $options ) if defined $options;

    foreach my $item (@optionPairs) {
        my ( $option, $label ) = '';
        if ( $item =~ m/^(.*?[^\\])=(.*)$/ ) {
            ( $option, $label ) = ( $1, $2 );
        }
        else {
            $option = $item;
        }
        if ( !defined $label ) {
            $label = $option;
        }
        push( @optionList, $option );
        push( @labelList,  $label );
    }

    if ( defined $labels ) {

        # redefine label list, if any
        @labelList = split( /\s*,\s*/, $labels );
    }

    @selectedOptionList = split( /\s*,\s*/, $values ) if defined $values;

    return ( \@optionList, \@labelList, \@selectedOptionList );
}

1;

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (c) 2007-2011 Arthur Clemens, Sven Dowideit, Eugen Mayer
# All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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
#
# For licensing info read LICENSE file in the installation root.
