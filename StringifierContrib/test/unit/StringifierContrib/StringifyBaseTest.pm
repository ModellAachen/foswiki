# Test for StringifyBase.pm
package StringifyBaseTest;
use StringifierTest;
our @ISA = qw( StringifierTest );

use strict;
use File::Temp qw/tmpnam/;

use Foswiki::Contrib::Stringifier::Base;

sub set_up {
    my $this = shift;
    
    $this->{attachmentDir} = 'tree_example/';
    if (! -e $this->{attachmentDir}) {
        #running from foswiki/test/unit
        $this->{attachmentDir} = 'StringifierContrib/tree_example/';
    }

    $this->SUPER::set_up();
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_handler_for {
    my $this = shift;
    my $stringifier = Foswiki::Contrib::Stringifier::Base->new();

    my $handler = $stringifier->handler_for("test.pdf", "dummy");
    $this->assert($handler->isa("Foswiki::Contrib::Stringifier::Plugins::PDF"), 
		  "Bad handler for test.pdf");

    # I check that capital letters in the file name don't confuse the stringifier
    $handler = $stringifier->handler_for("TEST.PDF", "dummy");
    $this->assert($handler->isa("Foswiki::Contrib::Stringifier::Plugins::PDF"), 
		  "Bad handler for TEST.PDF");
}

1;
