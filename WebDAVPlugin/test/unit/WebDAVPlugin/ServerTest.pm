package ServerTest;

use HTTP::DAV;

my @davUser;
#######################################################
# Configure the following for your local installation #
# Requres a correctly installed server and a twiki    #
#######################################################
my $twikiCfg    = "/home/twiki/alpha/lib/TWiki.cfg";
my $davPubPath  = "twiki/pub";
my $davDataPath = "twiki/data";
my $davLockPath = "/var/lock/webdav";
my $twikiBinDir = "/home/twiki/alpha/bin";
$davUser[0] = {
    wikiname => "TestUser1",
    password => "hubbahubba",
    username => "TestUser1"     # username as in REMOTE_USER
};
$davUser[1] = {
    wikiname => "TestUser2",
    password => "bloodandguts",
    username => "TestUser2"
};
#######################################################

use strict;

use Unit::TestCase;
our @ISA = qw( Unit::TestCase );

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

use vars qw( $defaultUrlHost $scriptUrlPath $dispScriptUrlPath $dispViewPath
  $pubUrlPath $pubDir $templateDir $dataDir $logDir
  $detailedOS $OS $scriptSuffix $uploadFilter $safeEnvPath
  $mailProgram $noSpamPadding $mimeTypesFilename $rcsDir $rcsArg
  $nullDev $useRcsDir $endRcsCmd $cmdQuote
  $storeTopicImpl $lsCmd $egrepCmd $fgrepCmd
  $displayTimeValues $useLocale $siteLocale $siteCharsetOverride
  $localeRegexes $upperNational $keywordMode @storeSettings
  $securityFilter $defaultUserName $wikiToolName $wikiHomeUrl
  $siteWebTopicName $mainWebname $twikiWebname $debugFilename
  $warningFilename $htpasswdFormatFamily $htpasswdEncoding
  $htpasswdFilename $authRealm $logFilename $remoteUserFilename
  $wikiUsersTopicname $userListFilename $doMapUserToWikiName
  $mainTopicname $notifyTopicname $wikiPrefsTopicname
  $webPrefsTopicname $statisticsTopicname $statsTopViews
  $statsTopContrib $doDebugStatistics $numberOfRevisions $editLockTime
  $superAdminGroup $doKeepRevIfEditLock $doGetScriptUrlFromCgi
  $doRemovePortNumber $doRemoveImgInMailnotify $doRememberRemoteUser
  $doPluralToSingular $doHidePasswdInRegistration $doSecureInclude
  $doLogTopicView $doLogTopicEdit $doLogTopicSave $doLogRename
  $doLogTopicAttach $doLogTopicUpload $doLogTopicRdiff
  $doLogTopicChanges $doLogTopicSearch $doLogRegistration
  $disableAllPlugins $doSuperAdminGroup );

require "$twikiCfg";
my $twikiurl   = "$defaultUrlHost/$scriptUrlPath";
my $davPubURL  = "$defaultUrlHost/$davPubPath";
my $davDataURL = "$defaultUrlHost/$davDataPath";
my $binurl     = "$defaultUrlHost/$scriptUrlPath";

my $testAttName = "TestAttachment.gif";
my $testAttPath = "/tmp/$testAttName";

sub set_up {
    my $this = shift;
    `cp -R $dataDir/_default $dataDir/Attest` or $this->assert("Fixture");
    `mkdir -p $pubDir/Attest`                 or $this->assert("Fixture");
    `chmod -f -R 777 $dataDir/Atttest`;
    `chmod -f -R 777 $pubDir/Attest`;
    open( TA, ">$testAttPath" );
    print TA "Bollocks";
    close(TA);
}

sub tear_down {
    `rm -rf $dataDir/Attest`;
    `rm -rf $pubDir/Attest`;
    unlink $testAttPath;
}

sub _createProtectedTopic {
    my ( $this, $web, $root, $a, $b ) = @_;

    my $text = "\n";
    my ( @v, @c, @r );
    push( @v, $davUser[0]{wikiname} ) unless ( $a & 4 );
    push( @v, $davUser[1]{wikiname} ) unless ( $b & 4 );
    push( @c, $davUser[0]{wikiname} ) unless ( $a & 2 );
    push( @c, $davUser[1]{wikiname} ) unless ( $b & 2 );
    push( @r, $davUser[0]{wikiname} ) unless ( $a & 1 );
    push( @r, $davUser[1]{wikiname} ) unless ( $b & 1 );

    $text .= "\t* Set DENYTOPICVIEW = " . join( ",", @v ) . "\n"
      if ( scalar(@v) );
    $text .= "\t* Set DENYTOPICCHANGE = " . join( ",", @c ) . "\n"
      if ( scalar(@c) );
    $text .= "\t* Set DENYTOPICRENAME = " . join( ",", @r ) . "\n"
      if ( scalar(@r) );

    my $tname = "$root$a$b";
    _saveTopic( 0, $web, $tname, $text );

    # make sure the pub dir exists, so puts work
    mkdir("$pubDir/$web/$tname");

    return $tname;
}

sub urlencode {
    return "%" . sprintf( "%02x", ord(shift) );
}

sub _saveTopic {
    my ( $user, $web, $topic, $text ) = @_;

    die unless $web;
    die unless $topic;
    $text = "empty" unless $text;
    $text =~ s/%/%25/go;
    $text =~ s/\*/%2A/go;
    while ( $text =~ s/([^A-Za-z0-9%])/&urlencode($1)/geo ) {
        ;
    }
    my $cmd = "curl -s -S ";
    $cmd .= "-u $davUser[$user]{username}:$davUser[$user]{password} ";
    $cmd .= "-d text='$text' ";
    $cmd .= "-d dontnotify=on ";
    $cmd .= "-d unlock=on ";
    $cmd .= "$binurl/save$scriptSuffix/${web}/${topic} ";
    my $retries = 0;
    do {
        `$cmd`;
        if ($?) {
            print STDERR "$cmd failed - retrying\n";
            $retries++;
            sleep 2;
        }
    } while ( $? && $retries < 5 );
    die "Gave in" if ( $retries && $? );
}

sub saveattachment {
    my ( $this, $user, $web, $topic, $att ) = @_;
    die unless $web;
    die unless $topic;
    my $cmd = "curl -s -S ";
    $cmd .= "-u $davUser[$user]{username}:$davUser[$user]{password} ";
    $cmd .= "-F filepath=\\\@$testAttPath ";
    $cmd .= "-F filename=$att ";
    $cmd .= "-F filecomment=ElucidateTheGoose ";
    $cmd .= "$binurl/upload$scriptSuffix/${web}/${topic} ";
    my $retries = 0;
    do {
        `$cmd`;
        if ($?) {
            print STDERR "$cmd failed - retrying\n";
            $retries++;
            sleep 2;
        }
    } while ( $? && $retries < 5 );
    die "Gave in" if ( $retries && $? );
}

sub davopen {
    my ( $this, $user, $url ) = @_;
    my ( $un, $up );
    my $dav = new HTTP::DAV;
    $dav->credentials(
        -user => $davUser[$user]{username},
        -pass => $davUser[$user]{password},
        -url  => $url
    );

    $dav->open( -url => $url )
      or die "Failed to open $url "
      . $dav->message . " at "
      . join( ":", caller );

    return $dav;
}

sub davcheck {
    my ( $this, $op, $dav ) = @_;

    $this->assert( $op, $dav->message . " at " . join( ":", caller() ) );
}

# check that a list contains some things and excludes others
sub checklist {
    my ( $this, $v, $yes, $no ) = @_;

    if ($yes) {
        foreach my $thing ( split( /[,\s]+/, $yes ) ) {
            $this->assert_matches( qr/\b$thing\b/,
                $v . " at " . join( ":", caller ) );
        }
    }
    if ($no) {
        foreach my $thing ( split( /[,\s]+/, $no ) ) {
            $this->assert_does_not_match( qr/\b$thing\b/,
                $v . " at " . join( ":", caller ) );
        }
    }
}

# check that an attachment is there or not there
sub checkatt {
    my ( $this, $exp, $web, $topic, $att, $nocom ) = @_;
    my $al =
      `egrep 'META:FILEATTACHMENT.*name=\"$att\"' $dataDir/$web/$topic.txt`;
    my $res = $?;
    my $at = " at " . join( ":", caller );
    if ($exp) {
        $this->assert(
            -e "$pubDir/$web/$topic/$att",
            "$web/$topic/$att doesn't exist $at"
        );
        $this->assert( -e "$pubDir/$web/$topic/$att,v",
            "$pubDir/$web/$topic/$att,v doesn't exist $at" );
        $this->assert( !$res, "$att is not in META of $web/$topic $at" );
        $this->assert_matches( qr/name=\"$att\"/, $al, $at );
        if ( !$nocom ) {
            $this->assert_matches( qr/comment=\"ElucidateTheGoose\"/,
                $al, " at $at in $al" );
        }
    }
    else {
        $this->assert( !-e "$pubDir/$web/$topic/$att",
            "$web/$topic/$att exists $at" );
        $this->assert(
            !-e "$pubDir/$web/$topic/$att,v",
            "$web/$topic/$att,v exists $at"
        );
        $this->assert( $res, "$att is in META ($al) of $web/$topic $at" );
    }
}

sub test_get {
    my $this = shift;
    my $dav;
    my $t = $this->_createProtectedTopic( "Attest", "DavTest", 7, 0 );
    $this->assert( -e "$dataDir/Attest/$t.txt" );

    # view access permitted
    $dav = $this->davopen( 0, $davDataURL );
    $this->davcheck( $dav->get("Attest/$t.txt"), $dav );

    # view access denied
    $dav = $this->davopen( 1, $davDataURL );
    $this->davcheck( !$dav->get("Attest/$t.txt"), $dav );

    my $tt = $this->_createProtectedTopic( "Attest", "DavTest", 4, 2 );

    # change denied, but view permitted
    $dav = $this->davopen( 0, $davDataURL );
    $this->davcheck( $dav->get("Attest/$tt.txt"), $dav );

    # change permitted, but view denied
    $dav = $this->davopen( 1, $davDataURL );
    $this->davcheck( !$dav->get("Attest/$tt.txt"), $dav );

    $tt = $this->_createProtectedTopic( "Attest", "DavTest", 4, 1 );

    # rename denied, but view permitted
    $dav = $this->davopen( 0, $davDataURL );
    $this->davcheck( $dav->get("Attest/$tt.txt"), $dav );

    # rename permitted, but view denied
    $dav = $this->davopen( 1, $davDataURL );
    $this->davcheck( !$dav->get("Attest/$tt.txt"), $dav );

    # Attachments should mirror topic permissions. Just need to check
    # that allow/deny works for attachments.
    $this->saveattachment( 0, "Attest", $t, $testAttName );

    # view access permitted
    $dav = $this->davopen( 0, $davPubURL );
    $this->davcheck( $dav->get("Attest/$t/$testAttName"), $dav );

    # view access denied
    $dav = $this->davopen( 1, $davPubURL );
    $this->davcheck( !$dav->get("Attest/$t/$testAttName"), $dav );
}

sub test_put {
    my $this = shift;
    my $t    = "TestTopic";

    # put to web
    my $dav = $this->davopen( 0, $davDataURL );
    $this->davcheck(
        !$dav->put(
            -local => $testAttPath,
            -url   => "Davtestweb"
        ),
        $dav
    );
    $this->assert( !-e "$dataDir/Davtestweb" );

    $dav = $this->davopen( 0, $davPubURL );
    $this->davcheck(
        !$dav->put(
            -local => $testAttPath,
            -url   => "Davtestweb"
        ),
        $dav
    );
    $this->assert( !-e "$pubDir/Davtestweb" );

    # create new topic in data area is no problem
    $dav = $this->davopen( 0, $davDataURL );
    $this->davcheck(
        $dav->put(
            -local => $testAttPath,
            -url   => "Attest/$t.txt"
        ),
        $dav
    );
    $this->assert( -e "$dataDir/Attest/$t.txt" );
    $this->assert( -e "$dataDir/Attest/$t.txt,v" );

    # create new topic in pub area is a problem
    $dav = $this->davopen( 0, $davPubURL );
    $this->davcheck(
        !$dav->put(
            -local => $testAttPath,
            -url   => "Attest/TestTopicTwo.txt"
        ),
        $dav
    );
    $this->assert( !-e "$pubDir/Attest/TestTopicTwo.txt" );

    # put to existing topic is OK
    $t = $this->_createProtectedTopic( "Attest", "DavTest", 7, 3 );
    $this->davcheck(
        !$dav->put(
            -local => $testAttPath,
            -url   => "Attest/$t.txt"
        ),
        $dav
    );

    # put to web where change is denied
    $dav = $this->davopen( 0, $davDataURL );
    _saveTopic( 0, "Attest", "WebPreferences",
        "\t* Set DENYWEBCHANGE = $davUser[1]{wikiname}\n" );
    $dav = $this->davopen( 1, $davDataURL );
    $this->davcheck(
        !$dav->put(
            -local => $testAttPath,
            -url   => "Attest/TestTopicTwo.txt"
        ),
        $dav
    );
    $this->assert( !-e "$dataDir/Attest/TestTopicTwo.txt" );

    # attach to non-existent topic
    $dav = $this->davopen( 0, $davPubURL );
    $this->davcheck(
        !$dav->put(
            -local => $testAttPath,
            -url   => "Attest/NonExistant/$testAttName"
        ),
        $dav
    );
    $this->assert( !-e "$pubDir/Attest/NonExistant/$testAttName" );

    # attach to existing topic.
    # and put to the pub dir
    $this->davcheck(
        $dav->put(
            -local => $testAttPath,
            -url   => "Attest/$t/$testAttName"
        ),
        $dav
    );
    $this->checkatt( 1, "Attest", $t, $testAttName, 1 );

    _saveTopic( 0, "Attest", "WebPreferences", "$davUser[1]{wikiname}\n" );

    # view denied, but can still change.
    $dav = $this->davopen( 1, $davPubURL );
    $this->davcheck(
        $dav->put(
            -local => $testAttPath,
            -url   => "Attest/$t/$testAttName"
        ),
        $dav
    );
    $this->checkatt( 1, "Attest", $t, $testAttName, 1 );

    # change denied, view allowed, should not be able to save
    $t = $this->_createProtectedTopic( "Attest", "DavTest", 7, 5 );
    $this->davcheck(
        !$dav->put(
            -local => $testAttPath,
            -url   => "Attest/$t/$testAttName"
        ),
        $dav
    );
    $this->checkatt( 0, "Attest", $t, $testAttName, 1 );

    # rename denied, but should be able to save
    $t = $this->_createProtectedTopic( "Attest", "DavTest", 7, 6 );
    $this->davcheck(
        $dav->put(
            -local => $testAttPath,
            -url   => "Attest/$t/$testAttName"
        ),
        $dav
    );
    $this->checkatt( 1, "Attest", $t, $testAttName, 1 );
}

sub test_delete {
    my $this = shift;
    my $dav = $this->davopen( 0, $davPubURL );

    my $t = $this->_createProtectedTopic( "Attest", "DavTest", 7, 6 );
    $this->saveattachment( 0, "Attest", $t, $testAttName );

    # delete whole web
    $dav = $this->davopen( 0, $davDataURL );
    $this->davcheck( !$dav->delete("Attest"), $dav );
    $this->checkatt( 1, "Attest", $t, $testAttName );

    $dav = $this->davopen( 0, $davPubURL );
    $this->davcheck( !$dav->delete("Attest"), $dav );
    $this->checkatt( 1, "Attest", $t, $testAttName );

    # delete attachment only. user 1 has no change permission
    $dav = $this->davopen( 1, $davPubURL );
    $this->davcheck( !$dav->delete("Attest/$t/$testAttName"), $dav );
    $this->checkatt( 1, "Attest", $t, $testAttName );

    $dav = $this->davopen( 0, $davPubURL );
    $this->davcheck( $dav->delete("Attest/$t/$testAttName"), $dav );
    $this->checkatt( 0, "Attest", $t, $testAttName );

    $this->saveattachment( 0, "Attest", $t, $testAttName );

    # delete whole topic
    $dav = $this->davopen( 0, $davPubURL );
    $this->davcheck( !$dav->delete("Attest/$t"), $dav );
    $this->checkatt( 1, "Attest", $t, $testAttName );

    $dav = $this->davopen( 1, $davDataURL );
    $this->davcheck( !$dav->delete("Attest/$t"), $dav );
    $this->checkatt( 1, "Attest", $t, $testAttName );

    # delete topic is banned
    $dav = $this->davopen( 0, $davDataURL );
    $this->davcheck( !$dav->delete("Attest/$t.txt"), $dav );
}

# collection making is banned everywhere
sub test_mkcol {
    my $this = shift;

    my $dav = $this->davopen( 0, $davDataURL );
    $this->davcheck( !$dav->mkcol("Blockme"), $dav );
    $this->assert( !-d "$dataDir/Blockme" );
    $this->davcheck( !$dav->mkcol("Attest/Blockme"), $dav );
    $this->assert( !-d "$dataDir/Attest/Blockme" );
    $this->davcheck( !$dav->mkcol("Attest/Attest1/Blockme"), $dav );
    $this->assert( !-d "$dataDir/Attest/DavTest07/Blockme" );

    $dav = $this->davopen( 0, $davPubURL );
    $this->davcheck( !$dav->mkcol("Blockme"), $dav );
    $this->assert( !-d "$pubDir/Blockme" );
    $this->davcheck( !$dav->mkcol("Attest/Blockme"), $dav );
    $this->assert( !-d "$pubDir/Attest/Blockme" );
    $this->davcheck( !$dav->mkcol("Attest/Attest1/Blockme"), $dav );
    $this->assert( !-d "$pubDir/Attest/DavTest07/Blockme" );
}

sub test_copy {
    my $this = shift;

    my $t = $this->_createProtectedTopic( "Attest", "DavTest", 7, 0 );
    $this->saveattachment( 0, "Attest", $t, $testAttName );

    my $dav = $this->davopen( 0, $davPubURL );
    $this->davcheck(
        $dav->copy( "Attest/$t/$testAttName", "Attest/$t/LegalCopy.dat" ),
        $dav );
    $this->checkatt( 1, "Attest", $t, $testAttName );
    $this->checkatt( 1, "Attest", $t, "LegalCopy.dat" );

    $dav = $this->davopen( 1, $davPubURL );
    $this->davcheck(
        !$dav->copy( "Attest/$t/$testAttName", "Attest/$t/IllegalCopy.dat" ),
        $dav );
    $this->checkatt( 1, "Attest", $t, $testAttName );
    $this->checkatt( 0, "Attest", $t, "IllegalCopy.dat" );

    $t = $this->_createProtectedTopic( "Attest", "DavTest", 7, 4 );
    $this->saveattachment( 0, "Attest", $t, $testAttName );

    $dav = $this->davopen( 1, $davPubURL );
    $this->davcheck(
        !$dav->copy( "Attest/$t/$testAttName", "Attest/$t/IllegalCopy.dat" ),
        $dav );
    $this->checkatt( 1, "Attest", $t, $testAttName );
    $this->checkatt( 0, "Attest", $t, "IllegalCopy.dat" );

    # Copy topic is banned
    $dav = $this->davopen( 0, $davDataURL );
    $this->davcheck( !$dav->copy( "Attest/$t.txt", "Attest/SmeaGol.txt" ),
        $dav );
}

sub test_move {
    my $this = shift;

    my $t = $this->_createProtectedTopic( "Attest", "DavTest", 7, 4 );
    $this->saveattachment( 0, "Attest", $t, $testAttName );

    my $dav = $this->davopen( 0, $davPubURL );
    $this->davcheck( !$dav->move( "Attest/$t", "DavTest/SmeAgol" ), $dav );

    # move leaf access permitted within topic
    $this->davcheck(
        $dav->move( "Attest/$t/$testAttName", "Attest/$t/MarilynMonroe.dat" ),
        $dav );
    $this->checkatt( 0, "Attest", $t, $testAttName );
    $this->checkatt( 1, "Attest", $t, "MarilynMonroe.dat" );

    my $tt = $this->_createProtectedTopic( "Attest", "DavTest", 6, 7 );

    $this->saveattachment( 0, "Attest", $t, $testAttName );
    $dav = $this->davopen( 1, $davPubURL );
    $this->davcheck(
        !$dav->move( "Attest/$t/$testAttName", "Attest/$tt/MarilynMonroe.dat" ),
        $dav
    );

    # illegal to move topics
    $dav = $this->davopen( 0, $davDataURL );
    $this->davcheck( !$dav->move( "Attest/$t.txt", "Attest/SmeAgol.txt" ),
        $dav );

    # move attachment between topics
    $dav = $this->davopen( 0, $davPubURL );
    $this->saveattachment( 0, "Attest", $t, $testAttName );
    $this->davcheck(
        $dav->move( "Attest/$t/$testAttName", "Attest/$tt/$testAttName" ),
        $dav );
    $this->checkatt( 0, "Attest", $t,  $testAttName );
    $this->checkatt( 1, "Attest", $tt, $testAttName );

    # try and move it back - rename is denied
    $this->davcheck(
        !$dav->move( "Attest/$tt/$testAttName", "Attest/$t/$testAttName" ),
        $dav );

    # disallow moving to web level
    $this->davcheck(
        !$dav->move( "Attest/$t/$testAttName", "Attest/MarilynMonroe.dat" ),
        $dav );
}

# options that say what methods are available where
# test disabled because it really doesn't matter that it gives the
# wrong options.
sub DISABLEtest_options {
    my $this = shift;

    # root
    my $dav = $this->davopen( 0, $davPubURL );

    # attachment
    $this->checklist(
        $dav->options("Attest/DavTest70/Kitty.gif"),
        "OPTIONS,GET,DELETE,POST,COPY,MOVE,PROPFIND",
        "PROPPATCH,LOCK,UNLOCK"
    );

    # topic dir
    $this->checklist( $dav->options("Attest/DavTest70"),
        "OPTIONS,GET,PROPFIND,COPY", "PUT,MOVE,DELETE,PROPPATCH,LOCK,UNLOCK" );

    # web dir
    $this->checklist( $dav->options("Attest"),
        "OPTIONS,GET,PROPFIND,COPY", "PUT,MOVE,DELETE,PROPPATCH,LOCK,UNLOCK" );

    $this->checklist( $dav->options("."), "OPTIONS,GET,PROPFIND,COPY" );
}

sub test_recache_command_line {
    my $this = shift;

    # delete the db, regenerate it, create a topic with limitation,
    # recache, check the difference.
    $this->assert( -w $davLockPath,         "No permission to run this test" );
    $this->assert( -w "$davLockPath/TWiki", "No permission to run this test" );
    unlink("$davLockPath/TWiki");
    $this->assert( !$?, "Can't set up" );
    my $monitor = `$twikiBinDir/dav_recache$scriptSuffix`;
    $this->assert( !$?, "Can't run $twikiBinDir/dav_recache$scriptSuffix" );

    # Make sure it ran over all webs
    foreach my $web ( glob("$dataDir/*") ) {
        if ( -d $web ) {
            my @topics = glob("$web/*.txt");
            $web = `basename $web`;
            chop($web);
            $this->assert_matches( qr/(\d+)\b.*\b$web\b/, $monitor );
            $monitor =~ /(\d+)\b.*\b$web\b/;
            $this->assert( $1 <= scalar(@topics),
                "$web $1 " . scalar(@topics) );
        }
    }
    my $dump = `../dumpLockDB.pl $davLockPath`;
    $this->assert( !$?, "Can't dump" );
    my $du = $davUser[1]{wikiname};
    _saveTopic( 0, "Attest", "DavTest70",
            "\t* Set DENYTOPICVIEW = OakTree\n"
          . "\t* Set DENYTOPICCHANGE = AshTree\n" );
    unlink("$davLockPath/TWiki") || die "Failed";
    $this->assert( !$?, "Can't set_up" );
    $this->assert( !-e "$davLockPath/TWiki" );
    $monitor = `$twikiBinDir/dav_recache$scriptSuffix`;
    $this->assert( !$?, "Can't run" );
    $dump = `../dumpLockDB.pl $davLockPath`;
    $this->assert_does_not_match( qr/P:\/Attest\/DavTest70:V:D => \|$du\|/,
        $dump );
    $this->assert_does_not_match( qr/P:\/Attest\/DavTest70:C:D => \|$du\|/,
        $dump );
    $this->assert_matches( qr/P:\/Attest\/DavTest70:V:D => |OakTree|/, $dump );
    $this->assert_matches( qr/P:\/Attest\/DavTest70:C:D => |AshTree|/, $dump );

    $monitor = `$twikiBinDir/dav_recache$scriptSuffix Sandbox`;
    $this->assert_matches( qr/Processed \d+ topics from Sandbox\b/, $monitor );
    $monitor =~ s/Processed \d+ topics from Sandbox\b//;
    $this->assert_does_not_match( qr/Processed \d+ topics from \w+/, $monitor );

    $monitor = `$twikiBinDir/dav_recache$scriptSuffix Attest.DavTest70`;
    $this->assert_matches( qr/Processing topic Attest\.DavTest70\b/, $monitor );
    $monitor =~ s/Processing topic Attest\.DavTest70\b//;
    $this->assert_matches( qr/Processed 1 topics from Attest\b/, $monitor );
    $monitor =~ s/Processed \d+ topics from Attest\b//;
    $this->assert_does_not_match( qr/Processed \d+ topics from \w+/, $monitor );
}

sub test_recache_query {
    my $this = shift;
    $this->assert( -w $davLockPath,         "No permission to run this test" );
    $this->assert( -w "$davLockPath/TWiki", "No permission to run this test" );
    unlink("$davLockPath/TWiki") || die "Failed";
    my $monitor = `curl -s -S $binurl/dav_recache/$scriptSuffix`;
    $this->assert( !$?, "Can't run" );
    my $dump = `../dumpLockDB.pl $davLockPath`;
    $this->assert( !$?, "Can't dump" );
    my $du = $davUser[1]{wikiname};
    _saveTopic( 0, "Attest", "DavTest70",
            "\t* Set DENYTOPICVIEW = OakTree\n"
          . "\t* Set DENYTOPICCHANGE = AshTree\n" );
    unlink("$davLockPath/TWiki");
    $this->assert( !$?, "Can't set_up" );
    $monitor = `curl -s -S $binurl/dav_recache/$scriptSuffix`;
    $this->assert( !$?, "Can't run" );
    $dump = `../dumpLockDB.pl $davLockPath`;
    $this->assert_does_not_match( qr/P:\/Attest\/DavTest70:V:\w => \|$du\|/,
        $dump );
    $this->assert_does_not_match( qr/P:\/Attest\/DavTest70:C:\w => \|$du\|/,
        $dump );
    $this->assert_matches( qr/P:\/Attest\/DavTest70:V:D => \|OakTree\|/,
        $dump );
    $this->assert_matches( qr/P:\/Attest\/DavTest70:C:D => \|AshTree\|/,
        $dump );
}

1;
