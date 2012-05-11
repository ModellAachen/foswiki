
# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

=pod

---+ package AccessStatsPlugin

=cut

# change the package name and $pluginName!!!
package TWiki::Plugins::AccessStatsPlugin;

use Compress::Zlib;

#use Benchmark;

# Always use strict to enforce variable scoping
use strict;
use warnings;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars
  qw( $VERSION $RELEASE $debug $pluginName $accessLogFileName $accessLogDirectory $disableDefaultParam);

# This should always be $Rev: 8713$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 8713$';

#$VERSION = 'v1.002';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '9 Apr 2007';

# Name of this Plugin, only used in this module
$pluginName = 'AccessStatsPlugin';

# The Apache access log file name
$accessLogFileName = "access.log";

# The Apache access log directory
$accessLogDirectory = "/var/log/apache2/";

# Set to 1 to disable the _DEFAULT parameter and thus restrict the scope...
# ... of the search to the TWiki installation directory
#Comment out if you want to enable _DEFAULT parameter
#$disableDefaultParam=1;

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

REQUIRED

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using TWiki::Func::writeWarning and return 0. In this case
%FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

You may also call =TWiki::Func::registerTagHandler= here to register
a function to handle tags that have standard TWiki syntax - for example,
=%MYTAG{"my param" myarg="My Arg"}%. You can also override internal
TWiki tag handling functions this way, though this practice is unsupported
and highly dangerous!

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin preferences, variables defined by:
    $debug = TWiki::Func::getPreferencesValue("\U$pluginName\E_DEBUG");
    $debug ||= 0;    # make sure it has a value

    # register ACCESSSTATS tag
    TWiki::Func::registerTagHandler( 'ACCESSSTATS', \&_ACCESSSTATS );

    # Allow a sub to be called from the REST interface
    # using the provided alias
    #TWiki::Func::registerRESTHandler('example', \&restExample);

    # Plugin correctly initialized
    return 1;
}

# The function used to handle the %ACCESSSTATS{["regexp"]}% tag
# You would have one of these for each tag you want to process.
sub _ACCESSSTATS {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    # $session  - a reference to the TWiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a TWiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the tag

    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # $params->{sideorder} will be 'onions'

#load up the Apache Access log file
#could this be done only once per page rendering? We would need global variable though... or is there nay other way?
    my @lines = ();
    getAccessLogLines( \@lines );
    TWiki::Func::writeDebug("$pluginName: Line count : $#lines") if ($debug);

    #Check if we have default param
    my $default = "";
    if ( $params->{_DEFAULT} ) {

        #Check if default parameter is allowed
        if ($disableDefaultParam) {
            return
"*\%RED%$pluginName ERROR*: Default parameter is disabled! Only server admin can enable that feature for you!\%ENDCOLOR%";
        }

        #Default param must be a regexp
        $default = $params->{_DEFAULT};

#None of the web, topic and attachment parameter should be specified along with default parameter
        if ( $params->{web} || $params->{topic} || $params->{attachment} ) {
            return
"*\%RED%$pluginName ERROR*: Inconsistent parameter list!\%ENDCOLOR%";
        }
    }
    elsif ( $params->{attachment} ) {

        #Access statistics for attachment
        if ( $params->{web} && $params->{topic} ) {
            $default =
              getRegExpForAttachment( $params->{web}, $params->{topic},
                $params->{attachment} );
        }
        elsif ( $params->{topic} ) {

            #Verbose Debug
            TWiki::Func::writeDebug("$pluginName: Web: $theWeb") if ($debug);
            TWiki::Func::writeDebug("$pluginName: Topic: $params->{topic}")
              if ($debug);
            TWiki::Func::writeDebug(
                "$pluginName: Attachment: $params->{attachment}")
              if ($debug);
            $default =
              getRegExpForAttachment( $theWeb, $params->{topic},
                $params->{attachment} );
        }
        elsif ( $params->{web} ) {

  #specifying attachment and web parameter only does not make sense! Or does it?
            return
"*\%RED%$pluginName ERROR*: Inconsistent parameter list!\%ENDCOLOR%";
        }
        else {
            $default =
              getRegExpForAttachment( $theWeb, $theTopic,
                $params->{attachment} );
        }
    }
    elsif ( $params->{web} && $params->{topic} ) {

        #No regexp provided just build one based on provided web and topic
        $default = getRegExp( $params->{web}, $params->{topic} );
    }
    elsif ( $params->{topic} ) {

#No regexp and no web provided just build a regexp based on current web provided topic
        $default = getRegExp( $theWeb, $params->{topic} );
    }
    elsif ( $params->{web} ) {

        #specifying web parameter only does not make sense! Or does it?
        return
          "*\%RED%$pluginName ERROR*: Inconsistent parameter list!\%ENDCOLOR%";

       #No regexp and no topic provided just build a regexp based on current web
       #$default=getRegExp($params->{web},$params->{topic});
    }
    else {

        #No default parameter specified, set it to the current page
        $default = getRegExp( $theWeb, $theTopic );

#Verbose Debug
#TWiki::Func::writeDebug("$pluginName: Host: $host") if($debug);
#TWiki::Func::writeDebug("$pluginName: Query: $query") if($debug);
#TWiki::Func::writeDebug("$pluginName: NoHostQuery: $queryWithoutHost") if($debug);
    }

    #Output some debug info
    TWiki::Func::writeDebug("$pluginName: RegExp: $default") if ($debug);

    #compile our regular expression for optimisation
    my $regexp = qr/$default/i;

    my $matchCount = 0;
    my $line;
    foreach $line (@lines) {
        if ( $line =~ /$regexp/ ) {

            #unless ($line =~ /$exclude/)
            #    {
            $matchCount++;

            #$body.="$line<br />";
            #    }
        }
    }
    $_[0] = "$matchCount";    #"$params->{regex}"."$params->{_DEFAULT}";

}

=pod

---++ getRegExp($theWeb,$theTopic)

Returns the default regexp to search the Apache access log file with.

=cut

sub getRegExp {
    my ( $theWeb, $theTopic ) = @_;
    my $host = TWiki::Func::getUrlHost();
    my $query = TWiki::Func::getViewUrl( $theWeb, $theTopic );
    $query =~ /$host(.*)/;
    my $queryWithoutHost = $1;
    $_[0] = 'GET\s' . $queryWithoutHost . '.+HTTP/1.1.+\s200\s';
}

=pod

---++ getRegExpForAttachment($theWeb,$theTopic,$theAttachment)

Returns the default regexp to search the Apache access log file with.

=cut

sub getRegExpForAttachment {

    #Get preferences from the plugin page
    #my $debug = TWiki::Func::getPreferencesValue( "\U$pluginName\E_DEBUG" );

    my ( $theWeb, $theTopic, $theAttachment ) = @_;
    my $query =
      TWiki::Func::getPubUrlPath() . "/$theWeb/$theTopic/$theAttachment";
    $_[0] = 'GET\s' . $query . '.+HTTP/1.1.+\s200\s';
}

=pod

---++ getAccessLogLines(\@lines)

Returns the access log lines in the first parameter.
Access log lines are a concatenation of multiple access log gz files and the current access log file

=cut

sub getAccessLogLines {
    my $linesRef = $_[0];
    my @lines    = ();

    opendir( DIR, $accessLogDirectory )
      || die "Can't opendir $accessLogDirectory: $!";
    my @accessLogGz;
    @accessLogGz =
      grep { /^$accessLogFileName.+\.gz/ && -f "$accessLogDirectory/$_" }
      readdir(DIR);

    #for each gz file in the directory matching our patern
    foreach (@accessLogGz) {
        TWiki::Func::writeDebug("GZ log file :$_") if $debug;
        my $gz = gzopen( "$accessLogDirectory/$_", "rb" )
          or die "Cannot open $accessLogDirectory/$_: $gzerrno\n";
        while ( $gz->gzreadline($_) > 0 ) {
            push( @$linesRef, $_ );
        }
        $gz->gzclose();
    }
    closedir DIR;

    opendir( DIR, $accessLogDirectory )
      || die "Can't opendir $accessLogDirectory: $!";
    my @accessLogN;
    @accessLogN =
      grep { /^$accessLogFileName\.\d+$/ && -f "$accessLogDirectory/$_" }
      readdir(DIR);

    #for each access.log.n file in the directory
    foreach (@accessLogN) {
        TWiki::Func::writeDebug("n log file: $_") if $debug;
        open ACCESSLOG, "< $accessLogDirectory$_"
          or die "Cannot open $accessLogDirectory/$_\n";
        push( @$linesRef, <ACCESSLOG> );
        close ACCESSLOG;
    }

    closedir DIR;

    open ACCESSLOG, "< $accessLogDirectory$accessLogFileName"
      or die "Can't open $accessLogFileName: $!";
    push( @$linesRef, <ACCESSLOG> );
    close ACCESSLOG;

    #TWiki::Func::writeDebug("Count: $#lines");
    #TWiki::Func::writeDebug("Count in param: $#$linesRef");
}

