# Test for DOC_antiword.pm
package Doc_antiwordTests;
use StringifierTest;
our @ISA = qw( StringifierTest );

use strict;
use utf8;

use Foswiki::Func;
use Foswiki::Contrib::Stringifier();

sub set_up {
    my $this = shift;
    
    $this->{attachmentDir} = 'attachement_examples/';
    if (! -d $this->{attachmentDir}) {
        #running from foswiki/test/unit
        $this->{attachmentDir} = 'StringifierContrib/attachement_examples/';
    }
    $Foswiki::cfg{StringifierContrib}{WordIndexer} = 'antiword';

    $this->SUPER::set_up();
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_stringForFile {
    my $this = shift;
    my $stringifier1 = Foswiki::Contrib::Stringifier::Plugins::DOC_antiword->new();
    my $stringifier2 = Foswiki::Contrib::Stringifier::Plugins::DOC_abiword->new();
    my $stringifier3 = Foswiki::Contrib::Stringifier::Plugins::DOC_wv->new();

    my $fileName = $this->{attachmentDir}.'Simple_example.doc';

    my $text1 = $stringifier1->stringForFile($fileName);
    my $text2  = $stringifier2->stringForFile($fileName);
    my $text3  = $stringifier2->stringForFile($fileName);

    $this->assert(defined($text1) && $text1 ne "", "No text returned.");
    $this->assert(defined($text2) && $text2 ne "", "No text returned.");
    $this->assert(defined($text3) && $text3 ne "", "No text returned.");

    $this->assert_str_equals($text1, $text2, "DOC_antiword != DOC_abiword");
    $this->assert_str_equals($text1, $text3, "DOC_antiword != DOC_wv");
    $this->assert_str_equals($text2, $text3, "DOC_antiword != DOC_wv");

    my $ok = $text1 =~ /dummy/;
    $this->assert($ok, "Text dummy not included in text1");

    $ok = $text2 =~ /dummy/;
    $this->assert($ok, "Text dummy not included in text2");

    $ok = $text3 =~ /dummy/;
    $this->assert($ok, "Text dummy not included in text3");
}

sub test_SpecialCharacters {
    # check that special characters are not destroyed by the stringifier
    
    my $this = shift;
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::DOC_antiword->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Simple_example.doc');

    $this->assert_matches($this->encode('Größer'), $text, "Text Größer not found.");
}

# test for Passworded_example.doc
# Note that the password for that file is: foswiki
sub test_passwordedFile {
    my $this = shift;
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::DOC_antiword->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Passworded_example.doc');

    $this->assert_equals('', $text, "Protected file generated some text?");
}

# test what would happen if someone uploaded a png and called it a .doc
sub test_maliciousFile {
    my $this = shift;
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::DOC_antiword->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Im_a_png.doc');

    $this->assert_equals('', $text, "Malicious file generated some text?");
}

1;
