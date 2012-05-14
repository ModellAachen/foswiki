package Foswiki::Plugins::UpdateAttachmentsPlugin;
use strict;

our $VERSION = '$Rev$';
our $RELEASE = '2.0.3';
our $SHORTDESCRIPTION =
  'A batched alternative to AutoAttachments (adds and removes attachements)';
our $NO_PREFS_IN_TOPIC = 1;

my $debug = 0;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.1 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between UpdateAttachmentsPlugin  and Plugins.pm");
        return 0;
    }

    $debug = $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{Debug} || 0;
    Foswiki::Func::registerRESTHandler( 'update', \&restUpdate );
    return 1;
}

sub restUpdate {
    my $session = shift;
    my $web     = $session->{webName};

    #force autoattach off, as we need to know the real META
    my $cfgAutoAttach = $Foswiki::cfg{AutoAttachPubFiles};
    $Foswiki::cfg{AutoAttachPubFiles} = 0;

#TODO: consider the lighter weight aproach of scanning timestamps in the pub dir
#      checking&updating only those topics that have newer timestamp pub files
#      (it would only helps adding attachments, not removing them)

    my $topicsTested       = 0;
    my $topicsUpdated      = 0;
    my $attachmentsIgnored = 0;
    my $attachmentsRemoved = 0;
    my $attachmentsAdded   = 0;
    my $attachmentsUpdated = 0;
    my $detailedReport     = '';

    my $webObject = Foswiki::Meta->new( $session, $web );
    unless ( $webObject->haveAccess('VIEW')
        && $webObject->haveAccess('CHANGE') )
    {
        print STDERR "Check for VIEW and CHANGE on $web web failed\n" if $debug;
        $webObject->finish();
        return "Access denied on $web web.  UpdateAttachments not possible\n";
    }

    if ( $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}
        {CheckUPDATEATACHPermission} )
    {
        unless ( $webObject->haveAccess('UPDATEATTACH') ) {
            print STDERR "Check for UPDATEATTACH on $web web failed\n"
              if $debug;
            $webObject->finish();
            return
"UPDATEATTACH permission denied on $web web.  UpdateAttachments not possible\n";
        }
    }

    my @topicNames = Foswiki::Func::getTopicList($web);
    foreach my $topic (@topicNames) {
        print STDERR
          "===============  Processing $topic in $web ==============\n"
          if $debug;
        my $changed = 0;

        my $topicObject = Foswiki::Meta->new( $session, $web, $topic );

# Change topic context so topic can override attributes of attachments in their settings
        Foswiki::Func::pushTopicContext( $web, $topic );

        if ( !$topicObject->haveAccess('VIEW') ) {
            $detailedReport .=
              "bypassed $web.$topic - no permission to VIEW <br/>\n";
            $topicObject->finish();
            next;
        }

        if ( !$topicObject->haveAccess('CHANGE') ) {
            $detailedReport .=
              "bypassed $web.$topic - no permission to CHANGE <br/>\n";
            $topicObject->finish();
            next;
        }

        $topicObject->loadVersion();

        my @knownAttachments = $topicObject->find('FILEATTACHMENT');
        my (
            $attachmentsFoundInPub,  $attachmentsRemovedFromMeta,
            $attachmentsAddedToMeta, $attachmentsUpdatedInMeta,
            $badAttachments
        ) = synchroniseAttachmentsList( $topicObject, \@knownAttachments );

        Foswiki::Func::popTopicContext();

        # @validAttachmentsFound will contain the replacment attachment Metadata
        my @validAttachmentsFound;

        foreach my $foundAttachment (@$attachmentsFoundInPub) {
            push @validAttachmentsFound, $foundAttachment;
        }

        $topicObject->putAll( 'FILEATTACHMENT', @validAttachmentsFound )
          if ( @validAttachmentsFound || scalar @$attachmentsRemovedFromMeta );

        #TODO: actually test that they are the same! (update size, date etc)
        print STDERR "$web.$topic has "
          . scalar(@knownAttachments)
          . " in meta, "
          . scalar(@$attachmentsFoundInPub)
          . " in pub dir\n"
          if $debug;

        $changed =
          scalar(@$attachmentsRemovedFromMeta) +
          scalar(@$attachmentsAddedToMeta) +
          scalar(@$attachmentsUpdatedInMeta);

        if ($changed) {
            $topicObject->save( comment => 'UpdateAttachments' );
            print STDERR "updating the attachments of $web.$topic\n" if $debug;
            $topicsUpdated++;
            $attachmentsRemoved += scalar(@$attachmentsRemovedFromMeta);
            $attachmentsAdded   += scalar(@$attachmentsAddedToMeta);
            $attachmentsUpdated += scalar(@$attachmentsUpdatedInMeta);

            $detailedReport .= "Updating $web.$topic <br/>\n";
            foreach my $attach (@$attachmentsRemovedFromMeta) {
                $detailedReport .= "Removed $attach <br/>";
            }
            foreach my $attach (@$attachmentsAddedToMeta) {
                $detailedReport .= "Added $attach <br/>";
            }
            foreach my $attach (@$attachmentsUpdatedInMeta) {
                $detailedReport .= "Updated $attach <br/>";
            }

        }
        foreach my $attach (@$badAttachments) {
            $attachmentsIgnored++;
            $detailedReport .=
                'AutoAttachPubFiles ignoring '
              . "\"$attach\" in $web.$topic"
              . ' - not a valid Foswiki Attachment filename<br/>' . "\n";
        }
        $topicsTested++;
        $topicObject->finish();

        #TODO: $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{BatchLimit}

    }

    $webObject->finish();

    print STDERR
"UpdateAttachments checked $topicsTested, updated $topicsUpdated,   removed $attachmentsRemoved attachments, $attachmentsIgnored ignored"
      if $debug;

# Restore auto-attach setting.   (This *really* ought to be disabled if using this plugin
    $Foswiki::cfg{AutoAttachPubFiles} = $cfgAutoAttach;

    return <<HERE
UpdateAttachments Topics checked $topicsTested, updated $topicsUpdated, <br/> 
Attachments updated $attachmentsUpdated, added $attachmentsAdded, removed $attachmentsRemoved, ignored $attachmentsIgnored <br/><br/>
$detailedReport
HERE
}

=begin TML

---++ ObjectMethod synchroniseAttachmentsList(\@old) -> @new

*Copied directly from Foswiki::Store::VC::Handler.pm*

Synchronise the attachment list from meta-data with what's actually
stored in the DB. Returns an ARRAY of FILEATTACHMENTs. These can be
put in the new tom.

=cut

# IDEA On Windows machines where the underlying filesystem can store arbitary
# meta data against files, this might replace/fulfil the COMMENT purpose

sub synchroniseAttachmentsList {
    my ( $topicObject, $attachmentsKnownInMeta ) = @_;

    my %filesListedInPub     = _getAttachmentStats($topicObject);
    my %filesListedInMeta    = ();
    my %filesToAddToMeta     = ();
    my @filesRemovedFromMeta = ();
    my @filesAddedToMeta     = ();
    my @filesUpdatedInMeta   = ();
    my @badAttachments       = ();

    # You need the following lines if you want metadata to supplement
    # the filesystem
    if ( defined $attachmentsKnownInMeta ) {
        %filesListedInMeta =
          map { $_->{name} => $_ } @$attachmentsKnownInMeta;
    }

    foreach my $file ( keys %filesListedInPub ) {
        my $validated = Foswiki::Sandbox::validateAttachmentName($file);
        unless ( defined $validated
            && $validated eq $file )
        {
            push @badAttachments, $file;
            next;
        }

        if ( $filesListedInMeta{$file} ) {
            if ( $filesListedInMeta{$file}{size} ne
                   $filesListedInPub{$file}{size}
                || $filesListedInMeta{$file}{date} ne
                $filesListedInPub{$file}{date} )
            {
                $filesListedInPub{$file}{autoattached} = "1";
                push @filesUpdatedInMeta, $file;
                print STDERR "Updating $file \n" if $debug;
            }

            # Bring forward any missing yet wanted attribute
            foreach my $field (qw(comment attr user version autoattached)) {
                if ( $filesListedInMeta{$file}{$field} ) {
                    $filesListedInPub{$file}{$field} =
                      $filesListedInMeta{$file}{$field};
                }
            }
        }
        else {

            #default attachment owner to {AttachAsUser}
            push @filesAddedToMeta, $file;
            print STDERR "Adding $file \n" if $debug;
            $filesListedInPub{$file}{autoattached} = "1";
            if (
                (
                    defined(
                        $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}
                          {AttachAsUser}
                    )
                )
                && ( $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}
                    {AttachAsUser} ne '' )
              )
            {
                $filesListedInPub{$file}{user} =
                  Foswiki::Func::getCanonicalUserID(
                    $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}
                      {AttachAsUser} );
            }
        }
    }

    # A comparison of the keys of the $filesListedInMeta and %filesListedInPub
    # would show files that were in Meta but have disappeared from Pub.

    foreach my $file ( keys %filesListedInMeta ) {
        if ( !$filesListedInPub{$file} ) {
            my $validated = Foswiki::Sandbox::validateAttachmentName($file);
            next unless ( defined $validated
                && $validated eq $file );

            if (
                $Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{RemoveMissing} )
            {
                print STDERR "Removing $file \n" if $debug;
                push @filesRemovedFromMeta, $file;
            }
            else {
                $filesListedInPub{$file} = $filesListedInMeta{$file};
                print STDERR "Retained missing attachment $file\n" if $debug;
            }
        }
    }

    # Do not change this from array to hash, you would lose the
    # proper attachment sequence
    my @deindexedBecauseMetaDoesnotIndexAttachments = values(%filesListedInPub);

    return \@deindexedBecauseMetaDoesnotIndexAttachments,
      \@filesRemovedFromMeta, \@filesAddedToMeta, \@filesUpdatedInMeta,
      \@badAttachments;
}

=begin TML

---++ ObjectMethod getAttachmentList() -> @list

Get list of attachment names actually stored for topic.

=cut

sub getAttachmentList {
    my $topicObject = shift;
    my $dir =
        "$Foswiki::cfg{PubDir}/"
      . $topicObject->web() . "/"
      . $topicObject->topic();
    my $attachFilter =
      qr/$Foswiki::cfg{Plugins}{UpdateAttachmentsPlugin}{AttachFilter}/;
    my $dh;
    opendir( $dh, $dir ) || return ();
    my @files =
      grep { !/$attachFilter/ && !/,v$/ && -f "$dir/$_" } readdir($dh);
    closedir($dh);
    return @files;
}

# returns {} of filename => { key => value, key2 => value }
# for any given web, topic
sub _getAttachmentStats {
    my $topicObject    = shift;
    my %attachmentList = ();
    my $dir =
        "$Foswiki::cfg{PubDir}/"
      . $topicObject->web() . '/'
      . $topicObject->topic();
    foreach my $attachment ( getAttachmentList($topicObject) ) {
        my @stat = stat( $dir . "/" . $attachment );
        $attachmentList{$attachment} =
          _constructAttributesForAutoAttached( $attachment, \@stat );
    }
    return %attachmentList;
}

# as long as stat is defined, return an emulated set of attributes for that
# attachment.
sub _constructAttributesForAutoAttached {
    my ( $file, $stat ) = @_;

    my %pairs = (
        name    => $file,
        version => '',
        path    => $file,
        size    => $stat->[7],
        date    => $stat->[9],

#        user    => 'UnknownUser',  #safer _not_ to default - Foswiki will fill it in when it needs to
        comment => '',
        attr    => '',
    );

    if ( $#$stat > 0 ) {
        return \%pairs;
    }
    else {
        return;
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2007-2012 SvenDowideit@fosiki.com

Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:
Copyright (C) 2001-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

