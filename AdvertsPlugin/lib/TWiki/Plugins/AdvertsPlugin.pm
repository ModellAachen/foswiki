# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004 Martin Cleaver, Martin.Cleaver@BCS.org.uk
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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
# This is the Adverts TWiki plugin.
# It interfaces to phpAdsNew (http://p

# =========================
package TWiki::Plugins::AdvertsPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $phpAdsNewBase $selectionStringPrefix $selectionStringSuffix;
);

$VERSION    = '$Rev$';
$RELEASE    = 'Dakar';
$pluginName = 'AdvertsPlugin';    # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.001 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    # $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG");

 # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $phpAdsNewBase =
      TWiki::Func::getPreferencesValue("ADVERTSPLUGIN_ADVERTSCRIPTBASE");

    $selectionStringPrefix =
      TWiki::Func::getPreferencesValue("ADVERTSPLUGIN_ADVERTSPREFIX") || "";
    $selectionStringSuffix =
      TWiki::Func::getPreferencesValue("ADVERTSPLUGIN_ADVERTSSUFFIX") || "";

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    $_[0] =~ s/%ADVERT%/&handleAdvertRIJS()/ge;
    $_[0] =~ s/%ADVERT{(.*)}%/&handleAdvertRIJS($1)/ge;

    $_[0] =~ s/%ADVERTRIJS%/&handleAdvertRIJS()/ge;
    $_[0] =~ s/%ADVERTRIJS{(.*)}%/&handleAdvertRIJS($1)/ge;

    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;
}

# =========================

=pod

---+++ getTemplateAdvertRemoteInvocationJavaScript

This produces the code for phpAdsNew "Remote Invocation JavaScript" method

<script language='JavaScript' type='text/javascript'>
<!--
   if (!document.phpAds_used) document.phpAds_used = ',';
   phpAds_random = new String (Math.random()); phpAds_random = phpAds_random.substring(2,11);
   
   document.write ("<" + "script language='JavaScript' type='text/javascript' src='");
   document.write ("http://testwiki.mrjc.com/phpAdsNew-2.0/adjs.php?n=" + phpAds_random);
   document.write ("&amp;what=Foobar&amp;clientid=2");
   document.write ("&amp;exclude=" + document.phpAds_used);
   if (document.referer)
      document.write ("&amp;referer=" + escape(document.referer));
   document.write ("'><" + "/script>");
//-->
</script><noscript><a href='http://testwiki.mrjc.com/phpAdsNew-2.0/adclick.php?n=ad13c123' target='_blank'><img src='http://testwiki.mrjc.com/phpAdsNew-2.0/adview.php?what=Foobar&amp;clientid=2&amp;n=ad13c123' border='0' alt=''></a></noscript>

and (http://twiki.org/cgi-bin/view/Codev/JavaScriptInterferedWithByTWiki)

<script type="text/javascript">
<!-- Hide JavaScript and <pre> escape TWiki rendering
... your JavaScript goes here...
// Stop hiding and stop </pre> escaping TWiki rendering -->
</script>

Causes an entry such as this in access.log:

65.94.104.160 - - [29/Aug/2004:18:39:14 -0700] "GET /phpAdsNew-2.0/adjs.php?n=239035524&bannerid:1&exclude=, HTTP/1.1" 200 928 "http://cairotwiki.mrjc.com/ad.html" "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; .NET CLR 1.0.3705)"


which then causes this:

65.94.104.160 - - [29/Aug/2004:18:39:14 -0700] "GET /phpAdsNew-2.0/adlog.php?bannerid=1&clientid=2&zoneid=0&source=&block=0&capping=0&cb=092590b19368e17feb905f0b445970fe HTTP/1.1" 200 387 "http://cairotwiki.mrjc.com/ad.html" "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; .NET CLR 1.0.3705)"



=cut

sub handleAdvertRIJS {
    my ($param) = @_;
    my $ans = getTemplateAdvertRemoteInvocationJavaScript();
    $selectionString = $param || "";
    $selectionString =
      $selectionStringPrefix . $selectionString . $selectionStringSuffix;
    TWiki::Func::writeDebug(
        "Advert selection string: '" . $selectionString . "'" );
    $random        = "ad13xc123";      # TODO fix this
    $serverUrlBase = $phpAdsNewBase;

    $ans =~ s/%WHAT%/$selectionString/g;
    $ans =~ s/%RANDOM%/$random/g;
    $ans =~ s/%SERVERURLBASE%/$serverUrlBase/g;

    return $ans;
}

sub getTemplateAdvertRemoteInvocationJavaScript {
    my $ans = <<EOM;
<script language='JavaScript' type='text/javascript'>
<!-- Hide JavaScript and <pre> escape TWiki rendering
   if (!document.phpAds_used) document.phpAds_used = ',';
   phpAds_random = new String (Math.random()); phpAds_random = phpAds_random.substring(2,11);
   
   document.write ("<" + "script language='JavaScript' type='text/javascript' src='");
   document.write ("%SERVERURLBASE%/adjs.php?n=" + phpAds_random);
   document.write ("&amp;what=%WHAT%");
   document.write ("&amp;exclude=" + document.phpAds_used);
   if (document.referer)
      document.write ("&amp;referer=" + escape(document.referer));
   document.write ("'><" + "/script>");
// Stop hiding and stop </pre> escaping TWiki rendering -->
</script><noscript><a href='%SERVERURLBASE%?n=%RANDOM%' target='_blank'><img src='%SERVERURLDIR%/adview.php?what=%WHAT%;%RANDOM%' border='0' alt=''></a></noscript>
EOM
    return $ans;

}

# Template taken from https://www.google.com/adsense/faq-tech
#
sub getTemplateAdvertGoogleAdSense {
    my $ans = <<EOM;
<script language='JavaScript' type='text/javascript'>
<!-- Hide JavaScript and <pre> escape TWiki rendering
google_ad_client = "pub-0000000000000000"; 
google_alternate_ad_url = "http://www.mydomain.com/my_banner.html"; 
google_ad_width = 468; 
google_ad_height = 60; 
google_ad_format = "468x60_as"; 
google_ad_channel = "0000000000"; 
google_color_border = "B4D0DC"; 
google_color_bg = "ECF8FF"; 
google_color_link = "0000CC"; 
google_color_url = "008000"; 
google_color_text = "6F6F6F"; 
// Stop hiding and stop </pre> escaping TWiki rendering -->
</script> 
<script type="text/javascript" 
   src="http://pagead2.googlesyndication.com/pagead/show_ads.js"> 
</script> 
EOM
}

1;
