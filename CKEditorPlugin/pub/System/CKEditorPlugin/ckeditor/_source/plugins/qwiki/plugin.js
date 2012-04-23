

// Modac : RegEx um Foswiki Code zu filtern	
var provisRegex = /%PROCESS/g,
	getProvisRegex = /%PROCESS\{"([^"]*)"[\s\S]*(rev="([^"]*)")\}%$/ig,
	numberRegex = /^\d+(?:\.\d+)?$/,
	code1Regex = /%.*\{.*\}%$/g,
	codeRegex = /^%[\s\S]*%$/ig;

// Modac : Keine Ahnung was das macht
var cssifyLength = function( length )
	{
		if ( numberRegex.test( length ) )
			return length + 'px';
		return length;
	};

// Modac : RegEx um ProVis Diagramme zu filtern
var isProVis = function( element )
	{
		var provisRegex = new RegExp("%PROCESS\{[^\}]*\}%$", "ig");
		var wert = provisRegex.test( element );
		//alert(element + "und ist  :" + wert);
		return wert;
		//return ( wert );
	};

// Modac : Funktion um Links zu erkennen und richtig darzustellen	
var getLink = function( element )
	{
		//var linkRegex = new RegExp("\[\[([^\]]*)\]\[([^\]]*)\]\]", "ig");
		//var linkRegex = new RegExp("\[\[([\s\S]*)", "ig");
		
		var ausdruck1 = /([\s\S]*)/g;
		if (ausdruck1.test(element))
		{
			var result = ausdruck1.exec(element);
			alert(result);
			var name = result[0] || 'fehler';
			var href = result[0] || 'fehler';
		}
		
		var attributes = { name: name || 'fehler', href: href || 'fehler' };
		return attributes;
	};
	
// Modac : Funktion um ProVis Elemente auszulesen und darzustellen
var getProVis = function( element )
	{
		// RegExen um ProVis Informationen auszulesen
		var ausdruck1 = /name="([^"]*)"/g;
		var ausdruck2 = /\{"([^"]*)"/g;
		var ausdruck3 = /rev="([^"]*)"/g;
		var ausdruck4 = /type="([^"]*)"/g;
		var name = '';
		var rev = 1;
		var type = "swimlane";
		
		// Name
		if (ausdruck1.test(element))
		{
			ausdruck1.exec(element);
			name = RegExp.$1;
		}
		// Name wenn ProVis noch leer ist ( %PROCESS{"test"}% )
		else if (ausdruck2.test(element))
		{
			ausdruck2.exec(element);
			name = RegExp.$1;
		}	
		// Revision
		if (ausdruck3.test(element))
		{
			ausdruck3.exec(element);
			rev = RegExp.$1 || 1;
		}
		// Type - Standard ist swimlane
		if (ausdruck4.test(element))
		{
			ausdruck4.exec(element);
			type = RegExp.$1 || 'swimlane';
		}
	    
	    // Übergabe der Attribute
		var attributes = { name: name, rev: rev, type: type };
		return attributes;
	};

// Modac : Funktion um Code Elemente auszulesen
var isCode = function( element )
	{
		var codeRegex = new RegExp("^%.*%$", "ig");
		var wert = codeRegex.test( element );
		return wert;
	};


CKEDITOR.plugins.add('qwiki',
{
	requires : [ 'dialog', 'fakeobjects', 'qwikiprovisarea' ],

	init : function( editor, pluginPath )
	{
	
		// Dokumente Verlinken
		editor.addCommand( 'document', new CKEDITOR.dialogCommand( 'document' ) );
		editor.ui.addButton( 'Document',
			{
				label	: editor.lang.document.toolbar,
				command : 'document',
				icon	: this.path + 'images/document.gif'
			});
		CKEDITOR.dialog.add( 'document', this.path + 'dialogs/document.js' );
		
		// ProVis Einbinden / ProVis Eigenschaften bzw. Flowchart neu einfügen
		editor.addCommand( 'provis', new CKEDITOR.dialogCommand( 'provis' ));
		editor.ui.addButton( 'ProVis',
			{
				label : editor.lang.flowchart.toolbar,
				command : 'provis',
				icon	: this.path + 'images/flowchart.gif'
			});
	    CKEDITOR.dialog.add( 'provis', this.path + 'dialogs/provis.js' );
	    
	    //TODO: Warum hier?
		editor.on( 'doubleclick', function( evt )
				{
					var element = CKEDITOR.plugins.link.getSelectedLink( editor ) || evt.data.element;

					if ( element.getAttribute( '_cke_real_element_type' ) == 'provis' )
					{
						editor.execCommand('provisarea');
					}
				});

		// Code Einbinden
		// Modac : Anpassen
		editor.addCommand( 'code', new CKEDITOR.dialogCommand( 'code' ) );
		editor.ui.addButton( 'Code',
			{
				label : editor.lang.code.toolbar,
				command : 'code',
				icon	: this.path + 'images/code.png'
			});
		
		CKEDITOR.dialog.add( 'code', this.path + 'dialogs/code.js' );
		
		// Modac: Css für das Code FakeImage
		editor.addCss(
				'img.cke_code' +
				'{' +
					'background-image: url(' + CKEDITOR.getUrl( this.path + 'images/code_tag.gif' ) + ');' +
					'background-position: center center;' +
					'background-repeat: no-repeat;' +
					'border: 1px solid #a9a9a9;' +
					'width: 80px;' +
					'height: 20px;' +
				'}'
				);


		
		// If the "menu" plugin is loaded, register the menu items.
		if ( editor.addMenuItems )
		{
			editor.addMenuItems(
				{
					// ProVis Kontextmenü - Editieren starten
					provis :
					{
						label : editor.lang.flowchart.contextmenu,
						icon : this.path + "images/flowchart.gif",
						command : 'provisarea',
						group : 'provis',
						order : 1
					},
					// Foswiki Code Kontextmenü
					code :
					{
						label : "Code",
						command : 'code',
						group : 'code',
						order : 1
					}
				});
		}
		
		// Modac : Wenn Kontextmenü vorhanden ist: ProVis und Code mit rein nehmen.
		if ( editor.contextMenu )
		{
			// Modac : provis contextmenu
			editor.contextMenu.addListener( function( element, selection )
				{
					if ( element && element.is( 'img' ) && element.getAttribute( '_cke_real_element_type' ) == 'provis' )
						return { provis : CKEDITOR.TRISTATE_OFF };
				});
			
			// Modac : code contextmenu
			editor.contextMenu.addListener( function( element, selection )
				{
					if ( element && element.is( 'img' ) && element.getAttribute( '_cke_real_element_type' ) == 'code' )
						return { code : CKEDITOR.TRISTATE_OFF };
				});
			

		}
	},
	
	afterInit : function( editor )
	{
		var dataProcessor = editor.dataProcessor,
			dataFilter = dataProcessor && dataProcessor.dataFilter,
			htmlFilter = dataProcessor && dataProcessor.htmlFilter;
		
		
		if ( dataFilter )
		{
			dataFilter.addRules(
				{
					elements :
					{
						// Modac : Hier werden alle Span´s gefiltert und nach Code bzw. ProVis durchsucht
					    span : function( element )
						{
							// Modac : Due to lovely Internet Explorer
							var attr = '';							
							attr = element.attributes["class"];
							
							// Modac : Alle spans mit WYSIWYG_PROTECED Attribut werden hier ausgelesen
							if (attr == "WYSIWYG_PROTECTED")
							{
								for ( var i = 0 ; i < element.children.length ; i++ )
								{
									var value = element.children[ i ].value;
									value = value.replace(/\n/, '');
								
									var el;
									
									if ( isProVis(value) )
									{
										var attributes = getProVis(value);
										var host = FoswikiCKE.getFoswikiVar("ATTACHURL");
										var name = attributes.name + ".png" + "?rev=" + attributes.rev;
										var url = host + "/" + name;
										
										//TODO: AjaxRequest? oder andere Möglichkeit?
										
										el = editor.createFakeParserElement( element, 'cke_provis', 'provis', false, url );
										
										el.attributes._cke_provis_name = attributes.name;
										el.attributes._cke_provis_type = attributes.type;
										el.attributes._cke_provis_rev = attributes.rev;
										
										return el;
									}
									else if ( isCode(value) )
									{
										return editor.createFakeParserElement( element, 'cke_code', 'code');
									}
									else
										return element;
										
									return;

								}
							}
						}
					}
				});
		}
		
		if ( htmlFilter )
		{
			htmlFilter.addRules(
				{
					elements :
					{
						// Modac : Hier werden alle Span´s gefiltert und nach Code bzw. ProVis durchsucht
					    span : function( element )
						{
							// Modac : Due to lovely Internet Explorer
							var attr = '';							
							attr = element.attributes["class"];
							
							// TODO : Wofür ist der Html Filter da??
							if (attr == "WYSIWYG_PROTECTED")
							{
								for ( var i = 0 ; i < element.children.length ; i++ )
								{
									var value = element.children[ i ].value;
									value = value.replace(/\n/, '');

									if ( isProVis(value) )
									{
									}
									else if ( isCode(value) )
									{
									}
									return element;

								}
							}		
						}
					}
				});
		}
	}
} );

CKEDITOR.editor.prototype.createFakeParserElement = function( realElement, className, realElementType, isResizable, imgSrc )
{
var lang = this.lang.fakeobjects,
	html;

var writer = new CKEDITOR.htmlParser.basicWriter();
realElement.writeHtml( writer );
html = writer.getHtml();


var attributes =
{
	'class' : className,
	src : CKEDITOR.getUrl( 'images/spacer.gif' ) ,
	_cke_realelement : encodeURIComponent( html ),
		_cke_real_node_type : realElement.type,
		alt : lang[ realElementType ] || lang.unknown,
		align : realElement.attributes.align || ''
};
 
	if ( realElementType )
		attributes._cke_real_element_type = realElementType;

	if ( isResizable )
		attributes._cke_resizable = isResizable;
	
	if ( imgSrc )
	{
		// Modac : Hier muss gecheckt werden, ob das einwandfrei funzt, oder ob der Name noch überprüft werden muss
		attributes.src = CKEDITOR.getUrl( imgSrc );
		//alert(attributes.src);
	}

	return new CKEDITOR.htmlParser.element( 'img', attributes );
};





