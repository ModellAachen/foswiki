# Plugin for Foswiki Collaboration Platform, http://Foswiki.org/
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
# Author: Crawford Currie http://c-dot.co.uk
#

=pod

---+ package Foswiki::Plugins::PerlPlugin

This plugin provides an %PERL Foswiki variable that allows perl scripts to
be directly embedded in topics and executed on the server. It uses the
'Safe' package to limit the opcodes and namespace of the executed code,
to minimise the security risk.

=cut

package Foswiki::Plugins::PerlPlugin;

use strict;

use Safe       ();
use IO::Scalar ();

use Assert;
use Foswiki::Func    ();
use Foswiki::Sandbox ();

our $VERSION           = '$Rev$';
our $RELEASE           = '1.1.3';
our $SHORTDESCRIPTION  = 'Embed perl scripts in Foswiki topics';
our $NO_PREFS_IN_TOPIC = 1;

# The Safe container
our $compartment;
our $stderr;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # Delete any existing container so there is no reuse between mod_perl runs
    $compartment = undef;

    Foswiki::Func::registerTagHandler( 'PERL', \&_PERL );

    return 1;
}

sub _PERL {
    my ( $session, $params, $topic, $web ) = @_;

    my $expr = $params->{_DEFAULT};

    if ( defined $params->{topic} ) {
        my ( $w, $t ) =
          Foswiki::Func::normalizeWebTopicName( $web, $params->{topic} );
        if (
            !Foswiki::Func::checkAccessPermission(
                'VIEW', Foswiki::Func::getWikiName(),
                undef, $t, $w
            )
          )
        {
            return
"<pre class='foswikiAlert'>%PERL error: Access to $w.$t denied</pre>";
        }
        ( my $meta, $expr ) = Foswiki::Func::readTopic( $w, $t );
        if ( $expr =~ /%CODE(?:{\s*"perl".*?})?%(.*?)%ENDCODE%/s ) {
            $expr = $1;    # implicit untaint
        }
        else {
            $expr = Foswiki::Sandbox::untaintUnchecked($expr);
        }
        ASSERT( UNTAINTED($expr) ) if DEBUG;
    }
    return "<pre class='foswikiAlert'>%PERL error: no code to execute</pre>"
      unless defined $expr;

    if ( !defined($compartment) ) {
        $compartment = new Safe();

        # The compartment is created with ':default' ops enabled
        # :default = :base_core :base_mem :base_loop :base_orig :base_thread
        if ( $Foswiki::cfg{Plugins}{PerlPlugin}{Opcodes}{Permit} ) {
            $compartment->permit(
                @{ $Foswiki::cfg{Plugins}{PerlPlugin}{Opcodes}{Permit} } );
        }
        if ( $Foswiki::cfg{Plugins}{PerlPlugin}{Opcodes}{Deny} ) {
            $compartment->deny(
                @{ $Foswiki::cfg{Plugins}{PerlPlugin}{Opcodes}{Deny} } );
        }

        # Import symbols from Foswiki::Func
        if ( ref( $Foswiki::cfg{Plugins}{PerlPlugin}{Share} ) eq 'HASH' ) {
            while ( my ( $package, $symbols ) =
                each %{ $Foswiki::cfg{Plugins}{PerlPlugin}{Share} } )
            {
                $compartment->share_from( $package, $symbols );
            }
        }
    }

    # Permit floating point ops that may SIGFPE
    local $SIG{FPE} = sub {
        die "Floating point exception";
    };

    # Trap SIGALRM (process state will be undefined and we need to die, fast)
    local $SIG{ALRM} = sub {
        die "Alarm!";
    };

    # Override monkey-patched warn and die, specifically to
    # disable CGI::Carp which otherwise masks the errors because it
    # can't get to File::Spec
    my $result;
    $compartment->permit('print');
    $compartment->share_from( 'main', [ '*STDOUT', '*STDERR' ] );

    my $stdout = '';
    my $stderr = '';
    tie *STDERR, 'IO::Scalar', \$stderr;
    tie *STDOUT, 'IO::Scalar', \$stdout;

    {
        local $SIG{'__DIE__'}  = 'DEFAULT';
        local $SIG{'__WARN__'} = sub {
            my $mess = shift;
            $mess =~ s/ at \(eval \d+\)( line \d+.*)$/ at$1/;
            $stderr .= $mess;
        };

        $result = $compartment->reval( $expr, 1 );
    }
    untie *STDOUT;
    untie *STDERR;

    # The doc says a blocked opcode will set $@, but in perl 5.10 this
    # doesn't happen and reval just gives an undef. But this is what
    # should really trap errors.
    $result = "<pre class='foswikiAlert'>%PERL error: $@</pre>" if $@;
    $result = '' unless defined $result;
    if ( length($stdout) > 0 ) {
        $result .= $stdout;
    }
    if ( length($stderr) ) {
        $result .= "<pre class='foswikiAlert'>$stderr</pre>";
    }
    return $result;
}

1;
