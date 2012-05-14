# Test for Text.pm
package TxtTests;
use StringifierTest;
our @ISA = qw( StringifierTest );

use strict;
use utf8;

use Foswiki::Contrib::Stringifier::Base();
use Foswiki::Contrib::Stringifier ();

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
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::Text->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Simple_example.txt');
    my $text2 = Foswiki::Contrib::Stringifier->stringFor($this->{attachmentDir}.'Simple_example.txt');

    $this->assert(defined($text), "No text returned.");
    
    $this->assert_str_equals($text, $text2, "TXT stringifier not well registered.");

    my $ok = $text =~ /woodstock/;
    $this->assert($ok, "Text woodstock not included")
}

sub test_SpecialCharacters_utf8 {
    # check that special characters are not destroyed by the stringifier
    
    my $this = shift;
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::Text->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Simple_example.txt');

    $this->assert_matches($this->encode('Änderung'), $text, "Text Änderung not found.");
}

sub test_SpecialCharacters_latin1 {
    # check that special characters are not destroyed by the stringifier
    
    my $this = shift;
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::Text->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Simple_example_latin1.txt');

    $this->assert_matches($this->encode('Änderung'), $text, "Text Änderung not found.");
}

# test what would happen if someone uploaded a png and called it a .txt
# SMELL: strange test
sub DONT_test_maliciousFile {
    my $this = shift;
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::Text->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Im_a_png.txt');

    $this->assert_equals('', $text, "Malicious file generated some text?");
}

1;
