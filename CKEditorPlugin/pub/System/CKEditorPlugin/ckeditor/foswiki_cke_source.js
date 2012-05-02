/*
  Copyright (C) 2007 Crawford Currie http://wikiring.com and Arthur Clemens
  All Rights Reserved.iny

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either version 2
  of the License, or (at your option) any later version. For
  more details read LICENSE in the root of the Foswiki distribution.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  As per the GPL, removal of this notice is prohibited.
*/

// The FoswikiCKE class object
var FoswikiCKE = {

    foswikiVars : null,
    metaTags : null,

    tml2html : new Array(), // callbacks, attached in plugins
    html2tml : new Array(), // callbacks, attached in plugins
    
    instanceLoaded : false,

    // Get a Foswiki variable from the set passed
    getFoswikiVar : function (name) {
        if (FoswikiCKE.foswikiVars == null) {
        	//Alex: Variablen der aktuellen Instanz auslesen. Instanz sollte ggf. bei Installation übergeben werden...
        	var sets = CKEDITOR.instances.topic.config.foswiki_vars;
            //alert(sets);
            FoswikiCKE.foswikiVars = eval(sets);
        }

        return FoswikiCKE.foswikiVars[name];
    },

    expandVariables : function(url) {
        for (var i in FoswikiCKE.foswikiVars) {
            url = url.replace('%' + i + '%', FoswikiCKE.foswikiVars[i], 'g');
        }
        return url;
    },

    saveEnabled: 0,
    enableSaveButton: function(enabled) {
        var status = enabled ? null : "disabled";
        FoswikiCKE.saveEnabled = enabled ? 1 : 0;
        var elm = document.getElementById("save");
        if (elm) {
            elm.disabled = status;
        }
        elm = document.getElementById("quietsave");
        if (elm) {
            elm.disabled = status;
        }
        elm = document.getElementById("checkpoint");
        if (elm) {
            elm.disabled = status;
        }
        elm = document.getElementById("preview");
        if (elm) {
            elm.style.display = 'none'; // Item5263: broken preview
            elm.disabled = status;
        }
    },
    
    hideSaveButtons: function() {
    	//Alex: Aktuell doppelt gemoppelt
    	return;
    	
    	var elm = document.getElementsByClassName("patternActionButtons")[0];
        if (elm) {
            elm.style.display = 'none';
        }
        var elm = document.getElementById("save");
        if (elm) {
            elm.style.display = 'none';
        }
        elm = document.getElementById("quietsave");
        if (elm) {
            elm.style.display = 'none';
        }
        elm = document.getElementById("checkpoint");
        if (elm) {
            elm.style.display = 'none';
        }
        elm = document.getElementById("cancel");
        if (elm) {
            elm.style.display = 'none';
        }
        elm = document.getElementById("preview");
        if (elm) {
            elm.style.display = 'none'; // Item5263: broken preview
            elm.disabled = status;
        }
    },

    transform : function(editor, handler, text, onSuccess, onError) {
        // Work out the rest URL from the location
        var url = FoswikiCKE.getFoswikiVar("SCRIPTURL");
        var suffix = FoswikiCKE.getFoswikiVar("SCRIPTSUFFIX");
        if (suffix == null) suffix = '';
        url += "/rest" + suffix + "/WysiwygPlugin/" + handler;
        var path = FoswikiCKE.getFoswikiVar("WEB") + '.'
        + FoswikiCKE.getFoswikiVar("TOPIC");
        
        //Alex: HttpRequest an WysiwygPlugin
        //Ggf. Request wiederholen?
        var loaded = false;
        var a = CKEDITOR.qwikiajax.createXMLHttpRequest();
        
        a.open("POST", url, true);
        // Modac : Alles ausgrauen
        $.blockUI();

        a.setRequestHeader('Content-type', "application/x-www-form-urlencoded");
        a.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
        
        var data = "nocache=" + encodeURIComponent((new Date()).getTime())
        + "&topic=" + encodeURIComponent(path)
        + "&text=" + encodeURIComponent(text);
        a.send(data);
        
        a.onreadystatechange = function () {
            if (a.readyState == 4) {
            	if ( a.status == 200 ) { 
            		onSuccess('' + a.responseText);
            		// Modac : Eingaben erlauben
            		$.unblockUI();
            	} 
            	else { 
            	    onError('' + a.status); 
            	    // Modac : Eingaben erlauben
            	    $.unblockUI();
            	} 
            }
        };
        a.close;
    },

    initialisedFromServer : false,

    // Set up content for the initial edit
    setUpContent : function(editor) {
        // If we haven't done it before, then transform from TML
        // to HTML. We need this test so that pressing the 'back'
        // button from a failed save doesn't banjax the old content.
    	
        //if (FoswikiCKE.initialisedFromServer) return;
        FoswikiCKE.switchToWYSIWYG(editor);
        FoswikiCKE.initialisedFromServer = true;
    },

    cleanBeforeSave : function (eid, buttonId) {
        var el = document.getElementById(buttonId);
        if (el == null)
            return;
        // SMELL: what if there is already an onclick handler?
        el.onclick = function () {
        	//Alex: Instanzen müssen dynamisch übergeben werden
            var editor = CKEDITOR.instances.topic;
            editor.resetDirty();
            return true;
        }
    },

    onSubmitHandler : false,

    // Convert HTML content to textarea. Called from the WYSIWYG->raw switch
    switchToRaw : function (editor) {
        
    	var text = editor.getData();

        // Make the raw-edit help visible (still subject to toggle)
        var el = document.getElementById("FoswikiCKEPluginWysiwygEditHelp");
        if (el) {
            el.style.display = 'none';
        }
        el = document.getElementById("FoswikiCKEPluginRawEditHelp");
        if (el) {
            el.style.display = 'block';
        }

        // Evaluate post-processors attached from plugins
        //for (var i = 0; i < FoswikiCKE.html2tml.length; i++) {
        //    var cb = FoswikiCKE.html2tml[i];
        //    text = cb.apply(editor, [ editor, text ]);
        //}
        
        FoswikiCKE.enableSaveButton(false);
        //editor.getElement().value =
         //   "Please wait... retrieving page from server.";
        FoswikiCKE.transform(
            editor, "html2tml", text,
            function (text) {
                editor.setData(text);
                editor.resetDirty();
                FoswikiCKE.enableSaveButton(true);
            },
            function (status) {
                editor.setData("<div class='foswikiAlert'>"
                                + "There was a problem retrieving "
                                + status + "</div>");
                //FoswikiCKE.enableSaveButton(true); leave save disabled
            });
        
        FoswikiCKE.enableSaveButton(true);

        // Add the button for the switch back to WYSIWYG mode
        var eid = "111";
        var id = eid + "_2WYSIWYG";
        var el = document.getElementById(id);
        if (el) {
            // exists, unhide it
            el.style.display = "block";
        } else {
            // does not exist, create it
            el = document.createElement('INPUT');
            el.id = id;
            el.type = "button";
            el.value = "WYSIWYG";
            el.className = "foswikiButton";
            el.onclick = function () {
                // Make the wysiwyg help visible (still subject to toggle)
                var el = document.getElementById("FoswikiCKEPluginWysiwygEditHelp");
                if (el) {
                    el.style.display = 'block';
                }
                el = document.getElementById("FoswikiCKEPluginRawEditHelp");
                if (el) {
                    el.style.display = 'none';
                }
                CKEDITOR.execCommand("mceToggleEditor", null, eid);
                FoswikiCKE.switchToWYSIWYG(editor);
                return false;
            }
            // Need to insert after to avoid knackering 'back'
            //var pel = editor.getElement().parentNode;
            //pel.insertBefore(el, editor.getElement());
        }
        // SMELL: what if there is already an onchange handler?
        //editor.getElement().onchange = function() {
        //    var editor = CKEDITOR.getInstanceById(eid);
        //    editor.isNotDirty = false;
        //    return true;
        //},
        // Ooo-err. Stomp on the default submit handler and
        // forcibly disable the editor to prevent a call to
        // the TMCE save. This in turn blocks the getContent
        // that would otherwise wipe out the content of the
        // textarea with the DOM. We'd better make damn sure we
        // remove this handler when we switch back!
        
        //this.onSubmitHandler = function(ed, e) {
            // SMELL: Editor.initialized is undocumented and liable
            // to break when we upgrade TMCE
        //    editor.initialized = false;
        //};
        // SMELL: Event.addToTop() is undocumented and liable
        // to break when we upgrade TMCE
        //editor.onSubmit.addToTop(this.onSubmitHandler);
        // Make the save buttons mark the text as not-dirty 
        // to avoid the popup that says "Are you sure? The changes you have made will be lost"
        FoswikiCKE.cleanBeforeSave(eid, "save");
        FoswikiCKE.cleanBeforeSave(eid, "quietsave");
        FoswikiCKE.cleanBeforeSave(eid, "checkpoint");
        // preview shouldn't get the popup either, when preview is enabled one day
        FoswikiCKE.cleanBeforeSave(eid, "preview"); 
        // cancel shouldn't get the popup because the user just *said* they want to cancel
		// Actually, we'll want to make sure anyway, just in case the user misunderstood
		// the purpose of the cancel button or something
        // FoswikiCKE.cleanBeforeSave(eid, "cancel"); 
    },

    // Convert textarea content to HTML. This is invoked from the content
    // setup handler, and also from the raw->WYSIWYG switch
    switchToWYSIWYG : function (editor) {
        // Kill the change handler to avoid excess fires
        // editor.getElement().onchange = null;

        // Get the textarea content
    	// Alex - gibt´s hier keine elegante Lösung über den Editor itself?
    	var text = document.getElementById("topic").value;
    	
        FoswikiCKE.enableSaveButton(false);
        editor.setData("<span class='foswikiAlert'>"
                         + "Please wait... retrieving page from server."
                         + "</span>");
        FoswikiCKE.transform(
            editor, "tml2html", text,
            function (neuertext) { // Success
            	// Evaluate any registered pre-processors
                //for (var i = 0; i < FoswikiCKE.tml2html.length; i++) {
                //    var cb = FoswikiCKE.tml2html[i];
                //    text = cb.apply(this, [ this, text ]);
                //}
                /* SMELL: Work-around for Item2270. In future this plugin may
                   be updated so that this needs to be changed. TMCE's wordcount
                   plugin limits itself to a max. of one count per
                   2 seconds, so users always see a wordcount of 6 (Please
                   wait... retrieving page from server) when they first edit a
                   document. So remove lock before setContent() */
            	
                editor.setData(neuertext);
				// resetDirty frequently won't work at this point in IE,
				// probably due to it trying to access elements that IE
				// hasn't loaded yet. So, use an ugly hack to prevent it from
				// trying to access those elements. --jk
				editor.mayBeDirty = false;
				editor.resetDirty();
				editor.mayBeDirty = true;
                FoswikiCKE.enableSaveButton(true);
            },
            function (status) {
                // Handle a failure
            	//alert("Misserfolg");
                editor.setData("<div class='foswikiAlert'>"
                                + "There was a problem retrieving "
                                + "data: "
                                + " " + status + "</div>");
                //FoswikiCKE.enableSaveButton(true); leave save disabled
            });
        
        //Alex: Ändern
        var eid = "111";
        FoswikiCKE.cleanBeforeSave(eid, "save");
        FoswikiCKE.cleanBeforeSave(eid, "quietsave");
        FoswikiCKE.cleanBeforeSave(eid, "checkpoint");
        // preview shouldn't get the popup either, when preview is enabled one day
        FoswikiCKE.cleanBeforeSave(eid, "preview"); 
        // cancel shouldn't get the popup because the user just *said* they want to cancel
		// Actually, we'll want to make sure anyway, just in case the user misunderstood
		// the purpose of the cancel button or something
        // FoswikiCKE.cleanBeforeSave(eid, "cancel"); 
        
    },

    // Callback on save. Make sure the WYSIWYG flag ID is there.
    saveCallback: function(editor, html) {
        // Evaluate any registered post-processors
    	// Modac: TODO: Hier sollte die richtige Instanz schon immer übergeben werden!
        var secret_id = editor.config.foswiki_secret_id;
        if (secret_id != null && 
                html.indexOf('<!--' + secret_id + '-->') == -1) {
            // Something ate the ID. Probably IE. Add it back.
            html = '<!--' + secret_id + '-->' + html;
        }
        return html;
    },

    // Called 
    // Called on URL insertion, but not on image sources. Expand Foswiki
    // variables in the url.
    convertLink : function(url, node, onSave){
    	if(onSave == null)
            onSave = false;
        var orig = url;
        var pubUrl = FoswikiCKE.getFoswikiVar("PUBURL");
        var vsu = FoswikiCKE.getFoswikiVar("VIEWSCRIPTURL");
        url = FoswikiCKE.expandVariables(url);
        if (onSave) {
            if ((url.indexOf(pubUrl + '/') != 0) &&
                (url.indexOf(vsu + '/') == 0)) {
                url = url.substr(vsu.length + 1);
                url = url.replace(/\/+/g, '.');
                if (url.indexOf(FoswikiCKE.getFoswikiVar('WEB') + '.') == 0) {
                    url = url.substr(FoswikiCKE.getFoswikiVar('WEB').length + 1);
                }
            }
        } else {
            if (url.indexOf('/') == -1) {
                // if it's a wikiword, make a suitable link
                var match = /^((?:\w+\.)*)(\w+)$/.exec(url);
                if (match != null) {
                    var web = match[1];
                    var topic = match[2];
                    if (web == null || web.length == 0) {
                        web = FoswikiCKE.getFoswikiVar("WEB");
                    }
                    web = web.replace(/\.+/g, '/');
                    web = web.replace(/\/+$/, '');
                    url = vsu + '/' + web + '/' + topic;
                }
            }
        }
        return url;
    },

    // Called from Insert Image, when the image is inserted. The resultant
    // URL is only used when displaying the image in the picture dialog. It
    // is thrown away (reverts to the typed address) when the image is
    // actually inserted, at which time convertLink is called.
    convertPubURL : function(url){
        url = FoswikiCKE.expandVariables(url);
        if (url.indexOf('/') == -1) {
            var base = FoswikiCKE.getFoswikiVar("PUBURL") + '/'
                + FoswikiCKE.getFoswikiVar("WEB") + '/'
                + FoswikiCKE.getFoswikiVar("TOPIC") + '/';
            url = base + url;
        }
        return url;
    },

    getMetaTag : function(inKey) {
        if (FoswikiCKE.metaTags == null || FoswikiCKE.metaTags.length == 0) {
            // Do this the brute-force way because of the Firefox problem
            // seen sporadically on Bugs where the DOM appears complete, but
            // the META tags are not all found by getElementsByTagName
            var head = document.getElementsByTagName("META");
            head = head[0].parentNode.childNodes;
            FoswikiCKE.metaTags = new Array();
            for (var i = 0; i < head.length; i++) {
                if (head[i].tagName != null &&
                    head[i].tagName.toUpperCase() == 'META') {
                    FoswikiCKE.metaTags[head[i].name] = head[i].content;
                }
            }
        }
        return FoswikiCKE.metaTags[inKey]; 
    },
    
    // Alex: Hier müssen Custom Config Werte übergeben werden - ggf. über eine Config.js Datei...
    install : function() {
        var editor = null;
        cke_init = FoswikiCKE.init;
        if (cke_init != null) {
        	
        	// TODO: JQuery Implementation Überprüfen
        	if (typeof jQuery == "function")
        	{
        		$('textarea#topic').ckeditor(function() {
	        		//Inhalte von TML nach Html Parsen (Nach dem Laden des Editors)
				editor = $('textarea#topic').ckeditorGet();
				FoswikiCKE.hideSaveButtons();
				FoswikiCKE.setUpContent(editor);
			}, cke_init);
	            	return;
        	}
        	else
        	{
	        	// Editor initialisieren mit den Config Elementen aus der CKEPlugin.pm
	        	eval("CKEDITOR.replace('text', {" + unescape(cke_init) + "});");
	        	
	        	//Inhalte von TML nach Html Parsen (Nach dem Laden des Editors
	        	CKEDITOR.on("instanceReady", function(event)
	        			{
	        				FoswikiCKE.hideSaveButtons();
	        				editor = event.editor;
	        				
	        				setTimeout(function(){
	        					FoswikiCKE.setUpContent(editor);
							});
	        				CKEDITOR.instances.topic.resetDirty();
	        			});
        	}
        	
        	return;
        }
        alert("Unable to install CKEDITOR; <META name='CKEDITORPLUGIN_INIT' is missing"); 
    },

    getTopicPath: function() {
        return this.getFoswikiVar("WEB") + '.' + this.getFoswikiVar("TOPIC");
    },
    
    getWeb: function() {
        return this.getFoswikiVar("WEB");
    },
    
    getTopic: function() {
        return this.getFoswikiVar("TOPIC");
    },

    getScriptURL: function(script) {
        var scripturl = this.getFoswikiVar("SCRIPTURL");
        var suffix = this.getFoswikiVar("SCRIPTSUFFIX");
        if (suffix == null) suffix = '';
        return scripturl + "/" + script + suffix;
    },

    getRESTURL: function(fn) {
        return this.getScriptURL('rest') + "/WysiwygPlugin/" + fn;
    },

    getListOfAttachments: function(onSuccess) {
        var url = this.getRESTURL('attachments');
        var path = this.getTopicPath();
        path = "Main.WebAttachments";
        var params = "nocache=" + encodeURIComponent((new Date()).getTime())
        + "&topic=" + encodeURIComponent(path);
        
        var a = CKEDITOR.qwikiajax.createXMLHttpRequest();
        var loaded = false;
        
        a.open("POST", url + "?" + params, true);
        a.onreadystatechange = function () {
        	if (a.readyState == 4) {
            	if ( a.status == 200 ) { 
            		onSuccess('' + a.responseText); 
            		loaded = true;
            	} 
            	else { 
            	    onError(a, a.status); 
            	} 
            }
        };
        
        a.setRequestHeader('Content-type', "application/x-www-form-urlencoded");
        a.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
        
        var data = params;
        a.send(data);
        
        var i = 1;
        //Alex: Schleife um auf das Ajax Ergebnis zu warten
        while (loaded == false && i<25)
        {
        	setTimeout(function(){i++;}, 100);
        }
        
        a.close;
    },
    
    ajaxRequest: function(url, request, onSuccess, onError) {
        
    	var moreparams = request || '';
    	var params = "nocache=" + encodeURIComponent((new Date()).getTime()) + moreparams;
        
        var a = CKEDITOR.qwikiajax.createXMLHttpRequest();
        var loaded = false;
        
        a.open("POST", url + "?" + params, true);
        a.onreadystatechange = function () {
        	if (a.readyState == 4) {
            	if ( a.status == 200 ) { 
            		onSuccess('' + a.responseText); 
            		loaded = true;
            	} 
            	else { 
            	    onError(a, a.status); 
            	} 
            }
        };
        
        a.setRequestHeader('Content-type', "application/x-www-form-urlencoded");
        a.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
        
        var data = params;
        a.send(data);
        
        var i = 1;
        //Alex: Schleife um auf das Ajax Ergebnis zu warten
        while (loaded == false && i<25)
        {
        	setTimeout(function(){i++;}, 100);
        }
        
        a.close;
    }
    
};
