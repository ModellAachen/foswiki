use lib ('.');
use lib ('../../../..');
use integer;

use Assert;
use Foswiki::Plugins::TocPlugin::Section;

use HTML;

my $s1text     = "FirstTop level text";
my $s1texp     = "<nop>FirstTop level text";
my $s1topic    = "SectionOneWikiTopic";
my $s1_1text   = "First SubSection of FirstSection";
my $s1_1texp   = "First <nop>SubSection of <nop>FirstSection";
my $s2text     = "Second TopLevel text";
my $s2texp     = "Second <nop>TopLevel text";
my $s2topic    = "SectionTwoWikiTopic";
my $s1_1_1text = "a sub-sub-section";
my $s1_1_1texp = $s1_1_1text;

my $ts1text = "First TaggedSection";
my $ts1texp = "First <nop>TaggedSection";
my $ts2text = "SecondTagged Section";
my $ts2texp = "<nop>SecondTagged Section";
my $ts3text = "[[Third Tagged Section]]";
my $ts3texp = "Third Tagged Section";

my $type1    = "AnchorType";
my $t1n1     = "FirstAnchor";
my $t1n1text = "First AnchorText";
my $t1n1texp = "First <nop>AnchorText";
my $t1n2     = "secondAnchor";
my $t1n2text = "secondAnchor text";
my $t1n2texp = $t1n2text;
my $t1n3     = "FirstTaggedAnchor";
my $t1n3text = "First TaggedAnchor";
my $t1n3texp = "First <nop>TaggedAnchor";
my $t1n4     = "SecondTaggedAnchor";
my $t1n4text = "SecondTagged Anchor";
my $t1n4texp = "<nop>SecondTagged Anchor";

my $type2    = "figure";
my $t2n1     = "FirstFigure";
my $t2n1text = "FirstFigure Text";
my $t2n1texp = "<nop>FirstFigure Text";

my $section = Foswiki::Plugins::TocPlugin::Section->new( 1, "Text" );
Assert::equals( __LINE__, $section->level(), 1 );
Assert::assert( __LINE__, !defined( $section->parent() ) );
Assert::equals( __LINE__, $section->position(), -1 );
Assert::assert( __LINE__, !defined( $section->wikiName() ) );
Assert::equals( __LINE__, scalar( @{ $section->{SECTIONS} } ), 0 );
$section = Foswiki::Plugins::TocPlugin::Section->new( 2, "Text" );
Assert::equals( __LINE__, $section->level(), 2 );
Assert::equals( __LINE__, scalar( @{ $section->anchors("key") } ), 0 );

# Build a fixture consisting of a section within a section
my $root = Foswiki::Plugins::TocPlugin::Section->new( 0, "Root" );
my $s1   = Foswiki::Plugins::TocPlugin::Section->new( 1, $s1text );
$s1->wikiName($s1topic);
$root->_addSection($s1);
Assert::equals( __LINE__, $s1->_getRoot(), $root );
Assert::equals( __LINE__, $s1->position(), 1 );
Assert::sEquals( __LINE__, $s1->wikiName(), $s1topic );
my $s2 = Foswiki::Plugins::TocPlugin::Section->new( 1, $s2text );
$s2->wikiName($s2topic);
$root->_addSection($s2);
Assert::equals( __LINE__, $s2->_getRoot(), $root );
Assert::equals( __LINE__, $s2->position(), 2 );
Assert::sEquals( __LINE__, $s2->wikiName(),          $s2topic );
Assert::sEquals( __LINE__, $s1->_getSectionNumber(), "1." );
Assert::sEquals( __LINE__, $s2->_getSectionNumber(), "2." );
Assert::equals( __LINE__, $s1->_getTopic(),            $s1 );
Assert::equals( __LINE__, $s2->_getTopic(),            $s2 );
Assert::equals( __LINE__, $root->_findTopic($s1topic), $s1 );
Assert::equals( __LINE__, $root->_findTopic($s2topic), $s2 );

# add a subsection to section 1
my $s1_1 = Foswiki::Plugins::TocPlugin::Section->new( 2, $s1_1text );
$s1->_addSection($s1_1);
Assert::sEquals( __LINE__, $s1_1->_getSectionNumber(), "1.1." );
Assert::equals( __LINE__, $s1_1->_getTopic(),          $s1 );
Assert::equals( __LINE__, $s1_1->_getRoot(),           $root );
Assert::equals( __LINE__, $s1->_getLastSubsection(),   $s1_1 );
Assert::equals( __LINE__, $root->_getLastSubsection(), $s2 );
Assert::sEquals( __LINE__, $s1->_getTopicURL(),   $s1topic );
Assert::sEquals( __LINE__, $s1_1->_getTopicURL(), $s1topic );
Assert::sEquals( __LINE__, $s2->_getTopicURL(),   $s2topic );
Assert::sEquals( __LINE__,
    $s1_1->generateReference(),
    "${JS}#Section_1.1.${JE}1.1. $s1_1texp$AE"
);
Assert::sEquals( __LINE__,
    $s1_1->generateReference("Topic"),
    "${JS}Topic#Section_1.1.${JE}1.1. $s1_1texp$AE"
);
Assert::sEquals( __LINE__, $s1_1->generateTarget(),
    "<H2>${TS}Section_1.1.${TE}<\/A>1.1. $s1_1texp\n<\/H2>" );
my $b4 = $s1->toString(1);
my $t = Foswiki::Plugins::TocPlugin::Section->new( 2, "Temporary" );
$s1->_replaceSection( $s1_1, $t );
$s1->_replaceSection( $t,    $s1_1 );
Assert::sEquals( __LINE__, $s1->toString(1), $b4 );
my $s1_1_1 = Foswiki::Plugins::TocPlugin::Section->new( 3, $s1_1_1text );
$s1_1->_addSection($s1_1_1);
Assert::sEquals( __LINE__,
    $s1_1_1->generateTarget(),
    "<H3>${TS}Section_1.1.1.${TE}${AE}1.1.1. $s1_1_1texp<\/H3>"
);
Assert::sEquals( __LINE__,
    $s1_1_1->generateReference(),
    "${JS}#Section_1.1.1.${JE}1.1.1. $s1_1_1texp$AE"
);

# Add an anchor to sections and make sure we can find it
my $anc1 = $s1->_addAnchor( $type1, $t1n1, $t1n1text, 1 );
Assert::sEquals( __LINE__, $anc1->type(), $type1 );
Assert::sEquals( __LINE__, $anc1->uid(),  $t1n1 );
Assert::sEquals( __LINE__, $anc1->text(), $t1n1text );
Assert::assert( __LINE__, $anc1->visible() );
Assert::sEquals( __LINE__,
    $anc1->generateReference(),
    "${JS}#${type1}_$t1n1${JE}1.A $t1n1texp$AE"
);
Assert::sEquals( __LINE__,
    $anc1->generateReference("Topic"),
    "${JS}Topic#${type1}_$t1n1${JE}1.A $t1n1texp$AE"
);
Assert::sEquals( __LINE__, $anc1->generateTarget(),
    "${TS}${type1}_$t1n1${TE}${AE}1.A $t1n1texp" );
my ( $retsec, $retlink ) = $s1->_findTarget( $type1, "$t1n1" );
Assert::equals( __LINE__, $retsec,  $s1 );
Assert::equals( __LINE__, $retlink, $anc1 );

# repeat the exercise for another target of the same type
my $anc2 = $s1->_addAnchor( $type1, $t1n2, $t1n2text, 1 );
Assert::sEquals( __LINE__, $anc2->type(), $type1 );
Assert::sEquals( __LINE__, $anc2->uid(),  $t1n2 );
Assert::sEquals( __LINE__, $anc2->text(), $t1n2text );
Assert::assert( __LINE__, $anc2->visible() );
Assert::sEquals( __LINE__,
    $anc2->generateReference(),
    "${JS}#${type1}_$t1n2${JE}1.B $t1n2texp$AE"
);
Assert::sEquals( __LINE__,
    $anc2->generateReference("Topic"),
    "${JS}Topic#${type1}_$t1n2${JE}1.B $t1n2texp$AE"
);
Assert::sEquals( __LINE__, $anc2->generateTarget(),
    "${TS}${type1}_$t1n2${TE}${AE}1.B $t1n2texp" );
( $retsec, $retlink ) = $s1->_findTarget( $type1, $t1n2 );
Assert::equals( __LINE__, $retsec,  $s1 );
Assert::equals( __LINE__, $retlink, $anc2 );

# repeat the exercise for another target of a different type
my $anc3 = $s1->_addAnchor( $type2, $t2n1, $t2n1text, 1 );
Assert::sEquals( __LINE__, $anc3->type(), $type2 );
Assert::sEquals( __LINE__, $anc3->uid(),  $t2n1 );
Assert::sEquals( __LINE__, $anc3->text(), $t2n1text );
Assert::assert( __LINE__, $anc3->visible() );
Assert::sEquals( __LINE__,
    $anc3->generateReference(),
    "${JS}#${type2}_$t2n1${JE}1.A $t2n1texp$AE"
);
Assert::sEquals( __LINE__,
    $anc3->generateReference("Topic"),
    "${JS}Topic#${type2}_$t2n1${JE}1.A $t2n1texp$AE"
);
Assert::sEquals( __LINE__, $anc3->generateTarget(),
    "$TS${type2}_$t2n1${TE}${AE}1.A $t2n1texp" );
( $retsec, $retlink ) = $s1->_findTarget( $type2, $t2n1 );
Assert::equals( __LINE__, $retsec,  $s1 );
Assert::equals( __LINE__, $retlink, $anc3 );
my $q1 = "$LI${JS}$s1topic${JE}1. $s1texp$AE";
my $q2 = "$LI${JS}$s1topic#Section_1.1.${JE}1.1. $s1_1texp$AE";
my $q3 = "$LI${JS}$s1topic#Section_1.1.1.${JE}1.1.1. $s1_1_1texp$AE";
Assert::sEquals( __LINE__, $s1->generateTOC(1),     "$UL$q1$IL$LU\n" );
Assert::sEquals( __LINE__, $s1_1->generateTOC(1),   "$UL$q2$IL$LU\n" );
Assert::sEquals( __LINE__, $s1_1_1->generateTOC(1), "$UL$q3$IL$LU\n" );
Assert::sEquals( __LINE__, $s1->generateTOC(2), "$UL$q1$UL$q2$IL$LU$IL$LU" );
Assert::sEquals( __LINE__, $s1->generateTOC(0),
    "$UL$q1$UL$q2$UL$q3$IL$LU$IL$LU$IL$LU" );
Assert::sEquals( __LINE__, $root->generateTOC(1),
    "$UL$q1$IL$LI${JS}$s2topic${JE}2. $s2texp$AE$IL$LU" );

Assert::sEquals( __LINE__, $s1->generateTOC(0), $s1->generateTOC(3) );

Assert::sEquals( __LINE__, $root->generateRefTable($type2),
    "$REFT$TR$TH${type2}$HT$RT
$TR$TD${JS}$s1topic#${type2}_$t2n1${JE}1.A $t2n1texp$AE$DT$RT$TFER"
);
Assert::sEquals( __LINE__, $root->generateRefTable($type1),
    "$REFT$TR$TH${type1}$HT$RT
$TR$TD${JS}$s1topic#${type1}_$t1n1${JE}1.A $t1n1texp$AE$DT$RT
$TR$TD${JS}$s1topic#${type1}_$t1n2${JE}1.B $t1n2texp$AE$DT$RT$TFER"
);

# Now test tag processors
my $lev  = $s1->level() + 1;
my $s1_2 = $s1->processSECTIONTag(
    Foswiki::Plugins::TocPlugin::Attrs->new("level=$lev,text=\"$ts2text\"") );
Assert::sEquals( __LINE__,
    $s1_2->generateReference(),
    "${JS}#Section_1.2.${JE}1.2. $ts2texp$AE"
);

Assert::sEquals( __LINE__,
    $s1->processANCHORTag(
        Foswiki::Plugins::TocPlugin::Attrs->new( "
type=${type1},name=$t1n3,display=no,text=\"$t1n3text\"" )
      )->generateTarget(),
    "${TS}${type1}_$t1n3${TE}$AE"
);
$lev = $s1->level() + 2;
my $s1_2_1 = $s1->processSECTIONTag(
    Foswiki::Plugins::TocPlugin::Attrs->new( "
name=Deep,level=$lev,text=\"$ts3text\"" )
);
Assert::sEquals( __LINE__,
    $s1_2_1->generateReference(),
    "${JS}#Section_1.2.1.${JE}1.2.1. $ts3texp$AE"
);
Assert::sEquals( __LINE__, $s1->generateTOC(),
    "$UL$LI${JS}$s1topic${JE}1. $s1texp$AE$UL
$LI${JS}$s1topic#Section_1.1.${JE}1.1. $s1_1texp$AE$UL
$LI${JS}$s1topic#Section_1.1.1.${JE}1.1.1. $s1_1_1texp$AE$IL$LU$IL
$LI${JS}$s1topic#Section_1.2.${JE}1.2. $ts2texp$AE$UL
$LI${JS}$s1topic#Section_1.2.1.${JE}1.2.1. $ts3texp$AE$IL
$LU$IL
$LU$IL
$LU"
);

Assert::sEquals( __LINE__,
    $s1->processANCHORTag(
        Foswiki::Plugins::TocPlugin::Attrs->new( "
type=${type1},name=$t1n4,display=yes,text=\"$t1n4text\"" )
      )->generateTarget(),
    "${TS}${type1}_$t1n4${TE}${AE}1.2.1.A $t1n4texp"
);

# Process ref tags
Assert::sEquals( __LINE__,
    $s1->processREFTag(
        Foswiki::Plugins::TocPlugin::Attrs->new("type=Section,name=Deep")
    ),
    "${JS}$s1topic#Section_1.2.1.${JE}1.2.1. $ts3texp$AE"
);
Assert::sEquals( __LINE__,
    $s1->processREFTag(
        Foswiki::Plugins::TocPlugin::Attrs->new("type=${type1},name=$t1n4")
    ),
    "${JS}$s1topic#${type1}_$t1n4${JE}1.2.1.A $t1n4texp$AE"
);
Assert::sEquals( __LINE__,
    $s1->processREFTag(
        Foswiki::Plugins::TocPlugin::Attrs->new("type=${type2},name=$t2n1")
    ),
    "${JS}$s1topic#${type2}_$t2n1${JE}1.A $t2n1texp$AE"
);
$s1->{SECTION_TESTS_JUST_TESTING} = 1;
Assert::sEquals( __LINE__,
    $s1->processREFTag(
        Foswiki::Plugins::TocPlugin::Attrs->new(
            "type=${type2},name=$t2n1,topic=$s1topic")
    ),
    "${JS}$s1topic#${type2}_$t2n1${JE}1.A $t2n1texp$AE"
);

1;

