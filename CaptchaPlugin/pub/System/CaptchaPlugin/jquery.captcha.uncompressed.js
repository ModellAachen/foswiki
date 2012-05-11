jQuery(function($) {

  var defaults = {
        endpoint: foswiki.getPreference('SCRIPTURL')+'/jsonrpc/CaptchaPlugin',
        template: "<img src='${url}' height='${height}' width='${width}' /><input type='hidden' name='captcha_challenge' value='${challenge}' />",
        captchaContainer: '.jqCaptchaContainer',
        reloadButton: '.jqCaptchaReload',
        challengeName: 'captcha_challenge',
        responseName: 'captcha_response',
        createParams: {
          width:170,
          height:65
        },
        validateOnSubmit: true,
        disableOnSuccess: false
      };

  // Captcha object
  function Captcha(element, options) {
    var captcha = this;

    captcha.element = element;
    captcha.options = $.extend( {}, defaults, options) ;

    //console.log("captcha=", captcha);
    captcha.init();
  }

  Captcha.prototype.load = function() {
    var captcha = this,
        $container = $(captcha.element).find(captcha.options.captchaContainer);

    //console.log("load container=",$container);

    $.jsonRpc(
      captcha.options.endpoint, {
        method:"create",
        params: captcha.options.createParams,
        success: function(json, status, xhr) {
          //console.log(json);
          $container.empty().append($.tmpl(captcha.options.template, json.result));
        },
        error: function(json, status, xhr) {
          // TODO
          alert("Error: "+json.error.message);
        }
      }
    );
  }

  Captcha.prototype.init = function() {
    var captcha = this,
        $captcha = $(captcha.element);

    //console.log("init");
    
    // loading img
    captcha.load();

    // reload behavior
    $captcha.find(captcha.options.reloadButton).each(function() {
      var $btn = $(this);

      $btn.click(function() {
        captcha.unflagError();
        captcha.unflagSuccess();
        captcha.load();
        $captcha.find("input[name='"+captcha.options.challengeName+"']").val("").focus();
        return false;
      });
    });

    // event handler
    $captcha.bind("reload.captcha", function() {
      var captcha = $captcha.data("captcha");
      captcha.unflagError();
      captcha.unflagSuccess();
      captcha.load();      
    });

    // add to submit event
    if (this.options.validateOnSubmit) {
      $captcha.parents("form:first").submit(function() {
        //console.log("captcha got a submit event");
        return captcha.validate();
      });
    }

    // setting captcha height and width to prevent flickering
    $captcha.find(captcha.options.captchaContainer).css({
      width:captcha.options.createParams.width,
      height:captcha.options.createParams.height
    });

  };

  Captcha.prototype.params = function(options) {
    if (typeof(options) === 'undefined') {
      return this.options.createParams;
    } else {
      return $.extend(this.options.createParams, options);
    }
  };

  Captcha.prototype.validate = function() {
    var captcha = this,
        $captcha = $(captcha.element),
        $challenge = $captcha.find("input[name='"+captcha.options.challengeName+"']"),
        challenge = $challenge.val(),
        $response = $captcha.find("input[name='"+captcha.options.responseName+"']"),
        response = $response.val(),
        isValid = false;

    //console.log("challenge="+challenge+" response="+response);

    if (challenge && response) {
      $.ajax({
        url: foswiki.getPreference("SCRIPTURL")+"/rest/CaptchaPlugin/validate",
        async: false,
        data: {
          t: (new Date).getTime(),
          challenge: challenge,
          response: response
        },
        success: function(data, status, xhr) {
          isValid = (data === 'true');
        }
      });
    }

   //console.log("isValid=",isValid);
    if (isValid) {
      captcha.unflagError();
      captcha.flagSuccess();
      if (captcha.options.disableOnSuccess) {
        $response.attr("disabled", "disabled");
        $challenge.attr("disabled", "disabled");
      }
    } else {
      captcha.load();
      captcha.unflagSuccess();
      captcha.flagError();
      $response.val("").focus();
    }

    return isValid;
  };

  Captcha.prototype.flagError = function() {
    var captcha = this, $captcha = $(captcha.element);

    captcha.unflagSuccess();
    $captcha.find("input[name='"+captcha.options.responseName+"']").addClass("error");
    $captcha.find("label.error").show();
  };

  Captcha.prototype.unflagError = function() {
    var captcha = this, $captcha = $(captcha.element);

    $captcha.find("input[name='"+captcha.options.responseName+"']").removeClass("error");
    $captcha.find("label.error").hide();
  };

  Captcha.prototype.flagSuccess = function() {
    var captcha = this, $captcha = $(captcha.element);

    captcha.unflagError();
    $captcha.find("label.success").show();
  };

  Captcha.prototype.unflagSuccess = function() {
    var captcha = this, $captcha = $(captcha.element);

    $captcha.find("label.success").hide();
  };

  // extend jQuery
  $.fn.captcha = function(options) {
    //console.log("plugin called");
    return this.each(function() {
      if(!$.data(this, 'captcha')) {
        $.data(this, 'captcha', new Captcha(this, options));
      }
    });
  };
   
  // integrate into page
  $(".jqCaptcha:not(.jqCaptchaInited)").livequery(function() {
    var $this = $(this),
        options = $.extend({}, $this.metadata());

    //console.log("livequery");

    $this.addClass("jqCaptchaInited").captcha(options);
  });
});
