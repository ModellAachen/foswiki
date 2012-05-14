# Test for PPT.pm
package PptTests;
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
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::PPT->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Simple_example.ppt');
    my $text2 = Foswiki::Contrib::Stringifier->stringFor($this->{attachmentDir}.'Simple_example.ppt');

    $this->assert(defined($text) && $text ne "", "No text returned.");
    $this->assert_str_equals($text, $text2, "PPT stringifier not well registered.");

    my $ok = $text =~ /slide/;
    $this->assert($ok, "Text slide not included")
}

sub test_SpecialCharacters {
    # check that special characters are not destroyed by the stringifier
    
    my $this = shift;
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::PPT->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Simple_example.ppt');

    $this->assert_matches($this->encode('Übergang'), $text, "Text Übergang not found.");
}

# test for Passworded_example.ppt
# Note that the password for that file is: foswiki
sub test_passwordedFile {
    my $this = shift;
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::PPT->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Passworded_example.ppt');
    
    # not too sure what to test... This is the default from pptHtml
    $this->assert_matches('Created with pptHtml', $text);#, "Protected file generated some text?");
}

# test what would happen if someone uploaded a png and called it a .ppt
sub test_maliciousFile {
    my $this = shift;
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::PPT->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Im_a_png.ppt');

    $this->assert_equals('', $text, "Malicious file generated some text?");
}

1;
