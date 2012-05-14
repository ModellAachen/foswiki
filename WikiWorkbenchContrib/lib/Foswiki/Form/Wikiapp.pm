# See bottom of file for license and copyright information
package Foswiki::Form::Wikiapp;
use strict;
use warnings;

use Foswiki::Form::Select ();
our @ISA = ('Foswiki::Form::Select');

our $APPLICATIONS = 'Applications';

sub getOptions {
  my $this = shift;

  my $vals = $this->{_options};
  return $vals if $vals;

  require Foswiki::WebFilter;
  my $f = new Foswiki::WebFilter('allowed');
  my @apps = ();

  foreach my $app ($Foswiki::Plugins::SESSION->deepWebList($f)) {
    next unless $app =~ /^$APPLICATIONS/;
    $app =~ s/\//./g;
    $app =~ s/.*\.(.+?)$/$1/;

    $app = 'WikiWorkbench' if $app eq $APPLICATIONS;
    push @apps, $app;
  }

  @apps = sort @apps;
  unshift @apps, 'none';

  $this->{_options} = \@apps;

  return $this->{_options};
}

sub renderForDisplay {
  my ($this, $format, $value, $attrs) = @_;


  unless ($value eq 'none') {
    my $label = $value;

    if ($value eq 'WikiWorkbench') {
      $value = $APPLICATIONS;
    } else {
      $value = $APPLICATIONS . '.' . $value;
    }

    $value = '<a href="%SCRIPTURLPATH{"view"}%/' . $value . '/' . $Foswiki::cfg{HomeTopicName} . '">' . $label . '</a>';
  }

  return $this->SUPER::renderForDisplay($format, $value, $attrs);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012 Michael Daum http://michaeldaumconsulting.com

Additional copyrights apply to some or all of the code in this
file as follows:

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
