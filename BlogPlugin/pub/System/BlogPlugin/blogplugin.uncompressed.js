jQuery(function($) {
  $("#blogFetchTitle").live("click", function() {
    var $field = $(this).parents(".foswikiFormStep:first").find("input"),
        title = $("input[name=TopicTitle]").val();

    if (!title) {
      title = foswiki.getPreference("TOPIC");
    }

    $field.val(title.substr(0, 60));
    return false;
  });

  $("#blogFetchDescription").live("click", function() {
    var $field = $(this).parents(".foswikiFormStep:first").find("textarea"),
        description = $("input[name=Summary]").val();

    if (!description) {
      description = $("#topic").val();
    }

    $field.val(description.replace(/<[^>]*>/g, "").replace(/\n\s*\n/g, "").substr(0, 160));
    return false;
  });

  $("#blogFetchKeywords").live("click", function() {
    var $field = $(this).parents(".foswikiFormStep:first").find("input"),
        keywords = [];
        
    $("input[name=Tag]").each(function() {
      var val = $(this).val();
      if (val) {
        keywords = keywords.concat(val.split(/\s*,\s*/));
      }
    });

    $field.val(keywords.join(", "));
    return false;
  });
});
