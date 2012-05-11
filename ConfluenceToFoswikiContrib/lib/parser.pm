##########################################################################
#
# This software/utility is developed by TWIKI.NET (http://www.twiki.net)
# Copyright (C) 1999-2008  TWIKI.NET, sales@twiki.net
#
##########################################################################

package parser;

use strict;
use warnings;

use XML::LibXML;
use Exporter;
use Convertor;
use WikiText::Confluence::Parser;
use WikiText::Foswiki::Emitter;

our @ISA     = qw(Exporter);
our @EXPORTS = qw(foswikiEmitter);

my %pageinfo;
my %attinfo;
my %comminfo;
my %newsinfo;
my $logger;
my $root = undef;

sub foswikiEmitter {
    my $filename = shift;
    $logger = shift;
    my $session  = shift;
    my $sHomeDir = shift;
    my $webdir;

    $logger->info("START Parsing file $filename");
    my $parser = XML::LibXML->new();
    $root = $parser->parse_file($filename);

    if ( $filename =~ /.*xml\/(.*)\/entities/g ) {
        $webdir = $1;
    }

    if ( !defined $webdir ) {
        $logger->error("Could not parser Webdir from $filename");
    }

    my @pages       = $root->findnodes('//object[@class="Page"]');
    my @spaces      = $root->findnodes('//object[@class="Space"]');
    my @attachments = $root->findnodes('//object[@class="Attachment"]');
    my @comments    = $root->findnodes('//object[@class="Comment"]');
    my @news        = $root->findnodes('//object[@class="BlogPost"]');

    foreach my $comm (@comments) {
        process_comment($comm);
    }
    my $currspace = process_space( $spaces[0] );

    if ( !defined $currspace ) {
        $logger->error("Could not parse space from $filename");
    }

    $logger->info("DONE Parsing file $filename");

    foreach my $hnews (@news) {
        my $currnews = process_news($hnews);
        create_news_page( $currnews, $currspace, $session, $sHomeDir, $webdir )
          if ($currnews);
    }

    foreach my $attach (@attachments) {
        process_attachment($attach);
    }

    foreach my $page (@pages) {
        my $currpage = process_page($page);
        create_foswiki_page( $currpage, $currspace, $session, $sHomeDir,
            $webdir )
          if ($currpage);
    }

}

sub process_news {

    my ($news) = @_;
    my $newsid = $news->findvalue('./id/text()');
    $newsinfo{$newsid}{'newsid'} = $news->findvalue(
'./collection[@name="bodyContents"]/element[@class="BodyContent"][1]/id/text()'
    );
    $newsinfo{$newsid}{'title'} =
      $news->findvalue('./property[@name="title"]/text()');
    $newsinfo{$newsid}{'time'} =
      $news->findvalue('./property[@name="lastModificationDate"]/text()');
    my $bodyobj = (
        $root->findnodes(
            '//object[@class="BodyContent"][./id/text()="'
              . $newsinfo{$newsid}{'newsid'} . '"]'
        )
    )[0];
    if ( !$bodyobj ) {
        $logger->warn( "Couldn't find body "
              . $newsinfo{$newsid}{newsid}
              . " for mews id $newsid" );
    }
    $newsinfo{$newsid}{'body'} =
      $bodyobj->findvalue('./property[@name="body"]/text()');
    return $newsinfo{$newsid};
}

sub process_comment {
    my ($comment) = @_;
    my $commid = $comment->findvalue('./id/text()');
    $comminfo{$commid}{'pageid'} =
      $comment->findvalue('./property[@name="page"][@class="Page"]/id/text()');
    $comminfo{$commid}{"bodyid"} = $comment->findvalue(
'./collection[@name="bodyContents"]/element[@class="BodyContent"][1]/id/text()'
    );
    my $bodyobj = (
        $root->findnodes(
            '//object[@class="BodyContent"][./id/text()="'
              . $comminfo{$commid}{"bodyid"} . '"]'
        )
    )[0];
    if ( !$bodyobj ) {
        $logger->warn( "Couldn't find body "
              . $comminfo{$commid}{"bodyid"}
              . " for comment id $commid" );
    }
    $comminfo{$commid}{'body'} =
      $bodyobj->findvalue('./property[@name="body"]/text()');
    return $comminfo{$commid};
}

sub process_attachment {
    my ($att) = @_;
    my $attid = $att->findvalue('./id/text()');
    $attinfo{$attid}{'id'} = $attid;
    $attinfo{$attid}{'filename'} =
      $att->findvalue('./property[@name="fileName"]/text()');
    $attinfo{$attid}{'contenttype'} =
      $att->findvalue('./property[@name="contentType"]/text()');
    $attinfo{$attid}{'filesize'} =
      $att->findvalue('./property[@name="fileSize"]/text()');
    $attinfo{$attid}{'creationdate'} =
      $att->findvalue('./property[@name="creationDate"]/text()');
    $attinfo{$attid}{'comment'} =
      $att->findvalue('./property[@name="comment"]/text()');
    return $attinfo{$attid};

}

sub process_space {
    my ($space) = @_;
    my $spacename = $space->findvalue('./property[@name="name"]/text()');
    return $spacename;
}

sub process_page {
    my ($page) = @_;
    my @attachids;
    my @commentids;
    my ( $pageid, $parentid, $original_version, $historical_version,
        @bodycontentids );

    $pageid = $page->findvalue('./id/text()');
    $logger->debug("Processing page with pageid $pageid");

    if ( exists( $pageinfo{$pageid} ) ) {
        return;
    }

    $original_version = $page->findvalue(
        './property[@name="originalVersion"][@class="Page"]/id/text()');

    if ($original_version) {
        $logger->info("Old pageid $pageid not processing");
        return;
    }

    $parentid =
      $page->findvalue('./property[@name="parent"][@class="Page"]/id/text()');

    if ( $parentid && !exists( $pageinfo{$parentid} ) ) {
        my @parents = $root->findnodes(
            '//object[@class="Page"][./id/text()="' . $parentid . '"]' );
        if ( $#parents != 0 ) {
            die "Couldn't find parent page of $pageid";
        }
        process_page( $parents[0] );
    }

    $pageinfo{$pageid}{"id"}       = $pageid;
    $pageinfo{$pageid}{"parentid"} = $parentid;
    $pageinfo{$pageid}{"spaceid"} =
      $page->findvalue('./property[@name="space"][@class="Space"]/id/text()');
    $pageinfo{$pageid}{"title"} =
      $page->findvalue('./property[@name="title"]/text()');
    $pageinfo{$pageid}{"bodyid"} = $page->findvalue(
'./collection[@name="bodyContents"]/element[@class="BodyContent"][1]/id/text()'
    );
    $pageinfo{$pageid}{"version"} =
      $page->findvalue('./property[@name="version"]/text()');
    $pageinfo{$pageid}{"creatorName"} =
      $page->findvalue('./property[@name="creatorName"]/text()');
    $pageinfo{$pageid}{"creationDate"} =
      $page->findvalue('./property[@name="creationDate"]/text()');
    $pageinfo{$pageid}{"lastModifierName"} =
      $page->findvalue('./property[@name="lastModifierName"]/text()');
    $pageinfo{$pageid}{"lastModificationDate"} =
      $page->findvalue('./property[@name="lastModificationDate"]/text()');

    my $bodyobj = (
        $root->findnodes(
            '//object[@class="BodyContent"][./id/text()="'
              . $pageinfo{$pageid}{"bodyid"} . '"]'
        )
    )[0];

    if ( !$bodyobj ) {
        $logger->warn( "Couldn't find body "
              . $pageinfo{$pageid}{"bodyid"}
              . " for page $pageid" );
    }
    $pageinfo{$pageid}{"bodytext"} =
      $bodyobj->findvalue('./property[@name="body"]/text()');

    #find all attachment ids for cuurent page
    my @attachments = $page->findnodes(
'./collection[@name="attachments"]/element[@class="Attachment"]/id/text()'
    );

    #find comments for current page
    my @comment = $page->findnodes(
        './collection[@name="comments"]/element[@class="Comment"]/id/text()');

    foreach my $attachment (@attachments) {
        my $attachmentid = $attachment->textContent();
        push( @attachids, $attachment->textContent );
    }

    if ( $#attachids > 0 ) {
        $pageinfo{$pageid}{"attachments"} = [@attachids];
    }
    else {
        $pageinfo{$pageid}{'title'} =~ s/\s+/_/g;
        $logger->info(
            "No attachments found for topic \"$pageinfo{$pageid}{'title'}\" ");
    }

    foreach my $comment (@comment) {
        my $commid = $comment->textContent();
        push( @commentids, $comment->textContent );
    }

    if ( $#commentids > 0 ) {
        $pageinfo{$pageid}{"comments"} = [@commentids];
    }

    return $pageinfo{$pageid};
}

sub create_foswiki_page {

    my ( $pagehash, $currspace, $session, $sHomeDir, $webdir ) = @_;
    my $parenttopic;
    my $commentno = 1;
    my $currtopic = $pagehash->{'title'};
    $WikiText::Parser::logger = $logger;

    if ( defined $pagehash->{'title'} ) {
        $currspace = Utils::Common::toFoswikiname($currspace);
        $currtopic = Utils::Common::toFoswikiname($currtopic);

    }

    if ( defined( $pageinfo{ $pagehash->{'parentid'} }{'title'} ) ) {
        $parenttopic = Utils::Common::toFoswikiname(
            $pageinfo{ $pagehash->{'parentid'} }{'title'} );
    }

    my $attachs  = $pagehash->{'attachments'};
    my $comments = $pagehash->{'comments'};
    my ( $attid, $result );

    if ( !defined $pagehash->{id} ) {
        return;
    }

    #if we find comments for that page we include those in page body text.
    # as to current date there is no api for comments for Foswiki page
    foreach my $comment (@$comments) {
        $pagehash->{bodytext} =
            "$pagehash->{bodytext}" . "\n" . "\n\n"
          . "__Comment$commentno" . "__" . " \n" . "---" . "\n\n"
          . $comminfo{$comment}{body};
        $commentno++;
    }

    # Convert Confluence markup to Foswiki via WikiText

    $logger->debug(
        "Confluence body:\n$pagehash->{bodytext}##End of Confluence body");
    my $parser =
      WikiText::Confluence::Parser->new(
        receiver => WikiText::Foswiki::Emitter->new );
    my $output;
    eval { $output = $parser->parse( $pagehash->{bodytext} . "\n" ); };
    if ($@) {
        $logger->error(
            "Could not convert Confluence markup of $currtopic in $currspace");
        $logger->error("Details : $@");
        $logger->error(
            "Failed bodytext:\n$pagehash->{bodytext}##End of Confluence body");
        return;
    }
    else {
        $logger->debug("Foswiki body:\n$output##End of Foswiki body");

        #       return;
    }

    # foswiki by default has this webs, we need to rename them for publishing

    if ( $currspace =~ /^(system|sandbox|main)$/i ) {
        $currspace = "Confluence" . "$1";
        $logger->info("Renamed web $1 to $currspace");
    }

    my $re =
      Convertor::saveTopic( $session, $currspace, $currtopic, $parenttopic,
        $output );
    if ($re) {
        $logger->error("Could not save topic $currtopic in $currspace");
        $logger->error("Details : $re");
    }

    foreach $attid (@$attachs) {

        $attinfo{$attid}{'filepath'} =
          "$sHomeDir/xml/$webdir/attachments/$pagehash->{'id'}/$attid";
        my $ret =
          Convertor::attachmentExists( $currspace, $currtopic,
            $attinfo{$attid}{'filename'} );

        if ( !defined $ret or $ret != 1 ) {
            $result =
              Convertor::saveAttachment( $currspace, $currtopic,
                $attinfo{$attid}{'filename'},
                $attinfo{$attid} );
        }
        else {
            $logger->info(
"Attachment $attinfo{$attid}{'filename'} already exists for topic $currtopic"
            );
        }

        if ($result) {
            $logger->error(
"Could not save attachment $attinfo{$attid}{'filename'} for topic $currtopic"
            );
            $logger->error("Details: $result");
        }

    }
    return $re;
}

#news are not attached to pages, for every news we are creating a page (topic).
sub create_news_page {
    my ( $newshash, $currspace, $session, $sHomeDir, $webdir ) = @_;
    my $parenttopic;
    my $currtopic = "News_" . $newshash->{title};

    $currspace = Utils::Common::toFoswikiname($currspace);
    $currtopic = Utils::Common::toFoswikiname($currtopic);

    my $parser =
      WikiText::Confluence::Parser->new(
        receiver => WikiText::Foswiki::Emitter->new );
    my $output;
    eval { $output = $parser->parse( $newshash->{body} . "\n" ); };
    if ($@) {
        $logger->error(
            "Could not convert Confluence markup of $currtopic in $currspace");
        $logger->error("Details : $@");
        $logger->error(
            "Failed bodytext:\n$newshash->{body}##End of Confluence body");
        return;
    }
    else {
        $logger->debug("Foswiki body:\n$output##End of Foswiki body");
    }

    my $re =
      Convertor::saveTopic( $session, $currspace, $currtopic, $parenttopic,
        $output );

    if ($re) {
        $logger->error("Could not save news topic $currtopic in $currspace");
        $logger->error("Details : $re");
    }

}

1;
