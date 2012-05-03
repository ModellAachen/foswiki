/*
Copyright (c) 2003-2010, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

/**
 * @fileOverview The "ckefilebrowser" plugin, it adds support for file uploads and
 *               browsing.
 *
 * When file is selected inside of the file browser or uploaded, its url is
 * inserted automatically to a field, which is described in the 'ckefilebrowser'
 * attribute. To specify field that should be updated, pass the tab id and
 * element id, separated with a colon.
 *
 * Example 1: (Browse)
 *
 * <pre>
 * {
 * 	type : 'button',
 * 	id : 'browse',
 * 	ckefilebrowser : 'tabId:elementId',
 * 	label : editor.lang.common.browseServer
 * }
 * </pre>
 *
 * If you set the 'ckefilebrowser' attribute on any element other than
 * 'fileButton', the 'Browse' action will be triggered.
 *
 * Example 2: (Quick Upload)
 *
 * <pre>
 * {
 * 	type : 'fileButton',
 * 	id : 'uploadButton',
 * 	ckefilebrowser : 'tabId:elementId',
 * 	label : editor.lang.common.uploadSubmit,
 * 	'for' : [ 'upload', 'upload' ]
 * }
 * </pre>
 *
 * If you set the 'ckefilebrowser' attribute on a fileButton element, the
 * 'QuickUpload' action will be executed.
 *
 * ckefilebrowser plugin also supports more advanced configuration (through
 * javascript object).
 *
 * The following settings are supported:
 *
 * <pre>
 *  [action] - Browse or QuickUpload
 *  [target] - field to update, tabId:elementId
 *  [params] - additional arguments to be passed to the server connector (optional)
 *  [onSelect] - function to execute when file is selected/uploaded (optional)
 *  [url] - the URL to be called (optional)
 * </pre>
 *
 * Example 3: (Quick Upload)
 *
 * <pre>
 * {
 * 	type : 'fileButton',
 * 	label : editor.lang.common.uploadSubmit,
 * 	id : 'buttonId',
 * 	ckefilebrowser :
 * 	{
 * 		action : 'QuickUpload', //required
 * 		target : 'tab1:elementId', //required
 * 		params : //optional
 * 		{
 * 			type : 'Files',
 * 			currentFolder : '/folder/'
 * 		},
 * 		onSelect : function( fileUrl, errorMessage ) //optional
 * 		{
 * 			// Do not call the built-in selectFuntion
 * 			// return false;
 * 		}
 * 	},
 * 	'for' : [ 'tab1', 'myFile' ]
 * }
 * </pre>
 *
 * Suppose we have a file element with id 'myFile', text field with id
 * 'elementId' and a fileButton. If filebowser.url is not specified explicitly,
 * form action will be set to 'ckefilebrowser[DialogName]UploadUrl' or, if not
 * specified, to 'ckefilebrowserUploadUrl'. Additional parameters from 'params'
 * object will be added to the query string. It is possible to create your own
 * uploadHandler and cancel the built-in updateTargetElement command.
 *
 * Example 4: (Browse)
 *
 * <pre>
 * {
 * 	type : 'button',
 * 	id : 'buttonId',
 * 	label : editor.lang.common.browseServer,
 * 	ckefilebrowser :
 * 	{
 * 		action : 'Browse',
 * 		url : '/ckfinder/ckfinder.html&amp;type=Images',
 * 		target : 'tab1:elementId'
 * 	}
 * }
 * </pre>
 *
 * In this example, after pressing a button, file browser will be opened in a
 * popup. If we don't specify ckefilebrowser.url attribute,
 * 'ckefilebrowser[DialogName]BrowseUrl' or 'ckefilebrowserBrowseUrl' will be used.
 * After selecting a file in a file browser, an element with id 'elementId' will
 * be updated. Just like in the third example, a custom 'onSelect' function may be
 * defined.
 */
( function()
{
	/**
	 * Adds (additional) arguments to given url.
	 *
	 * @param {String}
	 *            url The url.
	 * @param {Object}
	 *            params Additional parameters.
	 */
	function uploadPost( evt )
	{
		var dialog = this.getDialog();
		var editor = dialog.getParentEditor();
		
		editor._.ckefilebrowserSe = this;

		// If user didn't select the file, stop the upload.
		if ( !dialog.getContentElement( this[ 'for' ][ 0 ], this[ 'for' ][ 1 ] ).getInputElement().$.value )
			return false;

		if ( !dialog.getContentElement( this[ 'for' ][ 0 ], this[ 'for' ][ 1 ] ).getAction() )
			return false;

		
		var el_input = dialog.getContentElement( this[ 'for' ][ 0 ], this[ 'for' ][ 1 ] ).getInputElement();
		var el_form = el_input.getParent();

	    //Parameter auslesen und in Formular übergeben
	    var params = this.ckefilebrowser.params;
	    
	    //Parameter mit den Auswahlelementen erweitern
	    params.filename = dialog.getContentElement( this[ 'for' ][ 0 ], 'filename' ).getInputElement().$.value;
	    
	    //Web und Topic auslesen
	    if (dialog.getContentElement( this[ 'for' ][ 0 ], 'uploadtarget' ).getInputElement().$.value == 'local')
	    {
	    	params.topic = utf8_decode(FoswikiCKE.getTopicPath());
	    	
	    }
	    else
	    {
	    	params.topic = "Main.WebAttachments";
	    }
	    
	    for ( var i in params )
	    {
	    	var el = new CKEDITOR.dom.element( 'input' );

			el.setAttribute('type', 'text');
			el.setAttribute('name', i);
			el.setAttribute('value', params[i]); 
	    	
			el.insertAfter(el_input);
			//Neues Element anhängen
			//el_form.append(el);
	    }
	    return true;
	}
	
	function utf8_decode (utftext) {
		var string = "";
		var i = 0;
		var c = c1 = c2 = 0;
 
		while ( i < utftext.length ) {
 
			c = utftext.charCodeAt(i);
 
			if (c < 128) {
				string += String.fromCharCode(c);
				i++;
			}
			else if((c > 191) && (c < 224)) {
				c2 = utftext.charCodeAt(i+1);
				string += String.fromCharCode(((c & 31) << 6) | (c2 & 63));
				i += 2;
			}
			else {
				c2 = utftext.charCodeAt(i+1);
				c3 = utftext.charCodeAt(i+2);
				string += String.fromCharCode(((c & 15) << 12) | ((c2 & 63) << 6) | (c3 & 63));
				i += 3;
			}
 
		}
 
		return string;
	}
	
	
	/**
	 * Adds (additional) arguments to given url.
	 *
	 * @param {String}
	 *            url The url.
	 * @param {Object}
	 *            params Additional parameters.
	 */
	function addQueryString( url, params )
	{
		var queryString = [];

		if ( !params )
			return url;
		else
		{
			for ( var i in params )
				queryString.push( i + "=" + encodeURIComponent( params[ i ] ) );
		}

		return url + ( ( url.indexOf( "?" ) != -1 ) ? "&" : "?" ) + queryString.join( "&" );
	}

	/**
	 * Make a string's first character uppercase.
	 *
	 * @param {String}
	 *            str String.
	 */
	function ucFirst( str )
	{
		str += '';
		var f = str.charAt( 0 ).toUpperCase();
		return f + str.substr( 1 );
	}

	/**
	 * The onlick function assigned to the 'Browse Server' button. Opens the
	 * file browser and updates target field when file is selected.
	 *
	 * @param {CKEDITOR.event}
	 *            evt The event object.
	 */
	function browseServer( evt )
	{
		var dialog = this.getDialog();
		var editor = dialog.getParentEditor();

		editor._.ckefilebrowserSe = this;

		var width = editor.config[ 'ckefilebrowser' + ucFirst( dialog.getName() ) + 'WindowWidth' ]
				|| editor.config.ckefilebrowserWindowWidth || '80%';
		var height = editor.config[ 'ckefilebrowser' + ucFirst( dialog.getName() ) + 'WindowHeight' ]
				|| editor.config.ckefilebrowserWindowHeight || '70%';

		var params = this.ckefilebrowser.params;
		params.CKEditor = editor.name;
		params.CKEditorFuncNum = editor._.ckefilebrowserFn;
		if ( !params.langCode )
			params.langCode = editor.langCode;

		var url = addQueryString( this.ckefilebrowser.url, params );
		editor.popup( url, width, height );
	}

	/**
	 * The onlick function assigned to the 'Upload' button. Makes the final
	 * decision whether form is really submitted and updates target field when
	 * file is uploaded.
	 *
	 * @param {CKEDITOR.event}
	 *            evt The event object.
	 */
	function uploadFile( evt )
	{
		var dialog = this.getDialog();
		var editor = dialog.getParentEditor();

		editor._.ckefilebrowserSe = this;

		// If user didn't select the file, stop the upload.
		if ( !dialog.getContentElement( this[ 'for' ][ 0 ], this[ 'for' ][ 1 ] ).getInputElement().$.value )
			return false;

		if ( !dialog.getContentElement( this[ 'for' ][ 0 ], this[ 'for' ][ 1 ] ).getAction() )
			return false;

		return true;
	}

	/**
	 * Setups the file element.
	 *
	 * @param {CKEDITOR.ui.dialog.file}
	 *            fileInput The file element used during file upload.
	 * @param {Object}
	 *            ckefilebrowser Object containing ckefilebrowser settings assigned to
	 *            the fileButton associated with this file element.
	 */
	function setupFileElement( editor, fileInput, ckefilebrowser )
	{
		var params = ckefilebrowser.params;
		params.CKEditor = editor.name;
		params.CKEditorFuncNum = editor._.ckefilebrowserFn;
		if ( !params.langCode )
			params.langCode = editor.langCode;

		fileInput.action = addQueryString( ckefilebrowser.url, params );
		fileInput.ckefilebrowser = ckefilebrowser;
	}
	
	/**
	 * Setups the file element.
	 *
	 * @param {CKEDITOR.ui.dialog.file}
	 *            fileInput The file element used during file upload.
	 * @param {Object}
	 *            ckefilebrowser Object containing ckefilebrowser settings assigned to
	 *            the fileButton associated with this file element.
	 */
	function setupPostFileElement( editor, fileInput, ckefilebrowser )
	{
		var params = ckefilebrowser.params;
		params.CKEditor = editor.name;
		params.CKEditorFuncNum = editor._.ckefilebrowserFn;
		if ( !params.langCode )
			params.langCode = editor.langCode;

		fileInput.ckefilebrowser = ckefilebrowser;
		fileInput.action = ckefilebrowser.url;
	}

	/**
	 * Traverse through the content definition and attach ckefilebrowser to
	 * elements with 'ckefilebrowser' attribute.
	 *
	 * @param String
	 *            dialogName Dialog name.
	 * @param {CKEDITOR.dialog.dialogDefinitionObject}
	 *            definition Dialog definition.
	 * @param {Array}
	 *            elements Array of {@link CKEDITOR.dialog.contentDefinition}
	 *            objects.
	 */
	function attachckefilebrowser( editor, dialogName, definition, elements )
	{
		var element, fileInput;

		for ( var i in elements )
		{
			element = elements[ i ];

			if ( element.type == 'hbox' || element.type == 'vbox' )
				attachckefilebrowser( editor, dialogName, definition, element.children );

			if ( !element.ckefilebrowser )
				continue;

			if ( element.ckefilebrowser.params === undefined )
				element.ckefilebrowser.params = {};

			if ( typeof element.ckefilebrowser == 'string' )
			{
				var fb =
				{
					action : ( element.type == 'fileButton' ) ? 'QuickUpload' : 'Browse',
					target : element.ckefilebrowser
				};
				element.ckefilebrowser = fb;
			}
			if ( element.ckefilebrowser.action == 'Browse' )
			{
				var url = element.ckefilebrowser.url || editor.config[ 'ckefilebrowser' + ucFirst( dialogName ) + 'BrowseUrl' ]
							|| editor.config.ckefilebrowserBrowseUrl;

				if ( url )
				{
					element.onClick = browseServer;
					element.ckefilebrowser.url = url;
					element.hidden = false;
				}
			}
			else if ( element.ckefilebrowser.action == 'QuickUpload' && element[ 'for' ] )
			{
				
				url =  element.ckefilebrowser.url || editor.config[ 'ckefilebrowser' + ucFirst( dialogName ) + 'UploadUrl' ]
							|| editor.config.ckefilebrowserUploadUrl;

				if ( url )
				{
					var onClick = element.onClick;
					element.onClick = function( evt )
					{
						// "element" here means the definition object, so we need to find the correct
						// button to scope the event call
						var sender = evt.sender;
						if ( onClick && onClick.call( sender, evt ) === false )
							return false;

						return uploadFile.call( sender, evt );
					};

					element.ckefilebrowser.url = url;
					element.hidden = false;
					setupFileElement( editor, definition.getContents( element[ 'for' ][ 0 ] ).get( element[ 'for' ][ 1 ] ), element.ckefilebrowser );
				}
			}
			else if ( element.ckefilebrowser.action == 'UploadPOST' && element[ 'for' ] )
			{
				
				
				url =  element.ckefilebrowser.url || editor.config[ 'ckefilebrowser' + ucFirst( dialogName ) + 'UploadUrl' ]
							|| editor.config.ckefilebrowserUploadUrl;

				if ( url )
				{
					var onClick = element.onClick;
					element.onClick = function( evt )
					{
						// "element" here means the definition object, so we need to find the correct
						// button to scope the event call
						var sender = evt.sender;
						if ( onClick && onClick.call( sender, evt ) === false )
							return false;

						return uploadPost.call( sender, evt );
					};

					element.ckefilebrowser.url = url;
					element.hidden = false;
					setupPostFileElement( editor, definition.getContents( element[ 'for' ][ 0 ] ).get( element[ 'for' ][ 1 ] ), element.ckefilebrowser );
				}
			}
		}
	}

	/**
	 * Updates the target element with the url of uploaded/selected file.
	 *
	 * @param {String}
	 *            url The url of a file.
	 */
	function updateTargetElement( url, sourceElement )
	{
		var dialog = sourceElement.getDialog();
		var targetElement = sourceElement.ckefilebrowser.target || null;
		url = url.replace( /#/g, '%23' );

		// If there is a reference to targetElement, update it.
		if ( targetElement )
		{
			var target = targetElement.split( ':' );
			var element = dialog.getContentElement( target[ 0 ], target[ 1 ] );
			if ( element )
			{
				element.setValue( url );
				dialog.selectPage( target[ 0 ] );
			}
		}
	}

	/**
	 * Returns true if ckefilebrowser is configured in one of the elements.
	 *
	 * @param {CKEDITOR.dialog.dialogDefinitionObject}
	 *            definition Dialog definition.
	 * @param String
	 *            tabId The tab id where element(s) can be found.
	 * @param String
	 *            elementId The element id (or ids, separated with a semicolon) to check.
	 */
	function isConfigured( definition, tabId, elementId )
	{
		if ( elementId.indexOf( ";" ) !== -1 )
		{
			var ids = elementId.split( ";" );
			for ( var i = 0 ; i < ids.length ; i++ )
			{
				if ( isConfigured( definition, tabId, ids[i]) )
					return true;
			}
			return false;
		}

		var elementckefilebrowser = definition.getContents( tabId ).get( elementId ).ckefilebrowser;
		return ( elementckefilebrowser && elementckefilebrowser.url );
	}

	function setUrl( fileUrl, data )
	{
		var dialog = this._.ckefilebrowserSe.getDialog(),
			targetInput = this._.ckefilebrowserSe[ 'for' ],
			onSelect = this._.ckefilebrowserSe.ckefilebrowser.onSelect;

		if ( targetInput )
			dialog.getContentElement( targetInput[ 0 ], targetInput[ 1 ] ).reset();

		if ( typeof data == 'function' && data.call( this._.ckefilebrowserSe ) === false )
			return;

		if ( onSelect && onSelect.call( this._.ckefilebrowserSe, fileUrl, data ) === false )
			return;

		// The "data" argument may be used to pass the error message to the editor.
		if ( typeof data == 'string' && data )
			alert( data );

		
		if ( fileUrl )
			updateTargetElement( fileUrl, this._.ckefilebrowserSe );
	}

	CKEDITOR.plugins.add( 'qwikifilebrowser',
	{
		init : function( editor, pluginPath )
		{
			editor._.ckefilebrowserFn = CKEDITOR.tools.addFunction( setUrl, editor );

			CKEDITOR.on( 'dialogDefinition', function( evt )
			{
				var definition = evt.data.definition,
					element;
				// Associate ckefilebrowser to elements with 'ckefilebrowser' attribute.
				for ( var i in definition.contents )
				{
					element = definition.contents[ i ] ;
					attachckefilebrowser( evt.editor, evt.data.name, definition, element.elements );
					if ( element.hidden && element.ckefilebrowser )
					{
						element.hidden = !isConfigured( definition, element[ 'id' ], element.ckefilebrowser );
					}
				}
			} );
		}
	} );

} )();

/**
 * The location of an external file browser, that should be launched when "Browse Server" button is pressed.
 * If configured, the "Browse Server" button will appear in Link, Image and Flash dialogs.
 * @see The <a href="http://docs.cksource.com/CKEditor_3.x/Developers_Guide/File_Browser_(Uploader)">File Browser/Uploader</a> documentation.
 * @name CKEDITOR.config.ckefilebrowserBrowseUrl
 * @since 3.0
 * @type String
 * @default '' (empty string = disabled)
 * @example
 * config.ckefilebrowserBrowseUrl = '/browser/browse.php';
 */

/**
 * The location of a script that handles file uploads.
 * If set, the "Upload" tab will appear in "Link", "Image" and "Flash" dialogs.
 * @name CKEDITOR.config.ckefilebrowserUploadUrl
 * @see The <a href="http://docs.cksource.com/CKEditor_3.x/Developers_Guide/File_Browser_(Uploader)">File Browser/Uploader</a> documentation.
 * @since 3.0
 * @type String
 * @default '' (empty string = disabled)
 * @example
 * config.ckefilebrowserUploadUrl = '/uploader/upload.php';
 */

/**
 * The location of an external file browser, that should be launched when "Browse Server" button is pressed in the Image dialog.
 * If not set, CKEditor will use {@link CKEDITOR.config.ckefilebrowserBrowseUrl}.
 * @name CKEDITOR.config.ckefilebrowserImageBrowseUrl
 * @since 3.0
 * @type String
 * @default '' (empty string = disabled)
 * @example
 * config.ckefilebrowserImageBrowseUrl = '/browser/browse.php?type=Images';
 */

/**
 * The location of an external file browser, that should be launched when "Browse Server" button is pressed in the Flash dialog.
 * If not set, CKEditor will use {@link CKEDITOR.config.ckefilebrowserBrowseUrl}.
 * @name CKEDITOR.config.ckefilebrowserFlashBrowseUrl
 * @since 3.0
 * @type String
 * @default '' (empty string = disabled)
 * @example
 * config.ckefilebrowserFlashBrowseUrl = '/browser/browse.php?type=Flash';
 */

/**
 * The location of a script that handles file uploads in the Image dialog.
 * If not set, CKEditor will use {@link CKEDITOR.config.ckefilebrowserUploadUrl}.
 * @name CKEDITOR.config.ckefilebrowserImageUploadUrl
 * @since 3.0
 * @type String
 * @default '' (empty string = disabled)
 * @example
 * config.ckefilebrowserImageUploadUrl = '/uploader/upload.php?type=Images';
 */

/**
 * The location of a script that handles file uploads in the Flash dialog.
 * If not set, CKEditor will use {@link CKEDITOR.config.ckefilebrowserUploadUrl}.
 * @name CKEDITOR.config.ckefilebrowserFlashUploadUrl
 * @since 3.0
 * @type String
 * @default '' (empty string = disabled)
 * @example
 * config.ckefilebrowserFlashUploadUrl = '/uploader/upload.php?type=Flash';
 */

/**
 * The location of an external file browser, that should be launched when "Browse Server" button is pressed in the Link tab of Image dialog.
 * If not set, CKEditor will use {@link CKEDITOR.config.ckefilebrowserBrowseUrl}.
 * @name CKEDITOR.config.ckefilebrowserImageBrowseLinkUrl
 * @since 3.2
 * @type String
 * @default '' (empty string = disabled)
 * @example
 * config.ckeckeckefilebrowserImageBrowseLinkUrl = '/browser/browse.php';
 */
