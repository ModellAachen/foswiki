/*
Copyright (c) 2003-2010, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

/**
 * @fileSave plugin.
 */

(function()
{
	var abortingEdit = true;

	var saveCmd =
	{
		modes : { wysiwyg:1,source:1 },

		exec : function( editor )
		{
			$('#save').click();
		}
	};

	var doFinalSubmit = function(editor, form)
	{
		editor.updateElement();
		if (typeof StrikeOne == 'object') StrikeOne.submit(form);
		var action = abortingEdit ? 'cancel' : 'save';
		$(form).find('input[name=action]').val(action);
		form.submit();
	}

	var saveHandler = function(e) {
		if (!foswiki.Edit.validateSuppressed &&
				!foswiki.Edit.validateMandatoryFields())
			return false;

		// Use saveCallback to restore secret comment if necessary
		var editor = e.data;
		var $form = editor.element.$.form;
		$.blockUI();
		abortingEdit = false;
		var html = FoswikiCKE.saveCallback(editor, editor.getData());
		if (html) {
			editor.setData(html, function() {
				doFinalSubmit(editor, $form);
			});
		} else {
			doFinalSubmit(editor, $form);
		}
		return false;
	};

	var unloadHandler = function(e) {
		// CKEditor's checkDirty() likes to deliver both false positives and
		// false negatives, so simply complain unconditionally for now
		if (abortingEdit) {
			var warning = e.data.lang.qwikisave.warning;
			var oe = e.originalEvent || window.event;
			if (oe) oe.returnValue = warning;
			return warning;
		}
		return;
	}

	var cancelCmd =
	{
		modes : { wysiwyg:1, source:1 },

		exec : function( editor )
		{
			$('#cancel').click();
		}
	};

	var pluginName = 'qwikisave';

	// Register a plugin named "save".
	CKEDITOR.plugins.add( pluginName,
	{
		lang : [ 'de', 'en' ],
		init : function( editor )
		{
			var form = editor.element.$.form;
			if (!form) return;

			$('#save').on('click', null, editor, saveHandler);
			$(window).on('beforeunload', null, editor, unloadHandler);

			var command = editor.addCommand( 'save', saveCmd );
			editor.ui.addButton( 'Save',
				{
					label : editor.lang.save,
					command : 'save'
				});

			//Abbrechen
			editor.addCommand( 'cancel', cancelCmd );
			editor.ui.addButton( 'Cancel',
				{
					label	: editor.lang.common.cancel,
					command : 'cancel',
					icon	: this.path + 'images/icon_close.gif'
				});
		}
	});
})();
