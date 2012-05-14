# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
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

---+ package Foswiki::Plugins::MathJaxPlugin

=cut

package Foswiki::Plugins::MathJaxPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

use vars qw(
  $web $topic $core %FoswikiCompatibility
);

our $VERSION = '$Rev: 2083 (2010-10-27) $';
our $RELEASE = '0.9.1';

our $SHORTDESCRIPTION =
'Macros for embedding <nop>MathJax (an open source <nop>JavaScript display engine for mathematics)';
our $NO_PREFS_IN_TOPIC = 1;
$FoswikiCompatibility{endRenderingHandler} = 1.1;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    undef $core;

    # Tell WyswiygPlugin to protect <latex>...</latex> markup
    if ( defined &Foswiki::Plugins::WysiwygPlugin::addXMLTag ) {
        Foswiki::Plugins::WysiwygPlugin::addXMLTag( 'latex', sub { 1 } );
    }

    Foswiki::Func::registerTagHandler( 'MATHMODE', \&_MATHMODE );

    #    Foswiki::Func::registerTagHandler( '$', \&_MATHMODE );

    # Allow a sub to be called from the REST interface
    # using the provided alias
    #    Foswiki::Func::registerRESTHandler( 'example', \&restExample );

    # Plugin correctly initialized
    return 1;
}

###############################################################################
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;

    $_[0] =~ s/%\\\[(.*?)\\\]%/&handleMath($1,0)/geo;
    $_[0] =~ s/%\$(.*?)\$%/&handleMath($1,1)/geo;
    $_[0] =~ s/<latex(?: (.*?))?>(.*?)<\/latex>/&handleMath($2,2,$1)/geos;
}

################################################################################
sub getCore {
    return $core if $core;

    require Foswiki::Plugins::MathJaxPlugin::Core;
    $core = new Foswiki::Plugins::MathJaxPlugin::Core;

    return $core;

    # try:
    require Foswiki::Plugins::MathJaxPlugin::Core;
    return $core
      || new Foswiki::Plugins::MathJaxPlugin::Core;
}

###############################################################################
sub handleMath {
    return getCore()->handleMath( $web, $topic, @_ );
}

###############################################################################
sub _MATHMODE {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    # $session  - a reference to the Foswiki session object
    #             (you probably won't need it, but documented in Foswiki.pm)
    # $params=  - a reference to a Foswiki::Attrs object containing
    #             parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             (unnamed) parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the macro. This will replace the
    # macro call in the final text.

    my $math = $params->{_DEFAULT};

    #Foswiki::Func::writeDebug( "MathJaxPlugin MATHMODE{$math}" );
    return handleMath( $math, my $inlineFlag = 0, $params );
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
