# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2002-2006 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2005-2006 Michael Daum <micha@nats.informatik.uni-hamburg.de>
# Copyright (C) 2005 TWiki Contributors
# Copyright (C) 2009,2010 Foswiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
#
# =========================
#
# This is the HeadlinesPlugin used to show RSS news feeds.
# Plugin home: http://foswiki.org/Extensions/HeadlinesPlugin
#

# =========================
package Foswiki::Plugins::HeadlinesPlugin::Core;

use strict;
use Digest::MD5 qw(md5_hex);

# =========================
use vars qw(
  $web $topic $debug
  $defaultRefresh $defaultLimit $defaultHeader $defaultFormat
  $useLWPUserAgent $isInitialized %entityHash
  $userAgent $userAgentTimeout $userAgentName $doneHeader
);

$debug = 0;    # toggle me

%entityHash = (
    160  => 'nbsp',
    161  => 'iexcl',
    162  => 'cent',
    163  => 'pound',
    164  => 'curren',
    165  => 'yen',
    166  => 'brvbar',
    167  => 'sect',
    168  => 'uml',
    169  => 'copy',
    170  => 'ordf',
    171  => 'laquo',
    172  => 'not',
    173  => 'shy',
    174  => 'reg',
    175  => 'macr',
    176  => 'deg',
    177  => 'plusmn',
    178  => 'sup2',
    179  => 'sup3',
    180  => 'acute',
    181  => 'micro',
    182  => 'para',
    183  => 'middot',
    184  => 'cedil',
    185  => 'sup1',
    186  => 'ordm',
    187  => 'raquo',
    188  => 'frac14',
    189  => 'frac12',
    190  => 'frac34',
    191  => 'iquest',
    192  => 'Agrave',
    193  => 'Aacute',
    194  => 'Acirc',
    195  => 'Atilde',
    196  => 'Auml',
    197  => 'Aring',
    198  => 'AElig',
    199  => 'Ccedil',
    200  => 'Egrave',
    201  => 'Eacute',
    202  => 'Ecirc',
    203  => 'Euml',
    204  => 'Igrave',
    205  => 'Iacute',
    206  => 'Icirc',
    207  => 'Iuml',
    208  => 'ETH',
    209  => 'Ntilde',
    210  => 'Ograve',
    211  => 'Oacute',
    212  => 'Ocirc',
    213  => 'Otilde',
    214  => 'Ouml',
    215  => 'times',
    216  => 'Oslash',
    217  => 'Ugrave',
    218  => 'Uacute',
    219  => 'Ucirc',
    220  => 'Uuml',
    221  => 'Yacute',
    222  => 'THORN',
    223  => 'szlig',
    224  => 'agrave',
    225  => 'aacute',
    226  => 'acirc',
    227  => 'atilde',
    228  => 'auml',
    229  => 'aring',
    230  => 'aelig',
    231  => 'ccedil',
    232  => 'egrave',
    233  => 'eacute',
    234  => 'ecirc',
    235  => 'euml',
    236  => 'igrave',
    237  => 'iacute',
    238  => 'icirc',
    239  => 'iuml',
    240  => 'eth',
    241  => 'ntilde',
    242  => 'ograve',
    243  => 'oacute',
    244  => 'ocirc',
    245  => 'otilde',
    246  => 'ouml',
    247  => 'divide',
    248  => 'oslash',
    249  => 'ugrave',
    250  => 'uacute',
    251  => 'ucirc',
    252  => 'uuml',
    253  => 'yacute',
    254  => 'thorn',
    255  => 'yuml',
    338  => 'OElig',
    339  => 'oelig',
    352  => 'Scaron',
    353  => 'scaron',
    376  => 'Yuml',
    710  => 'circ',
    732  => 'tilde',
    402  => 'fnof',
    913  => 'Alpha',
    914  => 'Beta',
    915  => 'Gamma',
    916  => 'Delta',
    917  => 'Epsilon',
    918  => 'Zeta',
    919  => 'Eta',
    920  => 'Theta',
    921  => 'Iota',
    922  => 'Kappa',
    923  => 'Lambda',
    924  => 'Mu',
    925  => 'Nu',
    926  => 'Xi',
    927  => 'Omicron',
    928  => 'Pi',
    929  => 'Rho',
    931  => 'Sigma',
    932  => 'Tau',
    933  => 'Upsilon',
    934  => 'Phi',
    935  => 'Chi',
    936  => 'Psi',
    937  => 'Omega',
    945  => 'alpha',
    946  => 'beta',
    947  => 'gamma',
    948  => 'delta',
    949  => 'epsilon',
    950  => 'zeta',
    951  => 'eta',
    952  => 'theta',
    953  => 'iota',
    954  => 'kappa',
    955  => 'lambda',
    956  => 'mu',
    957  => 'nu',
    958  => 'xi',
    959  => 'omicron',
    960  => 'pi',
    961  => 'rho',
    962  => 'sigmaf',
    963  => 'sigma',
    964  => 'tau',
    965  => 'upsilon',
    966  => 'phi',
    967  => 'chi',
    968  => 'psi',
    969  => 'omega',
    977  => 'thetasym',
    978  => 'upsih',
    982  => 'piv',
    8194 => 'ensp',
    8195 => 'emsp',
    8201 => 'thinsp',
    8204 => 'zwnj',
    8205 => 'zwj',
    8206 => 'lrm',
    8207 => 'rlm',
    8211 => 'ndash',
    8212 => 'mdash',
    8216 => 'lsquo',
    8217 => 'rsquo',
    8218 => 'sbquo',
    8220 => 'ldquo',
    8221 => 'rdquo',
    8222 => 'bdquo',
    8224 => 'dagger',
    8225 => 'Dagger',
    8240 => 'permil',
    8249 => 'lsaquo',
    8250 => 'rsaquo',
    8364 => 'euro',
    8226 => 'bull',
    8230 => 'hellip',
    8242 => 'prime',
    8243 => 'Prime',
    8254 => 'oline',
    8260 => 'frasl',
    8472 => 'weierp',
    8465 => 'image',
    8476 => 'real',
    8482 => 'trade',
    8501 => 'alefsym',
    8592 => 'larr',
    8593 => 'uarr',
    8594 => 'rarr',
    8595 => 'darr',
    8596 => 'harr',
    8629 => 'crarr',
    8656 => 'lArr',
    8657 => 'uArr',
    8658 => 'rArr',
    8659 => 'dArr',
    8660 => 'hArr',
    8704 => 'forall',
    8706 => 'part',
    8707 => 'exist',
    8709 => 'empty',
    8711 => 'nabla',
    8712 => 'isin',
    8713 => 'notin',
    8715 => 'ni',
    8719 => 'prod',
    8721 => 'sum',
    8722 => 'minus',
    8727 => 'lowast',
    8730 => 'radic',
    8733 => 'prop',
    8734 => 'infin',
    8736 => 'ang',
    8743 => 'and',
    8744 => 'or',
    8745 => 'cap',
    8746 => 'cup',
    8747 => 'int',
    8756 => 'there4',
    8764 => 'sim',
    8773 => 'cong',
    8776 => 'asymp',
    8800 => 'ne',
    8801 => 'equiv',
    8804 => 'le',
    8805 => 'ge',
    8834 => 'sub',
    8835 => 'sup',
    8836 => 'nsub',
    8838 => 'sube',
    8839 => 'supe',
    8853 => 'oplus',
    8855 => 'otimes',
    8869 => 'perp',
    8901 => 'sdot',
    8968 => 'lceil',
    8969 => 'rceil',
    8970 => 'lfloor',
    8971 => 'rfloor',
    9001 => 'lang',
    9002 => 'rang',
    9674 => 'loz',
    9824 => 'spades',
    9827 => 'clubs',
    9829 => 'hearts',
    9830 => 'diams',
);

# =========================
sub writeDebug {
    Foswiki::Func::writeDebug( 'HeadlinesPlugin - ' . $_[0] ) if $debug;
    print STDERR 'HeadlinesPlugin - ' . $_[0] . "\n" if $debug;
}

# =========================
sub doInit {

    return if $isInitialized;
    $isInitialized = 1;

    # Get plugin preferences
    $defaultRefresh =
      Foswiki::Func::getPreferencesValue('HEADLINESPLUGIN_REFRESH');
    $defaultRefresh = 60 unless length $defaultRefresh;
    $defaultLimit = Foswiki::Func::getPreferencesValue('HEADLINESPLUGIN_LIMIT');
    $defaultLimit = 100 unless length $defaultLimit;
    $defaultHeader =
      Foswiki::Func::getPreferencesValue('HEADLINESPLUGIN_HEADER')
      || '| *[[$link][$title ]]* |';
    $defaultFormat =
      Foswiki::Func::getPreferencesValue('HEADLINESPLUGIN_FORMAT')
      || '| [[$link][$title]] |';
    $useLWPUserAgent =
      Foswiki::Func::getPreferencesValue('HEADLINESPLUGIN_USELWPUSERAGENT')
      || 'on';
    $userAgentTimeout =
      Foswiki::Func::getPreferencesValue("HEADLINESPLUGIN_USERAGENTTIMEOUT");
    $userAgentTimeout = 20 unless length $userAgentTimeout;
    $userAgentName =
      Foswiki::Func::getPreferencesValue("HEADLINESPLUGIN_USERAGENTNAME")
      || 'FoswikiHeadlinesPlugin/'
      . $Foswiki::Plugins::HeadlinesPlugin::RELEASE;

    $useLWPUserAgent =~ s/^\s*(.*?)\s*$/$1/go;
    $useLWPUserAgent = ( $useLWPUserAgent =~ /on|yes|1/ ) ? 1 : 0;

}

# =========================
sub errorMsg {
    return
        $_[0]
      . '<span class="foswikiAlert">'
      . '<noautolink>' . "\n"
      . 'HeadlinesPlugin '
      . $_[1] . "\n"
      . '</noautolink>' . "\n"
      . '</span>';
}

# =========================
sub readRssFeed {
    my ( $theUrl, $theRefresh ) = @_;

    #writeDebug("readRssFeed($theUrl, $theRefresh)");

    my $cacheDir  = '';
    my $cacheFile = '';
    if ($theRefresh) {
        if ( defined &Foswiki::Func::getWorkArea ) {
            $cacheDir = Foswiki::Func::getWorkArea('HeadlinesPlugin');
        }
        else {
            my $foswikiWeb = $Foswiki::cfg{SystemWebName};
            $cacheDir =
                Foswiki::Func::getPubDir() . '/'
              . $foswikiWeb
              . '/HeadlinesPlugin';
            $cacheDir =~ /(.*)/;
            $cacheDir = $1;    # untaint (save because only internal variables)
        }
        $cacheFile = $cacheDir . '/_rss-' . md5_hex($theUrl);
        $cacheFile =~ /(.*)/;
        $cacheFile = $1;       # untaint
        if (   ( -e $cacheFile )
            && ( ( time() - ( stat(_) )[9] ) <= ( $theRefresh * 60 ) ) )
        {

      # return cached version if it exists and isn't too old. 1440 = 24h * 60min
            return Foswiki::Func::readFile($cacheFile);
        }
    }

    unless ( $theUrl =~ /^https?:\/\// ) {    # internal
        my ( $thisWeb, $thisTopic ) =
          Foswiki::Func::normalizeWebTopicName( $web, $theUrl );
        $theUrl = Foswiki::Func::getViewUrl( $thisWeb, $thisTopic );
        if ( $theUrl =~ /^\// ) {
            $theUrl = Foswiki::Func::getUrlHost() . $theUrl;
        }
    }

    #writeDebug("url=$theUrl");

    my ( $text, $errorMsg ) =
      $useLWPUserAgent ? &getUrlLWP($theUrl) : &getUrl($theUrl);
    return ( undef, "ERROR: $errorMsg" ) if $errorMsg;

    if ($theRefresh) {
        unless ( -e $cacheDir ) {

            # create the cache directory in the pub dir of the HeadlinesPlugin
            umask(002);
            mkdir( $cacheDir, 0775 );
        }

        # save text in cache file before returning it
        Foswiki::Func::saveFile( $cacheFile, $text );
    }

    return ( $text, undef );
}

# =========================
sub handleHeadlinesTag {
    my ( $thePre, $theArgs );
    ( $web, $topic, $thePre, $theArgs ) = @_;

    &doInit();

    my $href = Foswiki::Func::extractNameValuePair($theArgs)
      || Foswiki::Func::extractNameValuePair( $theArgs, 'href' );
    my $refresh = Foswiki::Func::extractNameValuePair( $theArgs, 'refresh' )
      || $defaultRefresh;
    my $limit = Foswiki::Func::extractNameValuePair( $theArgs, 'limit' )
      || $defaultLimit;
    my $header = Foswiki::Func::extractNameValuePair( $theArgs, 'header' )
      || $defaultHeader;
    my $format = Foswiki::Func::extractNameValuePair( $theArgs, 'format' )
      || $defaultFormat;

    $header =~ s/\$n([^a-zA-Z])/\n$1/gos;    # expand "$n" to new line
    $header =~ s/([^\n])$/$1\n/os;           # append new line if needed
    $header =~ s/\$percnt/\%/gos;
    $format =~ s/\$n([^a-zA-Z])/\n$1/gos;    # expand "$n" to new line
    $format =~ s/([^\n])$/$1\n/os;           # append new line if needed
    $format =~ s/\$t\b/\t/go;
    $format =~ s/\$percnt/\%/gos;

    unless ($href) {
        return errorMsg( $thePre, "href parameter (news source) is missing" );
    }

    my ( $raw, $msg ) = readRssFeed( $href, $refresh );
    return errorMsg( $thePre, $msg ) if $msg;

    my $text = $thePre . "<div class=\"headlinesRss\"><noautolink>\n";

    # distinguish rss from atom
    if ( $raw =~ /<feed xmlns=[^>]+?>/ ) {
        $text .= parseAtomFeed( $raw, $header, $format, $limit );
    }
    else {
        $text .= parseRssFeed( $raw, $header, $format, $limit );
    }
    $text .= "</noautolink></div>\n";

    return $text;
}

# =========================
sub parseRssFeed {
    my ( $raw, $header, $format, $limit ) = @_;

    #writeDebug("(1) raw=$raw");

    my $sub     = '';
    my $val     = '';
    my $text    = '';
    my $baseRef = '';

    if ( $raw =~ /<channel[^>]*>(.*?)<\/channel>/ ) {
        $sub = $1;
        if ( $sub =~ /(.*?)<item[^>]*>/g ) {
            $sub = $1;    # cut stuff above all <item>s
        }
        if ( $sub =~ /<title[^>]*>(.*?)<\/title>/ ) {
            $val = &recode($1);
            $header =~ s/\$(channel)?title/$val/gos;
        }
        if ( $sub =~ /<link[^>]*>\s*(.*?)\s*<\/link>/ ) {
            $val     = $1;
            $baseRef = $val;
            $baseRef =~ s/^(https?.\/\/.*?)\/.*$/$1/go;
            $header  =~ s/\$(channel)?link/$val/gos;
        }
        if ( $sub =~ /<description[^>]*>(.*?)<\/description>/ ) {
            $val = &recode($1);
            $header =~ s/\$(channel)?description/$val/gos;
        }
        if ( $sub =~ /<lastBuildDate[^>]*>(.*?)<\/lastBuildDate>/ ) {
            $val = $1;
            $header =~ s/\$(channel)?date/$val/gos;
        }
        if ( $sub =~ /<pubDate[^>]*>(.*?)<\/pubDate>/ ) {
            $val = $1;
            $header =~ s/\$(channel)?date/$val/gos;
        }
        if ( $sub =~ /<copyright[^>]*>(.*?)<\/copyright>/ ) {
            $val = &recode($1);
            $header =~ s/\$rights/$val/gos;
        }
        &parseDC( \$sub, \$header );
    }
    if ( $raw =~ /<image[^>]*>(.*?)<\/image>/ ) {
        $sub = $1;
        if ( $sub =~ /<title[^>]*>(.*?)<\/title>/ ) {
            $val = &recode($1);
            $header =~ s/\$imagetitle/$val/gos;
        }
        if ( $sub =~ /<url[^>]*>(.*?)<\/url>/ ) {
            $val = $1;
            if ( $baseRef && $val =~ /^\//o ) {
                $val = $baseRef . $val;    # fix relative image url
            }
            $header =~ s/\$imageurl/$val/gos;
        }
        if ( $sub =~ /<link[^>]*>\s*(.*?)\s*<\/link>/ ) {
            $val = $1;
            $header =~ s/\$imagelink/$val/gos;
        }
        if ( $sub =~ /<description[^>]*>(.*?)<\/description>/ ) {
            $val = &recode($1);
            $header =~ s/\$imagedescription/$val/gos;
        }
    }
    $header =~
      s/\$((channel|image)(title|link|description|url|date|rights))//go;
    $header =~
s/\$(rights|coverage|relation|language|source|identifier|format|date|contributor|creator|title|subject|description)//go;
    $text .= $header;

    $raw =~ s/<\/?items>//go;
    $raw =~ s/^.*?(<item[^>]*>)/$1/gos;    # cut stuff above all <item>s

    my $line  = "";
    my $ok    = 0;
    my $count = 0;
    foreach ( split( /<item[^>]*>/, $raw ) ) {
        next unless $_;

        #writeDebug("item='$_'");
        $line = $format;
        $ok   = 0;
        if (/<title[^>]*>(.*?)<\/title>/) {
            $val = &recode($1) || 'Untitled';
            $line =~ s/\$(item)?title/$val/gos;
            $ok = 1;
        }
        if (/<link[^>]*>\s*(.*?)\s*<\/link>/) {
            $val = $1;
            $val  =~ s/^http:\/\/.*\*(http:\/\/.*)$/$1/gos;    # yahoo fix
            $line =~ s/\$(item)?link/$val/gos;
            $ok = 1;
        }
        if ( &parseCONTENT( \$_, \$line ) ) {
            $ok = 1;
        }
        if (/<description[^>]*>(.*?)<\/description>/) {
            $val = &recode($1);
            $line =~ s/\$(item)?description/$val/gos;
            $ok = 1;
        }
        if (/<pubDate[^>]*>(.*?)<\/pubDate>/) {
            $val = $1;
            $line =~ s/\$(item)?date/$val/gos;
            $ok = 1;
        }
        if (/<date[^>]*>(.*?)<\/date>/) {
            $val = $1;
            $line =~ s/\$(item)?date/$val/gos;
            $ok = 1;
        }
        if (/<category[^>]*>(.*?)<\/category>/) {
            $val = $1;
            $line =~ s/\$(item)?category/$val/gos;
            $ok = 1;
        }
        if ( &parseDC( \$_, \$line ) ) {
            $ok = 1;
        }
        if ( &parseIMAGE( \$_, \$line ) ) {
            $ok = 1;
        }
        $line =~ s/\$title/Untitled/go;
        $line =~ s/\$(item)?(link|description|date|category)//go;
        $line =~
s/\$(rights|coverage|relation|language|source|identifier|format|date|contributor|creator|subject|description)//go;
        $text .= $line if ($ok);
        $count++;
        last if $count >= $limit;
    }

    # fix relative img urls
    $text =~ s/(<img .*?src=['"])\//$1$baseRef\//go if $baseRef;

    return $text;
}

# =========================
sub parseAtomFeed {
    my ( $raw, $header, $format, $limit ) = @_;

    my $sub     = '';
    my $val     = '';
    my $text    = '';
    my $baseRef = '';

    if ( $raw =~ /<feed.*?>(.*?)<\/feed>/ ) {
        $sub = $1;
        if ( $sub =~ /<title[^>]*>(.*?)<\/title>/ ) {
            $val = &recode($1);
            $header =~ s/\$(channel)?title/$val/gos;
        }
        if (   $sub =~ /<link[^>]*href="([^"]*)"[^>]*type="text\/html"[^>]*\/>/
            || $sub =~
            /<link[^>]*type="text\/html"[^>]*href="([^"]*)"[^>]*\/>/ )
        {
            $val     = $1;
            $baseRef = $val;
            $baseRef =~ s/^(https?.\/\/.*?)\/.*$/$1/go;
            $header  =~ s/\$(channel)?link/$val/gos;
        }
        if ( $sub =~ /<updated[^>]*>(.*?)<\/updated>/ ) {
            $val = $1;
            $header =~ s/\$(channel)?date/$val/gos;
        }
        if ( $sub =~ /<modified[^>]*>(.*?)<\/modified>/ ) {
            $val = $1;
            $header =~ s/\$(channel)?date/$val/gos;
        }

        #    if ($sub =~ /<link rel="icon" href="([^"]*)" [^>]*\/>/) {
        #	$val = $1;
        #	$header =~ s/\$imageurl/$val/gos;
        #    }
        if ( $sub =~ /<logo[^>]*>(.*?)<\/logo>/ ) {
            $val = $1;
            if ( $baseRef && $val =~ /^\//o ) {
                $val = $baseRef . $val;    # fix relative image url
            }
            $header =~ s/\$imageurl/$val/gos;
        }
        if ( $sub =~ /<rights[^>]*>(.*?)<\/rights>/ ) {
            $val = &recode($1);
            $header =~ s/\$rights/$val/gos;
        }
        if ( $sub =~ /<subtitle[^>]*>(.*?)<\/subtitle>/ ) {
            $val = &recode($1);
            $header =~ s/\$(channel)?description/$val/gos;
        }
        if ( $sub =~ /<tagline[^>]*>(.*?)<\/tagline>/ ) {
            $val = &recode($1);
            $header =~ s/\$(channel)?description/$val/gos;
        }
        $header =~ s/\$(image)?(title|link|description|url|date|rights)//go;
        $header =~
s/\$(rights|coverage|relation|language|source|identifier|format|contributor|creator|subject)//go;
        $text .= $header;

        $raw =~ s/.*?(<entry[^a-z])/$1/os;    # cut stuff above all entries
        my $line  = "";
        my $ok    = 0;
        my $count = 0;
        foreach ( split( /<entry[^>]*>/, $raw ) ) {
            next unless $_;
            $line = $format;
            $ok   = 0;
            if (/<title[^>]*>(.*?)<\/title>/) {
                $val = &recode($1) || 'Untitled';
                $line =~ s/\$(item)?title/$val/gos;
                $ok = 1;
            }
            if (   /<link[^>]*href="([^"]*)"[^>]*type="text\/html"[^>]*\/>/
                || /<link[^>]*type="text\/html"[^>]*href="([^"]*)"[^>]*\/>/ )
            {
                $val = $1;
                $val  =~ s/^http:\/\/.*\*(http:\/\/.*)$/$1/gos;    # yahoo fix
                $line =~ s/\$(item)?link/$val/gos;
                $ok = 1;
            }
            if (/<updated[^>]*>(.*?)<\/updated>/) {
                $val = $1;
                $line =~ s/\$(item)?date/$val/gos;
                $ok = 1;
            }
            if (/<author[^>]*>(.*?)<\/author>/) {
                $sub = $1;
                if ( $sub =~ /<name[^>]*>(.*?)<\/name>/ ) {
                    $val = &recode($1);
                    $line =~ s/\$contributor/$val/gos;
                    $ok = 1;
                }
            }
            if (/<created[^>]*>(.*?)<\/created>/) {
                $val = $1;
                $line =~ s/\$(item)?date/$val/gos;
                $ok = 1;
            }
            if (/<modified[^>]*>(.*?)<\/modified>/) {
                $val = $1;
                $line =~ s/\$(item)?date/$val/gos;
                $ok = 1;
            }
            if (/<content[^>]*>(.*?)<\/content>/) {
                $val = &recode($1);
                $line =~ s/\$(item)?description/$val/gos;
                $ok = 1;
            }
            if (/<summary[^>]*>(.*?)<\/summary>/) {
                $val = &recode($1);
                $line =~ s/\$(item)?description/$val/gos;
                $ok = 1;
            }
            if (/<category[^>]*>(.*?)<\/category>/) {
                $val = $1;
                $line =~ s/\$(item)?category/$val/gos;
                $ok = 1;
            }

            $line =~ s/\$(item)?title/Untitled/go;
            $line =~ s/\$(item)?(link|description|date|category)//go;
            $line =~
s/\$(rights|coverage|relation|language|source|identifier|format|contributor|creator|subject)//go;
            $text .= $line if ($ok);
            $count++;
            last if $count >= $limit;
        }
    }

    # fix relative img urls
    $text =~ s/(<img .*?src=['"])\//$1$baseRef\//go if $baseRef;

    return $text;
}

# =========================
# TODO: externalize this function to a place of more general use
sub recode {
    my $text = shift;

    unless ( $text =~ s/<\!\[CDATA\[(.*?)\]\]>/$1/gos ) {
        $text =~ s/&lt;/</go;
        $text =~ s/&gt;/>/go;
        $text =~ s/&amp;/&/go;
        $text =~ s/&quot;/"/go;
    }

    $text =~ s/&#xD;/\n/go;

    # TODO: partial utf8 support
    $text =~ s/\xc2\xae/&reg;/go;
    $text =~ s/\xc2\xab/&laquo;/go;
    $text =~ s/\xc2\xbb/&raquo;/go;

    $text =~ s/\xc3\xa8/&egrave;/go;
    $text =~ s/\xc3\xa9/&eacute;/go;
    $text =~ s/\xc3\xb1/&ntilde;/go;

    $text =~ s/\xe2\x80\xa2/&bull;/go;
    $text =~ s/\xe2\x80\xa6/&hellip/go;
    $text =~ s/\xe2\x80[\x93\x94]/-/go;    # SMELL: use matching entities
    $text =~ s/\xe2\x80[\x98\x99]/'/go;
    $text =~ s/\xe2\x80[\x9c\x9d]/''/go;

    $text =~ s/([\xc2\xc3])([\x80-\xbf])/chr(ord($1)<<6&0xC0|ord($2)&0x3F)/eg;

    # map integer representations to html entities
    $text =~ s/&#(\d+);/($1<160)?chr($1):'&'.($entityHash{$1}||"#$1").';'/ge;

    return $text;
}

# =========================
sub formatDCdate {
    my $date = shift;

    if ( $date =~ /(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d).*/ ) {
        my $year   = $1;
        my $month  = $2;
        my $day    = $3;
        my $hour   = $4;
        my $minute = $5;
        return "$year-$month-$day $hour\:$minute";
    }

    return $date;
}

# =========================
sub parseDC {
    my ( $input, $output ) = @_;
    my $ok = 0;
    my $val;

    if ( !$output ) {
        $output = $input;
    }

    #writeDebug("parseDC called");
    #writeDebug("- input = $$input");

    if ( $$input =~ /<dc:title[^>]*>(.*?)<\/dc:title>/ ) {
        $val = &recode($1);
        $$output =~ s/\$title/$val/gos;
        $ok = 1;
    }
    if ( $$input =~ /<dc:creator[^>]*>(.*?)<\/dc:creator>/ ) {
        $val = &recode($1);
        $$output =~ s/\$creator/$val/gos;
        $ok = 1;
    }
    if ( $$input =~ /<dc:subject[^>]*>(.*?)<\/dc:subject>/ ) {
        $val = &recode($1);
        $$output =~ s/\$subject/$val/gos;
        $ok = 1;
    }
    if ( $$input =~ /<dc:description[^>]*>(.*?)<\/dc:description>/ ) {
        $val = &recode($1);
        $$output =~ s/\$description/$val/gos;
        $ok = 1;
    }
    if ( $$input =~ /<dc:publisher[^>]*>(.*?)<\/dc:publisher>/ ) {
        $val = &recode($1);
        $$output =~ s/\$publisher/$val/gos;
        $ok = 1;
    }
    if ( $$input =~ /<dc:contributor[^>]*>(.*?)<\/dc:contributor>/ ) {
        $val = &recode($1);
        $$output =~ s/\$contributor/$val/gos;
        $ok = 1;
    }
    if ( $$input =~ /<dc:date[^>]*>(.*?)<\/dc:date>/ ) {
        $val = &formatDCdate($1);
        $$output =~ s/\$date/$val/gos;
        $ok = 1;
    }
    if ( $$input =~ /<dc:type[^>]*>(.*?)<\/dc:type>/ ) {
        $val = $1;
        $$output =~ s/\$type/$val/gos;
        $ok = 1;
    }
    if ( $$input =~ /<dc:format[^>]*>(.*?)<\/dc:format>/ ) {
        $val = $1;
        $$output =~ s/\$format/$val/gos;
        $ok = 1;
    }
    if ( $$input =~ /<dc:identifier[^>]*>(.*?)<\/dc:identifier>/ ) {
        $val = $1;
        $$output =~ s/\$identifier/$val/gos;
        $ok = 1;
    }
    if ( $$input =~ /<dc:source[^>]*>(.*?)<\/dc:source>/ ) {
        $val = $1;
        $$output =~ s/\$source/$val/gos;
        $ok = 1;
    }
    if ( $$input =~ /<dc:language[^>]*>(.*?)<\/dc:language>/ ) {
        $val = $1;
        $$output =~ s/\$language/$val/gos;
        $ok = 1;
    }
    if ( $$input =~ /<dc:relation[^>]*>(.*?)<\/dc:relation>/ ) {
        $val = $1;
        $$output =~ s/\$relation/$val/gos;
        $ok = 1;
    }
    if ( $$input =~ /<dc:coverage[^>]*>(.*?)<\/dc:coverage>/ ) {
        $val = $1;
        $$output =~ s/\$coverage/$val/gos;
        $ok = 1;
    }
    if ( $$input =~ /<dc:rights[^>]*>(.*?)<\/dc:rights>/ ) {
        $val = &recode($1);
        $$output =~ s/\$rights/$val/gos;
        $ok = 1;
    }

    #writeDebug("- output = $$output") if ($debug && $ok);

    return $ok;
}

# =========================
sub parseIMAGE {
    my ( $input, $output ) = @_;
    my $ok = 0;
    my $val;

    #writeDebug("- HeadlinesPlugin::parseIMAGE called");
    #writeDebug("- input = $$input");

    if ( $$input =~ /<image:item ([^>]*?)>(.*?)<\/image:item>/ ) {
        my $attrs = $1;
        my $boddy = $2;
        my $img   = "<img ";
        if ( $attrs =~ /rdf:about="([^"]*?)"/ ) {
            $img .= "src=\"$1\" ";
            $ok = 1;
        }
        if ( $boddy =~ /<.*?title>(.*?)<\/.*?title>/ ) {
            $img .= "alt=\"$1\" ";
        }
        if ( $boddy =~ /<image:width>(.*?)<\/image:width>/ ) {
            $img .= "width=\"$1\" ";
        }
        if ( $boddy =~ /<image:height>(.*?)<\/image:height>/ ) {
            $img .= "height=\"$1\" ";
        }

        if ($ok) {
            $img .= "/>";
            $$output =~ s/\$image/$img/gos;
        }
    }

    $$output =~ s/\$image//gos;

    #writeDebug("- output = $$output");

    return $ok;
}

# =========================
sub parseCONTENT {
    my ( $input, $output ) = @_;
    my $ok = 0;
    my $val;

    #writeDebug("- HeadlinesPlugin::parseCONTENT called");
    #writeDebug("input=$$input");

    if ( $$input =~ /<content:encoded[^>]*>(.*?)<\/content:encoded>/ ) {

        #writeDebug("found content:encoded");
        $val = &recode($1);
        if ($val) {
            $ok = 1;

            #$$output =~ s/\$content/$val/g;
            $$output =~ s/\$description/$val/g;
        }
    }

    $$output =~ s/\$content//g;

    return $ok;
}

# =========================
sub getUrlLWP {
    my $theUrl = shift;

    #writeDebug("called getUrlLWP($theUrl)");

    unless ($userAgent) {
        eval "use LWP::UserAgent";
        die $@ if $@;

        my $proxyHost = Foswiki::Func::getPreferencesValue('PROXYHOST') || '';
        my $proxyPort = Foswiki::Func::getPreferencesValue('PROXYPORT') || '';
        $proxyHost ||= $Foswiki::cfg{PROXY}{HOST};
        $proxyPort ||= $Foswiki::cfg{PROXY}{PORT};
        my $proxySkip = $Foswiki::cfg{PROXY}{SkipProxyForDomains} || '';

        $userAgent = LWP::UserAgent->new();
        $userAgent->agent($userAgentName);

        # don't leave the LWP default string there as
        # this is blocked by some sites, e.g. google news
        $userAgent->timeout($userAgentTimeout);
        if ( $proxyHost && $proxyPort ) {
            my $proxyURL = "$proxyHost:$proxyPort/";
            $proxyURL = 'http://' . $proxyURL
              unless ( $proxyURL =~ /^https?:\/\// );
            $userAgent->proxy( "http", $proxyURL );
            my @skipDomains = split( /[\,\s]+/, $proxySkip );
            $userAgent->no_proxy(@skipDomains);
        }
    }

    my $request = HTTP::Request->new( 'GET', $theUrl );
    $request->referer( Foswiki::Func::getViewUrl( $web, $topic ) );
    my $response = $userAgent->request($request);
    if ( $response->is_error ) {
        return ( undef, $response->status_line );
    }
    else {
        my $text = $response->content;
        $text =~ s/\r\n?/ /gos;
        $text =~ s/\n/ /gos;

        #$text =~ s/ +/ /gos;
        return ( $text, undef );
    }
}

# =========================
sub getUrl {
    my $theUrl = shift;

    my $host = '';
    my $port = 0;
    my $path = '';
    if ( $theUrl =~ /https?\:\/\/(.*?)\:([0-9]+)(\/.*)/ ) {
        $host = $1;
        $port = $2;
        $path = $3;
    }
    elsif ( $theUrl =~ /https?\:\/\/(.*?)(\/.*)/ ) {
        $host = $1;
        $path = $2;
    }
    return ( undef, "invalid format of the href parameter" ) unless $path;

 # figure out how to get to Foswiki::Net which is wide open in Cairo and before,
 # but Dakar uses the session object.
    my $text =
        $Foswiki::Plugins::SESSION->{net}
      ? $Foswiki::Plugins::SESSION->{net}->getUrl( $host, $port, $path )
      : Foswiki::Net::getUrl( $host, $port, $path );

    if ( $text =~ /text\/plain\s*ERROR\: (.*)/s ) {
        my $msg = $1;
        $msg =~ s/[\n\r]/ /gos;
        return ( undef, "Can't read $theUrl ($msg)" );
    }
    if ( $text =~ /HTTP\/[0-9\.]+\s*([0-9]+)\s*([^\n]*)/s ) {
        return ( undef, "Can't read $theUrl ($1 $2)" )
          unless $1 == 200;
    }
    $text =~ s/^.*?\n\n(.*)/$1/os;    # strip header
    $text =~ s/\r\n?/ /gos;
    $text =~ s/\n/ /gos;

    #$text =~ s/ +/ /gos;

    return ( $text, undef );
}

1;

