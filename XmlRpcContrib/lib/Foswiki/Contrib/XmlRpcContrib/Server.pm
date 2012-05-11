# XML-RPC server for Foswiki
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

package Foswiki::Contrib::XmlRpcContrib::Server;

use RPC::XML ();
use RPC::XML::Parser ();
use Error qw( :try );

use constant DEBUG => 0; # toggle me

# predefined error codes:
# -32700: parse error. not well formed
# -32701: parse error. unsupported encoding
# -32702: parse error. invalid character for encoding
# -32600: server error. invalid xml-rpc. not conforming to spec.
# -32601: server error. requested method not found
# -32602: server error. invalid method parameters
# -32603: server error. internal xml-rpc error
# -32500: application error
# -32400: system error
# -32300: transport error

################################################################################
# static
sub writeDebug {
  print STDERR '- XmlRpcContrib::Server - '.$_[0]."\n" if DEBUG;
}

################################################################################
# constructor
sub new {
  my $class = shift;

  writeDebug("called constructor");

  my $this = {
    parser=> RPC::XML::Parser->new(),
    session=>'',
  };

  return bless($this, $class);
}

################################################################################
sub registerMethod {
  my ($this, $methodName, $fnref, %options) = @_;

  writeDebug("registerMethod($methodName, $fnref)");

  $this->{handler}{$methodName} = {
    function => $fnref,
    %options
  };
}

################################################################################
sub dispatch {
  my ($this, $session, $data) = @_;

  writeDebug("called dispatch");
  $this->{session} = $session;

  unless (defined $data) {
    my $query = $session->{cgiQuery};
    $data = $query->param('POSTDATA') || '';
  }

  #writeDebug("data=$data");

  # check ENV
  if ($ENV{'REQUEST_METHOD'} ne 'POST') {
    $this->printError('405 Method Not Allowed', -32300, 'Only XML-RPC POST requests recognised.');
    return;
  }

  if ($ENV{'CONTENT_TYPE'} ne 'text/xml') {
    $this->printError('415 Unsupported Media Type', -32300, 'Only XML-RPC POST requests recognised.');
    return;
  }

  # parse
  my $request = $this->{parser}->parse($data);
  unless (ref($request)) {
    $this->printError('400 Bad Request', -32700, $request) unless ref($request);
    return;
  }

  # get handler
  my $name = $request->name;
  my $handler = $this->{handler}{$name};

  # check impl
  unless ($handler) {
    $this->printError('501 Not Implemented', -32601, "Method $name not supported");
    return;
  }

  # call 
  my $result;
  my $status;
  my $error;
  $session->enterContext($name);
  try {
    no strict 'refs';
    my $function = $handler->{function};
    ($status, $error, $result) = &$function($session, $request->args);
    use strict 'refs';
  } catch Error::Simple with {
    $status = '500 Server Error';
    $error  = -32500;
    $result = "Internal server error".shift;
  };
  $session->leaveContext($name);

  writeDebug("status=$status");
  writeDebug("error=$error");
  writeDebug("result=$result");

  # print response
  if ($error == 0) {
    $result = RPC::XML::string->new($result) if not ref $result;
    $this->print($status, $this->getResponse($result)); # default 
  } else {
    $this->printError($status, $error, $result); # error
  }

  return;
}

################################################################################
sub getError  {
  my ($this, $error, $data) = @_;

  return $this->getResponse(RPC::XML::fault->new($error, $data));
}

################################################################################
sub getResponse {
  my ($this, $data) = @_;

  return RPC::XML::response->new($data);
}

################################################################################
sub printError {
  my ($this, $status, $error, $data) = @_;

  $this->print($status, $this->getError(-32300, 'Only XML-RPC POST requests recognised.'));
}

################################################################################
sub print {
  my ($this, $status, $response) = @_;

  $this->{session}->{response}->header(
    -status  => $status,
    -type    => 'text/plain',
  );

  my $text = $response->as_string;
print STDERR "response=$text\n";

  $this->{session}->{response}->print($response->as_string);
}

1;
