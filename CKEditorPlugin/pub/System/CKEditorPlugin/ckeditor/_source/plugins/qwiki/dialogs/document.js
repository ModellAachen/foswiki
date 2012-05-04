/*
Copyright (c) 2003-2010, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

CKEDITOR.dialog.add( 'document', function( editor )
{
	// Loads the parameters in a selected link to the link dialog fields.
	var urlRegex = /^((?:http|https|ftp|news):\/\/)?(.*)$/;

	var parseLink = function( editor, element )
	{
		var href = element ? ( element.getAttribute( 'data-cke-saved-href' ) || element.getAttribute( 'href' ) ) : '',
			urlMatch,
			retval = {};

		// urlRegex matches empty strings, so need to check for href as well.
		if (  href && ( urlMatch = href.match( urlRegex ) ) )
		{
			retval.type = 'url';
			retval.url = {};
			retval.url.protocol = urlMatch[1];
			retval.url.url = urlMatch[2];
		}
		else
			retval.type = 'url';

		// Record down the selected element in the dialog.
		this._.selectedElement = element;

		return retval;
	};

	var setupParams = function( page, data )
	{
		if ( data[page] )
			this.setValue( data[page][this.id] || '' );
	};

	var commitParams = function( page, data )
	{
		if ( !data[page] )
			data[page] = {};

		data[page][this.id] = this.getValue() || '';
	};

	return {
		title : editor.lang.qwikidocument.title,
		minWidth : 350,
		minHeight : 230,
		contents : [
			{
				id : 'info',
				label : editor.lang.qwikidocument.info,
				title : editor.lang.qwikidocument.info,
				elements :
				[
					{
						type : 'vbox',
						id : 'urlOptions',
						children :
						[
							{
								type : 'hbox',
								widths : [ '100%' ],
								children :
								[
									{
										type : 'text',
										id : 'url',
										label : editor.lang.qwikidocument.toUrl,
										required: true,
										onKeyDown : function()
										{
											// IE7 doesn't like doing this during onLoad
											if (!this.qwikiautosuggest) return;
											this.qwikiautosuggest("init", {source: CKEDITOR.qwikiautosuggest.attachments, minLength: 2});
											this.qwikiautosuggest = false;
										},
										validate : function()
										{
											var dialog = this.getDialog();

											var func = CKEDITOR.dialog.validate.notEmpty( editor.lang.qwikidocument.noUrl );
											return func.apply( this );
										},
										setup : function( data )
										{
											if ( data.url )
												this.setValue( data.url.url );

										},
										commit : function( data )
										{
											if ( !data.url )
												data.url = {};

											data.url.url = this.getValue();
										}
									}
								],
								setup : function( data )
								{
									if ( !this.getDialog().getContentElement( 'info', 'linkType' ) )
										this.getElement().show();
								}
							},
							{
								type : 'button',
								id : 'browse',
								hidden : 'true',
								filebrowser : 'info:url',
								label : editor.lang.common.browseServer
							}
						]
					}
				]
			},
			{
				id : 'upload',
				hidden : true,
				ckefilebrowser : 'uploadButton',
				label : editor.lang.image.upload,
				elements :
				[
					{
						type : 'file',
						id : 'filepath',
						label : editor.lang.qwikidocument.fileBrowser,
						style: 'height:40px',
						size : 26,
						onChange : function()
						{
							// Modac : Hier sollte eine onChange Funktionalität hin
						}
					},
					{
						type : 'text',
						id : 'filename',
						label : editor.lang.qwikidocument.fileName,
						style : 'width: 60%',
						size : 20,
						onFocus : function()
						{
							if (!this.getValue())
							{
								dialog = this.getDialog()
								var fname = dialog.getContentElement('upload', 'filepath').getInputElement().getValue();
								// We're not terribly interested in Windows paths
								fname = fname.replace(/^.:\\(.+)\\/, '');
								this.setValue(fname);
							}
						}
					},
					{
						type : 'select',
						hidden : 'true',
						id : 'uploadtarget',
						label : editor.lang.qwikidocument.uploadOptions,
						'default' : 'local',
						items :
							[
								[ 'Attach to this topic' , 'local']
							]
					},
					{
						type : 'fileButton',
						id : 'uploadButton',
						label : editor.lang.common.uploadSubmit,
						ckefilebrowser : 
							{
						 		action : 'UploadPOST', //required
						 		target : 'info:url', //required
						 		url : FoswikiCKE.getFoswikiVar("SCRIPTURL") + '/rest/WysiwygPlugin/upload'
						 	},
						'for' : [ 'upload', 'filepath']
					}
				],
				setup : function()
				{
					//alert("muuusso");
				}
			}
		],
		onShow : function()
		{
			var editor = this.getParentEditor(),
				selection = editor.getSelection(),
				ranges = selection.getRanges(),
				element = null,
				me = this;
			// Fill in all the relevant fields if there's already one link selected.
			if ( ranges.length == 1 )
			{

				var rangeRoot = ranges[0].getCommonAncestor( true );
				element = rangeRoot.getAscendant( 'a', true );
				if ( element && element.getAttribute( 'href' ) )
				{
					selection.selectElement( element );
				}
				else
					element = null;
			}

			this.setupContent( parseLink.apply( this, [ editor, element ] ) );

		},
		onOk : function()
		{
			var attributes = { href : 'javascript:void(0)/*' + CKEDITOR.tools.getNextNumber() + '*/' },
				data = { href : attributes.href },
				editor = this.getParentEditor();

			this.commitContent( data );

			// Compose the URL.
			var protocol = ( data.url && data.url.protocol != undefined ) ? data.url.protocol : 'http://',
				url = ( data.url && data.url.url ) || '';
			attributes['data-cke-saved-href'] = ( url.indexOf( '/' ) === 0 ) ? url : protocol + url;

			if ( !this._.selectedElement )
			{
				// Create element if current selection is collapsed.
				var selection = editor.getSelection(),
					ranges = selection.getRanges();
				if ( ranges.length == 1 && ranges[0].collapsed )
				{
					var text = new CKEDITOR.dom.text( attributes['data-cke-saved-href'], editor.document );
					ranges[0].insertNode( text );
					ranges[0].selectNodeContents( text );
					selection.selectRanges( ranges );
				}

				// Apply style.
				var style = new CKEDITOR.style( { element : 'a', attributes : attributes } );
				style.type = CKEDITOR.STYLE_INLINE;		// need to override... dunno why.
				style.apply( editor.document );
			}
			else
			{
				// We're only editing an existing link, so just overwrite the attributes.
				var element = this._.selectedElement,
					href = element.getAttribute( 'data-cke-saved-href' ),
					textView = element.getHtml();

				element.setAttributes( attributes );
				// Update text view when user changes protocol #4612.
				if (href == textView)
					element.setHtml( attributes['data-cke-saved-href'] );

				delete this._.selectedElement;
			}
		},
		onLoad : function()
		{
			this.on('selectPage', function(e) {
				if (e.data.page == 'info') {
					this.enableButton('ok');
					$(this.getButton('ok').getElement().$).show();
				} else {
					this.disableButton('ok');
					$(this.getButton('ok').getElement().$).hide();
				}

			});
		},
		// Inital focus on 'url' field if link is of type URL.
		onFocus : function()
		{
			this.getContentElement( 'info', 'url' ).select();
		}
	};
});

