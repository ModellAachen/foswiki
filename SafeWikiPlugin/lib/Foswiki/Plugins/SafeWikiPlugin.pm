# See bottom of file for notices
package Foswiki::Plugins::SafeWikiPlugin;

use strict;
use Assert;
use Error ':try';
use Digest::MD5 qw(md5_base64);

use Foswiki::Plugins::SafeWikiPlugin::Parser ();

our $VERSION = '$Rev$';
our $RELEASE = '2.0.0';
our $SHORTDESCRIPTION =
  'Secure your Foswiki so it can\'t be used for mounting phishing attacks';
our $NO_PREFS_IN_TOPIC = 1;

our %FILTERIN;
our %FILTEROUT;
our $parser;
our %SIGNATURES;

my $web;
my $topic;

sub initPlugin {

    #my( $topic, $web, $user, $installWeb ) = @_;

    $topic = shift;
    $web   = shift;

    unless ($parser) {
        $parser = new Foswiki::Plugins::SafeWikiPlugin::Parser();
    }

    $Foswiki::cfg{Plugins}{SafeWikiPlugin}{Action} ||= 'FAIL';

    unless ( %SIGNATURES ) {
        foreach my $sig ( @{$Foswiki::cfg{Plugins}{SafeWikiPlugin}{SignaturesList}} ) {
            #print STDERR "Adding $sig";
            $SIGNATURES{$sig} = 1;
        }

        if ( $Foswiki::cfg{Plugins}{SafeWikiPlugin}{SignaturesTopic} ) {
            my ( $sigWeb, $sigTopic) = Foswiki::Func::normalizeWebTopicName('', $Foswiki::cfg{Plugins}{SafeWikiPlugin}{SignaturesTopic});
            my ($meta, $text) = Foswiki::Func::readTopic( $sigWeb, $sigTopic );
            if ( $text ) {
               $text =~ s/^\|\s?(.*?)\s?\|/&_addMD5($1)/msge;
            }
        }
    }

    return $parser ? 1 : 0;
}

sub _addMD5 {
    my $md5 = shift;
    if ( length($md5) eq 22 ) {
        print STDERR "Found $md5\n" if $md5;
        $SIGNATURES{$md5} = 1;
    }
    return '';
}

my $CONDITIONAL_IF    = "C\0NDITI\0N";
my $CONDITIONAL_ENDIF = "COND\1TI\1N";

# Handle the complete HTML page about to be sent to the browser
sub completePageHandler {

    #my($html, $httpHeaders) = @_;

    return unless $_[1] =~ m#^Content-type: text/html#mi;

    # Some ajax requests fetch text without being wrapped in <html>..</html>
    # It results in a parser error: Unexpected leaf: 0:  If the tags are missing,
    # wrap text in <html> tags so that the parser will function on html segments
    my $insertHtml = 0;
    unless ( $_[0] =~ m/<html\b/ ) {
        $insertHtml = 1;
        $_[0] = '<html>' . $_[0] . '</html>';
    }

    my @condifs;

    #<!--[if IE]><style type="text/css" media="screen">
    #pre {
    #	overflow-x:auto;
    #}
    #</style>
    #<![endif]-->

    # Parse the HTML and generate a parse tree
    # This handler can be patched into pre-4.2 revs of Foswiki
    $_[0] =~ s/(<!--\[if [^]]*\]>)(.*?)<!\[endif\]-->/
      push(@condifs, $1);
      "${CONDITIONAL_IF}$#condifs;$2$CONDITIONAL_ENDIF"/ges;

    my $holdHTML = $_[0];
    eval {
	my $tree = $parser->parseHTML( $_[0] );
	$_[0] =
	    $tree->generate( \&_filterURI, \&_filterHandler, \&_filterInline );
    };
    if ($@) {
        if ( $Foswiki::cfg{Plugins}{SafeWikiPlugin}{Action} eq 'WARN' ) {
            print STDERR
            "SAFEWIKI: exception while processing\n $@\n";
            $_[0] = $holdHTML;
        } else {
            my $e = $@;
            $_[0] = Foswiki::Func::loadTemplate('safewikierror') ||
            "Error loading safewiki error page. %EXCEPTION%";
            $_[0] =~ s/%EXCEPTION%/$e/;
            ASSERT(0, "SAFEWIKI: FAIL $e") if DEBUG &&
            $Foswiki::cfg{Plugins}{SafeWikiPlugin}{Action} eq 'ASSERT';
        }
    }

    $_[0] =~
s/${CONDITIONAL_IF}(\d+);(.*?)$CONDITIONAL_ENDIF/$condifs[$1]$2<![endif]-->/gs;

    # unwrap the text if we inserted the <html> tags.
    if ($insertHtml) {
         $_[0] =~ s/^<html>//;
         $_[0] =~ s/<\/html>$//;
    }
}

sub _filter {
    my ( $code, $type ) = @_;

    unless ( $type eq 'URI' ) {
        my $sig = md5_base64($code);
        print STDERR "SWP: $web.$topic: MATCH $sig\n" if ($SIGNATURES{$sig});
        return 1 if ($SIGNATURES{$sig});
        print STDERR "SWP: $web.$topic: " . md5_base64($code) . "($code) ($type) MD5 \n";
    }

    if ( scalar( $Foswiki::cfg{Plugins}{SafeWikiPlugin}{"Unsafe$type"} || '' ) )
    {
        unless ( defined( $FILTEROUT{$type} ) ) {

            # the eval expands $Foswiki::cfg vars
            $FILTEROUT{$type} = join( '|',
                map { s/(\$Foswiki::cfg({.*?})+)/eval($1)/ge; qr/($_)/ }
                  @{ $Foswiki::cfg{Plugins}{SafeWikiPlugin}{"Unsafe$type"} } );
        }
        return 0 if ( $code =~ /$FILTEROUT{$type}/ );
    }
    if ( scalar( $Foswiki::cfg{Plugins}{SafeWikiPlugin}{"Safe$type"} || '' ) ) {
        unless ( defined( $FILTERIN{$type} ) ) {

            # the eval expands $Foswiki::cfg vars
            $FILTERIN{$type} = join( '|',
                map { s/(\$Foswiki::cfg({.*?})+)/eval($1)/ge; qr/($_)/ }
                  @{ $Foswiki::cfg{Plugins}{SafeWikiPlugin}{"Safe$type"} } );
        }
        return 0 unless ( $code =~ /$FILTERIN{$type}/ );
    }
    return 1;
}

# Something was disarmed; either warn or error out. If DEBUG is enabled,
# raise an ASSERT.
sub _report {
    my ($m, $code) = @_;
    $m = "SafeWikiPlugin: $Foswiki::cfg{Plugins}{SafeWikiPlugin}{Action}: "
	. $m . " on "
	. ($ENV{REQUEST_URI} || 'command line')
	. ($ENV{QUERY_STRING} || '');
    if (DEBUG && $Foswiki::cfg{Plugins}{SafeWikiPlugin}{Action} eq 'ASSERT') {
	$code = md5_base64($code) . ") $code";
	ASSERT(0, $m . " ($code")
    }
    $m .= "\n$code";
    Foswiki::Func::writeWarning($m);
    return $Foswiki::cfg{Plugins}{SafeWikiPlugin}{Action} eq 'WARN';
}

sub _filterInline {
    my $code = shift;
    return '' unless defined $code && length($code);
    return $code if _filter( $code, 'Inline' );
    return $code if _report("Disarmed inline", $code);
    $code =~ s/<!--|-->/#/gs;
    return '<!-- Inline code disarmed by SafeWikiPlugin: $code -->';
}

sub _filterURI {
    my $uri = shift;

    return $uri if _filter( $uri, 'URI' );
    return $uri if _report("Disarmed URI", $uri);
    return $Foswiki::cfg{Plugins}{SafeWikiPlugin}{DisarmURI} ||
	'URI filtered by SafeWikiPlugin';
}

sub _filterHandler {
    my $code = shift;
    return '' unless defined $code && length($code);
    return $code if _filter( $code, 'Handler' );
    return $code if _report("Disarmed on*", $code);
    return $Foswiki::cfg{Plugins}{SafeWikiPlugin}{DisarmHandler} ||
	'/*Handler disarmed by SafeWikiPlugin*/';
}

1;
__DATA__

Copyright (C) 2007-2009 C-Dot Consultants http://c-dot.co.uk
All rights reserved
Author: Crawford Currie

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html

This notice must be retained in all copies or derivatives of this
code.
