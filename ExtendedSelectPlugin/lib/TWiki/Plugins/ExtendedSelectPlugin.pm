#
# ExtendedSelect entry plugin
#
# Copyright (C) Eric Schwertfeger http:/geekzilla.org/
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

package TWiki::Plugins::ExtendedSelectPlugin;

use strict;

use TWiki::Func;

use vars qw( $VERSION $pluginName );

$VERSION    = 1.10;
$pluginName = 'ExtendedSelectPlugin';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;
    if ( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    return 1;
}

sub renderFormFieldForEditHandler {
    my ( $name, $type, $size, $value, $attributes, $possibleValues ) = @_;

    return unless $type =~ /^select\+/;
    my ( $isMulti, $isShrink, $isValues, $selected, $item, $params,
        $itemValue );
    $isMulti  = ( $type =~ /\+multi(\+.+)?$/o );
    $isShrink = ( $type =~ /\+shrink(\+.+)?$/o );
    $isValues = ( $type =~ /\+values(\+.+)?$/o );
    my $choices = '';
    foreach $item (@$possibleValues) {
        $item      = &TWiki::urlDecode($item);
        $params    = {};
        $itemValue = $item;
        if ( $isValues && ( $item =~ /^(.*?[^\\])=(.*)$/o ) ) {
            $item = $1;
            $item =~ s/\\=/=/go;
            $itemValue = $2;
            $params->{'value'} = $itemValue;
        }
        elsif ($isValues) {
            $item =~ s/\\=/=/go;
        }
        if ($isMulti) {
            $selected = ( $value =~ /^(.*,)?\s*$itemValue\s*(,.*)?$/ );
        }
        else {
            $selected = ( $itemValue eq $value );
        }
        if ($selected) {
            $params->{'selected'} = 'selected';
        }
        $item =~ s/<nop/&lt\;nop/go;
        $choices .= CGI::option( $params, $item );
    }
    if ( $isShrink && $#$possibleValues < $size ) {
        if ( $#$possibleValues >= 0 ) {
            $size = $#$possibleValues + 1;
        }
        else {
            $size = 1;
        }
    }
    $params = { name => $name, size => $size };
    if ($isMulti) {
        $params->{'multiple'} = 'on';
    }
    return CGI::Select( $params, $choices );
}

1;
