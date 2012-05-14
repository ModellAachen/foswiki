package InvalidXml;

use Exceptions;
use overload ( '""' => 'stringify' );

@ISA = (Exceptions);

sub new {
    my ($sclass) = shift;
    my (%this)   = @_;
    my $self     = {};
    $self->{'-msg'}  = $this{'-msg'};
    $self->{'-file'} = $this{'-file'};

    bless $self, $sclass;
    return $self;
}

sub msg {
    my $obj = shift;
    return $obj->{'file'} . "not a valid XML file";
}

1;

