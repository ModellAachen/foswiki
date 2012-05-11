FOSWIKI_ROOT?=~/foswiki/trunk/core
TARGET=jquery.tweet.js jquery.tweet.css jquery.tweet.init.js
CP=cp

-include $(FOSWIKI_ROOT)/pub/System/JQueryPlugin/Makefile.include

jquery.tweet.uncompressed.js: git/tweet/jquery.tweet.js
	@echo copying $< to $@ 
	@$(CP) $< $@
