#!/usr/local/bin/perl -wI.
#
# GenPDFAddOn.pm (converts Foswiki page to PDF using HTMLDOC)
#    (based on PrintUsingPDF pdf script)
#
# This script Copyright (c) 2005 Cygnus Communications
# and distributed under the GPL (see below)
#
# Foswiki WikiClone (see wiki.pm for $wikiversion and other info)
#
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
# Copyright (C) 1999 Peter Thoeny, peter@thoeny.com
# Additional mess by Patrick Ohl - Biomax Bioinformatics AG
# January 2003
# fixes for Foswiki 4.2 (c) 2008 SvenDowideit@fosiki.com
# 24-Dec-2008 - litt@acm.org
# Fixes for images & title page segfaults.  Include some patches
# from the plugin wiki.  Added
# pdffirstpage GENPDFADDON_FIRSTPAGE toc p1, c1, toc
# pdfdestination GENPDFADDON_DESTINATION view view,save
# pdfpagelayout GENPDFADDON_PAGELAYOUT single single, one, twoleft, tworight
# pdfpagemode GENPDFADDON_PAGEMODE outline document, outline, fullscreen
# pdftitledoc GENPDFADDON_TITLEDOC undef document (file) as title
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

=pod

=head1 Foswiki::Contrib::GenPDFAddOn

Foswiki::Contrib::GenPDFAddOn - Displays Foswiki page as PDF using HTMLDOC

=head1 DESCRIPTION

See the GenPDFAddOn Foswiki topic for a description.

=head1 METHODS

Methods with a leading underscore should be considered local methods and not called from
outside the package.

=cut

package Foswiki::Contrib::GenPDFAddOn;

use strict;

use CGI;
use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version
use File::Temp qw( tempfile );
use Error qw( :try );

# This should always be $Rev$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
our $VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
our $RELEASE = '1.2';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION =
  'Generate a PDF from a Foswiki topic or topic hierarchy';

$| = 1;    # Autoflush buffers

our $query;
our %tree;
our %prefs;

our $NO_PREFS_IN_TOPIC = 1;    # Don't read the Plugin topic for preferences.

# Need to keep temporary image files around until htmldoc runs,
# so keep the file handles at the upper level
my @tempfiles = ();
my $tempdir;

# Regex strings for manipulating tags
#  - Single-quoted string
my $reSqString = qr{
      \'
      [^\']*
      \'
    }x;

#  - Double-quoted string
my $reDqString = qr{
      \"
      [^\"]*
      \"
    }x;

#  - Attribute delimited by single or double quotes, or by spaces.
my $reAttrValue = qr{
      (?: $reSqString | $reDqString | [^\'\"\s]+ )
    }x;

#  - Set to true if the document contains html headings
#    If the document doesn't have any headings, force to webpage or continuous output.
my $hasHeadings = '';

=pod

=head2 _fixTags($text)

Expands tags in the passed in text to the appropriate value in the preferences hash and
returns modified $text.
 
=cut

sub _fixTags {
    my ($text) = @_;

    $text =~ s|%GENPDFADDON_BANNER%|$prefs{'banner'}|g;
    $text =~ s|%GENPDFADDON_TITLE%|$prefs{'title'}|g;
    $text =~ s|%GENPDFADDON_SUBTITLE%|$prefs{'subtitle'}|g;

    return $text;
}

=pod

=head2 _getRenderedView($webName, $topic)

Generates rendered HTML of $topic in $webName using Foswiki rendering functions and
returns it.
 
=cut

sub _getRenderedView {
    my ( $webName, $topic, $rev ) = @_;

    my $text = Foswiki::Func::readTopicText( $webName, $topic, $rev );

    # FIXME - must be a better way?
    if ( $text =~ /^http.*\/.*\/oops\/.*oopsaccessview$/ ) {
        return "Sorry, this topic is not accessible at this time."
          if $prefs{'recursive'};    # no point spoiling _everything_
        Foswiki::Func::redirectCgiQuery( $query, $text );
    }

    my $skin = $prefs{'cover'} . ',' . $prefs{'skin'};
    my $tmpl = Foswiki::Func::readTemplate( $prefs{'template'}, $skin )
      || '%TEXT%';

    my ( $start, $end );
    if ( $tmpl =~ m/^(.*)%TEXT%(.*)$/s ) {
        my @starts = split( /%STARTTEXT%/, $1 );
        if ( $#starts > 0 ) {

            # we know that there is something before %STARTTEXT%
            $start = $starts[0];
            $text  = $starts[1] . $text;
        }
        else {
            $start = $1;
        }
        my @ends = split( /%ENDTEXT%/, $2 );
        if ( $#ends > 0 ) {

            # we know that there is something after %ENDTEXT%
            $text .= $ends[0];
            $end = $ends[1];
        }
        else {
            $end = $2;
        }
    }
    else {
        my @starts = split( /%STARTTEXT%/, $tmpl );
        if ( $#starts > 0 ) {

            # we know that there is something before %STARTTEXT%
            $start = $starts[0];
            $text  = $starts[1];
        }
        else {
            $start = $tmpl;
            $text  = '';
        }
        $end = '';
    }

    $text =~ s/\%TOC({.*?})?\%//g;    # remove Foswiki TOC
    $text = Foswiki::Func::expandCommonVariables( $start . $text . $end,
        $topic, $webName );
    $text = Foswiki::Func::renderText($text);

    return $text;
}

=pod

=head2 _extractPdfSections

Removes the text not found between PDFSTART and PDFSTOP HTML
comments. PDFSTART and PDFSTOP comments must appear in pairs.
If PDFSTART is not included in the text, the entire text is
return (i.e. as if PDFSTART was at the beginning and PDFSTOP
was at the end).

=cut

sub _extractPdfSections {
    my ($text) = @_;

    # If no start or stop tag, just return everything
    return $text if ( $text !~ /<!--\s*PDFSTART\s*-->/ );
    return $text if ( $text !~ /<!--\s*PDFSTOP\s*-->/ );

    my $output = "";
    while ( $text =~ /(.*?)<!--\s*PDFSTART\s*-->(.*?)<!--\s*PDFSTOP\s*-->/sg ) {
        $output .= $2;
    }
    return $output;
}

=pod

=head2 _getHeaderFooterData($webName)

If header/footer topic is present in $webName, gets it, expands local tags, renders the
rest, and returns the data. "Local tags" (see _fixTags()) are expanded first to allow
values passed in from the query to have precendence.
 
=cut

sub _getHeaderFooterData {
    my ($webName) = @_;

    # Get the header/footer data (if it exists)
    my $text  = "";
    my $topic = $prefs{'hftopic'};

    # Get a topic name without any whitespace
    $topic =~ s|\s||g;

    ( $webName, $topic ) =
      Foswiki::Func::normalizeWebTopicName( $webName, $topic );

    if ( $prefs{'hftopic'} ) {
        $text = Foswiki::Func::readTopicText( $webName, $topic );
    }

    # FIXME - must be a better way?
    if ( $text =~ /^http.*\/.*\/oops\/.*oopsaccessview$/ ) {
        Foswiki::Func::redirectCgiQuery( $query, $text );
    }

    # Extract the content between the PDFSTART and PDFSTOP comment markers
    $text = _extractPdfSections($text);
    $text = _fixTags($text);

    my $output = "";

# Expand common variables found between quotes. We have to jump through this loop hoop
# as the variables to expand occur inside html comments so just expanding variables in
# the full text doesn't do anything
    for my $line ( split( /(?=<)/, $text ) ) {
        if ( $line =~ /([^"]*")(.*)("[^"]*)/g ) {
            my $start = $1;
            my $var   = $2;
            my $end   = $3;

            # Expand common variables and render
            #print STDERR "var = '$var'\n"; #DEBUG
            $var =
              Foswiki::Func::expandCommonVariables( $var, $topic, $webName );
            $var = Foswiki::Func::renderText($var);
            $var =~ s/<.*?>|\n|\r//gs
              ;    # htmldoc can't use HTML tags in headers/footers
                   #print STDERR "var = '$var'\n"; #DEBUG
            $output .= $start . $var . $end;
        }
        else {
            $output .= $line;
        }
    }

    return $output;
}

=pod

=head2 _createTitleFile($webName)

If title page topic is present in $webName, gets it, expands local tags, renders the
rest, and returns the data. "Local tags" (see _fixTags()) are expanded first to allow
values passed in from the query to have precendence.

=cut

sub _createTitleFile {
    my ($webName) = @_;

    my $text  = '';
    my $topic = $prefs{'titletopic'};

    ( $webName, $topic ) =
      Foswiki::Func::normalizeWebTopicName( $webName, $topic );

    _writeDebug("building title topic  $topic") if $prefs{'debug'};    # DEBUG

    # Get a topic name without any whitespace
    $topic =~ s|\s||g;

    # Get the title topic (if it exists)
    if ( $prefs{'titletopic'} ) {
        my $doc = $prefs{'titledoc'};
        if ($doc) {
            _writeDebug(
"building title topic from an attachment  $webName, $topic, $doc"
            ) if $prefs{'debug'};                                      # DEBUG
            $text = Foswiki::Func::readAttachment( $webName, $topic, $doc );
            if ($text) {
                $doc =~ m/^.*\.(\w+)$/;
                my ( $fh, $name ) = tempfile(
                    'GenPDFAddOnXXXXXXXXXX',
                    DIR    => File::Spec->tmpdir(),
                    SUFFIX => ( $1 || '.html' )
                );
                open $fh, ">$name";
                binmode $fh;
                print $fh $text;
                close $fh;
                return $name;
            }
            $text = "Unable to read $webName.$topic/$doc for title";
        }
        else {
            _writeDebug("building title topic from a topic  $webName, $topic")
              if $prefs{'debug'};    # DEBUG
            $text .= Foswiki::Func::readTopicText( $webName, $topic );
            if ( $text =~ /^http.*\/.*\/oops\/.*oopsaccessview$/ ) {
                _writeDebug("Access exception reading   $webName, $topic")
                  ;                  # DEBUG
            }

        }
    }

    # FIXME - must be a better way?
    if ( $text =~ /^http.*\/.*\/oops\/.*oopsaccessview$/ ) {
        Foswiki::Func::redirectCgiQuery( $query, $text );
    }

    # Extract the content between the PDFSTART and PDFSTOP comment markers
    $text = _extractPdfSections($text);
    $text = _fixTags($text);

    # Now render the rest of the topic
    $text = Foswiki::Func::expandCommonVariables( $text, $topic, $webName );
    $text = Foswiki::Func::renderText($text);

    # Keep the body only.  A new header will be added later.
    $text =~ s%.*<body[^>]*>%%is;
    $text =~ s%</body>.*%%is;

    # remove <nop> tags
    $text =~ s/<nop>//g;

    # FIXME - send to _fixHtml
    # As of HtmlDoc 1.8.24, it only handles HTML3.2 elements so
    # convert some common HTML4.x elements to similar HTML3.2 elements
    $text =~ s/&ndash;/&shy;/g;
    $text =~ s/&[lr]dquo;/"/g;    #"
    $text =~ s/&[lr]squo;/'/g;    #'
    $text =~ s/&brvbar;/|/g;

    # replace arrows
    $text =~ s/&rarr;/->/g;
    $text =~ s/&larr;/<-/g;
    $text =~ s/&harr;/<->/g;
    $text =~ s/&rArr;/=>/g;
    $text =~ s/&lArr;/<=/g;
    $text =~ s/&hArr;/<=>/g;

# convert FoswikiNewLinks to normal text
# FIXME - should this be a preference? - should use setPreferencesValue($name, $val) to set NEWTOPICLINK

    $text =~ s{
      <span\s*class="foswikiNewLink">     # Start span of a new link
      (.*?)                               # The linked word - non-greedy
      <a\s+                               # Start of the create link
      .*?                                 # The rest of the tag - non-greedy match
      >\?                                 # Close tag and question mark
      </a>                                # Closing link
      </span>                             # Closing span
      }{$1}sgx;

    # Fix the image tags to use hard-disk path rather than url paths.
    # This is needed in case wiki requires read authentication like SSL client
    # certificates.
    $text = _fixImages($text);

    # Fully qualify any unqualified URLs (to make it portable to another host)
    my $url = Foswiki::Func::getUrlHost();
    $text =~ s{
          <a\s+                                   # starting img tag plus space
          ( (?: \w+ \s*=\s* $reAttrValue \s+ )* ) # 0 or more word = value - Assign to $1
          [hH][rR][eE][fF]\s*                     # href = with or without spaces
          (  =\s*[\"\']?                          # starts quote delimitied
          )/
         }{<a $1 href$2$url/}sgx;

    # Save it to a file
    my ( $fh, $name ) = tempfile(
        'GenPDFAddOnXXXXXXXXXX',
        DIR => $tempdir,

        #UNLINK => 0,          # DEBUG
        SUFFIX => '.html'
    );
    open $fh, ">$name";

    print $fh $text;

    close $fh;
    return $name;
}

=pod

=head2 _shiftHeaders($html)

Functionality from original PDF script.

=cut

sub _shiftHeaders {
    my ( $html, $shift ) = @_;

    if ( $shift != 0 ) {
        my $newHead;
        _writeDebug("-- shifting headers $shift ");

# You may want to modify next line if you do not want to shift _all_ headers.
# I leave for example all header that contain a digit folowed by a point.
# Look like this:
# $html =~ s&<h(\d)>((?:(?!(<h\d>|\d\.)).)*)</h\d>&'<h'.($newHead = ($1+$sh)>6?6:($1+$sh)<1?1:($1+$sh)).'>'.$2.'</h'.($newHead).'>'&gse;
# NOTE - htmldoc allows headers up to <h15>

        $html =~ s{
             <h                                      # starting header tag
             ([\d]{1,2})                             # $1 is 1 or 2 digits
             (.*?)                                   # 0 or more word = value - Assign to $2
             >                                       # End the tag
             (.*?)                                    # Non-greedy string to $3  Need 0 or more - seeing some empty headings.
             </h\1>                                  # End tag with backref
          }{'<h'.
             ($newHead = ($1+$shift) > 15 ? 15 :     # Trinary - if heading >= 15, then set it to 15 else
               ($1+$shift) < 1 ? 1 : ($1+$shift)) .    # if heading less than 1, set to 1.
             $2 . '>' .                              # Any style attributes and close tag
             $3 .                                    # The title
             '</h' . ($newHead) .  '>'               # Close the title.
          }sgxei;
    }

    return $html;
}

=head2 _fixImages($html,nt)

Extract all local server image names and convert to temporary files
Images that are relative to the server pub path or any images
that are fully qualified by server URL to the pub directory need to
be converted to temp files to avoid http / https authorization issues
on authenticated servers, and to validate image access throught the
Foswiki access controls.

if nt is set to true, then return a simple filename instead of an html tag.

=cut

sub _fixImages {
    my $html = $_[0];
    my $notag = $_[1] || 0;
    my %infoForImages;
    my $Foswikiurl = Foswiki::Func::getUrlHost();
    my $pubpath    = Foswiki::Func::getPubUrlPath();

    # Extract all of the image URLs from the html page

    my $reImgSrc = qr{
      <[iI][mM][gG]                                             # <img 
        \s+                                                     # space
      (?: \w+ \s*=\s* $reAttrValue \s+ )*                       # 0 or more word = value
      [sS][rR][cC] \s*=\s*                                      # src=
      (?: (?:\'([^\']+)\') | (?:\"([^\"]+)\") | ([^\'\"\s]+) )  # delimited value
      (?: \s+ \w+ \s*=\s* $reAttrValue )*                       # 0 or more word = value
      \s*/?>                                                    # ending bracket
    }x;

    my @imgsrc = $html =~ m/$reImgSrc/gs;

    foreach my $imgurl (@imgsrc) {
        if ( !defined $imgurl ) {
            next;
        }    # Regex will return undefined matches for non-matching cases
        if ( !( ( $imgurl =~ m{^$pubpath/} ) || ( $imgurl =~ m{^$Foswikiurl} ) )
          )
        {
            next;
        }    # Skip images foreign to this site
             #print STDERR $url."\n";  #DEBUG
         # Parse the url into the Foswiki components, starting from the /pub/ path  /pub/web/topic/filename
        ( my $imgweb, my $imgtopic, my $imgfile ) =
          ( $imgurl =~ m{$pubpath/([^/]+)/([^/]+)/(.*)$} );
        $infoForImages{$imgurl} =
          { # Save the information into a hash keyed by $imgurl to eliminate duplicate URLs
            url   => $imgurl,
            web   => $imgweb,
            topic => $imgtopic,
            file  => $imgfile,
          };
    }
    foreach my $imgInfo ( values(%infoForImages) ) {
        my $imgurl = $imgInfo->{url};

# Create a temporary file and ask Foswiki to copy the attachment into the temp file
        my $tempfh = new File::Temp(
            TEMPLATE => 'GenPDFImgXXXXXXXXXXXX',
            DIR      => $tempdir,
            UNLINK   => 0
        );    #DEBUG
        push @tempfiles, $tempfh;  # Save the temp file handle for later cleanup

        try {
            _writeDebug( "Read attachment"
                  . $imgInfo->{web} . " "
                  . $imgInfo->{topic} . " "
                  . $imgInfo->{file} )
              if $prefs{'debug'};    #DEBUG
            my $data =
              Foswiki::Func::readAttachment( $imgInfo->{web}, $imgInfo->{topic},
                $imgInfo->{file} );
            if ($data) {             # Don't fault for missing / empty files.
                binmode $tempfh;
                print $tempfh $data; # copy the attachment to the temporary file
                close $tempfh;
            }
            else {
                &Foswiki::Func::writeDebug( "Empty or missing image file "
                      . $imgInfo->{web} . " "
                      . $imgInfo->{topic} . " "
                      . $imgInfo->{file} );
            }
        }
        catch Foswiki::AccessControlException with {

      # ignore access errors - htmldoc will ignore empty files, but log an error
            &Foswiki::Func::writeDebug( "File Access Exception"
                  . $imgInfo->{web} . " "
                  . $imgInfo->{topic} . " "
                  . $imgInfo->{file} );
        };

        # replace all instances of url with the temporary filename
        ( my $tvol, my $tdir, my $fname ) =
          File::Spec->splitpath( $tempfh->filename );

# For htmldoc commandline parameters, images are passed as a filename, not an html tag.
        if ($notag) {
            $html =~ s{
              <[iI][mM][gG]\s+                     # starting img tag plus space
              ( (?: \w+ \s*=\s* $reAttrValue \s+ )* )   # 0 or more word = value - Assign to $1
              [sS][rR][cC]\s*=\s*                  # src = with or without spaces
              ([\"\']?)                            # assign quote to $2
              $imgurl                              # value of URL
              \2                                # Optional Closing quote
              ( (?: \s+ \w+ \s*=\s* $reAttrValue )* )   # 0 or more word = value - Assign to $3
              \s*/?>                                    # Close tag  Group 
             }{$tempfh}sgx;
        }
        else {
            $html =~ s{
              <[iI][mM][gG]\s+                     # starting img tag plus space
              ( (?: \w+ \s*=\s* $reAttrValue \s+ )* )   # 0 or more word = value - Assign to $1
              [sS][rR][cC]\s*=\s*                  # src = with or without spaces
              ([\"\']?)                            # assign quote to $2
              $imgurl                              # value of URL
              \2                                # Optional Closing quote
              ( (?: \s+ \w+ \s*=\s* $reAttrValue )* )   # 0 or more word = value - Assign to $3
              \s*/?>                                    # Close tag  Group 
             }{<img $1 src=$2$fname$2 $3 > }sgx;
        }
    }

    return $html;
}

=pod



=pod

=head2 _fixHtml($html)

Cleans up the HTML as needed before htmldoc processing. This currently includes fixing
img links as needed, removing page breaks, META stuff, and inserting an h1 header if one
isn't present. Returns the modified html.

=cut

sub _fixHtml {
    my ( $html, $topic, $webName, $refTopics, $depth ) = @_;
    _writeDebug("fixHtml called for $topic depth $depth");

    #_writeDebug("-----DUMP----\n$html\n----END DUMP----");
    my $title =
      Foswiki::Func::expandCommonVariables( $prefs{'title'}, $topic, $webName );
    $title = Foswiki::Func::renderText($title);
    $title =~ s/<.*?>//gs;

    _writeDebug("title: $title");    # DEBUG

    # Keep the body only.  A new header will be added later.
    $html =~ s%.*<body[^>]*>%%is;
    $html =~ s%</body>.*%%is;

    # Extract the content between the PDFSTART and PDFSTOP comment markers
    $html = _extractPdfSections($html);

    # remove <nop> tags
    $html =~ s/<nop>//g;

  # remove all page breaks
  # FIXME - why remove a forced page break? Instead insert a <!-- PAGE BREAK -->
  #         otherwise dangling </p> is not cleaned up
    $html =~
s/(<p(.*) style="page-break-before:always")/\n<!-- PAGE BREAK -->\n<p$1/gis;

    # remove %META stuff
    $html =~ s/%META:\w+{.*?}%//gs;

    # Prepend META tags for PDF meta info - may be redefined later by topic text
    my $meta = '';
    if ( $depth == 0 ) {    # Only add meta tags for root level topics
        $meta =
'<META NAME="AUTHOR" CONTENT="%SPACEOUT{%REVINFO{format="$wikiname"}%}%"/>'
          ;                 # Specifies the document author.
                            #
         # As of htmldoc 1.8.27, it  appends the copyright statement into the Author metadata. This can break
         # some content management systems.  Copyright metadata can be excluded by setting to '0'.
         #
        $meta .=
          '<META NAME="COPYRIGHT" CONTENT="' . $prefs{'copyright'} . '"/>'
          if $prefs{'copyright'};    # Specifies the document copyright.
        $meta .=
'<META NAME="DOCNUMBER" CONTENT="%REVINFO{format="r1.$rev - $date"}%"/>'
          ;                          # Specifies the document number.
        $meta .=
          '<META NAME="GENERATOR" CONTENT="%WIKITOOLNAME% %WIKIVERSION%"/>'
          ;    # Specifies the application that generated the HTML file.
        $meta .=
            '<META NAME="KEYWORDS" CONTENT="'
          . $prefs{'keywords'}
          . '"/>';    # Specifies document search keywords.
        $meta .=
            '<META NAME="SUBJECT" CONTENT="'
          . $prefs{'subject'}
          . '"/>';    # Specifies document subject.
        $meta = Foswiki::Func::expandCommonVariables( $meta, $topic, $webName );
        $meta =~ s/<(?!META).*?>//g;  # remove any tags from inside the <META />
        $meta = Foswiki::Func::renderText($meta);
        $meta =~ s/<(?!META).*?>//g;  # remove any tags from inside the <META />
            # FIXME - renderText converts the <META> tags to &lt;META&gt;
            # if the CONTENT contains anchor tags (trying to be XHTML compliant)
        $meta =~ s/&lt;/</g;
        $meta =~ s/&gt;/>/g;
    }

    #print STDERR "meta: '$meta'\n"; # DEBUG

    # Remove empty headings - print skin inserts for some reason.
    $html =~ s{
          <h                                      # starting header tag 
          ([\d]{1,2})                             # $1 is 1 or 2 digits
          >                                       # End the tag  
          </h\1>                                  # End tag with backref
          }{}sgxi;

# If hard coded values set for header shifting, use it, otherwise
# if shift is set to "auto", shift the headers by the recursive "depth" of the topic.
# (Depth = 0 for root level topic.)
    my $shift = 0;
    my $hn    = 1;

    if ( $prefs{'shift'} =~ /^[+-]?\d+$/ ) {
        $shift = $prefs{'shift'};
    }
    else {
        if ( $prefs{'shift'} eq "auto" ) {
            $shift = $depth;
            $hn    = $depth + 1;
        }
    }

    $html = _shiftHeaders( $html, $shift );

  # Check if any headings are present - if none, can't generate a structured PDF
    $hasHeadings = ( $html =~ /<h[2-6]>/is ) unless ($hasHeadings);

    # Insert a header if one isn't present
    # and a target (after the header) for this topic so it gets a bookmark
    if ( $html !~ /<h$hn/is ) {
        _writeDebug(" Search for <h$hn failed - inseerting <h$hn>$topic</$hn>");
        $html = "<h$hn>$topic</h$hn><a name=\"$topic\"> </a>$html";
    }

    # htmldoc reads <title> for PDF Title meta-info
    $html =
"<html><head><title>$title</title>\n$meta</head>\n<body>$html</body></html>";

    # As of HtmlDoc 1.8.24, it only handles HTML3.2 elements so
    # convert some common HTML4.x elements to similar HTML3.2 elements
    $html =~ s/&ndash;/&shy;/g;
    $html =~ s/&[lr]dquo;/"/g;    #"
    $html =~ s/&[lr]squo;/'/g;    #'
    $html =~ s/&brvbar;/|/g;

    # replace arrows
    $html =~ s/&rarr;/->/g;
    $html =~ s/&larr;/<-/g;
    $html =~ s/&harr;/<->/g;
    $html =~ s/&rArr;/=>/g;
    $html =~ s/&lArr;/<=/g;
    $html =~ s/&hArr;/<=>/g;

# convert FoswikiNewLinks to normal text
# FIXME - should this be a preference? - should use setPreferencesValue($name, $val) to set NEWTOPICLINK

    $html =~ s{
      <span\s*class="foswikiNewLink">     # Start span of a new link
      (.*?)                               # The linked word - non-greedy
      <a\s+                               # Start of the create link
      .*?                                 # The rest of the tag - non-greedy match
      >\?                                 # Close tag and question mark
      </a>                                # Closing link
      </span>                             # Closing span
      }{$1}sgx;

  # Fix the image tags to use hard-disk path rather than relative url paths for
  # images.  Needed if wiki requires authentication like SSL client certifcates.
    $html = _fixImages($html);

    # Fully qualify any unqualified URLs (to make it portable to another host)
    my $url = Foswiki::Func::getUrlHost();
    $html =~ s{
          <a\s+                                    # starting img tag plus space
          ( (?: \w+ \s*=\s* $reAttrValue \s+ )* )  # 0 or more word = value - Assign to $1
          [hH][rR][eE][fF]\s*                      # href = with or without spaces
          ( =\s*[\"\']?                            # starts quote delimitied
          )/
         }{<a $1 href$2$url/}sgx;

    # link internally if we include the topic
    for my $wikiword (@$refTopics) {
        $url = Foswiki::Func::getScriptUrl( $webName, $wikiword, 'view' );
        $html =~ s/([\'\"])$url/$1#$wikiword/g;    # not anchored
        $html =~ s/$url(#\w*)/$1/g;                # anchored
    }

    # change <li type=> to <ol type=>
    $html =~ s/<ol>\s+<li\s+type="([AaIi])">/<ol type="$1">\n<li>/g;
    $html =~ s/<li\s+type="[AaIi]">/<li>/g;

    #_writeDebug("-----RETURN DUMP----\n$html\n----END DUMP----");

    return $html;
}

=pod

=head2 _getPrefs($query)

Creates a hash with the various preference values. For each preference key, it will set the
value first to the one supplied in the URL query. If that is not present, it will use the Foswiki
preference value, and if that is not present and a value is needed, it will use a default.

See the GenPDFAddOn topic for a description of the possible preference values and defaults.

=cut

sub _getPrefs {

    # HTMLDOC location
    # $Foswiki::htmldocCmd must be set in Foswiki.cfg

    use constant BANNER       => "";
    use constant TITLE        => "";
    use constant SUBTITLE     => "";
    use constant HEADERTOPIC  => "";
    use constant TITLETOPIC   => "";
    use constant TITLEDOC     => "";
    use constant FIRSTPAGE    => 'toc';
    use constant SKIN         => "pattern";
    use constant COVER        => "print";
    use constant TEMPLATE     => "view";
    use constant RECURSIVE    => undef;
    use constant FORMAT       => "pdf14";
    use constant TOCLEVELS    => 5;
    use constant PAGESIZE     => "a4";
    use constant ORIENTATION  => "portrait";
    use constant WIDTH        => 860;
    use constant HEADERSHIFT  => 0;
    use constant KEYWORDS     => '%FORMFIELD{"KeyWords"}%';
    use constant SUBJECT      => '%FORMFIELD{"TopicHeadline"}%';
    use constant TOCHEADER    => "...";
    use constant TOCFOOTER    => "..i";
    use constant HEADER       => undef;
    use constant FOOTER       => undef;
    use constant HEADFOOTFONT => "";
    use constant HEADFOOTSIZE => undef;
    use constant BODYIMAGE    => "";
    use constant BODYFONT     => "";
    use constant TEXTFONT     => "";
    use constant HEADINGFONT  => "";
    use constant LOGOIMAGE    => "";
    use constant NUMBEREDTOC  => undef;
    use constant DUPLEX       => undef;
    use constant PERMISSIONS  => undef;
    use constant MARGINS      => undef;
    use constant BODYCOLOR    => undef;
    use constant DESTINATION  => 'view';
    use constant PAGELAYOUT   => 'single';
    use constant PAGEMODE     => 'outline';
    use constant STRUCT       => 'book';
    use constant DEBUG        => 0;
    use constant COPYRIGHT    => '%WEBCOPYRIGHT%';

    # copyright notice inserted into PDF Metadata
    $prefs{'copyright'} = $query->param('pdfcopyright');
    if ( ( !defined $prefs{'copyright'} ) || $prefs{'copyright'} eq '' ) {
        $prefs{'copyright'} =
          Foswiki::Func::getPreferencesValue("GENPDFADDON_COPYRIGHT");
        if ( !defined $prefs{'copyright'} || $prefs{'copyright'} eq '' ) {
            $prefs{'copyright'} = COPYRIGHT;
        }
    }

    # Debugging:  Logs to data/debug.txt and preserves temporary files
    $prefs{'debug'} =
         $query->param('pdfdebug')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_DEBUG")
      || DEBUG;

    # header/footer topic
    $prefs{'hftopic'} =
         $query->param('pdfheadertopic')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_HEADERTOPIC")
      || HEADERTOPIC;

    # title topic
    $prefs{'titletopic'} =
         $query->param('pdftitletopic')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_TITLETOPIC")
      || TITLETOPIC;
    $prefs{'titledoc'} =
         $query->param('pdftitledoc')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_TITLEDOC")
      || TITLEDOC;

    $prefs{'banner'} = $query->param('pdfbanner')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_BANNER");
    $prefs{'banner'} = BANNER unless defined $prefs{'banner'};

    $prefs{'title'} = $query->param('pdftitle')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_TITLE");
    $prefs{'title'} = TITLE unless defined $prefs{'title'};

    $prefs{'subtitle'} = $query->param('pdfsubtitle')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_SUBTITLE");
    $prefs{'subtitle'} = SUBTITLE unless defined $prefs{'subtitle'};

    $prefs{'keywords'} =
         $query->param('pdfkeywords')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_KEYWORDS")
      || KEYWORDS;

    $prefs{'subject'} =
         $query->param('pdfsubject')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_SUBJECT")
      || SUBJECT;

    # get skin path based on urlparams and genpdfaddon settings
    $prefs{'skin'} =
         $query->param('skin')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_SKIN")
      || SKIN;
    $prefs{'cover'} =
         $query->param('cover')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_COVER")
      || COVER;

    # get view template
    $prefs{'template'} =
         $query->param('template')
      || Foswiki::Func::getPreferencesValue('VIEW_TEMPLATE')
      || TEMPLATE;

    # get htmldoc structure mode
    $prefs{'struct'} =
         $query->param('pdfstruct')
      || Foswiki::Func::getPreferencesValue('GENPDFADDON_MODE')
      || STRUCT;
    $prefs{'struct'} = STRUCT
      unless $prefs{'struct'} =~ /^(book|webpage|continuous)$/o;

    # Get TOC header/footer. Set to default if nothing useful given
    $prefs{'tocheader'} =
         $query->param('pdftocheader')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_TOCHEADER")
      || '';
    $prefs{'tocheader'} = TOCHEADER
      unless ( $prefs{'tocheader'} =~ /^[\.\/:1aAcCdDhiIltT]{3}$/ );

    $prefs{'tocfooter'} =
         $query->param('pdftocfooter')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_TOCFOOTER")
      || '';
    $prefs{'tocfooter'} = TOCFOOTER
      unless ( $prefs{'tocfooter'} =~ /^[\.\/:1aAcCdDhiIltT]{3}$/ );

    # TOC Title
    $prefs{'toctitle'} = $query->param('pdftoctitle')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_TOCTITLE");

    # Get some other parameters and set reasonable defaults unless not supplied
    $prefs{'format'} =
         $query->param('pdfformat')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_FORMAT")
      || '';
    $prefs{'format'} = FORMAT
      unless ( $prefs{'format'} =~ /^(html(sep)?|ps([123])?|pdf(1[1234])?)$/ );

    $prefs{'size'} =
         $query->param('pdfpagesize')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_PAGESIZE")
      || '';
    $prefs{'size'} = PAGESIZE
      unless ( $prefs{'size'} =~
        /^(letter|legal|a4|universal|(\d+x\d+)(pt|mm|cm|in))$/ );
    $prefs{'firstpage'} =
         $query->param('pdffirstpage')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_FIRSTPAGE")
      || FIRSTPAGE;
    $prefs{'firstpage'} = FIRSTPAGE
      unless ( $prefs{'firstpage'} =~ /^(p1|c1|toc)$/ );
    $prefs{'pagelayout'} =
         $query->param('pdfpagelayout')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_PAGELAYOUT")
      || PAGELAYOUT;
    $prefs{'pagelayout'} = PAGELAYOUT
      unless ( $prefs{'pagelayout'} =~ /^(single|one|twoleft|tworight)$/ );
    $prefs{'pagemode'} =
         $query->param('pdfpagemode')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_PAGEMODE")
      || PAGEMODE;
    $prefs{'pagemode'} = PAGEMODE
      unless ( $prefs{'pagemode'} =~ /^(outline|document|fullscreen)$/ );
    $prefs{'orientation'} =
         $query->param('pdforientation')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_ORIENTATION")
      || '';
    $prefs{'orientation'} = ORIENTATION
      unless ( $prefs{'orientation'} =~ /^(landscape|portrait)$/ );

    $prefs{'headfootsize'} =
         $query->param('pdfheadfootsize')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_HEADFOOTSIZE")
      || '';
    $prefs{'headfootsize'} = HEADFOOTSIZE
      unless ( $prefs{'headfootsize'} =~ /^\d+$/ );

    $prefs{'header'} =
         $query->param('pdfheader')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_HEADER")
      || '';
    $prefs{'header'} = HEADER
      unless ( $prefs{'header'} =~ /^[\.\/:1aAcCdDhiIltT]{3}$/ );

    $prefs{'footer'} =
         $query->param('pdffooter')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_FOOTER")
      || '';
    $prefs{'footer'} = FOOTER
      unless ( $prefs{'footer'} =~ /^[\.\/:1aAcCdDhiIltT]{3}$/ );

    $prefs{'headfootfont'} =
         $query->param('pdfheadfootfont')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_HEADFOOTFONT")
      || '';
    $prefs{'headfootfont'} = HEADFOOTFONT
      unless ( $prefs{'headfootfont'} =~
/^(times(-roman|-bold|-italic|bolditalic)?|(courier|helvetica)(-bold|-oblique|-boldoblique)?)$/
      );

    $prefs{'width'} =
         $query->param('pdfwidth')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_WIDTH")
      || '';
    $prefs{'width'} = WIDTH unless ( $prefs{'width'} =~ /^\d+$/ );

    $prefs{'toclevels'} = $query->param('pdftoclevels');
    $prefs{'toclevels'} =
      Foswiki::Func::getPreferencesValue("GENPDFADDON_TOCLEVELS")
      unless ( defined( $prefs{'toclevels'} )
        && ( $prefs{'toclevels'} =~ /^\d+$/ ) );
    $prefs{'toclevels'} = TOCLEVELS
      unless ( defined( $prefs{'toclevels'} )
        && ( $prefs{'toclevels'} =~ /^\d+$/ ) );

    $prefs{'bodycolor'} =
         $query->param('pdfbodycolor')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_BODYCOLOR")
      || '';
    $prefs{'bodycolor'} = BODYCOLOR
      unless ( $prefs{'bodycolor'} =~ /^[0-9a-fA-F]{6}$/ );

 # Anything results in true (use 0 to turn these off or override the preference)
    $prefs{'recursive'} =
         $query->param('pdfrecursive')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_RECURSIVE")
      || RECURSIVE
      || '';

    $prefs{'bodyimage'} =
         $query->param('pdfbodyimage')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_BODYIMAGE")
      || BODYIMAGE;

    $prefs{'bodyfont'} =
         $query->param('pdfbodyfont')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_BODYFONT")
      || BODYFONT;
    $prefs{'bodyfont'} = BODYFONT
      unless ( $prefs{'bodyfont'} =~
        /^Arial|Courier|Helvetica|Monospace|Sans|Serif|Times$/i );

    $prefs{'headingfont'} =
         $query->param('pdfheadingfont')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_HEADINGFONT")
      || HEADINGFONT;
    $prefs{'headingfont'} = HEADINGFONT
      unless ( $prefs{'headingfont'} =~
        /^Arial|Courier|Helvetica|Monospace|Sans|Serif|Times$/i );

    $prefs{'textfont'} =
         $query->param('pdftextfont')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_TEXTFONT")
      || TEXTFONT;
    $prefs{'textfont'} = TEXTFONT
      unless ( $prefs{'textfont'} =~
        /^Arial|Courier|Helvetica|Monospace|Sans|Serif|Times$/i );

    $prefs{'logoimage'} =
         $query->param('pdflogoimage')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_LOGOIMAGE")
      || LOGOIMAGE;

    $prefs{'numbered'} =
         $query->param('pdfnumberedtoc')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_NUMBEREDTOC")
      || NUMBEREDTOC
      || '';
    $prefs{'destination'} =
         $query->param('pdfdestination')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_DESTINATION")
      || DESTINATION;
    $prefs{'duplex'} =
         $query->param('pdfduplex')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_DUPLEX")
      || DUPLEX
      || '';

    $prefs{'shift'} =
         $query->param('pdfheadershift')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_HEADERSHIFT")
      || HEADERSHIFT;

    $prefs{'compress'} =
         $query->param('pdfcompress')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_COMPRESS")
      || '';

    $prefs{'jpegquality'} =
         $query->param('pdfjpegquality')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_JPEGQUALITY")
      || '';

    $prefs{'permissions'} =
         $query->param('pdfpermissions')
      || Foswiki::Func::getPreferencesValue("GENPDFADDON_PERMISSIONS")
      || PERMISSIONS
      || '';
    $prefs{'permissions'} = join(
        ',',
        grep(
/^(all|annotate|copy|modify|print|no-annotate|no-copy|no-modify|no-print|none)$/,
            split( /,/, $prefs{'permissions'} ) )
    );

    my @margins = grep( /^(top|bottom|left|right):\d+(\.\d+)?(cm|mm|in|pt)?$/,
        split(
            ',',
            (
                     $query->param('pdfmargins')
                  || Foswiki::Func::getPreferencesValue("GENPDFADDON_MARGINS")
                  || MARGINS
                  || ''
            )
        ) );

    for (@margins) {
        my ( $key, $val ) = split(/:/);
        $prefs{$key} = $val;
    }

#for my $key (keys %prefs) { print STDERR "$key = " . ($prefs{$key} || "<<UNDEFINED>>"). "\n"; } #DEBUG
}

=pod

=head2 viewPDF

This is the core method to convert the current page into PDF format.

=cut

sub viewPDF {

    my $session = shift;

    $Foswiki::Plugins::SESSION = $session;

    $query = $session->{cgiQuery};
    my $webName  = $session->{webName};
    my $topic    = $session->{topicName};
    my $response = $session->{response};
    my $rev      = $query->param('rev');

    open( STDERR, ">>$Foswiki::cfg{DataDir}/error.log" )
      ;    # redirect errors to a log file

    %tree  = ();
    %prefs = ();

    my $thePathInfo   = $query->path_info();
    my $theRemoteUser = $query->remote_user();
    my $theTopic      = $query->param('topic');
    my $theUrl        = $query->url;

    # Get preferences
    _getPrefs($query);

    # Set a default skin in the query
    $query->param( 'skin',  $prefs{'skin'} );
    $query->param( 'cover', $prefs{'cover'} );

    # Check for existence
    Foswiki::Func::redirectCgiQuery( $query,
        Foswiki::Func::getOopsUrl( $webName, $topic, "oopsmissing" ) )
      unless Foswiki::Func::topicExists( $webName, $topic );
    Foswiki::Func::redirectCgiQuery(
        $query,
        Foswiki::Func::getOopsUrl(
            $webName, $prefs{'hftopic'}, "oopscreatenewtopic"
        )
    ) unless Foswiki::Func::topicExists( $webName, $prefs{'hftopic'} );
    Foswiki::Func::redirectCgiQuery(
        $query,
        Foswiki::Func::getOopsUrl(
            $webName, $prefs{'titletopic'}, "oopscreatenewtopic"
        )
    ) unless Foswiki::Func::topicExists( $webName, $prefs{'titletopic'} );

    # Get header/footer data
    my $hfData = _getHeaderFooterData($webName);

    my $htmldocCmd = $Foswiki::cfg{Extensions}{GenPDFAddOn}{htmldocCmd}
      || 'htmldoc';

    if ( defined $Foswiki::cfg{TempfileDir} ) {
        $tempdir = $Foswiki::cfg{TempfileDir};
    }
    else {
        $tempdir = File::Spec->tmpdir();
    }

    if ( $prefs{'recursive'} ) {
        if ($rev) {
            &_writeDebug(
"Recursive processing disabled - explicit topic revision specified."
            );
        }
        else {
            my $fmt;
            if ( $prefs{'shift'} eq "auto" ) {
                $fmt = '$count(<!-- TOC PROMOTE -->.*);$topic:$parent';
            }
            else {
                $fmt = '0;$topic:$parent';
            }
            my $list = Foswiki::Func::expandCommonVariables(
                '%SEARCH{ "^%META:TOPICPARENT"
                    type="regex"
                    multiple="on"
                    format="' . $fmt . '"
                    separator="|"
                    header=""
                    nonoise="on"}%'
            );
            map {
                my ( $ch, $par ) = split( /:/, $_ );
                push @{ $tree{$par} }, $ch if $par;
                &_writeDebug("Parent $par Child $ch");
            } split( /\|/, $list );
        }
    }

    my @topics;
    my @depths;
    push @topics, $topic;
    push @depths, 0;
    _depthFirst( $topic, \@topics, \@depths, 1 );

    my @contentFiles;
    for $topic (@topics) {

        my $depth = shift(@depths);
        my $dep = $depth || "x";
        _writeDebug("preparing $topic depth $dep");    # DEBUG
            # Get ready to display HTML topic
        my $htmlData = _getRenderedView( $webName, $topic, $rev );

# Fix topic text (i.e. correct any problems with the HTML that htmldoc might not like
        $htmlData = _fixHtml( $htmlData, $topic, $webName, \@topics, $depth );

        # The data returned also incluides the header. Remove it.
        $htmlData =~ s|.*(<!DOCTYPE)|$1|s;

        # Save this to a temp file for htmldoc processing
        my ( $cfh, $contentFile ) = tempfile(
            'GenPDFAddOnXXXXXXXXXX',
            DIR => $tempdir,

            #UNLINK => 0, # DEBUG
            SUFFIX => '.html'
        );
        open $cfh, ">$contentFile";
        print $cfh $hfData . $htmlData;
        close $cfh;
        push @contentFiles, $contentFile;
    }

    # Create a file holding the title data
    my $titleFile = _createTitleFile($webName);

    # Create a temp file for output
    my ( $ofh, $outputFile ) = tempfile(
        'GenPDFAddOnXXXXXXXXXX',
        DIR => $tempdir,

        #UNLINK => 0, # DEBUG
        SUFFIX => '.pdf'
    );

    # Override structured PDF if no headings present
    if ( $prefs{'struct'} eq 'book' && !$hasHeadings ) {
        $prefs{'struct'} = 'webpage';
        _writeDebug(
            "No headings present - Overriding structure from book to webpage");
    }

    # Convert contentFile to PDF using HTMLDOC
    my @htmldocArgs;
    push @htmldocArgs, "--$prefs{'struct'}", "--quiet", "--links",
      "--linkstyle", "plain", "--outfile", "$outputFile", "--format",
      "$prefs{'format'}", "--$prefs{'orientation'}", "--size", "$prefs{'size'}",
      "--path", $tempdir, "--browserwidth", "$prefs{'width'}", "--titlefile",
      "$titleFile";
    if ( $prefs{'toclevels'} eq '0' ) {
        push @htmldocArgs, "--no-toc";
        if ( $prefs{'firstpage'} eq 'toc' ) {
            push @htmldocArgs, "--firstpage", "p1";
        }
        else {
            push @htmldocArgs, "--firstpage", $prefs{'firstpage'};
        }
    }
    else {
        push @htmldocArgs, "--numbered" if $prefs{'numbered'};
        push @htmldocArgs, "--toclevels", "$prefs{'toclevels'}",
          "--tocheader", "$prefs{'tocheader'}",
          "--tocfooter", "$prefs{'tocfooter'}",
          "--firstpage", "$prefs{'firstpage'}";
        push @htmldocArgs, "--toctitle", "$prefs{'toctitle'}"
          if $prefs{'toctitle'};
    }
    push @htmldocArgs, "--duplex" if $prefs{'duplex'};
    push @htmldocArgs, "--bodyimage", "$prefs{'bodyimage'}"
      if $prefs{'bodyimage'};
    push @htmldocArgs, "--bodyfont", "$prefs{'bodyfont'}"
      if $prefs{'bodyfont'};
    push @htmldocArgs, "--headingfont", "$prefs{'headingfont'}"
      if $prefs{'headingfont'};
    push @htmldocArgs, "--textfont", "$prefs{'textfont'}"
      if $prefs{'textfont'};
    push @htmldocArgs, "--logoimage", "$prefs{'logoimage'}"
      if $prefs{'logoimage'};
    push @htmldocArgs, "--headfootfont", "$prefs{'headfootfont'}"
      if $prefs{'headfootfont'};
    push @htmldocArgs, "--headfootsize", "$prefs{'headfootsize'}"
      if $prefs{'headfootsize'};
    push @htmldocArgs, "--header", "$prefs{'header'}" if $prefs{'header'};
    push @htmldocArgs, "--footer", "$prefs{'footer'}" if $prefs{'footer'};
    push @htmldocArgs, "--permissions", "$prefs{'permissions'}"
      if $prefs{'permissions'};
    push @htmldocArgs, "--bodycolor", "$prefs{'bodycolor'}"
      if $prefs{'bodycolor'};
    push @htmldocArgs, "--top",    "$prefs{'top'}"    if $prefs{'top'};
    push @htmldocArgs, "--bottom", "$prefs{'bottom'}" if $prefs{'bottom'};
    push @htmldocArgs, "--left",   "$prefs{'left'}"   if $prefs{'left'};
    push @htmldocArgs, "--right",  "$prefs{'right'}"  if $prefs{'right'};
    push @htmldocArgs, "--pagelayout", "$prefs{'pagelayout'}"
      if $prefs{'pagelayout'};
    push @htmldocArgs, "--pagemode", "$prefs{'pagemode'}" if $prefs{'pagemode'};
    push @htmldocArgs, "--no-compression" if ( $prefs{'compress'} eq 'none' );
    push @htmldocArgs, "--compression=$prefs{'compress'}"
      if ( $prefs{'compress'} =~ /^\d$/ );
    push @htmldocArgs, "--no-jpeg" if ( $prefs{'jpegquality'} eq 'none' );
    push @htmldocArgs, "--jpeg=$prefs{'jpegquality'}"
      if ( $prefs{'jpegquality'} =~ /^\d{1,2}$/ );
    push @htmldocArgs, @contentFiles;

    # Disable CGI feature of newer versions of htmldoc
    # (thanks to Brent Roberts for this fix)
    $ENV{HTMLDOC_NOCGI} = "yes";

    my $htmldocArgs = join( ' ', @htmldocArgs );
    $htmldocArgs =
      Foswiki::Func::expandCommonVariables( $htmldocArgs, $topic, $webName );

# Command line paramters need filenames, not image tags, so strip any tags and convert to filename.
    $htmldocArgs = _fixImages( $htmldocArgs, 1 );

    _writeDebug("Calling htmldoc with args: $htmldocArgs");

    my ( $Output, $exit ) =
      Foswiki::Sandbox->sysCommand( $htmldocCmd . ' ' . $htmldocArgs );
    _writeDebug("htmldoc exited with $exit");
    if ( !-e $outputFile ) {
        die "error running htmldoc ($htmldocCmd): $Output\n";
    }
    if ( !-s $outputFile ) {
        die "htmldoc produced zero length output ($htmldocCmd): $Output\n"
          . join( ' ', @htmldocArgs ) . "\n";
    }

    #  output the HTML header and the output of HTMLDOC
    my $cd = "filename=${webName}_$topic.%s";
    $cd = "attachment; $cd" if ( $prefs{'destination'} ne 'view' );

    try
    { #?? Doesn't this try belong around the run of htmldoc?  CGI::header won't fail.
        if ( $prefs{'format'} =~ /^pdf/ ) {
            print CGI::header(
                -TYPE                => 'application/pdf',
                -Content_Disposition => sprintf $cd,
                'pdf'
            );
        }
        elsif ( $prefs{'format'} =~ /^ps/ ) {
            print CGI::header(
                -TYPE                => 'application/postscript',
                -Content_Disposition => sprintf $cd,
                'ps'
            );
        }
        else {
            print CGI::header(
                -TYPE                => 'text/html',
                -Content_Disposition => sprintf $cd,
                'html'
            );
        }
    }
    catch Error::Simple with {
        print STDERR "GenPDF caught Error::Simple";
        my $e = shift;
        use Data::Dumper;
        die Dumper($e);
    };

    open $ofh, $outputFile;
    binmode $ofh;
    while (<$ofh>) {
        print;
    }
    close $ofh;

    # Cleaning up temporary files
    unlink $outputFile, $titleFile unless $prefs{'debug'};
    unlink @contentFiles unless $prefs{'debug'};
    unlink @tempfiles    unless $prefs{'debug'};

    # SMELL:  Foswiki 1.0.x adds the headers,  1.1 does not.   However
    # deleting them doesn't appear to cause problems in 1.1.

    my $headers = $response->headers();
    $response->deleteHeader( 'X-Foswikiuri', 'X-Foswikiaction' );
}

### sub _writeDebug
##
##   Writes a common format debug message if debug is enabled

sub _writeDebug {
    &Foswiki::Func::writeDebug( "GenPDF  - " . $_[0] ) if $prefs{'debug'};
}    ### SUB _writeDebug

# Do a recursive depth first walk through the ancestors in the tree
# sub is defined here for clarity
sub _depthFirst {
    my $parent = shift;
    my $topics = shift;    # ref to @topics
    my $depths = shift;    # ref to @depths
    my $depth  = shift;

    # the grep gets around a perl dereferencing bug when using strict refs
    my @children = grep { $_; } @{ $tree{$parent} };
    for ( sort @children ) {

        my ( $cnt, $child ) = split( /;/, $_ );
        _writeDebug("new child of $parent: '$child' Depth $depth ")
          if $prefs{'debug'};    # DEBUG
        push @$topics, $child;

        my $tempdepth;

        if ($cnt) {
            $tempdepth = $depth - 1;
            _writeDebug("RESET Depth of $child to 0");
        }
        else {
            $tempdepth = $depth;
            _writeDebug("Depth of $child left at $depth");
        }
        push @$depths, $tempdepth;
        if ( defined $tree{$child} ) {

            # this child is also a parent so bring them in too
            _depthFirst( $child, $topics, $depths, $tempdepth + 1 );
        }
    }
}

1;

