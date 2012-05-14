# See bottom of file for license and copyright information
package Foswiki::Plugins::BookmakerPlugin::JQuery;

use strict;
use warnings;
use Assert;

use Foswiki::Plugins::JQueryPlugin ();
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

use Foswiki::Plugins::JQueryPlugin::Plugin ();
use Foswiki::Plugins::BookmakerPlugin      ();

sub new {
    my $class   = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;
    my $src     = (DEBUG) ? '_src' : '';

    my $this = $class->SUPER::new(
        $session,
        name          => 'Bookmaker',
        version       => $Foswiki::Plugins::BookmakerPlugin::RELEASE,
        author        => 'Crawford Currie',
        homepage      => 'http://c-dot.co.uk',
        puburl        => '%PUBURLPATH%/%SYSTEMWEB%/BookmakerPlugin',
        documentation => "$Foswiki::cfg{SystemWebName}.BookmakerPlugin",
        summary       => $Foswiki::Plugins::BookmakerPlugin::SHORTDESCRIPTION,
        css =>
          [ "bookmaker${src}.css", "../JSTreeContrib/themes/apple/style.css" ],
        javascript   => ["bookmaker${src}.js"],
        dependencies => ['JSTree']
    );

    return $this;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
