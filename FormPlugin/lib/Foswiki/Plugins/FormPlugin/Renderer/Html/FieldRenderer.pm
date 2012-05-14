# See bottom of file for license and copyright information

package Foswiki::Plugins::FormPlugin::Renderer::Html::FieldRenderer;

use strict;
use warnings;

use Foswiki::Plugins::FormPlugin::Renderer::Html::BaseRenderer ();
our @ISA = ('Foswiki::Plugins::FormPlugin::Renderer::Html::BaseRenderer');

use CGI qw( :all -no_undef_params);
use Foswiki::Plugins::FormPlugin::Constants;
use Foswiki::Plugins::FormPlugin::Renderer::Html::FieldFactory;

=pod

=cut

sub new {
    my $class = shift;

    my $this = bless( {}, $class );
    return $this;
}

=pod

=cut

sub render {
    my ( $this, $fieldData, $formData ) = @_;

    # do not render form if the form has errors
    return $this->_renderErrors($fieldData)
      if $fieldData->{initErrors};

    my $options = $fieldData->{options};

    my $field =
      Foswiki::Plugins::FormPlugin::Renderer::Html::FieldFactory::getField(
        $options->{type} );

    my $renderedField = $field->render($options);
    return $this->_formatField( $renderedField, $fieldData, $formData );
}

=pod

=cut

sub renderError {
    my ( $this, $message, $fieldName, $fieldData, $formData ) = @_;

    my $currentUrl = $this->_currentUrl();
    my $fieldTitle;
    if ( defined $fieldData ) {
        $fieldName  = $fieldData->{options}->{name};
        $fieldTitle = $fieldData->{options}->{title};

        # remove punctuation
        $fieldTitle =~ s/^(.*?)[[:punct:][:space:]]*$/$1/;
    }

    my $anchor = _anchorLinkName( $fieldName, $formData->{options}->{name} );

    return _formatErrorItem( $message, $currentUrl, $anchor, $fieldTitle,
        $fieldName );
}

=pod

=cut

sub _formatErrorItem {
    my ( $errorString, $currentUrl, $anchor, $fieldTitle, $fieldName ) = @_;

    my $fieldLink = '';
    if ( defined $fieldTitle ) {
        $fieldLink = "<a href=\"$currentUrl#$anchor\">$fieldTitle</a>";
    }
    else {
        $fieldLink = $fieldName;
    }
    $fieldLink =~ s/\$name/$fieldName/go;

    return "   * $fieldLink: $errorString\n";
}

=pod

=cut

sub _currentUrl {
    my ($this) = @_;

    return $this->{CURRENT_URL} if $this->{CURRENT_URL};

    my $query = Foswiki::Func::getCgiQuery();
    $this->{CURRENT_URL} = $query->url( -path_info => 1 );
    return $this->{CURRENT_URL};
}

=pod

=cut

sub _formatField {
    my ( $this, $renderedField, $fieldData, $formData ) = @_;

    my $options = $fieldData->{options};

    my $sep = $options->{sep}
      || $Foswiki::Plugins::FormPlugin::Constants::DEFAULT_SEP;

    my $format = $options->{format};

    # javascripts
    my @javascripts = ();

    # focus
    push @javascripts,
      $Foswiki::Plugins::FormPlugin::Constants::TEMPLATE_JAVASCRIPT_FOCUS
      if $options->{focus};

    # placeholder
    push @javascripts,
      $Foswiki::Plugins::FormPlugin::Constants::TEMPLATE_JAVASCRIPT_PLACEHOLDER
      if $options->{placeholder};

    my $functionMap = {
        onFocus     => 'focus',
        onBlur      => 'blur',
        onClick     => 'click',
        onChange    => 'change',
        onBlur      => 'blur',
        onSelect    => 'select',
        onMouseOver => 'mouseover',
        onMouseOut  => 'mouseout',
        onKeyUp     => 'keyup',
        onKeyDown   => 'keydown',
    };

    while ( my ( $key, $behaviour ) = each %{$functionMap} ) {
        if ( $options->{javascript}->{$key} ) {
            my $fieldScript =
              $this->_formatJavascriptFunction( $behaviour,
                $options->{javascript}->{$key},
                $fieldData, $formData );
            push @javascripts, $fieldScript;
        }
    }

    if ( scalar @javascripts ) {
        my $javascriptTemplate =
          $Foswiki::Plugins::FormPlugin::Constants::TEMPLATE_JAVASCRIPT_FIELDS;
        my $pluginName = $Foswiki::Plugins::FormPlugin::pluginName;
        my $formName   = $formData->{options}->{name} || 'formPluginForm';
        my $id         = "$pluginName\_$formName\_fields";
        $javascriptTemplate =~ s/\$id/$id/;
        my $javascripts = join "\n", @javascripts;
        $javascriptTemplate =~ s/\$javascript/$javascripts/;
        $format             =~ s/(\$e)/$1$javascriptTemplate/;
    }

    # field
    $format =~ s/(\$e)/$this->_renderFieldToken($1, $renderedField)/ge;

    # titleformat
    $format =~
s/(\$titleformat)/$this->_renderTitleFormatToken($1, $options->{titleFormat})/ge
      if $options->{title};

    # title
    my $title = $options->{title} || '';
    $format =~ s/(\$t)\b/$this->_renderTitleToken($1, $title)/ge;

    # mandatory
    $format =~
      s/(\$m)/$this->_renderMandatoryToken($1, $options->{mandatory})/ge;

    # anchor link
    my $anchorDone = 0;
    if ( $format =~ m/\$a/ ) {
        $format =~
s/(\$a)/$this->_renderAnchorToken($options->{name}, $formData->{options}->{name})/ge;
        $anchorDone = 1;
    }

    # hint
    $format =~ s/(\$h)/$this->_renderHintToken($1, $options->{hint})/ge;

    ###############
    # clean up tokens if no title
    $format =~ s/\$titleformat//go;
    $format =~ s/\$a//go;
    $format =~ s/\$m//go;
    $format = $this->_renderFormattingTokens($format);

    ############### container css
    if ( $options->{fieldCssClass} ) {
        $format = CGI::div( { class => $options->{fieldCssClass} }, $format );
    }

    if ( $fieldData->{error} ) {
        $format = _formatError($format);
    }

    ############### anchor
    if ( $formData && !$anchorDone ) {

        # add anchor so individual fields can be targeted from any
        # error feedback
        $format =
          _anchorLinkHtml( $options->{name}, $formData->{options}->{name} )
          . $format;
        $anchorDone = 1;
    }

    $format =~ s/\n/$sep/ge if ( $sep ne "\n" );

    return $format;
}

=pod

=cut

sub _renderFieldToken {
    my ( $this, $text, $token ) = @_;

    # prevent wiki words inside form fields
    $token = "<noautolink>$token</noautolink>";
    return $token;
}

=pod

=cut

sub _renderTitleFormatToken {
    my ( $this, $text, $token ) = @_;

    $token ||= $Foswiki::Plugins::FormPlugin::Constants::DEFAULT_TITLE_FORMAT;
    return $token;
}

=pod

=cut

sub _renderTitleToken {
    my ( $this, $text, $token ) = @_;

    $token = $token ? _wrapHtmlTitleContainer($token) : '';
    return $token;
}

=pod

=cut

sub _renderMandatoryToken {
    my ( $this, $text, $token ) = @_;

    $token =
      $token
      ? _wrapHtmlMandatoryContainer(
        $Foswiki::Plugins::FormPlugin::Constants::MANDATORY_STRING)
      : '';
    return $token;
}

=pod

=cut

sub _renderHintToken {
    my ( $this, $text, $token ) = @_;

    $token = $token ? _wrapHtmlHint($token) : '';
    return $token;
}

=pod

=cut

sub _renderAnchorToken {
    my ( $this, $fieldName, $formName ) = @_;

    my $token = _anchorLinkHtml( $fieldName, $formName );
    return $token;
}

=pod

=cut

sub _wrapHtmlTitleContainer {
    my ($text) = @_;

    return '<noautolink>'
      . CGI::span(
        { class => $Foswiki::Plugins::FormPlugin::Constants::TITLE_CSS_CLASS },
        $text
      ) . '</noautolink>';
}

=pod

=cut

sub _wrapHtmlMandatoryContainer {
    my ($text) = @_;

    return CGI::span(
        {
            class =>
              $Foswiki::Plugins::FormPlugin::Constants::MANDATORY_CSS_CLASS
        },
        $text
    );
}

=pod

=cut

sub _anchorLinkHtml {
    my ( $name, $formName ) = @_;

    my $anchorName = _anchorLinkName( $name, $formName );
    return '<a name="' . $anchorName . '"><!--//--></a>';
}

sub _anchorLinkName {
    my ( $name, $formName ) = @_;

    $name     ||= '';
    $formName ||= '';
    my $anchorName = ucfirst($formName) . ucfirst($name);
    $anchorName =~ s/[[:punct:][:space:]]//go;
    return $Foswiki::Plugins::FormPlugin::Constants::ELEMENT_ANCHOR_NAME
      . $anchorName;
}

=pod

=cut

sub _wrapHtmlHint {
    my ($text) = @_;

    return CGI::label(
        { class => $Foswiki::Plugins::FormPlugin::Constants::HINT_CSS_CLASS },
        $text );
}

=pod

Finds string for CSS class 'foswikiInputField' or 'formPluginGroup' and adds an error class to it.

=cut

sub _formatError {
    my ($text) = @_;

    $text =~
s/\b(foswikiInputField|$Foswiki::Plugins::FormPlugin::Constants::ELEMENT_GROUP_CSS_CLASS)\b/$1 $Foswiki::Plugins::FormPlugin::Constants::ERROR_CSS_CLASS/;

    return $text;
}

=pod

=cut

sub _renderFormattingTokens {
    my ( $this, $text ) = @_;

    $text =~ s/\$nop//go;
    $text =~ s/\$n/\n/go;
    $text =~ s/\$percnt/%/go;
    $text =~ s/\$dollar/\$/go;
    $text =~ s/\$quot/\"/go;

    return $text;
}

=pod

=cut

sub _formatJavascriptFunction {
    my ( $this, $behaviour, $function, $fieldData, $formData ) = @_;

    my $fieldScript =
      $Foswiki::Plugins::FormPlugin::Constants::TEMPLATE_JAVASCRIPT_FIELD;
    $fieldScript =~ s/\$formname/$formData->{options}->{name}/g;
    $fieldScript =~ s/\$fieldname/$fieldData->{options}->{name}/g;
    $fieldScript =~ s/\$behaviour/$behaviour/g;
    $fieldScript =~ s/\$function/$function/g;

    return $fieldScript;
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
