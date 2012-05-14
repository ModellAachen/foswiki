# See bottom of file for license and copyright information

package Foswiki::Plugins::FormPlugin::Validate::BackendValidator;

use strict;
use warnings;

use Foswiki::Func;
use Foswiki::Plugins::FormPlugin::Constants;
use Foswiki::Plugins::FormPlugin::Validate::Error;

my %FP_RE;

=pod

validate( $request, \@formFields, \@validationRules ) -> \@errors

- fields in request object must be defined in $fields
- field values in request object must obey the rules in $validationRules

Returns list of Foswiki::Plugins::FormPlugin::Validate::Error objects.

=cut

sub validate {
    my ( $fields, $validationRules, $earlierErrors ) = @_;

    my $request = Foswiki::Func::getCgiQuery()
      ; # instead of  Foswiki::Func::getRequestObject() to be compatible with older versions

    my @errors = defined $earlierErrors ? @{$earlierErrors} : ();

    # check with validation rules
    foreach my $field ( @{$fields} ) {
        if ( defined $field->{options}->{validate} ) {

            # validate this field
            my $name = $field->{options}->{name};

            my $validationRule   = $validationRules->{$name};
            my $validationParams = $validationRule->{params};

            my $value = $request->param($name);

            my $seenErrors = {};
            foreach my $methodName ( keys %{$validationParams} ) {

                my $conditionalValue = $validationParams->{$methodName};
                my ( $validates, $message ) =
                  test( $methodName, $value, $conditionalValue );

                if ( !$validates ) {

                    # only save the first error message
                    my $error =
                      Foswiki::Plugins::FormPlugin::Validate::Error->new(
                        $field, $name, $message );
                    push @errors, $error if !$seenErrors->{$name};
                    $seenErrors->{$name} = 1;

                    # also set error to the field
                    $field->{error} = $error;
                }
                else {
                    $field->{error} = undef;
                }
            }
        }
    }
    return \@errors;
}

=pod

=cut

sub test {
    my ( $methodName, $value, $conditionalValue ) = @_;

    my $validationMethod = _validationMethod($methodName);

    my $validationMethodRef = \&$validationMethod;

    my ( $validates, $message ) =
      $validationMethodRef->( $methodName, $value, $conditionalValue );

    return ( $validates, $message );
}

=pod

=cut

sub _validationMethod {
    my ($name) = @_;

    my $method = 'validate_' . lc($name);
    return $method;
}

=pod

=cut

sub validate_required {
    my ( $name, $value ) = @_;

    my $isValid = defined $value && $value ne '';
    my $message =
      $isValid
      ? ''
      : Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction::parseMessage(
        $name);
    return ( $isValid, $message );
}

=pod

=cut

sub validate_number {
    my ( $name, $value ) = @_;

    #use Regexp::Common qw /number/;
    $FP_RE{num}{real} ||=
qr'(?:(?i)(?:[+-]?)(?:(?=[0123456789]|[.])(?:[0123456789]*)(?:(?:[.])(?:[0123456789]{0,}))?)(?:(?:[E])(?:(?:[+-]?)(?:[0123456789]+))|))';

    my $isValid = $value =~ m/^$FP_RE{num}{real}$/;
    my $message =
      $isValid
      ? ''
      : Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction::parseMessage(
        $name);
    return ( $isValid, $message );
}

=pod

=cut

sub validate_integer {
    my ( $name, $value ) = @_;

    #use Regexp::Common qw /number/;
    $FP_RE{num}{int} ||= qr'(?:(?:[+-]?)(?:[0123456789]+))';

    my $isValid = $value =~ m/^$FP_RE{num}{int}$/;
    my $message =
      $isValid
      ? ''
      : Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction::parseMessage(
        $name);
    return ( $isValid, $message );
}

=pod

=cut

sub validate_float {
    my ( $name, $value ) = @_;

    #use Regexp::Common qw /number/;
    $FP_RE{num}{real} ||=
qr'(?:(?i)(?:[+-]?)(?:(?=[0123456789]|[.])(?:[0123456789]*)(?:(?:[.])(?:[0123456789]{0,}))?)(?:(?:[E])(?:(?:[+-]?)(?:[0123456789]+))|))';

    my $isValid = ( $value =~ m/^$FP_RE{num}{real}$/ )
      && !( $value =~ m/^$FP_RE{num}{int}$/ );

    my $message =
      $isValid
      ? ''
      : Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction::parseMessage(
        $name);
    return ( $isValid, $message );
}

=pod

=cut

sub validate_min {
    my ( $name, $value, $conditionalValue ) = @_;

    my $min     = $conditionalValue;
    my $isValid = $value >= $min;
    my $message =
      $isValid
      ? ''
      : Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction::parseMessage(
        $name, $min );
    return ( $isValid, $message );
}

=pod

=cut

sub validate_max {
    my ( $name, $value, $conditionalValue ) = @_;

    my $max     = $conditionalValue;
    my $isValid = $value <= $max;
    my $message =
      $isValid
      ? ''
      : Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction::parseMessage(
        $name, $max );
    return ( $isValid, $message );
}

=pod

=cut

sub validate_range {
    my ( $name, $value, $conditionalValue ) = @_;

    my ( $min, $max ) = _range($conditionalValue);
    my $isValid = $value >= $min && $value <= $max;

    my $message =
      $isValid
      ? ''
      : Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction::parseMessage(
        $name, $min, $max );
    return ( $isValid, $message );
}

=pod

=cut

sub validate_minlength {
    my ( $name, $value, $conditionalValue ) = @_;

    my $length    = length $value;
    my $minLength = int $conditionalValue;

    my $isValid = $length >= $minLength;
    my $message =
      $isValid
      ? ''
      : Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction::parseMessage(
        $name);
    return ( $isValid, $message );
}

=pod

=cut

sub validate_maxlength {
    my ( $name, $value, $conditionalValue ) = @_;

    my $length    = length $value;
    my $maxLength = int $conditionalValue;

    my $isValid = $length <= $maxLength;
    my $message =
      $isValid
      ? ''
      : Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction::parseMessage(
        $name);
    return ( $isValid, $message );
}

=pod

=cut

sub validate_rangelength {
    my ( $name, $value, $conditionalValue ) = @_;

    my ( $min, $max ) = _range($conditionalValue);
    my $length = length $value;
    my $isValid = $length >= $min && $length <= $max;

    my $message =
      $isValid
      ? ''
      : Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction::parseMessage(
        $name, $min, $max );
    return ( $isValid, $message );
}

=pod

=cut

sub validate_digits {
    my ( $name, $value ) = @_;

    return validate_integer(@_);
}

=pod

=cut

sub validate_creditcard {
    my ( $name, $value ) = @_;

    eval "use Regexp::Common qw /CC/";
    if ($@) {
        return ( 0, 'Install Regexp::Common to use credit card validation.' );
    }
    else {
        eval "$FP_RE{CC}{Mastercard} = $Regexp::Common::RE{CC}{Mastercard}";
    }

    my $isValid = $value =~ m/^$FP_RE{CC}{Mastercard}$/;

    my $message =
      $isValid
      ? ''
      : Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction::parseMessage(
        $name);
    return ( $isValid, $message );
}

=pod

Currently only checks fields with syntax '#id'.

=cut

sub validate_equalto {
    my ( $name, $value, $conditionalValue ) = @_;

    my $isValid = 0;
    if ( $conditionalValue =~ m/^#(.*?)$/ ) {
        my $request = Foswiki::Func::getCgiQuery()
          ; # instead of  Foswiki::Func::getRequestObject() to be compatible with older versions
        my $fieldValue = $request->param($1);
        $isValid = $value eq $fieldValue;
    }

    my $message =
      $isValid
      ? ''
      : Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction::parseMessage(
        $name);
    return ( $isValid, $message );
}

=pod

=cut

sub validate_email {
    my ( $name, $value ) = @_;

    use Foswiki::Plugins::FormPlugin::Validate::Address qw(valid);

    my $isValid = valid($value);

    my $message =
      $isValid
      ? ''
      : Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction::parseMessage(
        $name);
    return ( $isValid, $message );
}

=pod

=cut

sub validate_multiemail {
    my ( $name, $value ) = @_;

    use Foswiki::Plugins::FormPlugin::Validate::Address qw(valid);

    my @addresses = split( /\s*[[\s,;]]*\s*/, $value );
    my $isValid = 0;

    foreach my $address (@addresses) {
        print STDERR "$address:" . valid($address) . "\n";
        $isValid ||= valid($address);
    }

    my $message =
      $isValid
      ? ''
      : Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction::parseMessage(
        $name);
    return ( $isValid, $message );
}

=pod

=cut

sub validate_url {
    my ( $name, $value ) = @_;

    #use Regexp::Common qw /URI/;
    $FP_RE{URI}{HTTP} ||=
qr'(?:(?:http)://(?:(?:(?:(?:(?:(?:[a-zA-Z0-9][-a-zA-Z0-9]*)?[a-zA-Z0-9])[.])*(?:[a-zA-Z][-a-zA-Z0-9]*[a-zA-Z0-9]|[a-zA-Z])[.]?)|(?:[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+)))(?::(?:(?:[0-9]*)))?(?:/(?:(?:(?:(?:(?:(?:[a-zA-Z0-9\-_.!~*\'():@&=+$,]+|(?:%[a-fA-F0-9][a-fA-F0-9]))*)(?:;(?:(?:[a-zA-Z0-9\-_.!~*\'():@&=+$,]+|(?:%[a-fA-F0-9][a-fA-F0-9]))*))*)(?:/(?:(?:(?:[a-zA-Z0-9\-_.!~*\'():@&=+$,]+|(?:%[a-fA-F0-9][a-fA-F0-9]))*)(?:;(?:(?:[a-zA-Z0-9\-_.!~*\'():@&=+$,]+|(?:%[a-fA-F0-9][a-fA-F0-9]))*))*))*))(?:[?](?:(?:(?:[;/?:@&=+$,a-zA-Z0-9\-_.!~*\'()]+|(?:%[a-fA-F0-9][a-fA-F0-9]))*)))?))?)';

    my $isValid = $value =~ m/$FP_RE{URI}{HTTP}/;

    my $message =
      $isValid
      ? ''
      : Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction::parseMessage(
        $name);
    return ( $isValid, $message );
}

=pod

=cut

sub validate_accept {
    my ( $name, $value, $conditionalValue ) = @_;

    $conditionalValue =~ s/\s*,\s*/|/g;

    my $isValid = $value =~ m/^(.+)\.($conditionalValue)$/;

    my $message =
      $isValid
      ? ''
      : Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction::parseMessage(
        $name);
    return ( $isValid, $message );
}

=pod

=cut

sub validate_wikiword {
    my ( $name, $value ) = @_;

    my $isValid = Foswiki::Func::isValidWikiWord($value);

    my $message =
      $isValid
      ? ''
      : Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction::parseMessage(
        $name);
    return ( $isValid, $message );
}

=pod

=cut

sub _range {
    my ($rangeString) = @_;

    my $min;
    my $max;
    if ( $rangeString =~ m/^\s*\[([0-9]+)\s*,\s*([0-9]+)\s*\]\s*$/ ) {
        $min = $1;
        $max = $2;
    }
    return ( $min, $max );
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
