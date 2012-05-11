package Exceptions;

our @ISA = (Error);

sub new {
    my ($sclass) = shift;
    my (%this)   = @_;
    my $self     = {};

    bless $self, $sclass;
    return $self;
}

# we will add methods which will be commonly used by
# individual expection classes

1;
