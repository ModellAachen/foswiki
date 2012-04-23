/*
Copyright (c) 2003-2010, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

/**
 * @fileOverview The "sourcearea" plugin. It registers the "source" editing
 *		mode, which displays the raw data being edited in the editor.
 */

CKEDITOR.plugins.add( 'qwikiwikitext',
{
	requires : [ 'editingblock' ],

	init : function( editor )
	{
		var wikitext = CKEDITOR.plugins.wikitext,
			win = CKEDITOR.document.getWindow();
		
		editor.on( 'saveWikitext', function(event)
				{
					editor = event.editor;
					
					//alert("alex");
					editor.updateElement()
    				setTimeout(function(){
    					FoswikiCKE.setUpContent(editor);
					}, 1000);
					editor.fire("data");
				});

		editor.on( 'editingBlockReady', function()
			{
				var textarea,
					onResize;

				editor.addMode( 'wikitext',
					{
						load : function( holderElement, data )
						{
							if ( CKEDITOR.env.ie && CKEDITOR.env.version < 8 )
								holderElement.setStyle( 'position', 'relative' );

							// Create the source area <textarea>.
							editor.textarea = textarea = new CKEDITOR.dom.element( 'textarea' );
							textarea.setAttributes(
								{
									dir : 'ltr',
									tabIndex : editor.tabIndex,
									'role' : 'textbox',
									'aria-label' : editor.lang.editorTitle.replace( '%1', editor.name )
								});
							textarea.addClass( 'cke_source' );
							textarea.addClass( 'cke_enable_context_menu' );

							var styles =
							{
								// IE7 has overflow the <textarea> from wrapping table cell.
								width	: CKEDITOR.env.ie7Compat ?  '99%' : '100%',
								height	: '100%',
								resize	: 'none',
								outline	: 'none',
								'text-align' : 'left'
							};

							// Having to make <textarea> fixed sized to conque the following bugs:
							// 1. The textarea height/width='100%' doesn't constraint to the 'td' in IE6/7.
							// 2. Unexpected vertical-scrolling behavior happens whenever focus is moving out of editor
							// if text content within it has overflowed. (#4762)
							if ( CKEDITOR.env.ie )
							{
								onResize = function()
								{
									// Holder rectange size is stretched by textarea,
									// so hide it just for a moment.
									textarea.hide();
									textarea.setStyle( 'height', holderElement.$.clientHeight + 'px' );
									textarea.setStyle( 'width', holderElement.$.clientWidth + 'px' );
									// When we have proper holder size, show textarea again.
									textarea.show();
								};

								editor.on( 'resize', onResize );
								win.on( 'resize', onResize );
								setTimeout( onResize, 0 );
							}
							else
							{
								// By some yet unknown reason, we must stop the
								// mousedown propagation for the textarea,
								// otherwise it's not possible to place the caret
								// inside of it (non IE).
								textarea.on( 'mousedown', function( evt )
									{
										evt.data.stopPropagation();
									} );
							}

							// Reset the holder element and append the
							// <textarea> to it.
							holderElement.setHtml( '' );
							holderElement.append( textarea );
							textarea.setStyles( styles );

							editor.fire( 'ariaWidget', textarea );

							textarea.on( 'blur', function()
								{
									editor.focusManager.blur();
								});

							textarea.on( 'focus', function()
								{
									editor.focusManager.focus();
								});

							// The editor data "may be dirty" after this point.
							editor.mayBeDirty = true;
							
							
							// Set the <textarea> value.

							FoswikiCKE.transform(
						        editor, "html2tml", data,
						            function (text) {
						        		textarea.setValue( text );
						        		editor.fire( 'dataReady' );
						            },
						            function (type, req, o) {
						            	alert("Misserfolg");
						                this.setContent("<div class='foswikiAlert'>"
						                                + "There was a problem retrieving "
						                                + o.url + ": "
						                                + type + " " + req.status + "</div>");
						                //FoswikiCKE.enableSaveButton(true); leave save disabled
						        });

							var keystrokeHandler = editor.keystrokeHandler;
							if ( keystrokeHandler )
								keystrokeHandler.attach( textarea );

							setTimeout( function()
							{
								editor.mode = 'wikitext';
								editor.fire( 'mode' );
							},
							( CKEDITOR.env.gecko || CKEDITOR.env.webkit ) ? 100 : 0 );
						},

						loadData : function( data )
						{
							textarea.setValue( data );
							editor.fire( 'dataReady' );
						},

						getData : function()
						{
							return textarea.getValue();
						},

						getSnapshotData : function()
						{
							return textarea.getValue();
						},

						unload : function( holderElement )
						{
							editor.textarea = textarea = null;

							if ( onResize )
							{
								editor.removeListener( 'resize', onResize );
								win.removeListener( 'resize', onResize );
							}

							if ( CKEDITOR.env.ie && CKEDITOR.env.version < 8 )
								holderElement.removeStyle( 'position' );
						},

						focus : function()
						{
							textarea.focus();
						}
					});
			});

		editor.addCommand( 'wikitext', wikitext.commands.wikitext );

		if ( editor.ui.addButton )
		{
			editor.ui.addButton( 'WikiText',
				{
					label : editor.lang.source,
					command : 'wikitext',
					icon	: this.path + 'images/wikitext.gif'
				});
		}

		editor.on( 'mode', function()
			{
				editor.getCommand( 'wikitext' ).setState(
					editor.mode == 'wikitext' ?
						CKEDITOR.TRISTATE_ON :
						CKEDITOR.TRISTATE_OFF );
			});
	}
});

/**
 * Holds the definition of commands an UI elements included with the sourcearea
 * plugin.
 * @example
 */
CKEDITOR.plugins.wikitext =
{
	commands :
	{
		wikitext :
		{
			modes : { wysiwyg:1, wikitext:1 },

			exec : function( editor )
			{
				if ( editor.mode == 'wysiwyg' )
				{
					editor.fire( 'saveSnapshot' );
				}
				else
				{
					$.blockUI();
					editor.fire( 'saveWikitext' );
				}
				editor.getCommand( 'wikitext' ).setState( CKEDITOR.TRISTATE_DISABLED );
				editor.setMode( editor.mode == 'wikitext' ? 'wysiwyg' : 'wikitext' );
			},

			canUndo : false
		}
	}
};