﻿/*
Copyright (C) 2012, Modell Aachen UG
Based on the original CKEditor plugin "smiley"; original credits follow

Copyright (c) 2003-2012, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

CKEDITOR.plugins.add( 'qwikisymbol',
{
	requires : [ 'dialog' ],
	lang : [ 'de', 'en' ],

	init : function( editor )
	{
		editor.config.symbol_path = editor.config.symbol_path || ( this.path + 'images/' );
		editor.addCommand( 'qwikisymbol', new CKEDITOR.dialogCommand( 'qwikisymbol' ) );
		editor.ui.addButton( 'QWikiSymbol',
			{
				label : editor.lang.qwikisymbol.toolbar,
				command : 'qwikisymbol',
				icon : this.path + 'images/toolbar.png'
			});
		CKEDITOR.dialog.add( 'qwikisymbol', this.path + 'dialogs/qwikisymbol.js' );
	}
} );

/**
 * The base path used to build the URL for the symbol images. It must end with
 * a slash.
 * @name CKEDITOR.config.qwikisymbol_path
 * @type String
 * @default <code><em>CKEDITOR.basePath</em> + 'plugins/qwikisymbol/images/'</code>
 * @example
 * config.qwikisymbol_path = 'http://www.example.com/images/smileys/';
 * @example
 * config.qwikisymbol_path = '/images/smileys/';
 */

/**
 * The file names for the smileys to be displayed. These files must be
 * contained inside the URL path defined with the
 * {@link CKEDITOR.config.qwikisymbol_path} setting.
 * @type Array
 * @default (see example)
 * @example
 * // This is actually the default value.
 * config.qwikisymbol_images = [
 *     'regular_smile.gif','sad_smile.gif','wink_smile.gif','teeth_smile.gif','confused_smile.gif','tounge_smile.gif',
 *     'embaressed_smile.gif','omg_smile.gif','whatchutalkingabout_smile.gif','angry_smile.gif','angel_smile.gif','shades_smile.gif',
 *     'devil_smile.gif','cry_smile.gif','lightbulb.gif','thumbs_down.gif','thumbs_up.gif','heart.gif',
 *     'broken_heart.gif','kiss.gif','envelope.gif'];
 */
CKEDITOR.config.qwikisymbol_images = [
	'regular_smile.gif','sad_smile.gif','wink_smile.gif','teeth_smile.gif','confused_smile.gif','tounge_smile.gif',
	'embaressed_smile.gif','omg_smile.gif','whatchutalkingabout_smile.gif','angry_smile.gif','angel_smile.gif','shades_smile.gif',
	'devil_smile.gif','cry_smile.gif','lightbulb.gif','thumbs_down.gif','thumbs_up.gif','heart.gif',
	'broken_heart.gif','kiss.gif','envelope.gif'];

/**
 * The description to be used for each of the symbols defined in the
 * {@link CKEDITOR.config.qwikisymbol_images} setting. Each entry in this array list
 * must match its relative pair in the {@link CKEDITOR.config.qwikisymbol_images}
 * setting.
 * @type Array
 * @default  The textual descriptions of symbols.
 * @example
 * // Default settings.
 * config.qwikisymbol_descriptions =
 *     [
 *         'smiley', 'sad', 'wink', 'laugh', 'frown', 'cheeky', 'blush', 'surprise',
 *         'indecision', 'angry', 'angel', 'cool', 'devil', 'crying', 'enlightened', 'no',
 *         'yes', 'heart', 'broken heart', 'kiss', 'mail'
 *     ];
 * @example
 * // Use textual emoticons as description.
 * config.qwikisymbol_descriptions =
 *     [
 *         ':)', ':(', ';)', ':D', ':/', ':P', ':*)', ':-o',
 *         ':|', '>:(', 'o:)', '8-)', '>:-)', ';(', '', '', '',
 *         '', '', ':-*', ''
 *     ];
 */
CKEDITOR.config.qwikisymbol_descriptions =
	[
		'smiley', 'sad', 'wink', 'laugh', 'frown', 'cheeky', 'blush', 'surprise',
		'indecision', 'angry', 'angel', 'cool', 'devil', 'crying', 'enlightened', 'no',
		'yes', 'heart', 'broken heart', 'kiss', 'mail'
	];

/**
 * Optional links to be automatically inserted for given symbols.
 * This must be an object mapping a symbol's description (from {@link
 * CKEDITOR.config.qwikisymbol_descriptions}) to the wiki page to link to.
 * @type object
 * @example
 * config.qwikisymbol_links =
 *     {
 *         smiley: 'Main.AwesomePage',
 *         sad: 'Main.DepressingPage',
 *         wink: 'http://example.org/'
 *     };
 */
CKEDITOR.config.qwikisymbol_links =
	{
	};

/**
 * The number of columns to be generated by the smilies matrix.
 * @name CKEDITOR.config.qwikisymbol_columns
 * @type Number
 * @default 8
 * @since 3.3.2
 * @example
 * config.qwikisymbol_columns = 6;
 */
