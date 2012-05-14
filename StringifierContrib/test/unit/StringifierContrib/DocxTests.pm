# Test for DOCX.pm
package DocxTests;
use StringifierTest;
our @ISA = qw( StringifierTest );

use strict;
use utf8;

use Foswiki::Contrib::Stringifier::Base();
use Foswiki::Contrib::Stringifier();

sub set_up {
    my $this = shift;
    
    $this->{attachmentDir} = 'attachement_examples/';
    if (! -e $this->{attachmentDir}) {
        #running from foswiki/test/unit
        $this->{attachmentDir} = 'StringifierContrib/attachement_examples/';
    }

    $this->SUPER::set_up();
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_stringForFile {
    my $this = shift;
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::DOCX->new();

    my $fileName = $this->{attachmentDir}.'Simple_example.docx';
    my $text  = $stringifier->stringForFile($fileName);
    my $text2 = Foswiki::Contrib::Stringifier->stringFor($fileName);

    $this->assert(defined($text) && $text ne "", "No text returned.");
    $this->assert_str_equals($text, $text2, "DOCX stringifier not well registered.");

    my $ok = $text =~ /dummy/;
    $this->assert($ok, "Text dummy not included")
}

sub test_SpecialCharacters {
    # check that special characters are not destroyed by the stringifier
    
    my $this = shift;
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::DOCX->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Simple_example.docx');

    $this->assert_matches($this->encode('Größer'), $text, "Text Größer not found.");
}

# test for Passworded_example.docx
# Note that the password for that file is: foswiki
sub test_passwordedFile {
    my $this = shift;
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::DOCX->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Passworded_example.docx');

    $this->assert_equals('', $text, "Protected file generated some text?");
}

# test what would happen if someone uploaded a png and called it a .docx
sub DONT_test_maliciousFile {
    my $this = shift;
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::DOCX->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Im_a_png.docx');

    $this->assert_equals('', $text, "Malicious file generated some text?");
}

1;
