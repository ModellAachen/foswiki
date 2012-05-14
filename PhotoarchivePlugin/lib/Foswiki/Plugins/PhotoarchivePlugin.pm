# PhotoarchivePlugin.pm
# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
#
# PhotoarchivePlugin is
# Copyright (C) 2004 by Markus Kolb, twiki-photoarchive@tower-net.de
#
# $Id: PhotoarchivePlugin.pm 13352 2007-04-10 21:35:55Z SteffenPoulsen $
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

# =========================

package Foswiki::Plugins::PhotoarchivePlugin;

# =========================

use POSIX;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug
  $attachment_dir
  $bin_anytopnm $bin_pnmscale $bin_pnmtopng $bin_pnmtojpeg
  $cgi_query
);

# This should always be $Rev: 13352 $ so that the release system can
# determine the checked-in status of the plugin. It is used by the
# build automation tools, so you should leave it alone.
$VERSION = '$Rev: 13352 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Nov 2009';

$pluginName = 'PhotoarchivePlugin';    # Name of this Plugin

# initialize to be safe against warnings
$web            = '';
$topic          = '';
$installWeb     = '';
$debug          = 0;
$attachment_dir = '';

my $render_script = $Foswiki::cfg{Plugins}{PhotoarchivePlugin}{Script} || '';

# =========================
sub startPhotoarchive;

# =========================
# initPlugin start
# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = Foswiki::Func::getPluginPreferencesValue("DEBUG") || 0;

    # $debug = 1;

    Foswiki::Func::writeDebug($render_script);

    # Plugin correctly initialized
    Foswiki::Func::writeDebug(
        "- Foswiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;

    return 1;
}

# =========================
# initPlugin end
# =========================

# =========================
# commonTagsHandler start
# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    Foswiki::Func::writeDebug(
        "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by handleCommonTags, after %INCLUDE:"..."%

    $_[0] =~ s/%PHOTOARCHIVEPLUGIN%/startPhotoarchive()/ge;
    $_[0] =~
      s/%BEGINPHOTOARCHIVE%(.*)%ENDPHOTOARCHIVE%/startPhotoarchive($1)/giseo;
    $_[0] =~ s/%PHOTOARCHIVEPLUGINRANDOM%/startRandom()/ge;
}

# =========================
# commonTagsHandler end
# =========================

# ==========================
# spliceIt start
# ==========================
sub spliceIt {
    my $pfile           = $_[0];
    my $page            = $_[1];
    my $images_per_page = $_[2];

    # remove elements from array which belong to next page
    if ( ( $page * $images_per_page ) <= $#{$pfile} ) {
        splice( @{$pfile}, ( $page * $images_per_page ) );

        Foswiki::Func::writeDebug( "- Foswiki::Plugins::${pluginName}::spliceIt"
              . "( $web.$topic ) spliced array from index ($page * $images_per_page) to end."
        ) if $debug;
    }

    # remove elements from array which belong to page before
    if ( $page >= 2 ) {
        splice( @{$pfile}, 0, ( ( $page - 1 ) * $images_per_page ) );

        Foswiki::Func::writeDebug( "- Foswiki::Plugins::${pluginName}::spliceIt"
              . "( $web.$topic ) spliced array from index 0 to (($page - 1) * $images_per_page)"
        ) if $debug;
    }

    return ($pfile);

}

# ==========================
# spliceIt stop
# ==========================

# ==========================
# attachedImages start
# ==========================
sub attachedImages {
    my $page            = $_[0];
    my $images_per_page = $_[1];
    my $pfile           = $_[2];
    my $pheader         = $_[3];
    my $pdescription    = $_[4];
    my @imagedata       = ();
    my $counter         = 0;
    my $oa_counter      = 1;       # overall counter
    my $topiccontent    = "";
    my $pagenext        = 0;
    my $pageback        = 0;

    unless ( Foswiki::Func::topicExists( "$web", "$topic" . "Photoarchive" ) ) {
        Foswiki::Func::writeWarning( "PhotoarchivePlugin: topic $web / " 
              . "$topic"
              . "Photoarchive does not exist" );
        return ( $pfile, $pheader, $pdescription, $pageback, $pagenext )
          ;                        # return empty array
    }

    if (
        Foswiki::Func::checkAccessPermission(
            "VIEW", Foswiki::Func::getWikiUserName(),
            "",     "$topic" . "Photoarchive",
            $web
        )
      )
    {
        $topiccontent =
          Foswiki::Func::readTopicText( $web, "$topic" . "Photoarchive",
            "", "1" );

        # commented because it is defined in start...()

        # Pattern to filter entries (allow multiline comments?)
        (@imagedata) = $topiccontent =~
m!<pa_image>\n?(.*?)\n?</pa_image>\n?<pa_header>\n?(.*?)\n?</pa_header>\n?<pa_description>\n?(.*?)\n?</pa_description>!gim;

        Foswiki::Func::writeDebug( " PA found  " . @imagedata . " images " );

        # split imagedata array in the three parts
        my $j = 0;
        for ( my $i = 0 ; $i <= $#imagedata ; $j++ ) {

            # filename security
            $imagedata[$i] =~ s/(\.\.|\/|;|~|\$|\*|\||<|>|=|\\|\n)/X/g;

            # check if image exist
            unless ( -f "$attachment_dir" . "$imagedata[$i]" ) {
                Foswiki::Func::writeDebug( "- Foswiki::Plugins::${pluginName}"
                      . "::attachedImages ( $web.$topic ) "
                      . "$attachment_dir"
                      . "$imagedata[$i]"
                      . " is no file" )
                  if $debug;
                $i = $i + 3;
                $j--;
                next;    # jump to next filename
            }
            $pfile->[$j] = $imagedata[$i];
            $i++;
            $pheader->[$j] = $imagedata[$i];
            $i++;
            $pdescription->[$j] = $imagedata[$i];
            $i++;
        }

        # correct page number to range of images for random images
        # there is a "rnd" in front of the image number
        $pagenext = $page;
        $page =~ s/[^0-9]//g;
        unless ( $page eq $pagenext ) {
            $page = int($page);

            # set from random number to one of the existing image pages
            # one image per page!
            $page =
              int( $page -
                  ( $#{$pfile} + 1 ) * int( $page / ( $#{$pfile} + 1 ) ) +
                  1 );
        }
        $pagenext = 0;

        # check if we need pageback and pagenext
        if (   ( $page > 1 )
            && ( ( ( $page - 1 ) * $images_per_page - 1 ) < $#{$pfile} ) )
        {
            $pageback = 1;
        }
        if ( ( $page * $images_per_page - 1 ) < $#{$pfile} ) {
            $pagenext = 1;
        }

        # remove unneeded parts of arrays
        $pfile        = spliceIt( $pfile,        $page, $images_per_page );
        $pheader      = spliceIt( $pheader,      $page, $images_per_page );
        $pdescription = spliceIt( $pdescription, $page, $images_per_page );

    }
    else {
        Foswiki::Func::writeDebug(
                "- Foswiki::Plugins::${pluginName}::attachedImages "
              . "( $web.$topic ) no access to topic for user $user" )
          if $debug;
        return ( $pfile, $pheader, $pdescription, $pageback, $pagenext )
          ;    # return empty array
    }

    Foswiki::Func::writeDebug(
            "- Foswiki::Plugins::${pluginName}::attachedImages "
          . "( $web.$topic ) last index of image_files: $#{$pfile} image_headers: $#{$pheader} "
          . "image_descriptions: $#{$pdescription}" )
      if $debug;

    return ( $pfile, $pheader, $pdescription, $pageback, $pagenext );

}

# ==========================
# attachedImages stop
# ==========================

# ==========================
# getDescriptedContent start
# ==========================
sub getDescriptedContent {
    my $page = $_[0];
    my $attachment_url =
        Foswiki::Func::getPubUrlPath() . "/" . "$web" . "/" 
      . "$topic"
      . "Photoarchive/";
    my $images_per_col =
         Foswiki::Func::getPreferencesValue( $pluginName . "_THUMBSCOL" )
      || Foswiki::Func::getPluginPreferencesValue("THUMBSCOL")
      || "3";
    my $images_per_row =
         Foswiki::Func::getPreferencesValue( $pluginName . "_THUMBSROW" )
      || Foswiki::Func::getPluginPreferencesValue("THUMBSROW")
      || "4";
    my $images_per_page =
         Foswiki::Func::getPreferencesValue( $pluginName . "_DESCRIPTEDIMAGES" )
      || Foswiki::Func::getPluginPreferencesValue("DESCRIPTEDIMAGES")
      || "5";
    my $images_per_tpage = $images_per_row * $images_per_col;
    my $image_width =
         Foswiki::Func::getPreferencesValue( $pluginName . "_DESCRIPTEDWIDTH" )
      || Foswiki::Func::getPluginPreferencesValue("DESCRIPTEDWIDTH")
      || "250";
    my $image_height =
         Foswiki::Func::getPreferencesValue( $pluginName . "_DESCRIPTEDHEIGHT" )
      || Foswiki::Func::getPluginPreferencesValue("DESCRIPTEDHEIGHT")
      || "";
    my $detailedspace =
         Foswiki::Func::getPreferencesValue( $pluginName . "_DESCRIPTEDSPACE" )
      || Foswiki::Func::getPluginPreferencesValue("DESCRIPTEDSPACE")
      || "5";
    my ( @image_file, @image_header, @image_description );
    my $pfile        = \@image_file;
    my $pheader      = \@image_header;
    my $pdescription = \@image_description;
    my $content =
      qq(<table border="0" align="center" cellpadding="$detailedspace">\n);
    my ( $descripted, $sourcedescripted, $sourceimage, $pnmheight, $pnmwidth );
    my ( $hcmd,       $wcmd );
    my ( $pageback,   $pagenext );
    my $pref_width    = "";
    my $pref_height   = "";
    my $himage_width  = "";
    my $himage_height = "";

    if ( $image_width ne "" && $image_width ne "0" ) {
        $pnmwidth = int($image_width);
        $wcmd = sprintf( "-width %d", $pnmwidth ) if ($pnmwidth);

        #  $himage_width = "width=\"$image_width\"";
    }
    else {
        $pnmwidth     = "";
        $himage_width = "";
    }

    if ( $image_height ne "" && $image_height ne "0" ) {
        $pnmheight = int($image_height);
        $hcmd = sprintf( "-height %d", $pnmheight ) if ($pnmheight);

        # $himage_height = "height=\"$image_height\"";
    }
    else {
        $pnmheight     = "";
        $himage_height = "";
    }

    ( $pfile, $pheader, $pdescription, $pageback, $pagenext ) =
      attachedImages( $page, $images_per_page, $pfile, $pheader,
        $pdescription );

    if ( $#{$pfile} == -1 ) {
        return "<!-- Foswiki.PhotoarchivePlugin no file found //-->";
    }

    if (
        open( FH,
            "$attachment_dir" . "_" . "$pluginName" . "_" . "descriptedprefs"
        )
      )
    {
        $pref_width  = <FH>;    # read first line which is the saved image width
        $pref_height = <FH>;    # read 2nd line which is the saved image height
        close(FH);
        chomp $pref_width;
        chomp $pref_height;
    }

    # rewrite pref file if preferences changed
    if ( $pref_width ne $image_width || $pref_height ne $image_height ) {
        if (
            open( FH,
                    "> $attachment_dir" . "_"
                  . "$pluginName" . "_"
                  . "descriptedprefs"
            )
          )
        {
            print FH "$image_width\n$image_height\n";
            close(FH);
            Foswiki::Func::writeDebug(
                    "- Foswiki::Plugins::${pluginName}::getDescriptedContent"
                  . "( $web.$topic ) wrote new descriptedprefs" )
              if $debug;
        }
    }

    for ( my $i = 0 ; $i <= $#image_file ; $i++ ) {
        my $virt_page =
          ceil( ( $page * $images_per_page - $images_per_page + $i + 1 ) /
              $images_per_tpage );
        $descripted = $sourceimage = $pfile->[$i];
        $descripted =~ s/\.[^\.]*$//;
        $sourcedescripted =
            "$attachment_dir" . "_"
          . "$pluginName" . "_"
          . "$descripted"
          . "_descripted.jpg";
        $descripted =
            "$attachment_url" . "_"
          . "$pluginName" . "_"
          . "$descripted"
          . "_descripted.jpg";
        $sourceimage = "$attachment_dir" . "$sourceimage";

        # check if we need image resizing
        if (   ( !-f "$sourcedescripted" )
            || ( -M "$sourcedescripted" > -M "$sourceimage" )
            || ( $pref_width ne $image_width )
            || ( $pref_height ne $image_height ) )
        {
            Foswiki::Func::writeDebug(
                    "- Foswiki::Plugins::${pluginName}::getDescriptedContent"
                  . "( $web.$topic ) generate image $sourcedescripted" )
              if $debug;

            my $scalestr = " -xysize $pnmwidth $pnmwidth "
              if ( $pnmwidth > 0 );
            $scalestr |= '';

            # create descripted images
            Foswiki::Sandbox->sysCommand(
                "$render_script " . '%SRC|F% %OUT|F% %LOG|F% %PAD|N% %SCL|U% ',
                SRC => $sourceimage,
                LOG => '/tmp/PA_log',
                SCL => $scalestr,
                PAD => 0,
                OUT => $sourcedescripted
            );
        }

        my $img_td;
        if ( $Foswiki::cfg{Plugins}{LightboxPlugin}{Enabled} == 1 ) {
            $img_td =
                '<td align="center">' . "\n"
              . '%LIGHTBOX{'
              . 'image="%ATTACHURLPATH%Photoarchive/'
              . $pfile->[$i] . '" '
              . 'fullcaption="'
              . $pdescription->[$i]
              . '<br>" '
              . 'thumbnail="'
              . $descripted . '"'
              . 'caption="'
              . $pheader->[$i] . '" ' . '}% ' . '<br>'
              . qq{<a href="?PhotoarchivePlugin_file=$pfile->[$i]&PhotoarchivePlugin_page=$virt_page&PhotoarchivePlugin_view=detailed" class="wikiLink">full detail</a>}
              . "</td>\n";
        }
        else {
            $img_td =
qq{<a href="?PhotoarchivePlugin_file=$pfile->[$i]&PhotoarchivePlugin_page=$virt_page&PhotoarchivePlugin_view=detailed" class="wikiLink"><img src="$descripted" alt="image: $pheader->[$i]" title="$pheader->[$i]" $himage_width $himage_height border="0"></a>};
        }

        # image on the right
        if ( ( $i % 2 ) == 0 ) {
            $content .=
qq{<tr>\n<td align="left">$pheader->[$i]</td>\n<td align="center">$img_td</td>\n</tr>\n};
        }

        # image on the left
        else {
            $content .=
qq{<tr>\n<td align="center">$img_td</td>\n<td align="left">$pheader->[$i]</td>\n</tr>\n};
        }

    }

    $content .= "</table>\n";

    #page browsing
    $content .= qq(<br /><div align="center">);
    if ( $pageback == 1 ) {
        $pageback = $page - 1;
        $content .=
qq(<a href="?PhotoarchivePlugin_page=$pageback&PhotoarchivePlugin_view=descripted" class="wikiLink">&lt;- back</a>);
    }
    else {
        $content .= qq(&lt;- back);
    }
    $content .= qq( -- page $page -- );
    if ( $pagenext == 1 ) {
        $pagenext = $page + 1;
        $content .=
qq(<a href="?PhotoarchivePlugin_page=$pagenext&PhotoarchivePlugin_view=descripted" class="twikiLink">next -&gt;</a>);
    }
    else {
        $content .= qq(next -&gt;);
    }
    $content .= qq(</div>);

    my $virt_page =
      ceil( ( $page * $images_per_page - $images_per_page + 1 ) /
          $images_per_tpage );
    $content =
qq(<br />\n<div align="center"><a href="?PhotoarchivePlugin_page=$virt_page&PhotoarchivePlugin_view=thumbs" class="wikiLink">thumbnails</a> &nbsp;&nbsp;&nbsp; descriptions &nbsp;&nbsp;&nbsp; <a href="?PhotoarchivePlugin_file=$pfile->[0]&PhotoarchivePlugin_page=$virt_page&PhotoarchivePlugin_view=detailed" class="wikiLink">details</a></div>\n<br />\n)
      . $content;

    return $content;

}

# ==========================
# getDescriptedContent stop
# ==========================

# ==========================
# getDetailedContent start
# ==========================
sub getDetailedContent {
    my $page = $_[0];
    my $attachment_url =
        Foswiki::Func::getPubUrlPath() . "/" . "$web" . "/" 
      . "$topic"
      . "Photoarchive/";
    my $images_per_col =
         Foswiki::Func::getPreferencesValue( $pluginName . "_THUMBSCOL" )
      || Foswiki::Func::getPluginPreferencesValue("THUMBSCOL")
      || "3";
    my $images_per_row =
         Foswiki::Func::getPreferencesValue( $pluginName . "_THUMBSROW" )
      || Foswiki::Func::getPluginPreferencesValue("THUMBSROW")
      || "4";
    my $images_per_page = ( $images_per_col * $images_per_row );
    my $images_per_dpage =
         Foswiki::Func::getPreferencesValue( $pluginName . "_DESCRIPTEDIMAGES" )
      || Foswiki::Func::getPluginPreferencesValue("DESCRIPTEDIMAGES")
      || "5";
    my $image_width =
         Foswiki::Func::getPreferencesValue( $pluginName . "_DETAILEDWIDTH" )
      || Foswiki::Func::getPluginPreferencesValue("DETAILEDWIDTH")
      || "600";
    my $image_height =
         Foswiki::Func::getPreferencesValue( $pluginName . "_DETAILEDHEIGHT" )
      || Foswiki::Func::getPluginPreferencesValue("DETAILEDHEIGHT")
      || "";
    my $detailedspace =
         Foswiki::Func::getPreferencesValue( $pluginName . "_DETAILEDSPACE" )
      || Foswiki::Func::getPluginPreferencesValue("DETAILEDSPACE")
      || "5";
    my ( @image_file, @image_header, @image_description );
    my $pfile        = \@image_file;
    my $pheader      = \@image_header;
    my $pdescription = \@image_description;
    my $content      = qq();
    my (
        $array_counter, $detailed,  $sourcedetailed,
        $sourceimage,   $pnmheight, $pnmwidth
    );
    my ( $pageback, $pagenext );
    my ( $hcmd,     $wcmd );
    my $pref_width    = "";
    my $pref_height   = "";
    my $cgifile       = $cgi_query->param('PhotoarchivePlugin_file') || "";
    my $nextfile      = $cgi_query->param('PhotoarchivePlugin_nextfile') || "";
    my $himage_width  = "";
    my $himage_height = "";

    if ( $image_width ne "" && $image_width ne "0" ) {
        $pnmwidth = int($image_width);
        $wcmd = sprintf( "-width %d", $pnmwidth ) if ($pnmwidth);

        # $himage_width = "width=\"$image_width\"";
    }
    else {
        $pnmwidth     = "";
        $himage_width = "";
    }

    if ( $image_height ne "" && $image_height ne "0" ) {
        $pnmheight = int($image_height);
        $hcmd = sprintf( "-height %d", $pnmheight ) if ($pnmheight);

        # $himage_height = "height=\"$image_height\"";
    }
    else {
        $pnmheight     = "";
        $himage_height = "";
    }

    ( $pfile, $pheader, $pdescription, $pageback, $pagenext ) =
      attachedImages( $page, $images_per_page, $pfile, $pheader,
        $pdescription );

    if ( $#{$pfile} == -1 ) {
        return "<!-- Foswiki.PhotoarchivePlugin no file found //-->";
    }

    $array_counter = 0;

    # look for index of cgifilename
    if ( $cgifile ne "" && $nextfile eq "" ) {
        for ( my $i = 0 ; $i <= $#image_file ; $i++ ) {
            if ( $pfile->[$i] eq $cgifile ) {
                $array_counter = $i;
                last;
            }
        }
    }    # set array_counter to the next image index
    elsif ( $nextfile eq "first" ) {
        $array_counter = 0;
    }
    elsif ( $nextfile eq "last" ) {
        $array_counter = $#image_file;
    }

    $detailed = $sourceimage = $pfile->[$array_counter];
    $detailed =~ s/\.[^\.]*$//;    # cut extension
    $sourcedetailed =
        "$attachment_dir" . "_"
      . "$pluginName" . "_"
      . "$detailed"
      . "_detailed.jpg";
    $detailed =
        "$attachment_url" . "_"
      . "$pluginName" . "_"
      . "$detailed"
      . "_detailed.jpg";
    $sourceimage = "$attachment_dir" . "$sourceimage";

    if (
        open( FH,
            "$attachment_dir" . "_" . "$pluginName" . "_" . "detailedprefs"
        )
      )
    {
        $pref_width  = <FH>;    # read first line which is the saved image width
        $pref_height = <FH>;    # read 2nd line which is the saved image height
        close(FH);
        chomp $pref_width;
        chomp $pref_height;
    }

    # rewrite pref file if preferences changed
    if ( $pref_width ne $image_width || $pref_height ne $image_height ) {
        if (
            open( FH,
                    "> $attachment_dir" . "_"
                  . "$pluginName" . "_"
                  . "detailedprefs"
            )
          )
        {
            print FH "$image_width\n$image_height\n";
            close(FH);
            Foswiki::Func::writeDebug(
                    "- Foswiki::Plugins::${pluginName}::getDetailedContent"
                  . "( $web.$topic ) wrote new detailedprefs" )
              if $debug;
        }
    }

    # check if we need image resizing
    if (   ( !-f "$sourcedetailed" )
        || ( -M "$sourcedetailed" > -M "$sourceimage" )
        || ( $pref_width ne $image_width )
        || ( $pref_height ne $image_height ) )
    {
        Foswiki::Func::writeDebug(
                "- Foswiki::Plugins::${pluginName}::getDetailedContent"
              . "( $web.$topic ) generate image $sourcedetailed" )
          if $debug;

        my $scalestr = " -xysize $pnmwidth $pnmwidth "
          if ( $pnmwidth > 0 );
        $scalestr |= '';

        # create detailed image
        Foswiki::Sandbox->sysCommand(
            "$render_script " . '%SRC|F% %OUT|F% %LOG|F% %PAD|N% %SCL|U% ',
            SRC => $sourceimage,
            LOG => '/tmp/PA_log',
            SCL => $scalestr,
            PAD => 0,
            OUT => $sourcedetailed
        );
    }

    $content .=
qq(<br />\n<table border="0" align="center" width="70%" cellpadding="$detailedspace">\n<tr>\n
                <td align="center"><h2>$pheader->[$array_counter]</h2></td></tr>\n<tr><td align="center"><a href="$attachment_url$pfile->[$array_counter]" target="Photoarchive" class="wikiLink">\n
                <img src="$detailed" border="0" alt="image: $pheader->[$array_counter]" title="$pheader->[$array_counter]"></a></td></tr>\n<tr><td>$pdescription->[$array_counter]</td></tr>\n</table>\n);

    $content .= qq(<br /><div align="center">);

    if ( $array_counter != 0 ) {
        $array_counter--;
        $content .=
qq(<a href="?PhotoarchivePlugin_file=$pfile->[$array_counter]&PhotoarchivePlugin_page=$page&PhotoarchivePlugin_view=detailed" class="wikiLink">&lt;- back</a> --- );
        $array_counter++;
    }
    elsif ( $page >= 2 ) {
        $pageback = $page - 1;
        $content .=
qq(<a href="?PhotoarchivePlugin_nextfile=last&PhotoarchivePlugin_page=$pageback&PhotoarchivePlugin_view=detailed" class="wikiLink">&lt;- back</a> --- );
    }
    else {
        $content .= qq(&lt;- back --- );
    }

    if ( $array_counter != $#image_file ) {
        $array_counter++;
        $content .=
qq(<a href="?PhotoarchivePlugin_file=$pfile->[$array_counter]&PhotoarchivePlugin_page=$page&PhotoarchivePlugin_view=detailed" class="wikiLink">next -&gt;</a>);
        $array_counter--;
    }
    elsif ( $pagenext == 1 ) {
        $pagenext = $page + 1;
        $content .=
qq(<a href="?PhotoarchivePlugin_nextfile=first&PhotoarchivePlugin_page=$pagenext&PhotoarchivePlugin_view=detailed" class="wikiLink">next -&gt;</a>);
    }
    else {
        $content .= qq(next -&gt;);
    }

    $content .= qq(</div>);

    my $virt_page = ceil(
        (
            $page * $images_per_page - ( $images_per_page - $array_counter - 1 )
        ) / $images_per_dpage
    );

    $content =
qq(<br />\n<div align="center"><a href="?PhotoarchivePlugin_page=$page&PhotoarchivePlugin_view=thumbs" class="wikiLink">thumbnails</a> &nbsp;&nbsp;&nbsp; <a href="?PhotoarchivePlugin_page=$virt_page&PhotoarchivePlugin_view=descripted" class="wikiLink">descriptions</a> &nbsp;&nbsp;&nbsp; details</div>\n<br />\n)
      . $content;

    return $content;

}

# ==========================
# getDetailedContent stop
# ==========================

# ==========================
# getThumbsContent start
# ==========================
sub getThumbsContent {
    my $page = $_[0];
    my $attachment_url =
        Foswiki::Func::getPubUrlPath() . "/" . "$web" . "/" 
      . "$topic"
      . "Photoarchive/";
    my $images_per_col =
         Foswiki::Func::getPreferencesValue( $pluginName . "_THUMBSCOL" )
      || Foswiki::Func::getPluginPreferencesValue("THUMBSCOL")
      || "3";
    my $images_per_row =
         Foswiki::Func::getPreferencesValue( $pluginName . "_THUMBSROW" )
      || Foswiki::Func::getPluginPreferencesValue("THUMBSROW")
      || "4";
    my $images_per_page = ( $images_per_col * $images_per_row );
    my $images_per_dpage =
         Foswiki::Func::getPreferencesValue( $pluginName . "_DESCRIPTEDIMAGES" )
      || Foswiki::Func::getPluginPreferencesValue("DESCRIPTEDIMAGES")
      || "5";
    my $image_width =
         Foswiki::Func::getPreferencesValue( $pluginName . "_THUMBSWIDTH" )
      || Foswiki::Func::getPluginPreferencesValue("THUMBSWIDTH")
      || "";
    my $image_height =
         Foswiki::Func::getPreferencesValue( $pluginName . "_THUMBSHEIGHT" )
      || Foswiki::Func::getPluginPreferencesValue("THUMBSHEIGHT")
      || "120";
    my $thumbsspace =
         Foswiki::Func::getPreferencesValue( $pluginName . "_THUMBSSPACE" )
      || Foswiki::Func::getPluginPreferencesValue("THUMBSSPACE")
      || "5";
    my ( @image_file, @image_header, @image_description );
    my $pfile        = \@image_file;
    my $pheader      = \@image_header;
    my $pdescription = \@image_description;
    my $content =
      qq(<table border="0" align="center" cellpadding="$thumbsspace"><tr>\n);
    my (
        $row_counter, $thumb,     $sourcethumb,
        $sourceimage, $pnmheight, $pnmwidth
    );
    my ( $pageback, $pagenext );
    my ( $hcmd,     $wcmd );
    my $pref_width    = "";
    my $pref_height   = "";
    my $himage_width  = "";
    my $himage_height = "";

    if ( $image_width ne "" && $image_width ne "0" ) {
        $pnmwidth     = int($image_width);
        $wcmd         = "-width %W|N% ";
        $himage_width = "width=\"$image_width\"";
    }
    else {
        $pnmwidth     = "";
        $himage_width = "";
    }

    if ( $image_height ne "" && $image_height ne "0" ) {
        $pnmheight     = int($image_height);
        $hcmd          = "-height %H|N% ";
        $himage_height = "height=\"$image_height\"";
    }
    else {
        $pnmheight     = "";
        $himage_height = "";
    }

    ( $pfile, $pheader, $pdescription, $pageback, $pagenext ) =
      attachedImages( $page, $images_per_page, $pfile, $pheader,
        $pdescription );

    if ( $#{$pfile} == -1 ) {
        return "<!-- Foswiki.PhotoarchivePlugin no file found //-->";
    }

    if (
        open( FH, "$attachment_dir" . "_" . "$pluginName" . "_" . "thumbsprefs"
        )
      )
    {
        $pref_width  = <FH>;    # read first line which is the saved image width
        $pref_height = <FH>;    # read 2nd line which is the saved image height
        close(FH);
        chomp $pref_width;
        chomp $pref_height;
    }

    # rewrite pref file if preferences changed
    if ( $pref_width ne $image_width || $pref_height ne $image_height ) {
        if (
            open( FH,
                "> $attachment_dir" . "_" . "$pluginName" . "_" . "thumbsprefs"
            )
          )
        {
            print FH "$image_width\n$image_height\n";
            close(FH);
            Foswiki::Func::writeDebug(
                    "- Foswiki::Plugins::${pluginName}::getThumbsContent"
                  . "( $web.$topic ) wrote new thumbsprefs" )
              if $debug;
        }
    }

    $row_counter = 0;

    for ( my $i = 0 ; $i <= $#image_file ; $i++ ) {
        $thumb = $sourceimage = $pfile->[$i];
        $thumb =~ s/\.[^\.]*$//;
        $sourcethumb =
            "$attachment_dir" . "_"
          . "$pluginName" . "_"
          . "$thumb"
          . "_thumb.jpg";
        $thumb =
            "$attachment_url" . "_"
          . "$pluginName" . "_"
          . "$thumb"
          . "_thumb.jpg";
        $sourceimage = "$attachment_dir" . "$sourceimage";

        # check if we need image resizing
        if (   ( !-f "$sourcethumb" )
            || ( -M "$sourcethumb" > -M "$sourceimage" )
            || ( $pref_width ne $image_width )
            || ( $pref_height ne $image_height ) )
        {
            Foswiki::Func::writeDebug(
                    "- Foswiki::Plugins::${pluginName}::getThumbsContent"
                  . "( $web.$topic ) generate thumbnail $sourcethumb" )
              if $debug;

            # create thumbnails
            my $scalestr = " -xysize 160 160 ";
            $pnmwidth = 160;

            # $scalestr .= sprintf(" -width %d ",$pnmwidth)
            #     if ($wcmd);
            # $scalestr .= sprintf(" -width %d ",$pnmheight)
            #     if ($hcmd);

            Foswiki::Sandbox->sysCommand(
                "$render_script %SRC|F% %OUT|F% %LOG|F% %PAD|N% %SCL|U% ",
                SRC => $sourceimage,
                OUT => $sourcethumb,
                LOG => '/tmp/PA_log',
                PAD => $pnmwidth,
                SCL => $scalestr,
            );

        }

        if ( $row_counter == $images_per_row ) {
            $content .= "</tr><tr>\n";
            $row_counter = 0;
        }

        $row_counter++;

        my $tag;
        if ( $Foswiki::cfg{Plugins}{LightboxPlugin}{Enabled} == 1 ) {
            $tag =
                '<td align="center">' . "\n"
              . '%LIGHTBOX{'
              . 'image="%ATTACHURLPATH%Photoarchive/'
              . $pfile->[$i] . '" '
              . 'fullcaption="'
              . $pdescription->[$i]
              . '<br>" '
              . 'thumbnail="'
              . $thumb . '"'
              . 'caption="'
              . $pheader->[$i] . '" ' . '}% ' . '<br>'
              . qq{<a href="?PhotoarchivePlugin_file=$pfile->[$i]&PhotoarchivePlugin_page=$virt_page&PhotoarchivePlugin_view=detailed" class="wikiLink">full detail</a>}
              . "</td>\n";
        }
        else {
            $tag =
qq{<td align="center"><a href="?PhotoarchivePlugin_file=$pfile->[$i]&PhotoarchivePlugin_page=$page&PhotoarchivePlugin_view=detailed" class="wikiLink"><img src="$thumb" alt="image: $pheader->[$i]" title="$pheader->[$i]" $himage_width $himage_height border="0"></a></td>\n};
        }

        $content .= $tag;
    }

    $content .= "</tr></table>\n";

    #page browsing
    $content .= qq(<br /><div align="center">);
    if ( $pageback == 1 ) {
        $pageback = $page - 1;
        $content .=
qq(<a href="?PhotoarchivePlugin_page=$pageback&PhotoarchivePlugin_view=thumbs" class="wikiLink">&lt;- back</a>);
    }
    else {
        $content .= qq(&lt;- back);
    }
    $content .= qq( -- page $page -- );
    if ( $pagenext == 1 ) {
        $pagenext = $page + 1;
        $content .=
qq(<a href="?PhotoarchivePlugin_page=$pagenext&PhotoarchivePlugin_view=thumbs" class="wikiLink">next -&gt;</a>);
    }
    else {
        $content .= qq(next -&gt;);
    }
    $content .= qq(</div>);

    my $virt_page =
      ceil( ( ( $page - 1 ) * $images_per_page + 1 ) / $images_per_dpage );

    $content =
qq(<br />\n<div align="center">thumbnails &nbsp;&nbsp;&nbsp; <a href="?PhotoarchivePlugin_page=$virt_page&PhotoarchivePlugin_view=descripted" class="wikiLink">descriptions</a> &nbsp;&nbsp;&nbsp; <a href="?PhotoarchivePlugin_page=$page&PhotoarchivePlugin_view=detailed" class="wikiLink">details</a></div>\n<br />\n)
      . $content;

    return $content;

}

# ==========================
# getThumbsContent stop
# ==========================

# =========================
# startPhotoarchive start
# =========================
sub startPhotoarchive {
    my $desc = $_[0] || '';
    my $content;
    my $page = 1;
    my $view = "thumbs";
    my %dispatcher;

    $cgi_query = Foswiki::Func::getCgiQuery();

    Foswiki::Func::writeDebug(
            "- Foswiki::Plugins::${pluginName}::startPhotoarchive"
          . "( $web.$topic ) cgi_query = $cgi_query" )
      if $debug;

    # retrieve cgi query
    if ($cgi_query) {
        $page = $cgi_query->param('PhotoarchivePlugin_page') || 1;
        $view =
             $cgi_query->param('PhotoarchivePlugin_view')
          || Foswiki::Func::getPluginPreferencesValue("DEFAULTVIEW")
          || "thumbs";

        Foswiki::Func::writeDebug(
                "- Foswiki::Plugins::${pluginName}::startPhotoarchive"
              . "( $web.$topic ) page = $page, view = $view via CGI" )
          if $debug;
    }
    else {
        Foswiki::Func::writeWarning("PhotoarchivePlugin: no query information");
        exit 0;
    }

    $page = int($page);

    # set page to a right minimum
    unless ( $page >= 1 ) {
        $page = 1;
    }

    # set view to an existing value
    unless ( $view eq "descripted" || $view eq "detailed" || $view eq "thumbs" )
    {
        $view = "thumbs";
    }

    # attachment_dir is used in attachedImages() and get...Content()
    $attachment_dir =
        Foswiki::Func::getPubDir() . "/" . "$web" . "/" 
      . "$topic"
      . "Photoarchive/";

    Foswiki::Func::writeDebug(
            "- Foswiki::Plugins::${pluginName}::startPhotoarchive"
          . "( $web.$topic ) page = $page, view = $view after correction" )
      if $debug;

    %dispatcher = (
        descripted => \&getDescriptedContent,
        detailed   => \&getDetailedContent,
        thumbs     => \&getThumbsContent
    );

    $content = &{ $dispatcher{$view} }($page);

    return $content;

}

# =========================
# startPhotoarchive end
# =========================

# =========================
# startRandom start
# =========================
sub startRandom {

    my $content = "";
    my $page;    # for random numbers
                 # random images can be attached to any web and topic
                 # you have to set the preferences only
    my $rndtopic =
         Foswiki::Func::getPreferencesValue( $pluginName . "_RANDOMTOPIC" )
      || Foswiki::Func::getPluginPreferencesValue("RANDOMTOPIC")
      || $topic;
    my $rndweb =
         Foswiki::Func::getPreferencesValue( $pluginName . "_RANDOMWEB" )
      || Foswiki::Func::getPluginPreferencesValue("RANDOMWEB")
      || $web;
    my $attachment_url =
      Foswiki::Func::getPubUrlPath() . "/" . $rndweb . "/" . $rndtopic . "/";
    my $rnd_dir = Foswiki::Func::getPubDir() . "/" . $web . "/" . $topic . "/";
    my $rnd_url =
      Foswiki::Func::getPubUrlPath() . "/" . $web . "/" . $topic . "/";
    my $images_per_page = 1;
    my $image_width =
         Foswiki::Func::getPreferencesValue( $pluginName . "_RANDOMWIDTH" )
      || Foswiki::Func::getPluginPreferencesValue("RANDOMWIDTH")
      || "";
    my $image_height =
         Foswiki::Func::getPreferencesValue( $pluginName . "_RANDOMHEIGHT" )
      || Foswiki::Func::getPluginPreferencesValue("RANDOMHEIGHT")
      || "120";
    my ( @image_file, @image_header, @image_description );
    my $pfile        = \@image_file;
    my $pheader      = \@image_header;
    my $pdescription = \@image_description;
    my ( $image, $sourceimage, $destimage, $pnmheight, $pnmwidth );
    my ( $pageback, $pagenext );
    my ( $hcmd,     $wcmd );
    my $pref_width    = "";
    my $pref_height   = "";
    my $saveweb       = $web;
    my $savetopic     = $topic;
    my $himage_width  = "";
    my $himage_height = "";

    unless (
        Foswiki::Func::checkAccessPermission(
            "VIEW", Foswiki::Func::getWikiUserName(),
            "", $rndtopic, $rndweb
        )
      )
    {
        Foswiki::Func::writeDebug(
                "- Foswiki::Plugins::${pluginName}::startRandom "
              . "( $rndweb.$rndtopic ) no access to topic for user $user" )
          if $debug;
        return "<!-- no access to $rndweb / $rndtopic //-->";
    }

    # attachment_dir is used in attachedImages()
    $attachment_dir =
        Foswiki::Func::getPubDir() . "/" 
      . $rndweb . "/"
      . $rndtopic
      . "Photoarchive/";

    unless ( -d $attachment_dir ) {
        Foswiki::Func::writeDebug(
                "- Foswiki::Plugins::${pluginName}::startRandom "
              . "( $rndweb.$rndtopic ) no such directory $attachment_dir" )
          if $debug;
        return "<!-- could not get attached images //-->";
    }

    # check and create attachment directory for random topic
    unless ( -d $rnd_dir ) {
        unless ( mkdir( $rnd_dir, 0755 ) ) {
            Foswiki::Func::writeDebug(
                    "- Foswiki::Plugins::${pluginName}::startRandom "
                  . "( $rndweb.$rndtopic ) error on mkdir $rnd_dir" )
              if $debug;
            return "<!-- could not create directory //-->";
        }
    }

    if ( $image_width ne "" && $image_width ne "0" ) {
        $pnmwidth     = int($image_width);
        $wcmd         = sprintf( "-width %d ", $pnmwidth ) if ($pnmwidth);
        $himage_width = "width=\"$image_width\"";
    }
    else {
        $wcmd         = "";
        $himage_width = "";
    }

    if ( $image_height ne "" && $image_height ne "0" ) {
        $pnmheight     = int($image_height);
        $hcmd          = sprintf( "-height %d", $pnmheight ) if ($pnmheight);
        $himage_height = "height=\"$image_height\"";
    }
    else {
        $hcmd          = "";
        $himage_height = "";
    }

  # generate random number between 1 inclusive and 10000 inclusive
  # If you really want to manage image archives with _more_ than 10000 images
  # with this script I think you should extend this script for database use!
  # The function attachedImages() parses a tagged textfile and reads in all
  # image filenames, headers and descriptions into an array.
  # So if there are more images more memory is needed for a short time to manage
  # all the images.
    $page = int( rand(10000) + 1 );
    $page = "rnd$page";

    # set web and topic for attachedImages() to Photoarchive
    $web   = $rndweb;
    $topic = $rndtopic;

    # get a random image
    ( $pfile, $pheader, $pdescription, $pageback, $pagenext ) =
      attachedImages( $page, $images_per_page, $pfile, $pheader,
        $pdescription );

    # reset web and topic
    $web   = $saveweb;
    $topic = $savetopic;

    if ( $#{$pfile} == -1 ) {
        Foswiki::Func::writeDebug(
                "- Foswiki::Plugins::${pluginName}::startRandom "
              . "( $rndweb.$rndtopic ) rnd = '$page' image = sourceimage = '$pfile->[0]'"
              . " number '$#{$pfile}'" )
          if $debug;
        return "<!-- could not get an attached image //-->";
    }

    $image = $sourceimage = $pfile->[0];
    $image =~ s/\.[^\.]*$//;    # cut extension
    $destimage = "$rnd_dir" . "_" . "$pluginName" . "_" . "$image" . "_rnd.jpg";
    $image     = "$rnd_url" . "_" . "$pluginName" . "_" . "$image" . "_rnd.jpg";
    $sourceimage = "$attachment_dir" . "$sourceimage";

    if ( open( FH, "$rnd_dir" . "_" . "$pluginName" . "_" . "rndprefs" ) ) {
        $pref_width  = <FH>;    # read first line which is the saved image width
        $pref_height = <FH>;    # read 2nd line which is the saved image height
        close(FH);
        chomp $pref_width;
        chomp $pref_height;
    }

    # rewrite pref file if preferences changed
    if ( $pref_width ne $image_width || $pref_height ne $image_height ) {
        if ( open( FH, "> $rnd_dir" . "_" . "$pluginName" . "_" . "rndprefs" ) )
        {
            print FH "$image_width\n$image_height\n";
            close(FH);
            Foswiki::Func::writeDebug(
                    "- Foswiki::Plugins::${pluginName}::startRandom"
                  . "( $web.$topic ) wrote new rndprefs in $rnd_dir" )
              if $debug;
        }
    }

    # check if we need image resizing
    if (   ( !-f "$destimage" )
        || ( -M "$destimage" > -M "$sourceimage" )
        || ( $pref_width ne $image_width )
        || ( $pref_height ne $image_height ) )
    {
        Foswiki::Func::writeDebug(
                "- Foswiki::Plugins::${pluginName}::startRandom"
              . "( $web.$topic ) generate image $destimage" )
          if $debug;

        my $scalestr = " -xysize $pnmwidth $pnmwidth "
          if ( $pnmwidth > 0 );
        $scalestr |= '';

        # create random image
        Foswiki::Sandbox->sysCommand(
            "$render_script " . '%SRC|F% %OUT|F% %LOG|F% %PAD|N% %SCL|U% ',
            SRC => $sourceimage,
            LOG => '/tmp/PA_log',
            SCL => $scalestr,
            PAD => 0,
            OUT => $destimage
        );

    }

    $content .=
qq(<img src="$image" alt="image: $pheader->[0]" title="$pheader->[0]" $himage_width $himage_height border="0">);

    return $content;

}

# =========================
# startRandom end
# =========================

# return 1 (true)
1;
