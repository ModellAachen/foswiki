/*
 * reddot helper
 *
 * Copyright (c) 2010-2011 Michael Daum http://michaeldaumconsulting.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 * Revision: $Id$
 *
 */
jQuery(function($) {
  $('.redDotAnimated:not(.redDotInited)').livequery(function() {
    var $this = $(this);
    $this.addClass('redDotInited').parent().hoverIntent({
      over: function() {
        $this.fadeIn(500, function() {
          $this.css({opacity: 1.0});
        });
      },
      out: function() {
        $this.stop();
        $this.css({display:'none', opacity: 1.0});  
      }
    });
  });
});
