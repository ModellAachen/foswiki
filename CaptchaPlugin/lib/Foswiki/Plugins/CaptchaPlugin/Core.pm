# Visual Confirmation Plugin for Foswiki Collaboration 
# Platform, http://Foswiki.org/
#
# Copyright (C) 2011 Michael Daum, daum@michaeldaumconsulting.com
# Copyright (C) 2005-2007 Koen Martens, kmartens@sonologic.nl
# Copyright (C) 2007 KwangErn Liew, kwangern@musmo.com
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
#

# =========================
package Foswiki::Plugins::CaptchaPlugin::Core;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Contrib::JsonRpcContrib::Error ();
use Error qw(:try);

# =========================
sub new {
  my $class = shift;
  my $session = shift;

  my $this = bless({
    session => $session,
    debug => Foswiki::Func::isTrue($Foswiki::cfg{Plugins}{CaptchaPlugin}{Debug}),
    saveForAll => $Foswiki::cfg{Plugins}{CaptchaPlugin}{SaveForAll} || 0,
    @_
  }, $class);

  return $this;
}

# =========================
sub getStore {
  my $this = shift;

  unless ($this->{store}) {
    require Foswiki::Plugins::CaptchaPlugin::Store;
    $this->{store} = Foswiki::Plugins::CaptchaPlugin::Store->new();
  };

  return $this->{store};
}

# =========================
sub CAPTCHACHECK {
  my ($this, $params, $topic, $web) = @_;

  my $theError = $params->{error};
  $theError = 'error' unless defined $theError;

  my $theSuccess = $params->{success};
  $theSuccess = 'success' unless defined $theSuccess;

  my $theChallenge = $params->{challenge};
  my $theResponse = $params->{response};

  return '' unless $theChallenge && $theResponse;

  my $format = $this->isValidCaptcha($theChallenge, $theResponse, 1)?$theSuccess:$theError;

  return Foswiki::Func::decodeFormatTokens($format);
}

# =========================
sub jsonRpcCreate {
  my ($this, $request) = @_;

  require Foswiki::Plugins::CaptchaPlugin::Captcha;
  return Foswiki::Plugins::CaptchaPlugin::Captcha->new(
    $this->getStore, 
    params => $request->params,
  )->toHash();
}

# =========================
sub CAPTCHAFORM {
  my ($this, $params, $topic, $web) = @_;

  Foswiki::Func::readTemplate("captcha");

  return Foswiki::Func::expandTemplate("captcha");
}

# =========================
sub CAPTCHA {
  my ($this, $params, $topic, $web) = @_;

  Foswiki::Plugins::JQueryPlugin::createPlugin("captcha");
  my $metadata = '{'.join(",", map('"'.$_.'": "'.$params->{$_}.'"', grep {!/^_/} keys %$params)).'}';
  return "<span class='jqCaptcha ".$metadata."'><a href='#' class='jqTooltip jqCaptchaReload jqCaptchaContainer' title='%MAKETEXT{\"click to reload\"}%'></a></span>";
}

# =========================
sub isValidCaptcha {
  my ($this, $challenge, $response, $forceDelete) = @_;

  my $captcha = $this->getStore()->readCaptcha($challenge);
  unless ($captcha) {
    my $remoteAddress = Foswiki::Func::getRequestObject()->remoteAddress();
    $challenge ||= '???'; 
    my $msg = "Warning: Requesting check on unknown captcha $challenge from $remoteAddress";
    Foswiki::Func::writeWarning($msg);
    print STDERR $msg."\n";
    return;
  }

  return $captcha->isValid($response, $forceDelete);
}

# =========================
sub beforeSaveHandler {
  my ($this, undef, $topic, $web ) = @_;

  my $wikiName = Foswiki::Func::getWikiName();

  return if $wikiName eq $Foswiki::cfg{Register}{RegistrationAgentWikiName};
  return unless $wikiName eq $Foswiki::cfg{DefaultUserWikiName} || $this->{saveForAll};

  my $query = Foswiki::Func::getCgiQuery();
  my $challenge = $query->param('captcha_challenge');
  my $response = $query->param('captcha_response');

  unless ($this->isValidCaptcha($challenge, $response, 1)) {
    throw Foswiki::OopsException(
      'captcha',
      web => $this->{session}->{webName},
      topic => $this->{session}->{topicName},
      def => 'captcha::invalid_response',
    );
  }
}

1;
