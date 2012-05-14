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
package Foswiki::Plugins::CaptchaPlugin::Store;

use strict;
use warnings;

use DB_File;
use Fcntl qw(:flock);
use Foswiki::Plugins::CaptchaPlugin::Captcha ();

# =========================
sub new {
  my $class = shift;

  my $this = bless({
    debug => Foswiki::Func::isTrue($Foswiki::cfg{Plugins}{CaptchaPlugin}{Debug}),
    expiry => int($Foswiki::cfg{Plugins}{CaptchaPlugin}{Expiry} || 600),
    @_
  }, $class);

  $this->{dbPath} = Foswiki::Func::getWorkArea("CaptchaPlugin") . "/secrets.db";

  $this->expire;

  return $this;
}

# =========================
sub writeDebug {
  my ($this, $message) = @_;
  #Foswiki::Func::writeDebug($message) if $this->{debug};
  print STDERR "CaptchaPlugin::Store - $message\n" if $this->{debug};
}

# =========================
sub readCaptcha {
  my ($this, $challenge) = @_;

  return unless $challenge;
  $this->lockDB(LOCK_SH);

  my %database;
  tie(%database, 'DB_File', $this->{dbPath}, O_CREAT | O_RDONLY, 0664, $DB_HASH);
  
  my $val = $database{$challenge};
  return unless $val;

  my ($time, $secret, $counter, $remoteAddress) = split(/,/, $val);
  $counter = 2 unless defined $counter;
    $remoteAddress ||= '';

  untie(%database);
  $this->unlockDB;

  return unless $secret; # not found

  return Foswiki::Plugins::CaptchaPlugin::Captcha->new(
    $this, 
    secret => $secret,
    challenge => $challenge,
    counter => $counter,
    remoteAddress => $remoteAddress,
  );
}

# =========================
sub writeCaptcha {
  my ($this, $captcha) = @_;

  $this->lockDB;

  my %database;
  tie(%database, 'DB_File', $this->{dbPath}, O_CREAT | O_RDWR, 0664, $DB_HASH);

  #$this->writeDebug("storing secret=$captcha->{secret} challenge=$captcha->{challenge}");

  $database{$captcha->{challenge}} = join(",",
    time(),
    $captcha->{secret},
    $captcha->{counter},
    $captcha->{remoteAddress},
  );

  untie(%database);
  $this->unlockDB;
}

# =========================
sub removeCaptcha {
  my ($this, $captcha) = @_;

  return unless defined $captcha;

  $this->writeDebug("removing captcha $captcha->{challenge}");

  $this->lockDB;
  my %database;
  tie(%database, 'DB_File', $this->{dbPath}, O_CREAT | O_RDWR, 0664, $DB_HASH);

  delete($database{$captcha->{challenge}});

  untie(%database);
  $this->unlockDB;

  $captcha->init(1); # to make sure all properties are set
  my $imgPath = $captcha->{imgPath};

  $this->writeDebug("unlinking $imgPath");
  unlink($imgPath);
}

# =========================
sub lockDB {
  my ($this, $mode) = @_;

  $mode ||= LOCK_EX;

  die "no dbPath" unless defined $this->{dbPath};

  my $lockfile = $this->{dbPath} . ".lock";
  open($this->{lockFile}, ">$lockfile") or die "can't create lock file $lockfile";
  flock($this->{lockFile}, $mode);
}

# =========================
sub unlockDB {
  my $this = shift;

  flock($this->{lockFile}, LOCK_UN);
  close($this->{lockFile});
}

# =========================
sub expire {
  my $this = shift;

  my %database;
  tie(%database, 'DB_File', $this->{dbPath}, O_CREAT | O_RDONLY, 0664, $DB_HASH);

  my $now = time();
  while(my ($key,$val) = each %database) {
    #$this->writeDebug("checking $key");

    my ($time, $secret, $counter, $remoteAddress) = split(/,/, $val);
    $counter = 2 unless defined $counter;
    $remoteAddress ||= '';

    if ($now >= $time + $this->{expiry}) {
      my $captcha = Foswiki::Plugins::CaptchaPlugin::Captcha->new(
        $this, 
        secret => $secret,
        challenge => $key,
        counter => $counter,
        remoteAddress => $remoteAddress,
      );
      $this->writeDebug("challenge $key expired");

      $this->removeCaptcha($captcha);
    }
  }
  untie(%database);
}

1;
