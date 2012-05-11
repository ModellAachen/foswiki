# Test for PDF.pm
package PdfTests;
use StringifierTest;
our @ISA = qw( StringifierTest );

use strict;
use utf8;

use Foswiki::Contrib::Stringifier::Base();
use Foswiki::Contrib::Stringifier();

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    
    $this->{attachmentDir} = 'attachement_examples/';
    if (! -e $this->{attachmentDir}) {
        #running from foswiki/test/unit
        $this->{attachmentDir} = 'StringifierContrib/attachement_examples/';
    }
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_stringForFile {
    my $this = shift;
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::PDF->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Simple_example.pdf');
    my $text2 = Foswiki::Contrib::Stringifier->stringFor($this->{attachmentDir}.'Simple_example.pdf');

    $this->assert(defined($text), "No text returned.");
    $this->assert_str_equals($text, $text2, "PDF stringifier not well registered.");

    my $ok = $text =~ /Adobe/;
    $this->assert($ok, "Text Adobe not included");

    $this->assert_matches($this->encode('Äußerung'), $text, "Text Äußerung not found.");
}

sub test_SpecialCharacters {
    # check that special characters are not destroyed by the stringifier
    
    my $this = shift;
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::PDF->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Simple_example.pdf');

    $this->assert_matches($this->encode('Überflieger'), $text, "Text Überflieger not found.");
}

# test what would happen if someone uploaded a png and called it a .pdf
sub test_maliciousFile {
    my $this = shift;
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::PDF->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Im_a_png.pdf');

    $this->assert_equals('', $text, "Malicious file generated some text?");
}

1;
