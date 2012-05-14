# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
# NavbarPlugin v1.2, 20 Sep 2002, Colas Nahaboo
#
# Stores info in a per-web cache file .navbarcache, format is a suite
# of index blocks.
# An index block for topic XXX begins with =START=XXX={
# ends with }=END=XXX=
# and is comprised of lines, one per subpage of the form
# %TopicName PrevTopic UpTopic NextTopic
# with exactly one space as separator, empty fields being marked by a _

# =========================
package TWiki::Plugins::NavbarPlugin;    # change the package name!!!

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
  $exampleCfgVar $webName $topicName
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
            "Version mismatch between NavbarPlugin and Plugins.pm");
        return 0;
    }

 # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $exampleCfgVar = &TWiki::Func::getPreferencesValue("NAVBARPLUGIN_EXAMPLE")
      || "default";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("NAVBARPLUGIN_DEBUG");

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::NavbarPlugin::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub beforeSaveHandler {
## my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    #  &TWiki::Func::writeDebug( "- Navbar: saving $_[2].$_[1]");
    #  &TWiki::Func::writeDebug( "  text is $_[0]");
    if ( $_[0] =~ /%NAVBARINDEX%/ ) {

        # we are saving an index topic, rebuild cache of this web
        # TODO: lock for concurrent access
        my $cachefilename = TWiki::Func::getDataDir() . "/$_[2]/.navbarcache";
        my $cachetext     = TWiki::Func::readFile($cachefilename);

       # &TWiki::Func::writeDebug( "- Navbar: generating cache $cachefilename");
       # remove old cache for this index
        $cachetext =~ s/=START=$_[1]={.*}=END=$_[1]=\n//sg;

        # generate new cache
        $cachetext .= "=START=$_[1]={\n";

        my $prev   = "_";
        my $next   = "_";
        my $cur    = "_";
        my $up     = $_[1];
        my $buffer = $_[0];
        $buffer =~ s/^.*%NAVBARINDEX%//s;
        $buffer =~ s/^%NAVBARINDEXEND%.*$//s;

        # look for each bullet list beginning by a Wiki name
        foreach ( split( /\n/, $buffer ) ) {
            if (/^\s+(\*|[0-9]+)\s+([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/) {
                if ( -e TWiki::Func::getDataDir() . "/$_[2]/$2.txt" ) {
                    $prev = $cur;
                    $cur  = $next;
                    $next = $2;
                    if ( $cur ne "_" ) {
                        $cachetext .= "%$cur $prev $up $next\n";
                    }
                    else {
                        $cachetext .= "%$_[1] $prev _ $next\n";
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
        $cachetext .= "}=END=$_[1]=\n";
        TWiki::Store::saveFile( $cachefilename, $cachetext );
    }
}

# =========================
sub endRenderingHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

#    &TWiki::Func::writeDebug( "- NavbarPlugin::endRenderingHandler( $web.$topic ) " ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop
    my $cache =
      TWiki::Func::readFile( TWiki::Func::getDataDir() . "/$web/.navbarcache" );
    if ( $cache =~ /\n%$topic ([a-zA-Z_0-9]+) ([a-zA-Z_0-9]+) ([a-zA-Z_0-9]+)/ )
    {
        my $prev = $1;
        my $up   = $2;
        my $next = $3;
        $_[0] =~ s/%NAVBAR({(.*?)})?%/&renderNavbar($2, $prev, $up, $next)/ge;
    }
    else {
        $_[0] =~ s/%NAVBAR[^%]*%//g;
    }
}

sub renderNavbar {
    my ( $args, $prev, $up, $next ) = @_;
    my $navbar;
    my $prefix;
    my $graphics;
    my $size;
    my $suffix;
    if ($args) {
        $prefix   = TWiki::Func::extractNameValuePair( $args, "prefix" );
        $suffix   = TWiki::Func::extractNameValuePair( $args, "suffix" );
        $graphics = TWiki::Func::extractNameValuePair( $args, "graphics" );
        $size     = TWiki::Func::extractNameValuePair( $args, "size" );
    }
    if ($graphics) {
        if ( $graphics eq "on" ) {
            $graphics = "Plugins/NavbarPlugin/nav";
            $size     = "width=16 height=16";
        }
        if ( $prev eq "_" ) {
            $navbar =
"$prefix<img src='$TWiki::pubUrlPath/$graphics-previ.gif' alt='No previous topic' $size>&nbsp;";
        }
        else {
            $navbar =
"$prefix<a href=$prev><img src='$TWiki::pubUrlPath/$graphics-prev.gif' border=0 alt='Previous: $prev' $size></a>&nbsp;";
        }
        if ( $up eq "_" ) {
            $navbar .=
"<img src='$TWiki::pubUrlPath/$graphics-upi.gif' alt='Already in index' $size>&nbsp;";
        }
        else {
            $navbar .=
"<a href=$up><img src='$TWiki::pubUrlPath/$graphics-up.gif' border=0 alt='Up: $up' $size></a>&nbsp;";
        }
        if ( $next eq "_" ) {
            $navbar .=
"<img src='$TWiki::pubUrlPath/$graphics-nexti.gif' alt='No next topic' $size>$suffix";
        }
        else {
            $navbar .=
"<a href=$next><img src='$TWiki::pubUrlPath/$graphics-next.gif' border=0 alt='Next: $next' $size></a>$suffix";
        }
    }
    else {
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
            $navbar .= "<strike>Next</strike>$suffix";
        }
        else {
            $navbar .= "<a href=$next>Next</a>$suffix";
        }
    }
    return $navbar;
}

# =========================

1;
