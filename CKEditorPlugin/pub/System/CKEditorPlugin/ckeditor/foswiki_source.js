/*
  Copyright (C) 2007 Crawford Currie http://wikiring.com and Arthur Clemens
  All Rights Reserved.

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either version 2
  of the License, or (at your option) any later version. For
  more details read LICENSE in the root of the Foswiki distribution.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  As per the GPL, removal of this notice is prohibited.
*/

// Top level setup for tiny MCE editor. Requires tiny_mce.js and foswiki_tiny.js
$(document).ready(function() {
 FoswikiCKE.install();
});

// Setup the standard edit screen for use with TMCE
var IFRAME_ID = 'mce_editor_0';

/**
   Overrides changeEditBox in foswiki_edit.js.
*/
function changeEditBox(inDirection) {
	return false;
}

/**
   Overrides setEditBoxHeight in foswiki_edit.js.
*/
function setEditBoxHeight(inRowCount) {}

/**
   Give the iframe table holder auto-height.
*/
function initTextAreaStyles() {
    var iframe = document.getElementById(IFRAME_ID);
    if (iframe == null) return;
    
    // walk up to the table
    var node = iframe.parentNode;
    var counter = 0;
    while (node != document) {
        if (node.nodeName == 'TABLE') {
            node.style.height = 'auto';
           
            // get select boxes
            var selectboxes = node.getElementsByTagName('SELECT');
            var i, ilen = selectboxes.length;
            for (i=0; i<ilen; ++i) {
                selectboxes[i].style.marginLeft =
                    selectboxes[i].style.marginRight = '2px';
                selectboxes[i].style.fontSize = '94%';
            }
            
            break;
        }
        node = node.parentNode;
    }
}

/**
Disables the use of ESCAPE in the edit box, because some browsers will interpret this as cancel and will remove all changes.
Copied from %SYSTEMWEB%.JavascriptFiles/foswiki_edit.js because it is used in
pickaxe mode.
*/
function handleKeyDown(e) {
	if (!e) e = window.event;
	var code;
	if (e.keyCode) code = e.keyCode;
	if (code==27) return false;
	return true;
}

