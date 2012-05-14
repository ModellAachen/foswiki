# Plugin for Foswiki Collaboration Platform, http://foswiki.org/
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

=pod

---+ package Foswiki::Plugins::DebugLogPlugin


=cut

package Foswiki::Plugins::DebugLogPlugin;
use strict;

require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version

use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC
  $Current_topic $Current_web $Current_user $installWeb);

$VERSION           = '$Rev: 7777 (27 Oct 2010) $';
$RELEASE           = '2.0';
$SHORTDESCRIPTION  = 'Detailed Debug logging for Foswiki';
$NO_PREFS_IN_TOPIC = 1;
$pluginName        = 'DebugLogPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in


=cut

sub initPlugin {
    ( $Current_topic, $Current_web, $Current_user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    if ( my $method = Foswiki::Func::getCgiQuery()->request_method() ) {
        writeLog($method)
          if (  ( $Foswiki::cfg{DebugLogPlugin}{LogPOST} )
            and ( $method eq 'POST' ) );
        writeLog($method)
          if (  ( $Foswiki::cfg{DebugLogPlugin}{LogGET} )
            and ( $method eq 'GET' ) );
    }

    my $setting = $Foswiki::cfg{Plugins}{DebugLogPlugin}{ExampleSetting} || 0;
    $debug = $Foswiki::cfg{Plugins}{DebugLogPlugin}{Debug} || 0;

    # Plugin correctly initialized
    return 1;
}

#TODO: need to extract and abstract so I cna write  DBI, Syslog, Foswiki::Logger, MongoDB 'writers'
sub writeLog {
    my $logtype = shift || 'topic';
    my $text = shift
      ;  #this is actually a hash whenever possible - like Monitor::monitorMacro

#totally non-blocking tick - one file per foswiki op - will scale up to the point where there are too many
#requests for the FS to deal with
    my $dir    = Foswiki::Func::getWorkArea( ${pluginName} );
    my $script = Foswiki::Func::getCgiQuery()->action();

    #TODO: use Foswiki session id's if available
    my $session = Foswiki::Func::getCgiQuery()->remote_addr();
    $session =~ /^(.*)$/; #i really don't know why CGI does not intaint this one
    $session = $1;

    my $file = join(
        '-',
        (
            $logtype, $script,
            $Current_web . '.' . $Current_topic,
            $Current_user,
            $session,
            Foswiki::Func::formatTime(
                time(), '$ye:$mo:$day:$hours:$minutes:$seconds', 'gmtime'
            ),
            rand()
        )
    );
    my $tickfile = $dir . '/' . $file;

    Foswiki::Func::writeDebug("$tickfile") if $debug;

    $tickfile =~
      /^(.*)$/;    #TODO: need to remove this and untaint at the right source
    $tickfile = $1;

    open( TICK, '>', $tickfile ) or warn "$!";
    Foswiki::Func::getCgiQuery()->save( \*TICK );    #save the CGI query params
    if ( defined($text) ) {
        print TICK "\n==============\n";
        if ( ref($text) eq 'HASH' ) {

       #as we're being more intellegent, we can also add a little more info here
            $text->{Store} = ();
            $text->{Store}{Implementation} =
              $Foswiki::cfg{Store}{Implementation};
            $text->{Store}{SearchAlgorithm} =
              $Foswiki::cfg{Store}{SearchAlgorithm};
            $text->{Store}{QueryAlgorithm} =
              $Foswiki::cfg{Store}{QueryAlgorithm};
            $text->{Store}{PrefsBackend} = $Foswiki::cfg{Store}{PrefsBackend};
            $text->{EnableHierarchicalWebs} =
              $Foswiki::cfg{EnableHierarchicalWebs};

            use Data::Dumper;
            print TICK 'HASH ' . Dumper($text);
        }
        elsif ( ref($text) eq 'ARRAY' ) {

            #boooo
            print TICK '| ' . join( ' | ', @$text ) . ' |';
        }
        else {

            #presume a string
            print TICK $text;
        }
        print TICK "\n==============\n";
    }
    close(TICK);
}

sub earlyInitPlugin {
    if (   ( $Foswiki::cfg{DebugLogPlugin}{RequestTimes} )
        or ( $Foswiki::cfg{DebugLogPlugin}{MonitorMacros} ) )
    {
        $ENV{FOSWIKI_MONITOR} = 1;
        require Monitor;
        Monitor::startMonitoring();
    }
    if ( $Foswiki::cfg{DebugLogPlugin}{MonitorMacros} ) {
        foreach my $tag ( keys( %{ $Foswiki::cfg{DebugLogPlugin}{Monitor} } ) )
        {
            Monitor::monitorMACRO( $tag,
                $Foswiki::cfg{DebugLogPlugin}{Monitor}{$tag}, \&writeLog );
        }
    }

    return undef;
}

=begin TML

---++ completePageHandler($html, $httpHeaders)

This handler is called on the ingredients of every page that is
output by the standard CGI scripts. It is designed primarily for use by
cache and security plugins.
   * =$html= - the body of the page (normally &lt;html>..$lt;/html>)
   * =$httpHeaders= - the HTTP headers. Note that the headers do not contain
     a =Content-length=. That will be computed and added immediately before
     the page is actually written. This is a string, which must end in \n\n.

*Since:* Foswiki::Plugins::VERSION 2.0

=cut

sub completePageHandler {

    #    my( $html, $httpHeaders ) = @_;
    #    # modify $_[0] or $_[1] if you must change the HTML or headers
    #    # You can work on $html and $httpHeaders in place by using the
    #    # special perl variables $_[0] and $_[1]. These allow you to operate
    #    # on parameters as if they were passed by reference; for example:
    #    # $_[0] =~ s/SpecialString/my alternative/ge;
    if (   ( $Foswiki::cfg{DebugLogPlugin}{RequestTimes} )
        or ( $Foswiki::cfg{DebugLogPlugin}{MonitorMacros} ) )
    {
        my $times = Monitor::getRunTimeSoFar();
        $Foswiki::Plugins::SESSION->{response}
          ->pushHeader( 'X-Foswiki-Monitor-DebugLogPlugin-Rendertime', $times );
    }
}

sub mergeHandler {

    #my ($diff, $old, $new, $infoRef) = @_;

    if ( $Foswiki::cfg{DebugLogPlugin}{LogMerge} ) {
        use Data::Dumper;
        writeTEXT( 'merge', Dumper(@_) );
    }
}

1;
