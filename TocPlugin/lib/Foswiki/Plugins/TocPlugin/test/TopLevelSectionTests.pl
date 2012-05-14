package TopLevelSectionTests;

use lib ("$ENV{FOSWIKI_HOME}/lib");
use lib ('.');

use integer;

use Assert;
use Foswiki::Plugins::TocPlugin::Attrs;
use Foswiki::Plugins::TocPlugin::TopLevelSection;
use FakeWikiIF;

use HTML;

my $l1text = "TopLevel";
my $l1texp = "<nop>TopLevel";
my $l2text = "SecondLevel";
my $l2texp = "<nop>SecondLevel";
my $l3text = "ThirdLevel";
my $l3texp = "<nop>ThirdLevel";

my $l1btext = "AnotherTopLevel";
my $l1btexp = "<nop>$l1btext";
my $l2btext = "AnotherSecondLevel";
my $l2btexp = "<nop>$l2btext";

my $wif = Foswiki::Plugins::TocPlugin::test::FakeWikiIF->getInterface( "Test",
    $l1btext );

my ( $root, $mess ) =
  Foswiki::Plugins::TocPlugin::TopLevelSection::createTOC( "Test", $wif );

ASSERT( $mess eq "${ERF}No WebOrder in this web$FRE" );
Foswiki::Plugins::TocPlugin::test::FakeWikiIF::writeTopic(
    "WebOrder",
    "\t* $l1text
\t\t* $l2text
\t\t\t* $l3text
\t\t* $l2btext
\t* $l1btext
\t* $l1text
\t\t* $l2text
\t\t\t* $l3text
\t\t* $l2btext
\t* $l1btext
"
);
( $root, $mess ) =
  Foswiki::Plugins::TocPlugin::TopLevelSection::createTOC( "Test", $wif );
ASSERT(
    $mess eq "${ERF}Topic $l1text used more than once in WebOrder<br>$FRE
${ERF}Topic $l2text used more than once in WebOrder<br>$FRE
${ERF}Topic $l3text used more than once in WebOrder<br>$FRE
${ERF}Topic $l2btext used more than once in WebOrder<br>$FRE
${ERF}Topic $l1btext used more than once in WebOrder<br>$FRE"
);

Foswiki::Plugins::TocPlugin::test::FakeWikiIF::writeTopic(
    "WebOrder",
    "\t* $l1text
\t\t* $l2text
\t\t\t* $l3text
\t\t* $l2btext
\t* $l1btext\n"
);
my $l2tagtext = "Tagged LevelTwo Section";
my $l2tagtexp = "Tagged <nop>LevelTwo Section";
Foswiki::Plugins::TocPlugin::test::FakeWikiIF::writeTopic( $l1text,
    "%SECTION1% $l2tagtext" );
my $l3tagtext = "Tagged LevelThree Section";
my $l3tagtexp = "Tagged <nop>LevelThree Section";
Foswiki::Plugins::TocPlugin::test::FakeWikiIF::writeTopic( $l2text,
    "%SECTION1% $l3tagtext" );
my $l4tagtext = "Tagged LevelFourSection";
my $l4tagtexp = "Tagged <nop>LevelFourSection";
Foswiki::Plugins::TocPlugin::test::FakeWikiIF::writeTopic( $l3text,
    "%SECTION1% $l4tagtext" );
Foswiki::Plugins::TocPlugin::test::FakeWikiIF::writeTopic( $l1btext,
    "%SECTION0% $l1btexp" );
Foswiki::Plugins::TocPlugin::test::FakeWikiIF::writeTopic( $l2btext,
    "%SECTION0% $l2btexp" );

( $root, $mess ) =
  Foswiki::Plugins::TocPlugin::TopLevelSection::createTOC( "Test", $wif );
die $mess unless $root;
ASSERT(
    $root->processTOCTag( Foswiki::Plugins::TocPlugin::Attrs->new("") ) eq "$DIV
$UL$LI$JS$l1text${JE}1. $l1texp$AE$UL
$LI$JS$l2text${JE}1.1. $l2texp$AE$UL
$LI$JS$l3text${JE}1.1.1. $l3texp$AE$UL
$LI${JS}$l3text#Section_1.1.1.1.${JE}1.1.1.1. $l4tagtexp$AE$IL
$LU$IL
$LI${JS}$l2text#Section_1.1.2.${JE}1.1.2. $l3tagtexp$AE$IL
$LU$IL
$LI$JS$l2btext${JE}1.2. $l2btexp$AE$IL
$LI$JS$l1text#Section_1.3.${JE}1.3. $l2tagtexp$AE$IL
$LU$IL
$LI$JS$l1btext${JE}2. $l1btexp$AE$IL
$LU$VID"
);
ASSERT(
    $root->processTOCTag(
        Foswiki::Plugins::TocPlugin::Attrs->new("topic=$l1text")
      ) eq "$DIV
$UL$LI$JS$l1text${JE}1. $l1texp$AE$UL
$LI$JS$l2text${JE}1.1. $l2texp$AE$UL
$LI$JS$l3text${JE}1.1.1. $l3texp$AE$UL
$LI$JS${l3text}#Section_1.1.1.1.${JE}1.1.1.1. $l4tagtexp$AE$IL
$LU$IL
$LI$JS$l2text#Section_1.1.2.${JE}1.1.2. $l3tagtexp$AE$IL
$LU$IL
$LI$JS$l2btext${JE}1.2. $l2btexp$AE$IL
$LI$JS$l1text#Section_1.3.${JE}1.3. $l2tagtexp$AE$IL
$LU$IL
$LU$VID"
);

my $tt = $root->_findTopic($l1btext);
ASSERT( $tt->wikiName() eq $l1btext );
ASSERT( $tt->{IS_LOADED} );
my $ct = $root->currentTopic();
ASSERT( $ct->wikiName() eq $l1btext );
ASSERT( $ct->{IS_LOADED} );

$root->loadTopics($root);
ASSERT(
    $root->processTOCTag( Foswiki::Plugins::TocPlugin::Attrs->new("") ) eq
      "$DIV$UL$LI$JS$l1text${JE}1. $l1texp$AE$UL
$LI$JS$l2text${JE}1.1. $l2texp$AE$UL
$LI$JS$l3text${JE}1.1.1. $l3texp$AE$UL
$LI$JS$l3text#Section_1.1.1.1.${JE}1.1.1.1. $l4tagtexp$AE$IL
$LU$IL
$LI$JS$l2text#Section_1.1.2.${JE}1.1.2. $l3tagtexp$AE$IL
$LU$IL
$LI$JS$l2btext${JE}1.2. $l2btexp$AE$IL
$LI$JS$l1text#Section_1.3.${JE}1.3. $l2tagtexp$AE$IL
$LU$IL
$LI$JS$l1btext${JE}2. $l1btexp$AE$IL
$LU$VID"
);

ASSERT( $root->processTOCCHECKTag() eq "" );
Foswiki::Plugins::TocPlugin::test::FakeWikiIF::writeTopic( "Missing", "" );
ASSERT(
    $root->processTOCCHECKTag() eq
      "${ERF}The following topics were not found in the WebOrder:
<OL>${LI}Missing$IL</OL>$FRE"
);

ASSERT(
    $root->processREFTABLETag( Foswiki::Plugins::TocPlugin::Attrs->new("") ) eq
      "${ERF}Bad type in REFTABLE$FRE" );
ASSERT(
    $root->processREFTABLETag(
        Foswiki::Plugins::TocPlugin::Attrs->new("type=fred")
      ) eq "$REFT$TR${TH}fred$HT$RT$TFER"
);

1;
