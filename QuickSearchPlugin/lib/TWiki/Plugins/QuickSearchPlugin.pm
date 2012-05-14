#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2002 David Alsup, dave_a@innovasic.com
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
package TWiki::Plugins::QuickSearchPlugin;

use TWiki::Func;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between QuickSearchPlugin and Plugins.pm");
        return 0;
    }

# Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
# $exampleCfgVar = &TWiki::Func::getPreferencesValue( "EMPTYPLUGIN_EXAMPLE" ) || "default";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("QUICKSEARCHPLUGIN_DEBUG");

# Plugin correctly initialized
# &TWiki::Func::writeDebug( "- TWiki::Plugins::QuickSearchPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug(
        "- QuickSearchPlugin::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    $_[0] =~ s/%QUICKSEARCH{(.*?)}%/&handleQuickSearch($_[1],$_[2],$1)/geo;
}

# =========================
# The following was hacked out of TWiki::searchWeb
sub handleQuickSearch {
    my ( $topicin, $web, $attributes ) = @_;

    my $theWebName =
         TWiki::Func::extractNameValuePair( $attributes, "web" )
      || $web
      || "";
    my $theSearchVal =
      TWiki::Func::extractNameValuePair( $attributes, "search" ) || "";
    my $theRegex = TWiki::Func::extractNameValuePair( $attributes, "regex" )
      || "";
    my $caseSensitive =
      TWiki::Func::extractNameValuePair( $attributes, "casesensitive" ) || "";
    my $noTotal = TWiki::Func::extractNameValuePair( $attributes, "tototal" )
      || "";
    my $totalOnly =
      TWiki::Func::extractNameValuePair( $attributes, "totalonly" ) || "";

    my $searchResult = "";

    ## #############
    ## 0501 kk : vvv An entire new chunk devoted to setting up mult-web
    ##               searches.

    my @webList;

    # A value of 'all' or 'on' by itself gets all webs,
    # otherwise ignored (unless there is a web called "All".)
    my $searchAllFlag = ( $theWebName =~ /^(([Aa][Ll][Ll])||([Oo][Nn]))$/ );

    # Search what webs?  "" current web, list gets the list, all gets
    # all (unless marked in WebPrefs as NOSEARCHALL)

    if ( !$theWebName ) {

        #default to current web
        push @webList, $TWiki::webName;

    }
    elsif ($searchAllFlag) {

        # get list of all webs by scanning $dataDir
        opendir DIR, TWiki::Func::getDataDir();
        my @tmpList = readdir(DIR);
        closedir(DIR);

        # this is not magic, it just looks like it.
        @webList = sort
          grep { s#^.+/([^/]+)$#$1# }
          grep { -d }
          map  { TWiki::Func::getDataDir() . "/$_" }
          grep { !/^[._]/ } @tmpList;

        # what that does (looking from the bottom up) is take the file
        # list, filter out the dot directories and dot files, turn the
        # list into full paths instead of just file names, filter out
        # any non-directories, strip the path back off, and sort
        # whatever was left after all that (which should be merely a
        # list of directory's names.)

    }
    else {

        # use whatever the user sent
        @webList = split( " ", $theWebName );  # the web processing loop filters
                                               # for valid web names, so don't
                                               # do it here.
    }
    ## 0501 kk : ^^^
    ## ##############

    my $tempVal        = "";
    my $topicCount     = 0;                    # JohnTalintyre
    my $originalSearch = $theSearchVal;
    my $tmpl = &TWiki::Func::readTemplate("quicksearch");
    my ( $tmplTable, $tmplNumber ) = split( /%SPLIT%/, $tmpl );

    if ( !$tmplTable ) {
        print "<html><body>";
        print "<h1>TWiki Installation Error</h1>";

        # Might not be search.tmpl FIXME
        print "Incorrect format of quicksearch.tmpl (missing %SPLIT% parts)";
        print "</body></html>";
        return;
    }

    my $cmd = "";
    $cmd =
"%GREP% %SWITCHES% -l $TWiki::cmdQuote$theSearchVal$TWiki::cmdQuote *.txt";

    if ($caseSensitive) {
        $tempVal = "";
    }
    else {
        $tempVal = "-i";
    }
    $cmd =~ s/%SWITCHES%/$tempVal/go;

    if ($theRegex) {
        $tempVal = $TWiki::egrepCmd;
    }
    else {
        $tempVal = $TWiki::fgrepCmd;
    }
    $cmd =~ s/%GREP%/$tempVal/go;

    ## #############
    ## 0501 kk : vvv New web processing loop, does what the old straight
    ##               code did for each web the user requested.  Note that
    ##               '$theWebName' is mostly replaced by '$thisWebName'

    foreach my $thisWebName (@webList) {

        # PTh 03 Nov 2000: Add security check
        $thisWebName =~ s/$TWiki::securityFilter//go;
        $thisWebName =~ /(.*)/;
        $thisWebName = $1;    # untaint variable

        next
          unless &TWiki::Func::webExists($thisWebName)
        ;                     # can't process what ain't thar

        my $thisWebBGColor =
          &TWiki::Func::getPreferencesValue( "WEBBGCOLOR", $thisWebName )
          || "\#FF00FF";
        my $thisWebNoSearchAll =
          &TWiki::Func::getPreferencesValue( "NOSEARCHALL", $thisWebName );

        # make sure we can report this web on an 'all' search
        # DON'T filter out unless it's part of an 'all' search.
        # PTh 18 Aug 2000: Need to include if it is the current web
        next
          if (
            ($searchAllFlag)
            && (   ( $thisWebNoSearchAll =~ /on/i )
                || ( $thisWebName =~ /^[\.\_]/ ) )
            && ( $thisWebName ne $TWiki::webName )
          );

        ( my $baz = "foo" ) =~ s/foo//;    # reset search vars. defensive coding

        # 0501 kjk : vvv New var for accessing web dirs.
        my $sDir      = TWiki::Func::getDataDir() . "/$thisWebName";
        my @topicList = "";
        if ($theSearchVal) {

            # do grep search
            chdir("$sDir");
            $cmd =~ /(.*)/;
            $cmd     = $1;      # untaint variable (NOTE: Needs a better check!)
            $tempVal = `$cmd`;
            @topicList = split( /\n/, $tempVal );

            # cut .txt extension
            my @tmpList = map { /(.*)\.txt$/; $_ = $1; } @topicList;
            @topicList = ();
            my $lastTopic = "";
            foreach (@tmpList) {
                $tempVal = $_;

                # make topic unique
                if ( $tempVal ne $lastTopic ) {
                    push @topicList, $tempVal;
                }
            }
        }

        next if ( $noEmpty && !@topicList );    # Nothing to show for this topic

        @topicList = map { $_->[1] }
          sort { $a->[0] cmp $b->[0] }
          map { [ $_, $_ ] } @topicList;

        # output header of $thisWebName
        my ( $beforeText, $repeatText, $afterText ) =
          split( /%REPEAT%/, $tmplTable );

        $beforeText =~ s/%WEBBGCOLOR%/$thisWebBGColor/o;
        $beforeText =~ s/%WEB%/$thisWebName/o;
        $searchResult = $beforeText;

        # output the list of topics in $thisWebName
        my $ntopics = 0;
        my $topic   = "";
        my $head    = "";
        foreach (@topicList) {
            $topic = $_;
            if ( !$totalOnly ) {

                my $meta = "";
                my $text = "";

                $tempVal = $repeatText;

                $tempVal =~ s/%WEB%/$thisWebName/go;
                $tempVal =~ s/%TOPICNAME%/$topic/go;

                $searchResult .= $tempVal;
            }
            $ntopics += 1;
        }

        $searchResult .= $afterText;

        if ($totalOnly) {
            $searchResult = $ntopics;
        }
        elsif ( !$noTotal ) {

            # print "Number of topics:" part
            my $thisNumber = $tmplNumber;
            $thisNumber =~ s/%NTOPICS%/$ntopics/go;
            $searchResult .= $thisNumber;
        }
    }
    return $searchResult;
}

1;

