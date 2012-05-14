package StringifierContribSuite;
use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub include_tests {
 qw(
   StringifyBaseTest
   Doc_wvTests
   DocxTests 
   Doc_antiwordTests 
   Doc_abiwordTests
   PdfTests 
   TxtTests 
   HtmlTests 
   PptTests 
   PptxTests 
   XlsxTests 
   OdtTests 
   XlsTests
 );
#qw(TxtTests);
}

1;
