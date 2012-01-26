(function($) { 
    var restUpdate = function() {
	var input = $(this);
	var form = input.closest("form");
	// Transfer user selected value to "value" field
	if (input.hasClass("userval"))
	    form[0].value.value = input.val();
	if (typeof(StrikeOne) != 'undefined')
	    StrikeOne.submit(form);
	$.ajax({
	    url: form.attr("action"),
	    type: "post",
	    data: form.serialize(),
	    //dataType: "json",
	    success: function(d, t, r) {
		//console.debug(t);
		if (input.attr("tagName") == "SELECT") {
		    input.attr("class", input.attr("class").replace(/\s*\bvalue_\S+\b/, ''));
		    input.addClass("value_" + input.val());
		}
	    },
	    error: function(r, t, e) {
		alert(t);
	    }
	});
    };

    $("select.atp_update").livequery("change", restUpdate);
    $("input.atp_update").livequery("click", restUpdate);

    $('a.atp_edit').livequery("click", function(event) {
	var div = $("#atp_editor");
	if (!div.length) {
	    div = $("<div id='atp_editor' title='Edit action'></div>");
	    $("body").append(div);
	    div.dialog({autoOpen: false, width: 600});
	}
	div.load(this.href,
		 function(done, status) {
		     var m = /<!-- ATP_CONFLICT ~(.*?)~(.*?)~(.*?)~(.*?)~ -->/.exec(done, "s");
		     if (m) {
			 var ohno = "<p style='color:red'>Could not access " + m[1] +
			     ", the topic containing this action.</p>" +
			     m[2];
			 if (m[4] == "") {
			     ohno += " may still be editing the topic, but their lease expired " +
				 m[3] + " ago.";
			 } else {
			     ohno += " has been editing the topic for " + m[3] +
				 " and their lease is still active for another " + m[4];
			 }
			 ohno += "<p>To clear the lease, try editing " + m[1] +
			     " with the standard text editor.</p>";
			 div.html(ohno);
			 div.dialog("open");
		     } else if (status == "error") {
			 alert("Error when I tried to edit the action");
		     } else {
			 div.dialog("open");
		     }
		 });
	return false;
    });

    $('#atp_editor input[type="submit"]').livequery(function() {
	$(this).click(function() {
	    $("#atp_editor").dialog("close");
	    return true;
	});
    });

    $("#atp_editor form[name='loginform']").livequery("submit",
	function() {
	    var form = $(this);
	    $.ajax({
		url: form.attr("action"),
		data: form.serialize(),
		success: function(d, t, r) {
		    // Dialog will have been closed by the submit. That's
		    // OK, as we want to relayout anyway.
		    $("#atp_editor").html(d).dialog("open");
		},
		error: function(r, t, e) {
		    // IE fails validation of the login
		    alert("Sorry, validation failed, possibly because someone else is already editing the action. Please try again in a few minutes.");
		}
	    });
	    return false;
	});
})(jQuery); 
