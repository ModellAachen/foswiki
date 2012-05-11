# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Oliver Krueger <oliver@wiki-one.net>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 2 as published by the Free Software Foundation.
# For more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.
package Foswiki::Plugins::BrowserBoosterPlugin;

use strict;

require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version

use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev$';
$RELEASE = '2008-12-27';
$SHORTDESCRIPTION =
  'Embeds js and css files into the page to reduce the number of http objects.';
$NO_PREFS_IN_TOPIC = 1;
$pluginName        = 'BrowserBoosterPlugin';

use constant DEBUG => 0;     # toggle me

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.2 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Plugin correctly initialized
    return 1;
}

sub completePageHandler {

    #my ( $text, $header ) = @_;

    Foswiki::Func::writeDebug("- ${pluginName}::completePageHandler()")
      if DEBUG;

    # import javascript
    $_[0] =~
s/(<script\s+type=.text\/javascript.\s+src=[^>]+><\/script>)/&importJavascript($1)/gei;

    # import css via <link>
    my $prefix = '<style type="text/css"><!-- ' . "\n";
    my $suffix = "\n--></style>";
    $_[0] =~
s/<link\s+rel=.stylesheet.\s+href=["']?(.*?)["']?\s+type=["']?text\/css["']?[^>]*?>/&importStylesheet($1,$prefix,$suffix)/gei;

    # search <style>-tags for @import directives
    $_[0] =~
      s/(<style[^>]*?>)(.*?)(<\/style>)/&doStyleContainer($2,$1,$3)/geism;

    # might be done better with recursive regexes
}

sub readFile {
    my $name = shift;
    open( IN_FILE, "<$name" ) || return '';
    local $/ = undef;
    my $data = <IN_FILE>;
    close(IN_FILE);
    $data = '' unless ( defined($data) );
    return $data;
}

sub importJavascript {
    my $text = $_[0];

    # determine filename from url
    $text =~ m/src=["'](.*?)["']/i;
    my $file = $1;
    my $src  = $1;
    $file =~ s/.*$Foswiki::cfg{PubUrlPath}/$Foswiki::cfg{PubDir}/g;

    # read file
    my $fileContent = readFile($file);

    # return container
    return $text unless $fileContent;    # just to make sure

    $fileContent =~ s/<(\/?script)/&lt;$1/go;
    return
        "\n<!-- BrowserBoosterPlugin: $src -->\n"
      . '<script type="text/javascript">' . "\n"
      . $fileContent
      . "\n</script>\n";
}

sub parseStylesheet {
    my $css = $_[0];
    $css =~
s/(.*?)\@import\s+url\(["']?(.*?)["']?\).*?;(.*)/&importStylesheet($2,$1,$3)/ge;
    return $css;
}

sub rewriteUrls {
    my ( $css, $base ) = @_;
    my $host = $Foswiki::cfg{DefaultUrlHost};
    my $pub  = $Foswiki::cfg{PubUrlPath};

    # rewrite /my/path/file.css
    $css =~ s/url\(["']?\/([^;]*?)["']?\)/url('$host\/$1')/g;

    # rewrite file.css
    $css =~ s/url\(["']?([^\/][^:]*?)["']?\)/url('$base$1')/g;

    return $css;
}

sub importStylesheet {
    my ( $url, $prefix, $suffix ) = @_;
    my $retval = "";
    my $file   = $url;
    $file =~ s/.*$Foswiki::cfg{PubUrlPath}/$Foswiki::cfg{PubDir}/g;

    if ($file) {
        my $fileContent = readFile($file);

        # determine current base path and rewrite urls
        $url =~ m/^(.*\/)[^\/]+$/;
        $retval = rewriteUrls( $fileContent, $1 );

        # recursion
        $retval = parseStylesheet($retval);

        # SMELL: We should maintain a list of visited urls to prevent loops
    }

    return $prefix . "/* BrowserBoosterPlugin: $url */\n" . $retval . $suffix;
}

sub doStyleContainer {
    my ( $content, $prefix, $suffix ) = @_;

    # import css via @import
    $content =~
      s/\@import\s+url\(["']?(.*?)["']?\).*?;/&importStylesheet($1,"","")/gei;

    # $prefix = "\n<!-- " . $1 . " -->\n" . $prefix;

    return $prefix . $content . $suffix;
}

1;
