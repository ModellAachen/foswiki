# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004-2005 Patrick Diamond, patrick_diamond@mailc.net
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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
# Requirements on external modules
#     DBI
#     XML::LibXML
#     XML::LibXSLT
#     XML::Simple
#     Text::ParseWords
#     Cache::Cache
#     String::CRC
#
#

# =========================
package TWiki::Plugins::XmlQueryPlugin
  ;    # change the package name and $pluginName!!!

use TWiki;
use TWiki::Func ();

# =========================
use strict;
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $activeCfgVar $initialized $readswitchon
  $xmldir
  $cache
  $cachelimit
  $cacheexpires
  $datadir $pubdir
  $libxslt_debug
  $dbi_connections
  $allow_user_to_specify_dbi_connection
);

BEGIN {

    $pluginName = 'XmlQueryPlugin';    # Name of this Plugin

    ###########################################################################
    # modify the following hash to include your database connection definations
    ###########################################################################
    $dbi_connections = {
        'xxxxx' => {
            'DBD' =>
              'dbi:mysql:database=xxxxxxxxxxxxxx;host=yyyyyyyyyyyyyy.zzzzz',
            'user'     => 'uuuuuuuuuuuuuuuu',
            'password' => 'pppppppppp'
        },
        'clonethis' => { 'DBD' => '', 'user' => '', 'password' => '' },
    };
    ###########################################################################
  # Modify the following variable to allow TWiki page authors to specify
  # their own DBI connections instead of being limited to the above set. This
  # is a potential security risk depending on which DBD drivers are installed
  # on the instance of perl running TWiki e.g. if a DBD driver allowing access
  # to local files is available that is a major security hole when this variable
  # is set to 1.
    ###########################################################################
    $allow_user_to_specify_dbi_connection = 1;
    ###########################################################################
    # The following settings control the location of the auto generated XML and
    # cache files, plus size limits. Placed here as they are not suitable Plugin
    # Preferences
    ####################
    $xmldir =
      undef;    # undef = use platform specific default for plugin file storage
    $cachelimit   = 1024 * 1024 * 100;    # default 100 meg
    $cacheexpires = 'never';

    ###########################################################################
# do not modify below. Settings suitable for modification can be altered via WebPreferences
# see Plugin documentation for more info on this
    $initialized = 0;
    $VERSION     = '1.204';
    $RELEASE     = 'Dakar';
    $debug       = 0;
    $cache       = undef;
}

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag and other preferences

    # Get plugin preferences
    my ( $cl, $ct );
    if ( $TWiki::Plugins::VERSION < 1.1 ) {

        # Cairo codebase
        $debug = &TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG")
          || $debug;
    }
    else {

        # Dakar codebase
        $debug = TWiki::Func::getPluginPreferencesFlag('DEBUG') || $debug;
    }

    # Setup cache size limit
    my ( $cl_value, $cl_type ) = ( $cl =~ /^\s*([0-9]*)\s*([a-z]*)\s*$/ );
    if ( defined $cl_value ) {
        if ( not defined $cl_type =~ /^m/i ) {
            $cachelimit = $cl_value * 1024 * 1024;    # megabytes default
        }
        else {
            if ( $cl_type =~ /^k/i ) {
                $cachelimit = $cl_value * 1024;       # kilobytes
            }
            elsif ( $cl_type =~ /^g/i ) {
                $cachelimit = $cl_value * 1024 * 1024 * 1024;    # gigabytes!!!
            }
        }
    }

    # set cache default timeout
    $ct =~ s/^\s*//;
    $ct =~ s/\s*$//;    # strip leading and trailing spaces
    if (   $ct =~ /^(now|never)$/
        or $ct =~
/^[0-9]+\s+(s|second|seconds|sec|m|minute|minutes|min|h|hour|hours|d|day|days|w|week|weeks|M|month|months|y|year|years)$/
      )
    {
        $cacheexpires = $ct;
    }
    else {
        TWiki::Func::writeWarning(
            "Error CACHEEXPIRES incorrect for $web, $topic Value=\"$ct\"");
    }

    # ensure that the XMLDIR is correctly defined
    if ( not defined $xmldir ) {
        if ( $TWiki::Plugins::VERSION >= 1.1 ) {

            # TWiki 4.0+ provides a plugin work area
            $xmldir = TWiki::Func::getWorkArea($pluginName);
        }
        else {
            $xmldir = '/var/tmp/twiki_xml';
        }

        # override xmldir if it has a Unix style path on a Windows machine
        $xmldir = 'c:/.twiki_xml'
          if $^O eq 'MSWin32' and $xmldir !~ /^\[a-z]\:/i;
    }

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;

    return 1;
}

# =========================
sub commonTagsHandler {
    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2] $_[1] )")
      if $debug;

    return unless ( $_[0] =~ m/\%(XSLTSTART|XMLSTART)/o );

    $_[0] =~
s/\n?%XSLTSTART{(.*?)}%(.*?)%XSLTEND%\s*\n?/&_handle_XSLT_tag($1,$2,$_[1],$_[2])/geos;
    $_[0] =~
      s/%XMLSTART{(.*?)}%(.*?)%XMLEND%/&_handle_XML_tag($1,$2,$_[1],$_[2])/geos;

}

# =========================
sub beforeSaveHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::beforeSaveHandler( $_[2] $_[1] )")
      if $debug;
    generateXML( $_[0], $_[1], $_[2], 0 );
}

# =========================
sub afterEditHandler {
    TWiki::Func::writeDebug("- ${pluginName}::afterEditHandler( $_[2].$_[1] )")
      if $debug;

    # ensure that the cache has a copy of the previewed xml to work with
    generateXML( $_[0], $_[1], $_[2], 1 );
}

sub generateXML {

    #return if $activeCfgVar !~ /true/i;
    TWiki::Func::writeDebug(
        "TWiki::Plugins::XmlQueryPlugin::_generateXML  $_[1] $_[2]")
      if $debug;
    return if not _initialize();

    # initize vars
    my $text    = $_[0];
    my $topic   = $_[1];
    my $web     = $_[2];
    my $preview = $_[3];    # flaged this xml as preview only
    my $data = { 'metadata' => {}, 'actions' => {}, 'tables' => {} };

    # extract data
    my $title = _processTitle( $text, $topic, $web );
    my $metadata = _processMetaData( $text, $topic, $web );
    my $actions = _processActions( $text, $topic, $web );
    my $tables = _processTables( $text, $topic, $web );
    my $xml = _processXML( $text, $topic, $web );

    # build data structure to generate XML
    my $out;
    $out                          = $data;
    $out->{'metadata'}            = $metadata;
    $out->{'tables'}              = {};
    $out->{'tables'}->{'table'}   = $tables;
    $out->{'actions'}->{'action'} = $actions;
    $out->{'xmldata'}->{'xml'}    = $xml;
    $out->{'web'}                 = $web;
    $out->{'topic'}               = $topic;
    $out->{'title'}               = $title;
    $out->{'version'}             = $VERSION;
    $out->{'preview'} = 1 if defined $preview;
    my $page = {};
    $page->{'data'} = $out;

    # Generate XML to temporary file
    mkdir($xmldir) if not -d $xmldir;
    mkdir("$xmldir/$web") if not -d "$xmldir/$web";
    my $xmlfile = "$xmldir/$web/$topic.xml";
    $xmlfile .= '.preview' if defined $preview;
    open( FH, ">$xmlfile" )
      or TWiki::Func::writeWarning(
        "Error opening XML outputfile $xmldir/$web/$topic.xml $!")
      and return;
    print FH XML::Simple::XMLout(
        $page,
        KeepRoot => 1,
        XMLDecl  => "<?xml version='1.0' encoding='ISO-8859-1'?>"
    );
    close FH;
    $out = undef;
}

sub _processTitle {

    # extract the first header in the text and return it as the header
    my $text  = $_[0];
    my $topic = $_[1];

    TWiki::Func::writeDebug(
        "TWiki::Plugins::XmlQueryPlugin::_processTitle $web $topic ")
      if $debug;
    my $title = '';

    if ( $text =~ /^--[\-]+[\+]+[\!]*\s*(.*?)$/ms ) {
        $title = $1;
        $title =~ s/^\s*\<nop\>//;      # common prefix not needed now
        $title =~ s/%TOPIC%/$topic/;    # common header not needed now
    }
    return $title;
}

sub _processXML {

    # extract XML DATA from the topic text
    my $text  = $_[0];
    my $topic = $_[1];
    my $web   = $_[2];
    TWiki::Func::writeDebug(
        "TWiki::Plugins::XmlQueryPlugin::_processXML $web $topic ")
      if $debug;
    my $xml = [];

    my $i = -1;
    while ( $text =~ /\s*\%XMLSTART\{(.*?)\}\%(.*?)%XMLEND/gs ) {

        $i++;
        my ( $xmlargs, $xmltxt ) = ( $1, $2 );

        $xmlargs = TWiki::Func::expandCommonVariables( $xmlargs, $topic, $web )
          if $xmlargs =~ /\%.*\%/;
        my $h = _args2hash($xmlargs);
        $xml->[$i] =
          XML::Simple::XMLin( $xmltxt, KeepRoot => 1, ForceArray => 1 )
          if $xmltxt =~ /\<.*\>/;
        foreach my $key ( keys %$h ) {
            $xml->[$i]->{$key} = $h->{$key};
        }
    }
    return $xml;
}

sub _processMetaData {

    # extract META DATA from the topic text
    my $text  = $_[0];
    my $topic = $_[1];
    my $web   = $_[2];
    TWiki::Func::writeDebug(
        "TWiki::Plugins::XmlQueryPlugin::_processMetaData $web $topic ")
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

        # unescape quotes and new lines
        foreach my $a ( keys %$args ) {
            $args->{$a} =~ s/\%_N_/\n/g;
            $args->{$a} =~ s/\%_Q_\%/\"/g;
        }

        $metatype = lc($metatype);
        $metadata->{$metatype} = [] if not exists $metadata->{$metatype};
        push @{ $metadata->{$metatype} }, {%$args};
    }
    return $metadata;
}

sub _processActions {

    # extract Actions from the topic text
    my $text  = $_[0];
    my $topic = $_[1];
    my $web   = $_[2];
    TWiki::Func::writeDebug(
        "TWiki::Plugins::XmlQueryPlugin::_processActions $web $topic ")
      if $debug;
    my $actions = [];

    my $gathering;
    my $processAction = 0;
    my $attrs;
    my $descr;
    my $i = -1;
    foreach my $line ( split( /\r?\n/, $text ) ) {
        if ($gathering) {
            if ( $line =~ m/^$gathering\b.*/ ) {
                $gathering     = undef;
                $processAction = 1;
            }
            else {
                $descr .= "$line\n";
                next;
            }
        }
        elsif ( $line =~ m/.*?%ACTION{(.*?)}%(.*)$/o ) {
            $attrs = $1;
            $descr = $2;
            if ( $descr =~ m/\s*<<(\w+)\s*(.*)$/o ) {
                $descr     = $2;
                $gathering = $1;
                next;
            }
            $processAction = 1;
        }
        if ($processAction) {
            $i++;
            $actions->[$i]                  = _args2hash($attrs);
            $actions->[$i]->{'description'} = $descr;
            $processAction                  = 0;
        }
    }
    return $actions;
}

sub _processTables {

    # extract table data from the topic text
    my $text  = $_[0];
    my $topic = $_[1];
    my $web   = $_[2];
    TWiki::Func::writeDebug(
        "TWiki::Plugins::XmlQueryPlugin::_processTables $web $topic ")
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

                if ( $arg =~ /^(\s*\*\s*)(.*)(\s*\*\s*)$/ ) {
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
    return $tables;
}

sub _args2hash {

    # convert a list of arguments as found in a twiki macro into a hash
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

sub _handle_XSLT_tag {

    # process an xslt tag
    my ( $args_txt, $xslt_txt, $topic, $web ) = @_;
    TWiki::Func::writeDebug(
        "TWiki::Plugins::XmlQueryPlugin::_handle_XSLT_tag $web $topic ")
      if $debug;
    return if not _initialize();

    my $t0        = new Benchmark;
    my $benchmark = 0;
    my $b         = "";
    my $xmlstr;
    my $preview;

    ###############################
    # read the args associated with the xslt
    $args_txt = TWiki::Func::expandCommonVariables( $args_txt, $topic, $web )
      if $args_txt =~ /\%.*\%/;
    my $args = _args2hash( $args_txt, 'urlinc' );
    $benchmark = 1
      if ( exists $args->{'benchmark'}
        and lc( $args->{'benchmark'} ) eq 'on' )
      or ( exists $args->{'debug'}
        and lc( $args->{'debug'} ) eq 'on' );

    # the output of the xslt can be redirected to an attachment
    my $output_to;
    if ( exists $args->{'output'} ) {
        my $output_dir = "$pubdir/$web/$topic";
        $output_to = $args->{'output'};
        $output_to =~ s/^.*[\\\/]//g;    # strip all but the basename
             # create the content dir if it doesn't already exist
        File::Path::mkpath($output_dir) if !-d $output_dir;
        $output_to = "$output_dir/$output_to";
    }

    # check for a web def
    my $quiet = 0;
    $quiet = 1
      if ( exists $args->{'quiet'} and lc( $args->{'quiet'} ) eq 'on' );

    my $debug_output = 0;
    $debug_output = 1
      if exists $args->{'debug'}
          and $args->{'debug'} =~ /^(on|full)$/i;

    # check for caching request
    my $usecache          = 1;
    my $crcstr            = "$VERSION,";      # str used to generate checksum
    my $localcacheexpires = $cacheexpires;    # set cache expires to default
    $usecache = 0
      if ( exists $args->{'cache'} and lc( $args->{'cache'} ) eq 'off' );
    if (
        exists $args->{'cacheexpires'}
        and (
            $args->{'cacheexpires'} =~ /^(now|never)$/
            or ( $args->{'cacheexpires'} =~
/^[0-9]+\s+(s|second|seconds|sec|m|minute|minutes|min|h|hour|hours|d|day|days|w|week|weeks|M|month|months|y|year|years)$/
            )
        )
      )
    {
        $usecache          = 1;
        $localcacheexpires = $args->{'cacheexpires'};
    }
    $b .= _update_benchmark( 'Eval Args', $t0 ) if $benchmark;

    ##########################################
    # fetch a local web/topic/[attachment]

    # determine the source of the xml
    my ( $xweb, $attach ) = ( $web, undef );
    my @xtopic = ($topic);
    my @attach;
    my $files  = {};
    my $fcount = 0;

    # check for a web def
    if ( exists $args->{'web'} ) {
        my @xw =
          grep { File::Basename::basename($_) =~ /$args->{'web'}/ }
          <$datadir/[A-Z]*>;    # find match to web
        if ( not @xw ) {
            return if $quiet;
            return
                '<font color=red>Error Web '
              . _escapeHTML( $args->{'web'} )
              . ' not matched </font><br>';
        }
        foreach (@xw) { $files->{ File::Basename::basename($_) } = {} }
    }
    else {
        $files->{$web} = {};
    }

    # check for a topic def
    if ( exists $args->{'topic'} ) {
        foreach my $xweb ( keys %$files ) {
            foreach ( grep { /$args->{'topic'}/ }
                TWiki::Func::getTopicList($xweb) )
            {
                $files->{$xweb}->{$_} = [];
                $fcount++;
            }

        }
        if ( $fcount == 0 ) {
            return if $quiet;
            return
                '<font color=red>Error no topics for web '
              . _escapeHTML( $args->{'web'} )
              . ' topic '
              . _escapeHTML( $args->{'topic'} )
              . " found </font>$fcount<br>";
        }
    }
    else {

        # by default the current topic in the current web is used
        $files->{$web}->{$topic} = [];
    }

    # check for an attachment def
    if ( exists $args->{'attach'} and $args->{'attach'} !~ /^\s*$/ ) {
        foreach my $xweb ( sort keys %$files ) {
            foreach my $atopic ( sort keys %{ $files->{$xweb} } ) {
                if ( -d "$pubdir/$xweb/$atopic" ) {
                    foreach my $f ( sort grep { /$args->{'attach'}/ }
                        <$pubdir/$xweb/$atopic/*> )
                    {
                        push @{ $files->{$xweb}->{$atopic} }, $f;
                        if ($usecache) {
                            my @s = stat($f);
                            $crcstr .= $s[9]
                              . ',';    # add last modified date to crc string
                        }
                        $fcount++;
                    }
                }
            }
        }
    }

    $b .= _update_benchmark( 'Files Ref Checked', $t0 ) if $benchmark;

    # include multiple xml topics
    $xmlstr = '<?xml version="1.0" encoding="ISO-8859-1"?>
<twiki xmlns:xi="http://www.w3.org/2001/XInclude">
';

    # include topic info
    my ( $timestamps, $num_updated ) = _ensureXMLUptodate($files);
    $crcstr .= $timestamps;
    foreach my $xweb ( sort keys %$files ) {
        $xmlstr .= "<web name=\"$xweb\">\n";
        foreach my $atopic ( sort keys %{ $files->{$xweb} } ) {
            $xmlstr .= "\n<topic name=\"$atopic\">\n";

           # insert the topic xml, preview xml if it is available for this topic
            if (    $xweb eq $web
                and $atopic eq $topic
                and -r "$xmldir/$xweb/$atopic.xml.preview" )
            {
                $usecache = 0;
                $preview  = "$xmldir/$xweb/$atopic.xml.preview";
                $xmlstr .=
                  "<xi:include href=\"$xmldir/$xweb/$atopic.xml.preview\"/>\n";
                $crcstr .= localtime();
            }
            else {
                $crcstr .= ',';
                $xmlstr .= "<xi:include href=\"$xmldir/$xweb/$atopic.xml\"/>\n";
            }

            # now include attachments
            $xmlstr .= '<attachments>' . "\n";
            foreach my $attach ( @{ $files->{$xweb}->{$atopic} } ) {
                $xmlstr .= '<attachment name=\"'
                  . File::Basename::basename($attach) . "\">\n";
                $xmlstr .= "<xi:include href=\"$attach\"/>\n";
                $xmlstr .= '</attachment>' . "\n";
            }
            $xmlstr .= '</attachments>' . "\n";
            $xmlstr .= '</topic>' . "\n";
        }
        $xmlstr .= '</web>' . "\n";
    }

    $b .= _update_benchmark( "XML Updated $num_updated", $t0 ) if $benchmark;

    $crcstr .= $xmlstr;    # add the toplevel xml to the checksum

    # where  a url has been defined setup appropiate crcstr
    if ( exists $args->{'url'} and $args->{'url'} !~ /^\s*$/ ) {
        $crcstr .= $args->{'url'};
    }

    # when caching is on and debug off then use cache
    my $cache_available = 0;
    my $checksum;
    my $result_str;
    if ( $usecache and not $debug_output ) {
        $cache->set_namespace('XSLT_Result');
        $checksum   = String::CRC::crc( $crcstr . $xslt_txt . $args_txt );
        $result_str = $cache->get($checksum);
        if ( defined $result_str ) {
            $b .= _update_benchmark( 'Cache Fetch', $t0 ) if $benchmark;
            $cache_available = 1;
        }
        else {
            $b .= _update_benchmark( 'Cache Check', $t0 ) if $benchmark;
        }
    }

    ##########################################
    # handle external data sources
    if ( not $cache_available ) {

        # if a URL has been defined then fetch that
        my $errorstr = _process_xslt_url( $args, $xmlstr, $benchmark, $b, $t0 );
        return $errorstr if defined $errorstr and $errorstr !~ /^\s*$/;
    }

    if ( not $cache_available ) {

        # generate the result directly

        #############################################
        # prepare the stylesheets, catching any errors
        my $stylesheet;
        my $xml;
        eval {
            $TWiki::Plugins::XmlQueryPlugin::libxslt_debug = '';

            if ( $debug_output and $args->{'debug'} =~ /^full$/ ) {
                XML::LibXSLT->debug_callback(
                    sub {
                        $TWiki::Plugins::XmlQueryPlugin::libxslt_debug .=
                          join( ',', @_ ) . "<br/>\n";
                    }
                );
            }

            # Setup the XML parse
            my $parser = XML::LibXML->new();
            $parser->complete_attributes(0);
            $readswitchon =
              1;    # allow external docs to to sourced from the filesystem
            my $xmlcrc = String::CRC::crc($crcstr);
            $b .= _update_benchmark( 'XML Parser Setup', $t0 ) if $benchmark;
            $xml = $parser->parse_string($xmlstr);
            $b .= _update_benchmark( 'XML parse toplevel string', $t0 )
              if $benchmark;
            $parser->process_xincludes($xml);
            $b .= _update_benchmark( 'XML parse includes', $t0 ) if $benchmark;

            # now setup the XSLT
            $readswitchon =
              0;    # disallow the reading of external docs on filesystem
            $parser->pedantic_parser(1) if $debug_output == 1;
            $parser->line_numbers(1)    if $debug_output == 1;
            my $style_doc = $parser->parse_string($xslt_txt);
            $b .= _update_benchmark( 'XML parse XSLT', $t0 ) if $benchmark;
            my $xslt = XML::LibXSLT->new();
            $b .= _update_benchmark( 'XSLT Parser Setup', $t0 ) if $benchmark;
            $stylesheet = $xslt->parse_stylesheet($style_doc);
            $b .= _update_benchmark( 'XSLT parsed', $t0 ) if $benchmark;
            XML::LibXSLT->debug_callback(undef)
              if $debug_output and $args->{'debug'} =~ /^full$/;
        };

        unlink $preview if defined $preview;

        if ( $@ or not defined $xml ) {
            return if $quiet;
            my $str =
                '<table border=1><caption>XSLT ERRORS</caption>'
              . '<tr><th valign=top>Error Message</th><td><pre>'
              . _escapeHTML($@) . '<br/>'
              . '<tr><th valign=top>Debug Trace</th><td><pre>'
              . _escapeHTML($TWiki::Plugins::XmlQueryPlugin::libxslt_debug)
              . '</pre></td></tr><tr><th valign=top>XSLT</th><td><pre>'
              . _escapeHTML($xslt_txt)
              . '</pre></td></tr><tr><th valign=top>XML Includes</th>'
              . '<td><pre>'
              . _escapeHTML($xmlstr)
              . '</pre></td></tr><tr><th valign=top>XML Included</th>'
              . '<td><pre>'
              . _escapeHTML( substr( $xml->toString, 0, 9999 ) )
              . '</pre></td>';

            $str .= '</tr></table>';
            return $str;
        }

        unlink $preview if defined $preview;

        #############################
        # transform the xml with the xslt
        my $results;
        eval {
            if ( not scalar( keys %$args ) )
            {

                # no args to pass
                $results = $stylesheet->transform($xml);
            }
            else {

                # pass args into stylesheet
                $results =
                  $stylesheet->transform( $xml,
                    XML::LibXSLT::xpath_to_string(%$args) );
            }
        };
        if ($@) {
            return if $quiet;
            return "<pre>\n($@)\n<br/>" if $@;
        }

        $b .= _update_benchmark( 'XSLT Tranform', $t0 ) if $benchmark;
        $result_str = $stylesheet->output_string($results);

        # save the result
        $cache->set( $checksum, $result_str, $localcacheexpires )
          if ( $usecache and not $debug_output );

        $b .= _update_benchmark( 'Result Cached', $t0 ) if $benchmark;

        # if an output file has been specified then write to that
        if ( defined $output_to ) {
            open( FH, '>', $output_to )
              or return "Error writing to $output_to <br/> $!";
            flock FH, 2;    # lock the file
            print FH $result_str;
            flock FH, 8;    # unlock the file
            close(FH);
        }

        # user requested debug output
        if ($debug_output) {
            my $xml_string;
            if ( $args->{'debug'} =~ /^full$/ ) {
                $xml_string = $xml->toString;
            }
            else {
                $xml_string = substr( $xml->toString, 0, 9999 );
            }
            return
                "<table border=1><caption>DEBUG=$args->{'debug'}</caption>"
              . '<tr><th valign=top>XML Includes</th><td><pre>'
              . _escapeHTML($xmlstr)
              . '</pre><tr><th valign=top>XML Included</th><td><pre>'
              . _escapeHTML($xml_string)
              . '</pre></pre></td></tr><tr><th valign=top>XSLT</th><td><pre>'
              . _escapeHTML($xslt_txt)
              . '</pre></td></tr><tr><th valign=top>Result</th><td><pre>'
              . _escapeHTML($result_str)
              . '</pre></td></tr><tr><th valign=top>Settings</th><td>'
              . "<table><th>Using Cache</th><td>$usecache</td></tr><tr><th>Cache size limit</th><td>$cachelimit</td></tr><tr><th>Cache Expires</th><td>$localcacheexpires</td></tr><tr><th>XMLDIR</th><td>$xmldir</td></tr></table>"
              . '</td></tr><tr><th valign=top>Benchmark</th><td><table>'
              . $b
              . '</table></td></tr>'
              . '<tr><th valign=top>DEBUG</th><td><pre>'
              . _escapeHTML($TWiki::Plugins::XmlQueryPlugin::libxslt_debug)
              . '</pre></td></tr>'
              . '</table>';
        }
    }

    # user requested benchmark numbers along with result
    return $result_str . "<br><b>Benchmark</b><table>$b</table>" if $benchmark;

    return if defined $output_to;    # no output to screen

    # vanilla result
    return $result_str;
}

###########
# these callbacks allow disabling of local file reads
sub _callback_match_file_uri {
    my $uri = shift;
    return $uri !~ /:\/\// or $uri =~ /^\s*file:\/\//;    # handle local files
}

sub _callback_open_file_uri {
    my $uri = shift;

    # unless the global variable $readswitchon has been set to 1 refuse to
    # read the external file
    return 0 if not defined $readswitchon or !$readswitchon;

    my $handler = new IO::File;
    if ( not $handler->open("<$uri") ) {
        $handler = 0;
    }

    return $handler;
}

sub _callback_read_file_uri {
    my $handler = shift;
    my $length  = shift;
    my $buffer  = undef;
    if ($handler) {
        $handler->read( $buffer, $length );
    }
    return $buffer;
}

sub _callback_close_file_uri {
    my $handler = shift;
    if ($handler) {
        $handler->close();
    }
    return 1;
}

sub _update_benchmark {
    my ( $msg, $t0 ) = @_;
    return
        "<tr><td>$msg:</td><td>"
      . Benchmark::timestr( Benchmark::timediff( new Benchmark, $t0 ) )
      . "</td></tr>\n";

}

sub _handle_XML_tag {

    # process an xml tag
    my ( $args_txt, $xml_txt, $topic, $web ) = @_;
    TWiki::Func::writeDebug(
        "TWiki::Plugins::XmlQueryPlugin::_handle_XML_tag $web $topic ")
      if $debug;
    return if not _initialize();

    # read the args associated with the xml
    $args_txt = TWiki::Func::expandCommonVariables( $args_txt, $topic, $web )
      if $args_txt =~ /\%.*\%/;
    my $args = _args2hash($args_txt);

    # by default the xml is displayed vertbatium
    $args->{'display'} = 'verbatim' if not exists $args->{'display'};

    if ( $args->{'display'} eq 'include' ) {
        return "<!-- <pre> -->\n$xml_txt\n</pre>";

        #return _reformatXML($xml_txt);
    }

    return '' if $args->{'display'} eq 'hidden';
    if ( $args->{'display'} eq 'verbatim' ) {
        return _escapeHTML($xml_txt);
    }

}

# handle references to url's and include either the data directly or via an include statement
# within the xml
sub _process_xslt_url {
    my $args      = $_[0];
    my $xmlstr    = $_[1];    # this var may be modified
    my $benchmark = $_[2];
    my $b         = $_[3];    # this var may be modified
    my $t0        = $_[4];

    TWiki::Func::writeDebug(
        "TWiki::Plugins::XmlQueryPlugin::_process_xslt_url  ")
      if $debug;

    if ( exists $args->{'url'} and $args->{'url'} !~ /^\s*$/ ) {
        my $ua = LWP::UserAgent->new;
        $ua->env_proxy;
        my $response = $ua->get( $args->{'url'} );

        if ( $response->is_success ) {
            my $str = $response->content;
            $_[1] = $str;
        }
        else {
            return
                '<font color=red>Error loading '
              . _escapeHTML( $args->{'url'} ) . '<br>'
              . $response->status_line
              . ' </font><br>';
        }

        $_[3] .= _update_benchmark( 'URL Get', $t0 ) if $benchmark;
    }
    else {

   # for each  urlinc parameter get the content of the url and place it into the
   # xml to be processed
        if ( exists $args->{'urlinc'} ) {
            my @urls;
            if ( ref $args->{'urlinc'} eq 'ARRAY' ) {
                push @urls, @{ $args->{'urlinc'} };
            }
            else {
                push @urls, $args->{'urlinc'};
            }

            my $id = 0;

            foreach my $url (@urls) {
                $id++;
                $_[1] .= "<url id=\"$id\">\n";
                $_[1] .= "<xi:include href=\"$url\"/>\n";
                $_[1] .= "\n</url>\n";
            }
        }
        $_[1] .= '</twiki>';    # complete the xml;
    }
    return;
}

# return the xml data for a specific topic
sub _xslt_read_topic {
    my ( $web, $topic ) = @_;

    TWiki::Func::writeDebug("TWiki::Plugins::XmlQueryPlugin::_xslt_read_topic")
      if $debug;

    if (
        not TWiki::Func::checkAccessPermission(
            'VIEW', TWiki::Func::getWikiName(),
            '', $topic, $web
        )
      )
    {
        return _import_dbi_data_warning("Error cannot read $web.$topic");
    }

    my $filecheck = {};
    $filecheck->{$web}->{$topic} = [];
    _ensureXMLUptodate($filecheck);

    my $parser = XML::LibXML->new();
    $readswitchon = 1;
    my $doc = $parser->parse_file("$xmldir/$web/$topic.xml");
    $readswitchon = 0;
    return $doc;

}

# return the xml data for a specific topic
sub _xslt_read_attachment {
    my ( $web, $topic, $attachment ) = @_;

    TWiki::Func::writeDebug(
        "TWiki::Plugins::XmlQueryPlugin::_xslt_read_attachment")
      if $debug;
    my $file = "$pubdir/$web/$topic/$attachment";

    if (
        not TWiki::Func::checkAccessPermission( 'VIEW',
            TWiki::Func::getWikiName(),
            '', $topic, $web )
        or not -r "$file"
      )
    {
        return _import_dbi_data_warning(
            "Error cannot read $web.$topic $attachment");
    }

    my $parser = XML::LibXML->new();
    $readswitchon = 1;
    my $doc = $parser->parse_file($file);
    $readswitchon = 0;
    return $doc;

}

# return the current set of CGI parameters. Optionally filtered by a supplied set
sub _xslt_cgi_param {
    my $dbi_def  = shift;
    my @cgi_args = @_;

    TWiki::Func::writeDebug("TWiki::Plugins::XmlQueryPlugin::_xslt_cgi_param")
      if $debug;

    # extract cgi filter parameters from values passed in
    my %cgi_filter;
    foreach my $sa (@cgi_args) {
        if ( ref $sa eq 'XML::LibXML::NodeList' ) {
            while ( my $str = $sa->string_value() ) {
                $cgi_filter{$str} = 1;
                $sa->shift;
            }
        }
        else {
            $cgi_filter{$sa} = 1;
        }
    }

    # build return doc
    my $doc  = XML::LibXML::NodeList->new();
    my $root = XML::LibXML::Element->new('parameters');
    $doc->push($root);

    # fetch each parameter add its value to the return doc if it exists
    foreach my $p ( CGI::param() ) {
        next if @cgi_args and not exists $cgi_filter{$p};
        foreach my $value ( CGI::param($p) ) {
            my $parm = XML::LibXML::Element->new($p);
            $parm->appendText($value);
            $root->appendChild($parm);
        }
    }

    return $doc;
}

sub _xslt_dbi_select {
    my $dbi_def  = shift;
    my $user     = shift;
    my $password = shift;
    my $sql      = shift;
    my @sql_args = @_;

    TWiki::Func::writeDebug(
        "TWiki::Plugins::XmlQueryPlugin::_xslt_dbi_select  ")
      if $debug;

    my ( $dbh, $error ) = _dbi_connect( $dbi_def, $user, $password );
    return $error if defined $error;

    # prepare select statement
    my $sth = $dbh->prepare_cached($sql)
      or return _import_dbi_data_warning(
        "Error preparing statement $sql " . $dbh->errstr );

    # extract sql parameters from values passed in
    my @sql_bind;
    foreach my $sa (@sql_args) {
        if ( ref $sa eq 'XML::LibXML::NodeList' ) {
            while ( my $str = $sa->string_value() ) {
                push @sql_bind, $str;
                $sa->shift;
            }
        }
        else {
            push @sql_bind, $sa;
        }
    }

    # execute, passing any args
    $sth->execute(@sql_bind)
      or return _import_dbi_data_warning( "Error executing statement $sql "
          . join( ',', @sql_args ) . ' '
          . $dbh->errstr );

    # build return doc
    my $doc  = XML::LibXML::NodeList->new();
    my $root = XML::LibXML::Element->new('result');
    $doc->push($root);

    # retrieve column names
    my @col_names;
    foreach my $colname ( @{ $sth->{'NAME'} } ) {
        push @col_names, lc($colname);
    }

    # fetch each row and add it to the return doc
    while ( my $dbrow = $sth->fetchrow_arrayref ) {
        my $row = XML::LibXML::Element->new('row');
        my $i   = -1;
        foreach my $field (@$dbrow) {
            $i++;
            my $col = XML::LibXML::Element->new( $col_names[$i] );
            $col->appendText($field);
            $row->appendChild($col);
        }
        $root->appendChild($row);
    }

    #  cleanup
    $sth->finish;
    $dbh->disconnect;

    return $doc;
}

sub _xslt_dbi_select2 {
    my $dbi_def  = shift;
    my $user     = shift;
    my $password = shift;
    my $sql      = shift;
    my @sql_args = @_;

    TWiki::Func::writeDebug(
        "TWiki::Plugins::XmlQueryPlugin::_xslt_dbi_select  ")
      if $debug;

    my ( $dbh, $error ) = _dbi_connect( $dbi_def, $user, $password );
    return $error if defined $error;

    # prepare select statement
    my $sth = $dbh->prepare_cached($sql)
      or return _import_dbi_data_warning(
        "Error preparing statement $sql " . $dbh->errstr );

    # extract sql parameters from values passed in
    my @sql_bind;
    foreach my $sa (@sql_args) {
        if ( ref $sa eq 'XML::LibXML::NodeList' ) {
            while ( my $str = $sa->string_value() ) {
                push @sql_bind, $str;
                $sa->shift;
            }
        }
        else {
            push @sql_bind, $sa;
        }
    }

    # execute, passing any args
    $sth->execute(@sql_bind)
      or return _import_dbi_data_warning( "Error executing statement $sql "
          . join( ',', @sql_args ) . ' '
          . $dbh->errstr );

    #  build return doc
    my $doc  = XML::LibXML::NodeList->new();
    my $root = XML::LibXML::Element->new('result');
    $doc->push($root);

    # retrieve column names
    my @col_names;
    foreach my $colname ( @{ $sth->{'NAME'} } ) {
        push @col_names, lc($colname);
    }

    # fetch each row and add it to the return doc
    while ( my $dbrow = $sth->fetchrow_arrayref ) {
        my $row = XML::LibXML::Element->new('row');
        my $i   = -1;
        foreach my $field (@$dbrow) {
            $i++;
            $row->setAttribute( $col_names[$i], $field );
        }
        $root->appendChild($row);
    }

    #  cleanup
    $sth->finish;
    $dbh->disconnect;

    return $doc;
}

sub _xslt_dbi_block {

    my $dbi_def  = shift;
    my $user     = shift;
    my $password = shift;
    my @sql_args = @_;

    TWiki::Func::writeDebug("TWiki::Plugins::XmlQueryPlugin::_xslt_dbi_block  ")
      if $debug;

    my ( $dbh, $error ) = _dbi_connect( $dbi_def, $user, $password );
    return $error if defined $error;

    my $result = _xslt_dbi_block_exe( $dbh, @sql_args )
      or
      return _import_dbi_data_warning( 'Error processing sql ' . $DBI::errstr );

    return $result;
}

# xslt function to execute a dbi->do statement
sub _xslt_dbi_do {
    my $dbi_def  = shift;
    my $user     = shift;
    my $password = shift;
    my $sql      = shift;
    my @sql_args = @_;

    TWiki::Func::writeDebug("TWiki::Plugins::XmlQueryPlugin::_xslt_dbi_do  ")
      if $debug;

    my ( $dbh, $error ) = _dbi_connect( $dbi_def, $user, $password );
    return $error if defined $error;

    # prepare the do statement
    my $sth = $dbh->prepare_cached($sql)
      or return _import_dbi_data_warning(
        "Error preparing statement $sql " . $dbh->errstr );

    # execute the do statement with any args if available
    $sth->execute(@sql_args)
      or return _import_dbi_data_warning( "Error executing statement $sql "
          . join( ',', @sql_args ) . ' '
          . $dbh->errstr );

    # insert into return doc the number of updates made
    my $doc     = XML::LibXML::NodeList->new();
    my $updates = XML::LibXML::Element->new('updates');
    my $text    = XML::LibXML::Text->new( $sth->rows );
    $updates->appendChild($text);
    $doc->push($updates);

    # cleanup and return
    $sth->finish;
    $dbh->disconnect;

    return $updates;
}

# Connect to the database returning a (connection,errormsg)
sub _dbi_connect {

    my ( $dbi_def, $user, $password ) = @_;

    TWiki::Func::writeDebug(
        "TWiki::Plugins::XmlQueryPlugin::_dbi_connect $dbi_def $user ")
      if $debug;

    # check if the dbi name actually maps to a predefined DBI connection setting
    if ( exists $dbi_connections->{$dbi_def} ) {

      # if the predefined DBI connection has a user id setting then override the
      # supplied user and password
        if ( exists $dbi_connections->{$dbi_def}->{'user'} ) {

            # update the userid and password
            $user     = $dbi_connections->{$dbi_def}->{'user'};
            $password = $dbi_connections->{$dbi_def}->{'password'};
        }
        $dbi_def = $dbi_connections->{$dbi_def}->{'DBD'};
    }
    elsif ( $allow_user_to_specify_dbi_connection == 0 ) {

        # unauthorized connection do not allow to proceed
        return (
            undef,
            _import_dbi_data_warning(
"Error DBI connection not authorized. Only the following connections are available: "
                  . join( ',', keys %$dbi_connections )
            )
        );
    }

    # connect to DB
    my $dbh = DBI->connect( $dbi_def, $user, $password )
      or return (
        undef,
        _import_dbi_data_warning(
            'Error connecting to database ' . $DBI::errstr
        )
      );

    TWiki::Func::writeDebug(
        "TWiki::Plugins::XmlQueryPlugin::_dbi_connect connected")
      if $debug;

    return ( $dbh, undef );
}

# take a block of sql statements  and associated data set. Execute this
# within a transaction block
sub _xslt_dbi_block_exe {
    my $dbh      = shift;
    my @sql_args = @_;
    my $affected = 0;

    my $doc = XML::LibXML::NodeList->new();

    # multiple statement execute
    foreach my $sql_arg (@sql_args) {

        if ( ref($sql_arg) == 'XML::LibXML::NodeList' ) {

            # extract each statement block
            while ( my $toplevel = $sql_arg->shift() ) {
                foreach my $cmd ( $toplevel->findnodes('//statement') ) {
                    my ( $sql, $sth );

                    # retrieve the sql text attribute
                    my @atts = $cmd->getAttributes();
                    foreach my $at (@atts) {
                        if ( $at->getName() eq "sql" ) {
                            $sql = $at->getValue();
                        }
                    }

                    # create an sql statment handler from the sql text
                    if ( defined $sql ) {
                        $sth = $dbh->prepare_cached($sql)
                          or $dbh->rollback()
                          and return _import_dbi_data_warning(
                            "Error preparing statement $sql " . $dbh->errstr );
                    }
                    else {
                        next;
                    }

                    my $count = 0;

                    # extract each row and apply it to the sql statement
                    foreach my $row ( $cmd->childNodes() ) {
                        $count++;

                        # node contains a row of data
                        # extract each field and put its contents into an array
                        my @args;
                        foreach my $field ( $row->childNodes ) {
                            push @args, $field->textContent();
                        }

                        $sth->execute(@args)
                          or $dbh->rollback()
                          and return _import_dbi_data_warning(
                                "Error executing statement $sql "
                              . join( ',', @args ) . " "
                              . $dbh->errstr );
                        $affected += $sth->rows;
                    }

                  # when no data has been associated with the sql statement then
                  # just do it with no args
                    if ( $count == 0 ) {
                        $sth->execute()
                          or $dbh->rollback()
                          and return _import_dbi_data_warning(
                            "Error executing statement $sql " . $dbh->errstr );
                        $affected += $sth->rows;
                    }
                }
            }
        }
        else {
            $dbh->rollback();
            return _import_dbi_data_warning("Error Nodelist required $sql_arg");
        }

    }

    my $root = XML::LibXML::Element->new('updates');
    my $text = XML::LibXML::Text->new($affected);
    $root->appendChild($text);
    $doc->push($root);

    return $doc;

}

sub _import_dbi_data_warning {

# taking an error message return a XML doc with 1 element <error>message</error>
    my $msg = shift;
    TWiki::Func::writeDebug(
        "TWiki::Plugins::XmlQueryPlugin::_import_dbi_data_warning $msg ")
      if $debug;

    my $doc  = XML::LibXML::Document->new();
    my $root = $doc->createElement('error');
    $doc->setDocumentElement($root);
    my $text = XML::LibXML::Text->new($msg);
    $root->appendChild($text);
    return $root;
}

sub _escapeHTML {
    my $txt = $_[0];
    $txt =~
s<([^\x20\x21\x23\x27-\x3b\x3d\x3F-\x5B\x5D-\x7E])><'&#'.(ord($1)).';'>seg;
    return $txt;
}

sub _ensureXMLUptodate {

    # ensure that the XML files which tracks the topic are up todate
    # returns the last modified date stamps
    my $files = $_[0];

    TWiki::Func::writeDebug(
        "TWiki::Plugins::XmlQueryPlugin::_ensureXMLUptodate $web $topic ")
      if $debug;

    my $return_str;
    my $updated = 0;
    foreach my $web ( sort keys %$files ) {
        foreach my $topic ( sort keys %{ $files->{$web} } ) {
            my $xml_file = "$xmldir/$web/$topic.xml";
            if ( !-r $xml_file ) {
                my $txt = TWiki::Func::readTopicText( $web, $topic );
                generateXML( $txt, $topic, $web );
                $txt = undef;

                my @stat = stat($xml_file);
                $return_str .= $stat[9];
                $updated++;
            }
            else {

     # generate xml if topic text is older than xml (within a couple of seconds)
                my @s1 = stat( $datadir . "/$web/$topic.txt" );
                my @s2 = stat($xml_file);
                if ( $s1[9] > $s2[9] + 1 ) {
                    my $txt = TWiki::Func::readTopicText( $web, $topic );
                    generateXML( $txt, $topic, $web );
                    $txt = undef;
                    $updated++;
                }
                $return_str .= $s2[9];
            }
        }
    }
    return ( $return_str, $updated );
}

sub _initialize {

    # test and optimized the loading of external Modules

    if ( !$initialized ) {
        foreach my $lib (
            'XML::LibXML ()',
            'XML::LibXSLT ()',
            'XML::Simple ()',
            'Benchmark',
            'Text::ParseWords ()',
            'Cache::SizeAwareFileCache ()',
            'String::CRC ()',
            'File::Basename ()',
            'LWP::UserAgent ()',
            'DBI',
            'File::Path ()',
            'IO::File ()'
          )
        {
            eval "use $lib;";
            if ($@) {
                TWiki::Func::writeWarning("Module $lib failed to load $@");
                return 0;
            }
        }

        # one time register perl functions within the XSLT engine
        XML::LibXSLT->register_function( "http://twiki.org/xmlquery",
            "dbiselect", \&_xslt_dbi_select );
        XML::LibXSLT->register_function( "http://twiki.org/xmlquery",
            "dbiselect2", \&_xslt_dbi_select2 );
        XML::LibXSLT->register_function( "http://twiki.org/xmlquery", "dbido",
            \&_xslt_dbi_do );
        XML::LibXSLT->register_function( "http://twiki.org/xmlquery",
            "dbiblock", \&_xslt_dbi_block );
        XML::LibXSLT->register_function( "http://twiki.org/xmlquery",
            "cgiparam", \&_xslt_cgi_param );
        XML::LibXSLT->register_function( "http://twiki.org/xmlquery",
            "readattachment", \&_xslt_read_attachment );
        XML::LibXSLT->register_function( "http://twiki.org/xmlquery",
            "readtopic", \&_xslt_read_topic );

        # enable the switch off of reading local files within xslt
        $XML::LibXML::match_cb = \&_callback_match_file_uri;
        $XML::LibXML::read_cb  = \&_callback_read_file_uri;
        $XML::LibXML::open_cb  = \&_callback_open_file_uri;
        $XML::LibXML::close_cb = \&_callback_close_file_uri;

        # Each of the following though useful once in a while for debug
        # are Very, Very Slow
        #XML::LibXSLT->debug_callback(
        #    sub {
        #        $TWiki::Plugins::XmlQueryPlugin::libxslt_debug .=
        #          join( ',', @_ ) . "<br/>\n";
        #    }
        #);

        #XML::LibXSLT->debug_callback(sub { TWiki::Func::writeWarning(@_) });

        $xmldir =~ s/\/$//;    # remove trailing /
        $xmldir .=
          "/$VERSION";    # ensure that the XML generated per topic is versioned

        # setup filecase in xmldir limited to 100 Megs
        $cache = new Cache::SizeAwareFileCache(
            {
                'namespace'         => 'XSLT_Result',
                'cache_root'        => "$xmldir/_xmlquerycache",
                'auto_purge_on_get' => 1,
                'max_size'          => $cachelimit
            }
        );
        if ( not defined $cache ) {
            TWiki::Func::writeWarning(
                "Couldn't instantiate SizeAwareFileCache $!");
            return 0;
        }

        $datadir     = TWiki::Func::getDataDir();
        $pubdir      = TWiki::Func::getPubDir();
        $initialized = 1;
    }
    return 1;
}

1;

