#!/usr/bin/perl

my $ssh_route   = $ARGV[0];
my $ssh_key     = $ARGV[2];
my $FoswikiPath = $ARGV[1];

my $data;
if ( open( my $IN, '<', $ssh_route ) ) {
    local $/ = undef;
    $data = <$IN>;
    $data =~ s#ssh -i (.*?) "\$@"#$1#;
    close($IN);
}

if ( $data ne $ssh_key ) {
    open( my $OUT, '>', $ssh_route );
    print $OUT "#!/bin/sh\nssh -i $ssh_key \"\$@\" ";
    close($OUT);
}
chmod( 0744, $ssh_route );

$ENV{GIT_SSH} = $ssh_route;

my $start = `pwd`;

chdir $FoswikiPath;

my $execCmd = "$ARGV[3] $ARGV[4]";

print `$execCmd 2>&1`;

chdir $start;
