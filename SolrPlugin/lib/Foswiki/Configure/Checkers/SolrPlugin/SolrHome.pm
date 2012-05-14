# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::SolrPlugin::SolrHome;

use strict;
use warnings;

use File::Spec();
use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;
    my $mess = '';

    if (
        $Foswiki::cfg{SolrPlugin}{AutoStartDaemon}
        && (  !$Foswiki::cfg{SolrPlugin}{SolrHome}
            || $Foswiki::cfg{SolrPlugin}{SolrHome} ne 'NOT SET' )
      )
    {
        my ( $vol, $dir ) =
          File::Spec->splitpath( $Foswiki::cfg{ScriptUrlPath}, 1 );
        my @dirs = File::Spec->splitdir($dir);

        pop(@dirs);
        $Foswiki::cfg{SolrPlugin}{SolrHome} =
          File::Spec->catpath( $vol, File::Spec->catdir( @dirs, 'solr' ), '' );
        $mess .= $this->guessed(0);
    }
    $mess .= $this->showExpandedValue( $Foswiki::cfg{SolrPlugin}{SolrHome} );

    return $mess;
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
