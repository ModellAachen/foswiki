# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005 Arild Bergh
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
#
# This is a TWiki plugin which will cache a reference to a webpage
# in a topic to a local file, either as a new topic or as a linked data file
#
# =========================
package TWiki::Plugins::URLCachePlugin
  ;    # change the package name and $pluginName!!!

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $exampleCfgVar
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'URLCachePlugin';    # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG");

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# this function returns (and creates if required) the correct directory inside the pub folder in
# the TWiki folder
sub getDirectory {
    my ( $web, $topic ) = @_;

    # Create web directory "pub/$web" if needed
    my $dir = TWiki::Func::getPubDir() . "/$web";
    unless ( -e "$dir" ) {
        umask(002);
        mkdir( $dir, 0775 );
    }

    # Create topic directory "pub/$web/$topic" if needed
    $dir .= "/$topic";
    unless ( -e "$dir" ) {
        umask(002);
        mkdir( $dir, 0775 );
    }
    return "$dir";
}

#create a basic text only page
sub HTML2Twiki {
    use Date::Format;
    my @lt = localtime(time);
    my $date = time2str( "%C", time );
    my $title;
    my $url = $_[1];
    use HTML::FormatText;
    use HTML::Parse;
    my $x     = parse_html( $_[0] );
    my $ascii = HTML::FormatText->new->format($x);
    ($title) = $_[0] =~ m/<title.*?>(.*?)<\/title>/ig;
    return "---+++$title\n\n---++++Downloaded from $url at $date\n\n$ascii";
}

#download the page to be cached
#tried to use LWP::Simple, but found that this will not work on some websites that require a
#user agent setting
sub getPage {
    use LWP::UserAgent;
    my $ua = LWP::UserAgent->new;
    $ua->protocols_allowed( [ 'http', 'https' ] );
    $ua->agent("Mozilla/8.0");
    $ua->timeout(30);
    my $request = HTTP::Request->new( GET, $_[0] );
    $request->header( 'Accept' => 'text/html' );
    $res = $ua->request($request);

    if ( !$res->is_success ) {
        return "";
    }
    else {
        return $res->content;
    }
}

# here's the main action which checks for http/https links and downloads them
sub beforeSaveHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    #quit if this has the no-cache flag set
    if ( $_[0] =~ /\Q<!--NOCACHE-->/ ) { return; }

    #is this a wiki that is not to be cached?
    my @ignore_webs =
      split( ",", TWiki::Func::getPluginPreferencesValue("IGNORE") );
    my @hit = grep /$_[2]/, @ignore_webs;
    if (@hit) { return; }

# to avoid recursive cahcing we have a flag, so only the original page that is being saved will be processed
    if ( $ALREADYHERE == 1 ) { return; }
    $ALREADYHERE = 1;
    use LWP::Simple;
    use HTML::LinkExtor;
    use File::Basename;
    use Date::Format;
    use Time::ParseDate;
    my @lt               = localtime(time);
    my $date             = time2str( "%C", time );
    my $urls             = '(http|https)';
    my $createtopic_urls = '(\+http|\+https)';
    my $ltrs             = '\w';
    my $gunk             = '/#~:.?+=&%@!\-,';
    my $punc             = '.:?\-';
    my $any              = "${ltrs}${gunk}${punc}";
    my ( @l, @links, @createtopic_links, @pagelinks, $linkarray, @res, $tmp,
        $parser );
    my ( $htmlpage, $img, $oopsUrl, $page_content, $topic, $cachedfrom,
        $imageurl );

    # pick up all the URLs to cache (i.e. stored locally with a link to them)
    (@res) = $_[0] =~ m/(^|\s)($urls : [$any] +? )(?=[$punc]*[^$any]|$)/igx;

#we get back three units for each URL, not yet sure how to turn this off (if indeed you can)
    if ( $res[0] ) {
        for ( $i = 0 ; $i < @res ; $i++ ) {
            if ( length( $res[$i] ) > 10 ) {
                push( @links, $res[$i] );
            }
        }
    }

    # now get the links that want to be stored as new topics
    (@res) =
      $_[0] =~
      m/(^|\s)($createtopic_urls : [$any] +? )(?=[$punc]*[^$any]|$)/igx;
    if ( $res[0] ) {
        for ( $i = 0 ; $i < @res ; $i++ ) {
            if ( length( $res[$i] ) > 10 ) {
                push( @createtopic_links, substr( $res[$i], 1 ) );
            }
        }
    }

    #if none we exit at this point
    if ( @links == 0 && @createtopic_links == 0 ) {
        $ALREADYHERE = 0;
        return;
    }

    #set some inital variables
    my $twiki_pubdir = getDirectory( $_[2], $_[1] );
    my $twiki_url =
        TWiki::Func::getUrlHost()
      . TWiki::Func::getPubUrlPath() . "/"
      . $_[2] . "/"
      . $_[1];
    my $twiki_thisurl = TWiki::Func::getViewUrl( $_[2], $_[1] );
    my $topic_header =
        "%META:TOPICINFO{author=\""
      . TWiki::Func::getWikiName()
      . "\" date=\""
      . time
      . "\" format=\"1.0\" version=\"1.0\"}%\n%META:TOPICPARENT{name=\""
      . $_[1]
      . "\"}%\n";

#first we do the ones that is to be new topics (i.e. searchable)
#here we strip off the tag, keep the title at top and make a note of where it's come from
    for ( $i = 0 ; $i < @createtopic_links ; $i++ ) {
        $page_content = getPage( $createtopic_links[$i] );
        if ( length($page_content) > 0 ) {
            $htmlpage = HTML2Twiki( $page_content, $createtopic_links[$i] );

        #whenever we have a successful download we first save the new topic
        # and then do a search and replace and replace the link to the new topic
            $topic = substr( $createtopic_links[$i], 6 );
            $topic =~ s/\W/ /g;
            $topic =~ s/(\w*) /\u\L$1/g;
            TWiki::Func::saveTopicText( $_[2], $topic,
                $topic_header . $htmlpage,
                1, 1 );    # save topic text
            if ( !$oopsUrl ) {
                $tmp    = $createtopic_links[$i];
                $tmpnew = "[[" . $topic . "][" . $tmp . "]]";
                $_[0] =~ s/\+\Q$tmp/$tmpnew/igx;
            }
        }
    }

    #here we proces the list of files that we want to cahce separately
    #we download each page and change the image & stylesheet links in it
    for ( $i = 0 ; $i < @links ; $i++ ) {
        $htmlpage = getPage( $links[$i] );
        if ( length($htmlpage) > 0 ) {
            $parser = HTML::LinkExtor->new(undef);
            $parser->parse($htmlpage);
            @pagelinks = $parser->links;
            $img       = basename( $links[$i] );
            $imageurl  = $links[$i];
            if ($img) {
                $imageurl =~ s/\Q$img//;
            }
            foreach $linkarray (@pagelinks) {
                my @element  = @$linkarray;
                my $elt_type = shift @element;
                while (@element) {
                    my ( $attr_name, $attr_value ) = splice( @element, 0, 2 );
                    if (   ( $elt_type eq 'img' && $attr_name eq 'src' )
                        || ( $elt_type eq 'link' && $attr_name eq 'href' ) )
                    {
                        $img = basename($attr_value);

                        #check if this image link already has a full URL in it
                        if ( $attr_value =~ /http/ ) {
                            mirror( $attr_value, $twiki_pubdir . "/" . $img );
                            $htmlpage =~ s/\Q$attr_value/$img/igx;
                        }
                        else {
                            mirror(
                                "$imageurl$attr_value",
                                $twiki_pubdir . "/" . $img
                            );
                            $htmlpage =~ s/\Q$attr_value/$img/igx;
                        }
                    }
                }
            }

            #finally we save the modified HTML page
            $topic = substr( $links[$i], 6 );
            $topic =~ s/\W//g;

            #here we add a line at the top of the page showing that it's cached
            $cachedfrom =
"<div style='text-align: center;'><pre>Downloaded from <a href='$links[$i]'>$links[$i]</a>\non $date\n<a href='$twiki_thisurl'>Return to Twiki</a></pre></div><hr>";
            $htmlpage =~ s/(<body.*?>)(.*?)/$1$2$cachedfrom/ig;
            TWiki::Func::saveFile( $twiki_pubdir . "/" . $topic . ".html",
                $htmlpage );

#whenever we have a successful download we do a search and replace and replace the link to the local
#cache rather than the online version [[ToRead][http://abergh.com/webmail]]
            $tmp = $links[$i];
            $tmpnew =
              "[[" . $twiki_url . "/" . $topic . ".html][" . $tmp . "]]";
            $_[0] =~ s/(^|\s)\Q$tmp/$tmpnew/igx;
        }
    }

    #reset the flag
    $ALREADYHERE = 0;
}

1;
