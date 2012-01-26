/***************************************************************************
 * SolrManager
 *
 * (c)opyright 2009-2011 Michael Daum http://michaeldaumconsulting.com
 */

var solr; /* last solr manager constructed; this is a singleton in most use cases */

(function($) {

  /***************************************************************************
   * constructor
   */
  $.SolrManager = function(elem, opts) {
    var self = this;
    self.log("SolrManager constructor called");

    /* basic properties */
    self.container = $(elem);
    self.submitButton = self.container.find(".solrSubmitButton");
    self.opts = opts;
    self.suppressSubmit = false; 
    //self.suppressSetFilter = false;
    self.selection = [];
    self.mapping = [];

    self.initMapping();
    self.initGui();
  };

  /***************************************************************************
   * bind: forward bind() to element that receives the event to listen to
   */
  $.SolrManager.prototype.bind = function(type, data, fn) {
    var self = this;
    return self.container.bind(type, data, fn);
  };

  /***************************************************************************
   * initMapping: read meta data and establish a translation map for strings
   */
  $.SolrManager.prototype.initMapping = function () {
    var self = this;
    self.log("initMapping called");

    /* get mappings from meta tags */
    $("meta[name^='foswiki.SolrPlugin.mapping']").each(function() {
      var $this = $(this),
	  key = $this.attr('name').replace(/^.*\./, ''),
	  val = $this.attr('content');
      self.addMapping(key, val);
      //self.log("mapping key="+key+", val="+val);
    });

    /* get mappings from facet values */
  };

  /***************************************************************************
   * addMapping: adds a key-value pair to the name mapper. this only
   * adds a new mapping if it doesnt exist yet. returns the current mapping
   */
  $.SolrManager.prototype.addMapping = function(key, val) {
    var self = this, 
	_key = 'DATA::'+key;
	// adding DATA:: prefix to prevent clashes with prototype properties of Arrays, like 'filter' 

    if (typeof(self.mapping[_key]) === 'undefined') {
      //self.log("mapping key="+key+", val="+val);
      self.mapping[_key] = val; 
    }

    return self.mapping[_key];
  };

  /***************************************************************************
   * getMapping: returns the mapping for the given key
   */
  $.SolrManager.prototype.getMapping = function(key) {
    var self = this;
    return self.mapping['DATA::'+key];
  };
 
  /***************************************************************************
   * getFacetValue: creates a FacetValue from the data embeded in a dom element
   */
  $.SolrManager.prototype.getFacetValue = function(elem) {
    var self = this,
        $elem = $(elem),
        val = $elem.attr('value'),
        title = $elem.attr('title') || undefined,
        match = /^(.*?):(.*)$/.exec(val);

    self.log("getFacetValue called, val="+val+" title="+title);

    if (match !== undefined) {
      var facetValue = {};
      facetValue.facet = match[1];
      facetValue.value = match[2];
      if (title !== undefined) {
        facetValue.valueTitle = title;
      }
      return facetValue;
    }
  };

  /***************************************************************************
   * applyMapping: replace the label of a facet with its mapping
   */
  $.SolrManager.prototype.applyMapping = function(elem) {
    var self = this,
        $elem = $(elem),
        id = $elem.attr("id"),
        $label, match,
        title, mappedTitle,
        regex = /^(.*?)\s+\((\d+)\)$/;

    if ($elem.is("a")) {
      title = $elem.text();
      if (match = regex.exec(title)) {
        mappedTitle = self.getMapping(match[1]);
        title = mappedTitle+' ('+match[2]+')';
      } else {
        mappedTitle = self.getMapping(title);
        if (mappedTitle !== "undefined") {
          title = mappedTitle;
        }
      }
      $elem.text(title);
      return;
    } 
    
    if ($elem.is("input")) {
      if (typeof(id) !== "undefined") {
        $label = $("label[for='"+id+"']");
        if ($label.length) {
          title = $label.text();
          match = regex.exec(title);
          if (match) {
            mappedTitle = self.getMapping(match[1]);
            if (typeof(mappedTitle) !== "undefined") {
              title = mappedTitle+' ('+match[2]+')';
              $label.text(title);
            }
          }
          return mappedTitle;
        }
      }
    }
  };

  /***************************************************************************
   * showSelection: render "Your current selection" based on the current selection
   */
  $.SolrManager.prototype.showSelection = function() {
    var self = this;
    self.log("showSelection called");

    $(".solrYourSelection > ul > li:not(.solrNoSelection)").remove()
    if (self.selection.length) {
      var template = "<li>"+
        "<table class='foswikiLayoutTable' width='100%'>"+
          "<tr>"+
          "<td width='12px'><input type='checkbox' class='foswikiCheckbox solrDeleteFacetValue solrDeleteFacetValue_$facet' value='$facet:$value' id='del_$facet_$value' name='filter' checked='checked'/></td>"+
          "<td><label for='del_$facet_$value' style='display:block'>$valuetitle (<nop>$facettitle)</label></td>"+
          "</tr>"+
        "</table>"+
        "</li>";
      
      self.debugSelection();

      var list = $(".solrYourSelection > ul");
      for (var i = 0; i < self.selection.length; i++) {
        var fv = self.selection[i];
        var valueTitle = fv.valueTitle;
        var facetTitle = fv.facetTitle;
        if (valueTitle === undefined) {
          valueTitle = self.getMapping(fv.value);
          if (valueTitle === undefined) {
            valueTitle = fv.value;
          }
        }
        if (facetTitle === undefined) {
          facetTitle = self.getMapping(fv.facet);
          if (facetTitle === undefined) {
            facetTitle = fv.facet;
          }
        }
        var item = template
          .replace(/\$valuetitle/g, valueTitle)
          .replace(/\$facettitle/g, facetTitle)
          .replace(/\$value/g, fv.value)
          .replace(/\$facet/g, fv.facet);
        //self.log("item="+item);
        //self.log("template="+template);
        list.append(item);
      }
      $(".solrClearAll").show();
      $(".solrNoSelection").hide();
    } else {
      $(".solrClearAll").hide();
      $(".solrNoSelection").show();
    }
  };

  /***************************************************************************
   * debug selection
   */
  $.SolrManager.prototype.debugSelection = function() {
    var self = this;
    if ($.SolrManager.DEBUG) {
      for (var i = 0; i < self.selection.length; i++) {
        self.log("selection["+i+"].facet="+self.selection[i].facet);
        self.log("selection["+i+"].facetTitle="+self.selection[i].facetTitle);
        self.log("selection["+i+"].value="+self.selection[i].value);
        self.log("selection["+i+"].valueTitle="+self.selection[i].valueTitle);
      }
    }
  };

  /***************************************************************************
   * selectFacetValue: adds a FacetValue to the selection and updates the ui.
   * returns 0: error
   *         1: new fv
   *         2: replaced an old one
   */
  $.SolrManager.prototype.selectFacetValue = function(fv) {
    var self = this, retVal = 0, indexOf = -1;
    if (fv === undefined) {
      return retVal;
    }

    // trigger select event
    self.container.trigger("selectFacetValue", [fv]);

    //fv.value = fv.value.replace(/"/g, '');
    self.log("selectFacetValue() called: fv=", fv);

    /* filter out old */
    retVal = 1;
    for (var i = 0; i < self.selection.length; i++) {
      if (self.selection[i].facet == fv.facet && self.selection[i].value == fv.value) {
        indexOf = i;
        break;
      }
    }
    if (indexOf >= 0) {
      self.selection.splice(indexOf, 1);
      retVal = 2;
    }
    self.selection.push(fv);

    if (fv.facet === 'keyword') {
      var keywords = self.getKeywordsFromSelection().join(' ');
      $(".solrSearchField").val(keywords);
    } else {
      $(".solrFacetValue[value='"+fv.facet+":"+fv.value+"']").addClass("current").filter("input").attr('checked', 'checked');
    }
    return retVal; 
  };

  /***************************************************************************
   * clearFacetValue: removes a FacetValue from the selection and updates the ui
   */
  $.SolrManager.prototype.clearFacetValue = function(fv) {
    var self = this, retVal = 0;

    if (fv === undefined) {
      return 0
    }

    //fv.value = fv.value.replace(/"/g, '');
    self.log("clearFacetValue("+fv.facet+", "+fv.value+", "+fv.facetTitle+", "+fv.valueTitle+") called");
    
    /* filter out old */
    var indexOf = -1;
    for (var i = 0; i < self.selection.length; i++) {
      if (self.selection[i].facet == fv.facet && self.selection[i].value == fv.value) {
        indexOf = i;
        break;
      }
    }
    if (indexOf >= 0) {
      self.selection.splice(indexOf, 1);
      retVal = 1;
    }

    if (fv.facet === 'keyword') {
      $(".solrSearchField").val(self.getKeywordsFromSelection().join(' '));
    } else {
      $(".solrFacetValue[value='"+fv.facet+":"+fv.value+"']")
      .removeClass("current")
      .filter("input").removeAttr('checked');
    }

    // trigger clear event
    if (retVal) {
      self.container.trigger("clearFacetValue", [fv]);
    }

    return retVal;
  };

  /***************************************************************************
   * getKeywords: get an arry of words and phrases in the search field
   */
  $.SolrManager.prototype.getKeywords = function () {
    var self = this;
    var search = $(".solrSearchField").val();
    var keywords = [];
    var re = /([\+\-]?(?:(?:[^\s"]+)|(?:"[^"]+")))/g; 
    while(re.exec(search)) { 
      keywords.push(RegExp.$1);
    }

    return keywords;
  };

  /***************************************************************************
   * getKeywordsFrom: get the list of selected words and phrases 
   */
  $.SolrManager.prototype.getKeywordsFromSelection = function () {
    var self = this;

    var keywords = [];
    for (var i = 0; i < self.selection.length; i++) {
      if (self.selection[i].facet === 'keyword') {
        keywords.push(self.selection[i].value);
      }
    }

    return keywords;
  };

  /***************************************************************************
   * initGui
   */
  $.SolrManager.prototype.initGui = function() {
    var self = this;
    self.log("initGui called");

    /* add filters to selection */
    $(".solrFilter").each(function() {
      var $this = $(this);
      var fv = $this.metadata();
      if (fv.value === undefined) {
        fv.value = $this.val();
      }
      fv.value = unescape(fv.value).replace(/(^")|("$)/g, '');
      self.selectFacetValue(fv);
    });

    /* add search to selection */
    var keywords = self.getKeywords();
    for (var i = 0; i < keywords.length; i++) {
      self.selectFacetValue({
        facet:'keyword',
        value:keywords[i]
      });
    }

    /* sort facets alphabetically */
    $(".solrFacetContainer.solrSort, .solrFacetContainer.solrSortReverse").each(function() {
      var $this = $(this);
      var $list = $this.find("ul");
      var items = $list.find("li").sort(function(a, b) {
        var valA = $("label", a).text().toUpperCase();
        var valB = $("label", b).text().toUpperCase();
        return (valA<valB)?-1:(valA>valB)?1:0;
      });
      if ($this.is(".solrSort")) {
        $.each(items, function(index, elem) {
          $list.append(elem);
        });
      } else {
        $.each(items, function(index, elem) {
          $list.prepend(elem);
        });
      }
      $this.removeClass("solrSort");
    });

    /* init autocompletion */
    var $searchField = $(".solrSearchField");

    if ($searchField.length) {
      var searchFieldOpts = $.extend({}, $searchField.metadata()),
          filter = searchFieldOpts.filter?searchFieldOpts.filter:[];

      for (var i = 0; i < self.selection.length; i++) {
        var fv = self.selection[i];
        if (fv.facet !== 'keyword') {
          filter.push(fv.facet+":"+fv.value);
        }
      }
      if (filter.length) {
        filter = ";filter="+filter.join(",");
      }

      /* init autocompletion */
      // TODO: test for newer autocomplete library
      if (1) {
        $searchField.autocomplete({
          source:foswiki.getPreference("SCRIPTURL")+'/rest/SolrPlugin/autocomplete?'+filter
        }).data("autocomplete")._renderItem = function(ul, item) {
          return $("<li></li>")
            .data("item.autocomplete", item)
            .append("<a><table width='100%'><tr><td align='left'>"+item.label+"</td><td align='right'>"+item.frequency+"</td></tr></table></a>")
            .appendTo(ul);
        };
      } else {
        $searchField.autocomplete(
          foswiki.getPreference("SCRIPTURL")+'/rest/SolrPlugin/autocomplete?'+filter, {
            selectFirst: false,
            autoFill:false,
            matchCase:false,
            matchSubset:false,
            matchContains:false,
            scrollHeight:'20em',
            formatItem: function(row, index, max, search) {
              return "<table width='100%'><tr><td align='left'>"+row[0]+"</td><td align='right'>"+row[2]+"</td></tr></table>";
            }
        });
      }
    }

    var filter = [];

    /* init facet pager */
    $(".solrSerialPager")
      .addClass("jqSerialPager")
      .removeClass("solrSerialPager"); // triggers pager plugin now, not earlier

    /* behavior for sorting */
    $("#solrSorting").change(function() {
      $("#solrSortOption").val($(this).val());
      self.submit();
    });

    /* behavior for rows */
    $("#solrRows").change(function() {
      $("#solrRowsOption").val($(this).val());
      self.submit();
    });

    /* behavior for display */
    $(".solrDisplay").click(function(e) {
      self.log("solrDisplay clicked");
      $("#solrDisplayOption").val($(this).val());
      self.submit();
    });

    /* behavior for facets */
    $(".solrFacetValue:not(.solrFacetValueInited)").livequery(function() {
      var $this = $(this);
      $this.addClass("solrFacetValueInited");

      /* get mapping */
      var fv = self.getFacetValue(this);
      if (fv && fv.valueTitle) {
	self.addMapping(fv.value, fv.valueTitle);
      }

      /* apply mapping */
      self.applyMapping(this);

      /* update selection */
      if ($this.is(".current, :checked")) {
        if (self.selectFacetValue(fv) > 0) {
          self.showSelection();
          self.debugSelection();
	}
      }

      /* callback used by click and change handler */
      function _changed() {
        self.log("solrFacetValue changed");
        if ($this.is("input[type=radio]")) {
          $("[name="+$this.attr('name')+"]").each(function() {
            var fv = self.getFacetValue(this);
            self.clearFacetValue(fv);
          });
        }
        $this.toggleClass("current");
        $(".solrDeleteFacetValue[value='"+$this.val()+"']").removeAttr("checked");
        if ($this.is(".current")) {
          self.selectFacetValue(fv);
        } else {
          self.clearFacetValue(fv);
        }
        self.showSelection();
        self.submit();
        return false;
      }

      /* install change handler */
      $this.not("a").change(_changed);
      $this.filter("a").click(_changed);

      /* install click handler */

      /* add hover handler */
      $this.parents('li:first').hover(
        function() { $(this).addClass("solrHover"); },
        function() { $(this).removeClass("solrHover"); }
      );
    });

    /* behaviour for delete facet */
    $(".solrDeleteFacetValue:not(.solrDeleteFacetValueInited)").livequery(function() {
      var $this = $(this);

      /* install click handler */
      $this.change(function(e) {
        self.log("solrDeleteFacetValue clicked");
        var fv = self.getFacetValue(this);
        $this.removeAttr('checked');
        self.clearFacetValue(fv);
        self.showSelection();
        self.submit();
      });

      /* add hover handler */
      $this.parents('li:first').hover(
        function() { $(this).addClass("solrHover"); },
        function() { $(this).removeClass("solrHover"); }
      );
    });

    /* auto sumbit */
    $(".solrAutoSubmit").click(function(e) {
      self.log("solrAutoSubmit clicked");
      self.submit();
    });

    /* behavior for clear button */
    $(".solrClear").click(function(e) {
      self.log("solrClear clicked");
      var $this = $(this);
      var fv = $.extend({}, $this.metadata());

      /* get facet values to clear */
      var selector = fv.selector;
      if (!selector) {
        selector = ".solrFacetValue_"+fv.facet;
      }
      self.log("selector="+selector);

      /* clear selection */
      $(selector).each(function() {
        var fv = self.getFacetValue(this);
        self.clearFacetValue(fv);
      });
      self.showSelection();
      self.submit();
      return false;

    }).each(function() {
      /* show when there's something to clear */
      var $this = $(this);
      if($this.parent().find("input:checked").length) {
        $this.show();
      }
    });

    /* behavior for hover */
    $(".solrSearchHit").hover(
      function() {
        $(this).addClass("solrSearchHitHover");
      }, 
      function() {
        $(this).removeClass("solrSearchHitHover");
      }
    );

    /* behavior for autosubmit */
    function updateAutoSubmit() {
      var $toggleAutoSubmit = $(".solrToggleAutoSubmit");
      if ($toggleAutoSubmit.length) {
        if ($toggleAutoSubmit.is(":checked") || $toggleAutoSubmit.is("[type=hidden][value=on]") ) {
          self.suppressSubmit = false;
        } else {
          self.suppressSubmit = true;
        }
      }
    }
    $(".solrToggleAutoSubmit").change(updateAutoSubmit);
    updateAutoSubmit();

    /* switch on */
    self.showSelection();
    $(".solrYourSelection label").css('visibility', 'hidden');
    $(".solrFacetPager").show();

    window.setTimeout(function() {
      $(".solrYourSelection label").css('visibility', 'visible');
    }, 100);
  };

  /***************************************************************************
   * submit: submits the search form; before, the selection is linearized
   * as hidden solrFilter input fields
   */
  $.SolrManager.prototype.submit = function() {
    var self = this;
    self.log("submit called");

    var $form = $(".solrSearchForm");
    $form.find(".solrFilter").remove();
    for (var i = 0; i < self.selection.length; i++) {
      var fv = self.selection[i];
      if (fv.facet !== 'keyword') {
        var filter = fv.facet+":";
        if (fv.value.match(/\s|(%20)/) && !fv.value.match(/^["\[].*["\]]$/)) {
          self.log("... adding quotes to "+fv.value);
          filter += "\""+fv.value+"\"";
        } else {
          self.log("... adding as is "+fv.value);
          filter += fv.value;
        }
        self.log("filter value="+filter);
        $form.prepend("<input type='hidden' class='solrFilter' name='filter' value='"+filter+"' />");
      }
    }

    if (self.suppressSubmit || $.SolrManager.SUPPRESSSUBMIT) {
      self.submitButton.stop().effect("pulsate", {times:3});
      self.log("... suppressed");
      return;
    }

    $("body, a, input").css('cursor', 'progress');
    $(".solrSearchForm").submit();
  };

  /***************************************************************************
   * logger
   */
  $.SolrManager.prototype.log = function()  {
    if ($.SolrManager.DEBUG) {
      var args = ["SOLR: "];
      for (var i = 0; i < arguments.length; i++) {
        args.push(arguments[i]);
      }
      window.console.log.apply(window.console, args);
    }
  };

  /***************************************************************************
   * default options
   */
  $.SolrManager.defaults = {};

  /***************************************************************************
   * static flags
   */
  $.SolrManager.DEBUG = false; // enables logging messages using $.log(), that is: 
                              // you will need to load the jquery.debug module as well
  $.SolrManager.SUPPRESSSUBMIT = false; // if set to true, the search form will not be submitted

  /***************************************************************************
   * plugin constructor
   */
  $.fn.solrManager = function(opts) {
    solr = new $.SolrManager(this, opts);
  };

  $(function() {
    $(".solrSearch:not(.solrSearchInited)").each(function() {
      var $this = $(this);
      var opts = $.extend({}, $.SolrManager.defaults, $this.metadata());
      $this.addClass("solrSearchInited");
      $this.solrManager(opts);
    });

    $(".solrSearchHitsGrid .solrImageHit").livequery(function() {
      var $this = $(this), $caption = $this.find(".solrImageCaption");
      $this.hover(
        function() {
          $caption.show().animate({
            'margin-top':0
          });
        },
        function() {
          $caption.stop().animate({
            'margin-top':-100
          }, function() {
            $(this).hide();
          });
        }
      );
    });
  });

})(jQuery);
