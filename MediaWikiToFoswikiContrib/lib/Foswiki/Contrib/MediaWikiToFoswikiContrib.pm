# Copyright (C) 2006-2012 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Contrib::MediaWikiToFoswikiContrib;

use strict;
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION );

$VERSION = '$Rev$';
$RELEASE = '2.1';
$SHORTDESCRIPTION = 'MediaWiki 2 Foswiki Conversion Tool';

use Getopt::Long;
use Pod::Usage;
use Foswiki::Contrib::MediaWikiToFoswikiContrib::Converter;

##############################################################################
sub main {
  my $help = 0;
  my %args = (
    debug => 0,
    debug => 0,
    defaultWeb=>'_default',
    dry => 0,
    cumulative => 0,
    excludePattern => '',
    fileName => '',
    images=>'',
    includePattern => '',
    language => 'en',
    match=> '',
    maxPages => 0,
    namespace => '',
    plugin=>'',
    targetWeb => 'MediaWiki',
    topicMapString => '',
    webMapString => '',
  );

  GetOptions(
    "debug|d+" => \$args{debug},
    "dry" => \$args{dry},
    "cumulative" => \$args{cumulative},
    "file|f:s" => \$args{fileName},
    "help|?" => \$help,
    "max|m:i" => \$args{maxPages},
    "web:s" => \$args{targetWeb},
    "exclude:s" => \$args{excludePattern},
    "include:s" => \$args{includePattern},
    "match:s" => \$args{matchPattern},
    "cat:s" => \$args{catPattern},
    "lang:s" => \$args{language},
    "namespace|n:s" => \$args{namespace},
    "webmap:s" => \$args{webMapString},
    "topicmap:s" => \$args{topicMapString},
    "language:s" => \$args{language},
    "images:s" => \$args{images},
    "defaultweb:s" => \$args{defaultWeb},
    "plugin:s" => \$args{plugin},
  ) or pod2usage(2);

  unless (defined
    $Foswiki::Contrib::MediaWikiToFoswikiContrib::Converter::language{$args{language}}) {
    print STDERR "ERROR: unknown language $args{language}. Known languages are: ".
      join(', ', sort keys %Foswiki::Contrib::MediaWikiToFoswikiContrib::language).
      "\n";
    exit;
  }

  pod2usage(-exitval =>1, 
    -verbose=>2,
    -message => "\nThe MEDIAWIKI 2 Foswiki Conversion Tool\n"
  ) if $help;

  my $converter = Foswiki::Contrib::MediaWikiToFoswikiContrib::Converter->new(%args);
  #$converter->writeInfo();
  $converter->convert();
}

1;
