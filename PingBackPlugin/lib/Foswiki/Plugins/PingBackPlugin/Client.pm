# Pingback Client
#
# Copyright (c) 2005-2012 MichaelDaum http://michaeldaumconsulting.com
#
# based on Pingback Proxy Copyright (c) 2002 by Ian Hickson
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

use strict;
use warnings;

package Foswiki::Plugins::PingBackPlugin::Client;

use LWP::UserAgent ();
use HTTP::Request ();
use RPC::XML::Client ();
use HTML::Entities ();

our $pingClient;
use constant DEBUG => 0; # toggle me

################################################################################
# static
sub writeDebug {
  print STDERR "- PingBackPlugin::Client - " . $_[0] . "\n" if DEBUG;
}

###############################################################################
# construct a signleton pingClient
sub getClient {

  $pingClient = new Foswiki::Plugins::PingBackPlugin::Client() unless $pingClient;

  return $pingClient;
}


################################################################################
# constructor
sub new {
  my ($class) = @_;

  my $this = {
    ua=>'', # LWP::UserAgent
  };

  return bless($this, $class);
}

################################################################################
sub getAgent {
  my $this = shift;

  return $this->{ua} if $this->{ua};

  $this->{ua} = LWP::UserAgent->new();
  $this->{ua}->agent("Foswiki Pingback Client");
  $this->{ua}->timeout(5);
  $this->{ua}->env_proxy();
  #writeDebug("new agent=" . $this->{ua}->agent());

  return $this->{ua};
}

################################################################################
# get target page
sub fetchPage {
  my ($this, $source, $target) = @_;

  writeDebug("called fetchPage($source, $target)");

  my $ua = $this->getAgent();
  my $request = HTTP::Request->new('GET' => $target);
  $request->referer($source);
  return $ua->request($request);
}

################################################################################
# detect a pingback server 
# source : the source of a possible ping
# target  : the ping target
# returns the xmlrpc server that is will take the ping or undef if there's no
# such service for the target
sub detectServer {
  my ($this, $source, $target) = @_;
  
  writeDebug("called detectServer($source, $target)");

  # get target page
  my $response = $this->fetchPage($source, $target);
  if ($response->is_error) {
    writeDebug("got an error code=".$response->code.", status=".$response->status_line);
    return;
  }

  my $content = $response->content;
  my $server;
  # check http header
  if (my @servers = $response->header('X-Pingback')) {
    $server = $servers[0];
    writeDebug("found server=$server in X-Pingback");
  } 
  
  # check html header
  elsif ($content =~ m/<link\s+rel=["']pingback['"]\s+href=["']([^"']+)["']\s*\/?>/ ||
      $content =~ m/<link\s+href=["']([^"']+)["']\s+rel=["']pingback["']\s*\/?>/) {
    $server = HTML::Entities::decode_entities($1);
    writeDebug("found server=$server in html header");
  } 
  
  # not found
  else {
    writeDebug("No pingback server found");
  }

  return $server;
}

################################################################################
# send a pingback to a server
# - source : the citing instance
# - target : the cited instance
# - server : the xmlrpc server (optional)
# returns ($status, $result) where
# - status : the http status code
# - result : is a plain text (error) message 
sub ping {
  my ($this, $source, $target, $server) = @_;

  writeDebug("called ping($source, $target)");

  # detect client
  unless ($server) {
    $server = $this->detectServer($source, $target);
    unless ($server) {
      # no server
      return ('501 Not Implemented', "target not pingback enabled");
    }
  }

  # do an xmlrpc call
  my $client = RPC::XML::Client->new($server);
  my $response = $client->send_request('pingback.ping', $source, $target);

  my $status = '';
  my $result = '';

  if (not ref $response) {
    $status = 502;
    $result = "Bad Gateway (not a valid XML-RPC response) from '$server':\n$response\n";
  } elsif ($response->is_fault) {
    my $value = $response->value;
    $status = $value->{faultCode};
    $result = $value->{faultString};
  } else {
    $status = 202;
    $result = $response->as_string;
  }

  writeDebug("status=$status, result=$result");

  return ($status, $result);
}

1;

