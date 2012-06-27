/*
Copyright (c) 2003-2010, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

CKEDITOR.dialog.add( 'code', function( editor )
{
	// Function called in onShow to load selected element.
	var loadElements = function( editor, selection, element )
	{
		this.editMode = true;
		this.editObj = element;

		var value = this.editObj.getHtml();

		if ( value )
		{
			//Alex:
			//parsing:
			
			value = value.replace(/&lt;/gi, "<");
			value = value.replace(/&gt;/gi, ">");
			value = value.replace(/&amp;lt;/gi, "<");
			value = value.replace(/&amp;gt;/gi, ">");
			value = value.replace(/&quot;/gi, '"');
			value = value.replace(/&#039;/gi, "'");
			value = value.replace(/&amp;/gi, "&");
			value = value.replace(/&nbsp;/gi, " ");

			this.setValueOf( 'info','foswikicode', value );
		}
		else
			this.setValueOf( 'info','foswikicode', 'Please type in the Macro with this format: %MACRONAME{"Data"}%' );
	};
	
	var createFakeElement = function( editor, realElement )
	{
		var fakeElement = editor.createFakeParserElement( realElement, 'cke_code', 'code', false ),
			fakeStyle = fakeElement.attributes.style || '';

		var width = realElement.attributes.width,
			height = realElement.attributes.height;

		if ( typeof width != 'undefined' )
			fakeStyle = fakeElement.attributes.style = fakeStyle + 'width:' + cssifyLength( width ) + ';';

		if ( typeof height != 'undefined' )
			fakeStyle = fakeElement.attributes.style = fakeStyle + 'height:' + cssifyLength( height ) + ';';

		return fakeElement;
	};

	// Handles the event when the "Target" selection box is changed


	var setupParams = function( page, data )
	{
		if ( data[page] )
			this.setValue( data[page][this.id] || '' );
	};

	var setupPopupParams = function( data )
	{
		return setupParams.call( this, 'target', data );
	};

	var setupAdvParams = function( data )
	{
		return setupParams.call( this, 'adv', data );
	};

	var commitParams = function( page, data )
	{
		if ( !data[page] )
			data[page] = {};

		data[page][this.id] = this.getValue() || '';
	};

	var commitPopupParams = function( data )
	{
		return commitParams.call( this, 'target', data );
	};

	var commitAdvParams = function( data )
	{
		return commitParams.call( this, 'adv', data );
	};

	var unescapeSingleQuote = function( str )
	{
		return str.replace( /\\'/g, '\'' );
	};

	var escapeSingleQuote = function( str )
	{
		return str.replace( /'/g, '\\$&' );
	};

	return {
		title : editor.lang.qwikicode.title,
		minWidth : 350,
		minHeight : 230,
		resizable : CKEDITOR.DIALOG_RESIZE_BOTH,
		contents :
		[
				{
					label : editor.lang.common.generalTab,
					id : 'info',
					elements :
					[
						{
							type : 'html',
							id : 'pasteMsg',
							html : '<div style="white-space:normal;width:340px;">' + editor.lang.clipboard.pasteMsg + '</div>'
						},
						{
							type : 'html',
							id : 'foswikicode',
							style : 'width:340px;height:170px',
							html :
								'<textarea style="' +
									'width:346px;' +
									'height:170px;' +
									'resize: none;' +
									'border:1px solid black;' +
									'background-color:white">' +
								'</textarea>',

							onLoad : function()
							{
								var label = this.getDialog().getContentElement( 'info', 'pasteMsg' ).getElement(),
									input = this.getElement();

								input.setAttribute( 'aria-labelledby', label.$.id );
							},

							focus : function()
							{
								this.getElement().focus();
							}
						}
					]
				}
		],
		
		onShow : function()
		{
			this.editObj = false;
			this.fakeObj = false;
			this.editMode = false;

			var selection = editor.getSelection();
			
			var element = selection.getSelectedElement();
			if ( element && element.getAttribute( 'data-cke-real-element-type' ) && element.getAttribute( 'data-cke-real-element-type' ) == 'code' )
			{
				this.fakeObj = element;
				element = editor.restoreRealElement( this.fakeObj );
				loadElements.apply( this, [ editor, selection, element ] );
				selection.selectElement( this.fakeObj );
			}
			else
			{
				this.setValueOf( 'info','foswikicode', 'Please type in the Macro with this format: %MACRONAME{"Data"}%' );
			}
			this.getContentElement( 'info', 'foswikicode' ).focus();

		},
		onOk : function()
		{
			/* Modac : Hier müssen rein
			*  Validierung ob Zeichen passen
			*  Test, ob Name schon vorhanden ist
			*  Ggf. Möglichkeit das Dokument zu Überschreiben
			*/ 
			{
				var value = this.getContentElement( 'info', 'foswikicode' ).getValue();
				
				// Modac : parsing
				value = value.replace(/</gi, '&lt;');
				value = value.replace(/>/gi, '&gt;');
				value = value.replace(/"/gi, '&quot;');
				value = value.replace(/'/gi, '&#039');
				//value = value.replace(/&/gi, '&amp;');
				value = value.replace(/[\s^\n]/gi, '&nbsp;');
				
				var element = CKEDITOR.dom.element.createFromHtml( '<span class="WYSIWYG_PROTECTED">' + value + '</span>' );
				
				element.removeAttribute( '_cke_saved_name' );
				
				// Insert code element
				var fakeElement = editor.createFakeElement( element, 'cke_code', 'code' );
				if ( !this.editMode )
				{
					editor.insertElement( fakeElement );
				}
				else
				{
					fakeElement.replace( this.fakeObj );
					editor.getSelection().selectElement( fakeElement );
				}
				
				return true;	
			}
		},
		onLoad : function()
		{


		},
		// Inital focus on 'url' field if link is of type URL.
		onFocus : function()
		{
		}
	};
});

/**
 * The e-mail address anti-spam protection option. The protection will be
 * applied when creating or modifying e-mail links through the editor interface.<br>
 * Two methods of protection can be choosed:
 * <ol>	<li>The e-mail parts (name, domain and any other query string) are
 *			assembled into a function call pattern. Such function must be
 *			provided by the developer in the pages that will use the contents.
 *		<li>Only the e-mail address is obfuscated into a special string that
 *			has no meaning for humans or spam bots, but which is properly
 *			rendered and accepted by the browser.</li></ol>
 * Both approaches require JavaScript to be enabled.
 * @name CKEDITOR.config.emailProtection
 * @since 3.1
 * @type String
 * @default '' (empty string = disabled)
 * @example
 * // href="mailto:tester@ckeditor.com?subject=subject&body=body"
 * config.emailProtection = '';
 * @example
 * // href="<a href=\"javascript:void(location.href=\'mailto:\'+String.fromCharCode(116,101,115,116,101,114,64,99,107,101,100,105,116,111,114,46,99,111,109)+\'?subject=subject&body=body\')\">e-mail</a>"
 * config.emailProtection = 'encode';
 * @example
 * // href="javascript:mt('tester','ckeditor.com','subject','body')"
 * config.emailProtection = 'mt(NAME,DOMAIN,SUBJECT,BODY)';
 */
