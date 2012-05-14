# See bottom of file for default license and copyright information

=begin TML

---+ package TopicRecursePlugin

=cut

package Foswiki::Plugins::TopicRecursePlugin;
use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

our $VERSION = '$Rev$ (06-11-2010)';
our $RELEASE = '0.3.0';

our $SHORTDESCRIPTION =
  'Query topics recursively, inspired by DBCachePlugin\'s DBRECURSE';
our $NO_PREFS_IN_TOPIC = 1;

my $coreLoaded;
my $debuglevel;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)
=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    $coreLoaded = 0;
    Foswiki::Func::registerTagHandler( 'TOPICRECURSE', \&_TOPICRECURSE );

    # Plugin correctly initialized
    return 1;
}

sub _TOPICRECURSE {
    my ( $session, $params, $topic, $web, $topicObject ) = @_;

    if ( not $coreLoaded ) {
        require Foswiki::Plugins::TopicRecursePlugin::Core;
        Foswiki::Plugins::TopicRecursePlugin::Core::init();
        $coreLoaded = 1;
    }

    return Foswiki::Plugins::TopicRecursePlugin::Core::TOPICRECURSE( $session,
        $params, $topic, $web, $topicObject );
}

sub writeDebug {
    my ( $message, $method, $level, $package, $refdebuglevel ) = @_;
    my @lines;

    if ( not defined $refdebuglevel ) {
        $refdebuglevel =
          (      $debuglevel
              || $Foswiki::cfg{Plugins}{TopicRecursePlugin}{Debug}
              || 0 );
    }
    if ( $refdebuglevel and ( not defined $level or $level <= $refdebuglevel ) )
    {
        @lines = split( /[\r\n]+/, $message );
        foreach my $line (@lines) {
            my @packparts = split( /::/, ( $package || __PACKAGE__ ) );
            my $logline = '::'
              . $packparts[ scalar(@packparts) - 1 ]
              . "::$method():\t$line\n";

            if ( defined &Foswiki::Func::writeDebug ) {
                Foswiki::Func::writeDebug($logline);
            }
            else {    # CLI
                print STDERR $logline;
            }
        }
    }

    return;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2011 Paul.W.Harvey@csiro.au, TRIN http://trin.org.au/ &
Centre for Australian National Biodiversity Research http://anbg.gov.au/cpbr
Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
