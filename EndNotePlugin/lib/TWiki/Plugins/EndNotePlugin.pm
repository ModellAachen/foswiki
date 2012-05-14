# EndNotePlugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006 Ian Bygrave, ian@bygrave.me.uk
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

# =========================
package TWiki::Plugins::EndNotePlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $pluginName
  $debug @endnotes %endnote_nums
);

$VERSION    = '1.021';
$pluginName = 'EndNotePlugin';    # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG");

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub storeEndNote {
    my $i;
    my $anchor = "";
    if ( exists $endnote_nums{ $_[0] } ) {
        $i = $endnote_nums{ $_[0] };
    }
    else {
        @endnotes              = ( @endnotes, $_[0] );
        $i                     = @endnotes;
        $endnote_nums{ $_[0] } = $i;
        $anchor                = "<a name=\"EndNote${i}text\"></a>";
    }
    return "${anchor}<sup>[[#EndNote${i}note][${i}]]</sup>";
}

# =========================
sub printEndNotes {
    my $c = @endnotes;
    return "" if ( $c == 0 );
    my $result = "\n---\n\n";
    my $i      = 0;
    my $n;
    while ( $i < $c ) {
        $n      = $i + 1;
        $result = $result
          . "\n#EndNote${n}note [[#EndNote${n}text][ *${n}:* ]] ${endnotes[$i]}\n\n";
        $i = $n;
    }
    $result = $result . "---\n\n";
    return $result;
}

# =========================
sub startRenderingHandler {
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug("- ${pluginName}::startRenderingHandler( $_[1] )")
      if $debug;

    @endnotes     = ();
    %endnote_nums = ();
    $_[0] =~ s/%ENDNOTE{(.*?)}%/&storeEndNote($1)/ge;
    $_[0] = $_[0] . printEndNotes();

}

# =========================

1;
