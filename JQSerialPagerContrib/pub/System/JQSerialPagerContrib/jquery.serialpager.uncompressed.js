/* 
 * serial scroller
 *
 * (c)opyright 2012 Michael Daum http://michaeldaumconsulting.com
*/
(function($) {

  var defaults = {
    pagesize: 10,
    width: 'auto',
    easing: 'easeOutQuart',
    duration: 500,
    cycle: true,
    counter: true,
    prevText: 'prev',
    nextText: 'next',
    widthElem: undefined
  };

  /* impl */
  $.fn.serialPager = function(opts) {
    var $pager = this, // already a jquery object
        $ul = $pager.find("ul:first"),
        nrVals = $ul.children("li").length;

    //console.log("pager=",$pager);
    //console.log("opts=",opts);
    //console.log("nrVals="+nrVals);

    // add pager if pagesize is exceeded
    if ($pager.length && nrVals > opts.pagesize) {
      
      // propagate to data cache
      $pager.data(opts);

      // create pane holding lists if items
      var $pane = $("<div class='jqSerialPagerScrollPane'></div>").appendTo($pager),
          nrPages = Math.ceil(nrVals / opts.pagesize);

      //console.log($pane, "nrVals="+nrVals,"pagesize="+opts.pagesize,"nrPages="+nrPages);

      for (var page = 0; page < nrPages; page++) {
        var $newUl = $("<ul class='jqSerialPagerPage'></ul>").appendTo($pane);
        $ul.find("li:lt("+opts.pagesize+")").appendTo($newUl);
      }
      $("<span class='foswikiClear' />").appendTo($pane);
      
      // remove the old list as everything has been moved over to the pane
      $ul.remove();

      // create pager ui
      var $buttons = $("<div class='jqSerialPagerButtons'></div>").width(opts.width).insertAfter($pager);
      var $prev = $("<a href='#' class='jqSerialPagerPrev'>"+opts.prevText+"</a>").appendTo($buttons);
      var $next = $("<a href='#' class='jqSerialPagerNext'>"+opts.nextText+"</a>").appendTo($buttons);
      var $counter;
      
      if(opts.counter) {
        $counter = $("<div class='jqSerialPagerCounter'>1/"+nrPages+"</div>").appendTo($buttons);
      }

      $("<span class='foswikiClear' />").appendTo($buttons);

      // init the serial scroll
      $pager.serialScroll({
        items:'.jqSerialPagerPage',
        prev:$prev,
        next:$next,
        constant:false,
        duration:opts.duration,
        start:0,
        force:false,
        cycle:opts.cycle,
        lock:false,
        easing:opts.easing,
        onBefore:function(e, elem, $pane, items, pos) {
          var cycle = $pane.data("cycle"), 
              counter = $pane.data("counter");
          if(counter) {
            $counter.html((pos+1)+"/"+nrPages);
          }
          if (!cycle) {
            if (pos == 0) {
              $prev.css("visibility", "hidden");
            } else {
              $prev.css("visibility", "visible");
            }
            if (pos+1 === nrPages) {
              $next.css("visibility", "hidden");
            } else {
              $next.css("visibility", "visible");
            }
          }
        }
      });

      // initial button state
      if (!opts.cycle) {
        $prev.css("visibility", "hidden");
      }

      //$pager.find(".foswikiClear").insertAfter($buttons);

      // fix width of pages
      setTimeout(function() {
        var $widthElem = opts.widthElem?$(opts.widthElem):$pager,
            width = $widthElem.width();
        if (width) {
	  $pager.find(".jqSerialPagerPage").css("width", width);
	}
      }, 0);

      $pager.width(opts.width).show();
    } else {
      $pager.removeClass("jqSerialPager");
    }

    return $pager;
  };

  /* init */
  $(function() {
    $(".jqSerialPager:not(.jqInitedSerialPager)").livequery(function() {
      var $this = $(this),
          opts = $.extend({}, defaults, $this.data(), $this.metadata());

      $this.addClass("jqInitedSerialPager").serialPager(opts);
    });
  });
})(jQuery);
