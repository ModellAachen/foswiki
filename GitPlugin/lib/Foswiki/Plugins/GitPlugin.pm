#
# Copyright (C) 2010 Thomas Weigert, weigert@mst.edu
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the installation root.

package Foswiki::Plugins::GitPlugin;

use strict;
use Assert;
require Foswiki::Plugins::GitPlugin::GitRun;
require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version
require CGI;
use Foswiki::Meta;
use Foswiki::Merge;
use Foswiki::Sandbox;

use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC $SESSION);

$VERSION           = '$Rev$';
$RELEASE           = '1.0';
$SHORTDESCRIPTION  = 'Supports distributed Foswiki installations using Git.';
$NO_PREFS_IN_TOPIC = 1;
$pluginName        = 'GitPlugin';

my %onlyOnceHandlers = (
    registrationHandler           => 1,
    writeHeaderHandler            => 1,
    redirectCgiQueryHandler       => 1,
    renderFormFieldForEditHandler => 1,
    renderWikiWordHandler         => 1,
);

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    Foswiki::Func::registerTagHandler( 'GITMERGE', \&_GITMERGE );

    #Foswiki::Func::registerTagHandler( 'GITCONFIRM', \&_GITCONFIRM );

    # Plugin correctly initialized
    return 1;
}

sub _GITMERGE {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    # $session  - a reference to the session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a Foswiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the variable

    #used to store conflict decision information
    my @result_Info;

    #web display used
    my $totalInfo = '';

    #for future use
    #my $remoteName = $params->{"remote"};
    #my @remoteArray = split( /\s*\|\s*/, $remoteName );

    #get the remote site list using "git remote"
    my ( $gitOut, $exit, @configRemotes );
    if ( $Foswiki::cfg{Git}{mergeMode} eq "distributed" ) {
        $totalInfo .= '<strong>Work mode</strong>: Distributed<br><br>';
    }
    elsif ( $Foswiki::cfg{Git}{mergeMode} eq "centralized" ) {
        $totalInfo .= '<strong>Work mode</strong>: Centralized<br><br>';
        ( $gitOut, $exit ) = Foswiki::Plugins::GitPlugin::GitRun::render(
            $Foswiki::cfg{Git}{fetchCmd},
            SITENAME => $Foswiki::cfg{Git}{backupReposName} );
        $gitOut = "No more data.\n" if ( $gitOut eq '' );           #get nothing
        $gitOut = "<strong>get fetch result:</strong>\n" . $gitOut;
        $gitOut =~ s/\n/<br>/go;
        $totalInfo .= $gitOut . "<br>";
    }
    else {
        return "Incorrect mergeMode.";
    }

    # fetch remote sites' names, such as site1,site2...
    @configRemotes = split( /\s*,\s*/, $Foswiki::cfg{Git}{remoteName} );

    my $GitDataPath = $Foswiki::cfg{Git}{root} . '/' . "data";
    $totalInfo .=
"<strong>warning:</strong> Can not read $GitDataPath/data, when trying to rmove .changes files.<br>"
      unless ( opendir( my $GitDIR, $GitDataPath ) );

    # Remove .changes in webs, which are in git repository, to avoid
    # out-sync when other sites do 'rename/move web'.
    _rmChanges( $GitDataPath, $GitDIR );
    closedir($GitDIR);

    foreach my $location (@configRemotes) {
        $totalInfo .= "<strong>[$location]</strong><BR>";

        # git fetch $location, git merge
        if ( $Foswiki::cfg{Git}{mergeMode} eq "distributed" ) {
            ( $gitOut, $exit ) = Foswiki::Plugins::GitPlugin::GitRun::render(
                $Foswiki::cfg{Git}{fetchCmd},
                SITENAME => $location );
            $gitOut = "No more data.\n" if ( $gitOut eq '' );
            $gitOut = "<strong>get fetch result:</strong>\n" . $gitOut;
            $gitOut =~ s/\n/<br>/go;
            $totalInfo .= $gitOut . "<br>";
            ( $gitOut, $exit ) = Foswiki::Plugins::GitPlugin::GitRun::render(
                $Foswiki::cfg{Git}{mergeCmdDistributed},
                SITENAME => $location );
        }
        elsif ( $Foswiki::cfg{Git}{mergeMode} eq "centralized" ) {
            $location = $Foswiki::cfg{Git}{backupReposName} . "/" . $location;
            ( $gitOut, $exit ) = Foswiki::Plugins::GitPlugin::GitRun::render(
                $Foswiki::cfg{Git}{mergeCmdCentralized},
                SITENAME => $location );
        }
        my $mergeInfo = $gitOut;

        #git ls-files --unmerged, if no files are unmerged, success.
        ( $gitOut, $exit ) = Foswiki::Plugins::GitPlugin::GitRun::render(
            $Foswiki::cfg{Git}{unmergeListCmd},
            SITENAME => $location );

        if ( $gitOut eq '' ) {
            $mergeInfo = "<strong>git merge result:</strong>\n" . $mergeInfo;
            $mergeInfo =~ s/\n/<br>/go;
            $totalInfo .= $mergeInfo . "<BR><BR>";
            next;
        }

#100755 44d9e312c687fbc3830b0caa9eb9386c7d210d27 1       data/Sandbox/TtA.txt
#100755 07773841434341cb353e2f512a2ef795f88f0fcf 2       data/Sandbox/TtA.txt
#100755 36a385828d687604594d3212db5eb432df9cbca2 3       data/Sandbox/TtA.txt
#100755 e9fec6f3cddec3bf203b6139042c2546a1439c60 2       pub/Sandbox/TtA/ICW.png
#100755 d204909212e393058f022f5ea83b5a9c8bda0c91 3       pub/Sandbox/TtA/ICW.png

        #resolve conficts
        my @conflictInfo = split( /\s+/, $gitOut );

        foreach (@conflictInfo) {
            _handleString($_);
        }

        my @sortedInfo;

        for ( my $i = 0 ; $i < $#conflictInfo + 1 ; $i += 4 ) {
            push(
                @sortedInfo,
                [
                    $conflictInfo[$i],
                    $conflictInfo[ $i + 1 ],
                    $conflictInfo[ $i + 2 ],
                    $conflictInfo[ $i + 3 ]
                ]
            );
        }

        #data/*/*.txt of topic, content of topic
        my %conflictTxt;

        #pub/* of attachment, include text files which act as the attachments.
        my %conflictBin;
        my %conflictFiles;

        for ( my $i = 0 ; $i < $#sortedInfo + 1 ; ++$i ) {

            if ( $sortedInfo[$i]->[3] =~ m#^data/.*\.txt$# ) {
                unless ( defined $conflictTxt{ $sortedInfo[$i]->[3] } ) {
                    $conflictTxt{ $sortedInfo[$i]->[3] } = {};
                }
                $conflictTxt{ $sortedInfo[$i]->[3] }->{ $sortedInfo[$i]->[2] } =
                  $sortedInfo[$i]->[1];
            }
            elsif ( $sortedInfo[$i]->[3] =~ m#^pub/.*# ) {
                unless ( defined $conflictBin{ $sortedInfo[$i]->[3] } ) {
                    $conflictBin{ $sortedInfo[$i]->[3] } = {};
                }
                $conflictBin{ $sortedInfo[$i]->[3] }->{ $sortedInfo[$i]->[2] } =
                  $sortedInfo[$i]->[1];
            }
            else {

                #just to be on the safe side, should never be here
                unless ( defined $conflictFiles{ $sortedInfo[$i]->[3] } ) {
                    $conflictFiles{ $sortedInfo[$i]->[3] } = {};
                }
                $conflictFiles{ $sortedInfo[$i]->[3] }
                  ->{ $sortedInfo[$i]->[2] } = $sortedInfo[$i]->[1];
            }
        }

#first, resolve the topic text, and merge the meta-data,
#after choose the suitable %ATTACHMENTS{}%, pick up the corresponding attachment
        foreach my $curFile ( sort keys %conflictTxt ) {
            my ( $web, $topic );
            my ( $ancestorFile, $headFile, $mergeheadFile );

            if ( $curFile =~ m#^data/(.*)/(\w*)\.txt$# ) {
                ( $web, $topic ) = ( $1, $2 );
            }

            if ( defined( $conflictTxt{$curFile}->{1} ) ) {
                ( $gitOut, $exit ) =
                  Foswiki::Plugins::GitPlugin::GitRun::render(
                    $Foswiki::cfg{Git}{showAncestorConfictCmd},
                    FILENAME => $curFile );
                $ancestorFile = $gitOut;
            }

            if ( defined( $conflictTxt{$curFile}->{2} ) ) {
                ( $gitOut, $exit ) =
                  Foswiki::Plugins::GitPlugin::GitRun::render(
                    $Foswiki::cfg{Git}{showHEADConfictCmd},
                    FILENAME => $curFile );
                $headFile = $gitOut;
            }

            if ( defined( $conflictTxt{$curFile}->{3} ) ) {
                ( $gitOut, $exit ) =
                  Foswiki::Plugins::GitPlugin::GitRun::render(
                    $Foswiki::cfg{Git}{showMERGE_HEADConfictCmd},
                    FILENAME => $curFile );
                $mergeheadFile = $gitOut;
            }

            if ( defined $headFile and defined $mergeheadFile ) {
                my ( $aMeta, $aText ) = ( undef, "" );
                my ( $bMeta, $bText ) =
                  _readTopicFromTopicRaw( $session, $web, $topic, $headFile );
                my ( $cMeta, $cText ) =
                  _readTopicFromTopicRaw( $session, $web, $topic,
                    $mergeheadFile );

                if ( defined $ancestorFile ) {
                    ( $aMeta, $aText ) =
                      _readTopicFromTopicRaw( $session, $web, $topic,
                        $ancestorFile );
                }

                $aText =~ s#^%GITCONFIRM{}%##;
                $bText =~ s#^%GITCONFIRM{}%##;
                $cText =~ s#^%GITCONFIRM{}%##;

                my $resolvedText = _merge(
                    "Ancestor",  $aText, "Local",  $bText,
                    "$location", $cText, ".*?\\n", $session
                );

#my $resolvedText = Foswiki::Merge::merge3("Ancestor", $aText, "Local", $bText, "$location", $cText, ".*?\\n", $session);

                my ( $resolvedMeta, @attachment_Info ) =
                  _mergeMeta( $bMeta, $cMeta, $web, $topic, \%conflictBin,
                    $location );

                #collect conflict decision information
                my $topicName = $web . '/' . $topic;
                my $flage     = 0;
                my @topic_Info;

                foreach my $topicT (@result_Info) {
                    if ( $topicT->[0] eq $topicName ) {
                        $topicT->[2] .= '.' . $location;
                        $flage = 1;
                    }
                }

                if ( $flage == 0 ) {
                    $topic_Info[0] = $topicName;
                    $topic_Info[2] = $location;
                    $topic_Info[1] = $bMeta->get('TOPICINFO')->{author};
                }

                push( @topic_Info,  @attachment_Info );
                push( @result_Info, \@topic_Info );

                #warning user to confirm the conflict
                $resolvedText = qq#%GITCONFIRM{}%\n# . $resolvedText;

#can't force new revision here to store topic before merge because commit one file must after commit merge
                Foswiki::Func::saveTopic( $web, $topic, $resolvedMeta,
                    $resolvedText );

                $web =~ s#/#\.#go;
                $totalInfo .=
                  "Please check merged file: $web.$topic in !$web<BR>";
            }
            elsif (
                (
                        defined $headFile
                    and ( not defined $mergeheadFile )
                    and ( not defined $ancestorFile )
                )
                or (    defined $mergeheadFile
                    and ( not defined $headFile )
                    and ( not defined $ancestorFile ) )
              )
            {

                #the file was moved to here
                my ( $Meta, $Text );
                if ( defined $headFile ) {
                    ( $Meta, $Text ) =
                      _readTopicFromTopicRaw( $session, $web, $topic,
                        $headFile );
                }
                elsif ( defined $mergeheadFile ) {
                    ( $Meta, $Text ) =
                      _readTopicFromTopicRaw( $session, $web, $topic,
                        $mergeheadFile );
                }

                if ( scalar $Meta->find('FILEATTACHMENT') > 0 ) {
                    my @tmpArray = $Meta->find('FILEATTACHMENT');
                    foreach my $attName (@tmpArray) {
                        my $attachPath =
                            "pub/" . "$web" . "/" 
                          . "$topic" . "/"
                          . $attName->{name};
                        ( $gitOut, $exit ) =
                          Foswiki::Plugins::GitPlugin::GitRun::render(
                            $Foswiki::cfg{Git}{initCmd},
                            FILENAME => $attachPath
                          );
                        delete $conflictBin{"$attachPath"};
                    }
                }
                ( $gitOut, $exit ) =
                  Foswiki::Plugins::GitPlugin::GitRun::render(
                    $Foswiki::cfg{Git}{initCmd},
                    FILENAME => $curFile );
            }
            elsif ( defined $ancestorFile
                and ( not defined $mergeheadFile )
                and ( not defined $headFile ) )
            {

                #the file was removed/deleted in both sides
                my ( $Meta, $Text ) =
                  _readTopicFromTopicRaw( $session, $web, $topic,
                    $ancestorFile );
                if ( scalar $Meta->find('FILEATTACHMENT') > 0 ) {
                    my @tmpArray = $Meta->find('FILEATTACHMENT');
                    foreach my $attName (@tmpArray) {
                        my $attachPath =
                            "pub/" . "$web" . "/" 
                          . "$topic" . "/"
                          . $attName->{name};
                        ( $gitOut, $exit ) =
                          Foswiki::Plugins::GitPlugin::GitRun::render(
                            $Foswiki::cfg{Git}{removeCmd},
                            FILENAME => $attachPath
                          );
                        delete $conflictBin{"$attachPath"};
                    }
                }

                ( $gitOut, $exit ) =
                  Foswiki::Plugins::GitPlugin::GitRun::render(
                    $Foswiki::cfg{Git}{removeCmd},
                    FILENAME => $curFile );
            }
            else {

                #should never get here
                ( $gitOut, $exit ) =
                  Foswiki::Plugins::GitPlugin::GitRun::render(
                    $Foswiki::cfg{Git}{removeCmd},
                    FILENAME => $curFile );
            }
        }

        foreach my $curFile ( sort keys %conflictBin ) {

            #should never get here
            ( $gitOut, $exit ) = Foswiki::Plugins::GitPlugin::GitRun::render(
                $Foswiki::cfg{Git}{removeCmd},
                FILENAME => $curFile );
        }

        foreach my $curFile ( sort keys %conflictFiles ) {

            #should never get here
            ( $gitOut, $exit ) = Foswiki::Plugins::GitPlugin::GitRun::render(
                $Foswiki::cfg{Git}{removeCmd},
                FILENAME => $curFile );
        }

        ( $gitOut, $exit ) = Foswiki::Plugins::GitPlugin::GitRun::render(
            $Foswiki::cfg{Git}{mergeConfictCmd} );

#To confirm the merge result, we do "git merge" again, and give this information to user
        if ( $Foswiki::cfg{Git}{mergeMode} eq "distributed" ) {
            ( $gitOut, $exit ) = Foswiki::Plugins::GitPlugin::GitRun::render(
                $Foswiki::cfg{Git}{mergeCmdDistributed},
                SITENAME => $location );
        }
        elsif ( $Foswiki::cfg{Git}{mergeMode} eq "centralized" ) {
            ( $gitOut, $exit ) = Foswiki::Plugins::GitPlugin::GitRun::render(
                $Foswiki::cfg{Git}{mergeCmdCentralized},
                SITENAME => $location );
        }
        $gitOut =~ s/\n/<br><br>/go;
        $totalInfo .= $gitOut;
    }

    #maintain soft link if Foswiki is in independent Git directory structure.
    my $maintainInfo = _maintainSLn();
    $totalInfo .= $maintainInfo if defined $maintainInfo;

#refresh files data/webname/.changes from "git log", when finished merge other sites
    my $changeInfo = _changeForm();
    $totalInfo .= $changeInfo if defined $changeInfo;

    #"git status"
    $totalInfo .=
"<strong>Please check information below, any problem you met, solve them using command line.</strong><BR><BR>";

    ( $gitOut, $exit ) = Foswiki::Plugins::GitPlugin::GitRun::render(
        $Foswiki::cfg{Git}{statusCmd} );
    $gitOut =~ s/\n/<br>/go;
    $totalInfo .= $gitOut;

    if ( $Foswiki::cfg{Git}{mergeMode} eq "centralized" ) {
        ( $gitOut, $exit ) = Foswiki::Plugins::GitPlugin::GitRun::render(
            $Foswiki::cfg{Git}{pushCmd},
            REPOSNAME => $Foswiki::cfg{Git}{backupReposName},
            LOCALNAME => $Foswiki::cfg{Git}{LocalName}
        );
    }

    #All conflicting topic info
    #foreach my $topic (@result_Info) {
    #	Foswiki::Func::writeDebug("Topic Name:".$topic->[0]);
    #	Foswiki::Func::writeDebug("Author Name:".$topic->[1]);
    #	Foswiki::Func::writeDebug("Confliction Site:".$topic->[2]);
    #
    #	for (my $i=3; $i<$#$topic+1; $i+=3) {
    #		Foswiki::Func::writeDebug("Attachment Name:".$topic->[$i]);
    #		Foswiki::Func::writeDebug("Result Site:".$topic->[$i+1]);
    #		Foswiki::Func::writeDebug("Operation:".$topic->[$i+2]);
    #	}
    #}

    return $totalInfo;

}

sub _readTopicFromTopicRaw {
    my ( $session, $web, $topic, $rawText ) = @_;

    my $meta = new Foswiki::Meta( $session, $web, $topic, $rawText );

    return ( $meta, $meta->text() );
}

sub _handleString {
    $_[0] =~ m#\s*(.*)\s*#;
    $_[0] = $1;

}

sub _mergeMeta {
    my ( $bMeta, $cMeta, $web, $topic, $refBin, $location ) = @_;

    # 1:ancestor, 2:head(local), 3:merge-head(remote)
    my $baseVersion = 2;
    my @attachmentTmp;

#pick %META:TOPICINFO{}%, %META:TOPICPARENT{}%, %META:FORM{}%, %META:FIELD{}%, latest win
    if ( $bMeta->get('TOPICINFO')->{date} < $cMeta->get('TOPICINFO')->{date} ) {
        ( $bMeta, $cMeta ) = ( $cMeta, $bMeta );
        $baseVersion = 3;
    }

#%META:PREFERENCE{name="ALLOWTOPICVIEW" title="ALLOWTOPICVIEW" type="Set" value="CapcGroup, ProcessGroup"}%
#%META:PREFERENCE{name="ALLOWTOPICHANGE" title="ALLOWTOPICHANGE" type="Set" value="CapcGroup"}%
#%META:TOPICINFO
#%META:TOPICPARENT

    #pick %META:TOPICMOVED{}%
    if (    defined $bMeta->get('TOPICMOVED')
        and defined $cMeta->get('TOPICMOVED') )
    {

        #latest win
        if ( $bMeta->get('TOPICMOVED')->{date} <
            $cMeta->get('TOPICMOVED')->{date} )
        {
            $bMeta->putKeyed( 'TOPICMOVED', $cMeta->find('TOPICMOVED') );
        }
    }
    elsif ( defined $cMeta->get('TOPICMOVED') ) {

        #combine
        $bMeta->putKeyed( 'TOPICMOVED', $cMeta->find('TOPICMOVED') );
    }

    # pick %META: FILEATTACHMENT{}%
    my $flagMatched;
    if (   scalar $bMeta->find('FILEATTACHMENT') > 0
        or scalar $cMeta->find('FILEATTACHMENT') > 0 )
    {
        my @tmpArrayB = $bMeta->find('FILEATTACHMENT');
        my @tmpArrayC = $cMeta->find('FILEATTACHMENT');

        foreach my $cAttachment (@tmpArrayC) {
            $flagMatched = 0;    #unmatched
            my $pickupVersion;

            foreach my $bAttachment (@tmpArrayB) {
                if ( $bAttachment->{name} eq $cAttachment->{name} ) {
                    my $flag = 0;
                    if ( $bAttachment->{date} == $cAttachment->{date} ) {
                        $flag = 1;
                    }

                    if ( $bAttachment->{date} < $cAttachment->{date} ) {

                        #pick up latest one
                        $bMeta->putKeyed( 'FILEATTACHMENT', $cAttachment );
                        $pickupVersion =
                          ( ( 0x1 xor( $baseVersion - 2 ) ) + 2 )
                          ;    #convert 2<-->3
                    }
                    else {
                        $pickupVersion = $baseVersion;
                    }

                    #collect attachment conflict decision information
                    push( @attachmentTmp, $bAttachment->{name} );
                    if ( $flag == 1 ) {
                        push( @attachmentTmp, 'local' );
                        push( @attachmentTmp, 'none' );
                    }
                    elsif ( $pickupVersion == 2 ) {
                        push( @attachmentTmp, 'local' );
                        push( @attachmentTmp, 'modify' );
                    }
                    else {
                        push( @attachmentTmp, $location );
                        push( @attachmentTmp, 'modify' );
                    }

                    _mergeAttachment( $web, $topic, $bAttachment->{name},
                        $pickupVersion, $refBin );
                    $flagMatched = 1;    #matched
                    last;
                }
            }

            if ( $flagMatched == 0 ) {

                #the attachment will be merged by Git automatically
                #collect attachment conflict decision information
                push( @attachmentTmp, $cAttachment->{name} );
                if ( $baseVersion == 3 ) {
                    push( @attachmentTmp, 'local' );
                    push( @attachmentTmp, 'none' );
                }
                else {
                    push( @attachmentTmp, $location );
                    push( @attachmentTmp, 'add' );
                }
                $bMeta->putKeyed( 'FILEATTACHMENT', $cAttachment );    #combine
            }
        }

        #collect attachment conflict decision information
        foreach my $bAttachment (@tmpArrayB) {
            my $flag = 0;
            for ( my $i = 0 ; $i < $#attachmentTmp + 1 ; $i += 3 ) {
                if ( $bAttachment->{name} eq $attachmentTmp[$i] ) {
                    $flag = 1;
                }
            }
            if ( $flag == 0 ) {
                push( @attachmentTmp, $bAttachment->{name} );
                if ( $baseVersion == 2 ) {
                    push( @attachmentTmp, 'local' );
                    push( @attachmentTmp, 'none' );
                }
                else {
                    push( @attachmentTmp, $location );
                    push( @attachmentTmp, 'add' );
                }
            }
        }
    }

    #check and keep alignment
    if ( scalar $bMeta->find('FILEATTACHMENT') > 0 ) {
        my @tmpArrayB = $bMeta->find('FILEATTACHMENT');
        foreach my $bAttachment (@tmpArrayB) {
            my $attachmentName = $bAttachment->{name};
            my $attachPath =
              $Foswiki::cfg{PubDir} . "/$web/$topic/$attachmentName";
            unless ( -e $attachPath ) {
                for ( my $i = 0 ; $i < $#attachmentTmp + 1 ; $i += 3 ) {
                    if ( $attachmentTmp[$i] eq $bAttachment->{name} ) {
                        $attachmentTmp[ $i + 2 ] = 'delete';
                    }
                }
                $bMeta->remove( 'FILEATTACHMENT', $attachmentName );
            }

            unlink "$attachPath" . "~HEAD";
            if ( $Foswiki::cfg{Git}{mergeMode} eq 'distributed' ) {
                unlink "$attachPath" . "~" . "$location" . "_master";
            }
            elsif ( $Foswiki::cfg{Git}{mergeMode} eq 'centralized' ) {
                my $temp = $location;
                $temp =~ s/\//_/;
                unlink "$attachPath" . "~" . $temp;
            }
        }
    }

    #       data/Sandbox/TestTopic002.txt~HEAD
    #       data/Sandbox/TestTopic002.txt~cn_master
    #       pub/Sandbox/TestTopic002/11.jpg~HEAD
    #       pub/Sandbox/TestTopic002/11.jpg~cn_master

    my $topicPath =
      $Foswiki::cfg{Git}{root} . '/' . "data" . "/$web/$topic" . ".txt";

    #unlink glob * was forbidden
    unlink "$topicPath" . "~HEAD";
    if ( $Foswiki::cfg{Git}{mergeMode} eq 'distributed' ) {
        unlink "$topicPath" . "~" . "$location" . "_master";
    }
    elsif ( $Foswiki::cfg{Git}{mergeMode} eq 'centralized' ) {
        my $temp = $location;
        $temp =~ s/\//_/;
        unlink "$topicPath" . "~" . $temp;
    }

    return $bMeta, @attachmentTmp;
}

sub _mergeAttachment {
    my ( $web, $topic, $attachmentName, $pickupVersion, $refBin ) = @_;

    my $attachPath = "pub/$web/$topic/$attachmentName";

#Foswiki::Func::writeDebug("mergeatt Path:".$attachPath."==pickupVersion==". $pickupVersion);

    if ( defined $refBin->{"$attachPath"}
        and ( my $sh1 = $refBin->{"$attachPath"}{$pickupVersion} ) )
    {
        my ( $gitOut, $exit ) = Foswiki::Plugins::GitPlugin::GitRun::render(
            $Foswiki::cfg{Git}{readFileCmd},
            SHA1 => $sh1 );

        my $tmpPath =
            $Foswiki::cfg{PubDir} . '/' 
          . $web . '/' 
          . $topic . '/'
          . $attachmentName;
        if ( open( HANDLE, '>', "$tmpPath" ) ) {
            print HANDLE $gitOut;
        }

        ( $gitOut, $exit ) = Foswiki::Plugins::GitPlugin::GitRun::render(
            $Foswiki::cfg{Git}{initCmd},
            FILENAME => $attachPath );

        delete $refBin->{"$attachPath"};

        return;
    }
}

#this function is copied form Foswiki::Merge::merge3
sub _merge {
    my ( $arev, $ia, $brev, $ib, $crev, $ic, $sep, $session, $info ) = @_;

    $sep = "\r?\n" if ( !defined($sep) );

    my @a = split( /(.+?$sep)/, $ia );
    my @b = split( /(.+?$sep)/, $ib );
    my @c = split( /(.+?$sep)/, $ic );
    require Algorithm::Diff;
    my @bdiffs = Algorithm::Diff::sdiff( \@a, \@b );
    my @cdiffs = Algorithm::Diff::sdiff( \@a, \@c );

    my $ai   = 0;                 # index into a
    my $bdi  = 0;                 # index into bdiffs
    my $cdi  = 0;                 # index into bdiffs
    my $na   = scalar(@a);
    my $nbd  = scalar(@bdiffs);
    my $ncd  = scalar(@cdiffs);
    my $done = 0;
    my ( @achunk, @bchunk, @cchunk );
    my @diffs;                    # (a, b, c)

    # diffs are of the form [ [ modifier, b_elem, c_elem ] ... ]
    # where modifiers is one of:
    #   '+': element (b or c) added
    #   '-': element (from a) removed
    #   'u': element unmodified
    #   'c': element changed (a to b/c)

    # first, collate the diffs.

    while ( !$done ) {
        my $bop = ( $bdi < $nbd ) ? $bdiffs[$bdi][0] : 'x';
        if ( $bop eq '+' ) {
            push @bchunk, $bdiffs[ $bdi++ ][2];
            next;
        }
        my $cop = ( $cdi < $ncd ) ? $cdiffs[$cdi][0] : 'x';
        if ( $cop eq '+' ) {
            push @cchunk, $cdiffs[ $cdi++ ][2];
            next;
        }
        while ( scalar(@bchunk) || scalar(@cchunk) ) {
            push @diffs, [ shift @achunk, shift @bchunk, shift @cchunk ];
        }
        if ( scalar(@achunk) ) {
            @achunk = ();
        }

        last if ( $bop eq 'x' || $cop eq 'x' );

        # now that we've dealt with '+' and 'x', the only remaining
        # operations are '-', 'u', and 'c', which all consume an
        # element of a, so we should increment them together.
        my $aline = $bdiffs[$bdi][1];
        my $bline = $bdiffs[$bdi][2];
        my $cline = $cdiffs[$cdi][2];
        push @diffs, [ $aline, $bline, $cline ];
        $bdi++;
        $cdi++;
    }

    # at this point, both lists should be consumed, unless theres a bug in
    # Algorithm::Diff. We'll consume whatevers left if necessary though.

    while ( $bdi < $nbd ) {
        push @diffs, [ $bdiffs[$bdi][1], undef, $bdiffs[$bdi][2] ];
        $bdi++;
    }
    while ( $cdi < $ncd ) {
        push @diffs, [ $cdiffs[$cdi][1], undef, $cdiffs[$cdi][2] ];
        $cdi++;
    }

    my ( @aconf, @bconf, @cconf, @merged );
    my $conflict = 0;
    my @out;
    my ( $aline, $bline, $cline );

    for my $diff (@diffs) {
        ( $aline, $bline, $cline ) = @$diff;
        my $ab = _equal( $aline, $bline );
        my $ac = _equal( $aline, $cline );
        my $bc = _equal( $bline, $cline );
        my $dline = undef;

        if ($bc) {

            # same change (or no change) in b and c
            $dline = $bline;
        }
        elsif ($ab) {

            # line did not change in b
            $dline = $cline;
        }
        elsif ($ac) {

            # line did not change in c
            $dline = $bline;
        }
        else {

            # line changed in both b and c
            $conflict = 1;
        }

        if ($conflict) {

            # store up conflicting lines until we get a non-conflicting
            push @aconf, $aline;
            push @bconf, $bline;
            push @cconf, $cline;
        }

        if ( defined($dline) ) {

            # we have a non-conflicting line
            if ($conflict) {

                # flush any pending conflict if there is enough
                # context (at least 3 lines)
                push( @merged, $dline );
                if ( @merged > 3 ) {
                    for my $i ( 0 .. $#merged ) {
                        pop @aconf;
                        pop @bconf;
                        pop @cconf;
                    }
                    _handleConflict(
                        \@out, \@aconf, \@bconf, \@cconf,  $arev,
                        $brev, $crev,   $sep,    $session, $info
                    );
                    $conflict = 0;
                    push @out, @merged;
                    @merged = ();
                }
            }
            else {

                # the line is non-conflicting
                my $merged =
                  dispatch( $session, 'mergeHandler', ' ', $dline, $dline,
                    $info );
                if ( defined $merged ) {
                    push( @out, $merged );
                }
                else {
                    push( @out, $dline );
                }
            }
        }
        elsif (@merged) {
            @merged = ();
        }
    }

    if ($conflict) {
        for my $i ( 0 .. $#merged ) {
            pop @aconf;
            pop @bconf;
            pop @cconf;
        }

        _handleConflict(
            \@out, \@aconf, \@bconf, \@cconf,  $arev,
            $brev, $crev,   $sep,    $session, $info
        );
    }
    push @out, @merged;
    @merged = ();

    #foreach ( @out ) { print STDERR (defined($_) ? $_ : "undefined") . "\n"; }

    return join( '', @out );
}

my $conflictAttrs = { class => 'foswikiConflict' };

# SMELL: internationalisation?
my $conflictB = CGI::b('CONFLICT');

# Below use %GITOPTION% instead of text
sub _handleConflict {
    my (
        $out,  $aconf, $bconf, $cconf,   $arev,
        $brev, $crev,  $sep,   $session, $info
    ) = @_;
    my ( @a, @b, @c );

    @a = grep( $_, @$aconf );
    @b = grep( $_, @$bconf );
    @c = grep( $_, @$cconf );
    my $merged = dispatch(
        $session, 'mergeHandler', 'c',
        join( '', @b ),
        join( '', @c ), $info
    );
    if ( defined $merged ) {
        push( @$out, $merged );
    }
    else {
        push( @$out, "%GITOPTION{\"START\"}%" . "\n" );
        if (@a) {

       #            push( @$out, CGI::div( $conflictAttrs,
       #                                   "$conflictB original $arev:" )."\n");
            push( @$out, "%GITOPTION{\"$arev\"}%" . "\n" );
            push( @$out, @a );
        }
        if (@b) {

       #            push( @$out, CGI::div( $conflictAttrs,,
       #                                   "$conflictB version $brev:"."\n" ) );
            push( @$out, "%GITOPTION{\"$brev\"}%" . "\n" );
            push( @$out, @b );
        }
        if (@c) {

       #            push( @$out, CGI::div( $conflictAttrs,,
       #                                   "$conflictB version $crev:"."\n" ) );
            push( @$out, "%GITOPTION{\"$crev\"}%" . "\n" );
            push( @$out, @c );
        }

        #        push( @$out, CGI::div( $conflictAttrs,,
        #                               "$conflictB end" )."\n");
        push( @$out, "%GITOPTION{\"END\"}%" . "\n" );
    }
}

sub _equal {
    my ( $a, $b ) = @_;
    return 1 if ( !defined($a) && !defined($b) );
    return 0 if ( !defined($a) || !defined($b) );
    return $a eq $b;
}

sub dispatch {

    # must be shifted to clear parameter vector
    my $this        = shift;
    my $handlerName = shift;
    foreach my $plugin ( @{ $this->{registeredHandlers}{$handlerName} } ) {

        # Set the value of $SESSION for this call stack
        local $SESSION = $this->{session};

        # apply handler on the remaining list of args
        no strict 'refs';
        my $status = $plugin->invoke( $handlerName, @_ );
        use strict 'refs';
        if ( $status && $onlyOnceHandlers{$handlerName} ) {
            return $status;
        }
    }
    return undef;
}

sub preRenderingHandler {

    #my ( $text ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    &Foswiki::Func::writeDebug("- $pluginName::preRenderingHandler") if $debug;

    # Only bother with this plugin if viewing (i.e. not searching, etc)
    return unless ( $0 =~ m/view|viewauth|render/o );

    my $cnt = 0;
    $_[0] =~ s/%GITCONFIRM(?:{(.*?)})?%/&handleGitConfirm($cnt++, $1)/geo;
    $cnt = 0;
    $_[0] =~ s/%GITOPTION{(.*?)}%/&handleGitOption($cnt++, $1)/geo;
}

sub handleGitConfirm {
    require Foswiki::Plugins::GitPlugin::GitAction;
    return Foswiki::Plugins::GitPlugin::GitAction::handleGitConfirm(@_);
}

sub handleGitOption {
    require Foswiki::Plugins::GitPlugin::GitAction;
    return Foswiki::Plugins::GitPlugin::GitAction::handleGitOption(@_);
}

sub _changeForm {

    # git log --since="276000 seconds ago", get git log info.

#commit 6583b85c1b9beed1fa4d97665dcd2b352299f2f5
#Author: Apache <apache@rat060.hengsoftware.cn>
#Date:   Tue Jul 20 09:19:00 2010 +0800
#    TW_Version:5        TW_Author:BaseUserMapping_333   TW_Path:data/Sandbox/TestTopic003.txt   TW_Comment:     TW_Date:1279588740

#commit 10c7d411139ebe70ada78ead85d533d3b6df81d4
#Author: Apache <apache@rat060.hengsoftware.cn>
#Date:   Tue Jul 20 09:18:59 2010 +0800
#    TW_Version:4        TW_Author:BaseUserMapping_333   TW_Path:data/Sandbox/TestTopic003.txt   TW_Comment:     TW_Date:1279588739

    #commit 84ab059fa4f7573f9e6c705c06de9139e8b1b740
    #Merge: 6ad4fd0 bd145a0
    #Author: Apache <apache@rat060.hengsoftware.cn>
    #Date:   Tue Jul 20 09:18:55 2010 +0800
    #    merge

    my ( $gitOut, $exit ) =
      Foswiki::Plugins::GitPlugin::GitRun::render( $Foswiki::cfg{Git}{logCmd},
        TIME => $Foswiki::cfg{Store}{RememberChangesFor} );
    my %webChange;

    if ( !$exit && $gitOut ) {
        my @commitsArray = split /commit/, $gitOut;

        # pick up webName, topicName, author, date, version.
        foreach my $commit (@commitsArray) {
            my ( $webName, @changeInfo ) = _getChangeInfo($commit);
            next unless defined $webName;

            if ( defined $webChange{$webName} ) {
                push @{ $webChange{$webName} }, \@changeInfo;
            }
            else {
                my @webChange;
                push @webChange, \@changeInfo;
                $webChange{$webName} = \@webChange;
            }
        }

        # write change infomation into each web's .change file.
        foreach my $webName ( keys %webChange ) {
            my $path = $Foswiki::cfg{Git}{root} . '/' . 'data' . '/' . $webName;
            next unless ( -e $path );
            $path .= '/.changes';

            if ( open( HANDLE, '>', "$path" ) ) {
                foreach my $info ( @{ $webChange{$webName} } ) {
                    foreach my $change (@$info) {
                        print HANDLE "$change\t";
                    }
                    print HANDLE "\n";
                }
                close(HANDLE);
            }
            else {
                return
                  "<strong>warning:</strong> can not wirte $path file.<br>";
            }
        }
        return;
    }
    return
"<strong>warning:</strong> can't get repository's log infomation. It failed when try to run 'git log'.";
}

sub _getChangeInfo {
    my ($commit) = @_;
    my ( $version, $author, $path, $topic, $date, $webName );

    if ( $commit =~
m/\s(.*?)\s(.*?)TW_Version:([0-9]*)\s(.*?)TW_Author:([0-9a-zA-Z_]*)\s(.*?)TW_Path:(.*?)\s(.*?)TW_Comment:(.*?)\s(.*?)TW_Date:(.*?)\s/s
      )
    {
        ( $version, $author, $path, $date ) = ( $3, $5, $7, $11 );
    }

    if ( defined $path and $path =~ m#^data/(.*)/(.*)\.txt$# ) {
        $topic   = $2;
        $webName = $1;
    }
    else {
        return;
    }

    $author = $Foswiki::Plugins::SESSION->{users}->getWikiName($author);

    return $webName, ( $topic, $author, $date, $version );
}

#####To maintain the soft link
sub _maintainSLn {
    _replaceLink('Data');
    _replaceLink('Pub');
}

sub _replaceLink {
    my $directory = shift;
    my $little    = $directory;
    $little =~ s/(.*)/\L$1/;    #Data->data   Pub->pub
    $directory .= 'Dir';

    my $FoswikiPath = $Foswiki::cfg{$directory};
    $FoswikiPath =~ s/\/[^\/]*$//;
    my $GitPath = $Foswiki::cfg{Git}{root};
    $GitPath =~ s/\/$//;

    return if ( $FoswikiPath eq $GitPath );

    my ( $GitDIR, $FoswikiDIR );
    return "<strong>warning:</strong> Can not read $GitPath/$little.<br>"
      unless ( opendir( $GitDIR, $GitPath . '/' . $little ) );
    return
      "<strong>warning:</strong> Can not read $Foswiki::cfg{$directory}.<br>"
      unless ( opendir( $FoswikiDIR, $Foswiki::cfg{$directory} ) );

    my %gitWebs;
    foreach my $gitWeb ( grep { !/^\.+$/ } readdir $GitDIR ) {
        $gitWebs{$gitWeb} = 1;
    }
    closedir($GitDIR);

    foreach my $softLnFile ( grep { !/^\.+$/ } readdir $FoswikiDIR ) {
        $softLnFile =~ /^(.*)$/;
        my $softLn = $Foswiki::cfg{$directory} . '/' . $1;
        next unless ( -l $softLn );
        my $link = readlink "$softLn";
        next
          unless ( $link =~ m#$GitPath/$little# )
          ;  #skip the soft link that does not point to <Gitroot> /date or /pub.

        unless ( -e $link ) {

            #remove the invalid soft link.
            unlink "$softLn";
            next;
        }

        delete $gitWebs{$softLnFile};    #The link already existed.
    }
    closedir($FoswikiDIR);

    foreach my $web ( keys %gitWebs ) {
        my $target = $GitPath . '/' . $little . '/' . $web;
        my $source = $Foswiki::cfg{$directory} . '/' . $web;
        $source .= 'Link' if ( -e $source );    #It should never been true;
        symlink $target, $source;
    }
}

sub _rmChanges {
    my ( $path, $DIR ) = @_;
    foreach my $file ( grep { !/^\.+$/ } readdir $DIR ) {
        $file =~ /^(.*)$/;
        my @localWeb = split( /\s*,\s*/, $Foswiki::cfg{Git}{outSync} );

        my $local = 0;
        foreach my $localWeb (@localWeb) {
            $local = 1 if ( $localWeb eq $file );
        }
        next if ($local);

        my $filePath = $path . '/' . $1;
        if ( -d $filePath ) {
            return "<strong>warning:</strong> Can not read $filePath.<br>"
              unless ( opendir( my $FileDIR, $filePath ) );
            _rmChanges( $filePath, $FileDIR );
            closedir($FileDIR);
        }

        if ( $file eq '.changes' ) {
            unlink $filePath;
        }
    }
}

1;
