# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

=pod

---+ package Foswiki::Plugins::MongoDBPlugin


=cut

package Foswiki::Plugins::MongoDBPlugin;

BEGIN {

    #print STDERR ">>><<<****** starting MongoDBPlugin..\n";
}

# Always use strict to enforce variable scoping
use strict;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use Assert;
use Exporter 'import';
our @EXPORT_OK = qw(writeDebug);

# Track every object including where they're created
#use Devel::Leak::Object qw{ GLOBAL_bless };
#$Devel::Leak::Object::TRACKSOURCELINES = 1;

our $VERSION = '$Rev: 5771 $';
our $RELEASE = '1.1.1';
our $SHORTDESCRIPTION =
'MongoDB is a scalable, high-performance, open source, schema-free, document-oriented database. ';
our $NO_PREFS_IN_TOPIC = 1;
our $pluginName        = 'MongoDBPlugin';

#this can also be disabled by the listener
our $enableOnSaveUpdates = 0;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)


=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    $enableOnSaveUpdates =
      $Foswiki::cfg{Plugins}{$pluginName}{EnableOnSaveUpdates} || 0;

    $Foswiki::Func::SESSION->{MongoDB}->{lastQueryTime} = ();

    #SMELL: ew
    #TODO: this sets our Global Connextion into the session :(
    getMongoDB();

    Foswiki::Func::registerTagHandler( 'MONGODB', \&_MONGODB );
    Foswiki::Func::registerRESTHandler( 'update',         \&_update );
    Foswiki::Func::registerRESTHandler( 'updateDatabase', \&_updateDatabase );

    return 1;
}

=begin TML

---++ earlyInitPlugin()

This handler is called before any other handler, and before it has been
determined if the plugin is enabled or not. Use it with great care!

If it returns a non-null error string, the plugin will be disabled.

=cut

sub earlyInitPlugin {
    ## Foswiki 2.0 Store Listener now used all the time
    $Foswiki::Plugins::SESSION->{store}
      ->setListenerPriority( 'Foswiki::Plugins::MongoDBPlugin::Listener', 1 );

    return undef;
}

=begin TML

---++ completePageHandler($html, $httpHeaders)

add another Header element to simplify performance testing

=cut

sub completePageHandler {

    #    my( $html, $httpHeaders ) = @_;
    #    # modify $_[0] or $_[1] if you must change the HTML or headers
    #    # You can work on $html and $httpHeaders in place by using the
    #    # special perl variables $_[0] and $_[1]. These allow you to operate
    #    # on parameters as if they were passed by reference; for example:
    #    # $_[0] =~ s/SpecialString/my alternative/ge;
    my $queryTimes = 'noQuery';
    my $timeArray  = getMongoDB()->{lastQueryTime};
    $queryTimes = join( ', ', @$timeArray ) if ( defined($timeArray) );
    $Foswiki::Plugins::SESSION->{response}
      ->pushHeader( 'X-Foswiki-Monitor-MongoDBPlugin-lastQueryTime',
        $queryTimes );

}

################################################################################################################
sub getMongoDB {
    if ( not defined( $Foswiki::Func::SESSION->{MongoDB} ) ) {
        require Foswiki::Plugins::MongoDBPlugin::DB;

        #need to remove undes username and pwd
        delete $Foswiki::cfg{MongoDBPlugin}{username}
          if ( defined( $Foswiki::cfg{MongoDBPlugin}{username} )
            and $Foswiki::cfg{MongoDBPlugin}{username} eq '' );
        delete $Foswiki::cfg{MongoDBPlugin}{password}
          if ( defined( $Foswiki::cfg{MongoDBPlugin}{password} )
            and $Foswiki::cfg{MongoDBPlugin}{password} eq '' );
        delete $Foswiki::cfg{MongoDBPlugin}{database}
          if ( defined( $Foswiki::cfg{MongoDBPlugin}{database} )
            and $Foswiki::cfg{MongoDBPlugin}{database} eq '' );
        delete $Foswiki::cfg{MongoDBPlugin}{port};    #deprecated

        my $mongoDB = new Foswiki::Plugins::MongoDBPlugin::DB(
            { cfg => $Foswiki::cfg{MongoDBPlugin} } );
    }
    return $Foswiki::Func::SESSION->{MongoDB};
}

#restHandler used to update the requested web.
sub _update {
    my $session = shift;
    my $query   = Foswiki::Func::getCgiQuery();

    my $webParam = $query->param('updateweb') || 'Sandbox';
    my $recurse =
      Foswiki::Func::isTrue( $query->param('recurse'), ( $webParam eq 'all' ) );
    my $importTopicRevisions =
      Foswiki::Func::isTrue( $query->param('revision'), 1 );
    my $fork = Foswiki::Func::isTrue( $query->param('fork'), 0 );

    my @webNames;
    if ($recurse) {

        if ( $webParam eq 'all' ) {
            $webParam = undef;
        }
        @webNames = Foswiki::Func::getListOfWebs( '', $webParam );
    }
    unshift( @webNames, $webParam ) if ( defined($webParam) );

    my $result = "\n importing: \n";
    foreach my $web (@webNames) {
        $web =~ s/\/$//;
        $web =~ s/^\///;
        if ($fork) {
            my @topicList = Foswiki::Func::getTopicList($web);
            print STDERR
"FORKING a new /MongoDBPlugin/update for $web ($#topicList) -revision=$importTopicRevisions\n";
            my $cmd =
"time ./rest /MongoDBPlugin/update -updateweb=$web  -revision=$importTopicRevisions -recurse=0";
            $cmd =~ /^(.*$)/;
            $cmd = $1;
            print STDERR `$cmd 2>&1`;
        }
        else {
            $result .= updateWebCache( $web, $importTopicRevisions );
        }

        #Devel::Leak::Object::status();
    }
    return $result . "\n\n";
}

sub updateWebCache {
    my $web                  = shift;
    my $importTopicRevisions = shift;
    $importTopicRevisions = 1 unless ( defined($importTopicRevisions) );

    my $result = '';

    my $query   = Foswiki::Func::getCgiQuery();
    my $session = $Foswiki::Plugins::SESSION;

    if ( not getMongoDB()->databaseNameSafeToUse($web) ) {
        print STDERR
"ERROR: sorry, $web cannot be cached to MongoDB as there is another web with the same spelling, but different case already cached\n";
        return
"ERROR: sorry, $web cannot be cached to MongoDB as there is another web with the same spelling, but different case already cached\n";
    }

#we need to deactivate any listeners :/ () at least stop the loadTopic one from triggering
    $session->{store}
      ->setListenerPriority( 'Foswiki::Plugins::MongoDBPlugin::Listener', 0 );

    #lets make sure we have the javascript we'll rely on later
    _updateDatabase( $session, $web, $query );

    my @topicList = Foswiki::Func::getTopicList($web);
    print STDERR "start web: $web ($#topicList) -> "
      . getMongoDB()->getDatabaseName($web) . "\n";

    my $count     = 0;
    my $rev_count = 0;
    foreach my $topic (@topicList) {
        my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

        #top revision
        _updateTopic( $web, $topic, $meta, { history_only => 0 } );

        if ($importTopicRevisions) {

#TODO: if $rev isn't == 1, then need to go thhrough the history and load that too.
            my $rev = $meta->getRevisionInfo()->{version};
            while ( --$rev > 0 ) {
                $rev_count++;
                ( $meta, $text ) =
                  Foswiki::Func::readTopic( $web, $topic, $rev );

                #add a new entry into the versions collection too
                _updateTopic( $web, $topic, $meta, { history_only => 1 } );

                #make sure we're chatty enough so apache doesn't timeout
                print STDERR "imported r$rev of $web.$topic\n"
                  if ( ( $rev_count % 50 ) == 0 );
            }
        }

        $meta->finish();
        undef $meta;

        $count++;
        print STDERR "imported $count\n" if ( ( $count % 1000 ) == 0 );
    }
    print STDERR "imported $count.$rev_count\n";
    $result .= $web . ': ' . $count . '.' . $rev_count . "\n";

    $session->{store}
      ->setListenerPriority( 'Foswiki::Plugins::MongoDBPlugin::Listener', 1 );

    return $result;
}

sub _remove {
    my $web        = shift;
    my $topic      = shift;
    my $attachment = shift;

    my $query = {};
    $query->{'_topic'} = $topic if ( defined($topic) );

    #attachment not implemented
    return if ( defined($attachment) );

    my $ret = getMongoDB()->remove( $web, 'current', $query );

}

sub _updateTopic {
    my $web              = shift;
    my $topic            = shift;
    my $savedMeta        = shift;
    my $options          = shift;
    my $MongoDB          = getMongoDB();
    my $mongo_collection = $MongoDB->_getCollection( $web, 'current' );

    #print STDERR "-update($web, $topic)\n" if DEBUG;
    $savedMeta->getRev1Info('createdate');

    my $meta = {
        _web   => $web,
        _topic => $topic
    };

    $MongoDB->ensureMandatoryIndexes($mongo_collection);
    foreach my $key ( keys(%$savedMeta) ) {

        #        print STDERR "------------------ importing $key - "
        #          . ref( $savedMeta->{$key} ) . "\n";
        next if ( $key eq '_session' );

#not totally sure if there's a benefit to using / not the _indices
#TODO: but if I don't use it here, I need to re-create it when loading Meta (and I'm not yet doing that)
        next if ( $key eq '_indices' );

#TODO: as of Oct 2010, mongodb can't sort on an element in an array, so we de-array the ARRAYs.
#TODO: use the registered list of META elements, and the type that is registered.
        if ( $Foswiki::Meta::isArrayType{$key} ) {

            #print STDERR "---- $key == many\n";
            my $FIELD = $savedMeta->{$key};
            $meta->{$key} = { '__RAW_ARRAY' => $FIELD };

            foreach my $elem (@$FIELD) {
                if ( $key eq 'FIELD' ) {

#TODO: move this into the search algo, so it makes an index the first time someone builds an app that sorts on it.
#even then, we have a hard limit of 40 indexes, so we're going to have to get more creative.
#mind you, we don't really need indexes for speed, just to cope with query() resultsets that contain more than 1Meg of documents - so maybe we can delay creation until that happens?
                    $MongoDB->ensureIndex(
                        $mongo_collection,
                        { $key . '.' . $elem->{name} . '.value' => 1 },
                        { name => $key . '.' . $elem->{name} }
                    );
                }

                $meta->{$key}{ $elem->{name} } = $elem if defined $elem->{name};
            }
        }
        else {
            if ( ref( $savedMeta->{$key} ) eq '' ) {

                #print STDERR "-A---$key - " . ref( $savedMeta->{$key} ) . "\n";
                $meta->{$key} = $savedMeta->{$key};
            }
            else {
                if ( $key eq '_indices' ) {

                    #print STDERR "-indicies---($web . $topic) $key\n";
                    $meta->{$key} = $savedMeta->{$key};
                    next;
                }
                if ( ref( $savedMeta->{$key} ) ne 'ARRAY' ) {

  #i don't know why, but this is never triggered, but without it, i get a crash.
  #so, i presume there is a weird case where it happens
  #print STDERR "-B---($web . $topic) $key - "
  #  . ref( $savedMeta->{$key} ) . "\n";

#print STDERR Dumper($savedMeta->{$key})."\n";
#print STDERR "\n######################################################## BOOOOOOOOM\n";
                    if ( $key eq '_getRev1Info' ) {
                        $key = 'CREATEINFO';
                        $meta->{'CREATEINFO'} =
                          $savedMeta->{_getRev1Info}->{rev1info};

                        #lets numericafy them
                        $meta->{'CREATEINFO'}->{version} =
                          int( $meta->{'CREATEINFO'}->{version} );
                        $meta->{'CREATEINFO'}->{date} =
                          int( $meta->{'CREATEINFO'}->{date} );

#use Data::Dumper;
#print STDERR "$topic: ".(defined($savedMeta->{'TOPICINFO'}[0]->{version})?($savedMeta->{'TOPICINFO'}[0]->{version}):'undef')." ".Dumper($meta->{'CREATEINFO'})."\n";
                    }

                    next;
                }

#shorcut version of the foreach below because atm, we know there is only one element in the array.
                $meta->{$key} = $savedMeta->{$key}[0];

                #print STDERR "-C---($web . $topic) $key - ";
                #print STDERR Dumper( $meta->{$key}) . "\n";

                if ( $key eq 'TOPICINFO' ) {

#TODO: foswiki's sort by TOPICINFO.author sorts by WikiName, not CUID - so need to make an internal version of this
# to support sort=editby => 'TOPICINFO._authorWikiName',
                    $meta->{'TOPICINFO'}->{_authorWikiName} =
                      Foswiki::Func::getWikiName( $meta->{$key}->{author} );

#Item10611: Paul found that the date, rev and version TOPICINFO is sometimes a string and other times a number
#rectify to always a string atm
                    $meta->{'TOPICINFO'}->{version} =
                      defined $meta->{'TOPICINFO'}->{version}
                      ? int( $meta->{'TOPICINFO'}->{version} )
                      : 1;
                    $meta->{'TOPICINFO'}->{date} =
                      defined $meta->{'TOPICINFO'}->{date}
                      ? int( $meta->{'TOPICINFO'}->{date} )
                      : 0;
                    $meta->{'TOPICINFO'}->{rev} =
                      defined $meta->{'TOPICINFO'}->{rev}
                      ? int( $meta->{'TOPICINFO'}->{rev} )
                      : 1;
                }
            }
        }
    }

    #workaround for Item10675 - a not-foswiki .txt file
    if ( not defined( $meta->{'TOPICINFO'} ) ) {
        $meta->{'TOPICINFO'}->{version}         = 1;
        $meta->{'TOPICINFO'}->{date}            = 0;
        $meta->{'TOPICINFO'}->{rev}             = 1;
        $meta->{'TOPICINFO'}->{author}          = 'BaseUserMapping_999';
        $meta->{'TOPICINFO'}->{_authorWikiName} = 'UnknownUser';
    }
    $meta->{'TOPICINFO'}->{rev} = 1
      if ( !defined $meta->{'TOPICINFO'}{rev}
        || $meta->{'TOPICINFO'}{rev} < 1 );
    $meta->{'TOPICINFO'}->{version} = 1
      if ( !defined $meta->{'TOPICINFO'}{version}
        || $meta->{'TOPICINFO'}{version} < 1 );

    $meta->{_raw_text} = $savedMeta->getEmbeddedStoreForm();

    #force the prefs to be loaded.
    $savedMeta->getPreference('ALLOWME');
    my %ACLProfiles;
    foreach my $mode ( $savedMeta->{_preferences}->prefs() ) {
        next unless ( $mode =~ /^(ALLOW|DENY)/ );

        #$meta->_updatefilecache( $savedMeta, $mode, 1 );
        my $rawACL_list =
          $savedMeta->{_session}->access->_getACL( $savedMeta, $mode );

#print STDERR "-- getACL($web, $topic) $mode ".($force?'FORCE':'noforce')." -> ".(defined($rawACL_list)?join(',', @$rawACL_list):'undef')."\n";

        if ( defined($rawACL_list) ) {
            my $sortedACL_list = join( ',', sort( @{$rawACL_list} ) );
            my $aclProfileHash = md5_hex($sortedACL_list);
            $meta->{'_ACL'}->{$mode}        = $sortedACL_list;
            $meta->{'_ACLProfile'}->{$mode} = $aclProfileHash;

            $ACLProfiles{$aclProfileHash}{_id}  = $aclProfileHash;
            $ACLProfiles{$aclProfileHash}{list} = $sortedACL_list;
            $ACLProfiles{$aclProfileHash}{$mode} =
              $sortedACL_list;    #tells us which mode its for..
        }
    }
    $meta->{'_ACLProfile_ALLOWTOPICVIEW'} =
      $meta->{'_ACLProfile'}->{'ALLOWTOPICVIEW'} || 'UNDEFINED';
    $meta->{'_ACLProfile_DENYTOPICVIEW'} =
      $meta->{'_ACLProfile'}->{'DENYTOPICVIEW'} || 'UNDEFINED';

#save the profiles used in this web, so that foreach search we do, we can pre-test for the user's ALLOW&DENY and go from there.
#TODO: drop this collection so we don't have old stuff in it
    foreach my $profileHash ( keys(%ACLProfiles) ) {

#my $ret = getMongoDB()->update( $web, 'ACLProfiles', $profileHash, $ACLProfiles{$profileHash}, 0);
        my $collection = getMongoDB()->_getCollection( $web, 'ACLProfiles' );
        $collection->update(
            { _id => $profileHash },
            $ACLProfiles{$profileHash},
            { upsert => 1, safe => 1 }
        );

#$collection->update({_id=>$profileHash}, $ACLProfiles{$profileHash}, {upsert=>1, safe=>1});
    }

    my $ret =
      getMongoDB()
      ->update( $web, 'current', "$web.$topic", $meta,
        $options->{history_only} || 0 );

    #need to clean up meta obj
    #TODO: clearly, I need to do a deep copy above :(
    delete $meta->{TOPICINFO}->{_authorWikiName};
}

#to be used by mongodbsearch to be able to add ACL to the query
#resultant query will be something like
#and ((_ACLProfile.ALLOWTOPICVIEW: $notdefined OR _ACLProfile.ALLOWTOPICVIEW: $in(userIsIn)) AND (_ACLProfile.DENYTOPICVIEW: $notdefined OR _ACLProfile.DENYTOPICVIEW: $NOTin(userIsIn)))
#and then have to work out how to mix in the web ACL's - but those are a constant (for each query)...
##SADLY> if I where to change what I write to the DB so that rather than ALLOWTOPICVIEW == undefined means there is no value, but instead I wrote ALLOWTOPICVIEW: 'UNDEF', then the query would be simpler:
### ((_ACLProfile.ALLOWTOPICVIEW: $in(userIsIn, UNDEF)) AND (_ACLProfile.DENYTOPICVIEW: $NOTin(userIsIn)))
### this is not worth doing for the other ACL's, as they're not used implicitly for searches.... so i'm better off making an ACLSEarchProfiles field extra..
sub getACLProfilesFor {
    my $cUID    = shift;
    my $web     = shift;
    my $session = shift || $Foswiki::Func::SESSION;

    my %userIsIn;

    #my $collection = getMongoDB()->_getCollection($web, 'ACLProfiles');
    my $cursor = getMongoDB()->query( $web, 'ACLProfiles', {} );
    while ( my $obj = $cursor->next ) {

        #{_id=>, list=>, ALLOWTOPICVIEW=> DENYTOPICVIEW=>}
        foreach my $mode (qw/ALLOWTOPICVIEW DENYTOPICVIEW/) {
            if ( defined( $obj->{$mode} ) ) {
                if (
                    $session->{users}->isInUserList( $cUID, [ $obj->{list} ] ) )
                {
                    $userIsIn{ $obj->{_id} } = 1;

                    #print STDERR "$cUID is in ".$obj->{list}."\n";
                }
                else {

                    #print STDERR "$cUID is not in ".$obj->{list}."\n";
                }
            }
        }
    }
    my @list = keys(%userIsIn);

    #print STDERR "---- getACLProfilesFor($cUID, $web) ".join(',',@list)."\n";

    return \@list;
}

#restHandler used to update the javascript saved in MongoDB
sub _updateDatabase {
    my $session = shift;
    my $query   = Foswiki::Func::getCgiQuery();

    #TODO: actually, should do all webs if not specified..
    my $web = shift;
    if ( not defined($web) or ( $web eq 'MongoDBPlugin' ) ) {
        my $count = 0;

        #do all webs..
        my @webNames = Foswiki::Func::getListOfWebs( '', undef );
        foreach $web (@webNames) {
            $count += _updateDatabase( $session, $web );
        }
        return $count;
    }

    #print STDERR "loading js into $web\n";

    Foswiki::Func::loadTemplate('mongodb_js');
    my $foswiki_d2n_js = Foswiki::Func::expandTemplate('foswiki_d2n_js');
    getMongoDB()->updateSystemJS( $web, 'foswiki_d2n', $foswiki_d2n_js );

    my $foswiki_getRef_js = Foswiki::Func::expandTemplate('foswiki_getRef_js');
    getMongoDB()->updateSystemJS( $web, 'foswiki_getRef', $foswiki_getRef_js );

    my $foswiki_getField_js =
      Foswiki::Func::expandTemplate('foswiki_getField_js');
    getMongoDB()
      ->updateSystemJS( $web, 'foswiki_getField', $foswiki_getField_js );

    my $foswiki_toLowerCase_js =
      Foswiki::Func::expandTemplate('foswiki_toLowerCase_js');
    getMongoDB()
      ->updateSystemJS( $web, 'foswiki_toLowerCase', $foswiki_toLowerCase_js );

    my $foswiki_toUpperCase_js =
      Foswiki::Func::expandTemplate('foswiki_toUpperCase_js');
    getMongoDB()
      ->updateSystemJS( $web, 'foswiki_toUpperCase', $foswiki_toUpperCase_js );

    my $foswiki_length_js = Foswiki::Func::expandTemplate('foswiki_length_js');
    getMongoDB()->updateSystemJS( $web, 'foswiki_length', $foswiki_length_js );

    my $foswiki_normaliseTopic_js =
      Foswiki::Func::expandTemplate('foswiki_normaliseTopic_js');
    getMongoDB()
      ->updateSystemJS( $web, 'foswiki_normaliseTopic',
        $foswiki_normaliseTopic_js );

    my $foswiki_getDatabaseName_js =
      Foswiki::Func::expandTemplate('foswiki_getDatabaseName_js');
    getMongoDB()
      ->updateSystemJS( $web, 'foswiki_getDatabaseName',
        $foswiki_getDatabaseName_js );

    return 1;
}

# The function used to handle the %EXAMPLETAG{...}% macro
# You would have one of these for each macro you want to process.
sub _MONGODB {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

 #    # $session  - a reference to the Foswiki session object (if you don't know
 #    #             what this is, just ignore it)
 #    # $params=  - a reference to a Foswiki::Attrs object containing
 #    #             parameters.
 #    #             This can be used as a simple hash that maps parameter names
 #    #             to values, with _DEFAULT being the name for the default
 #    #             (unnamed) parameter.
 #    # $theTopic - name of the topic in the query
 #    # $theWeb   - name of the web in the query
 #    # Return: the result of processing the macro. This will replace the
 #    # macro call in the final text.
 #
 #    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
 #    # $params->{_DEFAULT} will be 'hamburger'
 #    # $params->{sideorder} will be 'onions'

    my $webToShow = $params->{_DEFAULT} || 'Sandbox';

    return getMongoDB()->_MONGODB(
        {
            web => $webToShow,    #'Lauries/GlossaryData',

            #SMELL: ok, so i'm passing all sorts of stuff
            %$params              #over-ride the defaults
        }
    );
}

sub writeDebug {
    my ( $msg, $level ) = @_;
    my ( $package, $filename, undef, $subroutine ) = caller(1);
    my ( undef, undef, $line ) = caller(0);
    ( undef, undef, $filename ) = File::Spec->splitpath($filename);
    my @pack       = split( '::', $subroutine );
    my $abbr       = '';
    my $context    = Foswiki::Func::getContext();
    my $requestObj = Foswiki::Func::getRequestObject();

    ( undef, undef, $filename ) = File::Spec->splitpath($filename);
    if ( $pack[0] eq 'Foswiki' ) {
        $abbr = '::';
        shift(@pack);
        if ( $pack[0] eq 'Plugins' || $pack[0] eq 'Contrib' ) {
            shift(@pack);
        }
    }
    $abbr .= join( '::', @pack ) . '():' . $line;
    if ( $filename !~ /^$pack[-2]\.pm$/ ) {
        $abbr .= " in $filename";
    }
    $msg = "$abbr:\t$msg";
    if (   !defined $context
        || $requestObj->isa('Unit::Request')
        || $context->{command_line} )
    {
        print STDERR $msg . "\n";
        ASSERT( !defined $level || $level =~ /^[-]?\d+$/ ) if DEBUG;
    }
    else {
        Foswiki::Func::writeDebug($msg);
        if ( defined $level ) {
            ASSERT( $level =~ /^[-]?\d+$/ ) if DEBUG;
            if ( $level == -1 ) {
                Foswiki::Func::writeWarning($msg);
                print STDERR $msg . "\n";
            }
        }
    }

    return;
}

1;
__END__
This copyright information applies to the MongoDBPlugin:

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright 2010 - SvenDowideit@fosiki.com
#
# MongoDBPlugin is # This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the root of this distribution.
