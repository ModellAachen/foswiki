# InterwikiPreviewPlugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2007-2011 Ian Bygrave, ian@bygrave.me.uk
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

# Rule objects store the InterWikiPreviews configuration.
# There is one rule object per rule alias.

package Foswiki::Plugins::InterwikiPreviewPlugin::Rule;

use Foswiki::Func;
use Cache::FileCache;

my $pluginName = "InterwikiPreviewPlugin";
my $debug      = 0;

sub enableDebug {
    $debug = 1;
}

# Forget all rules
sub reset {
    Foswiki::Func::setSessionValue( $pluginName . 'Rules', {} );
}

# Create a new rule
sub new {
    my ( $class, $alias, $url, $format, $info, $reload ) = @_;

    # alias: The part
    # url: The URL to retrieve data from, may contain $page
    # format: XML or JSON
    # info: The text of the information to be appended to Interwiki links,
    #       with the %INTERWIKIPREVIEWFIEL{}% fields not expanded
    # reload: Reload interval in seconds or 0

    Foswiki::Func::writeDebug("- ${pluginName}::Rule::new( $alias )") if $debug;

    my $cache = new Cache::FileCache(
        {
            'cache_root' => Foswiki::Func::getWorkArea($pluginName) . "/cache",
            'directory_umask' => '022',
            'namespace'       => $alias
        }
    );

    my $this = {
        alias  => $alias,
        format => $format,
        info   => $info,
        reload => $reload,
        cache  => $cache,
        url    => $url,
    };

    Foswiki::Func::getSessionValue( $pluginName . 'Rules' )->{$alias} =
      bless( $this, $class );

    return $this;
}

sub get {

    # Find the Rule object for the give alias.
    my ( $class, $alias ) = @_;
    return Foswiki::Func::getSessionValue( $pluginName . 'Rules' )->{$alias};
}

sub restHandler {

    # Handle a REST query of the form: rest/$pluginName/$alias?page=$page
    # Find the rule for $alias,
    # expand its URL for $page
    # and retrieve the contents of that URL
    my ( $this, $session, $subject, $verb ) = @_;
    Foswiki::Func::writeDebug(
        "- ${pluginName}::Rule::restHandler($subject,$verb,$page)")
      if $debug;

    my $query = Foswiki::Func::getRequestObject();
    return unless $query;

    my $httpCacheControl =
      $Foswiki::cfg{Plugins}{InterwikiPreviewPlugin}{HttpCacheControl};

    # Extract $page from cgiQuery
    my $page = $query->param('page');

    # Check for 'Cache-control: no-cache' in the HTTP request
    unless ( $httpCacheControl
        && $query->http('Cache-control') =~ /no-cache/o )
    {

        # Look for cached response
        my $text = $this->{cache}->get($page);
        if ( defined $text ) {
            if ($debug) {
                my $expiry =
                  $this->{cache}->get_object($page)->get_expires_at - time();
                Foswiki::Func::writeDebug(
"- ${pluginName}::Rule::restHandler ${page} cached for ${expiry}s"
                );
            }
            $text =~ s/^(.*?\n)\n(.*)/$2/s;
            if ( $1 =~ /content\-type\:\s*([^\n]*)/ois ) {
                Foswiki::Func::setSessionValue( $pluginName . 'ContentType',
                    $1 );
            }
            return $text;
        }
    }
    my $path = "";
    my $url  = $this->{url};
    if ( !( $url =~ s/\$page/$page/go ) ) {

        # No $page in URL to expand, append $page instead
        $url = $url . $page;
    }
    my $response = Foswiki::Func::getExternalResource($url);
    if ( $response->is_error() ) {
        my $msg = "Code " . $response->code() . ": " . $response->message();
        $msg =~ s/[\n\r]/ /gos;
        Foswiki::Func::writeDebug(
            "- ${pluginName}::Rule ERROR: Can't read $url ($msg)")
          if $debug;
        return "#ERROR: Can't read $url ($msg)";
    }
    else {
        $text             = $response->content();
        $headerAndContent = 0;
    }
    my $expiry = $this->{reload};
    if ( $expiry == 0 ) {
        $expiry =
          $Foswiki::Cfg{Plugins}{InterwikiPreviewPlugin}{DefaultCacheExpiry};
    }
    $text =~ s/\r\n/\n/gos;
    $text =~ s/\r/\n/gos;

    # Check for 'Cache-control: no-store' in the HTTP request
    unless ( $httpCacheControl
        && $query->http('Cache-control') =~ /no-store/o )
    {
        $this->{cache}->set( $page, $text, $expiry );
    }
    $text =~ s/^(.*?\n)\n(.*)/$2/s;
    if ( $1 =~ /content\-type\:\s*([^\n]*)/ois ) {
        Foswiki::Func::setSessionValue( $pluginName . 'ContentType', $1 );
    }
    return $text;
}

# end of class Rule

1;
