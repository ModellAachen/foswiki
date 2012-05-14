var foswiki;
if (!foswiki) {
	foswiki = {};
}

/**
Base script. Handles:
- smooth scrolling
- sticky behaviour
*/


foswiki.base = (function ($) {

	"use strict";

	var calculateStickyOffset,
		DEFAULT_SCROLL_OFFSET = -20,
		GOOD_DEFAULT_SCROLL_SPEED = 900,
		GOOD_DEFAULT_SCROLL_MAX_DURATION = 550,
		DEFAULT_SCROLL_EASING = 'easeInOutQuart',
		PREVENT_ANCHOR_JUMP_AT_PAGE_LOAD = true,
		STICKY_CLASS_SELECTOR = '.foswikiMakeSticky';
			
	/*
	Calculate offset when sticky elements are around. 
	*/
	calculateStickyOffset = function(stickySelector) {
		var $fixedElements = $(stickySelector),
			offsetY = 0,
			i;
		for (i = 0; i < $fixedElements.length; i = i + 1) {
			offsetY -= $($fixedElements[i]).outerHeight();
		}
		return offsetY;
	};
	
	return {

		handleLocalScroll: function() {
		
			$("a[href*='#']").pageScroll({
				speed: GOOD_DEFAULT_SCROLL_SPEED,
				maxDuration: GOOD_DEFAULT_SCROLL_MAX_DURATION,
				easing: DEFAULT_SCROLL_EASING,
				mayScroll: function(opts) {
					opts.offset = DEFAULT_SCROLL_OFFSET + calculateStickyOffset(STICKY_CLASS_SELECTOR)
				}
			});

			if (PREVENT_ANCHOR_JUMP_AT_PAGE_LOAD && location.hash) {
				// hide body before forcing to top
				$('body').hide();
				// secretly go to top
				window.scrollTo(0, 0);
			}
			
			$(window).pageScroll({
				id: location.hash,
				event: 'load hashchange',
				speed: GOOD_DEFAULT_SCROLL_SPEED,
				maxDuration: GOOD_DEFAULT_SCROLL_MAX_DURATION,
				mayScroll: function(opts) {
					opts.offset = DEFAULT_SCROLL_OFFSET + calculateStickyOffset(STICKY_CLASS_SELECTOR)
				},
				willScroll: function(opts) {
					if ($('body').is(':hidden')) {
						$('body').show();
					}
				},
				willScrollDelay: 500
			});
		},
		
		removeYellowFromInputs: function() {
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
		
		/*
		Manage display 'views' - spatious, average and maximise.
		*/
		manageDisplaySettings: function() { 
			
			var setDisplay,
				parseMode;
				
			setDisplay = function(viewClass) {
				$('body').removeClass('foswikiViewDisplayRoomy').removeClass('foswikiViewDisplayCosy').removeClass('foswikiViewDisplayTight');
				$('body').addClass(viewClass);
			};
			
			parseMode = function(mode) {
				if (!mode) {
					return;
				}
				switch (mode) {
					case 'foswikiDisplayRoomy':
						setDisplay('foswikiViewDisplayRoomy');
						break;
					case 'foswikiDisplayCosy':
						setDisplay('foswikiViewDisplayCosy');
						break;
					case 'foswikiDisplayTight':
						setDisplay('foswikiViewDisplayTight');
						break;
				}
			};	
			$('a.foswikiDisplayRoomy,a.foswikiDisplayCosy,a.foswikiDisplayTight').livequery('click', function (e) {
				var $this = $(this),
					mode = $this.attr('class');
				
				e.preventDefault();
				parseMode(mode);
				if (foswiki.Pref && mode) {
					foswiki.Pref.setPref('skinDisplay', mode);
				}
			});
			
			if (foswiki.Pref) {
				parseMode(foswiki.Pref.getPref('skinDisplay'));
			}
		},
		
		/*
		Make elements with class STICKY_CLASS_SELECTOR stick to the window	
		*/
		handleSticky: function() { 
			$(STICKY_CLASS_SELECTOR).sticky({
				cssclass: 'foswikiSticky'
			});
		}
		
	};
}(jQuery));

jQuery(document).ready(function ($) {

	foswiki.base.removeYellowFromInputs();
	foswiki.base.manageDisplaySettings();
	foswiki.base.handleSticky();
	foswiki.base.handleLocalScroll();
	
	// add focus to elements with class foswikiFocus
	$('input.foswikiFocus').livequery(function () {
		$(this).focus();
	});
});

function scrollY() {
	return window.pageYOffset ? window.pageYOffset : document.documentElement.scrollTop ? document.documentElement.scrollTop : document.body.scrollTop;
}