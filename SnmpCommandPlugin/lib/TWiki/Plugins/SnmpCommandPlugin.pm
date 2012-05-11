# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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
# =========================
#
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see %SYSTEMWEB%.Plugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   earlyInitPlugin         ( )                                     1.020
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   beforeCommonTagsHandler ( $text, $topic, $web )                 1.024
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   afterCommonTagsHandler  ( $text, $topic, $web )                 1.024
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   afterSaveHandler        ( $text, $topic, $web, $errors )        1.020
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional.
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

# =========================
package TWiki::Plugins::SnmpCommandPlugin;

# =========================

# not really required:
eval { use HTML::Entities 'encode_entities'; };

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $PATH
  %defaults @renderedOptions %options $defaultsInitialized
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE    = 'Dakar';
$pluginName = 'SnmpCommandPlugin';    # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG");

    $defaultsInitialized = 0;

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;

    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    $_[0] =~ s/%SNMPCOMMAND%/&handleSnmpCommand("", $_[0], $_[1], $_[2])/ge;
    $_[0] =~
      s/%SNMPCOMMAND{(.*?)}%/&handleSnmpCommand($1, $_[0], $_[1], $_[2])/ge;

}

# =========================
sub initDefaults() {
    my $webbgcolor = &TWiki::Func::getPreferencesValue( "WEBBGCOLOR", $web )
      || 'white';
    %defaults = (
        cmdpath => '/usr/local/bin',    # path for snmp commands
        method  => 'walk',              # method to query snmpd
        host    => 'localhost',         # host to query
        oid     => '.1.3.6.1.2.1.1',    # only query the system tree
        version => 1,                   # the version to query 1,2c or 3
        port    => 161,                 # snmp port number
        comm    => 'public',            # community string
        outopts =>
          's',    # output arguments changed with V5 use s for V4 and Qs for V5.
        tablecaption     => undef,            # table caption
        cellpadding      => 1,                # table cellpadding
        cellspacing      => 0,                # table cellspacing
        border           => 1,                # table border
        topic            => "$web.$topic",    # topic with calendar entries
        tableheadercolor => $webbgcolor,      # table header color
        tablebgcolor     => 'white',          # table background color
        tablecaptionalign =>
          'top'    # table caption alignment (top|bottom|left|right)
    );
}

# =========================
sub initOptions() {
    my ($attributes) = @_;

# Setup options (attributes>plugin preferences>defaults) and render some options:
    foreach $option ( keys %defaults ) {
        $v = &TWiki::Func::extractNameValuePair( $attributes, $option )
          || undef;
        if ( defined $v ) {
            $options{$option} = $v;
        }
        else {
            $v = TWiki::Func::getPluginPreferencesValue("\U$option\E") || undef;
            $options{$option} = ( defined $v ) ? $v : $defaults{$option};
        }

        if ( grep( /^\Q$option\E$/, @renderedOptions ) ) {
            $options{$option} =
              &TWiki::Func::renderText( $options{$option}, $web );
        }
    }

    # set path based on location of snmp commands
    $PATH        = $ENV{'PATH'};
    $PATH        = $options{cmdpath} . ":" . $PATH;
    $ENV{'PATH'} = $PATH;
}

# =========================
sub handleSnmpCommand() {
    ( $attributes, $refText, $theTopic, $theWeb ) = @_;

    &initDefaults() unless $defaultsInitialized;

    &initOptions($attributes);

    return &renderSnmpOutput;
}

# =========================
sub renderSnmpOutput() {

    my $text = "";
    $text .= "<h4>"
      . $options{host} . " "
      . $options{method} . " "
      . $options{oid} . "</h4>";
    $text .=
        '<noautolink><table border="'
      . $options{border} . '"'
      . ' cellpadding="'
      . $options{cellpadding} . '"'
      . ' cellspacing="'
      . $options{cellspacing} . '"'
      . ' bgcolor="'
      . $options{tablebgcolor} . '"' . '>' . "\n";

    $text .=
        '<caption align="'
      . $options{tablecaptionalign}
      . '"><noautolink>'
      . $options{tablecaption}
      . '</noautolink></caption>' . "\n";

    my @snmp_out = ();
    if ( $options{method} eq 'table' ) {
        @snmp_out = &table(
            $options{host},    $options{oid},  $options{comm},
            $options{version}, $options{port}, $options{outopts}
        );

        my $ind = 0;
        foreach $line (@snmp_out) {
            chomp($line);

            #check for errors
            if ( $line =~ /Timeout/ ) {
                $text .=
                  "<tr><td>$line</td> <td>Check the community string </td>\n";
                last;
            }
            elsif ( $line =~ /End of MIB/ ) {
                $text .=
"<tr><td>$line</td> <td>OID may not exist or is protected</td>\n";
            }
            elsif ( $line =~ /Unknown host/ ) {
                $text .=
                  "<tr><td>$line</td> <td>Check the name of the device</td>\n";
            }
            elsif ( $line =~ /No entries/ ) {
                $text .=
"<tr><td>$line</td> <td>MIB may not be defined on host</td>\n";
            }
            if ( $line !~ /=/ ) {
                next;
            }
            if ( $ind == 0 ) {
                $text .= '<tr bgcolor="' . $options{tableheadercolor} . '">';
            }
            else {
                $text .= '<tr>';
            }
            @fields = split( /=/, $line );
            foreach $f (@fields) {
                if ( $ind == 0 ) {
                    $text .= "<th><font size='-2'>$f</font></th>";
                }
                else {
                    $text .= "<td>$f</td>";
                }
            }
            $ind++;
        }
        $text .= "</table>";
    }
    else {
        $text .= "<th>Object Name</th><th>Object Value</th>";
        if ( $options{method} eq 'get' ) {
            @snmp_out = &get(
                $options{host},    $options{oid},  $options{comm},
                $options{version}, $options{port}, $options{outopts}
            );
        }
        else {
            @snmp_out = &walk(
                $options{host},    $options{oid},  $options{comm},
                $options{version}, $options{port}, $options{outopts}
            );
        }

        foreach $line (@snmp_out) {
            chomp($line);

            #check for errors
            if ( $line =~ /Timeout/ ) {
                $text .=
                  "<tr><td>$line</td> <td>Check the community string </td>\n";
                last;
            }
            elsif ( $line =~ /End of MIB/ ) {
                $text .=
"<tr><td>$line</td> <td>OID may not exist or is protected</td>\n";
            }
            elsif ( $line =~ /Unknown host/ ) {
                $text .=
                  "<tr><td>$line</td> <td>Check the name of the device</td>\n";
            }
            else {
                my @fields = split( /=/, $line );
                $text .= "<tr><td>$fields[0]</td><td>$fields[1]</td>";
            }
        }
        $text .= "</table>";
    }
    return ($text);
}

# =========================

sub walk() {
    my ( $host, $oid, $comm, $version, $port, $outopts ) = @_;
    my $commandline =
        "snmpwalk -v " 
      . $version . " -c " 
      . $comm . " -O" 
      . $outopts . " "
      . $host . ":"
      . $port . " "
      . $oid;
    my @snmp_output = ();
    open( SNMPOUTPUT, "$commandline  2>&1 |" );
    @snmp_output = <SNMPOUTPUT>;
    close(SNMPOUTPUT);
    return (@snmp_output);
}

sub get() {
    my ( $host, $oid, $comm, $version, $port, $outopts ) = @_;
    my $commandline =
        "snmpget -v " 
      . $version . " -c " 
      . $comm . " -O" 
      . $outopts . " " 
      . $host . ":"
      . $port . " "
      . $oid;
    my @snmp_output = ();
    open( SNMPOUTPUT, "$commandline  2>&1 |" );
    @snmp_output = <SNMPOUTPUT>;
    close(SNMPOUTPUT);
    return (@snmp_output);
}

sub table() {
    my ( $host, $oid, $comm, $version, $port, $outopts ) = @_;
    my $commandline =
        "snmptable -v " 
      . $version . " -c " 
      . $comm
      . " -Cf = "
      . $host . ":"
      . $port . " "
      . $oid;
    my @snmp_output = ();
    open( SNMPOUTPUT, "$commandline  2>&1 |" );
    @snmp_output = <SNMPOUTPUT>;
    close(SNMPOUTPUT);
    return (@snmp_output);
}

sub translate() {
    my ( $host, $oid, $comm, $version, $port, $outopts ) = @_;
    my $commandline =
        "snmptable -v " 
      . $version . " -c " 
      . $comm
      . " -Cf = "
      . $host . ":"
      . $port . " "
      . $oid;
    my @snmp_output = ();
    open( SNMPOUTPUT, "$commandline  2>&1 |" );
    @snmp_output = <SNMPOUTPUT>;
    close(SNMPOUTPUT);
    return (@snmp_output);
}

1;
