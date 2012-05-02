/*
Copyright (c) 2012, Modell Aachen, http://modell-aachen.de/
All rights reserved.
*/

CKEDITOR.plugins.add('qwikistyles',
{
	requires : ['styles'],
	lang : ['de', 'en'],

	init : function( editor )
	{
		var l = editor.lang.qwikistyles;
		CKEDITOR.stylesSet.add( 'modellaachen', [
			{ name : l.red,    element : 'span', styles : { 'color' : 'red' } },
			{ name : l.yellow, element : 'span', styles : { 'background-color' : 'yellow' } },
			{ name : l.green,  element : 'span', styles : { 'background-color' : 'lime' } }
		]);
	}
} );


