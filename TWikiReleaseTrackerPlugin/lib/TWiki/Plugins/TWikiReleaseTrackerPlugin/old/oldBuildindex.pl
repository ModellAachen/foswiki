#! /usr/bin/perl -w

use strict;
use Digest::MD5;
use FileHandle;

package main;

my $excludeFilePattern = 'DEADJOE|.svn|\~$|\,v|.changes|.mailnotify|.session';

sub debug {
    my ($ans) = @_;

    #    print STDERR $ans;
}

sub relativeFromPathname {
    my ( $filename, $setpath ) = @_;
    my $ans = $filename;
    $ans =~ s!$setpath!!;
    return $ans;
}

sub indexSets {
    IndexSets::indexSet( "athens", $ENV{HOME} . "/athenstwiki.mrjc.com/",
        $excludeFilePattern );
    IndexSets::indexSet( "beijing", $ENV{HOME} . "/beijingtwiki.mrjc.com/",
        $excludeFilePattern );
    IndexSets::indexSet( "cairo", $ENV{HOME} . "/cairotwiki.mrjc.com/",
        $excludeFilePattern );

}

#indexSets();
#FileDigest::saveIndex("/tmp/index");
FileDigest::loadIndex("/tmp/index");

#FileDigest::printIndex();
#exit 1;

MatchAgainstIndex::match( "redbourn", $ENV{HOME} . "/redbourn.org.uk/",
    $excludeFilePattern );

package MatchAgainstIndex;

# This routine is supposed to restrict matches to those directories always
# present in a distro, but I couldn't get the regexp to match so I moved on...
sub includeDirectory {
    my ($dir) = @_;

    #    print "================\nAbout to process $dir\n";
    return 1 if ( $dir !~ m!/twiki/! );
    my $process = ( $dir =~
          m!/twiki/(data|pub|templates)*(/TWiki|Main|Know|Trash|Sandbox)*! );

    #    print "===> $process <====\n";
    return $process;
}

sub match {
    my ( $set, $setLocation, $excludeFilePattern ) = @_;
    use File::Find;

    # exclude files that are known junk
    # exclude dirs if
    my $preprocessCallback = sub {

        #	return unless (includeDirectory($File::Find::dir));
        return grep { !/$excludeFilePattern/ } @_;
    };

    my $findCallback = sub {
        my $pathname = $File::Find::name;    #  complete pathname to the file.
        return unless -f $pathname;
        return if -z $pathname;
        main::debug "$pathname\n";
        matchFile( $set, $setLocation, $pathname );
    };
    find(
        {
            wanted     => $findCallback,
            preprocess => $preprocessCallback,
            follow     => 0
        },
        $setLocation
    );
}

sub matchFile {
    my ( $set, $setLocation, $pathname ) = @_;
    my $digest = IndexSets::digestForFile($pathname);
    main::debug $digest. "\n";
    my $relativeFile = main::relativeFromPathname( $pathname, $setLocation );
    print $set. ": " . $relativeFile . " = ";

    #    print FileDigest::retreiveStringForKey($digest)."\n";
    print FileDigest::retreiveSetForKey( $digest, $relativeFile ) . "\n";
}

package IndexSets;

sub indexSet {
    my ( $set, $setLocation, $excludeFilePattern ) = @_;
    use File::Find;

    my $preprocessCallback = sub {
        return grep { !/$excludeFilePattern/ } @_;
    };

    my $findCallback = sub {
        my $pathname = $File::Find::name;    #  complete pathname to the file.
        return unless -f $pathname;
        return if -z $pathname;
        main::debug "$pathname\n";
        indexFile( $set, $setLocation, $pathname );
    };
    find(
        {
            wanted     => $findCallback,
            preprocess => $preprocessCallback,
            follow     => 0
        },
        $setLocation
    );
}

sub indexFile {
    my ( $set, $setLocation, $file ) = @_;
    my $digest = digestForFile($file);
    my $relativePath = main::relativeFromPathname( $file, $setLocation );
    main::debug $digest. "\n";
    FileDigest::addToIndex( $set, $relativePath, $digest );
}

sub digestForFile {
    my ($file) = @_;
    my $fh = new FileHandle $file, "r";
    unless ( defined $fh ) {
        return "$!";
    }
    unless ( -s $fh ) {
        return "EMPTY";
    }
    use Digest::MD5;
    my $ctx = Digest::MD5->new;
    $ctx->addfile($fh);
    return $ctx->hexdigest();
}

package FileDigest;
my %index;    #key = digest, value = [($setName, $file)];

sub addToIndex {
    my ( $setName, $file, $digest ) = @_;
    my $content = [ $setName, $file ];

    #    print $content;
    push @{ $index{$digest} }, $content;
}

sub retreiveArrayForKey {
    my ($key) = @_;
    my $values = $index{$key};
    if ( defined $values ) {
        return @{$values};
    }
    else {
        return ();
    }
}

sub retreiveStringForKey {
    my ($key) = @_;
    my @values = retreiveArrayForKey($key);
    unless (@values) {
        @values = ( [ "no match", "no match" ] );
    }
    my $ans;

    #    $ans  = $key . " => \n";
    foreach my $value (@values) {

        #	$ans .= "\t".$value."\n"; #debug
        $ans .= "\t" . join( " ", @{$value} ) . ", ";
    }
    return $ans;
}

sub retreiveSetForKey {
    my ( $key, $checkfile ) = @_;
    my @occurances = retreiveArrayForKey($key);
    if (@occurances) {
        my $ans;
        foreach my $occurance (@occurances) {
            my ( $set, $storedfile ) = @{$occurance};
            if ( $storedfile ne $checkfile ) {
                $ans .= "same content as $set '$storedfile', ";
            }
            else {
                $ans .= $set . ", ";
            }
        }
        $ans =~ s/, $//;    # trip trailing comma
        return $ans;
    }
    else {
        return "no match";
    }
    die "illegal exit from retreive set for key";
}

sub printIndex {
    foreach my $key ( sort keys %index ) {
        print retreiveStringForKey($key) . "\n";
    }
}

sub dumpIndex {
    use Data::Dumper;
    return Dumper(%index);
}

sub loadIndex {
    my ($filename) = @_;
    my $fh = new FileHandle $filename, "r";
    unless ( defined $fh ) {
        die "$!";
    }
    my $contents = join( "", <$fh> );
    %index = %{ eval $contents };
    close $fh;
}

sub saveIndex {
    my ($filename) = @_;
    my $fh = new FileHandle $filename, "w";
    unless ( defined $fh ) {
        die "$!";
    }
    $Data::Dumper::Terse = 1;
    print $fh Dumper( \%index );
    close $fh;
}
