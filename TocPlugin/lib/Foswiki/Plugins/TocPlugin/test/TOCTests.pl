use lib ("$ENV{FOSWIKI_HOME}/lib");
use lib ('.');

use integer;

use Assert;
use Foswiki::Plugins::TocPlugin::TOC;
use Foswiki::Plugins::TocPlugin::TopLevelSection;
use Foswiki::Plugins::TocPlugin::test::FakeWikiIF;

use HTML;

my $topic1 = "TopLevel";
my $topic2 = "ReferToMe";
my $wif = Foswiki::Plugins::TocPlugin::test::FakeWikiIF->getInterface( "Test",
    $topic1 );

Foswiki::Plugins::TocPlugin::test::FakeWikiIF::writeTopic( "WebOrder",
    "\t* $topic1\n\t* $topic2" );
Foswiki::Plugins::TocPlugin::test::FakeWikiIF::writeTopic( $topic1, "Blah" );
Foswiki::Plugins::TocPlugin::test::FakeWikiIF::writeTopic( $topic2,
    "%SECTION1{name=refme}% Refer to me" );

my $text = "%SECTION0% Section zero
%SECTION1{name=oneone}% Section one.one
%ANCHOR{type=Figure,name=ref}% Figure anchor
%SECTION1% Section one.two
%REF{type=Figure,name=ref}% A ref to ref
";

$mess = Foswiki::Plugins::TocPlugin::TOC::processTopic( $wif, "Test", $topic1,
    $text );
my $secs = "<H1>${TS}Section_1.${TE}1.  Section zero$AE</H1>
<H2>${TS}Section_1.1.${TE}1.1. Section one.one$AE${TS}Section_oneone$TE $AE
</H2>
${TS}Figure_ref${TE}1.1.A Figure anchor</A>
<H2>${TS}Section_1.2.${TE}1.2. Section one.two</A></H2>
${JS}$topic1#Figure_ref${JE}1.1.A Figure anchor</A> A ref to ref";
ASSERT( $mess eq $secs );

# check global tags
$mess = Foswiki::Plugins::TocPlugin::TOC::processTopic( $wif, "Test", $topic1,
    "$text %CONTENTS% %TOCCHECK% %REFTABLE{type=Figure}%" );
ASSERT(
    $mess eq "$secs
 $DIV
$UL$LI${JS}$topic1${TE}1.  Section zero</A>$UL
$LI${JS}$topic1#Section_1.1.${TE}1.1. Section one.one$AE$IL
$LI${JS}$topic1#Section_1.2.${TE}1.2. Section one.two$AE$IL
$LU$IL
$LI${JS}$topic2${TE}2. <nop>ReferToMe$AE$UL
$LI${JS}$topic2#Section_2.1.${TE}2.1. Refer to me$AE$IL
$LU$IL
$LU$VID$REFT
$TR${TH}Figure$HT$RT
$TR$TD${JS}$topic1#Figure_ref${JE}1.1.A Figure anchor$AE$DT$RT
$TFER"
);

# Check topic->topic cross reference
$mess = Foswiki::Plugins::TocPlugin::TOC::processTopic( $wif, "Test", $topic1,
    "%REF{topic=$topic2,type=Section,name=refme}%" );
ASSERT( $mess eq "${JS}$topic2#Section_2.1.${JE}2.1. Refer to me$AE" );

# the wif should cache the web
# the wif should be renewed if the web changes

1;
