# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
# Copyright (C) 2005 George Neville-Neil, gnn@neville-neil.com
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
# Originally based on the NavbarPlugin by Colas Nahaboo
# Stores info in a per-topic cache file .navbarcache, format is a suite
# of index blocks.
# An index block for topic XXX begins with =START=XXX={
# ends with }=END=XXX=
# and is comprised of lines, one per subpage of the form
# %TopicName PrevTopic UpTopic NextTopic
# with exactly one space as separator, empty fields being marked by a _
#

# =========================
package TWiki::Plugins::SlideNavPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $debug
  $exampleCfgVar $webName $topicName
);

$VERSION = '1.000';

# =========================
sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between NavbarPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("SLIDENAVPLUGIN_DEBUG");

    if ($debug) {
        &TWiki::Func::writeDebug(
            "- TWiki::Plugins::SlideNavPlugin::initPlugin( $web.$topic ) is OK"
        );
    }

    # Plugin correctly initialized
    return 1;
}

#
# beforeSaveHandler
#
# This function is used by the plugin to generate a new cache or
# rebuild an old cache every time the topic is saved.
#
# The cache is built from the list of sub topics, each of which must
# be preceded by the usual TWiki bullet, i.e. 3 spaces and an
# asterisk (*) character.
#
# XXX: There is a potential race condition here if two people save the
# same topic at the same time.  We do not anticipate fixing that
# anytime soon.
#
sub beforeSaveHandler {

    # NOTE: We do NOT mess with the arguments directly (i.e. $_[0] et
    # al) as suggested by EmptyPlugin.pm because that reduces the
    # readability of the code.
    my ( $text, $topic, $web, $meta ) = @_;

    if ( $text =~ /%SLIDENAVINDEX%/ ) {

        # we are saving an index topic, rebuild cache of this web
        my $cachefilename =
          TWiki::Func::getPubDir() . "/" . $web . "/" . $topic . ".navbarcache";
        my $cachetext = TWiki::Func::readFile($cachefilename);
        &TWiki::Func::writeDebug("- Navbar: generating cache $cachefilename");

        # remove old cache for this index
        $cachetext =~ s/=START=$_[1]={.*}=END=$_[1]=\n//sg;

        # generate new cache
        $cachetext .= "=START=$_[1]={\n";

        my $prev = "_";
        my $next = "_";
        my $cur  = "_";
        my $up   = $topic;
        $text =~ s/^.*%SLIDENAVINDEX%//s;

        # look for each bullet list beginning by a Wiki name
        foreach ( split( /\n/, $text ) ) {
            if (/^\s+(\*|[0-9]+)\s+([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/) {
                my $datafile =
                  TWiki::Func::getDataDir() . "/" . $web . "/" . $2 . ".txt";
                if ( -e $datafile ) {
                    $prev = $cur;
                    $cur  = $next;
                    $next = $2;
                    if ( $cur ne "_" ) {
                        $cachetext .= "%$cur $prev $up $next\n";
                    }
                    else {
                        $cachetext .= "%$topic $prev _ $next\n";
                    }
                }
            }
        }
        $prev = $cur;
        $cur  = $next;
        $next = "_";
        if ( $cur ne "_" ) {
            $cachetext .= "%$cur $prev $up $next\n";
        }
        $cachetext .= "}=END=$topic=\n";
        TWiki::Func::saveFile( $cachefilename, $cachetext );
    }
}

#
# commonTagsHandler
#
# This function handles the display of the navigational links.  In
# order that multiple presentations can be made from the same slides
# it is necessary to use a CGI query variable, in this case
# "presentation", to disambiguate different presentations.
#

sub commonTagsHandler {

    # NOTE: We do NOT mess with the arguments directly (i.e. $_[0] et
    # al) as suggested by EmptyPlugin.pm because that reduces the
    # readability of the code.

    my ( $text, $topic, $web ) = @_;

    # TWiki docs say we MUST always check for CGI as it's not a given
    my $query = TWiki::Func::getCgiQuery();

    # We must scrub the pages ourselves in order to prevent our tags
    # from showing up on an error.

    if ( !defined($query) ) {
        $text =~ s/%SLIDENAVINDEX%//go;
        $text =~ s/%SLIDENAVBAR%//go;
        $_[0] = $text;
        return;
    }

    my $presentation = $query->param('presentation');

    if ( !defined($presentation) ) {
        $text =~ s/%SLIDENAVINDEX%//go;
        $text =~ s/%SLIDENAVBAR%//go;
        $_[0] = $text;
        return;
    }

    my $cachefilename =
        TWiki::Func::getPubDir() . "/" 
      . $web . "/"
      . $presentation
      . ".navbarcache";
    my $cachetext = TWiki::Func::readFile($cachefilename);
    if ( $cachetext eq "" ) {
        ( $meta, $mytext ) = &TWiki::Func::readTopic( $web, $topic );
        my $parent = $meta->getParent();
        $cachefilename =
            TWiki::Func::getPubDir() . "/" 
          . $web . "/" 
          . $parent
          . ".navbarcache";
        if ($debug) {
            TWiki::Func::writeDebug("$parent");
            TWiki::Func::writeDebug("SubPage $cachefilename");
        }
        $cachetext = TWiki::Func::readFile($cachefilename);
    }
    if ( $cachetext =~
        /\n%$topic ([a-zA-Z_0-9]+) ([a-zA-Z_0-9]+) ([a-zA-Z_0-9]+)/ )
    {
        my $prev = $1;
        my $up   = $2;
        my $next = $3;
        my $end  = "";
        if ( $cachetext =~ /=START=([a-zA-Z_0-9]+)/ ) {
            $end = $1;
        }

        # Implement "End" as a return to the base page.
        $text =~
s/%SLIDENAVBAR({(.*?)})?%/&renderNavbar($2, $prev, $up, $next, $presentation, $end)/ge;
    }
    else {
        $text =~ s/%SLIDENAVBAR[^%]*%//g;
    }

    $text =~ s/%SLIDENAVINDEX%//go;
    $_[0] = $text;
}

#
# renderNavbar
#
# $prev: Previous page, may be "_" for None.
# $up: Index page, may be "_" for None.
# $next: Next page, may be "_" for None.
# $presentation: The name of the presentation, which is appended to
# all valid prev, up and next URLs.
# $end: a link to be used to end the presentation.
#
# It is the caller's responsibility to embed this into a page in some way.

sub renderNavbar {
    my ( $args, $prev, $up, $next, $presentation, $end ) = @_;
    my $navbar;
    my $prefix;
    my $size;
    my $suffix;
    if ($args) {
        $prefix = TWiki::Func::extractNameValuePair( $args, "prefix" );
        $suffix = TWiki::Func::extractNameValuePair( $args, "suffix" );
        $size   = TWiki::Func::extractNameValuePair( $args, "size" );
    }

    if ( $prev ne "_" ) {
        $prev = $prev . "?presentation=$presentation";
    }
    if ( $up ne "_" ) {
        $up = $up . "?presentation=$presentation";
    }
    if ( $next ne "_" ) {
        $next = $next . "?presentation=$presentation";
    }

    if ( $prev eq "_" ) {
        $navbar = "$prefix<strike>Prev</strike>&nbsp;";
    }
    else {
        $navbar = "$prefix<a href=$prev>Prev</a>&nbsp;";
    }
    if ( $up eq "_" ) {
        $navbar .= "<strike>Up</strike>&nbsp;";
    }
    else {
        $navbar .= "<a href=$up>Up</a>&nbsp;";
    }
    if ( $next eq "_" ) {
        $navbar .= "<a href=$end>End</a>$suffix";
    }
    else {
        $navbar .= "<a href=$next>Next</a>&nbsp;";
        $navbar .= "<a href=$end>End</a>$suffix";
    }
    return $navbar;
}

1;
