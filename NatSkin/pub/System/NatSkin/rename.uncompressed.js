jQuery(function($) {
  var $form = $("form[name='rename']");

  $(".natRenameSetAll").click(function() {
    $(this).parents("form:first").find("input[name=referring_topics]").attr('checked', 'checked');
    return false;
  });
  $(".natRenameClearAll").click(function() {
    $(this).parents("form:first").find("input[name=referring_topics]").removeAttr('checked');
    return false;
  });

  $("#wikifynewtopic").change(function() {
    var $this = $(this), 
        $target = $("input[name='newtopic']"),
        $source = $("#topictitle");
        
    if ($this.is(":checked")) {
      $target.attr("disabled", "disabled");
      $target.wikiword("#topictitle");
    } else {
      $target.removeAttr("disabled");
      $source.unbind();
    }
  });

  $form.submit(function() {
    $("input[name='newtopic']").removeAttr("disabled");
    return true;
  });

});
