# $REV$
# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006 Meredith Lesly
# And the usual copyright per TWiki.pm

=pod

---+ package InclTag

This is a lighter replacement for %INCLUDE%. It doesn't have all of the
functionality (intentionally), but does add one useful feature: an
optional list of "fallback" webs to look in in addition to the current web.

Note that this is lighter in the sense of stripped-down functionality, not
in terms of speed. As long as the core stuff it calls is slow, this
will be too. Sigh.

=cut

# Always use strict to enforce variable scoping
use strict;

package TWiki;

use TWiki::Func;

sub _INCL {
    my ( $twikiObj, $params, $topic, $web ) = @_;
    my $webNameRegex = TWiki::Func::getRegularExpression('webNameRegex');
    my $inclWeb      = $web;
    my $inclTopic    = $params->{'_DEFAULT'} || $params->{'topic'};
    my $warn         = $params->{'warn'} || 'on';
    my $fallback     = $params->{'fallback'};
    my $user         = TWiki::Func::getWikiName();
    my $webs;

    if ( $inclTopic =~ /^($webNameRegex)\.([^.]+)$/ ) {
        $inclWeb   = $1;
        $inclTopic = $2;
    }

    if ($fallback) {
        $webs = $inclWeb . ',' . $fallback;
    }
    else {
        $webs = $inclWeb;
    }
    $webs =~ tr/ //d;

    my $name = TWiki::Func::getWikiName();

    foreach my $aWeb ( split( /,/, $webs ) ) {
        if (
            TWiki::Func::topicExists( $aWeb, $inclTopic )
            && TWiki::Func::checkAccessPermission(
                'VIEW', $name, undef, $inclTopic, $aWeb
            )
          )
        {
            my ( $meta, $text ) = TWiki::Func::readTopic( $aWeb, $inclTopic );
            return TWiki::Func::expandCommonVariables( $text, $topic, $aWeb );
        }
    }
    if ( warn eq 'on' ) {
        return $twikiObj->inlineAlert( 'alerts', 'topic_not_found',
            $inclTopic );
    }
    else {
        return '';
    }
}

return 1;
