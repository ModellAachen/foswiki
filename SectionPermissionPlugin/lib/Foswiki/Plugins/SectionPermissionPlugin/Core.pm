# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# Copyright (C) 2009 Sven Hess, shess@seibert-media.net

package Foswiki::Plugins::SectionPermissionPlugin::Core;

use strict;

require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version

use vars qw($currentUser);

sub init {
    ($currentUser) = @_;
}

sub sectionPermissions {

    my ( $attributes, $theText ) = @_;

    $attributes ||= '';

    # return if current user is an admin
    return $theText if Foswiki::Func::isAnAdmin($currentUser);

    my %params = Foswiki::Func::extractParameters($attributes);

    my $allow = $params{allow} || $params{"_DEFAULT"} || '';

    my $deny = $params{deny} || '';

    # allow a grouplist from view
    if ( ( $allow ne '' ) && ( $deny eq '' ) ) {

        my $validGroup = 0;
        foreach my $group ( split( /\s*,\s*/, $allow ) ) {

            $validGroup = 1 if ( Foswiki::Func::isGroup($group) );
            return $theText
              if ( Foswiki::Func::isGroupMember( $group, $currentUser ) );
        }

        return '' if ( $validGroup == 1 );
    }

    # deny a grouplist from view
    elsif ( ( $deny ne '' ) && ( $allow eq '' ) ) {

        foreach my $group ( split( /\s*,\s*/, $deny ) ) {
            return ''
              if ( Foswiki::Func::isGroupMember( $group, $currentUser ) );
        }
    }

    return $theText;
}

1;
