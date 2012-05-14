# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2007 - 2011 Andrew Jones, andrewjones86@googlemail.com
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
# For licensing info read LICENSE file in the Foswiki root.

package Foswiki::Plugins::AutoCompletePlugin;

use strict;

require Foswiki::Func;
require Foswiki::Plugins;

require CGI;

use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC $id $doneYui $doneStyle @loadedData);

our $VERSION = '$Rev$';
our $RELEASE = '1.2.1';
our $SHORTDESCRIPTION =
'Provides an Autocomplete input field based on Yahoo\'s User Interface Library';
our $NO_PREFS_IN_TOPIC = 1;
our $pluginName        = 'AutoCompletePlugin';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # global variables
    $id         = 0;
    $doneYui    = 0;
    $doneStyle  = 0;
    @loadedData = ();

    Foswiki::Func::registerTagHandler( 'AUTOCOMPLETE', \&_handleTag );

    _Debug('init OK');

    # Plugin correctly initialized
    return 1;
}

# =========================
# handles autocomplete boxes in topics
sub _handleTag {

    #    my($session, $params, $theTopic, $theWeb) = @_;

    _Debug('Found in topic');

    return _createTextfield( $_[1] );
}

# Used to provide autocomplete text boxes in forms
sub renderFormFieldForEditHandler {
    my ( $name, $type, $size, $value, $attributes, $possibleValues ) = @_;
    return undef unless $type eq 'autocomplete';

    _Debug('Found in form');

    my %params = Foswiki::Func::extractParameters($possibleValues);

    $params{name} = $name;
    $params{size} = $size;
    unless ( $value eq $possibleValues ) {
        $params{value} = $value;
    }
    $params{class} = 'foswikiInputField';

    return _createTextfield( \%params );

}

# =========================
sub _createTextfield {

    my $params = shift;

    unless ( $params->{name} ) {
        return _returnError("The 'name' parameter is required.");
    }
    unless ( Foswiki::Func::topicExists( undef, $params->{datatopic} ) ) {
        return _returnError("$params->{datatopic} does not exist.");
    }
    unless ( $params->{datasection} ) {
        return _returnError("The 'datasection' parameter is required.");
    }

    # unique id
    $id++;

    my $size = $params->{size} || '20em';
    unless ( $size =~ m/em|px/ ) {
        $size .= 'em';
    }

    _addYUI();
    _addStyle( $params->{formname} );

    my $dataVar = _addData( $params->{datatopic}, $params->{datasection} );
    my $js = _getJavascript(
        $params->{name}, $dataVar,
        $params->{itemformat}        || 'item',
        $params->{delimchar}         || '',
        $params->{itemselecthandler} || ''
    );

    my $class;
    if ( $params->{class} ) {
        $class .= $params->{class} . ' autoCompleteInput';
    }
    else {
        $class = 'autoCompleteInput';
    }

    # parameters for textfield
    my %textfieldParams = (
        id    => $params->{name} . 'Input',
        name  => $params->{name},
        class => $class,
        style => "width:$size;"
    );

    # Optional parameters
    $textfieldParams{value} = $params->{value}
      if $params->{value};
    $textfieldParams{tabindex} = $params->{tabindex}
      if $params->{tabindex};
    $textfieldParams{onblur} = $params->{onblur}
      if $params->{onblur};
    $textfieldParams{onfocus} = $params->{onfocus}
      if $params->{onfocus};
    $textfieldParams{onselect} = $params->{onselect}
      if $params->{onselect};
    $textfieldParams{onchange} = $params->{onchange}
      if $params->{onchange};
    $textfieldParams{onmouseover} = $params->{onmouseover}
      if $params->{onmouseover};
    $textfieldParams{onmouseout} = $params->{onmouseout}
      if $params->{onmouseout};

    my $textfield = CGI::textfield( \%textfieldParams );

    my $results = CGI::div(
        {
            id    => $params->{name} . 'Results',
            class => 'autoCompleteResults',
            style => "width:$size;"
        },
        ''
    );

    return ( $js . $textfield . "\n" . $results );

}

# =========================
# adds the data to the head
# before it does this, it checks the data has not already been loaded on this topic
# if it has, will use the same one again
# this is good for performance if the same autocomplete is used multiple times on one topic (it does happen :-)
sub _addData {
    my ( $datatopic, $datasection ) = @_;

    my $dataVar = $datatopic;
    $dataVar =~ s/\.//;
    $dataVar .= "_$datasection";

    if ( !grep( /$dataVar/, @loadedData ) ) {

        # data has not been loaded before

        push( @loadedData, $dataVar );

        my $data = Foswiki::Func::expandCommonVariables(
            "%INCLUDE{\"$datatopic\" section=\"$datasection\"}%");

        my $out =
            '<script type="text/javascript">' . "\n"
          . "var $dataVar = [$data]; \n"
          . '</script>';

        Foswiki::Func::addToHEAD( $pluginName . '_data' . $id, $out );
    }

    return $dataVar;
}

# the javascript that makes it all work
sub _getJavascript {
    my ( $name, $dataVar, $itemformat, $delimchar, $customEvent ) = @_;

    my $Input   = $name . 'Input';
    my $Results = $name . 'Results';

    $delimchar = "topicAC.delimChar = \"$delimchar\""
      if $delimchar;
    $customEvent = "topicAC.itemSelectEvent.subscribe($customEvent);"
      if $customEvent;

    my $js = <<"EOT";
<script type="text/javascript">
    YAHOO.util.Event.addListener(window, "load", initAutoComplete$id);
    function initAutoComplete$id() {
        var topics = $dataVar;
        var oACDS = new YAHOO.widget.DS_JSArray(topics);
        var topicAC = new YAHOO.widget.AutoComplete("$Input", "$Results", oACDS);
        topicAC.queryDelay = 0;
        topicAC.autoHighlight = true;
        topicAC.useIFrame = false;
        topicAC.prehighlightClassName = "yui-ac-prehighlight";
        topicAC.typeAhead = false;
        $delimchar
        topicAC.allowBrowserAutocomplete = false;
        topicAC.useShadow = false;
        $customEvent
        topicAC.formatResult = function(item, query) { return $itemformat; };
    }
</script>
EOT

    return $js;
}

# adds the YUI Javascript files from header
# these are from the YahooUserInterfaceContrib, if installed
# or directly from the internet (See http://developer.yahoo.com/yui/articles/hosting/)
sub _addYUI {

    return if ( $doneYui == 1 );
    $doneYui = 1;

    my $yui;

    eval 'use Foswiki::Contrib::YahooUserInterfaceContrib';
    if ( !$@ ) {
        _Debug('YahooUserInterfaceContrib is installed, using local files');
        $yui =
'<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/YahooUserInterfaceContrib/build/yahoo-dom-event/yahoo-dom-event.js"></script>'
          . '<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/YahooUserInterfaceContrib/build/datasource/datasource-min.js"></script>'
          . '<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/YahooUserInterfaceContrib/build/autocomplete/autocomplete-min.js"></script>';
    }
    else {
        _Debug(
            'YahooUserInterfaceContrib is not installed, using Yahoo servers');
        $yui =
'<script type="text/javascript" src="http://yui.yahooapis.com/2.7.0/build/yahoo-dom-event/yahoo-dom-event.js"></script>'
          . '<script type="text/javascript" src="http://yui.yahooapis.com/2.7.0/build/datasource/datasource-min.js"></script>'
          . '<script type="text/javascript" src="http://yui.yahooapis.com/2.7.0/build/autocomplete/autocomplete-min.js"></script>';
    }

    Foswiki::Func::addToHEAD( $pluginName . '_yui', $yui );
}

# adds style sheet
sub _addStyle {

    return if ( $doneStyle == 1 );
    $doneStyle = 1;

    my ($formName) = @_;

    my $form;
    if ($formName) {
        $form = '#' . $formName;
    }
    else {
        $form = 'form';
    }

    my $Input   = '.autoCompleteInput';
    my $Results = '.autoCompleteResults';

    my $style = <<"EOT";
<style type="text/css" media="all">
<nop>$form {
    position:relative;
}
$Results {
    position:relative;
}
$Results .yui-ac-content {
    position:absolute;
    width:100%;
    font-size:94%; /* mimic foswikiInputField */
    padding:0 .2em; /* mimic foswikiInputField */
    border-width:1px;
    border-style:solid;
    border-color:#ddd #888 #888 #ddd;
    background:#fff;
    overflow:hidden;
    z-index:9050;
}
$Results .yui-ac-shadow {
    display:none;
    position:absolute;
    margin:2px;
    width:100%;
    background:#ccc;
    z-index:9049;
}
$Results ul {
    margin:0;
    padding:0;
    list-style:none;
}
$Results li {
    cursor:default;
    white-space:nowrap;
    margin:0 -.2em;
    padding:.1em .2em; /* mimic foswikiInputField */
}
$Results li.yui-ac-highlight,
$Results li.yui-ac-prehighlight {
    background:#06c; /* link blue */
    color:#fff;
}
</style>
EOT

    Foswiki::Func::addToHEAD( $pluginName . '_style', $style );
}

# =========================
sub _Debug {
    my $text = shift;

    my $debug = Foswiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG") || 0;

    Foswiki::Func::writeDebug("- Foswiki::Plugins::${pluginName}: $text")
      if $debug;
}

sub _returnError {
    my $text = shift;

    _Debug($text);

    return "<span class='foswikiAlert'>${pluginName} error: $text</span>";
}

1;
