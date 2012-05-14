# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2012 Michael Daum http://michaeldaumconsulting.com
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

use strict;
use warnings;

=begin TML

---+ package XmlRpcContrib

=cut

package Foswiki::Contrib::XmlRpcContrib;

our $VERSION = '$Rev$';
our $RELEASE = '1.00';
our $SERVER;
our $SHORTDESCRIPTION = '';

=begin TML

---++ ClassMethod registerMethod($methodName, $handler)

register an implementation for a handler

=cut

sub registerMethod {
  getServer()->registerMethod(@_);
}

=begin TML

---++ ClassMethod dispatch($session, $data)

process an xml call

=cut

sub dispatch {
  getServer()->dispatch(@_);
}

=begin TML

---++ ClassMethod getServer()

create a singleton server object

=cut

sub getServer {

  unless (defined $SERVER) {
    require Foswiki::Contrib::XmlRpcContrib::Server;
    $SERVER = Foswiki::Contrib::XmlRpcContrib::Server->new();
  }

  return $SERVER;
}

1;
