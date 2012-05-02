/*
Copyright (c) 2003-2010, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

CKEDITOR.dialog.add( 'provis', function( editor )
{
	// Function called in onShow to load selected element.
	var loadElements = function( editor, selection, element )
	{
		this.editMode = true;
		this.editObj = element;

		var attributeValue = this.editObj.getHtml();

		// RegExen um Attribute auszulesen
		var ausdruck1 = /\{"([^"]*)"/g;
		var ausdruck2 = /name="([^"]*)"[\s]/g;
		var ausdruck3 = /rev="([^"]*)"/g;
		var ausdruck4 = /type="([^"]*)"/g;
		var name = '';
		var rev, type;
		
		if (ausdruck1.test(attributeValue))
		{
			ausdruck1.exec(attributeValue);
			name = RegExp.$1;
		}
		else if (ausdruck2.test(attributeValue))
		{
			ausdruck2.exec(attributeValue);
			name = RegExp.$1;
		}	
		
		if (ausdruck3.test(attributeValue))
		{
			ausdruck3.exec(attributeValue);
			rev = RegExp.$1 || 1;
		}

		if (ausdruck4.test(attributeValue))
		{
			ausdruck4.exec(attributeValue);
			type = RegExp.$1 || 1;
		}

		var retval = {};
		
		retval.name = name;
		retval.rev = rev;
		retval.type = type;
		
		
		if ( name )
			this.setValueOf( 'info','name', name );
		else
			this.setValueOf( 'info','name', '' );
		
		return retval;
	};
	
	// Modac : Was geht hier?
	var parseProvis = function( editor,  element )
	{
		if (element)
		{
			var attributeValue = element.getHtml();

			// Modac : ProVis Flowchart per regulärem Ausdruck auslesen
			var ausdruck1 = /\{"([^"]*)"/g;
			var ausdruck2 = /name="([^"]*)"[\s]/g;
			var ausdruck3 = /rev="([^"]*)"/g;
			var ausdruck4 = /type="([^"]*)"/g;
			var name = '';
			var rev, type;
			
			if (ausdruck1.test(attributeValue))
			{
				ausdruck1.exec(attributeValue);
				name = RegExp.$1;
			}
			else if (ausdruck2.test(attributeValue))
			{
				ausdruck2.exec(attributeValue);
				name = RegExp.$1;
			}	
			
			if (ausdruck3.test(attributeValue))
			{
				ausdruck3.exec(attributeValue);
				rev = RegExp.$1 || 0;
			}
	
			if (ausdruck4.test(attributeValue))
			{
				ausdruck4.exec(attributeValue);
				type = RegExp.$1 || 1;
			}
		}

		var retval = {};
		
		retval.name = name || "Process1";
		retval.rev = rev || 1;
		retval.type = type || "swimlane";
		
		return retval;
	};
	
	// Modac : Fake Element im CKEditor erstellen
	var createFakeElement = function( editor, realElement )
	{
		var fakeElement = editor.createFakeParserElement( realElement, 'cke_provis', 'provis', true ),
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
	
	var removeSpace = function( str )
	{
		return str.replace( /[\s]/g, '' );
	};

	// Modac : Rendern vom Dialog
	return {
		title : editor.lang.qwikiflowchart.title,
		minWidth : 350,
		minHeight : 230,
		contents : [
			{
				id : 'info',
				label : editor.lang.qwikiflowchart.info,
				title : editor.lang.qwikiflowchart.info,
				elements :
				[
					{
						type : 'hbox',
						id : 'urlOptions',
						widths : [ '64%', '33%' ],
						children :
						[
							{
								type : 'vbox',
								children :
								[
									{
										id : 'flowchartType',
										type : 'select',
										label : editor.lang.qwikiflowchart.type,
										'default' : 'swimlanes',
										items :
										[
											[ editor.lang.qwikiflowchart.swimlane, 'Swimlane' ],
											[ editor.lang.qwikiflowchart.process1, 'Flex' ],
											[ editor.lang.qwikiflowchart.organigram, 'Orglane' ]
										],
										setup : function( data )
										{
											if ( data.type )
												this.setValue( data.type );
										},
										onChange : function()
										{
											var wert = this.getValue();
											var previewImage = document.getElementById("previewImage2");
											
											switch (wert) {
											  case "Swimlane":
												previewImage.setAttribute( 'src', CKEDITOR.plugins.getPath( 'qwiki' ) + 'images/03_schwimmbahn.gif' );
											    //data.type = "swimlane";
												break;
											  case "Flex":
												previewImage.setAttribute( 'src', CKEDITOR.plugins.getPath( 'qwiki' ) + 'images/01_chevron.gif' );
												//data.type = "process";
												break;
											  case "Orglane":
												previewImage.setAttribute( 'src', CKEDITOR.plugins.getPath( 'qwiki' ) + 'images/02_organigramm.gif' );
											    //data.type = "organigram";
												break;
											  default:
												previewImage.setAttribute( 'src', CKEDITOR.plugins.getPath( 'qwiki' ) + 'images/03_schwimmbahn.gif' );
											    //data.type = "swimlane";
											  	break;
											}
										},
										commit : function( data )
										{
											data.type = this.getValue();
										}
									},
									{
										type : 'text',
										id : 'name',
										label : editor.lang.qwikiflowchart.name,
										required: true,
										onLoad : function ()
										{
											this.allowOnChange = true;
										},
										onKeyUp : function()
										{
											this.allowOnChange = false;
											
											//TODO: Validation ob Name schon vorhandne ist 

											this.allowOnChange = true;

										},
										onChange : function()
										{
											if ( this.allowOnChange )		// Dont't call on dialog load.
												this.onKeyUp();
										},
										onShow : function()
										{
										},
										validate : function()
										{
											var dialog = this.getDialog();

											// Modac : Validieren ob die Eingabe richtig ist

											return true;

											var func = CKEDITOR.dialog.validate.notEmpty( editor.lang.qwikiflowchart.noUrl );
											return func.apply( this );
										},
										setup : function( data )
										{
											this.allowOnChange = false;
											// Modac : Überprüfen
											if ( data.name )
												this.setValue( data.name );
											this.allowOnChange = true;

										},
										commit : function( data )
										{
											// IE will not trigger the onChange event if the mouse has been used
											// to carry all the operations #4724
											this.onChange();

											var name = this.getValue();
											
											// Modac : TODO: Alles entfernen, was nicht gespeichert werden kann
											name = removeSpace(this.getValue());
											this.setValue(name);
											data.name = name;
											this.allowOnChange = false;
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
							},
							{
								type : 'vbox',
								height : '250px',
								children :
								[
									{
										id   : 'previewImage',
										type : 'html',
										//style : 'width:30%;',
										//Alex: Hier werden die Vorschaubilder genutzt
										html : '<div>' + CKEDITOR.tools.htmlEncode( editor.lang.qwikiflowchart.example ) + '<br>' +
										'<div id="FlowchartPreviewBox">'+
										'<img id="previewImage2" src="' + CKEDITOR.plugins.getPath( 'foswiki' ) + 'images/03_schwimmbahn.gif" alt="" /></a>' +
										'</div>'+'</div>'
									}
								]
							}
						]
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
			if ( element && element.getAttribute( 'data-cke-real-element-type' ) && element.getAttribute( 'data-cke-real-element-type' ) == 'provis' )
			{
				this.fakeObj = element;
				//alert(element.attributes.name);
				element = editor.restoreRealElement( this.fakeObj );
				alert(loadElements(editor, selection, element));
				this.setupContent (loadElements.apply( this, [ editor, selection, element ] ));
				selection.selectElement( this.fakeObj );
				this.getContentElement( 'info', 'name' ).focus();
				return;
				
			}
			this.setupContent( parseProvis.apply( this, [ editor, element ] ) );
			this.getContentElement( 'info', 'name' ).focus();
		},
		onOk : function()
		{
			var data = {};
			
			// Alex : Hier müssen rein
			// Validierung ob Zeichen passen
			// Test, ob Name schon vorhanden ist
			// Ggf. Möglichkeit das Dokument zu Überschreiben
			// 
			
			this.commitContent( data );
			
				{
					//kann ich hier auch direkt auf data zugreifen?
					var name = data.name || "Provis_Platzhalter";
					var type = data.type || "Swimlane";
					var rev = data.rev || 1;
					
					//name = this.removeSpace(name);
					//alert(name);

					var element = CKEDITOR.dom.element.createFromHtml( '<span class="WYSIWYG_PROTECTED">%PROCESS{name=&quot;' + name + '&quot; type=&quot;' + type + '&quot; rev=&quot;' + rev + '&quot;}%</span>' );
					
					if ( this.editMode )
					{
						//alert("jo mann!");
						//this.editObj.copyAttributes( element, { name : 1 } );
						//this.editObj.moveChildren( element );
					}
					
					// Set name.
					element.removeAttribute( '_cke_saved_name' );
					//element.setAttribute( 'name', "ProVis" );
					// Insert a new anchor.
					var imgSrc;
					switch (type) {
						case "Swimlane":
							imgSrc = CKEDITOR.plugins.getPath( 'qwiki' ) + 'images/diagramm_swimlane.png';
							break;
						case "Flex":
							imgSrc = CKEDITOR.plugins.getPath( 'qwiki' ) + 'images/diagramm_swimlane.png';
							break;
						case "Orglane":
							imgSrc = CKEDITOR.plugins.getPath( 'qwiki' ) + 'images/diagramm_swimlane.png';
							break;
						default:
							imgSrc = CKEDITOR.plugins.getPath( 'qwiki' ) + 'images/diagramm_swimlane.png';
							break;
					}
					
					var fakeElement = editor.createFakeElement( element, 'cke_provis', 'provis', false, imgSrc);
					
					//Alex: Css für das ProVis FakeImage als Style anbinden...
					var fakeStyle =
								'background-image: url(' + CKEDITOR.getUrl( CKEDITOR.plugins.getPath( 'qwiki' ) + 'images/diagramm_swimlane.png' ) + ');' +
								'background-repeat: no-repeat;' +
								'border: 1px solid #a9a9a9;' +
					            'width: 496px; height: 506px;';
					fakeElement.setAttribute('style', fakeStyle);
					
					// Modac : Hier kann angepackt werden
					fakeElement.setAttribute('_cke_provis_name', name);
					fakeElement.setAttribute('_cke_provis_type', type);
					
					// Modac : 
					if ( !fakeElement.getAttribute('_cke_provis_rev'));
						fakeElement.setAttribute('_cke_provis_rev', rev);
					
					if ( !this.editMode )
						editor.insertElement( fakeElement );
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
