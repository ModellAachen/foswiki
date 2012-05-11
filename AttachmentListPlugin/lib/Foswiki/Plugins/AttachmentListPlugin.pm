# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006 Vinod Kulkarni, Sopan Shewale
# Copyright (C) 2006-2011 Arthur Clemens, arthur@visiblearea.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::AttachmentListPlugin;

use strict;
use Foswiki::Func;
use Foswiki::Meta;
use Foswiki::Plugins::AttachmentListPlugin::FileData;
use Foswiki::Plugins::TopicDataHelperPlugin;

our $VERSION = '$Rev$';
our $RELEASE = '1.5.0';
our $SHORTDESCRIPTION =
'Displays a formattable list of topic attachments - from any topic - anywhere in a topic';
our $NO_PREFS_IN_TOPIC = 1;

my $topic;
my $web;
my $user;
my $installWeb;
my $pluginName = 'AttachmentListPlugin';
my $debug;
my $defaultFormat;
my $imageFormat;

my %sortInputTable = (
    'none' => $Foswiki::Plugins::TopicDataHelperPlugin::sortDirections{'NONE'},
    'ascending' =>
      $Foswiki::Plugins::TopicDataHelperPlugin::sortDirections{'ASCENDING'},
    'descending' =>
      $Foswiki::Plugins::TopicDataHelperPlugin::sortDirections{'DESCENDING'},
);

=pod

=cut

sub initPlugin {
    my ( $inTopic, $inWeb, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    $defaultFormat = '   * [[$fileUrl][$fileName]] $fileComment';

    # Get plugin preferences
    $defaultFormat =
      Foswiki::Func::getPreferencesValue('ATTACHMENTLISTPLUGIN_FORMAT')
      || $defaultFormat;

    $defaultFormat =~ s/^[\\n]+//;    # Strip off leading \n

    $imageFormat =
      '<img src=\'$fileUrl\' alt=\'$fileComment\' title=\'$fileComment\' />';

    # Get plugin preferences
    $imageFormat =
      Foswiki::Func::getPreferencesValue('ATTACHMENTLISTPLUGIN_IMAGE_FORMAT')
      || $imageFormat;

    $imageFormat =~ s/^[\\n]+//;      # Strip off leading \n

    # Get plugin debug flag
    $debug = Foswiki::Func::getPreferencesFlag('ATTACHMENTLISTPLUGIN_DEBUG');

    Foswiki::Func::registerTagHandler( 'FILELIST', \&_handleFileList )
      ;                               #deprecated
    Foswiki::Func::registerTagHandler( 'ATTACHMENTLIST', \&_handleFileList );

    # Plugin correctly initialized
    _debug(
        "- Foswiki::Plugins::${pluginName}::initPlugin( $inWeb.$inTopic ) is OK"
    );

    return 1;
}

=pod

=cut

sub _handleFileList {
    my ( $session, $inParams, $inTopic, $inWeb ) = @_;

    use Data::Dumper;
    _debug(
"AttachmentListPlugin::_handleFileList -- topic=$inWeb.$inTopic; params="
          . Dumper($inParams) );

    my $webs   = $inParams->{'web'}   || $inWeb   || '';
    my $topics = $inParams->{'topic'} || $inTopic || '';
    my $excludeTopics = $inParams->{'excludetopic'} || '';
    my $excludeWebs   = $inParams->{'excludeweb'}   || '';

    # find all attachments except for excluded topics
    my $topicData =
      Foswiki::Plugins::TopicDataHelperPlugin::createTopicData( $webs,
        $excludeWebs, $topics, $excludeTopics );

    # populate with attachment data
    Foswiki::Plugins::TopicDataHelperPlugin::insertObjectData( $topicData,
        \&_createFileData );

    _filterTopicData( $topicData, $inParams );

    my $files =
      Foswiki::Plugins::TopicDataHelperPlugin::getListOfObjectData($topicData);

    # sort
    $files = _sortFiles( $files, $inParams ) if defined $inParams->{'sort'};

    # limit files if param limit is defined
    splice @$files, $inParams->{'limit'}
      if defined $inParams->{'limit'};

    # format
    my $formatted = _formatFileData( $session, $files, $inParams );

    return $formatted;
}

=pod

Goes through the webs and topics in $inTopicData, finds the listed attachments for each topic and creates a FileData object.
Removes the topics keys in $inTopicData if the topic does not have META:FILEATTACHMENT data.
Assigns FileData objects to the $inTopicData hash using this structure:

%topicData = (
	Web1 => {
		Topic1 => {
			picture.jpg => FileData object 1,
			me.PNG => FileData object 2,		
			...
		},
	},
)

=pod

=cut

sub _createFileData {
    my ( $inTopicHash, $inWeb, $inTopic ) = @_;

    # define value for topic key only if topic
    # has META:FILEATTACHMENT data
    my $attachments = _getAttachmentsInTopic( $inWeb, $inTopic );
    my $attach_files = _getAttachmentList( $inWeb, $inTopic )
      if ( $Foswiki::cfg{RCS}{AutoAttachPubFiles} );

    #print STDERR "attachments = " . scalar @$attachments . "\n";
    #print STDERR "files = " . scalar @$attach_files . "\n" ;

    _debug("AttachmentListPlugin::_createFileData");
    use Data::Dumper;
    _debug( "\t attachments=" . Dumper($attachments) );

    if ( scalar @$attachments
        || ( defined $attach_files && scalar @$attach_files ) )
    {
        $inTopicHash->{$inTopic} = ();

        foreach my $attachment (@$attachments) {
            my $fd =
              Foswiki::Plugins::AttachmentListPlugin::FileData->new( $inWeb,
                $inTopic, $attachment );
            my $fileName = $fd->{name};
            $inTopicHash->{$inTopic}{$fileName} = \$fd;
        }

        if (   $Foswiki::cfg{RCS}{AutoAttachPubFiles}
            && defined $attach_files
            && ( scalar @$attachments != scalar @$attach_files ) )
        {
            foreach my $fileName (@$attach_files) {
                unless ( $inTopicHash->{$inTopic}{$fileName} ) {
                    my $fd =
                      Foswiki::Plugins::AttachmentListPlugin::FileData->new(
                        $inWeb, $inTopic,
                        {
                            name         => $fileName,
                            path         => $fileName,
                            autoattached => 1
                        }
                      );
                    $inTopicHash->{$inTopic}{$fileName} = \$fd;
                }
            }
        }
    }
    else {

        # no META:FILEATTACHMENT, so remove from hash
        delete $inTopicHash->{$inTopic};
    }
}

=pod

Filters topic data references in the $inTopicData hash.
Called function remove topic data references in the hash.

=cut

sub _filterTopicData {
    my ( $inTopicData, $inParams ) = @_;
    my %topicData = %$inTopicData;

    # ----------------------------------------------------
    # filter topics by view permission
    my $user = Foswiki::Func::getWikiName();
    my $wikiUserName = Foswiki::Func::userToWikiName( $user, 1 );
    Foswiki::Plugins::TopicDataHelperPlugin::filterTopicDataByViewPermission(
        \%topicData, $wikiUserName );

    # ----------------------------------------------------
    # filter hidden attachments
    my $hideHidden = Foswiki::Func::isTrue( $inParams->{'hide'} );
    if ($hideHidden) {
        Foswiki::Plugins::TopicDataHelperPlugin::filterTopicDataByProperty(
            \%topicData, 'hidden', 1, undef, 'hidden' );
    }

    # ----------------------------------------------------
    # filter attachments by user
    if ( defined $inParams->{'user'} || defined $inParams->{'excludeuser'} ) {
        Foswiki::Plugins::TopicDataHelperPlugin::filterTopicDataByProperty(
            \%topicData, 'user', 1, $inParams->{'user'},
            $inParams->{'excludeuser'} );
    }

    # ----------------------------------------------------
    # filter attachments by date range
    if ( defined $inParams->{'fromdate'} || defined $inParams->{'todate'} ) {
        Foswiki::Plugins::TopicDataHelperPlugin::filterTopicDataByDateRange(
            \%topicData, $inParams->{'fromdate'},
            $inParams->{'todate'} );
    }

    # ----------------------------------------------------
    # filter included/excluded filenames
    if (   defined $inParams->{'file'}
        || defined $inParams->{'excludefile'} )
    {
        Foswiki::Plugins::TopicDataHelperPlugin::filterTopicDataByProperty(
            \%topicData, 'name', 1, $inParams->{'file'},
            $inParams->{'excludefile'} );
    }

    # filter filenames by regular expression
    if (   defined $inParams->{'includefilepattern'}
        || defined $inParams->{'excludefilepattern'} )
    {
        Foswiki::Plugins::TopicDataHelperPlugin::filterTopicDataByRegexMatch(
            \%topicData, 'name',
            $inParams->{'includefilepattern'},
            $inParams->{'excludefilepattern'}
        );
    }

    # ----------------------------------------------------
    # filter by extension
    my $extensions =
         $inParams->{'extension'}
      || $inParams->{'filter'}
      || undef;    # "abc, def" syntax. Substring match will be used
                   # param 'filter' is deprecated
    my $excludeExtensions = $inParams->{'excludeextension'} || undef;
    if ( defined $extensions || defined $excludeExtensions ) {
        Foswiki::Plugins::TopicDataHelperPlugin::filterTopicDataByProperty(
            \%topicData, 'extension', 0, $extensions, $excludeExtensions );
    }

}

=pod

=cut

sub _sortFiles {
    my ( $inFiles, $inParams ) = @_;

    use Data::Dumper;
    _debug( "AttachmentListPlugin::_sortFiles -- files="
          . Dumper($inFiles)
          . "\nparams="
          . Dumper($inParams) );

    my $files = $inFiles;

    # get the sort key for the $inSortMode
    my $sortKey =
      &Foswiki::Plugins::AttachmentListPlugin::FileData::getSortKey(
        $inParams->{'sort'} );
    my $compareMode =
      &Foswiki::Plugins::AttachmentListPlugin::FileData::getCompareMode(
        $inParams->{'sort'} );

    # translate input to sort parameters
    my $sortOrderParam = $inParams->{'sortorder'} || 'none';
    my $sortOrder = $sortInputTable{$sortOrderParam}
      || $Foswiki::Plugins::TopicDataHelperPlugin::sortDirections{'NONE'};

    use Data::Dumper;
    _debug(
        "\t sortKey=$sortKey; compareMode=$compareMode; sortOrder=$sortOrder");

    # set default sort order for sort modes
    if ( $sortOrder ==
        $Foswiki::Plugins::TopicDataHelperPlugin::sortDirections{'NONE'} )
    {
        if ( defined $sortKey && $sortKey eq 'date' ) {

            # exception for dates: newest on top
            $sortOrder =
              $Foswiki::Plugins::TopicDataHelperPlugin::sortDirections{
                'DESCENDING'};
        }
        else {

            # otherwise sort by default ascending
            $sortOrder =
              $Foswiki::Plugins::TopicDataHelperPlugin::sortDirections{
                'ASCENDING'};
        }
    }
    $sortOrder = -$sortOrder
      if ( $sortOrderParam eq 'reverse' );

    $files =
      Foswiki::Plugins::TopicDataHelperPlugin::sortObjectData( $files,
        $sortOrder, $sortKey, $compareMode, 'name' )
      if defined $sortKey;

    return $files;
}

=pod

Returns an array of FILEATTACHMENT objects.

=cut

sub _getAttachmentsInTopic {
    my ( $inWeb, $inTopic ) = @_;

    my ( $meta, $text ) = Foswiki::Func::readTopic( $inWeb, $inTopic );
    my @fileAttachmentData = $meta->find("FILEATTACHMENT");
    return \@fileAttachmentData;
}

=pod

Returns array of attached files independent of metadata

=cut

sub _getAttachmentList {
    my ( $web, $topic ) = @_;

    #print STDERR "getAttachmentList entered for $web $topic\n";
    my $dir = "$Foswiki::cfg{PubDir}/$web/$topic";
    my $dh;
    my @files;
    opendir( $dh, $dir ) || return ();
    @files = grep { !/^[.*_]/ && !/,v$/ } readdir($dh);
    closedir($dh);
    return \@files;
}

=pod

=cut

sub _formatFileData {
    my ( $session, $inFiles, $inParams ) = @_;

    my @files = @$inFiles;

    # formatting parameters
    my $format    = $inParams->{'format'}    || $defaultFormat;
    my $header    = $inParams->{'header'}    || '';
    my $footer    = $inParams->{'footer'}    || '';
    my $alttext   = $inParams->{'alt'}       || '';
    my $separator = $inParams->{'separator'} || "\n";

    # store once for re-use in loop
    my $pubUrl = Foswiki::Func::getUrlHost() . Foswiki::Func::getPubUrlPath();

    my %listedExtensions =
      ();    # store list of extensions to be used for format substitution

    my @formattedData = ();

    foreach my $fileData (@files) {

        my $attrComment = $fileData->{attachment}->{comment} || '';
        my $attrAttr = $fileData->{attachment}->{attr};

        # keep track of listed file extensions
        my $fileExtension = $fileData->{extension};
        $fileExtension = ''
          if $fileExtension eq
              'none';    # do not use the extension placeholder for formatting
        $listedExtensions{$fileExtension} = 1
          if ($fileExtension)
          ;   # add current attachment extension for display for $fileExtensions

        my $s = "$format";

        # Go direct to file where possible, for efficiency
        # TODO: more flexible size formatting
        # also take MB into account
        my $attrSizeStr = '';
        $attrSizeStr = $fileData->{size};
        $attrSizeStr .= 'b'
          if ( $fileData->{size} > 0 && $fileData->{size} < 100 );
        $attrSizeStr = sprintf( "%1.1fK", $fileData->{size} / 1024 )
          if ( $fileData->{size} && $fileData->{size} >= 100 );

        $s =~ s/\$imgTag/$imageFormat/;    # imageFormat is a preference value

        if ( $s =~ m/imgHeight/ || $s =~ m/imgWidth/ ) {

            my ( $imgWidth, $imgHeight ) =
              _retrieveImageSize( $session, $fileData );
            $s =~ s/\$imgWidth/$imgWidth/g   if defined $imgWidth;
            $s =~ s/\$imgHeight/$imgHeight/g if defined $imgHeight;
        }

        $s =~ s/\$fileName/$fileData->{name}/g;
        $s =~ s/\$fileIcon/%ICON{"$fileExtension"}%/g;
        $s =~ s/\$fileSize/$attrSizeStr/g;
        $s =~ s/\$fileComment/$attrComment/g;
        $s =~ s/\$fileExtension/$fileExtension/g;
        $s =~ s/\$fileDate/_formatDate($fileData->{date})/ge;
        $s =~ s/\$fileUser/$fileData->{user}/g;

        if ( $s =~ m/\$fileActionUrl/ ) {
            my $fileActionUrl =
              Foswiki::Func::getScriptUrl( $fileData->{web}, $fileData->{topic},
                "attach" )
              . "?filename=$fileData->{name}&revInfo=1";
            $s =~ s/\$fileActionUrl/$fileActionUrl/g;
        }

        if ( $s =~ m/\$viewfileUrl/ ) {
            my $attrVersion = $fileData->{attachment}->{Version} || '';
            my $viewfileUrl =
              Foswiki::Func::getScriptUrl( $fileData->{web}, $fileData->{topic},
                "viewfile" )
              . "?rev=$attrVersion&filename=$fileData->{name}";
            $s =~ s/\$viewfileUrl/$viewfileUrl/g;
        }

        if ( $s =~ m/\$hidden/ ) {
            my $hiddenStr = $fileData->{hidden} ? 'hidden' : '';
            $s =~ s/\$hidden/$hiddenStr/g;
        }

        my $webEnc = $fileData->{web};
        $webEnc =~ s{([^-_/.a-zA-Z0-9])}{sprintf("%%%02x",ord($1))}eg;
        my $topicEnc = $fileData->{topic};
        $topicEnc =~ s{([^-_/.a-zA-Z0-9])}{sprintf("%%%02x",ord($1))}eg;
        my $fileEnc = $fileData->{name};
        $fileEnc =~ s{([^-_/.a-zA-Z0-9])}{sprintf("%%%02x",ord($1))}eg;
        my $fileUrl = "$pubUrl/$webEnc/$topicEnc/$fileEnc";

        $s =~ s/\$fileUrl/$fileUrl/g;
        $s =~ s/\$fileTopic/$fileData->{topic}/g;
        $s =~ s/\$fileWeb/$fileData->{web}/g;

        push @formattedData, $s;
    }

    my $outText = join $separator, @formattedData;

    if ( $outText eq '' ) {
        $outText = $alttext;
    }
    else {
        $header =~ s/(.+)/$1\n/;    # add newline if text
        $footer =~ s/(.+)/\n$1/;    # add newline if text
                                    # fileCount format param
        my $count = scalar @files;
        $header =~ s/\$fileCount/$count/g;
        $footer =~ s/\$fileCount/$count/g;

        # fileExtensions format param
        my @extensionsList = sort ( keys %listedExtensions );
        my $listedExtensions = join( ',', @extensionsList );
        $header =~ s/\$fileExtensions/$listedExtensions/g;
        $footer =~ s/\$fileExtensions/$listedExtensions/g;

        $outText = "$header$outText$footer";
    }
    $outText = Foswiki::Func::decodeFormatTokens($outText);
    $outText =~ s/\$br/\<br \/\>/g;
    return $outText;
}

=pod

Formats $epoch seconds to the date-time format specified in configure.

=cut

sub _formatDate {
    my ($inEpoch) = @_;

    return Foswiki::Func::formatTime(
        $inEpoch,
        $Foswiki::cfg{DefaultDateFormat},
        $Foswiki::cfg{DisplayTimeValues}
    );
}

=pod

=cut

sub _retrieveImageSize {
    my ( $session, $inFileData ) = @_;

    _debug("AttachmentListPlugin::_retrieveImageSize");

    my $imgWidth  = undef;
    my $imgHeight = undef;

    my $topicObject =
      Foswiki::Meta->new( $session, $inFileData->{web}, $inFileData->{topic} );

    if (
        !Foswiki::Func::attachmentExists(
            $inFileData->{web}, $inFileData->{topic}, $inFileData->{name}
        )
      )
    {
        debug("\t cannot read attachment");
        return ( undef, undef );
    }
    if ( $Foswiki::Plugins::VERSION < 2.1 ) {

        # sorry, no check
    }
    else {
        if ( !$topicObject->testAttachment( $inFileData->{name}, 'r' ) ) {
            _debug("\t use is not allowed to read attachment");
            return ( undef, undef );
        }
    }

    my $stream;
    if ( $Foswiki::Plugins::VERSION < 2.1 ) {
        $stream = $session->{store}->getAttachmentStream(
            $inFileData->{user},  $inFileData->{web},
            $inFileData->{topic}, $inFileData->{name}
        );
    }
    else {
        $stream = $topicObject->openAttachment( $inFileData->{name}, '<' );
    }

    _debug("\t opened stream=$stream");

    use Foswiki::Attach;
    ( $imgWidth, $imgHeight ) =
      Foswiki::Attach::_imgsize( $stream, $inFileData->{name} );
    $stream->close();

    _debug("\t width=$imgWidth; height=$imgHeight");

    return ( $imgWidth, $imgHeight );
}

=pod

=cut

sub _expandStandardEscapes {
    my $text = shift;
    $text =~ s/\$n\(\)/\n/gos;    # expand '$n()' to new line
    my $alpha = Foswiki::Func::getRegularExpression('mixedAlpha');
    $text =~ s/\$n([^$alpha]|$)/\n$1/gos;    # expand '$n' to new line
    $text =~ s/\$nop(\(\))?//gos;      # remove filler, useful for nested search
    $text =~ s/\$quot(\(\))?/\"/gos;   # expand double quote
    $text =~ s/\$percnt(\(\))?/\%/gos; # expand percent
    $text =~ s/\$dollar(\(\))?/\$/gos; # expand dollar
    return $text;
}

=pod

=cut

sub _debug {
    my ( $inText, $inDebug ) = @_;

    #print STDERR "$inText\n";

    Foswiki::Func::writeDebug($inText)
      if $inDebug || $debug;
}

1;
