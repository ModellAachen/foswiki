# See bottom of file for default license and copyright information

=begin TML

---+ package TinyMCECleanStickyBitsPlugin::Core

=cut

package Foswiki::Plugins::TinyMCECleanStickyBitsPlugin::Core;

use strict;
use warnings;

use Foswiki::Func();

=begin TML

---++ setup()

=cut

sub setup {
    my @plugin_ensure  = qw(foswikiclean);
    my @plugin_prefs   = qw(MCEPLUGINS ADDITIONAL_MCEPLUGINS);
    my $plugin_near    = 'table';
    my @buttons_ensure = qw(foswikiclean);
    my @buttons_prefs  = (
        qw(BUTTONS1 BUTTONS2 BUTTONS3),
        qw(ADDITIONAL_BUTTONS1 ADDITIONAL_BUTTONS2 ADDITIONAL_BUTTONS3)
    );
    my $buttons_near = 'tablecontrols';
    my %stickybits   = %{ _getWysiwygStickybits() };

    if (
        not Foswiki::Func::getPreferencesFlag(
            'TINYMCECLEANSTICKYBITSPLUGIN_NO_AUTOLOAD')
      )
    {
        _ensure( \@plugin_ensure, \@plugin_prefs, $plugin_near );
    }
    if (
        not Foswiki::Func::getPreferencesFlag(
            'TINYMCECLEANSTICKYBITSPLUGIN_NO_AUTOTOOLBAR')
      )
    {
        _ensure( \@buttons_ensure, \@buttons_prefs, $buttons_near );
    }
    Foswiki::Func::addToZone(
        'head',
        'TinyMCECleanStickyBitsPlugin',
        _genMeta( \%stickybits )
    );

    return;
}

sub _genMetaMarkup {
    my ( $key, $value ) = @_;

    return CGI::meta(
        {
            -name    => 'foswiki.TinyMCECleanStickyBitsPlugin.' . $key,
            -content => $value
        }
    ) . "\n";
}

sub _genMeta {
    my ($stickybits) = @_;
    my $markup       = '';
    my $index        = 0;

    while ( my ( $tagname, $attributes ) = each %{$stickybits} ) {
        my @attributePatterns = ();
        my @attributeLiterals = ();
        my $attributeLiteralString;
        my $tagType;
        $tagname =~ s/[\r\n\ ]//g;
        if ( $tagname =~ /[^a-zA-Z0-9]/ ) {
            $tagType = 'tagpattern';
        }
        else {
            $tagType = 'tag';
        }
        $markup .= _genMetaMarkup( "$index.$tagType", $tagname );
        foreach my $attribute ( @{$attributes} ) {
            $attribute =~ s/[\r\n\ ]//g;
            if ( $attribute =~ /[^a-zA-Z0-9]/ ) {
                push( @attributePatterns, $attribute );
            }
            else {
                push( @attributeLiterals, $attribute );
            }
        }
        $attributeLiteralString = join( ', ', @attributeLiterals );
        $markup .=
          _genMetaMarkup( "$index.attributes", $attributeLiteralString );
        my $attributePatternIndex = 0;
        foreach my $attributePattern (@attributePatterns) {
            $markup .=
              _genMetaMarkup( "$index.attributePatterns.$attributePatternIndex",
                $attributePattern );
            $attributePatternIndex = $attributePatternIndex + 1;
        }
        if ( scalar(@attributePatterns) ) {
            $markup .= _genMetaMarkup( "$index.attributePatterns.size",
                $attributePatternIndex );
        }
        $index = $index + 1;
    }
    $markup .= _genMetaMarkup( 'size', $index );

    return $markup;
}

# Ensure that items in $ensurelist appear in the values of $preflist,
# and if not, insert them into whatever preference contains $ensurenear.
# Magically, if the preferences aren't set, then pull them from topic sections
sub _ensure {
    my ( $ensurelist, $preflist, $ensurenear ) = @_;
    my %prefs      = ();   # preference values (keyed from $preflist)
    my @absentlist = ();   # $ensurelist items not appearing in $preflist values
    my $target_pref;       # The pref var to insert into

    foreach my $pref ( @{$preflist} ) {
        $prefs{$pref} = _getPref($pref);
    }
    $target_pref = _contains( $ensurenear, \%prefs );

    # No point continuing if missing $near occurance to insert next to
    if ($target_pref) {
        my $setpref = $prefs{$target_pref};
        foreach my $item ( @{$ensurelist} ) {
            if ( not _contains( $item, \%prefs ) ) {
                push( @absentlist, $item );
            }
        }
        foreach my $item (@absentlist) {
            $setpref =~ s/$ensurenear/$ensurenear, $item/;
        }
        Foswiki::Func::setPreferencesValue( 'TINYMCEPLUGIN_' . $target_pref,
            $setpref );
    }

    return ( $target_pref and 1 );
}

sub _getWysiwygStickybits {
    my $preftopic =
      Foswiki::Func::getPreferencesValue('WYSIWYGPLUGIN_STICKYBITS')
      || $Foswiki::cfg{SystemWebName} . '.WysiwygPluginSettings';
    my $preftext = Foswiki::Func::expandCommonVariables(<<"HERE");
%INCLUDE{"$preftopic" section="WYSIWYGPLUGIN_STICKYBITS" warn="off"}%
HERE
    my %stickybits = ();

    # Copied from Foswiki::Plugins::WysiwygPlugin::Handlers::protectedByAttr();
    foreach my $def ( split( /;\s*/s, $preftext ) ) {
        my ( $re, $attributes ) = split( /\s*=\s*/s, $def, 2 );
        my @attributelist = split( /\s*,\s*/, $attributes );
        $stickybits{ lc($re) } = \@attributelist;
    }

    return \%stickybits;
}

# Try to get a TinyMCEPlugin preference value; if not set, then try to get the
# default from TinyMCEPlugin's INIT_TOPIC via the equivalent topic section
sub _getPref {
    my ($pref) = @_;
    my $preftopic =
      Foswiki::Func::getPreferencesValue('TINYMCEPLUGIN_INIT_TOPIC')
      || $Foswiki::cfg{SystemWebName} . '.TinyMCEPlugin';
    my $value = Foswiki::Func::getPreferencesValue( 'TINYMCEPLUGIN_' . $pref )
      || Foswiki::Func::expandCommonVariables(<<"HERE");
%INCLUDE{"$preftopic" section="$pref" warn="off"}%\\
HERE

    return $value;
}

# Check if \b$something\b is contained in a $list (hash). If it is, then return
# the key for the first occurance in which it was found.
sub _contains {
    my ( $something, $list ) = @_;
    my $found = 0;

    while ( ( my ( $key, $value ) = each %{$list} ) and ( not $found ) ) {
        if ( $value =~ /\b$something\b/ ) {
            $found = $key;
        }
    }

    return $found;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Paul.W.Harvey@csiro.au, http://trin.org.au

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
