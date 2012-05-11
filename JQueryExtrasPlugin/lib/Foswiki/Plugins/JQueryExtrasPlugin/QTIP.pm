# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Javascript is Copyright (C) 2009 Craig Thompson, craig@craigsworks.com
#
# Packaged 2010/03 for Foswiki by Paul.W.Harvey@csiro.au - www.taxonomy.org.au
# Centre for Plant Biodiversity Research CSIRO Plant Industry- www.csiro.au/pi
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details,
# published at http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::JQueryExtrasPlugin::QTIP;
use strict;
use warnings;
use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::JQueryExtrasPlugin::QTIP

This is the perl stub for the jquery.qtip plugin.

=cut

=begin TML

---++ ClassMethod new( $class, $session, ... )

Constructor

=cut

sub new {
    my $class = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;

    my $this = bless(
        $class->SUPER::new(
            $session,
            name          => 'qTip',
            version       => '1.0.0-rc3',
            author        => 'Craig Thompson',
            homepage      => 'http://craigsworks.com/projects/qtip/',
            documentation => "$Foswiki::cfg{SystemWebName}.JQueryQTip",
            puburl        => '%PUBURLPATH%/%SYSTEMWEB%/JQueryExtrasPlugin/qtip',
            javascript    => ['jquery.qtip.js']
        ),
        $class
    );

    return $this;
}

1;
