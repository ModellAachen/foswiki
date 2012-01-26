jQuery(function($) {

  $(".jqRenameTag").each(function() {
    // ajaxification of renametagform
    var $this = $(this),
        opts = $.extend({}, $this.metadata());

    $this.ajaxForm({
        dataType: 'json',
        beforeSubmit: function(data, form, options) {
          var from = new Array;
          $this.find("input[name=from]").each(function() {
            var val = $(this).val();
            if (val) {
              from.push(val);
            }
          });
          if (from.length == 0) {
            return false;
          }
          $("#renameTagDialog").dialog("close");
          $.blockUI({message:"<h1> Processing ... </h1>"});
          if (typeof(foswikiStrikeOne) != 'undefined') {
            foswikiStrikeOne($this[0]);
          }
        },
        success: function(data, status) {
          var url = foswiki.getPreference("SCRIPTURL")+"/view/"+foswiki.getPreference("WEB")+"/"+foswiki.getPreference("TOPIC");
          $.unblockUI();
          $.blockUI({message:"<h1> "+data.result+"</h1>"});
          if (typeof(opts.onsuccess) == 'function') {
            opts.onsuccess.call(this, $this);
          }
          window.setTimeout(function() {
            window.location.href = url;
          }, 500);
        },
        error: function(xhr, status) {
          var data = $.parseJSON(xhr.responseText);
          $.unblockUI();
          $.blockUI({message:"<h1> "+data.error.message+"</h1>"});
          window.setTimeout(function() {
            $.unblockUI();
            if (typeof(opts.onerror) == 'function') {
              opts.onerror.call(this, $this);
            }
          }, 1000);
        }
    });
  });
});
