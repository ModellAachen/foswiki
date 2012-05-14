// (c)opyright 2006-2012 Michael Daum http://michaeldaumconsulting.com

// document ready
jQuery(function($) {

  /* move revinfo */
  if (foswiki.getPreference("NatSkin.fixRevisionPosition")) {
    var target = $(".natMainContents h1:first");
    if (target.length) { 
      $(".natRevision").remove().insertAfter(target);
    }
  }

  /* horiz menu */
  if (foswiki.getPreference("NatSkin.initWebMenu")) {
    var $container = $(".natWebMenuContents");
    $container.children("ul").superfish({
      dropShadows: false, /* enabled using css3 */
      autoArrows: false,
      onBeforeShow: function() {
        var $this = $(this);
        if ($this.is(".ajaxMenu")) {
          var opts = $.extend({}, $this.metadata());
          if (opts.url) {
            $this.load(opts.url, function() {
              $this.removeClass("ajaxMenu");
              $this.parent().removeClass("hasAjaxMenu");
            });
          }
        }
      }
    })
    .find("li:has(ul)").addClass("hasSubMenu")
    .find("li:has(.ajaxMenu)").addClass("hasAjaxMenu");

    $container.removeClass('natWebMenuHidden');
    if ($.browser.msie) {
      $container.css('display', 'block');
    }
  }

  /* add overflow div for tables */
  if (foswiki.getPreference("NatSkin.initOverflows")) { 
    $(".natMainContents").find(".foswikiTable")
      .not($(".foswikiTable .foswikiTable", this))
      .wrap("<div class='overflow foswikiTableOverflow'></div>");
  }

  if (foswiki.getPreference("NatSkin.initTopicActions")) { // topicaction tooltips 
    $(".natHistoryTopicActions .natTopicAction").each(function() {
      var $this = $(this),
          tip = $this.find("span.natTopicActionShortLabel").text();
      $this.attr("title", tip);
    });
  }

  // init more actions menu
  $(".natMoreActionsMenu:not(.natInitedMoreActionsMenu)").livequery(function() {
    var $this = $(this), opts = $.extend({}, $this.metadata());
    $this.addClass("natInitedMoreActionsMenu").superfish(opts).
    find("a[href]").click(function() {
      $this.hideSuperfishUl();
    });
  });

  // remove empty attachment comments
  $("#natTopicAttachments .natAttachmentComment").livequery(function(){
    var text = $(this).text();
    //alert("text='"+text+"' char="+text.charCodeAt(0));
    if ((text.length == 1 && text.charCodeAt(0) == 160)) {
      $(this).hide();
    }
  });

  $(".foswikiFormSteps").livequery(function() {
    var $this = $(this);
    $this.find("> .foswikiFormStep:last, > form > .foswikiFormStep:last").addClass("foswikiFormLast");
    $this.find("> .foswikiFormStep:first, > form > .foswikiFormStep:first").addClass("foswikiFormFirst");
  });

  if (false) { // add foswikiLast to last row of a foswikiTable/foswikiLayoutTable/foswikiNullTable
    $(".foswikiLayoutTable, .foswikiTable, .foswikiNullTable").livequery(function() {
      var $this = $(this);
      $this.find("tr:last").addClass("foswikiLast");
      $this.find("tr:first").addClass("foswikiFirst");
    });
  }

  if (foswiki.getPreference("NatSkin.initSideBar")) { // typographic improvements in sidebar
    $('.natSideBar h2 + h2:not(.jqInitedSideBar)').livequery(function() {
      var $this = $(this);
      $this.addClass('jqInitedSideBar');
      $this.replaceWith('<h3>'+$this.html()+'</h3>');
    });
  }

  if (foswiki.getPreference("NatSkin.initAutocomplete")) {// autocompletion using solr 
    var $input = $("#searchbox input[type=text]"),
        scriptUrl = foswiki.getPreference("SCRIPTURL") + '/rest/SolrPlugin/autocomplete',
        now = (new Date).getTime(),
        submitButton = $input.parent().find(".foswikiSubmit");

    if ($input.length) {
      $input.autocomplete({
        source: scriptUrl + '?t='+ now,
        loading: function(event) {
          //console.log("got loading event");
          submitButton.hide();
        },
        unloading: function(event) {
          //console.log("got unloading event");
          submitButton.show();
        }
      }).data("autocomplete")._renderItem = function(ul, item) {
        return $("<li></li>")
          .data("item.autocomplete", item)
          .append("<a><table width='100%'><tr><td>"+item.label+"</td><td align='right'>"+item.frequency+"</td></tr></table></a>")
          .appendTo(ul);
      };
    }
  }

  // replace hr with a div.hr on ie7
  if ($.browser.msie && $.browser.version == 7.0) {
    $("hr").livequery(function() {
      $(this).replaceWith("<div class='hr' />");
    });
  }

  // hide address bar on mobile devices
  if(navigator.userAgent.match(/Android/i)){
    window.scrollTo(0,1);
  }
});
