
INSTALLER_SCRIPT_REV = 1

FOSWIKI_RELEASE = 1.1.3

FOSWIKI_BASE_FILENAME = Foswiki-$(FOSWIKI_RELEASE)
INSTALLER_SCRIPT_FILENAME = $(FOSWIKI_BASE_FILENAME)-SharedHosting-$(INSTALLER_SCRIPT_REV).tgz

default : foswiki-install-shared-hosting.pl

help :
	@echo foswiki-install-shared-hosting.pl
	@echo release
	@echo clean
	@echo realclean
	@echo $(INSTALLER_SCRIPT_FILENAME).md5

RELEASE_FILES = $(INSTALLER_SCRIPT_FILENAME) $(INSTALLER_SCRIPT_FILENAME).md5
release : $(RELEASE_FILES)

ALL : release

$(INSTALLER_SCRIPT_FILENAME) : foswiki-install-shared-hosting.pl
	tar czvf $(INSTALLER_SCRIPT_FILENAME) foswiki-install-shared-hosting.pl

CPAN_LIBS = lib/CPAN/lib/Apache/Htpasswd.pm

# NOTE: *always* list a Foswiki distribution as the first data file in the list of uuencoded attachments.  the installer installs the main distribution by its slot position (0)
foswiki-install-shared-hosting.pl : foswiki-install-shared-hosting-preamble.pl $(CPAN_LIBS) $(FOSWIKI_BASE_FILENAME).tgz.uuencode FastCGIEngineContrib.tgz.uuencode 
	cat foswiki-install-shared-hosting-preamble.pl $(CPAN_LIBS) >foswiki-install-shared-hosting.pl
	echo __END__ >>foswiki-install-shared-hosting.pl
	cat $(FOSWIKI_BASE_FILENAME).tgz.uuencode FastCGIEngineContrib.tgz.uuencode >>foswiki-install-shared-hosting.pl
	chmod -x foswiki-install-shared-hosting.pl

$(INSTALLER_SCRIPT_FILENAME).md5 : $(INSTALLER_SCRIPT_FILENAME)
	md5sum $(INSTALLER_SCRIPT_FILENAME) >$(INSTALLER_SCRIPT_FILENAME).md5

$(FOSWIKI_BASE_FILENAME).tgz.uuencode : $(FOSWIKI_BASE_FILENAME).tgz
	perl -Ilib/CPAN/lib/ tools/puuencode $(FOSWIKI_BASE_FILENAME).tgz >$(FOSWIKI_BASE_FILENAME).tgz.uuencode

FastCGIEngineContrib.tgz.uuencode : FastCGIEngineContrib.tgz
	perl -Ilib/CPAN/lib/ tools/puuencode FastCGIEngineContrib.tgz >FastCGIEngineContrib.tgz.uuencode

$(FOSWIKI_BASE_FILENAME).tgz :
	wget -O $(FOSWIKI_BASE_FILENAME).tgz 'http://sourceforge.net/projects/foswiki/files/foswiki/$(FOSWIKI_RELEASE)/$(FOSWIKI_BASE_FILENAME).tgz/download'

FastCGIEngineContrib.tgz :
	wget 'http://foswiki.org/pub/Extensions/FastCGIEngineContrib/FastCGIEngineContrib.tgz'

#

clean :
	-rm *~ $(RELEASE_FILES) foswiki-install-shared-hosting.pl $(FOSWIKI_BASE_FILENAME).tgz.uuencode FastCGIEngineContrib.tgz.uuencode 2>/dev/null

realclean : clean
	-rm $(FOSWIKI_BASE_FILENAME).tgz FastCGIEngineContrib.tgz 2>/dev/null

print : 
	@echo RELEASE_FILES = $(RELEASE_FILES)
	@echo INSTALLER_SCRIPT_REV = $(INSTALLER_SCRIPT_REV)
	@echo FOSWIKI_RELEASE = $(FOSWIKI_RELEASE)
	@echo FOSWIKI_BASE_FILENAME = $(FOSWIKI_BASE_FILENAME)
	@echo INSTALLER_SCRIPT_FILENAME = $(INSTALLER_SCRIPT_FILENAME)
