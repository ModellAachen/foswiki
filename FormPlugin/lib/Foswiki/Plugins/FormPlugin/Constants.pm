# See bottom of file for license and copyright information

package Foswiki::Plugins::FormPlugin::Constants;

use strict;
use warnings;

our $STATUS_NO_ERROR  = 'noerror';
our $STATUS_ERROR     = 'error';
our $STATUS_UNCHECKED = 'unchecked';
our $DEFAULT_METHOD   = 'post';
our $FORM_DATA_PARAM  = 'FP_formData';
our $FORM_NAME_TAG    = 'FP_name';
our $FORM_SUBMIT_TAG  = 'FP_submit';
our $ACTION_URL_TAG   = 'FP_actionurl';
our $DEFAULT_SEP      = "\n";
our $INVALID_FIELD    = 'FP_INVALID_FIELD';

our $ERROR_MESSAGES = {
    required    => "This field is required.",
    remote      => "Please fix this field.",
    email       => "Please enter a valid email address.",
    multiemail  => "Please enter one or more valid email addresses.",
    url         => "Please enter a valid URL.",
    date        => "Please enter a valid date.",
    dateISO     => "Please enter a valid date (ISO).",
    number      => "Please enter a valid number.",
    integer     => "Please enter a rounded number.",
    float       => "Please enter a fractional number.",
    digits      => "Please enter only digits.",
    creditcard  => "Please enter a valid credit card number.",
    equalTo     => "Please enter the same value again.",
    accept      => "Please enter a value with a valid extension.",
    maxlength   => "Please enter no more than {0} characters.",
    minlength   => "Please enter at least {0} characters.",
    rangelength => "Please enter a value between {0} and {1} characters long.",
    range       => "Please enter a value between {0} and {1}.",
    max         => "Please enter a value less than or equal to {0}.",
    min         => "Please enter a value greater than or equal to {0}.",
    wikiword    => "Please enter a <nop>WikiWord."
};

our $NOTIFICATION_ANCHOR_NAME = 'FormPluginNotification';
our $ELEMENT_ANCHOR_NAME      = 'FormElement';
our $NOTIFICATION_CSS_CLASS   = 'formPluginNotification foswikiNotification';
our $ELEMENT_GROUP_CSS_CLASS  = 'formPluginGroup';
our $ELEMENT_GROUP_HINT_CSS_CLASS = 'formPluginHint';
our $ERROR_CSS_CLASS              = 'formPluginError';
our $TITLE_CSS_CLASS              = 'formPluginTitle';
our $HINT_CSS_CLASS               = 'formPluginHint';
our $MANDATORY_CSS_CLASS          = 'formPluginMandatory';
our $MANDATORY_STRING             = '*';
our $TEXTONLY_CSS_CLASS           = 'formPluginTextOnly';
our $FOCUS_CSS_CLASS              = 'foswikiFocus';

our $MISSING_PARAMS = {
    MISSING_STARTFORM_PARAM_NAME       => ( 1 << 1 ),
    MISSING_STARTFORM_PARAM_ACTION     => ( 1 << 2 ),
    MISSING_STARTFORM_PARAM_RESTACTION => ( 1 << 3 ),
    MISSING_FORMELEMENT_PARAM_NAME     => ( 1 << 4 ),
    MISSING_FORMELEMENT_PARAM_TYPE     => ( 1 << 5 ),
};

# read from template
# set after plugin init
our $DEFAULT_TITLE_FORMAT;
our $DEFAULT_ELEMENT_FORMAT;
our $DEFAULT_HIDDEN_FIELD_FORMAT;
our $TEMPLATE_JAVASCRIPT_FIELDS;
our $TEMPLATE_JAVASCRIPT_FIELD;
our $TEMPLATE_JAVASCRIPT_FOCUS;
our $TEMPLATE_JAVASCRIPT_PLACEHOLDER;
our $TEMPLATE_INLINE_VALIDATION;
our $TEMPLATE_INLINE_VALIDATION_REQUIRES_DEFAULT;

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
