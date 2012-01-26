(function ($) {
	"use strict";
	$.fn.sticky = function (options) {

		var settings = $.extend({
			'cssclass': 'sticky'
		}, options),
			$fixedElements = [],
			$fixedElement,
			offsetY = 0,
			scrollTop = 0,
			ival,
			i,
			$this,
			scrollZone,
			fix,
			unfix,
			handleScroll,
			handleScrollEvent,
			// scroll wait duration depends if sticky element changes are within scroll zone
			SCROLL_WAIT_FINE = 5,
			SCROLL_WAIT_COURSE = 15,
			scrollWait = SCROLL_WAIT_COURSE;

		this.each(function () {
			$this = $(this);
			// scrollY: y position from where to fixate
			$this.scrollY = $this.position().top - offsetY;

			// stickyY: y position when being sticky
			$this.stickyY = offsetY;
			offsetY += $this.outerHeight();

			// scrollZone: to get finegrained scroll updates when sticking/unsticking happens
			scrollZone = $this.scrollY + $this.outerHeight();

			$fixedElements.push($this);
		});

		fix = function ($element) {
			// fix element at y position stickyY
			$element.addClass(settings.cssclass);
			$element.css({
				top: $element.stickyY + 'px'
			});
			// add a div to hold the padding the fixed element has just removed
			$element.$div = jQuery('<div></div>').css({
				height: $element.outerHeight()
			});
			$element.after($element.$div);
			$fixedElement.isFixed = 1;
		};

		unfix = function ($element) {
			$element.$div.remove();
			$element.removeClass(settings.cssclass);
			$element.css({
				top: 'auto'
			});
			$fixedElement.isFixed = 0;
		};

		handleScroll = function () {

			scrollTop = $(window).scrollTop();
			for (i = 0; i < $fixedElements.length; i = i + 1) {
				$fixedElement = $fixedElements[i];

				if (scrollTop >= $fixedElement.scrollY) {
					if (!$fixedElement.isFixed) {
						fix($fixedElement);
					}
				} else {
					if ($fixedElement.isFixed) {
						unfix($fixedElement);
					}
				}
			}
			scrollWait = scrollTop < scrollZone ? SCROLL_WAIT_FINE : SCROLL_WAIT_COURSE;
		};

		handleScrollEvent = function () {
			clearTimeout(ival);
			ival = setTimeout(function () {
				handleScroll();
			}, scrollWait);
		};

		$(window).scroll(handleScrollEvent);

		// update first time without scroll event
		handleScroll();

		return this;
	};

}(jQuery));