/**
 * jquery.uploader.js
 *
 * Copyright 2010-2012, Michael Daum http://michaeldaumconsulting.com
 *
 * based on jquery.plupload.queue.js  Copyright 2009, Moxiecode Systems AB
 *
 */

(function($) {

  var defaults;

  $.fn.uploader = function(settings) {

    this.each(function() {
      var $this = $(this),
          fileList = $this.find(settings.fileList),
          browseButton = $this.find(settings.browseButton),
          startButton = $this.find(settings.startButton),
          stopButton = $this.find(settings.stopButton),
          messageContainer = $this.find(settings.messageContainer),
          commentField = $this.find(settings.commentField),
          createLinkBox = $this.find(settings.createLinkBox),
          hideFileBox = $this.find(settings.hideFileBox),
          autoStartBox = $this.find(settings.autoStartBox),
          stopClicked = false,
          isInited = false;

      // set the browser button
      var browseId = browseButton.attr("id");
      if (!browseId) {
        browseId = plupload.guid();
        browseButton.attr("id", browseId);
      }
      settings.browse_button = browseId;
      
      // set container 
      var containerId = browseButton.parent().attr("id");
      if (!containerId) {
        containerId = plupload.guid();
        browseButton.parent().attr("id", containerId);
      }
      settings.container = containerId;
      

      var uploader = new plupload.Uploader(settings);

      // bind events
      commentField.keypress(function(e) {
        if (e.keyCode == "13") {
          $this.trigger("Start");
          e.preventDefault();
          return false;
        }
      });

      // init autoStartBox
      if (!autoStartBox.is(".foswikiHidden")) {
        if (foswiki.Pref.getPref("UPLOADER::AUTOSTART")== "true") {
          autoStartBox.attr("checked", "checked");
          startButton.hide();
        } else {
          autoStartBox.removeAttr("checked");
        }
      }

      // add autoStartBox behaviour
      autoStartBox.change(function() {
        var autoStart = autoStartBox.is(":checked");
        //$.log("UPLOADER: autoStartBox changed ... autoStart = "+autoStart);
        foswiki.Pref.setPref("UPLOADER::AUTOSTART", autoStart?"true":"false");
        autoStartBox.blur();
        if (autoStart) {
          startButton.hide();
        } else {
          startButton.show();
        }
      });

      /**********************************************************************/
      function handleStatus(file) {
        var state = file.status, 
          actionClass, 
          fileRow = $("#"+file.id),
          statusText = file.statusText || "";

        $.log("UPLOADER: called handleStatus for "+file.name+" state="+state);
        fileRow.find(".jqUploaderFileAction").removeClass("jqUploaderDelete").children("a").attr("title", statusText);

        if (state == plupload.DONE) {
          actionClass = "jqUploaderDone";
        }

        if (state == plupload.FAILED) {
          actionClass = "jqUploaderFailed";
        }

        if (state == plupload.QUEUED) {
          actionClass = "jqUploaderQueued";
          fileRow.find(".jqUploaderFileAction").addClass("jqUploaderDelete");
        }

        if (state == plupload.UPLOADING) {
          actionClass = "jqUploaderUploading";
        }

        if (state < 0) {
          actionClass = "jqUploaderError";
        }

        if (actionClass !== undefined) {
          $.log("UPLOADER: actionClass="+actionClass);
          fileRow.removeClass("jqUploaderDone jqUploaderFailed jqUploaderQueued jqUploaderUploading").addClass(actionClass);

        }

        return fileRow;
      };

      /*********************************************************************/
      function updateMessage(msg, msgClass) {
        //$.log("UPLOADER: updateMessage");

        if (msgClass !== undefined) {
          messageContainer
            .removeClass("foswikiSuccessMessage foswikiErrorMessage foswikiTipMessage")
            .addClass(msgClass);
        }

        if (msg === undefined) {
          var uploaded = uploader.total.uploaded +1, 
              failed = uploader.total.failed,
              bytesPerSec = uploader.total.bytesPerSec,
              nrFiles = uploader.files.length;

          if (uploaded > nrFiles) {
            uploaded = nrFiles;
          }
          if (failed > nrFiles) {
            failed = nrFiles;
          }

          msg = "Uploading ";

          msg += uploaded+" of "+nrFiles+" file(s)";
          if (failed) {
            msg += ", "+failed+" failed";
          }

          if (bytesPerSec) {
            msg += " with "+plupload.formatSize(bytesPerSec)+"/s";
          }
        }

        return messageContainer.text(msg).show();
      };

      /*********************************************************************/
      function updateFileProgress(file) {
        $.log("UPLOADER: called updateFileProgress for "+file.name);
        var fileRow = $("#"+file.id),
            fileName = fileRow.find(".jqUploaderFileName"),
            width = fileName.width() * file.percent / 100.0,
            height = fileName.height();

        //$.log("percent="+file.percent+" width="+width);

        fileRow.find(".jqUploaderFileProgress").css({
          "width": width+ "px",
          "height": height+ "px"
        });

        fileRow.find(".jqUploaderFileStatus").html(file.percent + "%");

        handleStatus(file);
      };

      /*********************************************************************/
      function updateList() {
        $.log("UPLOADER: updateList");
        fileList.empty();
        $.each(uploader.files, function(i, file) {
          addFile(file);
          updateFileProgress(file);
        });
        $.log("UPLOADER: uploader has got "+uploader.files.length+" file(s)");
      };

      /**********************************************************************/
      function addFile(file) {
        var fileSize = file.size, fileRow;

        if (file.status == plupload.DONE) {
          return;
        }
        $.log("UPLOADER: called addFile()");

        if (fileSize) {
          fileSize = plupload.formatSize(fileSize);
        } else {
          fileSize = "";
        }

        fileRow = $(
          "<tr id='" + file.id + "'>" +
            "<td class='jqUploaderFileName'>" +
              "<div class='jqUploaderFileProgress'></div>" + file.name +
            "</td>" +
            "<td class='jqUploaderFileSize'>" + fileSize + "</td>" +
            "<td class='jqUploaderFileStatus'></td>" +
            "<td class='jqUploaderFileAction'><a href='#'></a></td>" +
          "</tr>"
        ).appendTo(fileList);

        $.log("UPLOADER: adding "+file.name+" id="+file.id);

        $(".jqUploaderFileAction a", fileRow).click(function(e) {
          $.log("UPLOADER: file action clicked for "+file.name);
          var actionButton = $(this);
          if (actionButton.parent().is(".jqUploaderDelete")) {
            $.log("UPLOADER: ... removing");
            fileRow.remove();
            uploader.removeFile(file);
          } else {
            $.log("action class="+actionButton.parent().attr("class"));
          }
          return false;
        });

        return fileRow;
      };

      /**********************************************************************/
      uploader.bind("BeforeUpload", function(up, file) {
        $.log("UPLOADER: got BeforeUpload event for file "+file.name);
        var comment = commentField.val(),
            createlink = createLinkBox.is(":checked"),
            hidefile = hideFileBox.is(":checked");

        if (uploader.features.multipart && uploader.settings.multipart) {
          uploader.settings.multipart_params = {
            "topic": encodeURI(foswiki.getPreference("WEB")) + "." + encodeURI(foswiki.getPreference("TOPIC")),
            "id": (new Date).getTime(),
            "filecomment": encodeURI(comment),
            "createlink": (createlink?"on":"off"),
            "hidefile": (hidefile?"on":"off")
          };
        } else {
          uploader.settings.url = settings.url + "?"
            + "topic=" + encodeURI(foswiki.getPreference("WEB")) + "." + encodeURI(foswiki.getPreference("TOPIC")) + "&"
            + "id=" + (new Date).getTime()
            + "&filecomment=" + encodeURI(comment)
            + "&createlink=" + (createlink?"on":"off")
            + "&hidefile=" + (hidefile?"on":"off");
        }

        $.log("UPLOADER: url="+uploader.settings.url);
      });

      /**********************************************************************/
      uploader.bind("UploadComplete", function(up, files) {
        $.log("UPLOADER: got UploadComplete event for files");
      });

      /**********************************************************************/
      uploader.bind("UploadFile", function(up, file) {
        $.log("UPLOADER: got UploadFile event for file "+file.name);
        var fileRow = $("#"+file.id);
        updateFileProgress(file);
        updateMessage();
        $this.find(".jqUploaderFilesContainer").stop().scrollTo(fileRow, {
          duration:300,
          onAfter: function () {
            fileRow.addClass("jqUploaderCurrent");
          },
          offset: {
            top:-97,
            left:0
          }
        });
      });

      /*********************************************************************/
      uploader.bind("Init", function(up, res) {
        if (isInited) {
          $.log("UPLOADER: warning ... alread had an init event ... ignoring")
          return;
        }

        $.log("UPLOADER: got Init event");
        $.log("UPLOADER: using runtime: " + res.runtime);

        isInited = true;

        // Enable drag/drop
        if (uploader.features.dragdrop && uploader.settings.dragdrop) {
          
          var dropZone = fileList.parent();
          var id = dropZone.attr("id");
          if (!id) {
            id = plupload.guid();
            dropZone.attr("id", id);
          }
          $.log("UPLOADER: enabling drag&drop on id=#"+id);
          $this.find(".jqUploaderDropText").show();
          uploader.settings.drop_element = id;
        }

        startButton.click(function(e) {
          $.log("your clicked the start button");
          messageContainer.hide();
          $this.trigger("Start");
          return false;
        });

        stopButton.click(function(e) {
          $.log("your clicked the stop button");
          $this.trigger("Stop");
          return false;
        });
      });

      /*********************************************************************/
      uploader.bind("Error", function(up, err) {
        var file = err.file, 
            msg = err.message.replace(/\.$/, "");
        
        if (err.details) {
          msg += ", "+err.details;
        }

        if (file) {
          msg = file.name+": "+msg;
          handleStatus(file).attr("title", msg);
        }

        $.log("UPLOADER: got Error event "+msg);
        updateMessage(msg, "foswikiErrorMessage");
      });

      /*********************************************************************/
      uploader.bind("StateChanged", function() {
        $.log("UPLOADER: got StateChanged event");
        if (uploader.state == plupload.STOPPED) {
          $.log("UPLOADER ... stopped");
          var errorMsg;

          if (stopClicked) {
            errorMsg = "Error: transfer aborded";
          } else if (uploader.total.failed) {
            errorMsg = "Error: some files faild to upload";
          } else {
            //$.growlUI("All files uploaded", "", 2000);
          }

          if (errorMsg) {
            // ERROR
            if (!messageContainer.is(".foswikiErrorMessage")) {
              updateMessage(errorMsg, "foswikiErrorMessage");
            }
            /*
            window.setTimeout(function() { 
              messageContainer.fadeOut();
            }, 2000);
            */

            if (uploader.settings.error) {
              $.log("UPLOADER: calling error handler");
              uploader.settings.error($this, uploader.files);
            }
          } else {
            // SUCCESS
            if (uploader.settings.success) {
              $.log("UPLOADER: calling success handler");
              uploader.settings.success($this, uploader.files);
            }
          }

          stopButton.hide();
          if (!autoStartBox.is(":checked")) {
            startButton.show();
          }

        } else if (uploader.state === plupload.STARTED) {
          stopClicked = false;
          updateMessage(undefined, "foswikiTipMessage");
        }
        updateList();
      });

      /*********************************************************************/
      uploader.bind("QueueChanged", function() {
        $.log("UPLOADER: got QueueChanged event");
        updateList();
        if (uploader.state !== plupload.STARTED) {
          if (autoStartBox.is(":checked")) {
            $.log("UPLOADER: autostart");
            $this.trigger("Start");
          } else {
            $.log("UPLOADER: no autostart");
          }
        }
      });

      /*********************************************************************/
      uploader.bind("FileUploaded", function(up, file, args) {
        var response, parseError = false;

        $.log("UPLOADER: got FileUploaded event for file "+file.name);

        // expect non-wellformed json
        try {
          response = $.parseJSON(args.response);
        } catch (e) {
          alert("can't parse json response from backend");
          parseError = true;
        }

        // patch in renamed files
        if (!parseError) {
          $.each(uploader.files, function(i, file) {
            if (typeof(response.result[file.name]) != 'undefined') {
              file.name = response.result[file.name];
            }
          });
        }

        updateFileProgress(file);
        updateMessage();
      });

      /*********************************************************************/
      uploader.bind("UploadProgress", function(up, file) {
        $.log("UPLOADER: got UploadProgress event for file "+file.name);
        if (uploader.state !== plupload.STOPPED) {
          if (uploader.total.uploaded == uploader.files.length) {
            uploader.stop();
          } else {
            updateFileProgress(file);
            updateMessage();
          }
        } else {
          updateList();
        }
      });

      /*********************************************************************/
      uploader.bind("FilesAdded", function(up, files) {
        $.log("UPLOADER: got FilesAdded event");
        messageContainer.hide();
      });

      /*********************************************************************/
      uploader.bind("ChunkUploaded", function(up, file, args) {
        $.log("UPLOADER: got ChunkUploaded even for file "+file.name);
      });

      /*********************************************************************/
      uploader.bind("FilesRemoved", function() {
        $.log("UPLOADER: got FilesRemoved event");
        //updateList();
      });

      /*********************************************************************/
      uploader.bind("PostInit", function(up) {
        //$.log("UPLOADER: got PostInit even");
      });

      /*********************************************************************/
      $this.bind("Refresh", function(e) {
        $.log("UPLOADER: got Refresh event");
        uploader.refresh();
        e.stopPropagation();
        return false;
      });

      /*********************************************************************/
      $this.bind("Start", function(e) {
        $.log("UPLOADER: got Start event");
        var nrFiles = uploader.files.length;
        if (nrFiles) {
          if (!$(this).is("plupload_disabled")) {
            $.log("UPLOADER: starting ...");
            startButton.hide();
            stopButton.show();
           uploader.start();
          } 
        } else {
          $.log("UPLOADER: not starting ... no files in queue");
        }
      });

      /*********************************************************************/
      $this.bind("Stop", function(e) {
        $.log("UPLOADER: got Stop event");
        stopClicked = true;
        if (!autoStartBox.is(":checked")) {
          startButton.show();
        }
        stopButton.hide();
        $.each(uploader.files, function(i, file) {
          if(file.status == plupload.UPLOADING) {
            $.log("UPLOADER: ... setting file "+file.name+" to FAILED");
            file.status = plupload.FAILED;
          }
        });
        uploader.stop();
      });


      /*********************************************************************/
      $.log("UPLOADER: initing uploader");
      uploader.init();
    });

    return this;
  };

  /************************************************************************/
  $(function() {

    var attachFileSizeLimit = foswiki.getPreference("TopicInteractionPlugin.attachFileSizeLimit") || 0;
    attachFileSizeLimit *= 1024;

    defaults = {
      dragdrop: true,
      /* chunk_size: "100KB", // 100KB: for debugging progress, 10MB for real world apps, or even undefine */
      max_file_size: attachFileSizeLimit,
      multipart: true,
      urlstream_upload: true, // SMELL: required by flash backend. you get a flash io error #2038 for some reasons otherwise
      file_data_name: "file",
      multi_selection: true,
      filters: [
        {title: "All files", extensions: "*"},
        {title: "Archives", extensions: "zip,rar,gz,bz,tar"},
        {title: "Audio files", extensions: "amr,awb,amr,awb,axa,au,snd,flac,mid,midi,kar,mpga,mpega,mp2,mp3,m4a,m3u,oga,ogg,spx,sid,aif,aiff,aifc,gsm,m3u,wma,wax,ra,rm,ram,ra,pls,sd2,wav"},
        {title: "Image files", extensions: "art,bmp,cdr,cdt,cpt,djvu,djv,gif,ico,ief,jng,jpeg,jpg,jpe,pat,pbm,pcx,pgm,png,pnm,ppm,psd,ras,rgb,svg,svgz,tiff,tif,wbmp,xbm,xpm,xwd"},
        {title: "MS Office files", extensions: "doc,docx,xls,xlsx,ppt,pptx"},
        {title: "Open Office files", extensions: "odc,odb,odf,odg,otg,odi,odp,otp,ods,ots,odt,odm,ott,oth"},
        {title: "PDF files", extensions: "pdf"},
        {title: "Text files", extensions: "txt"},
        {title: "Video files", extensions: "3gp,axv,dl,dif,dv,fli,gl,mpeg,mpg,mpe,mp4,m4v,qt,mov,ogv,mxu,flv,lsf,lsx,mng,asf,asx,wm,wmv,wmx,wvx,avi,movie,mpv"}
      ],
      runtimes: foswiki.getPreference("TopicInteractionPlugin.Runtimes"),
      flash_swf_url: foswiki.getPreference("TopicInteractionPlugin.flashUrl"),
      silverlight_xap_url: foswiki.getPreference("TopicInteractionPlugin.silverlightUrl"),
      url: foswiki.getPreference("SCRIPTURL")+"/rest/TopicInteractionPlugin/upload",
      fileList: ".jqUploaderFiles",
      browseButton:  ".jqUploaderBrowse",
      startButton:  ".jqUploaderStart",
      stopButton:  ".jqUploaderStop",
      messageContainer:  ".jqUploaderMessage",
      commentField: ".jqUploaderComment",
      createLinkBox: ".jqUploaderCreateLink",
      hideFileBox: ".jqUploaderHideFile",
      autoStartBox: ".jqUploaderAutoStart",
      error: null,
      success: function (uploader, files) {
        $.log("UPLOADER: finished");
      }
    };

    /* init */
    $(".jqUploader:not(.jqInitedUploader)").livequery(function() {
      var $this = $(this),
          settings = $.extend({}, defaults, $this.metadata());

      $.log("UPLOADER: found a jqUploader");
      $this.addClass("jqInitedUploader");
      $this.uploader(settings);
    });
  });
  
})(jQuery);
