/*
Copyright (c) 2003-2011, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

/**
 * @fileOverview The "toolbar" plugin. Renders the default toolbar interface in
 * the editor.
 */

(function()
{
	var toolbox = function()
	{
		this.toolbars = [];
		this.focusCommandExecuted = false;
	};

	toolbox.prototype.focus = function()
	{
		for ( var t = 0, toolbar ; toolbar = this.toolbars[ t++ ] ; )
		{
			for ( var i = 0, item ; item = toolbar.items[ i++ ] ; )
			{
				if ( item.focus )
				{
					item.focus();
					return;
				}
			}
		}
	};

	var commands =
	{
		toolbarFocus :
		{
			modes : { wysiwyg : 1, source : 1 },
			// Modac : Testen
			readOnly : 1,

			exec : function( editor )
			{
				if ( editor.toolbox )
				{
					editor.toolbox.focusCommandExecuted = true;

					// Make the first button focus accessible for IE. (#3417)
					// Adobe AIR instead need while of delay.
					if ( CKEDITOR.env.ie || CKEDITOR.env.air )
						setTimeout( function(){ editor.toolbox.focus(); }, 100 );
					else
						editor.toolbox.focus();
				}
			}
		}
	};

	CKEDITOR.plugins.add( 'qwikitoolbar',
	{
		init : function( editor )
		{
			var endFlag;

			var itemKeystroke = function( item, keystroke )
			{
				var next, toolbar;
				var rtl = editor.lang.dir == 'rtl',
					toolbarGroupCycling = editor.config.toolbarGroupCycling;

				toolbarGroupCycling = toolbarGroupCycling === undefined || toolbarGroupCycling;

				switch ( keystroke )
				{
					case 9 :					// TAB
					case CKEDITOR.SHIFT + 9 :	// SHIFT + TAB
						// Cycle through the toolbars, starting from the one
						// closest to the current item.
						while ( !toolbar || !toolbar.items.length )
						{
							toolbar = keystroke == 9 ?
								( ( toolbar ? toolbar.next : item.toolbar.next ) || editor.toolbox.toolbars[ 0 ] ) :
								( ( toolbar ? toolbar.previous : item.toolbar.previous ) || editor.toolbox.toolbars[ editor.toolbox.toolbars.length - 1 ] );

							// Look for the first item that accepts focus.
							if ( toolbar.items.length )
							{
								item = toolbar.items[ endFlag ? ( toolbar.items.length - 1 ) : 0 ];
								while ( item && !item.focus )
								{
									item = endFlag ? item.previous : item.next;

									if ( !item )
										toolbar = 0;
								}
							}
						}

						if ( item )
							item.focus();

						return false;

					case rtl ? 37 : 39 :		// RIGHT-ARROW
					case 40 :					// DOWN-ARROW
						next = item;
						do
						{
							// Look for the next item in the toolbar.
							next = next.next;

							// If it's the last item, cycle to the first one.
							if ( !next && toolbarGroupCycling )
								next = item.toolbar.items[ 0 ];
						}
						while ( next && !next.focus )

						// If available, just focus it, otherwise focus the
						// first one.
						if ( next )
							next.focus();
						else
							// Send a TAB.
							itemKeystroke( item, 9 );

						return false;

					case rtl ? 39 : 37 :		// LEFT-ARROW
					case 38 :					// UP-ARROW
						next = item;
						do
						{
							// Look for the previous item in the toolbar.
							next = next.previous;

							// If it's the first item, cycle to the last one.
							if ( !next && toolbarGroupCycling )
								next = item.toolbar.items[ item.toolbar.items.length - 1 ];
						}
						while ( next && !next.focus )

						// If available, just focus it, otherwise focus the
						// last one.
						if ( next )
							next.focus();
						else
						{
							endFlag = 1;
							// Send a SHIFT + TAB.
							itemKeystroke( item, CKEDITOR.SHIFT + 9 );
							endFlag = 0;
						}

						return false;

					case 27 :					// ESC
						editor.focus();
						return false;

					case 13 :					// ENTER
					case 32 :					// SPACE
						item.execute();
						return false;
				}
				return true;
			};

			var collapserId = "ckeToolbarCollapse";
			var themeSpaceHandler = function( event )
				{
					if ( event.data.space == editor.config.toolbarLocation )
					{
						editor.toolbox = new toolbox();
						

						var labelId = CKEDITOR.tools.getNextId();

						var output = [ '<div class="cke_toolbox" role="group" aria-labelledby="', labelId, '" onmousedown="return false;">' ],
							groupStarted;

						// Sends the ARIA label.
						output.push( '<span id="', labelId, '" class="cke_voice_label">', editor.lang.toolbars, '</span>' );

						var toolbars = editor.toolbox.toolbars,
							toolbar =
									( editor.config.toolbar instanceof Array ) ?
										editor.config.toolbar
									:
										editor.config[ 'toolbar_' + editor.config.toolbar ];

						for ( var r = 0 ; r < toolbar.length ; r++ )
						{
							var toolbarId,
								toolbarObj = 0,
								toolbarName,
								row = toolbar[ r ],
								items;

							// It's better to check if the row object is really
							// available because it's a common mistake to leave
							// an extra comma in the toolbar definition
							// settings, which leads on the editor not loading
							// at all in IE. (#3983)
							if ( !row )
								continue;

							if ( groupStarted )
							{
								output.push( '</div>' );
								groupStarted = 0;
							}

							if ( row === '/' )
							{
								output.push( '<div class="cke_break"></div>' );
								continue;
							}

							items = row.items || row;

							// Create all items defined for this toolbar.
							for ( var i = 0 ; i < items.length ; i++ )
							{
								var item,
									itemName = items[ i ],
									canGroup;

								item = editor.ui.create( itemName );

								if ( item )
								{
									canGroup = item.canGroup !== false;

									// Initialize the toolbar first, if needed.
									if ( !toolbarObj )
									{
										// Create the basic toolbar object.
										toolbarId = CKEDITOR.tools.getNextId();
										toolbarObj = { id : toolbarId, items : [] };
										toolbarName = row.name && ( editor.lang.toolbarGroups[ row.name ] || row.name );

										// Output the toolbar opener.
										output.push( '<span id="', toolbarId, '" class="cke_toolbar ',
											( toolbarName ? 'cke_toolbar_'+toolbarName : ''), '"',
											( toolbarName ? ' aria-labelledby="'+ toolbarId +  '_label"' : '' ),
											' role="toolbar">' );

										// If a toolbar name is available, send the voice label.
										toolbarName && output.push( '<span id="', toolbarId, '_label" class="cke_voice_label">', toolbarName, '</span>' );

										output.push( '<span class="cke_toolbar_start"></span>' );

										// Add the toolbar to the "editor.toolbox.toolbars"
										// array.
										var index = toolbars.push( toolbarObj ) - 1;

										// Create the next/previous reference.
										if ( index > 0 )
										{
											toolbarObj.previous = toolbars[ index - 1 ];
											toolbarObj.previous.next = toolbarObj;
										}
									}

									if ( canGroup )
									{
										if ( !groupStarted )
										{
											output.push( '<span class="cke_toolgroup" role="presentation">' );
											groupStarted = 1;
										}
									}
									else if ( groupStarted )
									{
										output.push( '</span>' );
										groupStarted = 0;
									}

									var itemObj = item.render( editor, output );
									index = toolbarObj.items.push( itemObj ) - 1;

									if ( index > 0 )
									{
										itemObj.previous = toolbarObj.items[ index - 1 ];
										itemObj.previous.next = itemObj;
									}

									itemObj.toolbar = toolbarObj;
									itemObj.onkey = itemKeystroke;

									/*
									 * Fix for #3052:
									 * Prevent JAWS from focusing the toolbar after document load.
									 */
									itemObj.onfocus = function()
									{
										if ( !editor.toolbox.focusCommandExecuted )
											editor.focus();
									};
								}
							}

							if ( groupStarted )
							{
								output.push( '</span>' );
								groupStarted = 0;
							}

							if ( toolbarObj )
								output.push( '<span class="cke_toolbar_end"></span></span>' );
						}

						if ( editor.config.toolbarCanCollapse && !editor.config.toolbar.match(/Provis/) )
						{
							var collapserFn = CKEDITOR.tools.addFunction(function() {
								editor.execCommand( 'toolbarCollapse' );
							});

							output.push( '<span id="' + collapserId + '" class="cke_expertenmodus cke_button">' );
							output.push( '<a title="' + editor.lang.toolbarExpand + '" tabIndex="-1"' );
							output.push( ' onclick="CKEDITOR.tools.callFunction(' + collapserFn + ')">',
									'<span class="cke_expertenicon_expand"></span></a></span>' );
						}

						output.push( '</div>' );

						event.data.html += output.join( '' );
					}
				};
			editor.on( 'themeSpace', themeSpaceHandler );
			// Have to re-add it because the theme code feels like removing all handlers
			// even though we still need this one
			editor.on( 'themeLoaded', function( event ) {
				editor.on( 'themeSpace', themeSpaceHandler );
			} );

			// Style for expand button
			$('head').append('<style type="text/css">\n'+
				'.cke_expertenmodus { float: right; }\n'+
				'.cke_expertenicon_expand { background: url('+CKEDITOR.basePath+'images/profi.gif) no-repeat; cursor: pointer; display: block; height: 16px; width: 16px; margin: 3px 4px 0 4px; }\n'+
			'</style>');

			editor.addCommand( 'toolbarFocus', commands.toolbarFocus );
			
			editor.addCommand( 'toolbarCollapse',
					{
						exec : function( editor, data )
						{
							var myCollapserId = data || collapserId;
							var collapser = CKEDITOR.document.getById( myCollapserId );
							var toolbox = collapser.getPrevious();
							var toolboxContainer = toolbox.getParent();
							//alert(toolboxContainer.getHtml());
							//var contentHeight = parseInt( contents.$.style.height, 16 );
							//var previousHeight = toolboxContainer.$.offsetHeight;
							//var collapsed = !toolbox.isVisible()
							var newtoolboxname, title;
							var newtoolbox = '';
							
							switch (editor.config.toolbar) {
							    case "Basic": 
								if (!editor.config.toolbar_Full) break;
							    	editor.config.toolbar = 'Full';
							    	collapser.setAttribute( 'title', editor.lang.toolbarExpand );
									newtoolbox = editor.fire("themeSpace", {space:'top',html:''}).html;
							        break;
							    case "Basic_Provis": 
								if (!editor.config.toolbar_Full_Provis) break;
							    	editor.config.toolbar = "Full_Provis";
							    	collapser.setAttribute( 'title', editor.lang.toolbarExpand );
									newtoolbox = editor.fire("themeSpace", {space:'top',html:''}).html;
							        break;
							    case "Full_Provis":
								if (!editor.config.toolbar_Basic_Provis) break;
							    	editor.config.toolbar = "Basic_Provis";
							    	collapser.setAttribute( 'title', editor.lang.toolbarExpand );
									newtoolbox = editor.fire("themeSpace", {space:'top',html:''}).html;
							        break;
							    case "Full": 
								if (!editor.config.toolbar_Basic) break;
							    	editor.config.toolbar = "Basic";
							    	collapser.setAttribute( 'title', editor.lang.toolbarExpand );
									newtoolbox = editor.fire("themeSpace", {space:'top',html:''}).html;
							        break;
							    default: 
							    	newtoolboxname = "Basic";
							    	collapser.setAttribute( 'title', editor.lang.toolbarExpand );
							    	newtoolbox = editor.fire("themeSpace", {space:'top',html:''}).html;
							        break;
							}
							editor.getThemeSpace('top').setHtml(newtoolbox);

						},

						modes : { wysiwyg : 1, source : 1 }
					} );
			
			
		}
	});
})();

CKEDITOR.UI_SEPARATOR = 'separator';

/**
 * The "theme space" to which rendering the toolbar. For the default theme,
 * the recommended options are "top" and "bottom".
 * @type String
 * @default 'top'
 * @see CKEDITOR.config.theme
 * @example
 * config.toolbarLocation = 'bottom';
 */
CKEDITOR.config.toolbarLocation = 'top';

/**
 * The toolbar definition. It is an array of toolbars (strips),
 * each one being also an array, containing a list of UI items.
 * Note that this setting is composed by "toolbar_" added by the toolbar name,
 * which in this case is called "Basic". This second part of the setting name
 * can be anything. You must use this name in the
 * {@link CKEDITOR.config.toolbar} setting, so you instruct the editor which
 * toolbar_(name) setting to you.
 * @type Array
 * @example
 * // Defines a toolbar with only one strip containing the "Source" button, a
 * // separator and the "Bold" and "Italic" buttons.
 * <b>config.toolbar_Basic =
 * [
 *     [ 'Source', '-', 'Bold', 'Italic' ]
 * ]</b>;
 * config.toolbar = 'Basic';
 */
CKEDITOR.config.toolbar_Basic =
[
	['Bold', 'Italic', '-', 'NumberedList', 'BulletedList', '-', 'Link', 'Unlink','-','About']
];

/**
 * This is the default toolbar definition used by the editor. It contains all
 * editor features.
 * @type Array
 * @default (see example)
 * @example
 * // This is actually the default value.
 * config.toolbar_Full =
 * [
 *     { name: 'document',    items : [ 'Source','-','Save','NewPage','DocProps','Preview','Print','-','Templates' ] },
 *     { name: 'clipboard',   items : [ 'Cut','Copy','Paste','PasteText','PasteFromWord','-','Undo','Redo' ] },
 *     { name: 'editing',     items : [ 'Find','Replace','-','SelectAll','-','SpellChecker', 'Scayt' ] },
 *     { name: 'forms',       items : [ 'Form', 'Checkbox', 'Radio', 'TextField', 'Textarea', 'Select', 'Button', 'ImageButton', 'HiddenField' ] },
 *     '/',
 *     { name: 'basicstyles', items : [ 'Bold','Italic','Underline','Strike','Subscript','Superscript','-','RemoveFormat' ] },
 *     { name: 'paragraph',   items : [ 'NumberedList','BulletedList','-','Outdent','Indent','-','Blockquote','CreateDiv','-','JustifyLeft','JustifyCenter','JustifyRight','JustifyBlock','-','BidiLtr','BidiRtl' ] },
 *     { name: 'links',       items : [ 'Link','Unlink','Anchor' ] },
 *     { name: 'insert',      items : [ 'Image','Flash','Table','HorizontalRule','Smiley','SpecialChar','PageBreak' ] },
 *     '/',
 *     { name: 'styles',      items : [ 'Styles','Format','Font','FontSize' ] },
 *     { name: 'colors',      items : [ 'TextColor','BGColor' ] },
 *     { name: 'tools',       items : [ 'Maximize', 'ShowBlocks','-','About' ] }
 * ];
 */
CKEDITOR.config.toolbar_Full =
[
	{ name: 'document',		items : [ 'Source','-','Save','NewPage','DocProps','Preview','Print','-','Templates' ] },
	{ name: 'clipboard',	items : [ 'Cut','Copy','Paste','PasteText','PasteFromWord','-','Undo','Redo' ] },
	{ name: 'editing',		items : [ 'Find','Replace','-','SelectAll','-','SpellChecker', 'Scayt' ] },
	{ name: 'forms',		items : [ 'Form', 'Checkbox', 'Radio', 'TextField', 'Textarea', 'Select', 'Button', 'ImageButton', 'HiddenField' ] },
	'/',
	{ name: 'basicstyles',	items : [ 'Bold','Italic','Underline','Strike','Subscript','Superscript','-','RemoveFormat' ] },
	{ name: 'paragraph',	items : [ 'NumberedList','BulletedList','-','Outdent','Indent','-','Blockquote','CreateDiv','-','JustifyLeft','JustifyCenter','JustifyRight','JustifyBlock','-','BidiLtr','BidiRtl' ] },
	{ name: 'links',		items : [ 'Link','Unlink','Anchor' ] },
	{ name: 'insert',		items : [ 'Image','Flash','Table','HorizontalRule','Smiley','SpecialChar','PageBreak','Iframe' ] },
	'/',
	{ name: 'styles',		items : [ 'Styles','Format','Font','FontSize' ] },
	{ name: 'colors',		items : [ 'TextColor','BGColor' ] },
	{ name: 'tools',		items : [ 'Maximize', 'ShowBlocks','-','About' ] }
];

/**
 * The toolbox (alias toolbar) definition. It is a toolbar name or an array of
 * toolbars (strips), each one being also an array, containing a list of UI items.
 * @type Array|String
 * @default 'Full'
 * @example
 * // Defines a toolbar with only one strip containing the "Source" button, a
 * // separator and the "Bold" and "Italic" buttons.
 * config.toolbar =
 * [
 *     [ 'Source', '-', 'Bold', 'Italic' ]
 * ];
 * @example
 * // Load toolbar_Name where Name = Basic.
 * config.toolbar = 'Basic';
 */
CKEDITOR.config.toolbar = 'Full';

/**
 * Whether the toolbar can be collapsed by the user. If disabled, the collapser
 * button will not be displayed.
 * @type Boolean
 * @default true
 * @example
 * config.toolbarCanCollapse = false;
 */
CKEDITOR.config.toolbarCanCollapse = true;

/**
 * Whether the toolbar must start expanded when the editor is loaded.
 * @name CKEDITOR.config.toolbarStartupExpanded
 * @type Boolean
 * @default true
 * @example
 * config.toolbarStartupExpanded = false;
 */

/**
 * When enabled, makes the arrow keys navigation cycle within the current
 * toolbar group. Otherwise the arrows will move trought all items available in
 * the toolbar. The TAB key will still be used to quickly jump among the
 * toolbar groups.
 * @name CKEDITOR.config.toolbarGroupCycling
 * @since 3.6
 * @type Boolean
 * @default true
 * @example
 * config.toolbarGroupCycling = false;
 */
