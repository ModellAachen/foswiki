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
package Foswiki::Plugins::CaptchaPlugin::Captcha;

use strict;
use warnings;

use Foswiki::Sandbox ();
use Digest::MD5 ();
use DB_File;
use GD::SecurityImage;# backend => 'Magick';

# =========================
sub new {
  my $class = shift;
  my $store = shift;
  my %args = @_;

  my $pubDir = Foswiki::Func::getPubDir();

  my $this = bless({
    store => $store,
    debug => Foswiki::Func::isTrue($Foswiki::cfg{Plugins}{CaptchaPlugin}{Debug}),
    imgDir => $pubDir . "/System/CaptchaPlugin/img",
    fontsDir => $pubDir . "/System/CaptchaPlugin/fonts",

    bgColor => $Foswiki::cfg{Plugins}{CaptchaPlugin}{BackgroundColor} || 'transparent',
    textColor => $Foswiki::cfg{Plugins}{CaptchaPlugin}{TextColor} || '#000000',
    lineColor => $Foswiki::cfg{Plugins}{CaptchaPlugin}{LineColor} || '#000000',

    font => $Foswiki::cfg{Plugins}{CaptchaPlugin}{Font} || 'random',
    fontSize => $Foswiki::cfg{Plugins}{CaptchaPlugin}{FontSize} || 20,
    numChars => $Foswiki::cfg{Plugins}{CaptchaPlugin}{NumberOfCharacters} || 6,
    chars => $Foswiki::cfg{Plugins}{CaptchaPlugin}{Characters} || 'abcdefghijklmnopqrstuvwxyz',
    knownFonts => $Foswiki::cfg{Plugins}{CaptchaPlugin}{KnownFonts} || 
      'AbscissaBold, AcklinRegular, Activa, BleedingCowboys, FreeMonoBoldOblique, MacType, ManaMana, StayPuft, Vera',

    width => $Foswiki::cfg{Plugins}{CaptchaPlugin}{ImageWidth} || 170,
    height => $Foswiki::cfg{Plugins}{CaptchaPlugin}{ImageHeight} || 65,

    numLines => $Foswiki::cfg{Plugins}{CaptchaPlugin}{NumberOfLines} || 6,

    style => $Foswiki::cfg{Plugins}{CaptchaPlugin}{Style} || 'blank',
    knownStyles => $Foswiki::cfg{Plugins}{CaptchaPlugin}{KnownStyles} || 'default, blank, rect, box, circle, ellipse, ec', 

    particles => $Foswiki::cfg{Plugins}{CaptchaPlugin}{Particles} || '100 100',
    scramble => Foswiki::Func::isTrue($Foswiki::cfg{Plugins}{CaptchaPlugin}{Scramble}, 1),
    frame => Foswiki::Func::isTrue($Foswiki::cfg{Plugins}{CaptchaPlugin}{Frame}), 

    params => {},
    %args

  }, $class);

  $this->{knownFonts} = [split(/\s*,\s*/, $this->{knownFonts})];
  $this->{knownFontsRegex} = '^('. join('|', @{$this->{knownFonts}}) . ')$';
  $this->{knownStyles} = [split(/\s*,\s*/, $this->{knownStyles})];
  $this->{knownStylesRegex} = '^('.join('|', @{$this->{knownStyles}}) . ')$';

  return $this;
}

# =========================
sub randomColor {
  return [ int(rand(255)), int(rand(255)), int(rand(255)) ]
}

# =========================
sub invertColor {
  my $color = shift;

  my @rgb;

  unless (ref($color)) {
    $color =~ s/^#//;
    @rgb = map {hex $_  } unpack 'a2a2a2', $color;
  } else {
    return [0,0,0] if $color eq 'transparent';
    @rgb = @$color;
  }

  return  [255 - $rgb[0], 255 - $rgb[1], 255 - $rgb[2]];
}

# =========================
sub writeDebug {
  my ($this, $message) = @_;
  #Foswiki::Func::writeDebug($message) if $this->{debug};
  print STDERR "CaptchaPlugin::Captcha - $message\n" if $this->{debug};
}

# =========================
sub toHash {
  my $this = shift;

  $this->init();

  return {
    challenge => $this->{challenge},
    width => $this->{width},
    height => $this->{height},
    url => $this->{imgUrl},
  };
}

# =========================
sub toHtml {
  my $this = shift;

  my $format = $this->{params}{format} || "<img src='\$url' width='\$width' height='\$height' /><input type='hidden' name='captcha_challenge' value='\$challenge' />";

  $this->init();

  $format =~ s/\$url/$this->{imgUrl}/g;
  $format =~ s/\$width/$this->{width}/g;
  $format =~ s/\$height/$this->{height}/g;
  $format =~ s/\$challenge/$this->{challenge}/g;

  return Foswiki::Func::decodeFormatTokens($format);
}

# =========================
sub init {
  my ($this, $dontCreate) = @_;

  if((!defined($this->{secret}) || !defined($this->{challenge}) && !$dontCreate )) {

    my $font = $this->{params}{font} || $this->{font};
    if ($font eq 'random') {
      $this->{font} = $this->{knownFonts}[int(rand(scalar(@{$this->{knownFonts}})))];
    } else {
      $this->{font} = $font if $font =~ /$this->{knownFontsRegex}/;
    }
    #$this->writeDebug("font=".$this->{font});

    my $style = $this->{params}{style} || $this->{style};
    if ($style eq 'random') {
      $this->{style} = $this->{knownStyles}[int(rand(scalar(@{$this->{knownStyles}})))];
    } else {
      $this->{style} = $style if $style =~ /$this->{knownStylesRegex}/;
    }
    #$this->writeDebug("style=".$this->{style});

    $this->{fontSize} = $this->{params}{fontsize} if defined $this->{params}{fontsize};
    $this->{height} = $this->{params}{height} if defined $this->{params}{height};
    $this->{numChars} = $this->{params}{numchars} if defined $this->{params}{numchars};
    $this->{numLines} = $this->{params}{numlines} if defined $this->{params}{numlines};
    $this->{width} = $this->{params}{width} if defined $this->{params}{width};
    $this->{chars} = $this->{params}{chars} if defined $this->{params}{chars};
    $this->{chars} = [split(//, $this->{chars})];
    $this->{particles} = $this->{params}{particles} if defined $this->{params}{particles};
    $this->{scramble} = Foswiki::Func::isTrue($this->{params}{scramble}) if defined $this->{params}{scramble};
    $this->{frame} = Foswiki::Func::isTrue($this->{params}{frame}) if defined $this->{params}{frame};

    if (defined $this->{params}{color}) {
      my $color = $this->{params}{color};
      $color = randomColor() if $color eq 'random';
      $this->{lineColor} = $this->{textColor} = $color;
      $this->{textColor} = invertColor($this->{textColor}) if $this->{style} eq 'box';
    } else {
      $this->{bgColor} = $this->{params}{bgcolor} if defined $this->{params}{bgcolor};
      $this->{lineColor} = $this->{params}{linecolor} if defined $this->{params}{linecolor};
      $this->{textColor} = $this->{params}{textcolor} if defined $this->{params}{textcolor};


      $this->{bgColor} = randomColor() if $this->{bgColor} eq 'random';
      $this->{lineColor} = randomColor() if $this->{lineColor} eq 'random';

      if ($this->{style} eq 'box') {
        $this->{textColor} = invertColor($this->{textColor});
      } else {
        $this->{textColor} = randomColor() if $this->{textColor} eq 'random';
      }
    }

    $this->{image} = GD::SecurityImage->new(
      width => $this->{width},
      height => $this->{height},
      ptsize => $this->{fontSize},
      lines => $this->{numLines},
      font => $this->{fontsDir} . "/" . $this->{font} . ".ttf",
      bgcolor => $this->{bgColor},
      scramble => $this->{scramble},
      rndmax => $this->{numChars},
      rnd_data => $this->{chars},
      send_ctobg => 1,
      frame => $this->{frame},
    );

    $this->{secret} = lc($this->{image}->random->random_str());
    $this->{challenge} = Digest::MD5::md5_hex($this->{secret} . time() . rand());
    $this->{counter} = 2; # allow the captcha to be checked twice before it gets deleted automatically
    $this->{remoteAddress} = Foswiki::Func::getRequestObject()->remoteAddress();

    $this->{imgPath} = $this->{imgDir} . "/" . $this->{challenge} . ".png";

    $this->{image}->create('ttf', $this->{style}, $this->{textColor}, $this->{lineColor});

    if ($this->{particles} =~ /^(\d+)[, ](\d+)$/) {
      $this->{image}->particle($1, $2);
    } elsif (Foswiki::Func::isTrue($this->{particles})) {
      $this->{image}->particle;
    }

    my ($data) = $this->{image}->out(force => "png");
  

    # write out image file
    open(IMGFILE, ">" . $this->{imgPath});
    binmode IMGFILE;
    print IMGFILE $data;
    close(IMGFILE);

    # remember challenge
    $this->{store}->writeCaptcha($this);
  } else {
    $this->{imgPath} = $this->{imgDir} . "/" . $this->{challenge} . ".png";
  }

  $this->{imgPath} = Foswiki::Sandbox::normalizeFileName($this->{imgPath});
  $this->{imgUrl} = Foswiki::Func::getPubUrlPath() . "/System/CaptchaPlugin/img/" . $this->{challenge} . ".png";
}

sub isValid {
  my ($this, $response, $forceDelete) = @_;

  my $remoteAddress = Foswiki::Func::getRequestObject()->remoteAddress();

  # check secret and remote address: the response must come from the same address the challenge was created for 
  my $isValid = ($this->{secret} eq lc($response) && $remoteAddress eq $this->{remoteAddress})?1:0;

  $this->{counter}--; # tick every check

  # log when the captcha was generated via a different remoteAddress
  unless ($remoteAddress eq $this->{remoteAddress}) {
    my $msg = "Warning: Challenge responded from $remoteAddress for captcha $this->{challenge} generated via a different address $this->{remoteAddress}";
    Foswiki::Func::writeWarning($msg);
    print STDERR $msg."\n";
  }

  # log any failed challenge
  unless ($isValid) {
    my $msg = "Warning: Challenge failed from $remoteAddress for captcha $this->{challenge}";
    Foswiki::Func::writeWarning($msg); 
    print STDERR $msg."\n";
  }

  $this->writeDebug("forcing delete") if $forceDelete;

  # remove this captcha when:
  # - the response was invalid or
  # - the challenge has been checked twice now or
  # - we force deletion now

  $this->{store}->removeCaptcha($this) if !$isValid || $forceDelete || $this->{counter} <= 0;

  return $isValid;
}

1;

