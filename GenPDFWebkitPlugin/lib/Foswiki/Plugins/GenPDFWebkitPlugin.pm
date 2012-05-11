# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009-2010 Michael Daum http://michaeldaumconsulting.com
#
# This license applies to GenPDFWebkitPlugin *and also to any derivatives*
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
# For licensing info read LICENSE file in the Foswiki root.

package Foswiki::Plugins::GenPDFWebkitPlugin;

use strict;

use Foswiki::Func ();
use Foswiki::Plugins ();
use Error qw(:try);

our $VERSION = '$Rev: 4419 (2009-07-03) $';
our $RELEASE = '1.00';
our $SHORTDESCRIPTION = 'Generate PDF using Webkit';
our $NO_PREFS_IN_TOPIC = 1;
our $baseTopic;
our $baseWeb;

use constant DEBUG => 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR "GenPDFWebkitPlugin - $_[0]\n" if DEBUG;
}

###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  if ($Foswiki::Plugins::VERSION < 2.0) {
    Foswiki::Func::writeWarning('Version mismatch between ',
    __PACKAGE__, ' and Plugins.pm');
    return 0;
  }

  return 1;
}

###############################################################################
sub completePageHandler {
  #my($html, $httpHeaders) = @_;

  my $query = Foswiki::Func::getCgiQuery();
  my $contenttype = $query->param("contenttype") || 'text/html';

  # is this a pdf view?
  return unless $contenttype eq "application/pdf";

  require File::Temp;
  require Foswiki::Sandbox;

  # remove left-overs
  $_[0] =~ s/([\t ]?)[ \t]*<\/?(nop|noautolink)\/?>/$1/gis;

  # create temp files
  my $htmlFile = new File::Temp(SUFFIX => '.html', UNLINK => (DEBUG?0:1));
  my $errorFile = new File::Temp(SUFFIX => '.log', UNLINK => (DEBUG?0:1));
  my ($pdfFilePath, $pdfFile) = getFileName($baseWeb, $baseTopic);

  # creater html file
  print $htmlFile "$_[0]";
  #writeDebug("htmlFile=".$_[0]);

  # create webkit command
  my $session = $Foswiki::Plugins::SESSION;
  my $pdfCmd = $Foswiki::cfg{GenPDFWebkitPlugin}{WebkitCmd} || 
    "$Foswiki::cfg{DataDir}/../tools/wkhtmltopdf -q --enable-plugins --outline --print-media-type %INFILE|F% %OUTFILE|F%";
  
  # execute
  my ($output, $exit) = Foswiki::Sandbox->sysCommand(
      $pdfCmd, 
      OUTFILE => $pdfFilePath,
      INFILE => $htmlFile->filename,
    );

  local $/ = undef;

  my $error = '';
  if ($exit || DEBUG) {
    $error = <$errorFile>;
  }

  writeDebug("GenPDFWebkitPlugin - error=$error");
  writeDebug("GenPDFWebkitPlugin - output=$output");

  if ($exit) {
    my $html = $_[0];
    my $line = 1;
    $html = '00000: '.$html;
    $html =~ s/\n/"\n".(sprintf "\%05d", $line++).": "/ge;
    throw Error::Simple("execution of wkhtmltopdf failed ($exit): \n\n$error\n\n$html");
  }

  my $url = Foswiki::Func::getScriptUrl($baseWeb, $baseTopic, 'viewfile',
    filename=>$pdfFile,
    t=>time(),
  );

  Foswiki::Func::redirectCgiQuery($query, $url);
}

###############################################################################
sub getFileName {
  my ($web, $topic) = @_;

  my $fileName = $topic;
  $fileName =~ s{[\\/]+$}{};
  $fileName =~ s!^.*[\\/]!!;
  $fileName =~ s/$Foswiki::regex{filenameInvalidCharRegex}//go;

  $web =~ s/\./\//g;
  my $filePath = Foswiki::Func::getPubDir().'/'.$web.'/'.$topic;
  File::Path::mkpath($filePath);

  $fileName = 'genpdf_'.$fileName.'.pdf';
  $filePath .= '/'.$fileName;

  return ($filePath, $fileName);
}

###############################################################################
sub modifyHeaderHandler {
  my ($hopts, $request) = @_;

  my $query = Foswiki::Func::getCgiQuery();
  my $contenttype = $query->param("contenttype") || 'text/html';

  # is this a pdf view?
  return unless $contenttype eq "application/pdf";

  # add disposition
  $hopts->{'Content-Disposition'} = "inline;filename=$baseTopic.pdf";
}

1;
