/*

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

(c)opyright 2010-2012 Michael Daum http://michaeldaumconsulting.com

are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

*/

jQuery(function($) {
  $(".cmtComments:not(.cmtCommentsInited)").livequery(function() {
    var $this = $(this),
        $container = $this.parent(),
        defaults = {
          topic: foswiki.getPreference("TOPIC"),
          web: foswiki.getPreference("WEB")
        },
        opts = $.extend({}, defaults, $this.metadata());

    /* function to reload all comments *************************************/
    function loadComments(message) {
      var url = foswiki.getPreference("SCRIPTURL") + 
          "/rest/RenderPlugin/template" +
          "?name=metacomments" + 
          ";render=on" +
          ";topic="+opts.web+"."+opts.topic +
          ";expand=metacomments";

      if (!message) {
        message = "Loading ...";
      }
      message = "<h1>"+message+"</h1>";
      $.blockUI({
        message:message,
        fadeIn: 0,
        fadeOut: 0,
        overlayCSS: {
          cursor:'progress'
        }
      });
      $container.load(url, function() {
        $.unblockUI();
        $container.height('auto');
      });
    }

    // add hover 
    $this.find(".cmtComment").hoverIntent({
      over: function() {
        var $this = $(this), $controls = $this.find(".cmtControls");
        $this.addClass("cmtHover");
        $controls.fadeIn(500, function() {
          $controls.css({opacity: 1.0});
        });
      },
      out: function() {
        var $this = $(this), $controls = $this.find(".cmtControls");
        $controls.stop();
        $controls.css({display:'none', opacity: 1.0});
        $this.removeClass("cmtHover");
      }
    });

    // ajaxify add and reply forms
    $this.find(".cmtAddCommentForm").each(function() {
      var $form = $(this), rev, $errorContainer;

      $form.ajaxForm({
        dataType:"json",
        beforeSubmit: function() {
          rev = $form.find("input[name='ref']").val(),
          $errorContainer = rev?$this.find("a[name='comment"+rev+"']").parent().parent():$form.parent();

          $this.find(".foswikiErrorMessage").remove();
          $.blockUI({
            message:"<h1>Submitting comment ...</h1>",
            fadeIn: 0,
            fadeOut: 0
          });
        },
        success: function(data, statusText, xhr) {
          $.unblockUI();
          if(data.error) {
            $errorContainer.after("<p><div class='foswikiErrorMessage'>Error: "+data.error.message+"</div></p>");
          } else {
            loadComments();
          }
          $.modal.close();
        },
        error: function(xhr, msg) {
          var data = $.parseJSON(xhr.responseText);
          $.unblockUI();
          $errorContainer.after("<p><div class='foswikiErrorMessage'>Error: "+data.error.message+"</div></p>");
          $.modal.close();
        }
      });
    });

    // ajaxify update form
    $this.find(".cmtUpdateCommentForm").each(function() {
      var $form = $(this), 
          $errorContainer, 
          id, index;

      $form.ajaxForm({
        dataType:"json",
        beforeSubmit: function() {
          id = $form.find("input[name='comment_id']").val();
          index = $form.find("input[name='index']").val();
          $errorContainer = $this.find("a[name='comment"+id+"']").parent().parent();
          $this.find(".foswikiErrorMessage").remove();
          $.blockUI({
            message:"<h1>Updating comment "+index+" ...</h1>",
            fadeIn: 0,
            fadeOut: 0
          });
        },
        success: function(data, statusText, xhr) {
          $.unblockUI();
          if(data.error) {
            $errorContainer.after("<div class='foswikiErrorMessage'>Error: "+data.error.message+"</div>");
          } else {
            loadComments();
          }
          $.modal.close();
        },
        error: function(xhr, msg) {
          var data = $.parseJSON(xhr.responseText);
          $.unblockUI();
          $errorContainer.after("<div class='foswikiErrorMessage'>Error: "+data.error.message+"</div>");
          $.modal.close();
        }
      });
    });

    // add reply behaviour
    $this.find(".cmtReply").click(function() {
      var $comment = $(this).parents(".cmtComment:first"),
          commentOpts = $.extend({}, $comment.metadata());

      $this.find(".foswikiErrorMessage").remove();

      foswiki.openDialog('#cmtReplyComment', {
        persist:true,
        containerCss: {
          width:600
        },
        onShow: function(dialog) { 
          dialog.container.find(".cmtCommentIndex").text(commentOpts.index);
          dialog.container.find("input[name='ref']").val(commentOpts.comment_id);
        }
      });

      return false;
    });

    // add edit behaviour
    $this.find(".cmtEdit").click(function() {
      var $comment = $(this).parents(".cmtComment:first"),
          commentOpts = $.extend({}, $comment.metadata());

      $this.find(".foswikiErrorMessage").remove();
      $.jsonRpc(foswiki.getPreference("SCRIPTURL")+"/jsonrpc", {
        namespace: "MetaCommentPlugin",
        method: "getComment",
        params: {
          "topic": opts.web+"."+opts.topic,
          "comment_id": commentOpts.comment_id
        },
        success: function(json, msg, xhr) {
          $.unblockUI();
          foswiki.openDialog('#cmtUpdateComment', {
            persist:true,
            containerCss: {
              width:600
            },
            onShow: function(dialog) { 
              dialog.container.find("input[name='comment_id']").val(commentOpts.comment_id);
              dialog.container.find("input[name='index']").val(commentOpts.index);
              dialog.container.find(".cmtCommentIndex").text(commentOpts.index);
              dialog.container.find("input[name='title']").val(json.result.title);
              dialog.container.find("textarea[name='text']").val(json.result.text);
            }
          });
        },
        error: function(json, msg, xhr) {
          $.unblockUI();
          $comment.parent().append("<div class='foswikiErrorMessage'>Error: "+json.error.message+"</div>");
        }
      });

      return false;
    });

    // add approve behaviour
    $this.find(".cmtApprove").click(function() {
      var $comment = $(this).parents(".cmtComment:first"),
          commentOpts = $.extend({}, $comment.metadata());

      $this.find(".foswikiErrorMessage").remove();

      foswiki.openDialog('#cmtConfirmApprove', {
        persist:false,
        containerCss: {
          width:300
        },
        onShow: function(dialog) { 
          dialog.container.find(".cmtCommentNr").text(commentOpts.index);
          dialog.container.find(".cmtAuthor").text(commentOpts.author);
          dialog.container.find(".cmtDate").text(commentOpts.date);
        },
        onSubmit: function(dialog) {
          $.blockUI({
            message:"<h1>Approving comment "+commentOpts.index+" ...</h1>",
            fadeIn: 0,
            fadeOut: 0
          });
          $.jsonRpc(foswiki.getPreference("SCRIPTURL")+"/jsonrpc", {
            namespace: "MetaCommentPlugin",
            method: "approveComment",
            params: {
              topic: opts.web+"."+opts.topic,
              comment_id: commentOpts.comment_id
            },
            error: function(json) {
              $.unblockUI();
              $comment.find(".cmtCommentContainer").append("<div class='foswikiErrorMessage'>Error: "+json.error.message+"</div>");
            },
            success: function(json) {
              $.unblockUI();
              loadComments();
            }
          });
        }
      });
      return false;
    });

    // add delete behaviour 
    $this.find(".cmtDelete").click(function() {
      var $comment = $(this).parents(".cmtComment:first"),
          commentOpts = $.extend({}, $comment.metadata());

      $this.find(".foswikiErrorMessage").remove();

      foswiki.openDialog('#cmtConfirmDelete', {
        persist:false,
        containerCss: {
          width:300
        },
        onShow: function(dialog) { 
          dialog.container.find(".cmtCommentNr").text(commentOpts.index);
          dialog.container.find(".cmtAuthor").text(commentOpts.author);
          dialog.container.find(".cmtDate").text(commentOpts.date);
        },
        onSubmit: function(dialog) {
          $.blockUI({
            message:"<h1>Deleting comment "+commentOpts.index+" ...</h1>",
            fadeIn: 0,
            fadeOut: 0
          });
          $.jsonRpc(foswiki.getPreference("SCRIPTURL")+"/jsonrpc", {
            namespace: "MetaCommentPlugin",
            method: "deleteComment",
            params: {
              "topic": opts.web+"."+opts.topic,
              "comment_id": commentOpts.comment_id
            },
            error: function(json) {
              $.unblockUI();
              $comment.find(".cmtCommentContainer").append("<div class='foswikiErrorMessage'>Error: "+json.error.message+"</div>");
            },
            success: function(json) {
              $.unblockUI();
              $comment.slideUp(function() {
                $comment.parent().hide();
                loadComments();
              });
            }
          });
        }
      });
      return false;
    });

    // work around blinking twisties
    setTimeout(function() {
      $this.find(".twistyPlugin").show();
    }, 1);
  });
});
