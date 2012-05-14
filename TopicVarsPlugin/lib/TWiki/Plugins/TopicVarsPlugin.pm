#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2001 Tripp Lilley, tripp+twiki-plugins@perspex.com
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
#
# This plugin allows you to define variables within arbitrary pages
# in your TWiki, then refer to them from other arbitrary pages. It
# (currently) only supports referring to variables defined within
# the same web, but may expand to include cross-web, and possibly
# even InterWiki references in the future.

package TWiki::Plugins::TopicVarsPlugin;

use vars qw(
  $currWeb $currTopic $user $installWeb $VERSION $RELEASE
  %vars
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

sub initPlugin {
    ( $currTopic, $currWeb, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between TopicVarsPlugin and Plugins.pm");
        return 0;
    }

    return 1;
}

## Stolen from TWiki::Prefs::getPrefsFromTopic because I don't
## (offhand) know of an easy way to override that to make it do what I
## want. I suppose I might be able to work some kind of black magic
## with the symbol table, but I'm not up to that right now.
#
# SMELL: with Dakar, you can do it, but it would require calling internals.
# Perhaps some day, when the object model is properly done.
#
sub getVarsFromTopic {
    my ( $web, $topic ) = @_;

    my ( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );

    my $key   = '';
    my $value = '';
    my $isKey = 0;
    foreach ( split( /\r?\n/, $text ) ) {
        if (/^(?:\t|   )+\*\sSet\s(\w+)\s\=\s*(.*)$/) {
            if ($isKey) {
                $vars{$web}{$topic}{$key} = $value;
            }
            $key   = $1;
            $value = $2;
            $value = '' unless defined $value;
            $isKey = 1;
        }
        elsif ($isKey) {
            if ( (/^(\t|   )+/) && ( !/^(\t|   )+\*/ ) ) {

                # follow up line, extending value
                $value .= "\n$_";
            }
            else {
                $vars{$web}{$topic}{$key} = $value;
                $isKey = 0;
            }
        }
    }
    if ($isKey) {
        $vars{$web}{$topic}{$key} = $value;
    }
}

sub get_var {
    my ( $web, $topic, $varname ) = @_;

    my $id = '';

    if ($web) {
        $id = $web . '.';
        if ( defined($TWiki::securityFilter) ) {
            $web =~ s/$TWiki::securityFilter//go;
        }
        else {
            $web =~ s/$TWiki::cfg{NameFilter}//go;
        }
    }
    else {
        $web = $currWeb;
    }

    if ($topic) {
        $id .= $topic . '.';
    }
    else {
        $topic = $currTopic;
    }

    getVarsFromTopic( $web, $topic ) unless $vars{$web}{$topic};
    my $var = $vars{$web}{$topic}{$varname};
    $var = defined $var ? $var : "%$id$varname%";
    return $var;
}

sub commonTagsHandler {
    ### my ( $text, $topic, $web ) = @_;

    ## Handle unqualified var references (will look on this page)
    $_[0] =~ s/%(\w+)%/get_var(undef, undef, $1)/geo;

    ## Handle topic-qualified var references (will look at topics on this web)
    $_[0] =~
s/%([A-Z]+[a-z]+[A-Z]+[A-Za-z0-9]*)\.([A-Za-z0-9_]+)%/get_var(undef, $1, $2)/geo;

    ## Handle fully-qualified var references (will look at webs/topics on this wiki)
    $_[0] =~
      s/%([A-Z][^%]*)\.([A-Z]+[a-z]+[A-Z]+\w*)\.(\w+)%/get_var($1, $2, $3)/geo;
}

1;
