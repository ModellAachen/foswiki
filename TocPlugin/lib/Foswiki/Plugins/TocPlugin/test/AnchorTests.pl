use lib ('.');
use lib ('../../../..');
use Foswiki::Plugins::TocPlugin::Anchor;
use Assert;

my $anchor =
  Foswiki::Plugins::TocPlugin::Anchor->new( "Anchor1Type", 1, "Anchor1Text",
    1 );
Assert::sEquals( __LINE__, $anchor->type(), "Anchor1Type" );
$anchor->type("Bleep1");
Assert::sEquals( __LINE__, $anchor->type(), "Bleep1" );
Assert::equals( __LINE__, $anchor->uid(), 1 );
$anchor->uid("Bleep2");
Assert::sEquals( __LINE__, $anchor->uid(),  "Bleep2" );
Assert::sEquals( __LINE__, $anchor->text(), "Anchor1Text" );
$anchor->text("Bleep3");
Assert::sEquals( __LINE__, $anchor->text(), "Bleep3" );
Assert::assert( __LINE__, $anchor->visible() );
$anchor->visible(0);
Assert::assert( __LINE__, !$anchor->visible() );

$anchor = Foswiki::Plugins::TocPlugin::Anchor->new( "Type", "1.1", "Text", 1 );
my $res = $anchor->generateTarget();
Assert::sEquals( __LINE__, $res, "<A name=\"Type_1.1\"></A>1.1 Text" );
$anchor->visible(0);
$res = $anchor->generateTarget();
Assert::sEquals( __LINE__, $res, "<A name=\"Type_1.1\"></A>" );
$res = $anchor->generateReference();
Assert::sEquals( __LINE__, $res, "<A href=\"#Type_1.1\">1.1 Text</A>" );
$res = $anchor->generateReference("Fred");
Assert::sEquals( __LINE__, $res, "<A href=\"Fred#Type_1.1\">1.1 Text</A>" );
$anchor->printable("printable");
$res = $anchor->generateReference("Fred");
Assert::sEquals( __LINE__, $res,
    "<A href=\"Fred#Type_1.1\">printable Text</A>" );

1;
