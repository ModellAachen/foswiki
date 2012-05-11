# See bottom of file for license and copyright information
package Foswiki::Plugins::VarCachePlugin;
use strict;
use Assert;

our $VERSION           = '$Rev$';
our $RELEASE           = '1.2';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION =
"Caches the results of expanding macros in selected topics for improved server performance";

our $MARKER    = "%--\001VARCACHE:";
our $ENDMARKER = "\001--%";
our $monkied;
our @requires;

sub initPlugin {
    my ( $topic, $web ) = @_;
    return 1;
}

# Use the beforeCommonTagsHandler because we may want to blow away the entire topic text
sub beforeCommonTagsHandler {
    my ( $text, $topic, $web ) = @_;

    return unless ( $_[0] =~ /%VARCACHE/ );

    $_[0] =~ s/%VARCACHE(?:{(.*?)})?%/_VARCACHE( $web, $topic, $1 )/es;

  # if "read", replace *all* text with marker, as we are going to load the cache
    if ( $_[0] =~ /(${MARKER}read\@.*?$ENDMARKER)/o ) {
        $_[0] = $1;
    }
    elsif ( $_[0] =~ /(${MARKER}save.*?$ENDMARKER)/o ) {

        # monkey-patch Foswiki::addToZone so we can reap the zones
        my ( $this, $zone, $id, $data, $requires ) = @_;
        no warnings 'redefine';
        $monkied            = \&Foswiki::addToZone;
        @requires           = ();
        *Foswiki::addToZone = sub {
            my @req = @_;
            shift @req;
            push( @requires, \@req );
            &$monkied(@_);
        };
        use warnings 'redefine';
    }
}

sub afterCommonTagsHandler {

    #my ( $text, $topic, $web, $meta ) = @_;

    return unless ( $_[0] =~ /%--\001VARCACHE\:/ );

    if ( $_[0] =~ /${MARKER}(read\@\d+|save):(.*?)$ENDMARKER/ ) {
        my $session = $Foswiki::Plugins::SESSION;
        my ( $act, $tag ) = ( $1, $2 );
        my ( $web, $topic ) = ( $_[2], $_[1] );
        my $cacheFilename = _cacheFileName( $web, $topic );

        if ( $act eq 'save' ) {

            ASSERT($monkied) if DEBUG;

            no warnings 'redefine';
            *Foswiki::addToZone = $monkied;
            use warnings 'redefine';

            # update cache
            Foswiki::Func::saveFile( $cacheFilename, $_[0] );
            my $msg = _formatMsg( $web, $topic, $tag );
            $_[0] =~ s/$MARKER.*?$ENDMARKER/$msg/g;

            require Data::Dumper;
            $Data::Dumper::Indent = 0;
            Foswiki::Func::saveFile( "${cacheFilename}_head",
                Data::Dumper->Dump( [ \@requires ], ['r'] ) );
        }
        else {

            # read cache
            ( $act, my $age ) = split( '@', $act );
            my $text = Foswiki::Func::readFile($cacheFilename);
            my $msg = _formatMsg( $web, $topic, $tag );
            $msg  =~ s/\$age/_formatAge($age)/geo;
            $text =~ s/$MARKER.*?$ENDMARKER/$msg/go;
            $_[0] =~ s/$MARKER.*?$ENDMARKER/$text/o;
            $cacheFilename .= "_head";
            $text = Foswiki::Func::readFile($cacheFilename);
            $text =~ /^(.*)$/s;
            my $r;
            eval $1;

            foreach my $require (@$r) {
                Foswiki::Func::addToZone(@$require);
            }
        }
    }
}

sub _VARCACHE {
    my ( $theWeb, $theTopic, $theArgs ) = @_;
    my $attrs = new Foswiki::Attrs($theArgs);

    my $query  = Foswiki::Func::getCgiQuery();
    my $action = "check";
    if ($query) {
        my $tmp = $query->param('varcache');
        if ( defined $tmp ) {
            $action = ( $tmp eq "refresh" ) ? "refresh" : "";
        }
    }

    if ( $action eq "check" ) {

        # Default action if ?varcache= is not given
        my $filename = _cacheFileName( $theWeb, $theTopic, 0 );
        if ( -e $filename ) {
            my $now       = time();
            my $cacheTime = ( stat $filename )[9];

            # SMELL: Assumes file system store for topics
            $filename = Foswiki::Func::getDataDir() . "/$theWeb/$theTopic.txt";
            my $topicTime = ( stat $filename )[9] || 10000000000;
            my $refresh =
                 $attrs->{_DEFAULT}
              || $attrs->{"refresh"}
              || Foswiki::Func::getPreferencesValue("VARCACHEPLUGIN_REFRESH")
              || 24;
            $refresh *= 3600;    # hours to seconds
            if (   ( ( $refresh == 0 ) || ( $cacheTime >= $now - $refresh ) )
                && ( $cacheTime >= $topicTime ) )
            {

                # add marker to signal completePageHandler to read from cache
                my $paramMsg = $attrs->{"cachemsg"}
                  || Foswiki::Func::getPreferencesValue(
                    "VARCACHEPLUGIN_CACHEMSG")
                  || 'This topic was cached $age ago ([<nop>[$link][refresh]])';
                $cacheTime = $now - $cacheTime;
                return "${MARKER}read\@$cacheTime:$paramMsg$ENDMARKER";
            }
        }
        $action = "refresh";
    }

    if ( $action eq "refresh" ) {

        # add marker to signal completePageHandler to refresh cache
        my $paramMsg =
             $attrs->{"updatemsg"}
          || Foswiki::Func::getPreferencesValue("VARCACHEPLUGIN_UPDATEMSG")
          || 'This topic is now cached ([<nop>[$link][refresh]])';
        return "${MARKER}save:$paramMsg$ENDMARKER";
    }

    # else normal uncached processing
    return "";
}

sub _formatAge {
    my ($s) = @_;
    my @parts;

    my $h = int( $s / 3600 );
    push( @parts, $h );
    $s %= 3600;
    my $m = int( $s / 60 );
    push( @parts, $m );
    $s %= 60;
    push( @parts, $s );

    return join( ':', map { sprintf( '%02d', $_ ) } @parts );
}

sub _formatMsg {
    my ( $theWeb, $theTopic, $msg ) = @_;

    $msg =~ s|\$link|%SCRIPTURL{view}%/%WEB%/%TOPIC%?varcache=refresh|g;
    $msg =~ s|%ATTACHURL%|%PUBURL%/%SYSTEMWEB%/VarCachePlugin|g;
    $msg =~ s|%ATTACHURLPATH%|%PUBURLPATH%/%SYSTEMWEB%/VarCachePlugin|g;
    $msg =~ s|<nop>||g;
    $msg = Foswiki::Func::decodeFormatTokens($msg);
    $msg = Foswiki::Func::expandCommonVariables( $msg, $theTopic, $theWeb );
    $msg = Foswiki::Func::renderText( $msg, $theWeb, $theTopic );
    return $msg;
}

sub _cacheFileName {
    my ( $web, $topic ) = @_;

    my $dir = Foswiki::Func::getWorkArea('VarCachePlugin');
    return "$dir/$web\_$topic";
}

1;
__END__
Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Design and original TWiki implementation by Peter Thoeny

Copyright (C) 2004-2007 Peter Thoeny, peter@thoeny.org
Copyright (C) 2009-2012 Foswiki Contributors

For licensing info read LICENSE file in the Foswiki root.
This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html

As per the GPL, removal of this notice is prohibited.
