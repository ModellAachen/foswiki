# See bottom of file for license and copyright information

package Foswiki::Plugins::FormPlugin::FormData;

use strict;
use warnings;

use Foswiki::Plugins::FormPlugin::Constants;
use Foswiki::Plugins::FormPlugin::FieldData;
use Foswiki::Plugins::FormPlugin::Util;

=pod

=cut

sub new {
    my ( $class, $params, $web, $topic ) = @_;
    my $this = {};

    my ( $options, $initErrors ) = _parseOptions( $params, $web, $topic );
    $this->{options}           = $options;
    $this->{substitutedValues} = {};
    $this->{initErrors}        = $initErrors if $initErrors;
    $this->{fields}          = ();    # array of FieldData objects
    $this->{names}           = {};    # to find field by name
    $this->{validationRules} = {};    # hash of ValidationInstruction objects

    bless $this, $class;
}

=pod

=cut

sub _parseOptions {
    my ( $params, $web, $topic ) = @_;

    my $options = {};

    # the current web.topic
    $options->{formWeb}   = $web;
    $options->{formTopic} = $topic;

    $options->{noFormHtml} = Foswiki::Func::isTrue( $params->{noformhtml}, 0 );

    $options->{name} = $params->{name};
    $options->{initError} |=
      $Foswiki::Plugins::FormPlugin::Constants::MISSING_PARAMS
      ->{MISSING_STARTFORM_PARAM_NAME}
      if !$options->{name} && !$options->{noFormHtml};

    # method
    $options->{method} =
      lc(    $params->{method}
          || $Foswiki::Plugins::FormPlugin::Constants::DEFAULT_METHOD );

    # web, topic
    my $webParam   = $params->{web}   || $web;
    my $topicParam = $params->{topic} || $topic;
    ( $options->{web}, $options->{topic} ) =
      Foswiki::Func::normalizeWebTopicName( $webParam, $topicParam );

    # disable whole form?
    $options->{disabled} =
      Foswiki::Func::isTrue( $params->{disabled} || 'off' );

    # redirection
    $options->{redirectto} = $params->{redirectto};

    # strictverification
    $options->{strictVerification} =
      Foswiki::Func::isTrue( $params->{strictverification} || 'on' );

    # validation
    $options->{disableValidation} =
      Foswiki::Func::isTrue( $params->{validate} || 'on' ) ? 0 : 1;
    $options->{inlineValidationOnly} =
      Foswiki::Func::isTrue( $params->{inlinevalidationonly} || 'off' );
    $options->{serversideValidationOnly} =
      Foswiki::Func::isTrue( $params->{serversidevalidationonly} || 'off' );

    $options->{substitute} =
      Foswiki::Func::isTrue( $params->{substitute} || 'off' );

    # action
    $options->{restAction} = $params->{restaction};
    $params->{action} ||= '';
    $options->{action} = $params->{action};
    $options->{initError} |=
      $Foswiki::Plugins::FormPlugin::Constants::MISSING_PARAMS
      ->{MISSING_STARTFORM_PARAM_ACTION}
      if !$params->{action} && !$options->{noFormHtml};

    if (   $params->{action}
        && $params->{action} =~
m/^(attach|changes|configure|edit|jsonrpc|login|logon|logos|manage|oops|preview|rdiffauth|rdiff|register|rename|resetpasswd|save|search|statistics|upload|view|viewauth|viewfile)$/
      )
    {

        # for now, assume that all scripts use script/web/topic
        $options->{$Foswiki::Plugins::FormPlugin::Constants::ACTION_URL_TAG} =
          "%SCRIPTURL{$1}%/$options->{web}/$options->{topic}";
    }
    elsif ( $params->{action} eq 'rest' ) {
        if ( $options->{restAction} ) {
            $options->{$Foswiki::Plugins::FormPlugin::Constants::ACTION_URL_TAG}
              = "%SCRIPTURL{rest}%/$options->{restAction}";
        }
        elsif ( !$options->{noFormHtml} ) {
            $options->{initError} |=
              $Foswiki::Plugins::FormPlugin::Constants::MISSING_PARAMS
              ->{MISSING_STARTFORM_PARAM_RESTACTION};
        }
    }
    else {
        $options->{$Foswiki::Plugins::FormPlugin::Constants::ACTION_URL_TAG} =
          $params->{action};
    }

    my ( $urlParams, $urlParamParts ) = _urlParams();
    if (   $options->{method} eq 'get'
        && $urlParamParts
        && scalar @{$urlParamParts} )
    {

        # append the query string to the url
        # in case of POST, use hidden fields (see below)
        my $queryParamPartsString = join( ';', @{$urlParamParts} );
        $options->{$Foswiki::Plugins::FormPlugin::Constants::ACTION_URL_TAG} .=
          "?$queryParamPartsString"
          if $queryParamPartsString;
    }
    elsif ( $urlParams && keys %{$urlParams} ) {
        $options->{urlParams} = $urlParams;
    }
    my $anchor = $params->{anchor};
    if ($anchor) {
        $options->{anchor} = $anchor;
        $options->{$Foswiki::Plugins::FormPlugin::Constants::ACTION_URL_TAG} .=
          "#$anchor"
          if $anchor && $options->{action} ne 'rest';
    }

    $options->{onSubmit} = $params->{onSubmit};

    # html options
    $options->{id}              = $params->{id} if $params->{id};
    $options->{formcssclass}    = $params->{formcssclass};
    $options->{elementcssclass} = $params->{elementcssclass};
    $options->{elementformat}   = $params->{elementformat}
      || $params->{fieldformat};

    # custom separator
    $options->{sep} =
      defined $params->{sep}
      ? $params->{sep}
      : $Foswiki::Plugins::FormPlugin::Constants::DEFAULT_SEP;

    $options->{noredirect} =
      Foswiki::Func::isTrue( $params->{noredirect} ) ? 1 : undef;

    # clean up
    Foswiki::Plugins::FormPlugin::Util::deleteEmptyHashFields($options);

    my $initErrors = _handleErrors($options);

    return ( $options, $initErrors );
}

=pod

=cut

sub _handleErrors {
    my ($options) = @_;

    my $errors;
    if ( $options->{initError} ) {

        # shorthand
        my $missingName =
          $Foswiki::Plugins::FormPlugin::Constants::MISSING_PARAMS
          ->{MISSING_STARTFORM_PARAM_NAME};
        my $missingAction =
          $Foswiki::Plugins::FormPlugin::Constants::MISSING_PARAMS
          ->{MISSING_STARTFORM_PARAM_ACTION};

        if (   ( $options->{initError} & $missingName )
            && ( $options->{initError} & $missingAction ) )
        {
            my $message = Foswiki::Func::expandTemplate(
                'formplugin:message:author:missing_name_and_action');
            $message =~ s/\$action/$options->{action}/g;
            $message =~ s/\$name/$options->{name}/g;
            push( @{$errors}, $message );
        }
        elsif ( $options->{initError} & $missingName ) {
            my $message = Foswiki::Func::expandTemplate(
                'formplugin:message:author:missing_name');
            $message =~ s/\$action/$options->{action}/g;
            $message =~ s/\$name/$options->{name}/g;
            push( @{$errors}, $message );
        }
        elsif ( $options->{initError} & $missingAction ) {
            my $message = Foswiki::Func::expandTemplate(
                'formplugin:message:author:missing_action');
            $message =~ s/\$action/$options->{action}/g;
            $message =~ s/\$name/$options->{name}/g;
            push( @{$errors}, $message );
        }
        if ( $options->{initError} &
            $Foswiki::Plugins::FormPlugin::Constants::MISSING_PARAMS
            ->{MISSING_STARTFORM_PARAM_RESTACTION} )
        {
            my $message = Foswiki::Func::expandTemplate(
                'formplugin:message:author:missing_rest_action');
            push( @{$errors}, $message );
        }
    }
    return $errors || undef;
}

=pod

_urlParams() -> (\%urlParams, \@urlParamsParts)

Retrieves the url params - not the POSTed variables!

=cut

sub _urlParams {

    my $query = Foswiki::Func::getCgiQuery();
    my $url_with_path_and_query = $query->url( -query => 1 );

    my $urlParams     = {};
    my @urlParamParts = ();
    if ( $url_with_path_and_query =~ m/\?(.*)(#|$)/ ) {
        my $queryString = $1;
        my @parts = split( ';', $queryString );
        foreach my $part (@parts) {
            if ( $part =~ m/^(.*?)\=(.*?)$/ ) {
                my $key = $1;
                next
                  if ( $key eq 'validation_key' )
                  ;    # Don't pass through the previous validation_key

                # retrieve value from param
                my $value = $query->url_param($key);
                if ( defined $value ) {
                    $urlParams->{$key} = $value if defined $value;
                    push @urlParamParts, $part;
                }
            }
        }
        return ( $urlParams, \@urlParamParts );
    }
    else {
        return ( undef, undef );
    }
}

=pod

=cut

sub addField {
    my ( $this, $fieldData ) = @_;

    my $name = $fieldData->{options}->{name};
    if ( !$this->{names}->{$name} ) {
        $this->{names}->{$name} = $fieldData;
        push( @{ $this->{fields} }, $fieldData );
    }
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
