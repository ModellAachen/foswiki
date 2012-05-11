# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
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
# For licensing info read LICENSE file in the TWiki root.
#
# '$Rev$'

=pod

---+ package CreateTopicTag

=cut

# Always use strict to enforce variable scoping
use strict;

package TWiki::Tags::CreateTopicTag::Support;

sub getJSPrefix {
    return <<'EOF';
%STARTSECTION{"formstart"}%<script type="text/javascript">
//<![CDATA[
function canSubmit(inForm, inShouldConvertInput) {
	var topicName = inForm.topic.value;

	var nospaces = removeSpaces(topicName);
	var isATWiki.WikiWord = isTWiki.WikiWord(nospaces);
	var wikiword = removeSpaces(capitalize(inForm.topic.value));

	var nonwikiwordChecked = inForm.nonwikiword.checked;
	if (nonwikiwordChecked) {
		if (inShouldConvertInput) inForm.topic.value = nospaces;
		enableSubmit();
	}
	if (!nonwikiwordChecked && !isATWiki.WikiWord) {
		if (inShouldConvertInput) {
			inForm.topic.value = wikiword;
			enableSubmit();
		} else{
			disableSubmit();
		}
		return false;
	}
	if (!nonwikiwordChecked && isATWiki.WikiWord) {
		if (inShouldConvertInput) inForm.topic.value = wikiword;
		enableSubmit();
	}
	// Use the negative value of the checkbox. This is the ugly way but must be used until edit script parameter =allowsnonwikiword= is implemented.
	inForm.onlywikiname.value = (nonwikiwordChecked == true) ? "off" : "on";
	return true;
}
function enableSubmit() {
	var submitButton = document.forms.newtopic.submit;
	removeClass(submitButton, "twikiSubmitDisabled");
	submitButton.disabled = false;
}
function disableSubmit() {
	var submitButton = document.forms.newtopic.submit;
	addClass(submitButton, "twikiSubmitDisabled");
	submitButton.disabled = true;
}
//]]>
</script>
EOF
}

sub getJSSuffix {
    return <<'EOF';
<script type="text/javascript">
//<![CDATA[
canSubmit(document.forms.newtopic,false);
//]]>
</script>%ENDSECTION{"formend"}%
%BR%
EOF
}

sub getFormStart {
    return <<'EOF';
<form name="newtopic" id="newtopic" action="%SCRIPTURLPATH{edit}%/%BASEWEB%/" onsubmit="return canSubmit(this,true);">%ENDSECTION{"formstart"}%
    <div class="twikiFormSteps">
EOF
}

sub getStep1 {
    return <<'EOF';
        <div class="twikiFormStep">
---+++ %MAKETEXT{"Topic name:"}%
            <p>%STARTSECTION{"topicname"}%<input type="text" class="twikiInputField" name="topic" id="topic" size="40" tabindex="10" %IF{"'%PREFILLTOPIC%'='1'" then="value=\"%BASETOPIC%\"" else="value=\"\""}% onkeyup="canSubmit(this.form,false);" onchange="canSubmit(this.form,false);"  onblur="canSubmit(this.form,true);" /> <span id="webTopicCreatorFeedback" class="twikiInputFieldDisabled"><!--generated name will be put here--></span>%ENDSECTION{"topicname"}%</p>
            <p>%STARTSECTION{"allownonwikiword"}%<input type="checkbox" class="twikiCheckbox" id="nonwikiword" name="nonwikiword" tabindex="11" onchange="canSubmit(this.form,false);" onmouseup="canSubmit(this.form,false);" /><label for="nonwikiword">%MAKETEXT{"Allow non <nop>WikiWord for the new topic name"}%</label><br />
<span class="twikiGrayText">%MAKETEXT{"It's usually best to choose a <a target='WikiWord' onclick=\"return launchWindow('[_1]','WikiWord')\" href='[_1]' rel='nofollow'>WikiWord</a> for the new topic name, otherwise automatic linking may not work. Characters not allowed in topic names, such as spaces will automatically be removed." args="%SYSTEMWEB%,%SCRIPTURLPATH{"view"}%/%SYSTEMWEB%/WikiWord"}%</span>%ENDSECTION{"allownonwikiword"}%</p>
        </div><!--/twikiFormStep-->
EOF
}

sub getStep2 {
    return <<'EOF';
        <div class="twikiFormStep">
---+++ %MAKETEXT{"Topic parent:"}%
            <p>%STARTSECTION{"topicparent"}%<select name="topicparent" size="10" tabindex="12">
                %TOPICLIST{"<option $marker value='$name'>$name</option>" separator=" " selection="%URLPARAM{ "parent" default="%MAKETEXT{"(no parent, orphaned topic)"}%" }%"}%
            <option value="">%MAKETEXT{"(no parent, orphaned topic)"}%</option>
        </select>%ENDSECTION{"topicparent"}%</p>
        </div><!--/twikiFormStep-->
EOF
}

sub getStep3 {
    return <<'EOF';
        <div class="twikiFormStep twikiLast">
            <p>%STARTSECTION{"submit"}%<input id="submit" type="submit" class="twikiSubmit" tabindex="13" value='%MAKETEXT{"Create this topic"}%' />%ENDSECTION{"submit"}%</p>
        </div><!--/twikiFormStep-->
    </div><!--/twikiFormSteps-->
EOF
}

sub getFormEnd {
    return <<'EOF';
    %STARTSECTION{"formend"}%
        <input type="hidden" name="onlywikiname" />
        <input type="hidden" name="onlynewtopic" value="on" />
EOF
}

1;
