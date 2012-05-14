# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::SolrPlugin::SupportedLanguages;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;

    unless ( $Foswiki::cfg{SolrPlugin}{SupportedLanguages}
        && ref( $Foswiki::cfg{SolrPlugin}{SupportedLanguages} ) )
    {
        $Foswiki::cfg{SolrPlugin}{SupportedLanguages} = {
            'en'         => 'en',
            'english'    => 'en',
            'cjk'        => 'cjk',
            'chinese'    => 'cjk',
            'japanese'   => 'cjk',
            'korean'     => 'cjk',
            'da'         => 'da',
            'danish'     => 'da',
            'de'         => 'de',
            'german'     => 'de',
            'es'         => 'es',
            'spanish'    => 'es',
            'fi'         => 'fi',
            'finish'     => 'fi',
            'fr'         => 'fr',
            'french'     => 'fr',
            'it'         => 'it',
            'italian'    => 'it',
            'nl'         => 'nl',
            'dutch'      => 'nl',
            'pt'         => 'pt',
            'portuguese' => 'pt',
            'ru'         => 'ru',
            'russian'    => 'ru',
            'se'         => 'se',
            'swedish'    => 'se',
            'tr'         => 'tr',
            'turkish'    => 'tr'
        };

        return $this->guessed(0);
    }

    return;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012-2012 Foswiki Contributors. Foswiki Contributors
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
