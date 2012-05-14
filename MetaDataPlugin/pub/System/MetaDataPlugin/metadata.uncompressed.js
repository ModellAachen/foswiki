(function($) {

  // global defaults
  var 
    pluginName = 'metaDataView',
    pluginClass = '.metaDataView',
    defaults = {
      actionFadeoutTime: 1000
    };


  // class constructor
  function MetaDataView(elem, opts) {
    var self = this;

    self.elem = $(elem);
    self.opts = $.extend({}, defaults, opts);

    //console.log("called new");

    self.init();

    return self;
  };

  // init method
  MetaDataView.prototype.init = function() {
    var self = this;

    self.elem.find("tr")
    .hover(
      function() {
        var $row = $(this);
        $row.addClass("hover");
        self.elem.find(".metaDataActions").hide();
        $row.find(".metaDataActions").show();
        if (self.timeout) {
          clearTimeout(self.timeout);
        }
      }, 
      function() {
        var $row = $(this);
        $row.removeClass("hover");
        self.timeout = setTimeout(function() {
          $row.find(".metaDataActions").stop().fadeOut();
        }, self.opts.actionFadeoutTime);
      }
    )
    .click(function(e) {
      var $this = $(this), 
          $editAction = $this.find(".metaDataEditAction");

      $this.children().effect("highlight");

      if ($(e.target).is("td")) {
        self.elem.find("tr").removeClass("selected");
        $this.addClass("selected");

        if ($editAction.length) {
          $editAction.trigger("click");
          return false;
        }
      }
    });
  };

  // register to jquery
  $.fn[pluginName] = function (opts) { 
    return this.each(function() { 
      if (!$.data(this, 'plugin_' + pluginName)) { 
        $.data(this, 'plugin_' + pluginName, 
          new MetaDataView(this, opts)); 
        } 
    }); 
  };
 
  // document ready things
  $(function() {
    $(pluginClass).livequery(function() {
      var $this = $(this),
          opts = $.extend({}, $this.metadata({type:'elem', name:'script'}));

      $this[pluginName](opts);
    });
  });

})(jQuery);

