/*
Copyright (c) 2003-2012, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

CKEDITOR.plugins.setLang( 'qwikiprovisarea', 'en',
{
	qwikiflowchart: {
		title			: 'Flowchart',
		contextmenu		: 'Edit Flowchart',
		name			: 'Internal Name',
		type			: 'Flowchart Type',
		specialCharsHint: 'You may only use letters (no special characters) and digits here.',
		autoGenerateHint: 'If you leave this field blank, a name will be automatically generated.',
		invalidName		: 'The specified internal name is invalid. Please use only letters (no special characters) and digits.',
		warnOverwriteMayLose : 'Warning: you have existing attachments with corresponding names. If you continue, the following files will be overwritten: ',
		warnOverwrite	: 'There is an existing flowchart with the same name. If you continue, it will be included here. Changes will also affect other instances of the same flowchart.',
		warnCouldNotCheckName : 'Warning: Could not check whether the name is available. Please try again. Internal error code: ',
		swimlane		: 'Swim Lane Diagram',
		process1		: 'Active Process Diagram',
		organigram		: 'Organigram',
		example			: 'Example',
		save			: 'Save Flowchart',
		cancel			: 'Cancel Editing',
		newdiagram		: 'Create New Diagram',
		newswimlane		: 'Insert New Swim Lane',
		undo			: 'Undo ProVis Operation',
		redo			: 'Redo ProVis Operation',
		nodes			: 'Process Types',
		resize			: 'ProVis Window Size',
		saveoptions		: 'Save Options',
		cancelmsg		: 'You are leaving ProVis without saving',
		saveerror		: 'The following errors occurred while trying to save the diagram: '
	}
});
