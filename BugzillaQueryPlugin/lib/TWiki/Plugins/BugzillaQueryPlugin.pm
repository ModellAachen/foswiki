# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
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
package TWiki::Plugins::BugzillaQueryPlugin
  ;    # change the package name and $pluginName!!!

use DBI;

# =========================
use vars qw( $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $url $showBugScript $bugListScript $dbHost $dbPort $dbName $dbUser $dbPasswd );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = "BugzillaQueryPlugin";    # Name of this Plugin

# HERE YOU HAVE TO SPECIFY THE MYSQL CREDENTIALS
# BECAUSE OF PLAIN TEXT FORMAT YOU SHOULD CREATE NEW USER WHO HAS ONLY READ-ONLY ACCESS TO DATABASE

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");
    $url   = TWiki::Func::getPreferencesValue("\U$pluginName\E_URL");
    if ( $url eq "" ) {
        TWiki::Func::writeWarning(
            "You have to set up URL variable in BugzillaQueryPlugin topic");
        return 0;
    }
    if ( $url =~ /\/$/ ) { $url =~ s/(.*?)\/$/$1/; }
    $showBugScript =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_SHOWBUGSCRIPT")
      || "show_bug.cgi";
    $bugListScript =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_BUGLISTSCRIPT")
      || "buglist.cgi";

    $dbHost =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_BUGZILLA_DB_HOST")
      || "";    # MySQL database host name
    $dbPort =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_BUGZILLA_DB_PORT")
      || "";    # MySQL database port number
    $dbName =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_BUGZILLA_DB_NAME")
      || "bugs";    # MySQL database name
    $dbUser = TWiki::Func::getPreferencesValue("\U$pluginName\E_BUGZILLA_USER")
      || "guest"
      ; # MySQL user who has access to $dbName database (read-only access is the best :-)))
    $dbPasswd =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_BUGZILLA_PASSWD")
      || "";    # password for $dbUser

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
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    $_[0] =~ s/%BGQ[{\[](.*?)[}\]]%/&handleBugzillaQuery($1)/ge;
}

# =========================

sub handleBugzillaQuery {
    my ($text)    = @_;
    my $anonymous = "";
    my $format    = TWiki::Func::getPreferencesValue("\U$pluginName\E_FORMAT")
      || "| \$bug_id | \$bug_severity | \$priority | \$bug_status | \$reporter | \$product |";
    my $dataView = 0;

    my %params;
    $anonymous = $1 if ( $text =~ s/^[\"\'](.*?)[\"\']// );
    $dataView  = 1  if ( $text =~ s/data=[\"\']on[\"\']// );
    $format    = $1 if ( $text =~ s/format=[\"\'](.*?)[\"\']// );

    while ( $text =~ s/\s*(.*?)\=[\"\'](.*?)[\"\']// ) {
        $params{$1} = $2;
    }
    if ( ( $anonymous ne "" ) && !defined( $params{"bug_id"} ) ) {
        $params{"bug_id"} = $anonymous;
    }

    if ( $dataView == 1 ) {
        my $db = openDB();
        $statement = "SELECT * FROM bugs";
        my @keys = keys %params;
        $statement .= ", keyworddefs, keywords" if ( grep( /keyword/, @keys ) );
        $statement .= " WHERE " if ( $#keys > -1 );
        my $i = 0;
        while ( ( $key, $value ) = each %params ) {
            my $j = 0;
            $statement .=
"bugs.bug_id = keywords.bug_id AND keywords.keywordid = keyworddefs.id AND "
              if ( $key eq "keyword" );
            @tmp = makeArray($value);
            $statement .= "( " if ( $#tmp > 0 );
            foreach my $tvalue (@tmp) {

                #EXCEPTIONS
                ( $tvalue, $key ) =
                  getField( "id", "products", "name", $tvalue, "product_id" )
                  if ( $key eq "product" );
                ( $tvalue, $key ) =
                  getField( "id", "components", "name", $tvalue,
                    "component_id" )
                  if ( $key eq "component" );
                ( $tvalue, $key ) = getField(
                    "userid", "profiles", "login_name", $tvalue,
                    "qa_contact"
                ) if ( $key eq "qa_contact" );
                ( $tvalue, $key ) =
                  getField( "userid", "profiles", "login_name", $tvalue,
                    "reporter" )
                  if ( $key eq "reporter" );
                ( $tvalue, $key ) = getField(
                    "userid", "profiles", "login_name", $tvalue,
                    "assigned_to"
                ) if ( $key eq "assigned_to" );

                #EXCEPTIONS
                if ( $key eq "short_desc" ) {
                    $statement .= "bugs.$key REGEXP '$tvalue' ";
                }
                elsif ( $key eq "keyword" ) {
                    $statement .= "keyworddefs.name = '$tvalue' ";
                }
                else {
                    $statement .= "bugs.$key = '$tvalue' ";
                }
                $statement .= "OR " if ( ( $j >= 0 ) && ( $j < $#tmp ) );
                $j++;
            }
            $statement .= ") " if ( $#tmp > 0 );
            $statement .= "AND " if ( ( $i >= 0 ) && ( $i < $#keys ) );
            $i++;
        }

        #&TWiki::Func::writeDebug( "ST = $statement" );
        my $tmp = $db->prepare($statement);
        $tmp->execute();
        my $result = "";
        while ( my $row = $tmp->fetchrow_hashref ) {
            my $s = $format;
            foreach my $field ( keys( %{$row} ) ) {
                my $value = $$row{$field};
                ( $value, $field ) =
                  getField( "name", "products", "id", $$row{$field}, "product" )
                  if ( $field eq "product_id" );
                ( $value, $field ) =
                  getField( "name", "components", "id", $$row{$field},
                    "component" )
                  if ( $field eq "component_id" );
                ( $value, $field ) = getField(
                    "login_name", "profiles", "userid", $$row{$field},
                    "qa_contact"
                ) if ( $field eq "qa_contact" );
                ( $value, $field ) = getField(
                    "login_name", "profiles", "userid", $$row{$field},
                    "reporter"
                ) if ( $field eq "reporter" );
                ( $value, $field ) = getField(
                    "login_name", "profiles",
                    "userid",     $$row{$field},
                    "assigned_to"
                ) if ( $field eq "assigned_to" );
                $s =~
s/\$bug_id/<a href=\"$url\/$showBugScript?id=$value\">$value<\/a>/g
                  if ( $field eq "bug_id" );
                $s =~ s/\$$field/$value/g;
            }
            $result .= "$s\n";
        }
        $db->disconnect;
        return $result;
    }
    else {
        if ( defined( $params{'bug_id'} ) ) {
            @tmp = makeArray( $params{'bug_id'} );
            if ( $#tmp < 1 ) {
                return "$url/$showBugScript?id=$tmp[0]";
            }
            else {
                return addArray( "$url/$bugListScript?", "bug_id", @tmp );
            }
        }
    }
    my $result = "$url/$bugListScript?";
    my $num    = 1;
    while ( ( $key, $value ) = each %params ) {
        my $solved = 0;
        ( $result, $solved ) =
          addEmail( $result, $value, "assigned_to", "substring", $num++ )
          if ( $key eq "assigned_to" );
        ( $result, $solved ) =
          addEmail( $result, $value, "reporter", "substring", $num++ )
          if ( $key eq "reporter" );
        ( $result, $solved ) =
          addEmail( $result, $value, "qa_contact", "substring", $num++ )
          if ( $key eq "qa_contact" );
        ( $result, $solved ) =
          addEmail( $result, $value, "cc", "substring", $num++ )
          if ( $key eq "cc" );
        ( $result, $solved ) =
          addEmail( $result, $value, "longdesc", "substring", $num++ )
          if ( $key eq "longdesc" );
        $result = addArray( $result, $key, makeArray($value) ) if ( !$solved );
    }
    return $result . "order=Reuse+same+sort+as+last+time";
}

sub getField {
    my ( $what, $table, $field, $value, $key ) = @_;
    $db = openDB();
    my $statement = "SELECT $what FROM $table WHERE $field = '$value'";
    my $tmp       = $db->prepare($statement);
    $tmp->execute();
    my @row = $tmp->fetchrow_array();
    $tmp->finish;
    $db->disconnect();
    return ( $row[0], $key );
}

sub openDB {
    my $host = "";
    $host .= ";host=$dbHost" if ( $dbHost ne "" );
    $host .= ";port=$dbPort" if ( $dbPort ne "" );
    my $db =
      DBI->connect( "DBI:mysql:$dbName$host", $dbUser, $dbPasswd,
        { PrintError => 1, RaiseError => 0 } );
    if ( !$db ) {
        die "ERROR!! Not possible to connect database!!";
    }
    return $db;
}

sub makeArray {
    my ($str) = @_;
    $str =~ s/\s//g;
    return split( /,/, $str );
}

sub addArray {
    my ( $text, $field, @arr ) = @_;
    foreach my $tmp (@arr) {
        $text .= "$field=$tmp&";
    }
    return $text;
}

sub addEmail {
    my ( $text, $email, $what, $type, $num ) = @_;
    $text .= "email$num=$email&emailtype$num=$type&email$what$num=1&";
    return ( $text, 1 );
}

1;
