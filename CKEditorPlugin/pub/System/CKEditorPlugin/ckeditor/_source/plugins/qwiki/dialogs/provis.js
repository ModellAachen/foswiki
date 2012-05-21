/*
Copyright (c) 2003-2010, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

CKEDITOR.dialog.add( 'provis', function( editor )
{
	var hasJava = true;
	if (typeof navigator.javaEnabled == 'function') {
		if (!navigator.javaEnabled()) hasJava = false;
	} else if (typeof window.clientInformation.javaEnabled == 'function') {
		if (!window.clientInformation.javaEnabled()) hasJava = false;
	}
	var javaHint = hasJava ? '' : '<div style="margin-top:1em;">'+editor.lang.qwiki.flowchartJavaWarning+'</div>';

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
										hidden : 'true',
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
											this.setValue(this.getValue().replace(/[^A-Z0-9_-]/ig, ''));
											this.allowOnChange = true;

										},
										onChange : function()
										{
											if ( this.allowOnChange )		// Dont't call on dialog load.
												this.onKeyUp();
										},
										validate : function()
										{
											var dialog = this.getDialog();

											var func = CKEDITOR.dialog.validate.regex( /^[A-Z0-9_-]*$/i, editor.lang.qwikiflowchart.invalidName );
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
											var name = this.getValue();
											data.name = name;
											this.allowOnChange = false;
										}
									},
									{
										id : 'name_expl',
										type : 'html',
										html : '<div style="font-weight:bold;">'+ editor.lang.qwikiflowchart.specialCharsHint +
											'</div><div>'+ editor.lang.qwikiflowchart.autoGenerateHint +'</div>'+ javaHint
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
								hidden : true,
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
			this.getContentElement( 'info', 'name' ).focus();
			this.valueChecked = false;
		},
		onOk : function()
		{
			var dialog = this;
			var el = dialog.getContentElement('info', 'name');

			var onRealOk = function() {
				var data = {};

				this.commitContent( data );

				var name = data.name || "ProVis_";
					var type = data.type || "Swimlane";
					var rev = data.rev || 1;
				var aqmrev = data.aqmrev || rev,
					maprev = data.maprev || rev,
					pngrev = data.pngrev || rev;

				var element = CKEDITOR.dom.element.createFromHtml( '<span class="WYSIWYG_PROTECTED">%PROCESS{'+
					'name=&quot;'+ name +'&quot; type=&quot;'+ type +'&quot;'+
					'aqmrev=&quot;'+ aqmrev +'&quot; maprev=&quot;'+ maprev +'&quot; pngrev=&quot;'+ pngrev +'&quot;}%</span>' );

				// Set name.
				element.removeAttribute( '_cke_saved_name' );

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

				var fakeElement = editor.createFakeElement( element, 'cke_provis', 'provis', false);
				fakeElement.setAttribute('src', imgSrc);

				fakeElement.setAttribute('_cke_provis_name', name);
				fakeElement.setAttribute('_cke_provis_type', type);

				fakeElement.setAttribute('_cke_provis_aqmrev', aqmrev);
				fakeElement.setAttribute('_cke_provis_maprev', maprev);
				fakeElement.setAttribute('_cke_provis_pngrev', pngrev);

				editor.insertElement( fakeElement );
				return true;
			};
			if (this.valueChecked || el.getValue() == '') return onRealOk.apply(dialog, []);

			var allGood = function() {
				$.unblockUI();
				dialog.valueChecked = true;
				dialog.getButton('ok').click();
			};
			var keepGuessing = function() {
				$.unblockUI();
			}

			$.blockUI();
			var url = FoswikiCKE.getFoswikiVar('SCRIPTURL') + '/rest/ProVisPlugin/check_exists';
			var data = {
				topic: FoswikiCKE.getFoswikiVar('WEB')+'.'+FoswikiCKE.getFoswikiVar('TOPIC'),
				drawing: el.getValue()
			};
			$.ajax({
				type: 'POST',
				url: url,
				data: data,
				dataType: 'json',
				success: function(resp) {
					if (!resp.exists) return allGood();
					if (resp.mayLose) return confirm(editor.lang.qwikiflowchart.warnOverwriteMayLose + resp.foundFiles.join(', ')) ? allGood() : keepGuessing();
					return confirm(editor.lang.qwikiflowchart.warnOverwrite) ? allGood() : keepGuessing();
				},
				error: function(xhr, textStatus, errorThrown) {
					alert(editor.lang.qwikiflowchart.warnCouldNotCheckName + (errorThrown || textStatus));
					keepGuessing();
				}
			});
			return false;
		}
	};
});

