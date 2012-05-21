/*
Copyright (c) 2003-2010, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

/**
 * @fileOverview The "sourcearea" plugin. It registers the "source" editing
 *		mode, which displays the raw data being edited in the editor.
 */

/* Hier wird der Modus der Commands gesetzt (Buttons ausgegraut) */
var updateCommandsMode = function( editor, namensraum, ein )
{
		var command,
			commands = editor._.commands;

		for ( var name in commands )
		{
			if (ein)
			{
				if (name.indexOf(namensraum) != 0)
				{
					command = commands[ name ];
					command[ 'disable' ]();
				}
			}
			else
			{
				command = commands[ name ];
				command[ 'enable' ]();
			}
		}
};
var flowchart = null;

CKEDITOR.plugins.add( 'qwikiprovisarea',
{
	requires : [ 'editingblock', 'richcombo', 'styles' ],
	lang : [ 'de', 'en' ],

	init : function( editor )
	{
		var provisarea = CKEDITOR.plugins.provisarea,
			win = CKEDITOR.document.getWindow(),
			iframe,
			provisframe,
			config = editor.config;
		
		config.provis_maxWidth = "800";
		config.provis_minWidth = "300";
		
		var container = null,
		textcontainer = null,
		proviscontainer = null,
		origin,
		startSize,
		provisSize,
		textSize,
		resizeHorizontal = 1,
		resizeVertical = 0;
		
		/*
		 * Watch auch für Internet Explorer etc
		 * 
		 */
		function watchIt(o, p,f) {
		    if(!o.watchNEU) {canDo(o, p, f);} 
		    else {o.watch(p,f);}
		};

		function unwatchIt(o, p) {
		    if(!o.unwatchNEU) {unDo(o, p);} 
		    else {o.unwatch(p);}
		};

		function unDo(o, p) {
		    eval('clearInterval(o.'+p+'timerID);'); 
		};

		function canDo(o, p, f){
			this.obj = o; this.prop = p; this.func = f;
		    var state=this.obj[this.prop]; 
			var control=function(){
				if(o[p]!=state)
				{
					state=f(p,state,o[p]);
				}
				};
		    eval('o.'+p+'timerID = setInterval(' + control + ', 100);');
		};
		
		function setDynRunvar(eventname, variable)
		{
			editor.fire( eventname, variable );
		};
		
		function saveMapper(saveStyle)
		{
			switch (saveStyle)
			{
			case "line": 	
				return "Einfache Trennlinien";
				break;
			case "frame": 	
				return "Rahmen";
				break;
			case "noframe": 		
				return "Ohne Rahmen";
				break;
			default:			
				return "Rahmen";
				break;
			}
		};
		
		function addComboSize( editor, comboName, styleType, lang, entries, defaultLabel, styleDefinition )
		{
			var config = editor.config;

			// Gets the list of fonts from the settings.
			var names = entries.split( ';' ),
				values = [];

			// Create style objects for all ProViiis.
			var styles = {};
			for ( var i = 0 ; i < names.length ; i++ )
			{
				var parts = names[ i ];

				if ( parts )
				{
					parts = parts.split( '/' );

					var vars = {},
						name = names[ i ] = parts[ 0 ];

					vars[ styleType ] = values[ i ] = name || name;

					styles[ name ] = new CKEDITOR.style( styleDefinition, vars );
					styles[ name ]._.definition.name = name;
				}
				else
					names.splice( i--, 1 );
			}

			editor.ui.addRichCombo( comboName,
				{
					label : editor.lang.qwikiflowchart.resize,
					title : editor.lang.qwikiflowchart.resize,
					className : 'cke_provis_size',
					panel :
					{
						css : editor.skin.editor.css.concat( config.contentsCss ),
						multiSelect : false,
						attributes : { 'aria-label' : lang.panelTitle }
					},

					init : function()
					{
						this.startGroup( editor.lang.qwikiflowchart.resize );
						for ( var i = 0 ; i < names.length ; i++ )
						{
							var name = names[ i ];

							// Add the tag entry to the panel list.
							this.add( name , styles[ name ].buildPreview(), name );
						}
						
					},

					onClick : function( value )
					{
						editor.execCommand( 'provisresize', value );
					},

					onRender : function()
					{
						editor.on( 'selectionChange', function( ev )
								{
									var currentValue = this.getValue();

									var elementPath = ev.data.path,
										elements = elementPath.elements;

									// For each element into the elements path.
									for ( var i = 0, element ; i < elements.length ; i++ )
									{
										element = elements[i];

										// Check if the element is removable by any of
										// the styles.
										for ( var value in styles )
										{
											if ( styles[ value ].checkElementRemovable( element, true ) )
											{
												if ( value != currentValue )
													this.setValue( value );
												return;
											}
										}
									}

									// If no styles match, just empty it.
									this.setValue( '', defaultLabel );
								},
								this);
					}
				});
		}
		
		function addCombo( editor, comboName, styleType, lang, entries, defaultLabel, styleDefinition )
		{
			var config = editor.config;
			
			// Gets the list of fonts from the settings.
			var names = entries.split( ';' ),
				values = [];

			// Create style objects for all ProViiis.
			var styles = {};
			for ( var i = 0 ; i < names.length ; i++ )
			{
				var parts = names[ i ];

				if ( parts )
				{
					parts = parts.split( '/' );
					
					var url =  CKEDITOR.plugins.getPath( 'provisarea' ) + 'images/' + parts[1];

					var vars = {},
						name = names[ i ] = parts[ 0 ];

					vars[ styleType ] = values[ i ] = parts[1] || name;

					styles[ name ] = new CKEDITOR.style( styleDefinition, vars );
					styles[ name ]._.definition.name = name;
				}
				else
					names.splice( i--, 1 );
			}

			editor.ui.addRichCombo( comboName,
				{
					label : editor.lang.qwikiflowchart.nodes,
					title : editor.lang.qwikiflowchart.nodes,
					className : 'cke_provis',
					panel :
					{
						css : editor.skin.editor.css.concat( config.contentsCss ),
						multiSelect : false,
						attributes : { 'aria-label' : lang.panelTitle }
					},

					init : function()
					{						
						this.startGroup(editor.lang.qwikiflowchart.nodes);

						for ( var i = 0 ; i < names.length ; i++ )
						{
							var name = names[ i ];

							// Add the tag entry to the panel list.
							this.add( name , styles[ name ].buildPreview(), name );
						}
						
					},

					onClick : function( value )
					{
						document.getElementById("iframe_provis").contentWindow.setShape(value);
						//alert(document.getElementById("iframe_provis").contentWindow.DynRunVar.activeShape);
					},

					onRender : function()
					{
						//TODO: Checken ob Wert vorhanden!
						editor.on( 'provis_shape', function( ev )
								{
									var currentValue = this.getValue();
									var wert = ev.data;
									this.setValue( wert );
								},
								this);
					}
				});
		}
		
		function addComboSave( editor, comboName, styleType, lang, entries, defaultLabel, styleDefinition )
		{
			var config = editor.config;
			
			// Gets the list of fonts from the settings.
			var names = entries.split( ';' ),
				values = [];

			// Create style objects for all ProViiis.
			var styles = {};
			for ( var i = 0 ; i < names.length ; i++ )
			{
				var parts = names[ i ];

				if ( parts )
				{
					parts = parts.split( '/' );
					
					var url =  CKEDITOR.plugins.getPath( 'provisarea' ) + 'images/' + parts[1];

					var vars = {},
						name = names[ i ] = parts[ 0 ];

					vars[ styleType ] = values[ i ] = parts[1] || name;

					styles[ name ] = new CKEDITOR.style( styleDefinition, vars );
					styles[ name ]._.definition.name = name;
				}
				else
					names.splice( i--, 1 );
			}

			editor.ui.addRichCombo( comboName,
				{
					label : editor.lang.qwikiflowchart.saveoptions,
					title : editor.lang.qwikiflowchart.saveoptions,
					className : 'cke_provis',
					panel :
					{
						css : editor.skin.editor.css.concat( config.contentsCss ),
						multiSelect : false,
						attributes : { 'aria-label' : lang.panelTitle }
					},

					init : function()
					{
						
						this.startGroup( "Speicheroptionen" );

						for ( var i = 0 ; i < names.length ; i++ )
						{
							var name = names[ i ];

							// Add the tag entry to the panel list.
							this.add( name , styles[ name ].buildPreview(), name );
						}
						
					},

					onClick : function( value )
					{
						document.getElementById("iframe_provis").contentWindow.setSaveStyleMapper(value);
						//alert(document.getElementById("iframe_provis").contentWindow.DynRunVar.saveStyle);
					},

					onRender : function()
					{
						//TODO: Checken ob Wert vorhanden!
						editor.on( 'provis_save', function( ev )
								{
									var currentValue = this.getValue();
									var wert = saveMapper(ev.data);
									this.setValue( wert );
								},
								this);
					}
				});
		}
		
		editor.on( 'doubleclick', function( evt )
				{
					var element = CKEDITOR.plugins.link.getSelectedLink( editor ) || evt.data.element;

					if ( element.getAttribute( 'data-cke-real-element-type' ) == 'provis' )
					{
						var hasJava = true;
						if (typeof navigator.javaEnabled == 'function') {
							if (!navigator.javaEnabled()) hasJava = false;
						} else if (typeof window.clientInformation.javaEnabled == 'function') {
							if (!window.clientInformation.javaEnabled()) hasJava = false;
						}
						if (hasJava) return editor.execCommand('provisarea');
						alert(editor.lang.qwikiflowchart.javaDisabled);
					}
				});
		


		editor.on( 'closeprovis', function(event)
				{
					editor = event.editor;
					
					//Provis Attribute auslesen
					var name = flowchart.getAttribute( '_cke_provis_name' );
					var type = flowchart.getAttribute( '_cke_provis_type' ) || Swimlane;
					// If we don't even have a legacy revision, use the newest
					// revision instead... there are probably worse choices
					var rev = flowchart.getAttribute( '_cke_provis_rev' ) || 0;

					// Fall back to legacy revision if no specific revision specified
					// The only situation in which this fallback should happen
					// is if a user deleted the attributes or the tag was
					// created by an old version of this plugin.
					var aqmRev = flowchart.getAttribute( '_cke_provis_aqmrev' ) || rev;
					var mapRev = flowchart.getAttribute( '_cke_provis_maprev' ) || rev;
					var pngRev = flowchart.getAttribute( '_cke_provis_pngrev' ) || rev;
					
					// Unblock editor UI
					//SMELL: should un-hardcode ID
					var ibody = $('#cke_contents_topic iframe').first().contents().find('body');
					ibody.find('#cke_provis_block_overlay').remove();
					ibody[0].contentEditable = "true";
					// Restore save/cancel buttons
					$('.patternBorder').show();

					// Neues Element kreiieren und ersetzen
					var element = CKEDITOR.dom.element.createFromHtml('<span class="WYSIWYG_PROTECTED">%PROCESS{'+
						'name=&quot;'+ name +'&quot; type=&quot;'+ type +'&quot; '+
						'aqmrev=&quot;'+ aqmRev +'&quot; maprev=&quot;'+ mapRev +'&quot; pngrev=&quot;'+ pngRev +'&quot;}%</span>'
					);
					element.replace(flowchart);
					
					var holderElement = editor.getThemeSpace("contents");
					holderElement.getChild(2).remove();
					holderElement.getChild(1).remove();
					holderElement.getChild(0).setStyle('width', '100%');
					
					var data = editor.getData();
					editor.setData(data);
					editor.fire( 'close_provistoolbar' );
					//Tristate wieder rausnehmen
					updateCommandsMode(editor, "provis", false);

					flowchart = null;
					
					//TODO: Was ist wenn die Var nicht gesetzt ist?
					try {
						//TODO: Dynamische Runtime Variable setzen
						var frame = document.getElementById("iframe_provis")
						var dynrunvar = frame.contentWindow.DynRunVar;
										
						unwatchIt(dynrunvar, "activeShape");
						unwatchIt(dynrunvar, "saveStyle");
					}
					catch (e){
					}
				});
		
		editor.on( 'openprovis', function(event)
				{
					var selection = editor.getSelection();
					
					var element = selection.getSelectedElement();
					var topic, name, type, rev;
					flowchart = element;

					// Remove save/cancel buttons for now
					$('.patternBorder').hide();
					// Block editor UI
					// Must happen after getting selected element because IE is prone to forgetting the selection -jk
					//SMELL: should un-hardcode ID
					var iframe = $('#cke_contents_topic iframe').first();
					var ibody = iframe.contents().find('body');
					ibody.append('<div id="cke_provis_block_overlay" style="left: 0; top: 0; background: black; -ms-filter:\'progid:DXImageTransform.Microsoft.Alpha(Opacity=50)\'; filter: alpha(opacity=50); opacity: .5; z-index: 15000; position: fixed;"></div>');
					ibody.find('#cke_provis_block_overlay').height(iframe.innerHeight()).width(iframe.innerWidth());
					if (ibody[0]) ibody[0].contentEditable = "false";
					// Make IE7 deselect flowchart element in editor, so that users
					// cannot accidentally delete it
					iframe.blur();

					if ( element && element.getAttribute( 'data-cke-real-element-type' ) && element.getAttribute( 'data-cke-real-element-type' ) == 'provis' )
					{
						//Alex: Topic??
						
						topic = element.getAttribute( '_cke_provis_topic' ) || FoswikiCKE.getFoswikiVar("WEB") + "." + FoswikiCKE.getFoswikiVar("TOPIC");
						name = element.getAttribute( '_cke_provis_name' );
						type = element.getAttribute( '_cke_provis_type' ) || swimlane;
						rev = element.getAttribute( '_cke_provis_aqmrev' ) ||
							element.getAttribute( '_cke_provis_rev' ) || 1;
					}
					else
						return false;
					
					//Alex: Standard Verteilung ProVis / Text
					var share = 0.7;
					//Alex: Was passiert, wenn der Themespace während der Bearbeitung größer / kleiner wird?
				
					editor = event.editor;
					var holderElement = editor.getThemeSpace("contents");
					
					startSize = { width : holderElement.$.offsetWidth || 0, height : holderElement.$.offsetHeight || 0 };
					provisSize = { width : (startSize.width * share) || "70%", height : holderElement.$.offsetHeight || "100%" };
					textSize = { width : startSize.width * (1 - share) || "30%", height : holderElement.$.offsetHeight || "100%" };
					
					config.provis_maxWidth = startSize.width;
					
					//Bestehendes Textfeld auf 30% reduzieren
					holderElement.getChild(0).setStyle( 'width', textSize.width + "px" );
					holderElement.getChild(0).setAttribute( 'id', 'iframe_text' );
					
					//Rest URL
					var srcScript = FoswikiCKE.getFoswikiVar('SCRIPTURL') + "/rest/ProVisPlugin/edit?topic=" + topic + 
					";drawingName=" + name +
					";drawingRevision=" + rev +
					";drawingType=" + type + ";";
					
					//Sizer					
					var div = CKEDITOR.dom.element.createFromHtml( '<div class="cke_provis_resizer"' +
						' style="position: absolute; display: inline; height: ' + startSize.height + 'px; width: 15px; background-color: #d3d3d3;"' +
						'></div>');
					
					//ProVis IFrame
					iframe = CKEDITOR.dom.element.createFromHtml( '<iframe' +
							' style="width:' + provisSize.width + 'px; height:100%; position:relative;"' +
							' frameBorder="0"' +
							' id="iframe_provis"' +
							' src="' + srcScript + '"' +
							' tabIndex="' + editor.tabIndex + '"' +
							' allowTransparency="true"' +
							'></iframe>' );
					
					//Append both divs
					holderElement.append(div);
					holderElement.append(iframe);

					editor.fire( 'load_provistoolbar' );
					updateCommandsMode(editor, "provis", true);

					$(iframe.$).one( 'load', function( ev )
						{
								//TODO: Dynamische Runtime Variable setzen
								var frame = document.getElementById("iframe_provis")
								var dynrunvar = frame.contentWindow.DynRunVar;

								watchIt(dynrunvar, "activeShape",
										function (id,oldvalue,newvalue) {
											if( newvalue ){
												setDynRunvar("provis_shape", newvalue );
												return newvalue;
											}
										});
										
								editor.fire("provis_shape", dynrunvar.activeShape );
								
								watchIt(dynrunvar, "saveStyle",
										function (id,oldvalue,newvalue) {
											if( newvalue ){
												setDynRunvar("provis_save", newvalue );
												return newvalue;
											}
										});
								editor.fire("provis_save", dynrunvar.saveStyle );
						});
				});
		
		editor.on( 'mode', function()
				{
					editor.getCommand( 'provisarea' ).setState(
						editor.mode == 'provisarea' ?
								CKEDITOR.TRISTATE_ON :
								CKEDITOR.TRISTATE_OFF );
								
				});
	
		//Alex: Hier neue Commands hinzufügen
		editor.addCommand( 'provisarea', provisarea.commands.provisarea );
		editor.addCommand( 'provisnewdiagram', provisarea.commands.provisnewdiagram );
		editor.addCommand( 'provisnewswimlane', provisarea.commands.provisnewswimlane );
		editor.addCommand( 'provissave', provisarea.commands.provissave );
		editor.addCommand( 'provisundo', provisarea.commands.provisundo );
		editor.addCommand( 'provisredo', provisarea.commands.provisredo );
		editor.addCommand( 'provisabort', provisarea.commands.provisabort );
		editor.addCommand( 'provisresize', provisarea.commands.provisresize );
		
		//Alex: Hier neue Buttons hinzufügen
		//Icons: 
		if ( editor.ui.addButton )
		{
			editor.ui.addButton( 'Provis_Save',
				{
					label : editor.lang.qwikiflowchart.save,
					command : 'provissave',
					className : 'cke_button_save'
				});
		}
		
		if ( editor.ui.addButton )
		{
			editor.ui.addButton( 'Provis_NewDiagram',
				{
					label : editor.lang.qwikiflowchart.newdiagram,
					command : 'provisnewdiagram',
					className : 'cke_button_newpage'
				});
		}
		
		if ( editor.ui.addButton )
		{
			editor.ui.addButton( 'Provis_NewSwimlane',
				{
					label : editor.lang.qwikiflowchart.newswimlane,
					command : 'provisnewswimlane',
					icon	: this.path + 'images/swimlane_new.gif'
				});
		}
		
		if ( editor.ui.addButton )
		{
			editor.ui.addButton( 'Provis_Undo',
				{
					label : editor.lang.qwikiflowchart.undo,
					command : 'provisundo',
					className : 'cke_button_undo'
				});
		}
		
		if ( editor.ui.addButton )
		{
			editor.ui.addButton( 'Provis_Redo',
				{
					label : editor.lang.qwikiflowchart.redo,
					command : 'provisredo',
					className : 'cke_button_redo'
				});
		}
		
		if ( editor.ui.addButton )
		{
			editor.ui.addButton( 'Provis_DeleteSwimlane',
				{
					label : "Ausgewählte Swimlane löschen",
					command : 'provisdeleteswimlane',
					icon	: this.path + 'images/swimlane_new.gif'
				});
		}
		
		if ( editor.ui.addButton )
		{
			editor.ui.addButton( 'Provisarea',
				{
					label : editor.lang.qwikiflowchart.cancel,
					command : 'provisabort',
					icon	: this.path + 'images/icon_close.gif'
				});
		}
		
		//Combos:
		//ProVis Nodes
		addCombo( editor, 'Provis_Nodes', 'imageurl', 'ProVis', config.provis_nodes, config.provis_defaultLabel, config.Prozessschritt_style );

		
		//Modac: Flowchart Window Size
		addComboSize( editor, 'Provis_Size', 'imageurl', 'ProVis_Size', config.provis_size, config.provis_sizedefaultLabel, config.Size_style );
		
		
		//Modac: Save Options
		addComboSave( editor, 'Provis_Saveoptions', 'imageurl', 'ProVis_Saveoptions', config.provis_saveoptions, config.provis_saveoptionsdefaultLabel, config.Saveoptions_style );
		
		// CSS for Sizing Combo
		// +IE7 hack for combo panel height
		$(document).find('head').append('<style type="text/css">\n'+
				'.cke_toolbar_provis_size { float: right !important; }'+
				'.cke_rcombopanel { min-height: 150px; }'+
				'</style>'
		);
	}
});

/**
 * Holds the definition of commands an UI elements included with the sourcearea
 * plugin.
 * @example
 * Hier kommen die neuen Befehle für Provis rein.
 */
CKEDITOR.plugins.provisarea =
{
	// "canUndo" must be false for any commands that update the editor,
	// otherwise IE7 will screw up badly -jk
	commands :
	{
		provisarea :
		{
			exec : function( editor )
			{
				var top = editor.getThemeSpace("top");
				if ( editor.getCommand( 'provisarea' ).state == 2 )
				{
					editor.fire( 'openprovis' );
					editor.getCommand( 'provisarea' ).setState( CKEDITOR.TRISTATE_ON );
					editor.config.toolbar = "Basic_Provis";
					newtoolbox = editor.fire("expandieren", {space:'top',html:''}).html;
					top.setHtml(newtoolbox);
				}
				else if ( editor.getCommand( 'provisarea' ).state == 1 )
				{
					editor.fire( 'closeprovis' );
					editor.getCommand( 'provisarea' ).setState( CKEDITOR.TRISTATE_OFF );
					editor.config.toolbar = "Basic";
					newtoolbox = editor.fire("expandieren", {space:'top',html:''}).html;
					top.setHtml(newtoolbox);
				}
			},
			canUndo : false
		},
		provisnewdiagram :
		{
			exec : function( editor )
			{
				var iframe = document.getElementById("iframe_provis");
				iframe.contentWindow.setNewDiagram();
			},
			canUndo : false
		},
		provisnewswimlane :
		{
			exec : function( editor )
			{
				var iframe = document.getElementById("iframe_provis");
				iframe.contentWindow.AddSwim();
			},
			canUndo : false
		},
		provisdeleteswimlane :
		{
			exec : function( editor )
			{
				var iframe = document.getElementById("iframe_provis");
				//iframe.contentWindow.AddSwim();
			},
			canUndo : false
		},
		provisundo :
		{
			exec : function( editor )
			{
				var iframe = document.getElementById("iframe_provis");
				iframe.contentWindow.unDone();
			},
			canUndo : false
		},
		provisredo :
		{
			exec : function( editor )
			{
				var iframe = document.getElementById("iframe_provis");
				iframe.contentWindow.reDone();
			},
			canUndo : false
		},
		provissave :
		{
			exec : function( editor )
			{
				var iframe = document.getElementById("iframe_provis");
				$.blockUI({ 
		            centerY: 0, 
					css: { top: '20px', 'left': '20px' }
		        });
				setTimeout(function() {
					iframe.contentWindow.saveProvis({
						success: function(data, textStatus, xhr) {
							flowchart.setAttribute('_cke_provis_aqmrev', data.aqmrev);
							flowchart.setAttribute('_cke_provis_maprev', data.maprev);
							flowchart.setAttribute('_cke_provis_pngrev', data.pngrev);
							flowchart.setAttribute('_cke_provis_name', data.name);
				$.unblockUI();
				editor.execCommand( 'provisarea' );
			},
						error: function(xhr, textStatus, errorThrown) {
							alert(editor.lang.qwikiflowchart.saveerror + (errorThrown || textStatus));
							$.unblockUI();
						}
					});
				}, 500);
			},
			canUndo : false
		},
		provisabort :
		{
			exec : function( editor )
			{
				if (confirm(editor.lang.qwikiflowchart.cancelmsg))
					editor.execCommand( 'provisarea' );
				else
					// IE7 somehow selects the flowchart element in the editor here,
					// thus theoretically allowing the user to accidentally delete it.
					// Blurring the iframe seems to deselect the element, too.
					$('#cke_contents_topic iframe').first().blur();
			},
			canUndo : false
		},
		provisresize :
		{
			exec : function( editor, data )
			{
				var holderElement = editor.getThemeSpace("contents");
				data = data.substr(0,data.indexOf("%")) || 50;
				data = parseFloat(data);
				
				var provisSize = data;
				var textSize = (100 - data);
				//alert(textSize);
				
				//Bestehendes Textfeld auf 30% reduzieren
				holderElement.getChild(0).setStyle( 'width', textSize + "%");
				holderElement.getChild(2).setStyle( 'width', provisSize + "%")
			},
			canUndo : false
		}
	}
};



/**
 * TODO: Neu schreiben und kommentieren
 * The list of fonts names to be displayed in the Font combo in the toolbar.
 * Entries are separated by semi-colons (;), while it's possible to have more
 * than one font for each entry, in the HTML way (separated by comma).
 *
 * A display name may be optionally defined by prefixing the entries with the
 * name and the slash character. For example, "Arial/Arial, Helvetica, sans-serif"
 * will be displayed as "Arial" in the list, but will be outputted as
 * "Arial, Helvetica, sans-serif".
 * @type String
 * @example
 * config.font_names =
 *     'Arial/Arial, Helvetica, sans-serif;' +
 *     'Times New Roman/Times New Roman, Times, serif;' +
 *     'Verdana';
 * @example
 * config.font_names = 'Arial;Times New Roman;Verdana';
 */
CKEDITOR.config.provis_nodes =
	'Start/prozesse_start.gif;' +
	'Prozessschritt/prozesse_prozess.gif;' +
	'Entscheidung/prozesse_entscheidung.gif;' +
	'Kommentar/prozesse_prozess.gif;' +
	'Knotenpunkt/prozesse_prozess.gif;' +
	'Datenbank/prozesse_datenbank.gif;' +	
	'Dokument/prozesse_dokument.gif;' +	
	'Ende/prozesse_ende.gif;';


/**
 * The text to be displayed in the Font combo is none of the available values
 * matches the current cursor position or text selection.
 * @type String
 * @example
 * // If the default site font is Arial, we may making it more explicit to the end user.
 * config.font_defaultLabel = 'Arial';
 */
CKEDITOR.config.provis_defaultLabel = 'Prozessschritt';

/**
 * The style definition to be used to apply the font in the text.
 * @type Object
 * @example
 * // This is actually the default value for it.
 * CKEDITOR.config.Prozessschritt_style =
 *     {
		element		: 'span',
		styles		: { 'padding-left' : '28px', 'background-repeat' : 'no-repeat', 'background-image' : 'url(#imageurl)', 'padding-right' : '28px' }
		};
 */
CKEDITOR.config.Prozessschritt_style =
	{
		element		: 'span',
		styles		: { 'background-repeat' : 'no-repeat'}
	};

/**
 * TODO: Beschreibung
 * 
 */

CKEDITOR.config.provis_size =
	'25%;' +
	'33%;' +
	'50%;' +
	'66%;' +
	'100%;';


/**
 * The text to be displayed in the Font combo is none of the available values
 * matches the current cursor position or text selection.
 * @type String
 * @example
 * // If the default site font is Arial, we may making it more explicit to the end user.
 * config.font_defaultLabel = 'Arial';
 */
CKEDITOR.config.provis_sizedefaultLabel = '66%';

/**
 * The style definition to be used to apply the font in the text.
 * @type Object
 * @example
 * // This is actually the default value for it.
 * config.font_style =
 *     {
 *         element		: 'span',
 *         styles		: { 'font-family' : '#(family)' },
 *         overrides	: [ { element : 'font', attributes : { 'face' : null } } ]
 *     };
 */
CKEDITOR.config.Size_style =
	{
		element		: 'span',
		styles		: { 'padding-left' : '2px' }
	};



CKEDITOR.config.provis_saveoptions =
	'Rahmen;' +
	'Einfache Trennlinien;' +
	'Ohne Rahmen;';


/**
 * The text to be displayed in the Font combo is none of the available values
 * matches the current cursor position or text selection.
 * @type String
 * @example
 * // If the default site font is Arial, we may making it more explicit to the end user.
 * config.font_defaultLabel = 'Arial';
 */
CKEDITOR.config.provis_saveoptionsdefaultLabel = 'Rahmen';

/**
 * The style definition to be used to apply the font in the text.
 * @type Object
 * @example
 * // This is actually the default value for it.
 * config.font_style =
 *     {
 *         element		: 'span',
 *         styles		: { 'font-family' : '#(family)' },
 *         overrides	: [ { element : 'font', attributes : { 'face' : null } } ]
 *     };
 */
CKEDITOR.config.Saveoptions_style =
	{
		element		: 'span',
		styles		: { 'padding-left' : '2px' }
	};




