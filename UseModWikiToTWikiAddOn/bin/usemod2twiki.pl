#!/usr/bin/perl
###########################################################################
### usemod2twiki.pl
### Copy and convert topics from a UseModWiki to a TWiki
###
### AUTHOR
###  l.m.orchard <deus_x@pobox.com> http://www.pobox.com/~deus_x
###
### TODO
###
### COPYRIGHT
###  Copyright (c) 2002, Leslie Michael Orchard.  All Rights Reserved.
###  This module is free software; you can redistribute it and/or
###  modify it under the same terms as Perl itself.
###
###########################################################################

use strict;
use vars
  qw( $usemod_root $usemod_script $usemod_conf @usemod_skip_topics $twiki_root $twiki_web );

### Configuration
BEGIN {
    ### Location of UseModWiki installation
    $usemod_root = "/home/user/public_html/cgi-bin";

    ### Link to the UseModWiki script (for instance "wiki.cgi" instead"
    $usemod_script = "$usemod_root/wiki.pl";

    ### UseModWiki configuration
    $usemod_conf = "$usemod_root/wiki.conf";

    @usemod_skip_topics =
      qw( BracketedLinks TextFormattingRules TextFormattingExamples WikiWiki );

    $twiki_root = "$usemod_root/twiki";
    $twiki_web  = "Usemod";
}

###########################################################################
###########################################################################

use lib ("$twiki_root/lib");
use Data::Dumper;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use CGI;

### Load and configure TWiki API
use TWiki;
use TWiki::Render;
use TWiki::Store::RcsWrap;

### Load and configure UseModWiki API
$_ = 'nocgi';
do "$usemod_conf";
$UseModWiki::UseConfig = 0;
$UseModWiki::EmbedWiki = 1;
$UseModWiki::q         = new CGI('');
require "$usemod_script";
&UseModWiki::InitLinkPatterns();
print "Loaded usemod wiki at $usemod_root.\n";

my %usemod_skip_topics = map { $_ => 1 } @usemod_skip_topics;

### UseModWiki expects to be in its root (at least in my install)
chdir($usemod_root);
my @all_pages = &UseModWiki::AllPagesList();

### Iterate over all UseModWiki pages
foreach my $name (@all_pages) {
    next if $usemod_skip_topics{$name};

    ### UseModWiki expects to be in its root (at least in my install)
    chdir($usemod_root);

    ### Load up the text for the page from UseModWiki
    print "Loading usemod topic '$name'...";
    &UseModWiki::OpenPage($name);
    &UseModWiki::OpenDefaultText();
    my $text = $UseModWiki::Text{'text'};
    print "loaded.\n";

    ### Convert formatting from UseModWiki to TWiki
    $text = &UseModLinesToTWiki( $text, $name );
    $text = &TWiki::Render::decodeSpecialChars($text);
    $text =~ s/ {3}/\t/go;

    ### TWiki expects to be in its root (at least in my install)
    chdir($twiki_root);

    ### Ensure UseModWiki topic name is valid for TWiki
    my $topic = $name;
    $topic =~ s/[^[:alnum:]]//g;

    ### Save the content as a TWiki topic
    print "Saving to TWiki as $topic...";
    my ( $meta, $tmp ) = &TWiki::Store::readTopic( $twiki_web, $topic );
    my $error =
      &TWiki::Store::saveTopic( $twiki_web, $topic, $text, $meta, "", undef,
        1 );
    print "saved.\n";
}

exit(0);

###########################################################################

# {{{ FixWikiWord: Fix UseModWiki words for TWiki

sub FixWikiWord {
    my ( $parent_topic, $word ) = @_;

    $word =~ s/^\//$parent_topic/;
    $word =~ s/\///g;

    return "$word";
}

# }}}
# {{{ TWikiBullet: Generate a TWiki-style bullet

sub TWikiBullet {
    my ( $bullet, $level, $txt ) = @_;
    return ( "   " x $level ) . "$bullet $txt";
}

# }}}
# {{{ TWikiHeading: Generate a TWiki-style heading

sub TWikiHeading {
    my ( $pre, $depth, $text ) = @_;

    $depth = length($depth);
    $depth = 6 if ( $depth > 6 );
    return $pre . "---" . ( "+" x $depth ) . " $text";
}

# }}}
# {{{ UseModLinesToTWiki: Convert UseModWiki formatting to TWiki formatting

sub UseModLinesToTWiki {
    my ( $pageText, $name ) = @_;

    my $IndentLimit  = 10;
    my $code         = '';
    my $oldCode      = '';
    my $processingOn = 0;
    my $inPre        = 0;
    my @htmlStack    = ();
    my $depth        = 0;
    my $pageHtml     = "";

    foreach ( split( /\n/, $pageText ) ) {    # Process lines one-at-a-time
        $_ .= "\n";

        # 	  if (s/^(\;+)([^:]+\:?)\:/<dt>$2<dd>/) {
        # 		  $code = "DL";
        # 		  $depth = length $1;
        if (s/^(\:+)/<dt><dd>/) {
            $code  = "DL";
            $depth = length $1;

            # 	  } elsif (s/^(\*+)/<li>/) {
            # 		  $code = "UL";
            # 		  $depth = length $1;
            # 	  } elsif (s/^(\#+)/<li>/) {
            # 		  $code = "OL";
            # 		  $depth = length $1;
            # 	  } elsif (/^[ \t].*\S/) {
        }
        elsif (/^[ \t].*\S/) {
            $code  = "PRE";
            $depth = 1;
        }
        else {
            $depth = 0;
        }

        while ( @htmlStack > $depth ) {    # Close tags as needed
            $pageHtml .= "</" . pop(@htmlStack) . ">\n";
        }
        if ( $depth > 0 ) {
            $depth = $IndentLimit if ( $depth > $IndentLimit );
            if (@htmlStack) {              # Non-empty stack
                $oldCode = pop(@htmlStack);
                if ( $oldCode ne $code ) {
                    $pageHtml .= "</$oldCode><$code>\n";
                }
                push( @htmlStack, $code );
            }
            while ( @htmlStack < $depth ) {
                push( @htmlStack, $code );
                $pageHtml .= "<$code>\n";
            }
        }

        #		s/----+/<hr noshade size=1>/g;
        s/====+/<hr noshade size=2>/g;

        s/\'\'\'\'\'(.*?)\'\'\'\'\'/__$1__/g;
        s/\'\'\'(.*?)\'\'\'/\*$1*/g;
        s/\'\'(.*?)\'\'/_$1_/g;
        s/^\;+([^:]+\:?)\:(.*)/   $1: $2/g;

        s/(^|\n)\s*(\=+)\s+([^\n]+)\s+\=+/&TWikiHeading($1, $2, $3)/geo;
        s/^(\*+) (.*)/&TWikiBullet('*', length $1, $2)/geo;
        s/^(\#+) (.*)/&TWikiBullet('1', length $1, $2)/geo;

        s/\[$UseModWiki::UrlPattern\s+([^\]]+?)\]/\[\[$1\]\[$2\]\]/g;
        s/\[$UseModWiki::InterLinkPattern\s+([^\]]+?)\]/\[\[$1\]\[$2\]\]/g;
        s/\[$UseModWiki::LinkPattern\s+([^\]]+?)\]/\[\[$1\]\[$2\]\]/g;

        s/($UseModWiki::LinkPattern)/&FixWikiWord($name, $1)/geo;

        $pageHtml .= $_;
    }
    while ( @htmlStack > 0 ) {
        $pageHtml .= "</" . pop(@htmlStack) . ">\n";
    }

    return $pageHtml;
}

# }}}
