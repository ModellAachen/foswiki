#! /usr/bin/perl -w

use strict;
use Digest::MD5;
use FileHandle;
use TWiki::Plugins::TWikiReleaseTrackerPlugin::Common;

package TWiki::Plugins::TWikiReleaseTrackerPlugin::FileDigest;

=pod

in: $digest
out: hash of 
       pairs of (all keys, with usages of those keys)
          where the key is the md5 hashvalue and
          where the value is an array of occurances
            where each occurance is a pair of (distribution, file) 

(for example)

{
    '1d95e2bcc6bc546e86a56996e37c4ff3' => [
					   [
					    'athens',
					    'twiki/data/Main/WebIndex.txt'
					    ],
					   [
					    'beijing',
					    'twiki/data/Main/WebIndex.txt'
					    ]
					   ],
    'b65816bb7dd1ee8a7a4f10a108c0e412' => [
					   [
					    'beijing',
					    'twiki/data/Main/WebPreferences.txt'
					    ]
					   ],
}
=cut

my %digestToOccurances;     #key = digest, value = [($distributionName, $file)];
my %filenameToOccurances;   #
my %distributionToOccurances;    # key = distribution

sub emptyIndexes {
    %digestToOccurances       = ();
    %filenameToOccurances     = ();
    %distributionToOccurances = ();
}

sub addOccurance {
    my ( $distribution, $file, $digest ) = @_;
    my $distributionAndFile   = [ $distribution, $file ];
    my $distributionAndDigest = [ $distribution, $digest ];
    my $filenameAndDigest     = [ $file,         $digest ];

    #    print $distributionAndFile;
    push @{ $digestToOccurances{$digest} },             $distributionAndFile;
    push @{ $filenameToOccurances{$file} },             $distributionAndDigest;
    push @{ $distributionToOccurances{$distribution} }, $filenameAndDigest;
}

sub getDistributions {
    return keys %distributionToOccurances;
}

sub getFilenames {
    return keys %filenameToOccurances;
}

sub getDigests {
    return keys %digestToOccurances;
}

sub retreiveOccurancesForDigest {

=pod
returns array of arrays:
outer: list of occurances
inner: pair of distribution, filename

=cut

    my ($digest) = @_;
    my $values = $digestToOccurances{$digest};

    if ( defined $values ) {
        return @{$values};
    }
    else {
        wantarray ? () : 0;
    }
}

sub retreiveOccurancesForDistribution {

=pod
returns array of arrays:
outer: list of occurances
inner: pair of filename, digest

=cut

    my ($digest) = @_;
    my $values = $distributionToOccurances{$digest};

    if ( defined $values ) {
        return @{$values};
    }
    else {
        wantarray ? () : 0;
    }
}

sub retreiveStringForDigest {
    my ($digest) = @_;
    my @occurances = retreiveOccurancesForDigest($digest);
    unless (@occurances) {
        @occurances = ( [ "no match", "no match" ] );
    }
    my $ans;

    #    $ans  = $digest . " => \n";
    foreach my $occurance (@occurances) {

        #	$ans .= "\t".$occurance."\n"; #debug
        $ans .= "\t" . join( " ", @{$occurance} ) . ", ";
    }
    return $ans;
}

sub retreiveFilenamesForDistribution {
    my ($distribution) = @_;
    my $occurances = $distributionToOccurances{$distribution};
    return () unless ( defined $occurances );

    my @occurances = @{$occurances};
    my @ans;
    foreach my $occurance (@occurances) {
        my ( $filename, $digest ) = @{$occurance};
        push @ans, $distribution;
    }
    return @ans;
}

sub retreiveDistributionsForFilename {
    my ($filename) = @_;
    my $occurances = $filenameToOccurances{$filename};
    return () unless ( defined $occurances );

    my @occurances = @{$occurances};
    my @ans;
    foreach my $occurance (@occurances) {
        my ( $distribution, $digest ) = @{$occurance};
        push @ans, $distribution;
    }
    return @ans;
}

sub retreiveDistributionsForDigest {

=pod
in: digest - key you are looking for
in: checkfile - filename you expect this to match
out: array: of distributions,  or "distribution: same content as $storedFile" or ()

=cut

    my ( $digest, $checkfile ) = @_;
    my @occurances = retreiveOccurancesForDigest($digest);
    if (@occurances) {
        my @ans = ();
        foreach my $occurance (@occurances) {
            my ( $distribution, $storedfile ) = @{$occurance};
            if ( $storedfile ne $checkfile ) {
                push @ans, "$distribution: same content as '$storedfile'";
            }
            else {
                push @ans, $distribution;
            }
        }
        return @ans;
    }
    else {
        return ();
    }
    die "illegal exit from retreive distribution for digest";
}

sub printIndexes {
    foreach my $digest ( sort keys %digestToOccurances ) {
        print retreiveStringForDigest($digest) . "\n";
    }
}

sub _dumperIndexes {
    use Data::Dumper;
    return Dumper(%digestToOccurances);
}

sub loadIndexes {
    my ($dir) = @_;

    use DirHandle;
    my $dh = DirHandle->new($dir) || die "$! - $dir";

    TWiki::Plugins::TWikiReleaseTrackerPlugin::Common::debug
      "loading indexes from $dir:\n\n";
    foreach my $index ( sort grep { /.md5$/ } $dh->read() ) {
        loadIndex( $dir . "/" . $index );
    }
}

sub loadIndex {
    my ($filename) = @_;
    TWiki::Plugins::TWikiReleaseTrackerPlugin::Common::debug
      "loading index $filename\n";
    my $fh = new FileHandle $filename, "r";
    unless ( defined $fh ) {
        die "$filename - $!";
    }
    local $/ = "\n";    # line mode

    while ( my $line = <$fh> ) {
        chomp $line;
        TWiki::Plugins::TWikiReleaseTrackerPlugin::Common::debug "$line\n";

        next if ( $line eq "" );
        next if ( $line =~ m/^#.*/ );
        my ( $digest, $distributionfile ) = split /\s+/, $line;
        my ( $distribution, $file ) = split /=/, $distributionfile;
        TWiki::Plugins::TWikiReleaseTrackerPlugin::Common::debug
          "$distribution, $file, $digest \n";
        addOccurance( $distribution, $file, $digest );
    }
    close $fh;
}

sub saveIndex {
    my ($filename) = @_;
    my $fh = new FileHandle $filename, "w";
    unless ( defined $fh ) {
        die "$! - $filename";
    }
    TWiki::Plugins::TWikiReleaseTrackerPlugin::Common::debug
      "Saving to $filename\n";
    foreach my $digest ( keys %digestToOccurances ) {
        my @occurances = retreiveOccurancesForDigest($digest);
        foreach my $occurance (@occurances) {
            my ( $distribution, $filename ) = @{$occurance};
            print $fh "$digest $distribution=$filename\n"
              ;    #CODE_SMELL: not standard format
        }
    }
    close $fh;
}

sub _unDumpIndex {    # NB. Does not work in taint mode due to eval.
    my ($filename) = @_;
    my $fh = new FileHandle $filename, "r";
    unless ( defined $fh ) {
        die "$!";
    }
    my $contents = join( "", <$fh> );
    %digestToOccurances = %{ eval $contents };
    close $fh;
}

sub dumpIndex {
    my ($filename) = @_;
    my $fh = new FileHandle $filename, "w";
    unless ( defined $fh ) {
        die "$!";
    }
    $Data::Dumper::Terse = 1;
    print $fh Dumper( \%digestToOccurances );
    close $fh;
}

sub dataOutline {
    my $ans;
    my @distros = FileDigest::getDistributions();
    $ans .= "Distributions:\n   * " . join( "\n   * ", sort @distros ) . "\n";

    $ans .= "Filenames:\n";
    my @filenames = sort &FileDigest::getFilenames;
    foreach my $file (@filenames) {
        $ans .= "\n   * " . $file;
        $ans .= "\n\t\t"
          . join( "\n\t\t", retreiveDistributionsForFilename($file) ) . "\n";
    }
    $ans .= "\n";

    my @digests = FileDigest::getDigests();
    $ans .= "Digests:\n   * " . join( "\n   * ", sort @digests );
    foreach my $digest (@digests) {
        $ans .= "\n   * " . $digest;
        $ans .= "\n\t\t"
          . join( "\n\t\t", retreiveDistributionsForDigest($digest) ) . "\n";
    }
    $ans .= "\n";

    $ans .= "\n";

    return $ans;
}

1;
