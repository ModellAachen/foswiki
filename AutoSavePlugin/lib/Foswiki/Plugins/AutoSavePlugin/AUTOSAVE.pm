# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Javascript is Copyright (C) 2009 Thomas Zobel
#
# Packaged 2010 for Foswiki by Oliver Krueger, oliver@wiki-one.net
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

package Foswiki::Plugins::AutoSavePlugin::AUTOSAVE;
use strict;
use warnings;
use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::AutoSavePlugin::AUTOSAVE; 

This is the perl stub for the autosave plugin.

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
            name          => 'AutoSave',
            version       => '1.0.0',
            author        => 'Thomas Zobel, Oliver Krueger',
            homepage      => 'http://foswiki.org/Extensions/AutoSavePlugin',
            documentation => "$Foswiki::cfg{SystemWebName}.AutoSavePlugin",
            puburl        => '%PUBURLPATH%/%SYSTEMWEB%/AutoSavePlugin',
            javascript    => ['autosave.js']
        ),
        $class
    );

    return $this;
}

1;
