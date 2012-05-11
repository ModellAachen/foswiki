package Foswiki::Plugins::CaptchaPlugin::JQueryPlugin;

use strict;
use warnings;

use Foswiki::Plugins::CaptchaPlugin ();
use Foswiki::Plugins::JQueryPlugin::Plugin ();
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

sub new {
  my $class = shift;

  my $this = bless(
    $class->SUPER::new(
      name => 'Captcha',
      version => $Foswiki::Plugins::CaptchaPlugin::RELEASE,
      author => 'Michael Daum',
      homepage => 'http://foswiki.org/Extensions/CaptchaPlugin',
      javascript => ['jquery.captcha.js'],
      css => ['jquery.captcha.css'],
      documentation => 'CaptchaPlugin',
      puburl => '%PUBURLPATH%/%SYSTEMWEB%/CaptchaPlugin',
      dependencies => ['tmpl', 'jsonrpc', 'tooltip'],
    ),
    $class
  );

  return $this;
}

1;

