FOSWIKI_ROOT?=~/foswiki/trunk/core
TARGET=\
  fullcalendar.js \
  fullcalendar.css \
  fullcalendar.print.css \
  gcal.js

-include $(FOSWIKI_ROOT)/pub/System/JQueryPlugin/Makefile.include

fullcalendar.uncompressed.js: git/build/fullcalendar/fullcalendar/fullcalendar.js
	cp $< $@

fullcalendar.uncompressed.css: git/build/fullcalendar/fullcalendar/fullcalendar.css
	cp $< $@

fullcalendar.print.uncompressed.css: git/build/fullcalendar/fullcalendar/fullcalendar.print.css
	cp $< $@

gcal.js: git/build/fullcalendar/fullcalendar/gcal.js
	cp $< $@
