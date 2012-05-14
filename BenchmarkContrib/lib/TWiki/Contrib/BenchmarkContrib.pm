use strict;

package TWiki::Contrib::BenchmarkContrib;
use vars qw( $VERSION );
$VERSION = '$Rev$';

# -------- Constants (don't use Constant, though - see PBP why)
#          (perhaps to be replaced by config vars some day)
use vars qw($benchmarkWeb $scriptName);
$benchmarkWeb = 'Benchmarks';
$scriptName   = 'profile';
my @supported_profilers = qw(DProf);
my %supported_profilers = map { $_ => 1 } @supported_profilers;

sub profile {
    my $twiki = shift;

    my $query = $twiki->{cgiQuery};

    $twiki->enterContext($scriptName);

    # how to profile
    my $profiler = $query->param('profiler') || '';
    ($profiler) = $profiler =~ /(\w*)/;
    if ( !$supported_profilers{$profiler} ) {
        $profiler = $supported_profilers[0];
    }

    my $profiler_package = "TWiki::Contrib::BenchmarkContrib::$profiler";
    eval "require $profiler_package";
    die $@ if $@;

    $profiler_package->profile( $twiki, $scriptName, $benchmarkWeb );
}

1;
