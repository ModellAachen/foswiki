/* init gui */
jQuery(function($) {

  // init edit link
  $(".ecpEdit").live("click", function() {
    var $this = $(this), 
        href = $this.attr("href"),
        opts = $.extend({}, $this.metadata());

    // lock
    $.jsonRpc(foswiki.getPreference("SCRIPTURL")+"/jsonrpc", {
      namespace: 'EditChapterPlugin',
      method: 'lock',
      params: {
        "topic": opts.web+"."+opts.topic
      },
      success: function() {
        $.get(href, function(content) { 
          var $content = $(content);
          $content.hide();
          $("body").append($content);
          $content.data("autoOpen", true);
        }); 
      },
      error: function(json, textStatus, xhr) {
        alert(json.error.message);
      }
    });

    return false;
  });

  // init edit form
  $(".ecpForm:not(.ecpInitedForm)").livequery(function() {
    var $this = $(this),
        topic = $this.find("input[name='topic']").val(),
        $dialog = $this.parent();

    $dialog.bind("cancel", function() {
      $.jsonRpc(foswiki.getPreference("SCRIPTURL")+"/jsonrpc", {
        namespace: "EditChapterPlugin",
        method: "unlock",
        params: {
          "topic": topic
        },
        error: function(json, textStatus, xhr) {
          //alert(json.error.message);
        }
      });
      $dialog.dialog("close");
    });

    // concat before submit
    $this.addClass("ecpInitedForm").submit(function() {
      var before = $this.find('[name=beforetext]'),
          after = $this.find('[name=aftertext]'),
          chapter = $this.find('[name=chapter]'),
          text = $this.find("[name=text]"),
          chapterText, lastChar;

      //console.log("called ECP's beforeSubmitHandler");

      if (!before.length || !after.length || !chapter.length) {
        //console.log("before=", before.length, " after=", after.length, " chapter=",chapter.length);
        return false;
      }

      //console.log("merging text");

      chapterText = chapter.val();
      lastChar = chapterText.substr(chapterText.length-1, 1);
      if (lastChar != '\n') {
        chapterText += '\n';
      }
      text.val(before.val()+chapterText+after.val());
      //return false;
    });
  });

  // init foswikiToc
  $(".foswikiToc .ecpHeading").addClass("ecpDisabled");
  if ($.browser.msie) {
    // hoverIntent fails on IE...wtf
    $(".ecpHeading:not(.ecpDisabled)").hover(
      function(event) {
        $(this).addClass('ecpHover');
        event.stopPropagation();
      },
      function(event) {
        $(this).removeClass('ecpHover');
        event.stopPropagation();
      }
    );
  } else {
    $(".ecpHeading:not(.ecpDisabled)").hoverIntent({
      timeout: 500,
      over: function(event) {
        $(this).addClass('ecpHover');
        event.stopPropagation();
      },
      out: function(event) {
        $(this).removeClass('ecpHover');
        event.stopPropagation();
      }
    });
  }
});
