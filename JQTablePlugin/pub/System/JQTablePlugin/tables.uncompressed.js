/*
 * Copyright (C) Foswiki Contributors 2010
 * Author: Crawford Currie http://c-dot.co.uk
 * Javascript implementation of TablePlugin
 * Uses the jQuery tablesorter plugin
 */
(function($) {
    var jqtp = {
        // Mappings for tableframe attributes
        tableframe: {
            'void':   'none',
            'above':  'solid none none none',
            'below':  'none none solid none',
            'lhs':    'none none none solid',
            'rhs':    'none solid none none',
            'hsides': 'solid none solid none',
            'vsides': 'none solid none solid',
            'box':    'solid',
            'border': 'solid'
        },

        defaultOpts: {
          widgets: ['colorize']
        },

        // Process elements marked with "jqtp_process". These are generated
        // when %TABLE tags are expanded.
        process : function() {
            var pdata = '({' + $(this).attr('title') + '})';
            var params = eval(pdata);
            var table = jqtp.nextTable(this);
            if (!table) {
                return;
            }
            $(table).attr("jqtp_params", pdata);
            jqtp.doTable(params, $(table));
            $(this).remove();
        },
        
        // Find the next TABLE tag after the given element. This matches
        // a %TABLE with the following <table>
        nextTable : function(el) {
            if (el === null) {
                return null;
            }
            do {
                // Zoom up
                while (el.nextSibling === null) {
                    if (el.parentNode === null) {
                        return null; // end of the road
                    } else {
                        el = el.parentNode;
                    }
                }
                // Next
                el = el.nextSibling;
                // Zoom down; stop and visit tables we pass on the way
                while (el.tagName != 'TABLE' && el.firstChild) {
                    el = el.firstChild;
                }
            } while (el && el.tagName != 'TABLE');
            return el;
        },

        // Add units to a number, for CSS
        unitify : function(n) {
            if (/^\d+$/.test(n)) {
                return n + "px";
            } else {
                return n;
            }
        },

        // Apply the given %TABLE params (p) to a table (t)
        doTable : function(p, t) {
            if (p.id !== undefined) {
                t.id = p.id;
            }
            if (p.summary !== undefined) {
                t.summary = p.summary;
            }
            if (p.caption !== undefined) {
                t.append("<caption>" + p.caption + "</caption>");
            }

            var hrc = p.headerrows;
            var frc = p.footerrows;

            jqtp.cleanHeadAndFoot(t, hrc, frc);

            jqtp.collapseCells(t);

            jqtp.colours(p, t);
            jqtp.borders(p, t);
            jqtp.layout(p, t);
            jqtp.align(p, t);
            if (p.sort == "on" && (p.disableallsort != "on")) {
                t.addClass("jqtp_sortable");
            }
        },

        // Find cell-collapse marks (^) and assign a rowspan
        // to the first non-^ cell in the rows above.
        collapseCells : function(t) {
            var span = /^\s*\^\s*$/;
            t.find("tr").each(
                function () {
                    $(this).find("td")
                        .add($(this).find("th"))
                        .filter(
                            function() {
                                return span.test( $(this).text() );
                            })
                        .each(
                            function() {
                                var offset = $(this).prevAll().length;
                                var rb = $(this);
                                do {
                                    rb = rb.parent().prev()
                                        .children().eq(offset);
                                } while (span.test(rb.text()));
                                rb.attr("rowspan", rb.attr("rowspan") + 1);
                            });
                });
            // Now chop out the spanned cells
            t.find("td")
            .add($(this).find("th"))
            .filter(
                function() {
                    return span.test( $(this).text() );
                })
            .remove();
        },

        // try and pull out head and foot
        cleanHeadAndFoot : function(t, hrc, frc) {
            var bodies = t.children('tbody'),
                b = bodies[0],
                h = t.find('thead'),
                bratz;
            
            if (h.length === 0 && b.firstChild) {
                // No THEAD, but TBODY has some rows
                if (hrc !== undefined) {
                    if (hrc > $(b).children().length) {
                        hrc = $(b).children().length;
                    }
                } else {
                    // See if we can find header rows by grouping
                    hrc = 0;
                    var fc = b.firstChild;
                    while (fc && fc.firstChild && fc.firstChild.tagName == 'TH') {
                        hrc++;
                        fc = fc.nextSibling;
                    }
                }
                if (hrc > 0) {
                    bodies.before("<thead></thead>");
                    h = t.find('thead');
                    while (hrc--) {
                        bratz = $(b).children();
                        h.append($(bratz[0]).remove());
                    }
                }
            }

            var f = t.find('tfoot');
            if (f.length !== 0 && f.children().length === 0) {
                // There's a bug in Render.pm that makes it generate
                // an empty tfoot even if there are footer rows
                // Remove empty tfoot and recompute
                f.remove();
                f = [];
            }
            if (f.length === 0 && $(b).children().length > 0) {
                // No TFOOT, are there enough rows in the body?
                if (frc !== undefined) {
                    if (frc > $(b).children().length) {
                        frc = $(b).children().length;
                    }
                } else {
                    // Footer rows not explicitly defined - see
                    // if we can find footer rows by groping
                    frc = 0;
                    var lc = b.lastChild;
                    while (lc && lc.firstChild && lc.firstChild.tagName == 'TH') {
                        frc++;
                        lc = lc.previousSibling;
                    }
                }
                if (frc > 0) {
                    bodies.after("<tfoot></tfoot>");
                    f = t.find('tfoot');
                    while (frc--) {
                        bratz = $(b).children();
                        f.append($(bratz[bratz.length - 1]).remove());
                    }
                }
            }
        },

        // handle colour options
        colours : function(p, t) {
            var h,c,i;
            if (p.headerbg !== undefined || p.headercolor !== undefined) {
                h = t.find('thead').add(t.find('tfoot'));
                if (h.length) {
                    if (p.headerbg !== undefined) {
                        h.css("background-color", p.headerbg);
                    }
                    if (p.headercolor !== undefined) {
                        h.css("color", p.headercolor);
                    }
                }
            }
            if (p.databg !== undefined || p.datacolor !== undefined) {
                h = t.find('tbody > tr');
                if (h.length) {
                    if (p.databg !== undefined) {
                        c = p.databg.split(/\s*,\s*/);
                        for (i = 0; i < h.length; i++) {
                            $(h[i]).css("background-color",
                                        c[i % c.length]);
                        }
                    }
                    if (p.datacolor !== undefined) {
                        c = p.datacolor.split(/\s*,\s*/);
                        for (i = 0; i < h.length; i++) {
                            $(h[i]).css("color",
                                        c[i % c.length]);
                        }
                    }
                }
            }
        },

        // handle border options
        borders: function(p, t) {
            if (p.tableborder !== undefined) {
                t[0].border = p.tableborder;
            }
            if (p.tableframe !== undefined && jqtp.tableframe[p.tableframe] !== undefined) {
                t.css('border-style', jqtp.tableframe[p.tableframe]);
            }
            if (p.tablerules === undefined) {
                p.tablerules = "rows";
            }
            t[0].rules = p.tablerules;
            if (p.cellborder !== undefined) {
                t.find("td").add(t.find("th"))
                    .css("border-width", jqtp.unitify(p.cellborder));
            }
        },

        // handle layout options
        layout: function(p, t) {
            if (p.cellpadding !== undefined) {
                t[0].cellPadding = p.cellpadding;
            }
            if (p.cellpadding !== undefined) {
                t[0].cellSpacing = p.cellspacing;
            }
            if (p.tablewidth !== undefined) {
                t[0].width = p.tablewidth;
            }
            if (p.columnwidths !== undefined) {
                var cw = p.columnwidths.split(/\s*,\s*/);
                var h = t.find('tr').each(
                    function() {
                        var i = 0;
                        var kid = this.firstChild;
                        while (kid && i < cw.length) {
                            var cs = kid.colSpan;
                            if (cs < 1) {
                              cs = 1;
                            }
                            // Skip columns with a colspan > 1
                            if (cs == 1) {
                                $(kid).css("width", jqtp.unitify(cw[i]));
                            }
                            i += cs;
                            do {
                                kid = kid.nextSibling;
                            } while (kid && kid.nodeType != 1);
                        }
                    });
            }
        },

        // handle alignment options
        align : function(p, t) {
            if (p.valign === undefined) {
                p.valign = "top";
            }
            if (p.headervalign === undefined) {
                p.headervalign = p.valign;
            }
            if (p.datavalign === undefined) {
                p.datavalign = p.valign;
            }

            t.find("thead > tr > th")
            .add(t.find("thead > tr > td"))
            .add(t.find("tfoot > tr > th"))
            .add(t.find("tfoot > tr > td"))
            .css("vertical-align", p.headervalign);

            t.find("tbody > tr > td")
            .add(t.find("tbody > tr > th"))
            .css("vertical-align", p.datavalign);

            if (p.headeralign) {
                t.find("thead > tr > th")
                    .add(t.find("thead > tr > td"))
                    .add(t.find("tfoot > tr > th"))
                    .add(t.find("tfoot > tr > td"))
                    .css("text-align", p.headeralign);
            }
            if (p.dataalign) {
                t.find("tbody > tr > td")
                    .add(t.find("tbody > tr > th"))
                    .css("text-align", p.headeralign);
            }
        },

        // handle sort options; cache them on the table for picking up when
        // we init tablesorter
        makeSortable : function() {
            var sortOpts = $.extend({}, jqtp.defaultOpts);

            var pdata = $(this).attr("jqtp_params");
            if (pdata !== undefined) {
                $(this).removeAttr("jqtp_params");
                var p = eval(pdata);
                var sortcol = [0, 0];

                if (p.initSort !== undefined) {
                    sortcol[0] = p.initSort - 1;
                    sortOpts.sortList = [sortcol];
                }
                if (p.initdirection !== undefined) {
                    sortcol[1] = (p.initdirection == "down") ? 1 : 0;
                    sortOpts.sortList = [sortcol];
                }

                if (p.databgsorted !== undefined) {

                    var className = 'jqtp_databgsorted_' +
                        p.databgsorted.replace(/\W/g, '_');

                    /* Simplification; rather than pissing about colouring
                       alternate rows, paint all rows the same colour. */
                    var cols = p.databgsorted.split(/\s*,\s*/);
                    var col = cols[0];

                    $("body").append('<style type="text/css">.' + className +
                                     '{background-color:' + col +
                                     '}</style>');
                    sortOpts.cssAsc = className;
                    sortOpts.cssDesc = className;
                }
            }
            if (!$(this).find("thead").length) {
                jqtp.cleanHeadAndFoot($(this));
            }

            $(this).tablesorter(sortOpts);
        }

    };

    // colorize columns
    $.tablesorter.addWidget({
      id: 'colorize',
      format: function(table) {
        $(".sorted", table).removeClass("sorted");
        $("th.headerSortDown, th.headerSortUp", table).each(function() {
          var index = this.cellIndex +1;
          $("td:nth-child("+index+")", table).addClass("sorted");
        });
      }
    });

    /// document ready
    $(function() {
      // Process tables with a %TABLE tag
      $(".jqtp_process").each(jqtp.process);

      // If sort is all, attach the sortable class to all tables
      var sort = foswiki.getPreference("JQTablePlugin.sort");
      if (sort) {
          if (sort == 'all') {
              $(".foswikiTable").addClass("jqtp_sortable");
          } else if (sort == 'attachments') {
              // Just attachments
              $(".foswikiAttachments table").addClass("jqtp_sortable");
          }
      }

      // Process tables marked as sortable
      $(".jqtp_sortable").each(jqtp.makeSortable);
    });

})(jQuery);
