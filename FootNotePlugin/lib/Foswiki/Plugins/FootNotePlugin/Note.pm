# FootNotePlugin for Foswiki Collaboration Platform, http://foswiki.org/
#
# Copyright (C) 2009 Ian Bygrave, ian@bygrave.me.uk
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

# A single footnote.

package Foswiki::Plugins::FootNotePlugin::Note;

use Foswiki::Func;
use Foswiki::Plugins::FootNotePlugin::LabelFormat;

my %notes        = ();
my $next_num     = 1;
my %labelformats = ();

sub reset {
    %notes        = ();
    $next_num     = 1;
    %labelformats = ();
}

sub makelabel {
    my (%params) = @_;
    my $label;

    if ( exists $params{"LABEL"} ) {
        $label = $params{"LABEL"};
    }
    else {

        # Use the label format given in the footnote,
        # otherwise use the default format specified on the page,
        # otherwise use the global default format.
        my $format = $params{"LABELFORMAT"};
        $format = $Foswiki::cfg{Plugins}{FootNotePlugin}{LabelFormat}
          unless defined $format;

        # Make a new label formatter for this format.
        if ( !exists $labelformats{$format} ) {
            $labelformats{$format} =
              Foswiki::Plugins::FootNotePlugin::LabelFormat->new( $format,
                %labelformats );
        }

        # Use the label formatter if there is one.
        if ( defined $labelformats{$format} ) {
            $label = $labelformats{$format}->makelabel();
        }
        else {
            $label = "Undefined_Label_Format";
        }
    }
    return $label;
}

sub new {
    my ( $class, $page, %params ) = @_;
    my $text = $params{"_DEFAULT"};
    my $safetext;
    my $label;

    # encode HTML special characters
    $safetext = $text;
    $safetext =~ s/[^\w\t ]/'&#'.ord($&).';'/goe;

    # Pick a label
    $label = makelabel(%params);

    # TODO: check for existing note with the same $label

    my $this = {
        n        => $next_num,
        label    => $label,
        page     => $page,
        text     => $text,
        safetext => $safetext,
        anchored => 0,
        printed  => 0,
    };

    bless( $this, $class );

    if ( !exists $notes{$text} ) {
        $notes{$text} = {
            anchors => [],
            first   => $next_num,
            printed => 0,
        };
    }

    push( @{ $notes{$text}->{"anchors"} }, $this );

    $next_num += 1;

    return $this;
}

sub anchor {
    my ($this) = @_;
    return "" if ( $this->{"anchored"} );
    $this->{"anchored"} = 1;
    return "<a name=\"FootNote" . $this->{"n"} . "text\"></a>";
}

sub text {
    my ($this)   = @_;
    my $n        = $this->{"n"};
    my $label    = $this->{"label"};
    my $page     = $this->{"page"};
    my $safetext = $this->{"safetext"};
    return $this->anchor()
      . "<span class=\"FootNoteTextLink\" title=\"${safetext}\">[[${page}#FootNote${n}note][(${label})]]</span>";
}

sub note {
    my ($this) = @_;
    return "" if ( $this->{"printed"} );
    $this->{"printed"} = 1;
    my $n     = $this->{"n"};
    my $label = $this->{"label"};
    my $page  = $this->{"page"};
    return
"<a name=\"FootNote${n}note\"></a><span class=\"FootNoteLabel\">[[${page}#FootNote${n}text][ *${label}* ]]</span>";
}

sub printNotes {
    my ($page) = @_;
    my $result = "";
    my @anchors;

    foreach $note ( sort { $a->{"first"} <=> $b->{"first"} } values(%notes) ) {
        next if $note->{"printed"};
        if ( $page eq "ALL" ) {
            @anchors = @{ $note->{"anchors"} };
        }
        else {
            @anchors = grep { $page eq $_->{"page"} } @{ $note->{"anchors"} };
        }
        next if $#anchors == -1;
        $result .= join( ',', map( $_->note(), @anchors ) );
        $result .=
            ": <span class=\"FootNote\">"
          . $anchors[0]->{"text"}
          . "</span> \n\n";
        $note->{"printed"} = 1;
    }

    return $result;
}

# end of class Note

1;

# vim:ts=2:sts=2:sw=2:et
