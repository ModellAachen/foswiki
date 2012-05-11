# Test for HTML.pm
package HtmlTests;
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
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::HTML->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Simple_example.html');
    my $text2 = Foswiki::Contrib::Stringifier->stringFor($this->{attachmentDir}.'Simple_example.html');

    $this->assert(defined($text), "No text returned.");
    $this->assert_str_equals($text, $text2, "HTML stringifier not well registered.");

    my $ok = $text =~ /Cern/;
    $this->assert($ok, "Text Cern not included");

    $this->assert_matches($this->encode('geöffnet'), $text, "Text geöffnet not found.");
}

sub test_SpecialCharacters {
    # check that special characters are not destroyed by the stringifier
    
    my $this = shift;
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::HTML->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Simple_example.html');

    $this->assert_matches($this->encode('geöffnet'), $text, "Text geöffnet not found.");
}

# test what would happen if someone uploaded a png and called it a .html
# SMELL: strange test
sub DONT_test_maliciousFile {
    my $this = shift;
    my $stringifier = Foswiki::Contrib::Stringifier::Plugins::HTML->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Im_a_png.html');

    $this->assert_equals('', $text, "Malicious file generated some text?");
}

1;
