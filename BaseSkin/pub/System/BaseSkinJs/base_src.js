var foswiki;
if (!foswiki) {
	foswiki = {};
}

/**
Base script. Handles:
- smooth scrolling
- sticky behaviour
*/


foswiki.base = (function () {

	"use strict";

	var getIdFromAnchorUrl,
		DEFAULT_SCROLL_OFFSET = 30,
		DEFAULT_SCROLL_DURATION = 300,
		DEFAULT_SCROLL_EFFECT = 'easeInOutSine',
		STICKY_CLASS_SELECTOR = '.foswikiMakeSticky';
		
	getIdFromAnchorUrl = function (url) {
		return url.replace(/^[^#]*#?!?(.*)$/, '$1');
	};

	return {

		/**
		opts: hash with id, duration, offset, effect, callback
		*/
		scrollToAnchor: function ($, opts) {
			var el = document.getElementById(opts.id);
			if (!el) {
				return;
			}
			var duration = opts.duration || DEFAULT_SCROLL_DURATION,
				offset = opts.offset || 0,
				top = offset + $(el).offset().top,
				effect = opts.effect || DEFAULT_SCROLL_EFFECT;

			$('html, body').animate({
				scrollTop: top
			}, {
				duration: duration,
				easing: effect,
				complete: opts.callback
			});
		},
		
		/*
		Calculate offset when sticky elements are around. Pass value to scroll options and call scrollToAnchor.
		*/
		smartScrollDealWithStickys: function ($, opts) {
			var $fixedElements = $(STICKY_CLASS_SELECTOR),
				offsetY = -DEFAULT_SCROLL_OFFSET,
				i;
			
			for (i = 0; i < $fixedElements.length; i = i + 1) {
				offsetY -= $($fixedElements[i]).outerHeight();
			}			
			opts.offset = offsetY;
			this.scrollToAnchor($, opts);
		},
		
		handleLocalScroll: function($) {
			var that = this,
				id,
				opts;

			// all links with anchors
			$("a[href*='#']").click(function() {
				id = getIdFromAnchorUrl(this.href);
				that.smartScrollDealWithStickys($, {id: id});
			});

			// also scroll on page load
			id = getIdFromAnchorUrl(location.href);
			if (id) {
				that.smartScrollDealWithStickys($, {id: id});
			}
		},
		
		removeYellowFromInputs: function($) {
			if (navigator.userAgent.toLowerCase().indexOf('chrome') >= 0) {
				var chromechk_watchdog = 0,
					chromechk;
				chromechk = setInterval(function() {
					if ($('input:-webkit-autofill').length > 0) {
						clearInterval(chromechk);
						$('input:-webkit-autofill').livequery(function () {
							var value = $(this).val(),
								name = $(this).attr('name');
							$(this).after(this.outerHTML).remove();
							$('input[name=' + name + ']').val(value);
						});
					} else if (chromechk_watchdog > 20) {
						clearInterval(chromechk);
					}
					chromechk_watchdog++;
				}, 50);
			}
		},
		
		manageDisplay: function($) { 
			var setDisplay = function(classname) {
				$('body').removeClass('foswikiDisplaySpatious').removeClass('foswikiDisplayAverage').removeClass('foswikiDisplayMaxscreen');
				$('body').addClass(classname);
				if (foswiki.Pref) {
					foswiki.Pref.setPref('skinDisplay', classname);
				}
			};
			$('a.foswikiDisplaySpatious,a.foswikiDisplayAverage,a.foswikiDisplayMaxscreen').livequery('click', function (e) {
				var $this = $(this);
				switch ($(this).attr('class')) {
					case 'foswikiDisplaySpatious':
						setDisplay('foswikiDisplaySpatious');
						break;
					case 'foswikiDisplayAverage':
						setDisplay('foswikiDisplayAverage');
						break;
					case 'foswikiDisplayMaxscreen':
						setDisplay('foswikiDisplayMaxscreen');
						break;
				}
				e.preventDefault();
			});
			
			if (foswiki.Pref) {
				var pref = foswiki.Pref.getPref('skinDisplay');
				if (pref) {
					setDisplay(pref);
				}
			}
		},

		handleSticky: function($) { 
			// make elements with class STICKY_CLASS_SELECTOR stick to the window	
			$(STICKY_CLASS_SELECTOR).sticky({
				cssclass: 'foswikiSticky'
			});
		}
		
	};
}());

jQuery(document).ready(function ($) {

	foswiki.base.removeYellowFromInputs($);
	foswiki.base.manageDisplay($);
	foswiki.base.handleLocalScroll($);
	foswiki.base.handleSticky($);
	
	// add focus to elements with class foswikiFocus
	$('input.foswikiFocus').livequery(function () {
		$(this).focus();
	});
});
