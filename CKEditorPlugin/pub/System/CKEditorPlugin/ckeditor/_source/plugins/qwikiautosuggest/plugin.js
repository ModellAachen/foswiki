/*
Copyright (c) 2012, Modell Aachen, http://modell-aachen.de/
All rights reserved.
*/

// THIRD-PARTY CODE for HTML autocomplete list {{{
/*
 * jQuery UI Autocomplete HTML Extension
 *
 * Copyright 2010, Scott González (http://scottgonzalez.com)
 * Dual licensed under the MIT or GPL Version 2 licenses.
 *
 * http://github.com/scottgonzalez/jquery-ui-extensions
 */
(function( $ ) {

var proto = $.ui.autocomplete.prototype,
	initSource = proto._initSource;

function filter( array, term ) {
	var matcher = new RegExp( $.ui.autocomplete.escapeRegex(term), "i" );
	return $.grep( array, function(value) {
		return matcher.test( $( "<div>" ).html( value.label || value.value || value ).text() );
	});
}

$.extend( proto, {
	_initSource: function() {
		if ( this.options.html && $.isArray(this.options.source) ) {
			this.source = function( request, response ) {
				response( filter( this.options.source, request.term ) );
			};
		} else {
			initSource.call( this );
		}
	},

	_renderItem: function( ul, item) {
		return $( "<li></li>" )
			.data( "item.autocomplete", item )
			.append( $( "<a></a>" )[ this.options.html ? "html" : "text" ]( item.label ) )
			.appendTo( ul );
	}
});

})( jQuery );
// }}}

CKEDITOR.plugins.add( 'qwikiautosuggest',
{
	requires : ['dialogui'],

	init : function( editor )
	{
		editor.element.getDocument().appendStyleSheet( CKEDITOR.getUrl(
				'_source/' + // @Packager.RemoveLine
				'plugins/qwikiautosuggest/css/autosuggest.css'
		));

		/*
		 * Add a new method qwikiautosuggest to UI elements in dialogs.
		 * Possible uses:
		 *
		 * element.qwikiautosuggest("init", options):
		 *         Initialize autocompletion for this element. Options is an object
		 *         that should contain at least a "source" element that is a
		 *         URL or a function. The URL may contain the special '$query'
		 *         keyword which will automatically be replaced with the string
		 *         to be autocompleted.
		 *
		 *         For other options, see the documentation for jQuery UI.
		 *
		 * element.qwikiautosuggest("url", url):
		 *         Changes the source URL, implementing the expansion as described
		 *         above.
		 *
		 * element.qwikiautosuggest(...):
		 *         Any other invocation is transparently passed through to jQuery UI's
		 *         autocomplete().
		 */
		CKEDITOR.tools.extend(CKEDITOR.ui.dialog.uiElement.prototype, {
			qwikiautosuggest: function(method) {
				var jq = $(this.getInputElement().$);
				switch (method) {
				case "init":
					var opts = arguments[1];
					if (opts.html !== false) opts.html = true;
					var orig_open = opts.open;
					// Required so that the list doesn't pop up behind the
					// CKEditor BG overlay -jk
					// We can't use the jQuery method of setting a base
					// z-index for the input element; IE7 will mess things up
					// spectacularly if we do. So, set the z-index dynamically
					// ourselves.
					opts.open = function(ev, ui) {
						if (orig_open) orig_open(ev, ui);
						$('.ui-autocomplete').css('z-index', '10020');
					};
					jq.autocomplete(opts);
					var source;
					if (opts && typeof(opts.source) == "string")
						this.qwikiautosuggest("url", opts.source);
					break;
				case "url":
					var url = arguments[1];
					jq.autocomplete("option", "source", function(req, resp) {
						$.ajax({
							'url': url.replace("$query", req.term),
							dataType: 'json',
							success: function(data) {
								resp($.map(data, function(val) {
									var o = {};
									o.label = '<div class="autocomplete_label">'+val.label+'</div>'+
											'<div class="autocomplete_sublabel">'+val.sublabel+'</div>';
									o.value = val.value;
									return o;
								}));
							},
							error: function(){ resp([]); }
						});
					});
					break;
				default:
					jq.autocomplete.apply(jq, arguments);
				}
			}
		});
		CKEDITOR.qwikiautosuggest = {
			topics: FoswikiCKE.getFoswikiVar("VIEWSCRIPTURL") + "/System/AjaxHelper?section=topic;contenttype=text/plain;skin=text;baseweb=all,-Trash*,-System,-TWiki,-Sandbox;input=$query",
			attachments: FoswikiCKE.getFoswikiVar("VIEWSCRIPTURL") + "/System/AjaxHelper?section=attachment;contenttype=text/plain;skin=text;input=$query",
			attachmentURLs: FoswikiCKE.getFoswikiVar("VIEWSCRIPTURL") + "/System/AjaxHelper?section=attachmenturl;contenttype=text/plain;skin=text;input=$query"
		};
	}
} );

