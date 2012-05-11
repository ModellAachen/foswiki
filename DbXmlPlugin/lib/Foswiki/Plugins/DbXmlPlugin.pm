# Plugin for Foswiki Collaboration Platform, http://foswiki.org/
#
# Copyright (C) 2005-2007 Oliver Krueger, oliver@wiki-one.net
# Copyright (C) 2004-2005 Patrick Diamond, patrick_diamond@mailc.net
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

# =========================
package Foswiki::Plugins::DbXmlPlugin;

use Foswiki;
use Foswiki::Func;
use Sleepycat::DbXml 'simple';
use XML::Simple;         # TODO: handle non-existence
use Text::ParseWords;    # TODO: handle non-existence

# =========================
use strict;
use vars qw(
  $web $topic $user $installWeb $VERSION $pluginName
  $debug $initialized $workingPath $NO_PREFS_IN_TOPIC $RELEASE
  $DBXMLENV $DBXMLMGR
);

$VERSION           = '$Rev$';
$RELEASE           = '1.1';
$NO_PREFS_IN_TOPIC = 1;
$pluginName        = 'DbXmlPlugin';
$initialized       = 0;

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Prepare some vars and configs
    $debug = $Foswiki::cfg{Plugins}{DbXmlPlugin}{Debug} || '0';
    my $allowRawXMLview = $Foswiki::cfg{Plugins}{DbXmlPlugin}{AllowRaw} || '0';
    $workingPath = Foswiki::Func::getWorkArea($pluginName)
      || $Foswiki::cfg{DataDir};
    $workingPath =~ s/(.*?)\/$/$1/;    # strip trailing slash if there is one

    # Register some REST functions for direct querying
    Foswiki::Func::registerRESTHandler( 'query',        \&externalQuery );
    Foswiki::Func::registerRESTHandler( 'debug_rawxml', \&externalDebugRawXml )
      if $allowRawXMLview;
    Foswiki::Func::registerRESTHandler( 'renew', \&externalRenewDbXml );

    # Register Tags (see also commonTagHandler)
    Foswiki::Func::registerTagHandler( 'DBXMLQUERY', \&doSingleLineQuery );

    # Plugin correctly initialized
    Foswiki::Func::writeDebug(
        "- Foswiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;

    return 1;
}

# =========================
sub _doLateInit {
    Foswiki::Func::writeDebug("- ${pluginName}::_doLateInit()") if $debug;

    # Get a DbXml Environment ...
    my $counter = 0;
    my $failed  = 0;
    $DBXMLENV = new DbEnv(0);
    $DBXMLENV->set_cachesize( 0, 64 * 1024, 1 );
    $DBXMLENV->set_lk_detect(Db::DB_LOCK_DEFAULT);

    # Open the Environment and react on errors
    do {
        if ($failed) {
            $DBXMLENV->close();
            $failed = 0;
        }
        eval {
            $failed = $DBXMLENV->open( $workingPath,
                Db::DB_INIT_MPOOL | Db::DB_CREATE | Db::DB_INIT_LOCK |
                  Db::DB_INIT_LOG | Db::DB_INIT_TXN );
        };
        if ( my $e = catch std::exception ) { $failed = 1; }
        sleep($counter);
        $counter++;
    } until ( ( not $failed ) or ( $counter > 5 ) );
    if ($failed) {
        Foswiki::Func::writeDebug("- ${pluginName} DBXMLENV->open() failed.");
        throw Foswiki::OopsException(
            'attention',
            def    => 'save_error',
            params => "DBXML: Failed opening environment."
        );
    }

    # ... and a XMLManager
    eval { $DBXMLMGR = new XmlManager($DBXMLENV); };
    if ( my $e = catch XmlException ) {
        Foswiki::Func::writeDebug(
            "- ${pluginName} DBXMLMGR->new() failed. Exiting.");
        throw Foswiki::OopsException(
            'attention',
            def    => 'save_error',
            params => "DBXML: Failed opening xml-manager."
        );
    }

    $initialized = 1;
    return "";
}

# =========================
sub commonTagsHandler {
    Foswiki::Func::writeDebug(
        "- ${pluginName}::commonTagsHandler( $_[2] $_[1] )")
      if $debug;

    $_[0] =~
s/%DBXMLQUERYSTART{(.*?)}%(.*?)%DBXMLQUERYEND%/&doMultiLineQuery($1,$2)/geos;

    return "";
}

# =========================
sub afterSaveHandler {
    Foswiki::Func::writeDebug(
        "- ${pluginName}::afterSaveHandler( $_[2] $_[1] )")
      if $debug;
    my $web = $_[2];

    if ( _checkResponsebilityForWeb($web) ) {

        # create foswiki container if it is not available
        if ( not -e "$workingPath/foswiki.dbxml" ) {
            createAllTopics();
            return "";
        }

        updateTopic( $_[0], $_[1], $_[2] );
    }

    return "";
}

# =========================
sub doMultiLineQuery {

    my $theAttributes = $_[0];
    my $theContainer =
      Foswiki::Func::extractNameValuePair( $theAttributes, "container" )
      || "$workingPath/foswiki.dbxml";
    my $theQuery = $_[1] || "";

    $theQuery =
      Foswiki::Func::expandCommonVariables( $theQuery, $topic, $web, undef );

    return _UTF82SiteCharSet( doQuery( $theQuery, $theContainer ) );
}

# =========================
sub doSingleLineQuery {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    my $theContainer = $params->{"container"} || "$workingPath/foswiki.dbxml";
    my $theQuery     = $params->{"query"}     || "";

    return _UTF82SiteCharSet( doQuery( $theQuery, $theContainer ) );
}

# =========================
sub doQuery {
    Foswiki::Func::writeDebug("- ${pluginName}::doQuery( $_[0], $_[1] )")
      if $debug;

    if ( not $initialized ) { _doLateInit() }

    my $theQuery     = $_[0];
    my $theContainer = $_[1];
    my $retval       = "";

    # test for LOCK file
    if ( -e "$theContainer.lock" ) {
        return
"Lock file detected. Query aborted. While DB creation is in progress, no queries allowed.";
    }

    # open a container in the db environment
    my $containerTxn = $DBXMLMGR->createTransaction();
    my $container = $DBXMLMGR->openContainer( $containerTxn, $theContainer );
    $containerTxn->commit();

    # query the db
    eval {
        my $qryTnx  = $DBXMLMGR->createTransaction();
        my $results = $DBXMLMGR->query( $qryTnx, $theQuery );
        my $value   = new XmlValue();

        while ( $results->next($value) ) {
            $retval .= $value;
        }
        $qryTnx->commit();
    };

    # handle errors
    if ( my $e = catch XmlException ) {
        $retval = "Query $theQuery failed\n";
        $retval .= $e->what() . "\n";
        return $retval;
    }
    elsif ($@) {
        $retval = "Query $theQuery failed\n";
        $retval .= $@;
        return $retval;
    }

    # $DBXMLENV->close;
    # $initialized = 0;

    Foswiki::Func::writeDebug(
        "- ${pluginName}::doQuery retval:\n" . $retval . "\n" )
      if $debug;

    return $retval;
}

# =========================
sub updateTopic {

    Foswiki::Func::writeDebug("- ${pluginName}::updateTopic( $_[1], $_[2] )")
      if $debug;

    my $theText      = $_[0];
    my $theTopic     = $_[1];
    my $theWeb       = $_[2];
    my $theContainer = "$workingPath/foswiki.dbxml";
    my $retval       = "";

    if ( not $initialized ) { _doLateInit() }

    # test for LOCK file
    if ( -e "$theContainer.lock" ) {
        my $text = $theText;
        throw Foswiki::OopsException(
            'attention',
            def    => 'save_error',
            web    => $theWeb,
            topic  => $theTopic,
            params => "DBXML lock file detected. Update failed."
        );
    }

    # open a container in the db environment
    my $containerTxn = $DBXMLMGR->createTransaction();
    my $container =
      $DBXMLMGR->openContainer( $containerTxn, $theContainer, Db::DB_CREATE );
    $containerTxn->commit();

    eval {

        #  Get an XmlUpdateContext. Useful from a performance perspective.
        my $updateContext = $DBXMLMGR->createUpdateContext();

        my $theQuery =
"collection('$theContainer')/data[\@topic='$theTopic'][\@web='$theWeb']";
        my $txn = $DBXMLMGR->createTransaction();
        my $results = $DBXMLMGR->query( $txn, $theQuery );

        my $docExists = $results->size();
        my ( $topicMoved, $movedFromWeb, $movedFromTopic ) =
          _isMoved( $theText, $theTopic, $theWeb );

        # new created topic
        if ( ( not $docExists ) && ( not $topicMoved ) ) {
            Foswiki::Func::writeDebug(
                "- ${pluginName}::updateTopic( new created topic )")
              if $debug;
            my $doc = $DBXMLMGR->createDocument();
            $doc->setContent( generateXML( $theText, $theTopic, $theWeb, 1 ) );
            $container->putDocument( $txn, $doc, $updateContext,
                DbXml::DBXML_GEN_NAME );
        }

        # moved topic
        if ( ( not $docExists ) && ($topicMoved) ) {
            Foswiki::Func::writeDebug(
                "- ${pluginName}::updateTopic( moved topic )")
              if $debug;

            # delete topics old location (OL)
            my $theQueryOL =
"collection('$theContainer')/data[\@topic='$movedFromTopic'][\@web='$movedFromWeb']";
            my $resultsOL = $DBXMLMGR->query( $txn, $theQueryOL );
            my $docOL = $DBXMLMGR->createDocument();
            $resultsOL->next($docOL);
            $container->deleteDocument( $txn, $docOL, $updateContext );

            # create new document
            my $doc = $DBXMLMGR->createDocument();
            $doc->setContent( generateXML( $theText, $theTopic, $theWeb, 1 ) );
            $container->putDocument( $txn, $doc, $updateContext,
                DbXml::DBXML_GEN_NAME );
        }

        # saved existing topic
        if ($docExists) {
            Foswiki::Func::writeDebug(
                "- ${pluginName}::updateTopic( saved existing topic )")
              if $debug;

            # delete old doc
            my $doc = $DBXMLMGR->createDocument();
            $results->next($doc);
            $container->deleteDocument( $txn, $doc, $updateContext );

            # create new document
            $doc = $DBXMLMGR->createDocument();
            $doc->setContent( generateXML( $theText, $theTopic, $theWeb, 1 ) );
            $container->putDocument( $txn, $doc, $updateContext,
                DbXml::DBXML_GEN_NAME );
        }

        $txn->commit();
    };

    # error handling
    if ( my $e = catch XmlException ) {
        $retval = "Query failed\n";
        $retval .= $e->what() . "\n";
        Foswiki::Func::writeDebug(
            "- ${pluginName}::updateTopic - " . $e->what() );
        throw Foswiki::OopsException(
            'attention',
            def    => 'save_error',
            params => "DBXML: Failed writing to XML database."
        );
        return $retval;
    }
    elsif ($@) {
        $retval = "Query failed\n";
        $retval .= $@;
        Foswiki::Func::writeDebug( "- ${pluginName}::updateTopic - " . $@ );
        throw Foswiki::OopsException(
            'attention',
            def    => 'save_error',
            params => "DBXML: Failed writing to XML database."
        );
        return $retval;
    }

    $container->sync();

    # $DBXMLENV->close;
    # $initialized = 0;

    return "$retval";
}

# =========================
sub createAllTopics {

    my @webList;

    if ( $Foswiki::cfg{Plugins}{DbXmlPlugin}{IncludeWeb} =~ m/^default$/ ) {
        @webList = Foswiki::Func::getListOfWebs("user");
    }
    else {
        my $webs = $Foswiki::cfg{Plugins}{DbXmlPlugin}{IncludeWeb};
        $webs =~ s/\s+/ /g;
        @webList = split( /,/, $webs );
    }

    if ( not $initialized ) { _doLateInit() }

    my $theContainer = "$workingPath/foswiki.dbxml";
    my $retval       = "";

    # test for / create LOCK file
    if ( -e "$workingPath/foswiki.dbxml.lock" ) {
        return "Lock file detected. Operation aborted.";
    }
    else {
        open( FILE, ">>$workingPath/foswiki.dbxml.lock" );
        print FILE gmtime() . " GMT";
        close(FILE);
    }

    # open a container in the db environment
    my $containerTxn = $DBXMLMGR->createTransaction();
    my $container =
      $DBXMLMGR->openContainer( $containerTxn, $theContainer, Db::DB_CREATE );
    $containerTxn->commit();

    #  Get an XmlUpdateContext. Useful from a performance perspective.
    my $updateContext = $DBXMLMGR->createUpdateContext();

    # Get a transaction
    my $txn = $DBXMLMGR->createTransaction();

    eval {
        WEBLIST: foreach my $thisWebName (@webList)
        {

            next unless Foswiki::Func::webExists($thisWebName);
            next if ( $thisWebName eq "Trash" );
            next if ( $thisWebName =~ m/^_.*/ );

            my @topicList = Foswiki::Func::getTopicList($thisWebName);
          TOPICLIST: foreach my $thisTopicName (@topicList) {

                # Extract XML stuff from Foswiki topic
                my $myXMLDoc = $DBXMLMGR->createDocument();
                my $text =
                  Foswiki::Func::readTopicText( $thisWebName, $thisTopicName );
                $myXMLDoc->setContent(
                    generateXML( $text, $thisTopicName, $thisWebName, 1 ) );
                $container->putDocument( $txn, $myXMLDoc, $updateContext,
                    DbXml::DBXML_GEN_NAME );
            }
        }
        $txn->commit();

        # start a new transacton for the indices
        $txn = $DBXMLMGR->createTransaction();

        # create Indices for common columns
        $container->addIndex( $txn, "", "web",
            "node-attribute-equality-string" );
        $container->addIndex( $txn, "", "topic",
            "node-attribute-equality-string" );
        $container->addIndex( $txn, "", "author",
            "node-attribute-equality-string" );
        $container->addIndex( $txn, "", "name",
            "node-attribute-presence-none" );
        $container->addIndex( $txn, "", "name",
            "node-attribute-equality-string" );
        $txn->commit();
    };

    if ( my $e = catch XmlException ) {
        Foswiki::Func::writeDebug( "- ${pluginName} " . $e->what() );
        $retval =
"DBXML file creation failed. Please delete ruins in data path manually.\n";
        $retval .= $e->what() . "<br />";
        return $retval;
    }
    elsif ($@) {
        Foswiki::Func::writeDebug( "- ${pluginName} " . $@ );
        $retval =
"DBXML file creation failed. Please delete ruins in data path manually.\n";
        $retval .= $@;
        return $retval;
    }

    $container->sync();

    # $DBXMLENV->close;
    # $initialized = 0;

    # delete lock file
    unlink "$workingPath/foswiki.dbxml.lock";

    return "Done.";
}

# =========================
sub generateXML {
    Foswiki::Func::writeDebug("- ${pluginName}::generateXML  $_[1] $_[2]")
      if $debug;

    # initize vars
    my $xmloutput     = "";
    my $text          = $_[0];
    my $topic         = $_[1];
    my $web           = $_[2];
    my $includePragma = $_[3];
    my $data          = { 'metadata' => {}, 'tables' => {} };

    # extract data
    my $title = _processTitle( $text, $topic, $web );
    my $metadata = _processMetaData( $text, $topic, $web );
    my $preferences = _processPreferences( $text, $topic, $web );
    my $tables = _processTables( $text, $topic, $web );

    # build data structure to generate XML
    my $out;
    $out                        = $data;
    $out->{'metadata'}          = $metadata;
    $out->{'preferences'}       = $preferences;
    $out->{'tables'}            = {};
    $out->{'tables'}->{'table'} = $tables;
    $out->{'web'}               = $web;
    $out->{'topic'}             = $topic;
    $out->{'title'}             = $title;
    $out->{'version'}           = $VERSION;

    # $out->{'date'}                = $metadata->{'topicinfo'}->[0]->{'date'};
    my $page = {};
    $page->{'data'} = $out;

    # It seems, no matter what we put into dbxml, we got UTF-8 back
    $xmloutput = XML::Simple::XMLout( $page, KeepRoot => 1, );
    $out = undef;

    if ($includePragma) {
        $xmloutput = "<?xml version='1.0' encoding='ISO-8859-1'?>" . $xmloutput;
    }

    Foswiki::Func::writeDebug( "- ${pluginName}::generateXML:\n" . $xmloutput )
      if $debug;

    return $xmloutput;
}

sub _processTitle {

    # extract the first header in the text and return it as the header
    my $text  = $_[0];
    my $topic = $_[1];

    Foswiki::Func::writeDebug(
        "Foswiki::Plugins::${pluginName}::_processTitle $web $topic ")
      if $debug;
    my $title = '';

    if ( $text =~ /^--[\-]+[\+]+[\!]*\s*(.*?)$/ms ) {
        $title = $1;
        $title =~ s/^\s*\<nop\>//;      # common prefix not needed now
        $title =~ s/%TOPIC%/$topic/;    # common header not needed now
    }
    return _UTF82SiteCharSet($title);
}

sub _processMetaData {

    # extract META DATA from the topic text
    my $text  = $_[0];
    my $topic = $_[1];
    my $web   = $_[2];
    Foswiki::Func::writeDebug(
        "Foswiki::Plugins::${pluginName}::_processMetaData $web $topic ")
      if $debug;
    my $metadata = {};
    my $reg_m    = '\s*\%META:([A-Z]+)\{(.*)\}\%';

    while ( $text =~ /$reg_m/g ) {
        my ( $metatype, $metaargs ) = ( $1, $2 );
        my $args = _args2hash($metaargs);

        # translate dates to a more parseable format
        if ( exists $args->{'date'} ) {
            my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday ) =
              gmtime( $args->{'date'} );
            $year += 1900;
            $args->{'date'} = sprintf( '%04d-%02d-%02dT%02d:%02d:%02d',
                $year, $mon + 1, $mday, $hour, $min, $sec );
        }

        while ( my ( $key, $value ) = each(%$args) ) {
            if (    ( $key eq "value" )
                and ( $value =~ m/(\d\d)\s(...)\s(\d\d\d\d)/ ) )
            {
                my ( $day, $month, $year ) = ( $1, 0, $3 );
                if ( lc($2) =~ m/jan/ ) { $month = "01"; }
                if ( lc($2) =~ m/feb/ ) { $month = "02"; }
                if ( lc($2) =~ m/m.r/ ) { $month = "03"; }
                if ( lc($2) =~ m/apr/ ) { $month = "04"; }
                if ( lc($2) =~ m/ma./ ) { $month = "05"; }
                if ( lc($2) =~ m/jun/ ) { $month = "06"; }
                if ( lc($2) =~ m/jul/ ) { $month = "07"; }
                if ( lc($2) =~ m/aug/ ) { $month = "08"; }
                if ( lc($2) =~ m/sep/ ) { $month = "09"; }
                if ( lc($2) =~ m/o.t/ ) { $month = "10"; }
                if ( lc($2) =~ m/nov/ ) { $month = "11"; }
                if ( lc($2) =~ m/de./ ) { $month = "12"; }
                if ( $month != 0 ) { $args->{'isodate'} = "$year-$month-$day"; }
            }
        }

        if ( exists $args->{'author'} ) {
            $args->{'author'} =~ s/BaseUserMapping_//;
        }

        # unescape quotes and new lines
        foreach my $a ( keys %$args ) {
            $args->{$a} =~ s/\%_N_/\n/g;
            $args->{$a} =~ s/\%_Q_\%/\"/g;
        }

        $metatype = lc($metatype);
        $metadata->{$metatype} = [] if not exists $metadata->{$metatype};
        push @{ $metadata->{$metatype} }, {%$args};
    }

    # if no META:TOPICINFO is given, add an empty template
    # SMELL: beware of TOPICINFO syntax changes
    if ( $text !~ '\s*\%META:TOPICINFO\{.*\}\%' ) {
        my $args = _args2hash(
'author="ProjectContributor" date="1970-01-01T00:00:00" format="1.1" version="0"'
        );
        push @{ $metadata->{"topicinfo"} }, {%$args};
    }

    return _UTF82SiteCharSet($metadata);
}

sub _processPreferences {

    my $prefs = {};

    my $topic = $_[1];
    my $web   = $_[2];
    my $text  = $_[0];

    my $key   = '';
    my $value = '';
    my $type;

    #                 1             2           3
    #^(?:\t|   )+\*\s+(Set|Local)\s+(\w+)\s*=\s*(.*)$

    foreach my $line ( split( /\r?\n/, $text ) ) {
        if ( $line =~ m/$Foswiki::regex{setVarRegex}/o ) {
            if ($type) {
                my $lctype = lc($type);
                $prefs->{$lctype} = [] if not exists $prefs->{$lctype};
                my $args;
                $args->{$key} = [$value];
                push @{ $prefs->{$lctype} }, {%$args};
            }
            $type  = $1;
            $key   = lc($2);
            $value = ( defined $3 ) ? $3 : '';
        }
        elsif ($type) {
            if (   $line =~ /^(\s{3}|\t)+\s*[^\s*]/
                && $line !~ m/$Foswiki::regex{bulletRegex}/o )
            {

                # follow up line, extending value
                $value .= "\n$line";
            }
            else {
                my $lctype = lc($type);
                $prefs->{$lctype} = [] if not exists $prefs->{$lctype};
                my $args;
                $args->{$key} = [$value];
                push @{ $prefs->{$lctype} }, {%$args};
                undef $type;
            }
        }
    }
    if ($type) {
        my $lctype = lc($type);
        $prefs->{$lctype} = [] if not exists $prefs->{$lctype};
        my $args;
        $args->{$key} = [$value];
        push @{ $prefs->{$lctype} }, {%$args};
    }

    return _UTF82SiteCharSet($prefs);
}

sub _processTables {

    # extract table data from the topic text
    my $text  = $_[0];
    my $topic = $_[1];
    my $web   = $_[2];
    Foswiki::Func::writeDebug(
        "Foswiki::Plugins::${pluginName}::_processTables $web $topic ")
      if $debug;
    my $state  = '';
    my $i      = -1;
    my $row    = -1;
    my $tables = [];
    foreach my $line ( split /\n/, $text ) {

        if ( $line =~ /^\s*\%(EDITTABLE|TABLE)\{(.*?)\}\%/ ) {

            # Table defined using EDITTABLE or TABLE macro
            my $t_type = $1;
            my $t_args = $2;
            $i++;    # new table
            $row = -1;
            $t_args =~ s/(format=[\"\'](.*?)[^\\][\'\"])//ig;    #
            $t_args =~ s/(^\s*,\s*)//;                           #

            my $args = _args2hash($t_args);
            $tables->[$i] = $args if defined $args;
            $tables->[$i]->{'type'} = $t_type;
            $tables->[$i]->{'row'}  = [];
            $state                  = 'table';
        }
        elsif ( $line =~ /^\s*\|/ ) {
            if ( $state ne 'table' ) {
                $i++;                                            # new table
                $row                   = -1;
                $tables->[$i]->{'row'} = [];
                $state                 = 'table';
            }
            $row++;

            $tables->[$i]->{'row'}->[$row] = { 'field' => [] };
            $line =~ s/^\s*\|//;    # strip leading |
            $line =~ s/\|\s*$//;    # strip trailing |
            my @args = split /\|/, $line;
            $a = -1;
            ############################
            # process each cell in a row
            foreach my $arg (@args) {
                my $header = 0;
                $a++;
                $arg =~ s/^\s+//;    # strip leading spaces
                $arg =~ s/\s+$//;    # strip trailing spaces
                if ( $arg =~ /^(.*)\s*\%EDITCELL\{.*\}\%\s*$/i ) {
                    $arg = $1;       # strip EDITCELL tags from cell
                }

                if ( $arg =~ /^(\s*\*\s*)(.*)(\s*\*\s*)/ ) {
                    $header = 1;     # flag cell as header
                    $arg    = $2;
                }

                $tables->[$i]->{'row'}->[$row]->{'field'}->[$a] = {};
                $tables->[$i]->{'row'}->[$row]->{'field'}->[$a]->{'content'} =
                  $arg;
                if ($header) {
                    $tables->[$i]->{'row'}->[$row]->{'field'}->[$a]->{'type'} =
                      'title';
                }
                else {
                    $tables->[$i]->{'row'}->[$row]->{'field'}->[$a]->{'type'} =
                      'data';
                }
            }
        }
        else {
            $state = '';
        }
    }
    return _UTF82SiteCharSet($tables);
}

sub _isMoved {

    my $theText  = $_[0];
    my $theTopic = $_[1];
    my $theWeb   = $_[2];

    if ( $theText =~ /\s*\%META:TOPICMOVED\{(.*)\}\%/g ) {

        my $args = _args2hash($1);
        my ( $toWeb, $toTopic ) =
          Foswiki::Func::normalizeWebTopicName( "", $args->{'to'} );

# due to TWiki:Bugs.Item3491 we have to check if the moved-meta-info concerns this topic
        if ( $toWeb == $theWeb && $toTopic == $theTopic ) {

           # if the prior place of the topic is empty, this topic might be moved
           # SMELL: this assumption is not very "exact"
            if ( not Foswiki::Func::topicExists( $args->{'from'} ) ) {
                my ( $fromWeb, $fromTopic ) =
                  Foswiki::Func::normalizeWebTopicName( "", $args->{'from'} );
                return ( 1, $fromWeb, $fromTopic );
            }
        }
    }

    return ( 0, "", "" );

}

sub _args2hash {

    # convert a list of arguments as found in a foswiki macro into a hash
    # a named set of parameters is allowed to have multiple instances
    my ($string) = @_;

    # record the set of allowed duplicates
    my %dups;
    foreach (@_) {
        $dups{$_} = 1;
    }

    $string =~ s/^\s*//;    # strip leading spaces
    $string =~ s/\s*$//;    # strip trailing spaces

    # extact values
    my $h;
    my @e = &Text::ParseWords::quotewords( '(\s+|\s*\=\s*)', 1, $string );
    while (@e) {

        # extract the key and value pair
        my $key = shift(@e);
        last if not @e;
        my $value = shift(@e);

        # strip leading and trailing spaces & quotes from arg values
        $value =~ s/^[\s\"\']*//;
        $value =~ s/[\s\"\']*$//;

        # if duplicates are allowed on this key then the values
        # are always stored as an array
        if ( exists $dups{$key} ) {
            if ( exists $h->{$key} ) {
                push @{ $h->{$key} }, $value;
            }
            else {
                $h->{$key} = [$value];
            }
        }
        else {
            $h->{$key} = $value;
        }
    }
    return $h;
}

sub _UTF82SiteCharSet {
    my ($text) = @_;
    my %regex;

    ## copied from Foswiki.pm
    ##
    ## in comparison to original, this function returns $text (not undef)
    ## if no UTF8 detected

    # 7-bit ASCII only
    $regex{validAsciiStringRegex} = qr/^[\x00-\x7F]+$/o;

    # Regex to match only a valid UTF-8 character, taking care to avoid
    # security holes due to overlong encodings by excluding the relevant
    # gaps in UTF-8 encoding space - see 'perldoc perlunicode', Unicode
    # Encodings section.  Tested against Markus Kuhn's UTF-8 test file
    # at http://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt.
    $regex{validUtf8CharRegex} = qr{
                # Single byte - ASCII
                [\x00-\x7F]
                |

                # 2 bytes
                [\xC2-\xDF][\x80-\xBF]
                |

                # 3 bytes

                    # Avoid illegal codepoints - negative lookahead
                    (?!\xEF\xBF[\xBE\xBF])

                    # Match valid codepoints
                    (?:
                    ([\xE0][\xA0-\xBF])|
                    ([\xE1-\xEC\xEE-\xEF][\x80-\xBF])|
                    ([\xED][\x80-\x9F])
                    )
                    [\x80-\xBF]
                |

                # 4 bytes
                    (?:
                    ([\xF0][\x90-\xBF])|
                    ([\xF1-\xF3][\x80-\xBF])|
                    ([\xF4][\x80-\x8F])
                    )
                    [\x80-\xBF][\x80-\xBF]
                }xo;

    $regex{validUtf8StringRegex} = qr/^ (?: $regex{validUtf8CharRegex} )+ $/xo;

    # Detect character encoding of the full topic name from URL
    return $text if ( $text =~ $regex{validAsciiStringRegex} );

    Foswiki::Func::writeDebug(
        "- ${pluginName}::_UTF82SiteCharSet: not valid ASCII.")
      if $debug;

# If not UTF-8 - assume in site character set, no conversion required
# return $text unless( $text =~ $regex{validUtf8StringRegex} );
# Foswiki::Func::writeDebug("Foswiki::Plugins::${pluginName}::_UTF82SiteCharSet: valid UTF-8.");

    # If site charset is already UTF-8, there is no need to convert anything:
    if ( $Foswiki::cfg{Site}{CharSet} =~ /^utf-?8$/i ) {

        # warn if using Perl older than 5.8
        if ( $] < 5.008 ) {
            Foswiki::Func::writeWarning( 'UTF-8 not supported on Perl ' 
                  . $]
                  . ' - use Perl 5.8 or higher..' );
        }

        # SMELL: is this true yet?
        Foswiki::Func::writeWarning( 'UTF-8 not yet supported as site charset -'
              . 'Foswiki is likely to have problems' );
        return $text;
    }

    Foswiki::Func::writeDebug(
        "- ${pluginName}::_UTF82SiteCharSet: siteChar is not UTF-8.")
      if $debug;

    # Convert into ISO-8859-1 if it is the site charset
    if ( $Foswiki::cfg{Site}{CharSet} =~ /^iso-?8859-?15?$/i ) {

        # ISO-8859-1 maps onto first 256 codepoints of Unicode
        # (conversion from 'perldoc perluniintro')
        Foswiki::Func::writeDebug(
            "- ${pluginName}::_UTF82SiteCharSet: siteChar is iso-8859-1.")
          if $debug;
        $text =~ s/ ([\xC2\xC3]) ([\x80-\xBF]) /
          chr( ord($1) << 6 & 0xC0 | ord($2) & 0x3F )
            /egx;
    }
    else {

        # Convert from UTF-8 into some other site charset
        Foswiki::Func::writeDebug(
            "- ${pluginName}::_UTF82SiteCharSet: converting.")
          if $debug;
        if ( $] >= 5.008 ) {
            require Encode;
            import Encode qw(:fallbacks);

            # Map $Foswiki::cfg{Site}{CharSet} into real encoding name
            my $charEncoding =
              Encode::resolve_alias( $Foswiki::cfg{Site}{CharSet} );
            if ( not $charEncoding ) {
                Foswiki::Func::writeWarning( 'Conversion to "'
                      . $Foswiki::cfg{Site}{CharSet}
                      . '" not supported, or name not recognised - check '
                      . '"perldoc Encode::Supported"' );
            }
            else {

                # Convert text using Encode:
                # - first, convert from UTF8 bytes into internal
                # (UTF-8) characters
                $text = Encode::decode( 'utf8', $text );

                # - then convert into site charset from internal UTF-8,
                # inserting \x{NNNN} for characters that can't be converted
                $text = Encode::encode( $charEncoding, $text, &FB_PERLQQ() );
            }
        }
        else {
            require Unicode::MapUTF8;    # Pre-5.8 Perl versions
            my $charEncoding = $Foswiki::cfg{Site}{CharSet};
            if ( not Unicode::MapUTF8::utf8_supported_charset($charEncoding) ) {
                Foswiki::Func::writeWarning( 'Conversion to "'
                      . $Foswiki::cfg{Site}{CharSet}
                      . '" not supported, or name not recognised - check '
                      . '"perldoc Unicode::MapUTF8"' );
            }
            else {

                # Convert text
                $text = Unicode::MapUTF8::from_utf8(
                    {
                        -string  => $text,
                        -charset => $charEncoding
                    }
                );

                # FIXME: Check for failed conversion?
            }
        }
    }
    return $text;
}

sub _checkResponsebilityForWeb {
    my $web = $_[0];
    my @includedWebs;
    my $retval = 0;

    if ( $Foswiki::cfg{Plugins}{DbXmlPlugin}{IncludeWeb} =~ m/^\s*default\s*$/ )
    {
        @includedWebs = Foswiki::Func::getListOfWebs("user");
    }
    else {
        $Foswiki::cfg{Plugins}{DbXmlPlugin}{IncludeWeb} =~ s/\s+/ /g;
        @includedWebs =
          split( /,/, $Foswiki::cfg{Plugins}{DbXmlPlugin}{IncludeWeb} );
    }

    foreach my $thisWeb (@includedWebs) {
        $thisWeb =~ s/^\s*//g;
        $thisWeb =~ s/\s*$//g;
        if ( $thisWeb eq $web ) { $retval = 1; }
    }

    my $webs = join( ":", @includedWebs ) if $debug;
    Foswiki::Func::writeDebug(
        "- ${pluginName}::_checkResponsebilityForWeb: ($webs) $web $retval")
      if $debug;

    return $retval;
}

sub externalQuery {

    my $cgi           = Foswiki::Func::getCgiQuery();
    my $myContentType = $cgi->param('contenttype') || 'text/xml';
    my $myQuery       = $cgi->param('query')
      || "collection('foswiki.dbxml')/data[\@topic='WebHome'][\@web='Main']";
    my $myContainer = $cgi->param('container') || "foswiki.dbxml";

    print "Content-Type: " . $myContentType . "\n\n";
    print "<?xml version='1.0' encoding='UTF-8'?>\n";
    my $queryresult = doQuery( $myQuery, $myContainer );
    print $queryresult;
    Foswiki::Func::writeDebug(
            "- ${pluginName}::externalQuery output (w/o header): \n"
          . $queryresult
          . "\n" )
      if $debug;

    # SMELL: This is a very untidy behaviour, because we leave
    # the "rest" context opened: $session->leaveContext( 'rest' )
    exit;
    return "";
}

sub externalDebugRawXml {

    my $cgi     = Foswiki::Func::getCgiQuery();
    my $myTopic = $cgi->param('mytopic') || 'WebHome';
    my $myWeb   = $cgi->param('myweb') || 'Main';
    my $myText  = Foswiki::Func::readTopicText( $myWeb, $myTopic );

    print "Content-Type: text/xml\n\n";
    print generateXML( $myText, $myTopic, $myWeb, 0 );

    # SMELL: This is a very untidy behaviour, because we leave
    # the "rest" context opened: $session->leaveContext( 'rest' )
    exit;
    return "";
}

sub unlinkDbXmlFile {

    my $retval = "Starting deletion process. <br />";

    opendir( D, $workingPath );
    my @f = readdir(D);
    closedir(D);

    foreach my $file (@f) {
        my $filename = "$workingPath/$file";

        # This is VERY VERY BAD. ;)
        $filename =~ /(.*)/;
        $filename = $1;

        if ( $file =~ m/^__db\.\d\d\d/ ) {
            unlink "$filename";
            $retval .= "Deleting $file <br />";
        }
        if ( $file =~ m/^log\.\d\d\d\d\d\d\d\d\d\d/ ) {
            unlink "$filename";
            $retval .= "Deleting $file <br />";
        }
        if ( $file =~ m/^foswiki.dbxml.*/ ) {
            unlink "$filename";
            $retval .= "Deleting $file <br />";
        }
    }
    return $retval;
}

sub externalRenewDbXml {

    my $retval = "";

    my $cgi = Foswiki::Func::getCgiQuery();

    $retval .= unlinkDbXmlFile();
    $retval .= "<br /> <br /> Recreating database... " . createAllTopics();

    return $retval;
}

1;

