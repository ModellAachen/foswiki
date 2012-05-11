# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009 Foswiki Contributors
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

package Foswiki::Plugins::KinoSearchPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
  $webName $topicName $enableOnSaveUpdates
);

$VERSION           = '$Rev: 5121 $';
$RELEASE           = '1.4';
$SHORTDESCRIPTION  = 'A plugin wrapper around the KinoSearchContrib';
$NO_PREFS_IN_TOPIC = 1;
$pluginName        = 'KinoSearchPlugin';

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    $debug = $Foswiki::cfg{Plugins}{KinoSearchPlugin}{Debug} || 0;
    $enableOnSaveUpdates =
      $Foswiki::cfg{Plugins}{KinoSearchPlugin}{EnableOnSaveUpdates} || 0;

    Foswiki::Func::registerTagHandler( 'KINOSEARCH', \&_KINOSEARCH );

    Foswiki::Func::registerRESTHandler( 'search', \&_search );
    Foswiki::Func::registerRESTHandler( 'index',  \&_index );
    Foswiki::Func::registerRESTHandler( 'update', \&_update );

    return 1;
}

sub _search {
    my $session = shift;

    require Foswiki::Contrib::KinoSearchContrib::Search;
    my $searcher = Foswiki::Contrib::KinoSearchContrib::Search->newSearch();
    return $searcher->search( $debug, $session );
}

sub _index {
    my $session = shift;

    require Foswiki::Contrib::KinoSearchContrib::Index;
    my $indexer = Foswiki::Contrib::KinoSearchContrib::Index->newCreateIndex();
    return $indexer->createIndex( $debug, 1 );
}

sub _update {
    my $session = shift;

    require Foswiki::Contrib::KinoSearchContrib::Index;
    my $indexer = Foswiki::Contrib::KinoSearchContrib::Index->newUpdateIndex();
    return $indexer->updateIndex($debug);
}

sub _KINOSEARCH {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    my $ret    = "";
    my $format = $params->{format}
      || "\$icon <b>\$match</b> <span class='foswikiAlert'>\$locked</span> <br />\$texthead<br /><hr />";
    $format =~ s/\$icon/%ICON%/go;
    $format =~ s/\$match/%MATCH%/go;
    $format =~ s/\$locked/%LOCKED%/go;
    $format =~ s/\$texthead/%TEXTHEAD%/go;

    require Foswiki::Contrib::KinoSearchContrib::Search;
    my $docs = Foswiki::Contrib::KinoSearchContrib::Search->docsForQuery(
        $params->{_DEFAULT} );

    while ( my $hit = $docs->fetch_hit_hashref ) {
        my $resweb   = $hit->{web};
        my $restopic = $hit->{topic};

     # For partial name search of topics, just hold the first part of the string
        if ( $restopic =~ m/(\w+)/ ) { $restopic =~ s/ .*//; }

        # topics moved away maybe are still indexed on old web
        next unless &Foswiki::Func::topicExists( $resweb, $restopic );

        my $wikiusername = Foswiki::Func::getWikiName();
        if (
            !Foswiki::Func::checkAccessPermission(
                'VIEW', $wikiusername, undef, $restopic, $resweb, undef
            )
          )
        {
            next;
        }

        $ret .=
          Foswiki::Contrib::KinoSearchContrib::Search->renderHtmlStringFor(
            $hit, $format, 0, 0 );
    }

    return "$ret";
}

sub afterSaveHandler {
    return
      if ( $enableOnSaveUpdates != 1 )
      ;    #disabled - they can make save's take too long
           # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $error, $meta ) = @_;
    my $web   = $_[2];
    my $topic = $_[1];

    require Foswiki::Contrib::KinoSearchContrib::Index;
    my $indexer = Foswiki::Contrib::KinoSearchContrib::Index->newUpdateIndex();
    my @topicsToUpdate = ($topic);
    $indexer->removeTopics( $web, @topicsToUpdate );
    $indexer->addTopics( $web, @topicsToUpdate );
}

sub afterRenameHandler {
    return
      if ( $enableOnSaveUpdates != 1 )
      ;    #disabled - they can make save's take too long
           # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment ) = @_;
    my $oldweb   = $_[0];
    my $oldtopic = $_[1];
    my $newweb   = $_[3];
    my $newtopic = $_[4];

    require Foswiki::Contrib::KinoSearchContrib::Index;
    my $indexer = Foswiki::Contrib::KinoSearchContrib::Index->newUpdateIndex();
    my @topicsToUpdate = ($oldtopic);
    $indexer->removeTopics( $oldweb, @topicsToUpdate );
    @topicsToUpdate = ($newtopic);
    $indexer->addTopics( $newtopic, @topicsToUpdate );
}

sub afterAttachmentSaveHandler {
    return
      if ( $enableOnSaveUpdates != 1 )
      ;    #disabled - they can make save's take too long
           # do not uncomment, use $_[0], $_[1]... instead
    ###   my( $attrHashRef, $topic, $web ) = @_;
    my $web   = $_[2];
    my $topic = $_[1];

    require Foswiki::Contrib::KinoSearchContrib::Index;
    my $indexer = Foswiki::Contrib::KinoSearchContrib::Index->newUpdateIndex();
    my @topicsToUpdate = ($topic);
    $indexer->removeTopics( $web, @topicsToUpdate );
    $indexer->addTopics( $web, @topicsToUpdate );
}

1;
__END__
This copyright information applies to the KinoSearchPlugin:

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# KinoSearchPlugin is # This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the root of this distribution.
