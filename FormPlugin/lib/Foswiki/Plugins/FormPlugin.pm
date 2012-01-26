# See bottom of file for license and copyright information

package Foswiki::Plugins::FormPlugin;

use strict;
use warnings;

use Storable qw(freeze thaw);
use Data::Dumper;

use Foswiki::Func;
use Foswiki::Plugins::FormPlugin::Constants;
use Foswiki::Plugins::FormPlugin::FormData;
use Foswiki::Plugins::FormPlugin::FieldData;
use Foswiki::Plugins::FormPlugin::RendererFactory;
use Foswiki::Plugins::FormPlugin::Validate::InlineValidator;
use Foswiki::Plugins::FormPlugin::Validate::BackendValidator;
use Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction;

our $VERSION          = '$Rev$';
our $RELEASE          = '2.3.1';
our $SHORTDESCRIPTION = 'Lets you create simple and advanced HTML forms';

# Name of this Plugin, only used in this module
our $pluginName = 'FormPlugin';

our $NO_PREFS_IN_TOPIC = 1;

my $doneHeader;
my $formData;
my $submittedFormData;
my $template;
my $renderFormDone;
my $redirecting;
our $tabIndex;

=pod

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;
    
    debug("initPlugin");

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    _initTopicVariables(@_);

    Foswiki::Func::registerTagHandler( 'STARTFORM',   \&_startForm );
    Foswiki::Func::registerTagHandler( 'ENDFORM',     \&_endForm );
    Foswiki::Func::registerTagHandler( 'FORMELEMENT', \&_formElement );

    # for testing rest interface
    my %options;
    Foswiki::Func::registerRESTHandler( 'test', \&_restTest, %options );
    
    # Plugin correctly initialized
    return 1;
}

sub _initTopicVariables {
    my ( $topic, $web, $user, $installWeb ) = @_;

    $doneHeader     = 0;
    $tabIndex       = 1;
    $renderFormDone = 0;
    $redirecting = 0;
    
    my $query = Foswiki::Func::getCgiQuery()
      ; # instead of  Foswiki::Func::getRequestObject() to be compatible with older versions
    my $submittedFormName =
      $query->param($Foswiki::Plugins::FormPlugin::Constants::FORM_NAME_TAG);
    if ( !$submittedFormName ) {
        _sessionClearForm('');
    }
}

=pod

=cut

sub _initFormVariables {

    undef $formData;

    if ( !$template ) {
        _readConstantsFromTemplate();
    }
}

sub _readConstantsFromTemplate {
    $template =
      Foswiki::Func::loadTemplate(
        Foswiki::Sandbox::untaintUnchecked( lc($pluginName) ) );

    $Foswiki::Plugins::FormPlugin::Constants::DEFAULT_TITLE_FORMAT =
      Foswiki::Func::expandTemplate('formplugin:format:element:title');
    $Foswiki::Plugins::FormPlugin::Constants::DEFAULT_ELEMENT_FORMAT =
      Foswiki::Func::expandTemplate('formplugin:format:element');
    $Foswiki::Plugins::FormPlugin::Constants::DEFAULT_HIDDEN_FIELD_FORMAT =
      Foswiki::Func::expandTemplate('formplugin:format:element:hidden');
    $Foswiki::Plugins::FormPlugin::Constants::TEMPLATE_JAVASCRIPT_FIELDS =
      Foswiki::Func::expandTemplate('formplugin:javascript:fields');
    $Foswiki::Plugins::FormPlugin::Constants::TEMPLATE_JAVASCRIPT_FIELD =
      Foswiki::Func::expandTemplate('formplugin:javascript:field');
    $Foswiki::Plugins::FormPlugin::Constants::TEMPLATE_JAVASCRIPT_FOCUS =
      Foswiki::Func::expandTemplate('formplugin:javascript:focus');
    $Foswiki::Plugins::FormPlugin::Constants::TEMPLATE_JAVASCRIPT_PLACEHOLDER =
      Foswiki::Func::expandTemplate('formplugin:javascript:placeholder');
    $Foswiki::Plugins::FormPlugin::Constants::TEMPLATE_INLINE_VALIDATION =
      Foswiki::Func::expandTemplate('formplugin:javascript:inlinevalidation');
    $Foswiki::Plugins::FormPlugin::Constants::TEMPLATE_INLINE_VALIDATION_REQUIRES_DEFAULT
      = Foswiki::Func::expandTemplate(
        'formplugin:javascript:inlinevalidation:requires:default');
    $Foswiki::Plugins::FormPlugin::Constants::TEMPLATE_REDIRECT_WARNING
      = Foswiki::Func::expandTemplate(
        'formplugin:message:redirect_warning');
}

=pod

_startForm( $session, $params, $topic, $web ) -> $html

=cut

sub _startForm {
    my ( $session, $params, $topic, $web ) = @_;

    debug("_startForm");

    _initFormVariables();
    _addHeader();

    $formData =
      Foswiki::Plugins::FormPlugin::FormData->new( $params, $web, $topic );

    my $errors = _verifyForm($formData) if !$formData->{initErrors};

    my $renderer =
      Foswiki::Plugins::FormPlugin::RendererFactory::getFormRenderer('html');
    my $html = $renderer->renderFormStart( $formData, $errors );
    return $html;
}

sub _verifyForm {
    my ($formData) = @_;

    my $formName = $formData->{options}->{name} || '';

    # check if this is the form that has been submitted (if after a submit)
    my $query = Foswiki::Func::getCgiQuery()
      ; # instead of  Foswiki::Func::getRequestObject() to be compatible with older versions
    my $submittedFormName =
      $query->param($Foswiki::Plugins::FormPlugin::Constants::FORM_NAME_TAG)
      || '';

    $submittedFormData = _sessionReadForm($submittedFormName)
      if $submittedFormName;

    my $errors;
    if ( defined $submittedFormData && $submittedFormName eq $formName ) {

        debug( "\t submittedFormData=" . Dumper($submittedFormData) );

        $errors = _clearRequestFromUnknownFields( $query, $submittedFormData )
          if $submittedFormData->{options}->{strictVerification};

        _updateFieldsWithRequestData( $query, $submittedFormData );

        if (   !$submittedFormData->{options}->{disableValidation}
            && !$submittedFormData->{options}->{inlineValidationOnly} )
        {

            debug("\t proceed to validate");

            $errors =
              Foswiki::Plugins::FormPlugin::Validate::BackendValidator::validate(
                $submittedFormData->{fields},
                $submittedFormData->{validationRules}, $errors );

            if ( !$errors || !scalar @{$errors} ) {

                debug("\t OK, no validation errors");

                # proceed
                if ( !$submittedFormData->{options}->{noredirect} ) {
                    return _redirectToActionUrl($submittedFormData);

                    # form start rendered anyhow below
                }
            }
            else {
                debug("\t WRONG: validation errors");

                #_sessionSaveForm( $submittedFormName, $submittedFormData );
                # error rendered below
            }

        }
        elsif ( $formData->{options}->{substitute} ) {
            _substituteFieldTokens( $query, $submittedFormData );
            return _redirectToActionUrl($submittedFormData);
        }

    }
    else {
        debug("\t no submittedFormName");
    }
    return $errors;
}

=pod

_endForm( $session, $params, $topic, $web ) -> $html

=cut

sub _endForm {
    my ( $session, $params, $topic, $web ) = @_;

    return '' if $redirecting;

    debug("_endForm");

    my $renderer =
      Foswiki::Plugins::FormPlugin::RendererFactory::getFormRenderer('html');
    my $html = $renderer->renderFormEnd($formData);

    return $html if $formData->{initErrors};

    $formData->{validationRules} = _processValidationRules($formData)
      if !$formData->{options}->{disableValidation};

    if ( !$formData->{options}->{disableValidation} ) {
        if ( !$formData->{options}->{serversideValidationOnly} ) {
            _addInlineValidationToHead( $formData->{options}->{name},
                $formData->{validationRules} );
        }
    }

    my $submittedFormName = $submittedFormData->{options}->{name} || '';
    if ( defined $submittedFormData
        && $submittedFormName eq $formData->{options}->{name} )
    {

        # submitted form has already been stored
        debug("\t this is the submitted form");
    }
    else {

        # store form if we are using validation or substitution
        my $doStore = 1;
        if (   $formData->{options}->{disableValidation}
            || $formData->{options}->{inlineValidationOnly} )
        {
            $doStore = 0;
        }
        if ( $formData->{options}->{substitute} ) {
            $doStore = 1;
        }
        if ($doStore) {
            my $formName = $formData->{options}->{name} || '';
            _sessionSaveForm( $formName, $formData );
        }
    }

    _initFormVariables();

    return $html;
}

=pod

_formElement( $session, $params, $topic, $web ) -> $html

=cut

sub _formElement {
    my ( $session, $params, $topic, $web ) = @_;

    return '' if $redirecting;

    debug("_formElement");

    _addHeader();

    my $fieldData;

    if ( !$formData ) {

        debug("\t no formData");

        # Basically for testing FORMELEMENT in isolation.
        # But it may also be that users working with an earlier version
        # of FormPlugin have just used FORMELEMENT on the page in between
        # handwritten form tags.
        # So we assume that if no formData exists, we will just render
        # the form field without form

        if ( !$template ) {
            _readConstantsFromTemplate();
        }

        $fieldData =
          Foswiki::Plugins::FormPlugin::FieldData->new( $params, $formData );
    }
    else {

        # build new form

        my $name              = $params->{name}                       || '';
        my $formName          = $formData->{options}->{name}          || '';
        my $submittedFormName = $submittedFormData->{options}->{name} || '';

        if (   defined $submittedFormData
            && $submittedFormName
            && $submittedFormName eq $formName )
        {
            print "HERE\n";

            # fields already populated: do nothing
            $fieldData = $submittedFormData->{names}->{$name};

            debug(  "\t submittedFormData name="
                  . $submittedFormName
                  . " - do nothing." );

        }
        else {

            debug("\t formData but no submittedFormData");

            $fieldData = Foswiki::Plugins::FormPlugin::FieldData->new( $params,
                $formData );
            $formData->addField($fieldData);
        }
    }

    my $fieldRenderer =
      Foswiki::Plugins::FormPlugin::RendererFactory::getFieldRenderer( 'html',
        $fieldData->{options}->{type} );
    my $html = $fieldRenderer->render( $fieldData, $formData );
    return $html;
}

=pod

=cut

sub _addHeader {
    return if $doneHeader;
    $doneHeader = 1;

    # Untaint is required if use locale is on
    Foswiki::Func::loadTemplate(
        Foswiki::Sandbox::untaintUnchecked( lc($pluginName) ) );
    my $css = Foswiki::Func::expandTemplate('formplugin:header:css');
    Foswiki::Func::addToZone( 'head', "$pluginName\_CSS", $css );
}

=pod

_processValidationRules ( \%formData ) -> \%validationRules

Processes validation rules.

=cut

sub _processValidationRules {
    my ($formData) = @_;

    my $rules = {};
    foreach my $field ( @{ $formData->{fields} } ) {

        if ( $field->{options}->{validate} ) {

            my $fieldName = $field->{options}->{name};

            my $validationRule =
              Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction
              ->new( $fieldName, $field->{options}->{validate} );

            $rules->{$fieldName} = $validationRule;
        }
    }
    return $rules;
}

=pod

=cut

sub _addInlineValidationToHead {
    my ( $formName, $validationRules ) = @_;

    debug("_addInlineValidationToHead");

    $formName ||= '';

    my ( $headText, $requires ) =
      Foswiki::Plugins::FormPlugin::Validate::InlineValidator::generateHeadText(
        $validationRules, $formName );

    # check dependencies

    my $createJQREQUIRE = sub {
        my ($require) = @_;
        my $name = $require;
        $name =~ s/^JQUERYPLUGIN::(.*?)$/$1/;
        $name = lc($name);

        my $tmpl = Foswiki::Func::expandTemplate(
            'formplugin:javascript:inlinevalidation:load:' . $name );
        return $tmpl;
    };

    foreach my $require ( @{$requires} ) {
        if ( $require eq 'JQUERYPLUGIN::WIKIWORD' ) {
            my $text = &$createJQREQUIRE($require);
            Foswiki::Func::expandCommonVariables($text);
        }
    }

    Foswiki::Func::addToZone(
        'script', "$pluginName\_$formName\_validation",
        $headText, join( ',', @{$requires} )
    );
}

=pod

=cut

sub _redirectToActionUrl {
    my ($formData) = @_;

    debug("_redirectToActionUrl");

    my $query = Foswiki::Func::getCgiQuery()
      ; # instead of  Foswiki::Func::getRequestObject() to be compatible with older versions

    # use web and topic values
    my $topic = $formData->{options}->{topic};
    my $web   = $formData->{options}->{web};

    _substituteFieldTokens( $query, $formData );

    if ( defined $formData->{options}->{action}
        && $formData->{options}->{action} eq 'rest' )
    {
        $query->param( -name => 'topic', -value => "$web\.$topic" )
          if defined $topic;
        $query->param( -name => 'web', -value => $web ) if defined $web;
        $query->path_info( '/' . $formData->{options}->{restAction} )
          if defined $formData->{options}->{restAction};
    }
    else {
        $query->param( -name => 'topic', -value => $topic ) if defined $topic;
        $query->param( -name => 'web',   -value => $web )   if defined $web;
        $query->path_info("/$web/$topic") if defined $topic && defined $web;
    }

    my $url =
      $query->param($Foswiki::Plugins::FormPlugin::Constants::ACTION_URL_TAG);
    $url = Foswiki::Func::expandCommonVariables($url);

    $query->uri($url);

    debug( "_redirectToActionUrl END; formData=" . Dumper($formData) );
    debug( "\t query=" . Dumper($query) );

    $redirecting = 1;
    Foswiki::Func::redirectCgiQuery( undef, $url, 1 );

    print "Status: 307\nLocation: $url\n\n";
	_sessionClearForm($formData->{options}->{name});

    return '';
}

=pod

=cut

sub _substituteFieldTokens {
    my ( $query, $formData ) = @_;

    debug("_substituteFieldTokens");

    # create quick lookup hash
    my $keyValues = {};

    # field data
    foreach my $field ( @{ $formData->{fields} } ) {
        my $name   = $field->{options}->{name};
        my @values = ();
        if ( defined $field->{submittedValue} ) {
            @values = @{ $field->{submittedValue} };
        }
        $keyValues->{$name} = {
            type      => 'FIELD',
            values    => \@values,
            condition => $field->{options}->{condition}
        };
    }

    # form options
    while ( my ( $name, $value ) = each %{ $formData->{options} } ) {
        my @values = defined $value ? ($value) : ('');
        $keyValues->{$name} = {
            type      => 'FORM',
            values    => \@values,
            condition => undef
        };
    }

    debug( "\t keyValues=" . Dumper($keyValues) );

    my $meetsCondition = sub {
        my ($condition) = @_;

        my ( $fieldName, $conditionalValue ) =
          $condition =~ m/\s*\$(\w+)\s*\=\s*(.*?)$/s;

        my $validationRule =
          Foswiki::Plugins::FormPlugin::Validate::ValidationInstruction->new(
            $fieldName, $conditionalValue );

        my $value = join( ',', @{ $keyValues->{$fieldName}->{values} } );

        debug(
"\t\t meetsCondition; fieldName=$fieldName; condition=$condition; value=$value"
        );

        my $validationParams = $validationRule->{params};
        foreach my $methodName ( keys %{$validationParams} ) {
            my ( $validates, $message ) =
              Foswiki::Plugins::FormPlugin::Validate::BackendValidator::test(
                $methodName, $value, $conditionalValue );

            debug(
"\t\t\t methodName=$methodName; validates=$validates; message=$message"
            );

            return 0 if !$validates;
        }
        return 1;
    };

    my $substituteValue = sub {
        my ($key) = @_;

        return join( ',', @{ $keyValues->{$key}->{values} } );
    };

    # void invalid values
    while ( my ( $name, $lookup ) = each %{$keyValues} ) {

        my $condition = $lookup->{condition};

        if ( $condition && !( &$meetsCondition($condition) ) ) {
            debug("\t\t $name does not meet condition");

            $query->param( -name => $name, -value => '' );
            my @emptyValues = ('');
            $lookup->{values} = \@emptyValues;
        }
    }

    # substitute
    while ( my ( $name, $lookup ) = each %{$keyValues} ) {

        debug("\t substitute:$name");

        foreach my $listValue ( @{ $lookup->{values} } ) {

            debug("\t listValue=$listValue");

            # find strings like '$Name' to subsitute the value of field 'Name'
            # so $keyValues->{Name}->{values} gives access to the values array
            $listValue =~ s/\$(\w+)/&$substituteValue($1)/ges;
        }
        if ( $lookup->{type} eq 'FIELD' ) {
            my $field = $formData->{names}->{$name};
            $field->{substitutedValue} = $lookup->{values};
        }
        elsif ( $lookup->{type} eq 'FORM' ) {
            $formData->{substitutedValues}->{$name} = $lookup->{values};
        }
    }

    debug( "\t _substituteFieldTokens END; formData=" . Dumper($formData) );

    _updateRequestWithFieldValues( $query, $formData );
}

=pod

Adds submitted form values in $field->{submittedValue}

=cut

sub _updateFieldsWithRequestData {
    my ( $query, $formData ) = @_;

    debug("_updateFieldsWithRequestData");

    # field data
    foreach my $field ( @{ $formData->{fields} } ) {
        my $name   = $field->{options}->{name};
        my @values = $query->param($name);

        debug("\t name=$name");
        debug( "\t values=" . Dumper(@values) );

        $field->{submittedValue} = \@values;
    }

    debug(
        "\t _updateFieldsWithRequestData END; formData=" . Dumper($formData) );

}

sub _updateRequestWithFieldValues {
    my ( $query, $formData ) = @_;

    debug("_updateRequestWithFieldValues");

    # field data
    foreach my $field ( @{ $formData->{fields} } ) {
        my $name   = $field->{options}->{name};
        my @values = ();
        if ( defined $field->{substitutedValue} ) {
            @values = @{ $field->{substitutedValue} };
        }
        elsif ( defined $field->{submittedValue} ) {
            @values = @{ $field->{submittedValue} };
        }

        debug("\t field:$name");
        debug( "\t\t values=" . Dumper( \@values ) ) if scalar @values;

        $query->param(
            -name  => $name,
            -value => @values
        );
    }

    while ( my ( $name, $value ) = each %{ $formData->{substitutedValues} } ) {

        my @values = ();
        if ( defined $value ) {
            @values = @{$value};
        }

        debug("\t form item:$name");
        debug( "\t\t values=" . Dumper( \@values ) ) if scalar @values;

        $query->param(
            -name  => $name,
            -value => @values
        );
    }

    debug( "\t _updateRequestWithFieldValues END; request=" . Dumper($query) );
}

=pod

_clearRequestFromUnknownFields( $request, \%formData )

Check if fields in request object are defined in $fields.
Otherwise throw out of request object.

Known added fields:
- FP_actionurl
- FP_name
- FP_anchor
- validation_key
    
=cut

sub _clearRequestFromUnknownFields {
    my ( $request, $formData ) = @_;

    debug("_clearRequestFromUnknownFields");

    my @errors = ();

    my $KNOWN_FIELDS = {
        $Foswiki::Plugins::FormPlugin::Constants::ACTION_URL_TAG => 1,
        $Foswiki::Plugins::FormPlugin::Constants::FORM_NAME_TAG  => 1,
        validation_key                                           => 1,
        redirectto                                               => 1,
        topic                                                    => 1,
        web                                                      => 1,
        text                                                     => 1,
    };

    my $fields = $formData->{fields};

    # add field names to KNOWN_FIELDS
    foreach my $field ( @{$fields} ) {
        my $name = $field->{options}->{name};
        $KNOWN_FIELDS->{$name} = 1;
    }

    # compare names in request with
    foreach my $name ( keys %{ $request->{param} } ) {
        if ( !$KNOWN_FIELDS->{$name} ) {

            debug("\t invalid field:$name");

            # mark field as invalid
            $request->param(
                -name => $name,
                -value =>
                  $Foswiki::Plugins::FormPlugin::Constants::INVALID_FIELD
            );

            my $errorText = Foswiki::Func::expandTemplate(
                'formplugin:message:error:unknownfield');

            my $error =
              Foswiki::Plugins::FormPlugin::Validate::Error->new( undef, $name,
                $errorText );
            push @errors, $error;
        }
    }

    return \@errors;
}

sub _sessionReadForm {
    my ($formName) = @_;
    return if $Foswiki::cfg{Plugins}{FormPlugin}{UnitTesting};

    debug("_sessionReadForm; formName=$formName");

    my $sessionFormData = Foswiki::Func::getSessionValue(
        $Foswiki::Plugins::FormPlugin::Constants::FORM_DATA_PARAM . $formName);

    my $serializedFormData = $sessionFormData->{$formName};
    my $formData           = thaw($serializedFormData);

    return $formData;
}

sub _sessionSaveForm {
    my ( $formName, $formData ) = @_;
    return if $Foswiki::cfg{Plugins}{FormPlugin}{UnitTesting};

    debug("_sessionSaveForm; formName=$formName");
    debug( "\t formData=" . Dumper($formData) );

    my $sessionFormData = Foswiki::Func::getSessionValue(
        $Foswiki::Plugins::FormPlugin::Constants::FORM_DATA_PARAM . $formName)
      || {};

    my $serializedFormData = Storable::freeze($formData);

    $sessionFormData->{$formName} = $serializedFormData;

    Foswiki::Func::setSessionValue(
        $Foswiki::Plugins::FormPlugin::Constants::FORM_DATA_PARAM . $formName,
        $sessionFormData );

}

sub _sessionClearForm {
    my ($formName) = @_;
    return if $Foswiki::cfg{Plugins}{FormPlugin}{UnitTesting};

    debug("_sessionClearForm");

    Foswiki::Func::setSessionValue(
        $Foswiki::Plugins::FormPlugin::Constants::FORM_DATA_PARAM . $formName, undef );
}

=pod

Shorthand debug function call.

=cut

sub debug {
    my ($text) = @_;
    Foswiki::Func::writeDebug("$pluginName:$text")
      if $text && $Foswiki::cfg{Plugins}{FormPlugin}{Debug};

    print STDOUT "$text\n"
      if $Foswiki::cfg{Plugins}{FormPlugin}{UnitTesting}
          && $text
          && $Foswiki::cfg{Plugins}{FormPlugin}{Debug};
}

=pod

For testing rest calls with FormPlugin.
No params: returns a dump of all params.
Param =show=: returns the value of that param.

=cut

sub _restTest {
    my ( $session, $subject, $verb, $response ) = @_;

    debug("_restTest");
    debug("\t subject=$subject") if defined $subject;
    debug("\t verb=$verb")       if defined $verb;

    my $query = Foswiki::Func::getRequestObject();
    debug( "\t params=" . Dumper( $query->{param} ) );

    my $showParam = $query->param('show');

    if ( defined $showParam ) {
        return $query->param($showParam);
    }
    else {
        use Data::Dumper;
        return Dumper( $query->param() );
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
