# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2002-2008 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2005-2006 Michael Daum <micha@nats.informatik.uni-hamburg.de>
# Copyright (C) 2005 TWiki Contributors
# Copyright (C) 2009 Foswiki Contributors
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
package Foswiki::Plugins::HeadlinesPlugin;
use strict;

# =========================
use vars qw($VERSION $RELEASE $isInitialized $doneHeader);

$VERSION = '$Rev$';
$RELEASE = '2.21.2';

# =========================
sub initPlugin {

    $isInitialized = 0;
    $doneHeader    = 0;

    return 1;
}

# =========================
sub commonTagsHandler {

    $_[0] =~
      s/([ \t]*)%HEADLINES{(.*?)}%/handleHeadlinesTag($_[2], $_[1], $1, $2)/geo;

    unless ($doneHeader) {
        my $link =
            '<link rel="stylesheet" '
          . 'href="%PUBURL%/%SYSTEMWEB%/HeadlinesPlugin/style.css" '
          . 'type="text/css" media="all" />';
        if ( $_[0] =~ s/<head>(.*?[\r\n]+)/<head>$1$link\n/o ) {
            $doneHeader = 1;
        }
    }
}

# =========================
sub handleHeadlinesTag {

    unless ($isInitialized) {
        eval 'use Foswiki::Plugins::HeadlinesPlugin::Core;';
        die $@ if $@;
        $isInitialized = 1;
    }

    return Foswiki::Plugins::HeadlinesPlugin::Core::handleHeadlinesTag(@_);
}

1;
