/*
 * @file image paste plugin for CKEditor
	Feature introduced in: https://bugzilla.mozilla.org/show_bug.cgi?id=490879
	doesn't include images inside HTML (paste from word): https://bugzilla.mozilla.org/show_bug.cgi?id=665341
 * Copyright (C) 2011 Alfonso Martínez de Lizarrondo
 *
 * == BEGIN LICENSE ==
 *
 * Licensed under the terms of any of the following licenses at your
 * choice:
 *
 *  - GNU General Public License Version 2 or later (the "GPL")
 *    http://www.gnu.org/licenses/gpl.html
 *
 *  - GNU Lesser General Public License Version 2.1 or later (the "LGPL")
 *    http://www.gnu.org/licenses/lgpl.html
 *
 *  - Mozilla Public License Version 1.1 or later (the "MPL")
 *    http://www.mozilla.org/MPL/MPL-1.1.html
 *
 * == END LICENSE ==
 *
 */

 // Handles image pasting in Firefox
CKEDITOR.plugins.add( 'imagepaste',
{
	init : function( editor )
	{

		// Paste from clipboard:
		editor.on( 'paste', function(e) {

			var html = e.data.html;
			if (!html)
				return;

			// Replace data: images in Firefox and upload them
			e.data.html = html.replace( /<img src="data:image\/png;base64,.*?" alt="">/g, function( img )
				{
					var data = img.match(/"data:image\/png;base64,(.*?)"/)[1];
					var id = CKEDITOR.tools.getNextId();
					
					var web = foswiki.getPreference("WEB");
					var topic = foswiki.getPreference("TOPIC");

					var url= editor.config.filebrowserImageUploadUrl + "?webName=" + web + "&topicName=" + topic;

					var xhr = new XMLHttpRequest();

					xhr.open("POST", url);
					xhr.onload = function() {
						// Upon finish, get the url and update the file
						//alert(xhr.responseText);
						var imageUrl = xhr.responseText.match(/,\s*"(.*?)"\s*,/)[1];
						var theImage = editor.document.getById( id );
						theImage.data( 'cke-saved-src', imageUrl);
						theImage.setAttribute( 'src', imageUrl);
						theImage.removeAttribute( 'id' );
					}

					// Create the multipart data upload. Is it possible somehow to use FormData instead?
					var BOUNDARY = "---------------------------1966284435497298061834782736";
					var rn = "\r\n";
					var req = "--" + BOUNDARY;

					  req += rn + "Content-Disposition: form-data; name=\"filepath\"";

						var bin = window.atob( data );
						// add timestamp?
						req += "; filename=\"" + id + ".png\"" + rn + "Content-type: image/png";

						req += rn + rn + bin + rn + "--" + BOUNDARY;

					req += "--";

					xhr.setRequestHeader("Content-Type", "multipart/form-data; boundary=" + BOUNDARY);
					xhr.sendAsBinary(req);

					return img.replace(/>/, ' id="' + id + '">')

				});
		});

	} //Init
} );
