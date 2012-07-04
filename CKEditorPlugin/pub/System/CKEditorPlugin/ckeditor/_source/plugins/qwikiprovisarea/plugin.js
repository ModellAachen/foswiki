/*
Copyright (c) 2003-2010, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

var flowchart = null;
var lang;

CKEDITOR.plugins.add( 'qwikiprovisarea',
{
	requires : [ 'editingblock', 'richcombo', 'styles' ],
	lang : [ 'de', 'en' ],

	init : function( editor )
	{
		var provisarea = CKEDITOR.plugins.provisarea,
			win = CKEDITOR.document.getWindow(),
			iframe,
			config = editor.config,
			provisframe;

		var maybeSetConfig = function(name, value) {
			if (config[name] === undefined) config[name] = value;
		};

		lang = editor.lang.qwikiflowchart;

		maybeSetConfig('provis_maxWidth', '800');
		maybeSetConfig('provis_minWidth', '300');

		maybeSetConfig('provis_nodes', ['start', 'process', 'decision', 'comment', 'join', 'database', 'document', 'end']);
		maybeSetConfig('provis_defaultnode', 'process');

		maybeSetConfig('provis_sizes', ['25%', '33%', '50%', '66%', '100%']);
		maybeSetConfig('provis_defaultsize', '66%');

		maybeSetConfig('provis_saveoptions', ['frame', 'line', 'noframe']);

		var container = null,
		textcontainer = null,
		proviscontainer = null,
		origin,
		startSize,
		provisSize,
		textSize,
		resizeHorizontal = 1,
		resizeVertical = 0;

		editor.on('doubleclick', function(evt) {
			var element = CKEDITOR.plugins.link.getSelectedLink( editor ) || evt.data.element;

			if ( element.getAttribute( 'data-cke-real-element-type' ) == 'provis' ) {
				var hasJava = true;
				if (typeof navigator.javaEnabled == 'function') {
					if (!navigator.javaEnabled()) hasJava = false;
				} else if (typeof window.clientInformation.javaEnabled == 'function') {
					if (!window.clientInformation.javaEnabled()) hasJava = false;
				}
				if (hasJava) return editor.execCommand('provisarea');
				alert(lang.javaDisabled);
			}
		});

		editor.on( 'closeprovis', function(event) {
			editor = event.editor;
			
			//Provis Attribute auslesen
			var name = flowchart.getAttribute( '_cke_provis_name' );
			var type = flowchart.getAttribute( '_cke_provis_type' ) || 'swimlane';
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

			flowchart = null;
		});

		editor.on( 'openprovis', function(event) {
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
			ibody.append('<div id="cke_provis_block_overlay" style="left: 0; top: 0; background: black; -ms-filter:\'progid:DXImageTransform.Microsoft.Alpha(Opacity=30)\'; filter: alpha(opacity=30); opacity: .3; z-index: 15000; position: fixed;"></div>');
			ibody.find('#cke_provis_block_overlay').height(iframe.innerHeight()).width(iframe.innerWidth());
			if (ibody[0]) ibody[0].contentEditable = "false";
			// Make IE7 deselect flowchart element in editor, so that users
			// cannot accidentally delete it
			iframe.blur();

			if ( element && element.getAttribute( 'data-cke-real-element-type' ) && element.getAttribute( 'data-cke-real-element-type' ) == 'provis' )
			{
				topic = element.getAttribute( '_cke_provis_topic' ) || FoswikiCKE.getFoswikiVar("WEB") + "." + FoswikiCKE.getFoswikiVar("TOPIC");
				name = element.getAttribute( '_cke_provis_name' );
				type = element.getAttribute( '_cke_provis_type' ).toLowerCase() || 'swimlane';
				rev = element.getAttribute( '_cke_provis_aqmrev' ) ||
					element.getAttribute( '_cke_provis_rev' ) || 0;
			}
			else
				return false;

			var holderElement = editor.getThemeSpace("contents");

			startSize = { width : holderElement.$.offsetWidth || 0, height : holderElement.$.offsetHeight || 0 };
			config.provis_maxWidth = startSize.width;
			
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
					' style="width:' + startSize.width + 'px; height:100%; position:relative;"' +
					' frameBorder="0"' +
					' id="iframe_provis"' +
					' src="' + srcScript + '"' +
					' tabIndex="' + editor.tabIndex + '"' +
					' allowTransparency="true"' +
					'></iframe>' );
			
			//Append both divs
			holderElement.append(div);
			holderElement.append(iframe);

			editor.fire('load_provistoolbar');
			editor.execCommand('provisresize', editor.config.provis_defaultsize);

			$(iframe.$).one('load', function(ev) {
				var framewin = document.getElementById("iframe_provis").contentWindow;
				framewin.subscribeEvent('change_shape', function(value) {
					editor.fire("provis_shape", value);
				});
				framewin.subscribeEvent('change_savestyle', function(value) {
					editor.fire("provis_save", value);
				});
				framewin.subscribeEvent('applet_loaded', function() {
					editor.fire("provis_shape", config.provis_defaultnode);
				});
			});
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
					label : lang.save,
					command : 'provissave',
					className : 'cke_button_save'
				});
			editor.ui.addButton( 'Provis_NewDiagram',
				{
					label : lang.newdiagram,
					command : 'provisnewdiagram',
					className : 'cke_button_newpage'
				});
			editor.ui.addButton( 'Provis_NewSwimlane',
				{
					label : lang.newswimlane,
					command : 'provisnewswimlane',
					icon	: this.path + 'images/swimlane_new.gif'
				});
			editor.ui.addButton( 'Provis_Undo',
				{
					label : lang.undo,
					command : 'provisundo',
					className : 'cke_button_undo'
				});
			editor.ui.addButton( 'Provis_Redo',
				{
					label : lang.redo,
					command : 'provisredo',
					className : 'cke_button_redo'
				});
			editor.ui.addButton( 'Provis_DeleteSwimlane',
				{
					label : "Ausgewählte Swimlane löschen",
					command : 'provisdeleteswimlane',
					icon	: this.path + 'images/swimlane_new.gif'
				});
			editor.ui.addButton( 'Provisarea',
				{
					label : lang.cancel,
					command : 'provisabort',
					icon	: this.path + 'images/icon_close.gif'
				});
		}

		var addCombo = function(params) {
			editor.ui.addRichCombo( params.name, {
				label: params.title,
				title: params.title,
				className: params.className || 'cke_provis',
				'default': params.defaultValue,
				panel: {
					css: editor.skin.editor.css.concat(config.contentsCss),
					multiSelect: false,
					attributes: { 'aria-label' : lang.panelTitle }
				},

				init: function() {
					this.startGroup(params.title);

					var combo = this;
					$.each(params.entries, function(_idx, value) {
						var label = value;
						var langVal = params.langBase && lang[params.langBase + value];
						if (langVal) label = langVal;
						var style = 'padding-left: 28px; background-repeat: no-repeat; background-position: left center;';
						if (params.imageNameFormat) style = style + ' background-image:url(\''+
							CKEDITOR.plugins.getPath('qwikiprovisarea') +'images/'+
							params.imageNameFormat.replace('%', value)
							+'\');';
						combo.add(value, '<span style="'+ style +'">'+ label +'</span>', null);
					});
				},

				onClick: function(value) {
					var label = value;
					var langVal = params.langBase && lang[params.langBase + value];
					var combo = this;
					if (langVal) setTimeout(function() { combo.setValue(value, langVal); });
					if (typeof params.onClick == "function") params.onClick(this, value);
				},

				onRender: function() {
					if (typeof params.onRender == "function") params.onRender(this);
				}
			});
		};

		addCombo({
			name: 'Provis_Nodes',
			title: lang.nodes,
			entries: config.provis_nodes,
			defaultValue: config.provis_defaultnode,
			langBase: 'nodes_',
			imageNameFormat: 'nodeicon_%.gif',
			onClick: function(_c, value) {
				document.getElementById('iframe_provis').contentWindow.setShape(value, false);
			},
			onRender: function(combo) {
				editor.on( 'provis_shape', function(ev) {
					this.onClick(ev.data);
				}, combo);
			}
		});

		addCombo({
			name: 'Provis_Size',
			title: lang.resize,
			entries: config.provis_sizes,
			className: 'cke_provis_size',
			defaultValue: config.provis_defaultsize,
			onClick: function(_c, value) {
				editor.execCommand('provisresize', value);
			}
		});

		addCombo({
			name: 'Provis_Saveoptions',
			title: lang.saveoptions,
			entries: config.provis_saveoptions,
			langBase: 'saveoptions_',
			onClick: function(_c, value) {
				document.getElementById('iframe_provis').contentWindow.setSaveStyle(value, false);
			},
			onRender: function(combo) {
				editor.on('provis_save', function(ev) {
					this.onClick(ev.data);
				}, combo);
			}
		});

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
					newtoolbox = editor.fire("themeSpace", {space:'top',html:''}).html;
					top.setHtml(newtoolbox);
				}
				else if ( editor.getCommand( 'provisarea' ).state == 1 )
				{
					editor.fire( 'closeprovis' );
					editor.getCommand( 'provisarea' ).setState( CKEDITOR.TRISTATE_OFF );
					editor.config.toolbar = "Basic";
					newtoolbox = editor.fire("themeSpace", {space:'top',html:''}).html;
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
				iframe.contentWindow.initDiagram(null, true);
			},
			canUndo : false
		},
		provisnewswimlane :
		{
			exec : function( editor )
			{
				var iframe = document.getElementById("iframe_provis");
				iframe.contentWindow.makeNewLane();
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
					css: { top: '20px', left: '20px' }
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
							alert(lang.saveerror + (errorThrown || textStatus));
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
				if (confirm(lang.cancelmsg))
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
				data = data.substr(0,data.indexOf("%")) || 66;
				data = parseFloat(data);
				
				var provisSize = data;
				var textSize = (100 - data);

				//Bestehendes Textfeld auf 30% reduzieren
				holderElement.getChild(0).setStyle( 'width', textSize + "%");
				holderElement.getChild(2).setStyle( 'width', provisSize + "%")
			},
			canUndo : false
		}
	}
};

