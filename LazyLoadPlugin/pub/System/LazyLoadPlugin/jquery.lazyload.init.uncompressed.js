jQuery(function($) {

  var defaults = {
    effect: "fadeIn",
    skip_invisible: false
  };

  $(".jqLazyLoad:not(.jqInitedLazyLoad)").each(function() {
    var $this = $(this), 
        opts = $.extend({}, defaults, $this.metadata());

    $this.addClass("jqInitedLazyLoad");
    $this.find("img").lazyload(opts);
 
    // give it a nother clap after a second
    setTimeout(function() {
      $(window).trigger("resize");
    }, 500);
  });
});
