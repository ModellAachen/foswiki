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

---+ package Foswiki::Plugins::S3LinkPlugin

=cut

package Foswiki::Plugins::S3LinkPlugin;

use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

use URI();
$URI::DEFAULT_QUERY_FORM_DELIMITER = ';';    # doesn't seem to work
use Digest::HMAC_SHA1();
use Encode qw( encode_utf8 );

our $VERSION = '$Rev: 20101205 (2010-12-05) $';
our $RELEASE = '1.0.0';
our $SHORTDESCRIPTION =
  'Easy linking to S3 storage with optional access controls';
our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    Foswiki::Func::registerTagHandler( 'S3LINK', \&_S3LINK );

    # Allow a sub to be called from the REST interface
    # using the provided alias
    #    Foswiki::Func::registerRESTHandler( 'example', \&restExample );

    return 1;
}

################################################################################
sub _S3LINK {
    my ( $session, $params, $topic, $web, $topicObject ) = @_;

    my $CanonicalizedResource =
      '/' . $params->{bucket} . '/' . $params->{_DEFAULT};
    my $uri = URI->new( 'https://s3.amazonaws.com' . $CanonicalizedResource );

    my $awskey = $Foswiki::cfg{Plugins}{S3LinkPlugin}{AWSAccessKeyId};

    my $opts = { AWSAccessKeyId => $awskey, };
    if ( my $expires_min = $params->{expires} ) {
        $opts->{Expires} = time() + ( $expires_min * 60 );
    }

    my $StringToSign = "GET\n"     # HTTP-VERB
      . "\n"                       # Content-MD5
      . "\n"                       # Content-Type
      . $opts->{Expires} . "\n"    # Expires
      . ''                         # Canonicalized Amz Headers
      . $CanonicalizedResource     # Canonicalized Resource
      ;
    my $signature = Digest::HMAC_SHA1->new($awskey);
    $signature->add( encode_utf8($StringToSign) );
    $opts->{Signature} = $signature->b64digest;
    $uri->query_form($opts);
    return $uri;
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
