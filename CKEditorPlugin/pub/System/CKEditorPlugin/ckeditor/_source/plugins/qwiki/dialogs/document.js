/*
Copyright (c) 2003-2010, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

CKEDITOR.dialog.add( 'document', function( editor )
{
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
										onLoad : function()
										{
											this.qwikiautosuggest("init", {source: CKEDITOR.qwikiautosuggest.attachments, minLength: 2});
										},
										validate : function()
										{
											var dialog = this.getDialog();

											var func = CKEDITOR.dialog.validate.notEmpty( editor.lang.qwikidocument.noUrl );
											return func.apply( this );
										},
										commit : function( data )
										{
											data.url = this.getValue();
										}
									}
								]
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
							this.getDialog().getContentElement('upload', 'filename').onFocus();
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
								fname = fname.replace(/^.:(.*)\\/, '');
								this.setValue(fname);
							}
						}
					},
					{
						type : 'fileButton',
						id : 'uploadButton',
						label : editor.lang.common.uploadSubmit,
						ckefilebrowser : 
							{
						 		action : 'UploadPOST', //required
						 		target : 'info:url', //required
								params : { relativepath: 1 },
						 		url : FoswikiCKE.getFoswikiVar("SCRIPTURL") + '/rest/WysiwygPlugin/upload'
						 	},
						'for' : [ 'upload', 'filepath']
					}
				]
			}
		],
		onOk : function()
		{
			var attributes = { href : 'javascript:void(0)/*' + CKEDITOR.tools.getNextNumber() + '*/' },
				data = { href : attributes.href },
				editor = this.getParentEditor();

			this.commitContent( data );

			// Compose the URL.
			var url = data.url || '';
			var urlPrefix = (url.match(/\//)) ? '%PUBURL%/' : '%ATTACHURL%/';
			attributes['data-cke-saved-href'] = urlPrefix + url;

			if ( !this._.selectedElement )
			{
				// Create element if current selection is collapsed.
				var selection = editor.getSelection(),
					ranges = selection.getRanges();
				if ( ranges.length == 1 && ranges[0].collapsed )
				{
					var text = new CKEDITOR.dom.text( url, editor.document );
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

