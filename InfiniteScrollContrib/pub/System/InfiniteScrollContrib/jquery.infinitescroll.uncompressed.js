/*
	--------------------------------
	Infinite Scroll
	--------------------------------
	+ https://github.com/paulirish/infinitescroll
	+ version 2.0b2.110603
	+ Copyright 2011 Paul Irish & Luke Shumard
	+ Licensed under the MIT license
	
	+ Documentation: http://infinite-scroll.com/
	
*/

(function(window, $) {
	
	$.infinitescroll = function(options, callback, element) {
		
		this.element = $(element);
		this._create(options, callback);
	
	};
	
	$.infinitescroll.defaults = {
		callback: function() { },
		debug: false,
		binder: undefined,
		nextSelector: "div.navigation a:first",
		loadingImg: "loading.gif",
		loadingText: "<em>Loading the next page...</em>",
		loadingStart: null,
		loadingEnd: null,
		donetext: "<em>Congratulations, you've reached the end of the internet.</em>",
		navSelector: "div.navigation",
		contentSelector: null, // rename to pageFragment
		loadMsgSelector: null,
		loadingMsgRevealSpeed: 'fast', // controls how fast you want the loading message to come in, ex: 'fast', 'slow', 200 (milliseconds)
		extraScrollPx: 150,
		itemSelector: "div.post",
		animate: false,
		pathParse: undefined,
		dataType: 'html',
		appendCallback: true,
		bufferPx: 40,
		errorCallback: function() { },
		currPage: 1,
		infid: 0, //Instance ID
		isDuringAjax: false,
		isInvalidPage: false,
		isDestroyed: false,
		isDone: false, // For when it goes all the way through the archive.
		isPaused: false,
		path: undefined,
		loadingMsg: undefined,
                localMode: false,
                zeroBased: false
	};


    $.infinitescroll.prototype = {

        /*	
        ----------------------------
        Private methods
        ----------------------------
        */

        _create: function(options, callback) {

            // Define options and shorthand
            var opts = this.options = $.extend({}, $.infinitescroll.defaults, options);
           
            // contentSelector is 'page fragment' option for .load() / .ajax() calls
            opts.contentSelector = opts.contentSelector || this.element;

            // loadMsgSelector - if we want to place the load message in a specific selector, defaulted to the contentSelector
            opts.loadMsgSelector = opts.loadMsgSelector || opts.contentSelector;

            // get the next page URL 
            opts.path = $(opts.nextSelector).attr('href');

            // if there's not path, return
            if (!opts.path) { 
              this._debug('Navigation ',opts.nextSelector,' selector not found'); 
              return; 
            }

            // init page counter
            opts.currPage = opts.zeroBased?0:1;

            // Define loadingMsg
            opts.loadingMsg = $('<div class="infscr-loading"><img alt="Loading..." src="' + opts.loadingImg + '" /><div>' + opts.loadingText + '</div></div>');

            // Preload loadingImg
            (new Image()).src = opts.loadingImg;


            // distance from nav links to bottom
            // computed as: height of the document + top offset of container - top offset of nav link
            $(opts.navSelector).hide();

            // callback loading
            // FIX
            opts.callback = callback || function() { };

            // Setup binding
            opts.binder = opts.localMode ? $(opts.contentSelector) : $(window);
            //this._debug("Binding to ",opts.binder);
            this.binding('bind');

        },

        // Console log wrapper
        _debug: function() {

            if (this.options.debug) {
                return window.console && console.log.apply(console, arguments);
            }

        },

        // find the number to increment in the path.
        _determinepath: function(path) {

            var opts = this.options;

            if ($.isFunction(opts.pathParse)) {
                    path = opts.pathParse(path, opts.currPage);
            } else if (path.match(/^(.*?)\b2\b(.*?)$/)) {
                    path = path.match(/^(.*?)\b2\b(.*?)$/).slice(1).join(opts.currPage);
            } else if (path.match(/^(.*?page=)\d+(.*?)$/)) {
                    
                    // if there is any page= in the url at all.    
                    path = path.match(/^(.*?page=)\d+(.*?)$/).slice(1).join(opts.currPage);
            } else {
                    this._debug("Sorry, can't determine pagination");
                    opts.isInvalidPage = true;  //prevent it from running on this page.
            }
            this._debug('determinePath', path);
            return path;
        },

        // Custom error
        _error: function(xhr) {

            var opts = this.options;

            if (xhr !== 'destroy' && xhr !== 'end') {
                xhr = 'unknown';
            }

            this._debug('Error', xhr);

            if (xhr == 'end') {
                this._showdonemsg();
            }

            opts.isDone = true;
            opts.currPage = opts.zeroBased?0:1; // if you need to go back to this instance
            opts.isPaused = false;
            this.binding('unbind');

        },

        // Load Callback
        _loadcallback: function(box, data) {

            var opts = this.options,
                callback = this.options.callback, // GLOBAL OBJECT FOR CALLBACK
                result = (opts.isDone) ? 'done' : (!opts.appendCallback) ? 'no-append' : 'append',
                frag, children;

            opts.loadingMsg.hide();

            switch (result) {

                case 'done':

                    this._showdonemsg();
                    return false;

                case 'no-append':

                    if (opts.dataType == 'html') {
                        data = '<div>' + data + '</div>';
                        data = $(data).find(opts.itemSelector);
                    }

                    break;

                case 'append':

                    children = box.children();

                    // if it didn't return anything
                    if (children.length === 0) {
                        return this._error('end');
                    }


                    // use a documentFragment because it works when content is going into a table or UL
                    frag = document.createDocumentFragment();
                    while (box[0].firstChild) {
                        frag.appendChild(box[0].firstChild);
                    }

                    this._debug('contentSelector', $(opts.contentSelector)[0]);
                    $(opts.contentSelector)[0].appendChild(frag);
                    // previously, we would pass in the new DOM element as context for the callback
                    // however we're now using a documentfragment, which doesnt havent parents or children,
                    // so the context is the contentContainer guy, and we pass in an array
                    //   of the elements collected as the first argument.

                    data = children.get();


                    break;

            }

            // this is where the loadingEnd function goes!!!


            // smooth scroll to ease in the new content
            if (opts.animate) {
                $('html,body').animate({ 
                        scrollTop: $(window).scrollTop() +
                                $('#infscr-loading').height() +
                                opts.extraScrollPx + 'px' 
                }, 800, function() { opts.isDuringAjax = false; });
            }

            if (!opts.animate) {
                opts.isDuringAjax = false; // once the call is done, we can allow it again.
            }

            callback.call($(opts.contentSelector)[0], data);

        },

        _hiddenHeight: function(element) {
                var height = 0;

                element.children().each(function() {
                    height += $(this).height();
                });

                return height;
        },

        _nearbottom: function() {

            var opts = this.options,
                        //documentElement = opts.localMode ? $(opts.contentSelector) : $(document),
                        documentElement = $(opts.contentSelector),
                        documentHeight = opts.localMode ? this._hiddenHeight(documentElement) : documentElement.height(),
                        viewPort = opts.localMode ? $(opts.contentSelector) : $(window),
                        scrollTop = viewPort.scrollTop(),
                        viewPortHeight = viewPort.height();

            this._debug("scrollTop+viewPortHeight=",scrollTop+viewPortHeight,
                        "documentHeight - buffer=",documentHeight - opts.bufferPx);

            return (scrollTop + viewPortHeight > documentHeight - opts.bufferPx);

        },

        // Show done message
        _showdonemsg: function() {

            var opts = this.options;

            opts.loadingMsg
                .find('img')
                .hide()
                .parent()
                .find('div').html(opts.donetext).animate({ opacity: 1 }, 2000, function() {
                        $(this).parent().fadeOut('normal');
                });

            // user provided callback when done    
            opts.errorCallback();

        },


        /*	
        ----------------------------
        Public methods
        ----------------------------
        */

        // Bind or unbind from scroll
        binding: function(binding) {

            var instance = this;

            if (binding !== 'bind' && binding !== 'unbind') {
                this._debug('Binding value  ' + binding + ' not valid');
                return false;
            }

            if (binding == 'unbind') {

                (this.options.binder).unbind('smartscroll.infscr.' + instance.options.infid);

            } else {

                (this.options.binder)[binding]('smartscroll.infscr.' + instance.options.infid, function() {
                    instance.setup();
                });

            }

            //this._debug('Binding', binding);

        },

        // Destroy current instance of plugin
        destroy: function() {

            this.options.isDestroyed = true;
            return this._error('destroy');

        },

        // Pause / temporarily disable plugin from firing
        pause: function(pause) {

            var opts = this.options;

            // If pause is not 'pause' or 'resume', toggle it's value
            if (pause !== 'pause' && pause !== 'resume' && pause !== 'toggle' && pause !== null) {
                this._debug('Invalid argument. Toggling pause value instead');
            }

            pause = (pause && (pause == 'pause' || pause == 'resume')) ? pause : 'toggle';

            switch (pause) {
                case 'pause':
                    opts.isPaused = true;
                    break;

                case 'resume':
                    opts.isPaused = false;
                    break;

                case 'toggle':
                    opts.isPaused = !opts.isPaused;
                    break;
            }

            this._debug('Paused', opts.isPaused);
            return false;

        },

        // Retrieve next set of content items
        retrieve: function(pageNum) {

            var instance = this,
                opts = instance.options,
                debug = instance._debug,
                box, frag, desturl, method, condition,
                getPage = (!!pageNum) ? pageNum : opts.currPage;

            if (opts.isDestroyed) {
                this._debug('Instance already destroyed');
                return false;
            }

            // we dont want to fire the ajax multiple times
            opts.isDuringAjax = true;

            // this is where the loadingStart function goes!!!
            //($.isFunction(opts.loadingStart)) ? opts.loadingStart() : /* default*/ '';

            opts.loadingMsg.appendTo(opts.loadMsgSelector).show(opts.loadingMsgRevealSpeed, function() {

                // increment the URL bit. e.g. /page/3/
                opts.currPage++;

                // if we're dealing with a table we can't use DIVs
                box = $(opts.contentSelector).is('table') ? $('<tbody/>') : $('<div/>');

                desturl = instance._determinepath(opts.path);
                //instance._debug('heading into ajax', desturl);

                // create switch parameter for append / callback
                // MAKE SURE CALLBACK EXISTS???
                method = (opts.dataType == 'html' || opts.dataType == 'json') ? opts.dataType : 'html+callback';
                if (opts.appendCallback && opts.dataType == 'html') {
                        method += '+callback';
                }

                switch (method) {

                    case 'html+callback':

                        instance._debug('Using HTML via .load() method');
                        box.load(desturl + ' ' + opts.itemSelector, null, function(jqXHR, textStatus) {
                            instance._loadcallback(box, jqXHR.responseText);
                        });

                        break;

                    case 'html':
                    case 'json':

                        instance._debug('Using ' + (method.toUpperCase()) + ' via $.ajax() method');
                        $.ajax({
                            // params
                            url: desturl,
                            dataType: opts.dataType,
                            complete: function(jqXHR, textStatus) {

                                condition = (typeof (jqXHR.isResolved) !== 'undefined') ? 
                                        (jqXHR.isResolved()) : 
                                        (textStatus === "success" || textStatus === "notmodified");

                                if(condition) {
                                        instance._loadcallback(box, jqXHR.responseText);
                                } else {
                                        instance._error('end');
                                }
                            }
                        });

                        break;

                }

            });

        },

        // Check to see height left to fire - rename this!!!!
        setup: function() {

            var opts = this.options;

            if (opts.isDuringAjax || opts.isInvalidPage || opts.isDone || opts.isDestroyed || opts.isPaused) {
                return;
            }

            if (!this._nearbottom()) {
                return;
            }

            this.retrieve();

        }

    };


    /*	
    ----------------------------
    Infinite Scroll function
    ----------------------------
	
    Borrowed logic from the following...
	
    jQuery UI
    - https://github.com/jquery/jquery-ui/blob/master/ui/jquery.ui.widget.js
	
    jCarousel
    - https://github.com/jsor/jcarousel/blob/master/lib/jquery.jcarousel.js
	
    Masonry
    - https://github.com/desandro/masonry/blob/master/jquery.masonry.js		
	
    */

    $.fn.infinitescroll = function(options, callback) {


        var thisCall = typeof options, args;

        switch (thisCall) {

            // method 
            case 'string':

                args = Array.prototype.slice.call(arguments, 1);

                this.each(function() {

                    var instance = $.data(this, 'infinitescroll');

                    if (!instance) {
                        // not setup yet
                        // return $.error('Method ' + options + ' cannot be called until Infinite Scroll is setup');
						return false;
                    }
                    if (!$.isFunction(instance[options]) || options.charAt(0) === "_") {
                        // return $.error('No such method ' + options + ' for Infinite Scroll');
						return false;
                    }

                    // no errors!
                    instance[options].apply(instance, args);

                });

                break;

            // creation 
            case 'object':

                this.each(function() {

                    var instance = $.data(this, 'infinitescroll');

                    if (instance) {

                        // go for it
                        // instance._create(options);

                    } else {

                        // initialize new instance
                        $.data(this, 'infinitescroll', new $.infinitescroll(options, callback, this));

                    }

                });

                break;

        }

        return this;

    };



    /* 
    * smartscroll: debounced scroll event for jQuery *
    * https://github.com/lukeshumard/smartscroll
    * Based on smartresize by @louis_remi: https://github.com/lrbabe/jquery.smartresize.js *
    * Copyright 2011 Louis-Remi & Luke Shumard * Licensed under the MIT license. *
    */

    var event = $.event,
		scrollTimeout;

    event.special.smartscroll = {
        setup: function() {
            $(this).bind("scroll", event.special.smartscroll.handler);
        },
        teardown: function() {
            $(this).unbind("scroll", event.special.smartscroll.handler);
        },
        handler: function(event, execAsap) {
            // Save the context
            var context = this,
		      args = arguments;

            // set correct event type
            event.type = "smartscroll";

            if (scrollTimeout) { 
                window.clearTimeout(scrollTimeout); 
            }

            scrollTimeout = window.setTimeout(
                function() {
                        jQuery.event.handle.apply(context, args);
                }, 
                execAsap === "execAsap" ? 0 : 100
            );
        }
    };

    $.fn.smartscroll = function(fn) {
        return fn ? this.bind("smartscroll", fn) : this.trigger("smartscroll", ["execAsap"]);
    };


})(window, jQuery);
