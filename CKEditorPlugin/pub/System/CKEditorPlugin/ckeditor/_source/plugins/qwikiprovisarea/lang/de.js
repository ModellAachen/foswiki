/*
Copyright (c) 2012, Modell Aachen, http://modell-aachen.de/

Kurzreferenz Umlaut-Codes:
ae \u00E4      AE \u00C4
oe \u00F6      OE \u00D6
ue \u00FC      UE \u00DC
ss \u00DF
*/

CKEDITOR.plugins.setLang( 'qwikiprovisarea', 'de',
{
	qwikiflowchart :
	{
		title			: 'Flussdiagramm',
		contextmenu		: 'Flussdiagramm bearbeiten',
		name			: 'Interner Name',
		type			: 'Flussdiagramm-Typ',
		specialCharsHint: 'Sie k\u00F6nnen hier nur Buchstaben (keine Sonderzeichen) und Ziffern benutzen.',
		autoGenerateHint: 'Wenn Sie das Feld leer lassen, wird automatisch ein Name generiert.',
		invalidName		: 'Der angegebene interne Name für das Flussdiagramm ist ung\u00FCltig. Bitte verwenden Sie nur Buchstaben (ohne Sonderzeichen) und Ziffern.',
		warnOverwriteMayLose : 'Achtung: es sind bereits Dateianh\u00E4nge mit entsprechenden Namen vorhanden. Wenn Sie fortfahren, werden folgende Dateien \u00FCberschrieben: ',
		warnOverwrite	: 'Es ist bereits ein Flussdiagram mit diesem Namen vorhanden. Wenn Sie fortfahren, wird es hier eingebunden. \u00C4nderung daran betreffen auch andere Orte, an denen das Flussdiagramm eingebunden wurde.',
		warnCouldNotCheckName : 'Achtung: Es konnte nicht \u00FCberpr\u00FCft werden, ob der Name noch frei ist. Bitte versuchen Sie es noch einmal. Interner Fehlercode: ',
		swimlane		: 'Flussdiagramm',
		process1		: 'Prozessschaubild',
		organigram		: 'Organigramm',
		example			: 'Beispiel',
		save			: 'Flussdiagramm speichern',
		cancel			: 'Bearbeiten abbrechen',
		newdiagram		: 'Neues Diagramm erstellen',
		newswimlane		: 'Neue Schwimmbahn einf\u00FCgen',
		undo			: 'ProVis-Schritt r\u00FCckg\u00E4ngig machen',
		redo			: 'ProVis-Schritt wiederherstellen',
		nodes			: 'Prozesstypen',
		resize			: 'ProVis Fenstergr\u00F6\u00DFe',
		saveoptions		: 'Darstellungsmodus',
		cancelmsg		: 'Sie verlassen nun ProVis, ohne zu speichern',
		saveerror		: 'Beim Speichern des Diagramms sind folgende Fehler aufgetreten: ',
		javaDisabled		: 'In Ihrem Browser ist Java nicht aktiviert. Ohne Java k\u00F6nnen Sie keine Flussdiagramme bearbeiten.'
	}
});
