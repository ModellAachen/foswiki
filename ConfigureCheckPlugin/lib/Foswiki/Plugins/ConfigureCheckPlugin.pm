# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::ConfigureCheckPlugin

Some day we might want to extend this into a configuration editor, and so get rid of some of the
cruftier bits of =configure=.

=cut

package Foswiki::Plugins::ConfigureCheckPlugin;

use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

our $VERSION = '$Rev: 13994 $';
our $RELEASE = '1.0.0';
our $SHORTDESCRIPTION =
'Run =configure= checkers from a plugin, to help debug a broken configuration';
our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    Foswiki::Func::registerTagHandler( 'CONFIGURE_CHECK', \&_CONFIGURE_CHECK )
      ;                     #	if Foswiki::Func::isAnAdmin();

    return 1;
}

{

    # Keeps a count of errors and warnings seen so far
    package Counter;

    sub new {
        my $class = shift;
        return bless( {}, $class );
    }

    sub inc {
        my ( $this, $k ) = @_;
        $this->{$k}++;
    }
}

sub _CONFIGURE_CHECK {
    my ( $session, $params ) = @_;
    $params->{format} ||= "| \$keys | \$answer |";
    require Foswiki::Configure::UI;
    my $c = _doChecks( '', new Counter(), $params );
    return join( $params->{separator} || "\n", @$c );
}

sub _doChecks {
    my ( $keys, $counter, $params ) = @_;
    my $data = $keys ? eval("\$Foswiki::cfg$keys") : \%Foswiki::cfg;
    my @checked;
    my $c = Foswiki::Configure::UI::loadChecker( $keys, $counter );
    my $haveReport = 0;
    my $answer;

    if ( !$c ) {
        if ( ref($data) eq 'HASH' ) {
            foreach my $key ( sort keys %$data ) {
                if ( $key =~ /^\w+$/ ) {
                    my ( $c, $i ) =
                      _doChecks( "$keys\{$key\}", $counter, $params );
                    push( @checked, @$c );
                }
            }
            return \@checked;
        }
        $answer = "No checker";
    }
    else {
        $answer = $c->check();
        if ( $answer && $answer eq 'NOT USED IN THIS CONFIGURATION' ) {
            $answer = "Not used";
        }
        elsif ($answer) {
            $answer =~ s/\n/ /g;
            $haveReport = 1;
        }
        else {
            $answer = "OK";
        }
    }
    if ( $haveReport || Foswiki::Func::isTrue( $params->{all} ) ) {
        my $fmt = $params->{format};
        $fmt =~ s/\$keys/$keys/g;
        $fmt =~ s/\$answer/$answer/g;
        $fmt =~ Foswiki::Func::decodeFormatTokens($fmt);
        push( @checked, $fmt );
    }

    return \@checked;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: CrawfordCurrie

Copyright (C) 2012 Foswiki Contributors. Foswiki Contributors
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
