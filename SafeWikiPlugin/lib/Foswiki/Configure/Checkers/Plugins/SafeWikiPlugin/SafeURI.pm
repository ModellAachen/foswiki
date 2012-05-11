# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Plugins::SafeWikiPlugin::SafeURI;
use strict;
use warnings;

use Foswiki::Configure::Checker;

use Foswiki::Configure::Checker;
our @ISA = qw( Foswiki::Configure::Checker );

my @goodURIs = (
    "$Foswiki::cfg{DefaultUrlHost}$Foswiki::cfg{PubUrlPath}/"
      . "$Foswiki::cfg{SystemWebName}/JavascriptFiles/strikeone.js",
    "$Foswiki::cfg{PubUrlPath}/$Foswiki::cfg{SystemWebName}"
      . '/JavascriptFiles/strikeone.js'
);

sub getGoodURIs {
    return @goodURIs;
}

sub expandVars {
    my $thestring = shift;

    $thestring =~ s/(\$Foswiki::cfg({.*?})+)/eval($1)/ge;

    return $thestring;
}

sub check {
    my $this = shift;
    my $warnings;
    my $safeURIs = $Foswiki::cfg{Plugins}{SafeWikiPlugin}{SafeURI};
    my @badURIs  = (

        #"$Foswiki::cfg{DefaultUrlHost}$Foswiki::cfg{PubUrlPath}/" .
        #    "$Foswiki::cfg{SystemWebName}/JavascriptFiles/bad.file",
        "$Foswiki::cfg{DefaultUrlHost}$Foswiki::cfg{PubUrlPath}"
          . '/BadWeb/JavascriptFiles/bad.file',
        "$Foswiki::cfg{DefaultUrlHost}/JavascriptFiles/bad.file",

        #"$Foswiki::cfg{PubUrlPath}/$Foswiki::cfg{SystemWebName}" .
        #    "/JavascriptFiles/bad.file",
        "$Foswiki::cfg{PubUrlPath}/BadWeb/JavascriptFiles/bad.file",
        '/JavascriptFiles/bad.file',
        "http://bad.com$Foswiki::cfg{PubUrlPath}/$Foswiki::cfg{SystemWebName}"
          . '/JavascriptFiles/bad.file',
"http://bad.com$Foswiki::cfg{PubUrlPath}/BadWeb/JavascriptFiles/bad.file",
        'http://bad.com/JavascriptFiles/bad.file',
        "https://bad.com$Foswiki::cfg{PubUrlPath}/$Foswiki::cfg{SystemWebName}"
          . '/JavascriptFiles/bad.file',
"https://bad.com$Foswiki::cfg{PubUrlPath}/BadWeb/JavascriptFiles/bad.file",
        'https://bad.com/JavascriptFiles/bad.file',
        "bad://bad.com$Foswiki::cfg{PubUrlPath}/$Foswiki::cfg{SystemWebName}"
          . '/JavascriptFiles/bad.file',
"bad://bad.com$Foswiki::cfg{PubUrlPath}/BadWeb/JavascriptFiles/bad.file",
        'bad://bad.com/JavascriptFiles/bad.file',
    );

    if ( $Foswiki::cfg{Plugins}{SafeWikiPlugin}{Enabled} ) {
        foreach my $safeURI ( @{$safeURIs} ) {
            my $expandedSafeURI = expandVars($safeURI);
            foreach my $badURI (@badURIs) {
                if ( $badURI =~ /$expandedSafeURI/ ) {
                    $warnings .= $this->WARN(<<"HERE");
Regexp: "<code style="color:#009900;">$safeURI</code>" failed to filter the bad
URI: "<code style="color:#009900;">$badURI</code>".
HERE
                }
            }
            foreach my $goodURI (@goodURIs) {
                if ( $goodURI !~ /$expandedSafeURI/ ) {
                    $warnings .= $this->WARN(<<"HERE");
Regexp: "<code style="color:#009900;">$safeURI</code>" filters the good URI: 
"<code style="color:#009900;">$goodURI</code>", which may prevent your wiki from
working correctly.
HERE
                }
            }
        }
    }

    return $warnings;
}

1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
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
