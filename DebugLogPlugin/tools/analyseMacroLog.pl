#!/usr/bin/perl -wT
#to generate a set of requests that can be used to generate a result set run:
# rgrep --files-with-matches --exclude='*,v' '%SEARCH{' * | sed 's/^/curl -I http:\/\/x61\/f\/bin\/view\//' | sed 's/.txt//' > runTests.sh
# that otput file can then be run for each cfg using 'sh runTests.sh > sometestoutput.log'
#
#from there, we have a pile of results in the working/work_areas/DebugLogPlugin dir...
#
# what we want is:
# 1 a list of SEARCH's (and the topic they are in) for which mongoDB is slower,
# 2 a simple to read table / graph that will quickly show when there are changes to results due to code changes (both good and bad, for whatever algo.
#
# so:
# foreach (algo) {
# make a list of SEARCH vs time
# rank and sort by time, and highlight by how much faster / slower it is than the 'benchmark'
# }
#
# graph difference?

use warnings;
use strict;

use Digest::MD5 'md5_hex';

my %results;
my %cfgs = ();
my @cfg_names;

my $logDir = 'working/work_areas/DebugLogPlugin/';
opendir( my $dh, $logDir );
while ( my $file = readdir($dh) ) {
    $file = $logDir . $file;
    next if ( not -f $file );
    loadFile( \%results, $file );
}

#consider the rcswrap|pureperl|forking the 'benchmark we're measuring against, and then add {store|query|search}->{array of diff}, {count}, {min}, {max}, {better}
print <<HERE;
   * =RcsWrap-QueryAlgorithms::BruteForce-SearchAlgorithms::Forking-1= column is the time takes in seconds
   * the other columns are the difference between the SEARCH macro's time - that 'benchmark'
   * so negative is good, positive is bad, and large positice needs fixing.
HERE
print "\n| *"
  . join( '* | *', @cfg_names )
  . "* |*topic*  |*type*|*SEARCH*  |\n";
map {
    analyseSearch(
        'RcsWrap-QueryAlgorithms::BruteForce-SearchAlgorithms::Forking-1',
        $results{$_}, $_ );
} keys(%results);

#######################################
sub loadFile {
    my $results = shift;
    my $file    = shift;

    open( my $fh, '<', $file ) || return "failed to open $file\n";
    local $/;
    my $text = <$fh>;
    close($fh);

    my ( $params, $log, $postamble ) = split( /==============\n/, $text );
    $log =~ s/^HASH//;
    $log =~ /(.*)/s;
    $log = $1;
    my $VAR1;
    eval($log);

    my $hash = md5_hex( $VAR1->{params}->{_RAW} );

    my @filename = split( /-/, $file );

    #print STDERR "-----".$filename[2]."\n";
    $VAR1->{topic} = $filename[2];
    $VAR1->{date}  = $filename[5];

    #generate a unique name for the cfg
    $VAR1->{id} = join(
        '-',
        (
            $VAR1->{Store}->{Implementation},
            $VAR1->{Store}->{QueryAlgorithm},
            $VAR1->{Store}->{SearchAlgorithm},
            $VAR1->{EnableHierarchicalWebs}
        )
    );

    #trim it a little
    $VAR1->{id} =~ s/Foswiki::Store:://g;

    if ( not defined( $cfgs{ $VAR1->{id} } ) ) {
        push( @cfg_names, $VAR1->{id} );
        $cfgs{ $VAR1->{id} } = {
            count => scalar( keys(%cfgs) ),
            name  => $VAR1->{id},
        };
    }

    if ( not( defined( $results->{$hash} ) ) ) {
        $results->{$hash} = ();
        $results->{$hash}{topic} = $VAR1->{topic};
    }
    my $elements = push( @{ $results->{$hash}{details} }, $VAR1 );

#     print "\tmd5(SEARCH.RAW): ".$hash."\n";
#     print "\tcfg ID:          ".${$results->{$hash}{details}}[$elements-1]->{id}."\n";
#     print "\tmacroTime:       ".${$results->{$hash}{details}}[$elements-1]->{macroTime}."\n";
#     print "\tparams.search:   ".${$results->{$hash}{details}}[$elements-1]->{params}->{search}."\n";

}

sub analyseSearch
{ #('RcsWrap|QueryAlgorithms::BruteForce|SearchAlgorithms::PurePerl|1', %results{$_});
    my $benchmark_id = shift;
    my $res          = shift;
    my $key          = shift;

    my $_RAW = $res->{details}[0]->{params}->{_RAW};
    my $SEARCH = $res->{details}[0]->{params}->{search} || 'huh';
    $SEARCH =~ s/\n/ \\\n/g;
    $SEARCH =~ s/\|/%VBAR%/g;
    my $type = ( $res->{details}[0]->{params}->{type} || 'literal' );

    #print "\n------------------------------------\n";
    #print "SEARCH:\t$SEARCH\n";

    #use the minimum time reported for the benchmart setup
    my $benchmark_minimum = 999999999999999999999999999999;

    #for my $i (@{$res->{details}}) {
    for ( my $i = 0 ; $i < scalar( @{ $res->{details} } ) ; $i++ ) {

#          'macroTime' => '0.684006 wallclock secs ( 0.43 usr +  0.02 sys =  0.45 CPU)',

        my $timestr = ${ $res->{details} }[$i]->{macroTime};
        $timestr =~ /^([\d\.]*) wallclock/;
        my $seconds = 1.0 * $1;
        ${ $res->{details} }[$i]->{seconds} = $seconds;

        #print "id:\t".${$res->{details}}[$i]->{id}."\n";
        #print "bam\t\t $timestr ----- $seconds\n";
        if ( ${ $res->{details} }[$i]->{id} eq $benchmark_id ) {
            if ( $seconds < $benchmark_minimum ) {
                $benchmark_minimum = $seconds;

            }
        }
    }
    $res->{benchmark_seconds} = $benchmark_minimum;

    #print "\n\nbenchmark\t $benchmark_minimum\n";

    my @differences = ( [], [], [], [], [], [], [], [], [], [] );

    #compare to benchmark_minimum
    for ( my $i = 0 ; $i < scalar( @{ $res->{details} } ) ; $i++ ) {
        my $date = ${ $res->{details} }[$i]->{date};
        $date =~ /^(\d\d):(\d\d):(\d\d):(\d\d):(\d\d):(\d\d)/;
        my $ndate = $1 . $2 . $3 . $4 . $5 . $6;

        #TODO: convert to integer
        my $diff = ${ $res->{details} }[$i]->{seconds} - $benchmark_minimum;
        if ( abs($diff) > 0.001 ) {
            ${ $res->{details} }[$i]->{difference} = $diff;
        }
        else {
            ${ $res->{details} }[$i]->{difference} = 0;    #essentially pontless
        }
        push(
            @{ $res->{ ${ $res->{details} }[$i]->{id} } },
            ${ $res->{details} }[$i]->{difference}
        );    ###store info for each cfg.

        my $cfg = $res->{details}[$i]->{id};

        #print "sec: \t" . ${ $res->{details} }[$i]->{seconds} . "\n";
        #print "cfg:\t" . $cfg . "\n";
        #print "diff\t" . ${ $res->{details} }[$i]->{difference} . "\n";
        #print "count\t" . $cfgs{$cfg}->{count} . "\n";

        if ( $cfgs{$cfg}->{name} eq $benchmark_id ) {
            $differences[ $cfgs{$cfg}->{count} ] =
              [ { ndate => 0, date => '', value => $benchmark_minimum } ];
        }
        else {

            #er, order by date - maybe use a sparkline...
            push(
                @{ $differences[ $cfgs{$cfg}->{count} ] },
                {
                    ndate => $ndate,
                    date  => $date,
                    value => ${ $res->{details} }[$i]->{difference}
                }
            );
        }
    }

    print "| " . join(
        ' | ',
        map {

           #            if (ref($differences[ $cfgs{$_}->{count}]) eq 'ARRAY') {
            join(
                ', ',
                map {
                    $_->{value}    #.'___'.$_->{date}
                       #order so that we have the most recent first - that way the table sort reflects current goodness
                  } sort { $b->{ndate} <=> $a->{ndate} }
                  @{ $differences[ $cfgs{$_}->{count} ] }
              )

              #              } else {
              #                  \('')
              #              }
          } keys(%cfgs)
      )
      . "| " . '[['
      . $res->{topic} . ']]'
      . "  |$type|$SEARCH  |\n";
}

1;
