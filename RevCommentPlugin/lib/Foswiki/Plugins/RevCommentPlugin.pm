# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005 by TWiki:Main.JChristophFuchs
# Copyright (C) 2008 Foswiki Contributors
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
#

# =========================
package Foswiki::Plugins::RevCommentPlugin;
use strict;
use warnings;

use Foswiki::Func    ();
use Foswiki::Plugins ();
use Foswiki::Meta    ();

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug
);

use vars qw(
  $commentFromUpload $attachmentComments $cachedCommentWeb $cachedCommentTopic $minorMark
);

# This should always be $Rev: 9841 $ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 9841 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '22 Jan 2009';

$pluginName = 'RevCommentPlugin';

$minorMark = '%MINOR%';

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.021 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    $commentFromUpload = undef;

    # Get plugin debug flag
    $debug = Foswiki::Func::getPluginPreferencesFlag("DEBUG");

 # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $attachmentComments =
      Foswiki::Func::getPluginPreferencesValue("ATTACHMENT_COMMENTS") || 1;

    $cachedCommentWeb   = '';
    $cachedCommentTopic = '';

    # Need to register meta, Item11249
    if ( defined &Foswiki::Meta::registerMETA ) {
        Foswiki::Meta::registerMETA( 'REVCOMMENT',
            allow => [qw(comment t minor rev ncomments)] );
    }

    # Plugin correctly initialized
    Foswiki::Func::writeDebug(
        "- Foswiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    Foswiki::Func::writeDebug(
        "- --- attachmentComments = " . $attachmentComments )
      if $debug;
    return 1;
}

sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    Foswiki::Func::writeDebug(
        "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by Foswiki::handleCommonTags, after %INCLUDE:"..."%

    $_[0] =~ s/%REVCOMMENT%/&handleRevComment()/ge;
    $_[0] =~ s/%REVCOMMENT{(.*?)}%/&handleRevComment($1)/ge;
    $_[0] =~ s/%REVCOMMENT\[(.*?)\]%/&handleRevComment($1)/ge;
}

sub beforeSaveHandler {
### my ( $text, $topic, $web, $meta ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    my ( $topic, $web, $meta ) = @_[ 1 .. 3 ];

    Foswiki::Func::writeDebug(
        "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )")
      if $debug;

# This handler is called by Foswiki::Store::saveTopic just before the save action.
# New hook in Foswiki::Plugins $VERSION = '1.010'

    my $query = Foswiki::Func::getCgiQuery();

    # Get current revision
    my ( $date, $user, $currev ) =
      Foswiki::Func::getRevisionInfo( $_[2], $_[1] );
    $currev ||= 0;

    my @comments = _extractComments($meta);

    # Set correct rev of comment
    foreach my $comment (@comments) {
        $comment->{rev} = $currev unless $comment->{rev} =~ /\d+/;
    }

    # Delete old comments
    @comments = grep { $_->{rev} >= $currev } @comments;

    # Check for new comments
    my $newComment;
    if ($commentFromUpload) {    # File upload
        $newComment = {
            comment => $commentFromUpload,
            t       => 'Upload' . time(),
            minor   => 0,
            rev     => undef,
        };
    }
    elsif ($attachmentComments
        && $query->url( -relative ) =~ /upload/ )
    {                            # Attachment changed
        $newComment = {
            comment => 'Changed properties for attachment !'
              . $query->param('filename'),
            t     => 'PropChanged' . time(),
            minor => 0,
            rev   => undef,
        };
    }
    elsif ( $query->param('comment') || $query->param('dontnotify') ) {
        my $commentFromForm = $query->param('comment') || ' ';
        my $t               = $query->param('t')       || time();

        $newComment = {
            comment => $commentFromForm,
            t       => $t,
            minor   => defined $query->param('dontnotify'),
            rev     => undef,
        };
    }

    if (   ( $newComment->{comment} || '' ) =~ /\S/
        || ( $newComment->{minor} && !@comments ) )
    {
        push @comments, $newComment;
    }
    $meta->remove('REVCOMMENT');
    _putComments( $meta, @comments );
}

sub beforeAttachmentSaveHandler {
    Foswiki::Func::writeDebug(
        "- ${pluginName}::beforeAttachmentSaveHandler( $_[2].$_[1] )")
      if $debug;

    return unless $attachmentComments;
    Foswiki::Func::writeDebug("--- still here") if $debug;

    my $query = Foswiki::Func::getCgiQuery();
    if ( defined( $query->param('filename') )
        && $query->param('filename') eq $_[0]->{attachment} )
    {

        $commentFromUpload = 'Updated attachment !' . $_[0]->{attachment};
    }
    else {
        $commentFromUpload = 'Attached file !' . $_[0]->{attachment};
    }
}

# =========================

sub _extractComments {

    my $meta     = shift;
    my @comments = ();

    if ( my $code = $meta->get('REVCOMMENT') ) {
        for ( my $i = 1 ; $i <= $code->{ncomments} ; ++$i ) {
            push @comments,
              {
                minor   => $code->{ 'minor_' . $i },
                comment => $code->{ 'comment_' . $i },
                t       => $code->{ 't_' . $i },
                rev     => $code->{ 'rev_' . $i },
              };
        }
    }

    return @comments;
}

sub _putComments {

    my $meta     = shift;
    my @comments = @_;
    my %args     = ( ncomments => scalar @comments, );

    for ( my $i = 1 ; $i <= scalar @comments ; ++$i ) {
        $args{ 'comment_' . $i } = $comments[ $i - 1 ]->{comment};
        $args{ 't_' . $i }       = $comments[ $i - 1 ]->{t};
        $args{ 'minor_' . $i }   = $comments[ $i - 1 ]->{minor};
        $args{ 'rev_' . $i }     = $comments[ $i - 1 ]->{rev};
    }

    $meta->put( 'REVCOMMENT', \%args );
}

sub handleRevComment {

    Foswiki::Func::writeDebug(
        "- Foswiki::Plugins::${pluginName}::handleRevComments: Args=>$_[0]<\n")
      if $debug;
    my $params = $_[0] || '';

# SMELL: this "convenience" should probably be removed; you can \" in Attributes
    $params =~ s/''/"/g;

    my %params = Foswiki::Func::extractParameters($params);

    my $web   = $params{web}   || $web;
    my $topic = $params{topic} || $topic;
    my $rev =
         $params{rev}
      || $params{_DEFAULT}
      || ( Foswiki::Func::getRevisionInfo( $web, $topic ) )[2];
    $rev =~ s/^1\.//;
    my $delimiter = $params{delimiter};
    $delimiter = '</li><li style="margin-left:-1em;">'
      unless defined($delimiter);
    $delimiter =~ s/\\n/\n/g;
    $delimiter =~ s/\\t/\t/g;
    my $pre = $params{pre};
    $pre = '<noautolink><ul><li style="margin-left:-1em;">'
      unless defined($pre);
    my $post = $params{post};
    $post = '</li></ul></noautolink>' unless defined($post);
    my $minor = $params{minor};
    $minor = '<i>(minor)</i> ' unless defined($minor);

    unless ( Foswiki::Func::topicExists( $web, $topic ) ) {
        return "Topic $web.$topic does not exist";
    }
    my @comments;

# SMELL: doesn't respect access permissions (too bad there isn't a version that does, like readTopic() does...)
    my ( $meta, undef ) = Foswiki::Func::readTopic( $web, $topic, $rev );

    @comments = _extractComments($meta);
    foreach my $comment (@comments) {
        $comment->{rev} = $rev unless $comment->{rev} =~ /\d+/;
    }
    @comments = grep { $_->{rev} == $rev } @comments;
    map { $_->{comment} = $minorMark . $_->{comment} if $_->{minor} } @comments;
    @comments = map { $_->{comment} } @comments;

    my $text =
      scalar @comments > 0
      ? $pre . join( $delimiter, @comments ) . $post
      : '';
    $text =~ s/$minorMark/$minor/g;
    return $text;
}

1;
