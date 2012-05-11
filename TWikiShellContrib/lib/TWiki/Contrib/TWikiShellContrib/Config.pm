
package TWiki::Contrib::TWikiShellContrib::Config;

sub new {

    my $self = bless {}, shift;
    $self->{verbosity} = 1;
    return $self;
}

#######################################
# Handle CL params
#######################################

sub handleParams {
    my $self    = shift;
    my $n       = 0;
    my $execute = 0;

    while ( $n <= $#ARGV ) {
        if ( $ARGV[$n] =~ /^--(.+)/o ) {
            if ( $1 eq "v" ) {
                $self->{verbosity} = 1;
            }
            elsif ( $1 eq "vv" ) {
                $self->{verbosity} = 2;
            }
            elsif ( $1 eq "q" ) {
                $self->{verbosity} = 0;
            }
            elsif ( $1 eq "d" ) {
                $self->{debug} = 1;
            }
            elsif ( $1 eq "shorcuts" ) {
                $self->{execute} = "shorcuts";
                last;
            }
        }
        else {
            $self->{execute} .= $ARGV[$n] . ' ';
        }
        $n++;
    }
}

sub saveAndDispose {
    my $self = shift;

    if ( $self->{execute} ) {
        $self->{execute} = "";
    }

    $self->{debug}      = 0;
    $self->{initialize} = 0;
    $self->save();
}

sub save {
    my $self = shift;
    use Data::Dumper;
    my $oldValue = $self->{execute};
    $self->{execute} = '';
    my $data = Data::Dumper->Dump( [$self], [qw(config)] );
    open CONFIG, ">" . $self->{configFileName};
    print CONFIG $data;
    close CONFIG;
    $self->{execute} = $oldValue;
}
1;
