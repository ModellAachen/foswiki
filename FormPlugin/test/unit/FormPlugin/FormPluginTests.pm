use strict;
use warnings;

package FormPluginTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use warnings;
use Error qw( :try );

use Foswiki::Plugins::FormPlugin;
use Foswiki::Func;
use Data::Dumper;    # for debugging
use HTML::Form;
use LWP::UserAgent;
use HTTP::Request;

my $DEBUG = 0;
my $query;

sub new {
    my $self = shift()->SUPER::new( 'FormPluginFunctions', @_ );
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $this->{session}->finish();

    $query = new Unit::Request;

    $this->_setPathInfoToTopic( 'view', $this->{test_web},
        $this->{test_topic} );

    # to make the received topic text less cluttered
    $this->_setWebPref( "SKIN", "text" );
}

sub _setPathInfoToTopic {
    my ( $this, $script, $web, $topic ) = @_;

    $query->path_info( "$script/" . $web . '/' . $topic );
    $this->{session}->finish() if ( defined( $this->{session} ) );
    $this->{session} = new Foswiki( undef, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
}

sub loadExtraConfig {
    my $this = shift;
    $this->SUPER::loadExtraConfig();
    setLocalSite();
}

sub setLocalSite {
    $Foswiki::cfg{Plugins}{FormPlugin}{Enabled}     = 1;
    $Foswiki::cfg{Plugins}{FormPlugin}{UnitTesting} = 1;
    $Foswiki::cfg{Plugins}{ZonePlugin}{Enabled}     = 1;
    $Foswiki::cfg{Plugins}{FormPlugin}{Debug}       = $DEBUG;

    #    $Foswiki::cfg{AllowRedirectUrl} = 0;
    #	$Foswiki::cfg{PermittedRedirectHostUrls} = '';
}

#sub tear_down {
#    my $this = shift;
#}

=pod

FORMELEMENT type="text"

=cut

sub test_formelement_type_text {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="comment" 
type="text" 
title="Comment" 
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementComment"><!--//--></a>  <noautolink><span class="formPluginTitle">Comment</span></noautolink> <br /> <noautolink><input type="text" name="comment" tabindex="1"  size="40" class="foswikiInputField" /></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT type="textonly"

=cut

sub test_formelement_type_textonly {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="name" 
type="textonly" 
value="%TOPIC%" 
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementName"><!--//--></a>  <noautolink><span class="formPluginTextOnly">TestTopicFormPluginFunctions</span><input type="hidden" name="name" value="TestTopicFormPluginFunctions"  /></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT type="password"

=cut

sub test_formelement_type_password {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="pw" 
type="password" 
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementPw"><!--//--></a>  <noautolink><input type="password" name="pw" tabindex="1"  size="40" class="foswikiInputField" /></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT type="upload"

=cut

sub test_formelement_type_upload {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
type="upload" 
name="filepath" 
title="Attach profile picture" 
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementFilepath"><!--//--></a>  <noautolink><span class="formPluginTitle">Attach profile picture</span></noautolink> <br /> <noautolink><input type="file" name="filepath" tabindex="1"  size="40" class="foswikiInputField" /></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT type="textarea"

=cut

sub test_formelement_type_textarea {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="body" 
type="textarea"
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementBody"><!--//--></a>  <noautolink><textarea name="body" tabindex="1"  class="foswikiInputField"></textarea></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT type="select"

=cut

sub test_formelement_type_select {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="friend" 
type="select" 
size="5" 
title="Select friend:" 
options="mary, peter, annabel, nicky, jennifer" 
labels="Mary M, Peter P, Annabel A, Nicky N, Jennifer J" 
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementFriend"><!--//--></a>  <noautolink><span class="formPluginTitle">Select friend:</span></noautolink> <br /> <noautolink><select name="friend" tabindex="1"  size="5" class="foswikiSelect">
<option value="mary">Mary M</option>
<option value="peter">Peter P</option>
<option value="annabel">Annabel A</option>
<option value="nicky">Nicky N</option>
<option value="jennifer">Jennifer J</option>
</select></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT type="select" with value of 0

=cut

sub test_formelement_type_select_value_0 {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="friend" 
type="select" 
size="5" 
title="Select friend:" 
options="0, 1, 2, 3, 4" 
labels="Mary M, Peter P, Annabel A, Nicky N, Jennifer J" 
value="0"
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementFriend"><!--//--></a>  <noautolink><span class="formPluginTitle">Select friend:</span></noautolink> <br /> <noautolink><select name="friend" tabindex="1"  size="5" class="foswikiSelect">
<option selected="selected" value="0">Mary M</option>
<option value="1">Peter P</option>
<option value="2">Annabel A</option>
<option value="3">Nicky N</option>
<option value="4">Jennifer J</option>
</select></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT type="selectmulti"

=cut

sub test_formelement_type_selectmulti {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="friends" 
type="selectmulti" 
size="5" 
title="Select friends:" 
options="mary, peter, annabel, nicky, jennifer" 
labels="Mary M, Peter P, Annabel A, Nicky N, Jennifer J" 
value=" mary , annabel " 
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementFriends"><!--//--></a>  <noautolink><span class="formPluginTitle">Select friends:</span></noautolink> <br /> <noautolink><select name="friends" tabindex="1"  size="5" multiple="multiple" class="foswikiSelect">
<option selected="selected" value="mary">Mary M</option>
<option value="peter">Peter P</option>
<option selected="selected" value="annabel">Annabel A</option>
<option value="nicky">Nicky N</option>
<option value="jennifer">Jennifer J</option>
</select></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT type="dropdown"

=cut

sub test_formelement_type_dropdown {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="friend" 
type="dropdown" 
title="Select friend:" 
options=",Mary M, peter=Peter P, annabel=Annabel A, nicky=Nicky N, jennifer=Jennifer J"
value="peter" 
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementFriend"><!--//--></a>  <noautolink><span class="formPluginTitle">Select friend:</span></noautolink> <br /> <noautolink><select name="friend" tabindex="1"  size="1" class="foswikiSelect">
<option value=""></option>
<option value="Mary M">Mary M</option>
<option selected="selected" value="peter">Peter P</option>
<option value="annabel">Annabel A</option>
<option value="nicky">Nicky N</option>
<option value="jennifer">Jennifer J</option>
</select></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT type="checkbox"

=cut

sub test_formelement_type_checkbox {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="name" 
type="checkbox" 
options="mary, peter, annabel, nicky, jennifer"
labels="Mary M, Peter P, Annabel A, Nicky N, Jennifer J"
value=" mary , peter " 
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementName"><!--//--></a>  <noautolink><fieldset class="formPluginGroup"><label><input type="checkbox" name="name" value="mary" checked="checked" class="foswikiCheckbox" size="40" />Mary M</label> <label><input type="checkbox" name="name" value="peter" checked="checked" class="foswikiCheckbox" size="40" />Peter P</label> <label><input type="checkbox" name="name" value="annabel" class="foswikiCheckbox" size="40" />Annabel A</label> <label><input type="checkbox" name="name" value="nicky" class="foswikiCheckbox" size="40" />Nicky N</label> <label><input type="checkbox" name="name" value="jennifer" class="foswikiCheckbox" size="40" />Jennifer J</label></fieldset></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT type="radio"

=cut

sub test_formelement_type_radio {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="name" 
type="radio" 
options="mary, peter, annabel, nicky, jennifer"
labels="Mary M, Peter P, Annabel A, Nicky N, Jennifer J" 
value="mary" 
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementName"><!--//--></a>  <noautolink><fieldset class="formPluginGroup"><label><input type="radio" name="name" value="mary" checked="checked" class="foswikiRadioButton" size="40" />Mary M</label> <label><input type="radio" name="name" value="peter" class="foswikiRadioButton" size="40" />Peter P</label> <label><input type="radio" name="name" value="annabel" class="foswikiRadioButton" size="40" />Annabel A</label> <label><input type="radio" name="name" value="nicky" class="foswikiRadioButton" size="40" />Nicky N</label> <label><input type="radio" name="name" value="jennifer" class="foswikiRadioButton" size="40" />Jennifer J</label></fieldset></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT type="radio" with cssclass="formPluginInlineLabels"

=cut

sub test_formelement_type_radio_inline_labels {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="name" 
type="radio" 
options="mary, peter, annabel, nicky, jennifer"
labels="Mary M, Peter P, Annabel A, Nicky N, Jennifer J" 
value="mary" 
cssclass="formPluginInlineLabels"
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementName"><!--//--></a>  <noautolink><fieldset class="formPluginGroup formPluginInlineLabels"><label><input type="radio" name="name" value="mary" checked="checked" class="foswikiRadioButton" size="40" />Mary M</label> <label><input type="radio" name="name" value="peter" class="foswikiRadioButton" size="40" />Peter P</label> <label><input type="radio" name="name" value="annabel" class="foswikiRadioButton" size="40" />Annabel A</label> <label><input type="radio" name="name" value="nicky" class="foswikiRadioButton" size="40" />Nicky N</label> <label><input type="radio" name="name" value="jennifer" class="foswikiRadioButton" size="40" />Jennifer J</label></fieldset></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT type="date"

=cut

sub test_formelement_type_date {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="date" 
type="date"
}%';

    my $pubUrlSystemWeb =
      Foswiki::Func::getPubUrlPath() . '/' . $Foswiki::cfg{SystemWebName};

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementDate"><!--//--></a>  <noautolink><input type="text" name="date" tabindex="1"  size="15" id="caldate"  class="foswikiInputField" /> <span class="foswikiMakeVisible"><input type="image" name="calendar" src="$pubUrlSystemWeb/JSCalendarContrib/img.gif" align="middle" alt="Calendar" onclick="return showCalendar('caldate','%e %b %Y')" class="editTableCalendarButton" /></span></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT type="submit"

=cut

sub test_formelement_type_submit {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="action" 
type="submit" 
value="Send info" 
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementAction"><!--//--></a>  <noautolink><input type="submit" tabindex="1" name="action" value="Send info" class="foswikiSubmit" /></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT type="button"

=cut

sub test_formelement_type_button {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="action" 
type="button" 
value="Send info" 
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementAction"><!--//--></a>  <noautolink><button tabindex='1' class='foswikiSubmit'>Send info</button></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT type="hidden"

=cut

sub test_formelement_type_hidden {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="CarbonCopy" 
type="hidden" 
default="$Name earns $Salary" 
}%';

    my $expected = <<END_EXPECTED;
<noautolink><input type="hidden" name="CarbonCopy" value="\$Name earns \$Salary"  /></noautolink>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT options="..." - DataForm notation

=cut

sub test_formelement_options_dataform_notation {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="name" 
type="checkbox" 
title="Choose a name:" 
options="mary=Mary M, peter=Peter P, annabel=Annabel A, nicky=Nicky N, jennifer=Jennifer J" 
value=" mary , peter " 
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementName"><!--//--></a>  <noautolink><span class="formPluginTitle">Choose a name:</span></noautolink> <br /> <noautolink><fieldset class="formPluginGroup"><label><input type="checkbox" name="name" value="mary" checked="checked" class="foswikiCheckbox" size="40" />Mary M</label> <label><input type="checkbox" name="name" value="peter" checked="checked" class="foswikiCheckbox" size="40" />Peter P</label> <label><input type="checkbox" name="name" value="annabel" class="foswikiCheckbox" size="40" />Annabel A</label> <label><input type="checkbox" name="name" value="nicky" class="foswikiCheckbox" size="40" />Nicky N</label> <label><input type="checkbox" name="name" value="jennifer" class="foswikiCheckbox" size="40" />Jennifer J</label></fieldset></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT buttonlabel

=cut

sub test_formelement_buttonlabel {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="action" 
type="submit" 
buttonlabel="Send info" 
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementAction"><!--//--></a>  <noautolink><input type="submit" tabindex="1" name="action" value="Send info" class="foswikiSubmit" /></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT placeholder

=cut

sub test_formelement_placeholder {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="comment" 
type="text" 
title="Comment" 
placeholder="anything"
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementComment"><!--//--></a>  <noautolink><span class="formPluginTitle">Comment</span></noautolink> <br /> <noautolink><input type="text" name="comment" tabindex="1"  size="40" class="foswikiInputField" placeholder="anything" /></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT spellcheck on

=cut

sub test_formelement_spellcheck_on {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="comment" 
type="text" 
title="Comment" 
spellcheck="on"
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementComment"><!--//--></a>  <noautolink><span class="formPluginTitle">Comment</span></noautolink> <br /> <noautolink><input type="text" name="comment" tabindex="1"  size="40" class="foswikiInputField" spellcheck="true" /></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT spellcheck off

=cut

sub test_formelement_spellcheck_off {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="comment" 
type="text" 
title="Comment" 
spellcheck="off"
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementComment"><!--//--></a>  <noautolink><span class="formPluginTitle">Comment</span></noautolink> <br /> <noautolink><input type="text" name="comment" tabindex="1"  size="40" class="foswikiInputField" spellcheck="false" /></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT hint

=cut

sub test_formelement_hint {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="comment" 
type="text" 
title="Comment" 
hint="anything"
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementComment"><!--//--></a>  <noautolink><span class="formPluginTitle">Comment</span></noautolink> <br /> <noautolink><input type="text" name="comment" tabindex="1"  size="40" class="foswikiInputField" /></noautolink>  <label class="formPluginHint">anything</label> </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT hint with group

=cut

sub test_formelement_hint_with_group {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="name" 
type="radio" 
options="mary, peter, annabel, nicky, jennifer"
labels="Mary M, Peter P, Annabel A, Nicky N, Jennifer J" 
value="mary" 
hint="anything"
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementName"><!--//--></a>  <noautolink><fieldset class="formPluginGroup formPluginHint"><label><input type="radio" name="name" value="mary" checked="checked" class="foswikiRadioButton" size="40" />Mary M</label> <label><input type="radio" name="name" value="peter" class="foswikiRadioButton" size="40" />Peter P</label> <label><input type="radio" name="name" value="annabel" class="foswikiRadioButton" size="40" />Annabel A</label> <label><input type="radio" name="name" value="nicky" class="foswikiRadioButton" size="40" />Nicky N</label> <label><input type="radio" name="name" value="jennifer" class="foswikiRadioButton" size="40" />Jennifer J</label></fieldset></noautolink>  <label class="formPluginHint">anything</label> </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT mandatory="on"

=cut

sub test_formelement_mandatory {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="comment" 
type="text" 
mandatory="on"
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementComment"><!--//--></a>  <noautolink><input type="text" name="comment" tabindex="1"  size="40" class="foswikiInputField" /></noautolink> <span class="formPluginMandatory">*</span>  </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT format

=cut

sub test_formelement_format {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="comment" 
type="text" 
title="Comment" 
hint="anything"
mandatory="on"
format="   * $a
   * m
   * h
   * $e
   * $t"
}%';

    my $expected = <<END_EXPECTED;
   * <a name="FormElementComment"><!--//--></a>
   * m
   * h
   * <noautolink><input type="text" name="comment" tabindex="1"  size="40" class="foswikiInputField" /></noautolink>
   * <noautolink><span class="formPluginTitle">Comment</span></noautolink>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

sub test_formelement_format_submit {
    my ($this) = @_;

    my $input = '%FORMELEMENT{
name="name"
type="text"
size="50"
format=" $e "
}%%FORMELEMENT{ 
name="action" 
type="submit" 
value="Send info" 
format=" $e "
}%';

    my $expected = <<END_EXPECTED;
<noautolink><input type="text" name="name" tabindex="1"  size="50" class="foswikiInputField" /></noautolink>  <noautolink><input type="submit" tabindex="2" name="action" value="Send info" class="foswikiSubmit" /></noautolink>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );

}

=pod

FORMELEMENT titleformat

=cut

sub test_formelement_titleformat {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="comment" 
type="text" 
title="Comment" 
titleformat=" *$t* <br />"
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementComment"><!--//--></a>  *<noautolink><span class="formPluginTitle">Comment</span></noautolink>* <br /> <noautolink><input type="text" name="comment" tabindex="1"  size="40" class="foswikiInputField" /></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT cssclass

=cut

sub test_formelement_cssclass {
    my ($this) = @_;

    my $input = '%FORMELEMENT{
name="Name"
type="text"
cssclass="foswikiBroadcastMessage"
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementName"><!--//--></a>  <noautolink><input type="text" name="Name" tabindex="1"  size="40" class="foswikiInputField foswikiBroadcastMessage" /></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT size

=cut

sub test_formelement_size {
    my ($this) = @_;

    my $input = '%FORMELEMENT{
name="Name"
type="text"
size="80"
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementName"><!--//--></a>  <noautolink><input type="text" name="Name" tabindex="1"  size="80" class="foswikiInputField" /></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT maxlength

=cut

sub test_formelement_maxlength {
    my ($this) = @_;

    my $input = '%FORMELEMENT{
name="Name"
type="text"
maxlength="10"
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementName"><!--//--></a>  <noautolink><input type="text" name="Name" tabindex="1"  size="40" maxlength="10" class="foswikiInputField" /></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT rows, cols

=cut

sub test_formelement_rows_cols {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="body" 
type="textarea" 
title="Message:" 
rows="5" 
cols="80" 
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementBody"><!--//--></a>  <noautolink><span class="formPluginTitle">Message:</span></noautolink> <br /> <noautolink><textarea name="body" tabindex="1"  rows="5" cols="80" class="foswikiInputField"></textarea></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT focus

=cut

sub test_formelement_focus {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="name" 
type="text"  
focus="on"
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementName"><!--//--></a>  <noautolink><input type="text" name="name" tabindex="1"  size="40" class="foswikiInputField foswikiFocus" /></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT disabled

Adds hidden fields to pass values on submit.

=cut

sub test_formelement_disabled {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="name" 
type="text"  
disabled="on"
value="yo"
}%
%FORMELEMENT{ 
name="friend" 
type="select" 
size="5" 
title="Select friend:" 
options="mary, peter, annabel, nicky, jennifer" 
labels="Mary M, Peter P, Annabel A, Nicky N, Jennifer J" 
disabled="on"
value="nicky"
}%
%FORMELEMENT{ 
name="friends" 
type="checkbox" 
options="mary, peter, annabel, nicky, jennifer"
labels="Mary M, Peter P, Annabel A, Nicky N, Jennifer J"
value="mary,peter"
disabled="on"
}%
%FORMELEMENT{ 
name="otherfriends" 
type="radio" 
options="mary, peter, annabel, nicky, jennifer"
labels="Mary M, Peter P, Annabel A, Nicky N, Jennifer J"
value="jennifer"
disabled="on"
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementName"><!--//--></a>  <noautolink><input type="text" name="name" tabindex="1" value="yo" size="40" disabled="disabled" class="foswikiInputField foswikiInputFieldDisabled" /><input type="hidden" name="name" value="yo"  /></noautolink>   </div>
<div class="formPluginField"> <a name="FormElementFriend"><!--//--></a>  <noautolink><span class="formPluginTitle">Select friend:</span></noautolink> <br /> <noautolink><select name="friend" tabindex="2"  size="5" disabled="disabled" class="foswikiSelect foswikiSelectDisabled">
<option value="mary">Mary M</option>
<option value="peter">Peter P</option>
<option value="annabel">Annabel A</option>
<option selected="selected" value="nicky">Nicky N</option>
<option value="jennifer">Jennifer J</option>
</select><input type="hidden" name="friend" value="nicky"  /></noautolink>   </div>
<div class="formPluginField"> <a name="FormElementFriends"><!--//--></a>  <noautolink><fieldset class="formPluginGroup"><label><input type="checkbox" name="friends" value="mary" checked="checked" class="foswikiCheckbox foswikiCheckboxDisabled" size="40" disabled='disabled'/><span style="color:gray">Mary M</span></label> <label><input type="checkbox" name="friends" value="peter" checked="checked" class="foswikiCheckbox foswikiCheckboxDisabled" size="40" disabled='disabled'/><span style="color:gray">Peter P</span></label> <label><input type="checkbox" name="friends" value="annabel" class="foswikiCheckbox foswikiCheckboxDisabled" size="40" disabled='disabled'/><span style="color:gray">Annabel A</span></label> <label><input type="checkbox" name="friends" value="nicky" class="foswikiCheckbox foswikiCheckboxDisabled" size="40" disabled='disabled'/><span style="color:gray">Nicky N</span></label> <label><input type="checkbox" name="friends" value="jennifer" class="foswikiCheckbox foswikiCheckboxDisabled" size="40" disabled='disabled'/><span style="color:gray">Jennifer J</span></label></fieldset><input type="hidden" name="friends" value="mary,peter"  /></noautolink>   </div>
<div class="formPluginField"> <a name="FormElementOtherfriends"><!--//--></a>  <noautolink><fieldset class="formPluginGroup"><label><input type="radio" name="otherfriends" value="mary" class="foswikiRadioButton foswikiRadioButtonDisabled" size="40" disabled='disabled'/><span style="color:gray">Mary M</span></label> <label><input type="radio" name="otherfriends" value="peter" class="foswikiRadioButton foswikiRadioButtonDisabled" size="40" disabled='disabled'/><span style="color:gray">Peter P</span></label> <label><input type="radio" name="otherfriends" value="annabel" class="foswikiRadioButton foswikiRadioButtonDisabled" size="40" disabled='disabled'/><span style="color:gray">Annabel A</span></label> <label><input type="radio" name="otherfriends" value="nicky" class="foswikiRadioButton foswikiRadioButtonDisabled" size="40" disabled='disabled'/><span style="color:gray">Nicky N</span></label> <label><input type="radio" name="otherfriends" value="jennifer" checked="checked" class="foswikiRadioButton foswikiRadioButtonDisabled" size="40" disabled='disabled'/><span style="color:gray">Jennifer J</span></label></fieldset><input type="hidden" name="otherfriends" value="jennifer"  /></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_formelement_disabled_per_item {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="friends" 
type="checkbox" 
options="mary, peter, annabel, nicky, jennifer"
labels="Mary M, Peter P, Annabel A, Nicky N, Jennifer J"
value="mary"
disabled="peter, annabel"
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementFriends"><!--//--></a>  <noautolink><fieldset class="formPluginGroup"><label><input type="checkbox" name="friends" value="mary" checked="checked" class="foswikiCheckbox foswikiCheckboxDisabled" size="40" />Mary M</label> <label><input type="checkbox" name="friends" value="peter" class="foswikiCheckbox foswikiCheckboxDisabled" size="40" disabled='disabled'/><span style="color:gray">Peter P</span></label> <label><input type="checkbox" name="friends" value="annabel" class="foswikiCheckbox foswikiCheckboxDisabled" size="40" disabled='disabled'/><span style="color:gray">Annabel A</span></label> <label><input type="checkbox" name="friends" value="nicky" class="foswikiCheckbox foswikiCheckboxDisabled" size="40" />Nicky N</label> <label><input type="checkbox" name="friends" value="jennifer" class="foswikiCheckbox foswikiCheckboxDisabled" size="40" />Jennifer J</label></fieldset><input type="hidden" name="friends" value="mary"  /></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT readonly

=cut

sub test_formelement_readonly {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="name" 
type="text"  
readonly="on"
value="heh"
}%
%FORMELEMENT{ 
name="text" 
type="textarea"  
readonly="on"
value="mo"
}%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementName"><!--//--></a>  <noautolink><input type="text" name="name" tabindex="1" value="heh" size="40" readonly="readonly" class="foswikiInputField foswikiInputFieldReadOnly" /></noautolink>   </div>
<div class="formPluginField"> <a name="FormElementText"><!--//--></a>  <noautolink><textarea name="text" tabindex="2"  readonly="readonly" class="foswikiInputField foswikiInputFieldReadOnly">mo</textarea></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

FORMELEMENT type="dateformat"

=cut

sub test_formelement_type_dateformat {
    my ($this) = @_;

    my $input = '%FORMELEMENT{ 
name="date" 
type="date" 
dateformat="%e-%b-%y" 
}%';

    my $pubUrlSystemWeb =
      Foswiki::Func::getPubUrlPath() . '/' . $Foswiki::cfg{SystemWebName};

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementDate"><!--//--></a>  <noautolink><input type="text" name="date" tabindex="1"  size="15" id="caldate" class="foswikiInputField" /> <span class="foswikiMakeVisible"><input type="image" name="calendar" src="$pubUrlSystemWeb/JSCalendarContrib/img.gif" align="middle" alt="Calendar" onclick="return showCalendar('caldate','%e-%b-%y')" class="editTableCalendarButton" /></span></noautolink>   </div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_simple_form {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );
    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $input = 'BEFORE
%STARTFORM{
name="myform"
action="view"
}%
%ENDFORM%
AFTER';

    my $expected = <<END_EXPECTED;
BEFORE
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" name="myform">
<input type="hidden" name="FP_actionurl" value="$actionUrl"  />
<input type="hidden" name="FP_name" value="myform"  />
<div>
</div>
</form>
AFTER
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_form_init_error_no_name_no_action {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $input = '%STARTFORM{
}%
%ENDFORM%';
    my $expected = <<END_EXPECTED;
<div class="foswikiAlert"><strong><nop>FormPlugin error:</strong> parameters =name= and =action= are required for =STARTFORM=.</div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_form_init_error_no_name {
    my ($this) = @_;

    my $input = '%STARTFORM{
action="view"
}%
%ENDFORM%';
    my $expected = <<END_EXPECTED;
<div class="foswikiAlert"><strong><nop>FormPlugin error:</strong> parameter =name= is required for =STARTFORM= (missing at form with action: =view=).</div>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_script_manage {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );
    my $manageScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'manage' );

    my $input = '%STARTFORM{
name="myform"
action="manage"
}%
%ENDFORM%';

    my $expected = <<END_EXPECTED;
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" name="myform">
<input type="hidden" name="FP_actionurl" value="$manageScriptUrl"  />
<input type="hidden" name="FP_name" value="myform"  />
<div>
</div>
</form>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_script_rest {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );
    my $restAction = 'CommentPlugin/comment';
    my $restScriptUrl =
      Foswiki::Func::getScriptUrl( 'CommentPlugin', 'comment', 'rest' );

    my $input = '%STARTFORM{
name="myform"
action="rest"
restaction="CommentPlugin/comment"
}%
%ENDFORM%';

    my $expected = <<END_EXPECTED;
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" name="myform">
<input type="hidden" name="FP_actionurl" value="$restScriptUrl"  />
<input type="hidden" name="FP_name" value="myform"  />
<div>
</div>
</form>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_form_init_error_no_action {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $input = '%STARTFORM{
name="myform"
}%
%ENDFORM%';
    my $expected = <<END_EXPECTED;
<div class="foswikiAlert"><strong><nop>FormPlugin error:</strong> parameter =action= is required for =STARTFORM= (missing at form with name: =myform=).</div>
END_EXPECTED

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_startform_param_action_custom {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'attach' );

    my $input = '%STARTFORM{
name="myform"
action="%SCRIPTURL{attach}%' . '/'
      . $this->{test_web} . '/'
      . $this->{test_topic} . '"' . '
}%
%ENDFORM%';

    my $expected = <<END_EXPECTED;
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" name="myform">
<input type="hidden" name="FP_actionurl" value="$actionUrl"  />
<input type="hidden" name="FP_name" value="myform"  />
<div>
</div>
</form>
END_EXPECTED

    $input =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_startform_param_id {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );
    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $input = '%STARTFORM{
name="myform"
action="view"
id="glow in the dark"
}%
%ENDFORM%';
    my $expected = <<END_EXPECTED;
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" name="myform" id="glow in the dark">
<input type="hidden" name="FP_actionurl" value="$actionUrl"  />
<input type="hidden" name="FP_name" value="myform"  />
<div>
</div>
</form>
END_EXPECTED

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_startform_param_topic {
    my ($this) = @_;

    my $topic = 'WebHome';
    $this->_setPathInfoToTopic( 'view', $this->{test_web}, $topic );

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $topic, 'view' );

    my $input = '%STARTFORM{
name="myform"
action="view"
topic="WebHome"
}%
%ENDFORM%';
    my $expected = <<END_EXPECTED;
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" name="myform">
<input type="hidden" name="FP_actionurl" value="$actionUrl"  />
<input type="hidden" name="FP_name" value="myform"  />
<div>
</div>
</form>
END_EXPECTED

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );

    $this->_setPathInfoToTopic( 'view', $this->{test_web},
        $this->{test_topic} );
}

=pod

=cut

sub test_startform_param_web {
    my ($this) = @_;

    my $web = 'MyWeb';
    $this->_setPathInfoToTopic( 'view', $web, $this->{test_topic} );

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );
    my $actionUrl =
      Foswiki::Func::getScriptUrl( $web, $this->{test_topic}, 'view' );

    my $input = '%STARTFORM{
name="myform"
action="view"
web="' . $web . '"
}%
%ENDFORM%';
    my $expected = <<END_EXPECTED;
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" name="myform">
<input type="hidden" name="FP_actionurl" value="$actionUrl" />
<input type="hidden" name="FP_name" value="myform" />
<div>
</div>
</form>
END_EXPECTED

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );

    $this->_setPathInfoToTopic( 'view', $this->{test_web},
        $this->{test_topic} );
}

=pod

=cut

sub test_startform_param_anchor {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $input = '%STARTFORM{
name="myform"
action="view"
anchor="StartHere"
}%
%ENDFORM%';
    my $expected = <<END_EXPECTED;
<form method="post" action="$formScriptUrl#StartHere" enctype="multipart/form-data" name="myform">
<input type="hidden" name="FP_actionurl" value="$actionUrl#StartHere" />
<input type="hidden" name="FP_name" value="myform" />
<div>
</div>
</form>
END_EXPECTED

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );

    _trimSpaces($expected);
    _trimSpaces($result);

    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_startform_param_method_post {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $input = '%STARTFORM{
name="myform"
action="view"
method="post"
}%
%ENDFORM%';
    my $expected = <<END_EXPECTED;
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" name="myform">
<input type="hidden" name="FP_actionurl" value="$actionUrl" />
<input type="hidden" name="FP_name" value="myform" />
<div>
</div>
</form>
END_EXPECTED

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_startform_param_method_get {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $input = '%STARTFORM{
name="myform"
action="view"
method="GET"
}%
%ENDFORM%';
    my $expected = <<END_EXPECTED;
<form method="get" action="$formScriptUrl" enctype="multipart/form-data" name="myform">
<input type="hidden" name="FP_actionurl" value="$actionUrl" />
<input type="hidden" name="FP_name" value="myform" />
<div>
</div>
</form>
END_EXPECTED

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_startform_param_method_empty {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $input = '%STARTFORM{
name="myform"
action="view"
method=""
}%
%ENDFORM%';
    my $expected = <<END_EXPECTED;
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" name="myform">
<input type="hidden" name="FP_actionurl" value="$actionUrl" />
<input type="hidden" name="FP_name" value="myform" />
<div>
</div>
</form>
END_EXPECTED

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_startform_param_redirectto {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );
    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $input = '%STARTFORM{
name="myform"
action="view"
redirectto="System.WebHome"
}%
%ENDFORM%';
    my $expected = <<END_EXPECTED;
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" name="myform">
<input type="hidden" name="FP_actionurl" value="$actionUrl" />
<input type="hidden" name="FP_name" value="myform" />
<input type="hidden" name="redirectto" value="System.WebHome"  />
<div>
</div>
</form>
END_EXPECTED

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_startform_param_disabled {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );
    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $input = '%STARTFORM{
name="myform"
action="view"
disabled="on"
}%
%FORMELEMENT{
type="text"
name="name"
value="so"
}%
%FORMELEMENT{
type="text"
name="to"
value="do"
disabled="off"
}%
%ENDFORM%';
    my $expected = <<END_EXPECTED;
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" name="myform">
<input type="hidden" name="FP_actionurl" value="$actionUrl"  />
<input type="hidden" name="FP_name" value="myform"  />
<div>
<div class="formPluginField"> <a name="FormElementMyformName"><!--//--></a>  <noautolink><input type="text" name="name" tabindex="1" value="so" size="40" disabled="disabled" class="foswikiInputField foswikiInputFieldDisabled" /><input type="hidden" name="name" value="so"  /></noautolink>   </div>
<div class="formPluginField"> <a name="FormElementMyformTo"><!--//--></a>  <noautolink><input type="text" name="to" tabindex="2" value="do" size="40" class="foswikiInputField" /></noautolink>   </div>
</div>
</form>
END_EXPECTED

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_startform_param_formcssclass {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $input = '%STARTFORM{
name="myform"
action="view"
formcssclass="foswikiFormSteps"
}%
%ENDFORM%';
    my $expected = <<END_EXPECTED;
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" name="myform">
<input type="hidden" name="FP_actionurl" value="$actionUrl" />
<input type="hidden" name="FP_name" value="myform" />
<div class="foswikiFormSteps">
</div>
</form>
END_EXPECTED

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_startform_param_elementcssclass {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $input = '%STARTFORM{
name="myform"
action="view"
formcssclass="foswikiFormSteps"
elementcssclass="foswikiFormStep"
}%
%FORMELEMENT{
name="Name"
type="text"
title="Enter your name:"
}%
%ENDFORM%';
    my $expected = <<END_EXPECTED;
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" name="myform">
<input type="hidden" name="FP_actionurl" value="$actionUrl"  />
<input type="hidden" name="FP_name" value="myform"  />
<div class="foswikiFormSteps">
<div class="foswikiFormStep"><div class="formPluginField"> <a name="FormElementMyformName"><!--//--></a>  <noautolink><span class="formPluginTitle">Enter your name:</span></noautolink> <br /> <noautolink><input type="text" name="Name" tabindex="1"  size="40" class="foswikiInputField" /></noautolink>   </div></div>
</div>
</form>
END_EXPECTED

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );

    _trimSpaces($input);
    _trimSpaces($expected);
    _trimSpaces($result);

    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

STARTFORM elementformat

=cut

sub test_startform_param_elementformat {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $input = '%STARTFORM{
name="elementformatform"
action="view"
elementformat="$e <br />"
}%
%FORMELEMENT{
name="friends"
type="radio"
options="mary=Mary M, peter=Peter P, annabel=Annabel A, nicky=Nicky N, jennifer=Jennifer J"
}%
%ENDFORM%';

    my $expected = <<END_EXPECTED;
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" name="elementformatform">
<input type="hidden" name="FP_actionurl" value="$actionUrl"  />
<input type="hidden" name="FP_name" value="elementformatform"  />
<div>
<a name="FormElementElementformatformFriends"><!--//--></a><noautolink><fieldset class="formPluginGroup"><label><input type="radio" name="friends" value="mary" checked="checked" class="foswikiRadioButton" size="40" />Mary M</label> <label><input type="radio" name="friends" value="peter" class="foswikiRadioButton" size="40" />Peter P</label> <label><input type="radio" name="friends" value="annabel" class="foswikiRadioButton" size="40" />Annabel A</label> <label><input type="radio" name="friends" value="nicky" class="foswikiRadioButton" size="40" />Nicky N</label> <label><input type="radio" name="friends" value="jennifer" class="foswikiRadioButton" size="40" />Jennifer J</label></fieldset></noautolink> <br />
</div>
</form>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_startform_param_noformhtml {
    my ($this) = @_;

    my $input = '%STARTFORM{
name="noform"
noformhtml="on"
}%
%FORMELEMENT{
name="Name"
type="text"
title="Enter your name:"
}%
%ENDFORM%';

    my $expected = <<END_EXPECTED;
<div class="formPluginField"> <a name="FormElementNoformName"><!--//--></a>  <noautolink><span class="formPluginTitle">Enter your name:</span></noautolink> <br /> <noautolink><input type="text" name="Name" tabindex="1"  size="40" class="foswikiInputField" /></noautolink>   </div>
END_EXPECTED

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );

    _trimSpaces($expected);
    _trimSpaces($result);

    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_startform_param_onSubmit {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );
    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $input = '%STARTFORM{
name="myform"
action="view"
onSubmit="return notify(this)"
}%
%ENDFORM%';
    my $expected = <<END_EXPECTED;
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" onsubmit="return notify(this)" name="myform">
<input type="hidden" name="FP_actionurl" value="$actionUrl" />
<input type="hidden" name="FP_name" value="myform" />
<div>
</div></form>
END_EXPECTED

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_startform_param_sep_nospace {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );
    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $input = '%STARTFORM{
name="myform"
action="view"
sep=""
}%
%ENDFORM%';
    my $expected = <<END_EXPECTED;
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" name="myform">
<input type="hidden" name="FP_actionurl" value="$actionUrl" />
<input type="hidden" name="FP_name" value="myform" />
<div>
</div></form>
END_EXPECTED

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_startform_param_sep_with_table {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );
    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $input = '%STARTFORM{
name="myform"
action="view"
sep=""
}%
| %FORMELEMENT{
name="Name"
type="text"
title="Enter your name:"
}% |
%ENDFORM%';
    my $expected = <<END_EXPECTED;
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" name="myform"><input type="hidden" name="FP_actionurl" value="$actionUrl"  /><input type="hidden" name="FP_name" value="myform"  /><div>
| <div class="formPluginField"> <a name="FormElementMyformName"><!--//--></a>  <noautolink><span class="formPluginTitle">Enter your name:</span></noautolink> <br /> <noautolink><input type="text" name="Name" tabindex="1"  size="40" class="foswikiInputField" /></noautolink>   </div> |
</div></form>
END_EXPECTED

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_startform_param_validate {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );
    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $input = '%STARTFORM{
name="myform"
action="view"
validate="on"
}%
%FORMELEMENT{
name="Name"
type="text"
mandatory="on"
}%
%FORMELEMENT{
name="action"
type="submit"
value="Submit"
}%
%ENDFORM%';
    my $expected = <<END_EXPECTED;
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" name="myform">
<input type="hidden" name="FP_actionurl" value="$actionUrl"  />
<input type="hidden" name="FP_name" value="myform"  />
<div>
<div class="formPluginField"> <a name="FormElementMyformName"><!--//--></a>  <noautolink><input type="text" name="Name" tabindex="1"  size="40" class="foswikiInputField" /></noautolink> <span class="formPluginMandatory">*</span>  </div>
<div class="formPluginField"> <a name="FormElementMyformAction"><!--//--></a>  <noautolink><input type="submit" tabindex="2" name="action" value="Submit" class="foswikiSubmit" /></noautolink>   </div>
</div>
</form>
END_EXPECTED

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_startform_param_validate_off {
    my ($this) = @_;

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );
    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    my $input = '%STARTFORM{
name="myform"
action="view"
validate="off"
}%
%FORMELEMENT{
name="Name"
type="text"
value=""
validate="nonempty"
}%
%FORMELEMENT{
name="action"
type="submit"
value="Submit"
}%
%ENDFORM%';

    my $response = $this->_submitForm($input);
    my $result   = $response->content;

    _removeValidationKey($result);

    my $expected = <<EXPECTED;
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" name="myform" onsubmit="StrikeOne.submit(this)"><input type='hidden' name='validation_key' value='?' />
<div>
<div class="formPluginField"> <a name="FormElementMyformName"><!--//--></a> <input type="text" name="Name" tabindex="1"  size="40" class="foswikiInputField" />   </div>
<div class="formPluginField"> <a name="FormElementMyformAction"><!--//--></a> <input type="submit" tabindex="2" name="action" value="Submit" class="foswikiSubmit" />   </div>
</div>
</form>
EXPECTED

    _trimSpaces($expected);
    _trimSpaces($result);

    _debug("EXP:$expected");
    _debug("RES:$result");

    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_post_startform_param_noredirect_on {
    my ($this) = @_;

    my $redirectTopic = 'WebHome';

    my $formScriptUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );
    my $actionUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $redirectTopic, 'view' );

    my $input = '%STARTFORM{
name="x"
action="view"
topic="' . $redirectTopic . '"
noredirect="on"
}%
%FORMELEMENT{
name="action"
type="submit"
buttonlabel="Submit"
}%
%ENDFORM%';

    my $response = $this->_submitForm($input);
    my $result   = $response->content;
    _removeValidationKey($result);

    my $expected = <<EXPECTED;
<form method="post" action="$formScriptUrl" enctype="multipart/form-data" name="x" onsubmit="StrikeOne.submit(this)"><input type='hidden' name='validation_key' value='?' />
<input type="hidden" name="FP_actionurl" value="$actionUrl"  />
<input type="hidden" name="FP_name" value="x"  />
<div>
<div class="formPluginField"> <a name="FormElementXAction"><!--//--></a> <input type="submit" tabindex="1" name="action" value="Submit" class="foswikiSubmit" />   </div>
</div>
</form>
EXPECTED

    _trimSpaces($expected);
    _trimSpaces($result);

    _debug("EXP:$expected");
    _debug("RES:$result");

    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

sub _debug {
    my ($text) = @_;

    return if !$DEBUG;
    Foswiki::Func::writeDebug($text);
    print STDOUT $text . "\n";
}

=pod

Copied from PrefsTests.
Used to set the SKIN preference to text, so that the smaller response page is easier to handle.

=cut

sub _setWebPref {
    my ( $this, $pref, $val, $type ) = @_;
    $this->_set( $this->{test_web}, $Foswiki::cfg{WebPrefsTopicName},
        $pref, $val, $type );
}

sub _set {
    my ( $this, $web, $topic, $pref, $val, $type ) = @_;
    $this->assert_not_null($web);
    $this->assert_not_null($topic);
    $this->assert_not_null($pref);
    $type ||= 'Set';

    my $user = $this->{session}->{user};
    $this->assert_not_null($user);
    my $topicObject = Foswiki::Meta->load( $this->{session}, $web, $topic );
    my $text = $topicObject->text();
    $text =~ s/^\s*\* $type $pref =.*$//gm;
    $text .= "\n\t* $type $pref = $val\n";
    $topicObject->text($text);
    try {
        $topicObject->save();
    }
    catch Foswiki::AccessControlException with {
        $this->assert( 0, shift->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() || '' );
    };
}

=pod

_trimSpaces( $text ) -> $text

Removes spaces from both sides of the text.

=cut

sub _trimSpaces {

    #my $text = $_[0]

    $_[0] =~ s/^[[:space:]]+//s;    # trim at start
    $_[0] =~ s/[[:space:]]+$//s;    # trim at end
}

sub _removeFoswikiRedirectCache {

    #my $text = $_[0]
    return if !defined $_[0];

    $_[0] =~ s/\?*foswiki_redirect_cache\=\w+//;
}

sub _removeValidationKey {

    #my $text = $_[0]
    return if !defined $_[0];

    $_[0] =~
s/name='validation_key' value='\?[[:alnum:]]+'/name='validation_key' value='?'/;
}

sub _saveTopicText {
    my ( $this, $formTML ) = @_;

    my $oopsUrl =
      Foswiki::Func::saveTopicText( $this->{test_web}, $this->{test_topic},
        $formTML );
    $this->assert_str_equals( '', $oopsUrl );
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $this->assert_str_equals( $formTML, $text );

    return $text;
}

sub _renderHtml {
    my ( $web, $topic, $text ) = @_;

    my $rendered = Foswiki::Func::expandCommonVariables( $text, $topic, $web );
    $rendered = Foswiki::Func::renderText( $rendered, $web, $topic );
    return $rendered;
}

=pod

This formats the text up to immediately before <nop>s are removed, so we
can see the nops.

=cut

sub _performTestHtmlOutput {
    my ( $this, $expected, $actual, $doRender ) = @_;
    my $session   = $this->{session};
    my $webName   = $this->{test_web};
    my $topicName = $this->{test_topic};

    $actual = _renderHtml( $webName, $topicName, $actual ) if ($doRender);

    # remove random id token
    $actual =~ s/caldate[0-9]+/caldate/go;
    $actual =~ s/<!--A2Z:.*?-->//go;

    $this->assert_html_equals( $expected, $actual );
}

=pod

Get the HTTP::Response object from submitting a form.

=cut

sub _submitForm {
    my ( $this, $formTML ) = @_;

    my $form = $this->_form($formTML);
    use LWP::UserAgent;
    my $ua = LWP::UserAgent->new;

    my $response = $ua->request( $form->click );

=pod
    _debug( "response=" . Dumper($response) );
    _debug( "is_success:" . $response->is_success );
    _debug( "status_line:" . $response->status_line );
    _debug( "content:" . $response->content );
    _debug( "location:" . $response->header('location') ) if defined $response->header('location');
=cut

    return $response;
}

sub _form {
    my ( $this, $formTML ) = @_;

    my $text = $this->_saveTopicText($formTML);
    my $formHtml = _renderHtml( $this->{test_web}, $this->{test_topic}, $text );
    my $formUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    return HTML::Form->parse( $formHtml, base => $formUrl, verbose => 1 );
}

1;
