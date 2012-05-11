#!/usr/bin/perl -w
# Interaction script for twiki_dav, the mod_dav module.

BEGIN {
    use FindBin qw( $Bin );
    use lib $Bin. '/../bin';
    require 'setlib.cfg';
}

use TWiki;
use File::Copy;
use CGI;
use Error qw( :try );

# default junk web and topic
my $defJWeb   = "Trash";
my $defJTopic = "TrashAttachment";

my $rf = $ARGV[0];
die "ERROR: No response file" unless $rf;

sub _decode {
    return chr( hex(shift) );
}

sub _standardChecks {
    my ( $access, $web, $topic, $user ) = @_;
    my $wikiUserName = TWiki::Func::userToWikiName($user);
    die "Web $web does not exist"
      unless TWiki::Func::webExists($web);
    die "Access to $access $web/$topic denied"
      unless TWiki::Func::checkAccessPermission( $access, $wikiUserName, '',
              $topic, $web );
}

sub _parseResource {
    my $path = shift;
    my ( $web, $topic, $att );

    $path =~ s/%(\d[A-Fa-f\d])/_decode($1)/ge;

    if ( $path =~ m/^\/?(\w+)\/(\w+)\/([^\/]+)$/ ) {

        ( $web, $topic, $att ) = ( $1, $2, $3 );
        $att =~ s/%(\d[A-Fa-f\d])/_decode($1)/ge;

    }
    elsif ( $path =~ m/^\/?(\w+)\/([^\/]+)\.txt$/ ) {

        ( $web, $topic ) = ( $1, $2 );

    }
    else {

        die "Bad resource $path";

    }
    die "No web in $path" unless ($web);

    return ( $web, $topic, $att );
}

sub _move {
    my ( $srcWeb, $srcTopic, $srcAtt, $dstWeb, $dstTopic, $user ) = @_;

    _standardChecks( "change", $srcWeb, $srcTopic, $user );
    _standardChecks( "change", $dstWeb, $dstTopic, $user );

    TWiki::Func::moveAttachment( $srcWeb, $srcTopic, $srcAtt, $dstWeb,
        $dstTopic, $srcAtt );
}

try {
    my $user = $ARGV[1];
    die "No user" unless $user;
    my $function = $ARGV[2];
    die "No function" unless $function;

    my ( $web, $topic, $att ) = _parseResource( $ARGV[3] || '' );
    die "No topic in resource" unless ($topic);

    my $query = new CGI("");
    $query->path_info("/$web/$topic");
    $TWiki::Plugins::SESSION = new TWiki( $user, $query );

    if ( $function eq 'delete' ) {

        # This has to be done by a move.
        my $jWeb   = $defJWeb;
        my $jTopic = $defJTopic;

        if ( !$att ) {
            die 'Cannot delete a TWiki topic';
        }

        _move( $web, $topic, $att, $jWeb, $jTopic, $user );

    }
    elsif ( $function eq 'move' ) {

        my ( $web2, $topic2, $att2 ) = _parseResource( $ARGV[4] );
        die 'No topic in ' . $ARGV[4] unless ($topic);

        _move( $web, $topic, undef, $web2, $topic2, $user );

    }
    elsif ( $function eq 'attach' ) {

        _standardChecks( 'change', $web, $topic, $user );

        die 'No attachment' unless ($att);
        $att =~ s/^\///o;
        $att =~ s/%(\d[A-Fa-f\d])/&_decode($1)/geo;

        my $path = $ARGV[4];
        die 'No path' unless ($path);
        $path =~ s/%(\d[A-Fa-f\d])/&_decode($1)/geo;
        die $path . ' does not exist' unless ( -e $path );

        my $f = $path . $$;
        File::Copy::move( $path, $f );
        TWiki::Func::saveAttachment( $web, $topic, $att, { file => $f } );
        unlink($f);

    }
    elsif ( $function eq 'unmeta' ) {

        # Get a topic, stripping meta-data, and write it to the path given
        # in $ARGV[4]
        my $path = $ARGV[4];
        die "No path" unless ($path);

        # Put a topic, re-adding meta-data. The new text is passed in
        _standardChecks( "view", $web, $topic, $user );

        my ( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );

        $text =~ s/\t/   /g;    # SMELL should be done in readTopic, if at all

        $path =~ s/%(\d[A-Fa-f\d])/&_decode($1)/geo;
        open( TXT, ">$path" ) or die "Could not open $path";
        print TXT $text;
        close(TXT);

    }
    elsif ( $function eq "remeta" ) {

        # Put a topic, re-adding previous meta-data. The new text is passed in
        # the given pathname.
        my $path = $ARGV[4];
        die "No path" unless ($path);

        _standardChecks( "change", $web, $topic, $user );

        my ( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );

        $text = '';
        $path =~ s/%(\d[A-Fa-f\d])/&_decode($1)/geo;
        open( TXT, "<$path" ) or die "Could not open $path";
        while (<TXT>) {
            $text .= $_;
        }
        close(TXT);

        $text =~ s/ {3}/\t/g;    # SMELL should be done in saveTopic, if at all

        TWiki::Func::saveTopic( $web, $topic, $meta, $text );

    }
    else {
        die "Bad function $function in " . join( " ", @ARGV );
    }
}
catch Error::Simple with {
    open( RF, ">$rf" );
    $| = 1;
    print RF "ERROR: $e->{-text}\n";
    close(RF);
    die $e->{-text};
};

1;
