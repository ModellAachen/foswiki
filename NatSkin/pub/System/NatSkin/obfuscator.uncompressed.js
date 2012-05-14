// (c)opyright 2006-2012 Michael Daum http://michaeldaumconsulting.com
var emoas;
(function($) {
  $.wremo = {
    build: function(options) {
      return this.each(function() {
        $(this).empty();
        var id = $(this).attr('id');
        var ems = [];
        for (var i = 0; i < emoas[id][1].length; i++) {
          ems.push(emoas[id][1][i][1]+'@'+emoas[id][1][i][0]+emoas[id][1][i][2]);
        }
        var txt = emoas[id][0] || ems.join(', ');
        var href = 'ma'+'il'+'to'+':'+ems.join(', ');
        $("<a></a>").attr('href', href).append(txt).appendTo(this);
      });
    }
  };

  $(function() {
    $.fn.wremo = $.wremo.build;
    $(".wremo").wremo();
  });

})(jQuery);
