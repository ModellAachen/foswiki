// Modac : RegEx um ProVis Diagramme zu filtern
var isProVis = function( element )
	{
		var provisRegex = new RegExp("%PROCESS\{[^}]*\}%$", "ig");
		var wert = provisRegex.test( element );
		return wert;
	};

// Modac : Funktion um ProVis Elemente auszulesen und darzustellen
var getProVis = function( value )
		{
	var name, type,
		aqmrev = 0, maprev = 0, pngrev = 0;
		
	// Modac : ProVis Flowchart per regulärem Ausdruck auslesen
	var rev = 0, type;
	
	var m_name_legacy = value.match(/\{"(.+?)"/);
	if (m_name_legacy !== null) {
		name = m_name_legacy[1];
	} else {
		var m_name = value.match(/\bname="(.+?)"/);
		if (m_name !== null) name = m_name[1];
		}	

	var m_rev_legacy = value.match(/\brev="(\d+)"/);
	if (m_rev_legacy !== null) {
		rev = m_rev_legacy[1];
	} else {
		var m_aqmrev = value.match(/\baqmrev="(\d+)"/);
		var m_maprev = value.match(/\bmaprev="(\d+)"/);
		var m_pngrev = value.match(/\bpngrev="(\d+)"/);
		aqmrev = m_aqmrev ? m_aqmrev[1] : rev;
		maprev = m_maprev ? m_maprev[1] : rev;
		pngrev = m_pngrev ? m_pngrev[1] : rev;
		}

	var m_type = value.match(/\btype="(.+?)"/);
	if (m_type !== null) {
		type = m_type[1];
		}
	    
	return {
		name: name || "",
		type: type || "swimlane",
		aqmrev: aqmrev,
		maprev: maprev,
		pngrev: pngrev
	};
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
	lang : [ 'de', 'en' ],

	init : function( editor, pluginPath )
	{
		// General UI fixes that don't fit anywhere else
		// Make combo boxes wide enough so nothing gets truncated
		$('head').append('<style type="text/css">\n'+
			'.cke_panel { min-width: 200px; }\n'+
			'.cke_rcombo .cke_text { width: auto !important; min-width: 60px; }\n'+
			'.cke_rcombo .cke_inline_label { padding-right: 4px; }\n'+
		'</style>');

		// Dokumente Verlinken
		editor.addCommand( 'document', new CKEDITOR.dialogCommand( 'document' ) );
		editor.ui.addButton( 'Document',
			{
				label	: editor.lang.qwikidocument.toolbar,
				command : 'document',
				icon	: this.path + 'images/document.gif'
			});
		CKEDITOR.dialog.add( 'document', this.path + 'dialogs/document.js' );
		
		// ProVis Einbinden / ProVis Eigenschaften bzw. Flowchart neu einfügen
		editor.addCommand( 'provis', new CKEDITOR.dialogCommand( 'provis' ));
		editor.ui.addButton( 'ProVis',
			{
				label : editor.lang.qwiki.toolbarFlowchart,
				command : 'provis',
				icon	: this.path + 'images/flowchart.gif'
			});
	    CKEDITOR.dialog.add( 'provis', this.path + 'dialogs/provis.js' );
	    
		// Code Einbinden
		editor.addCommand( 'code', new CKEDITOR.dialogCommand( 'code' ) );
		editor.ui.addButton( 'Code',
			{
				label : editor.lang.qwikicode.toolbar,
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
						label : editor.lang.qwikiflowchart.contextmenu,
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
					if ( element && element.is( 'img' ) && element.getAttribute( 'data-cke-real-element-type' ) == 'provis' ) {
						// Disable clipboard menu items to prevent accidents
						var items = [ 'cut', 'copy', 'paste' ];
						$.each(items, function(_idx, menuitem) {
							var mi = editor.getMenuItem( menuitem );
							if (!mi) return;
							mi.state = CKEDITOR.TRISTATE_DISABLED;
						});
						editor.getMenuItem( 'cut' )
						return { provis : CKEDITOR.TRISTATE_OFF };
					}
				});
			
			// Modac : code contextmenu
			editor.contextMenu.addListener( function( element, selection )
				{
					if ( element && element.is( 'img' ) && element.getAttribute( 'data-cke-real-element-type' ) == 'code' )
						return { code : CKEDITOR.TRISTATE_OFF };
				});
			

		}
	},
	
	afterInit : function( editor )
	{
		var dataProcessor = editor.dataProcessor,
			dataFilter = dataProcessor && dataProcessor.dataFilter;
		
		editor.lang.fakeobjects.provis = editor.lang.qwiki.flowchartType;
		
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
										var host = FoswikiCKE.getFoswikiVar("SCRIPTURL") +'/viewfile/'+
											FoswikiCKE.getFoswikiVar('WEB') +'/'+
											FoswikiCKE.getFoswikiVar('TOPIC') + '/';
										var name = attributes.name + ".png" + "?rev=" + attributes.pngrev;
										var url = host + "/" + name;
										
										el = editor.createFakeParserElement( element, 'cke_provis', 'provis', false );
										
										el.attributes._cke_provis_name = attributes.name;
										el.attributes._cke_provis_type = attributes.type;
										el.attributes._cke_provis_aqmrev = attributes.aqmrev;
										el.attributes._cke_provis_maprev = attributes.maprev;
										el.attributes._cke_provis_pngrev = attributes.pngrev;
										el.attributes.src = url;
										
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
	}
} );

