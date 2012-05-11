# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004 Cole Beck, cole.beck@vanderbilt.edu
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
# This is the EFetchPlugin.  It utilizes the EFetch tool from Entrez
# with PubMed to lookup abstract information.
# See http://eutils.ncbi.nlm.nih.gov/entrez/query/static/eutils_help.html
#
# Thanks to FEH and JRH
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
# =========================
package TWiki::Plugins::EFetchPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $doOldInclude $renderingWeb
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'EFetchPlugin';    # Name of this Plugin
use LWP::Simple;

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin preferences
    $doOldInclude =
      TWiki::Func::getPreferencesFlag("\U$pluginName\E_OLDINCLUDE") || "";

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    $renderingWeb = $web;

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

    # for compatibility for earlier TWiki versions:
    if ($doOldInclude) {

        # allow two level includes
        $_[0] =~
s/%INCLUDE:"([^%\"]*?)"%/TWiki::handleIncludeFile( $1, $_[1], $_[2], "" )/geo;
        $_[0] =~
s/%INCLUDE:"([^%\"]*?)"%/TWiki::handleIncludeFile( $1, $_[1], $_[2], "" )/geo;
    }

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;
    $_[0] =~ s/%PMID{([0-9]{1,9}?)}%/&fetch($1)/ge;
    $_[0] =~ s/%PMIDL{(.*?)}%/&link($1)/ge;
    $_[0] =~ s/%PMIDC{([0-9]{1,9}?)}%/&citelink($1)/ge;
}

# =========================
sub fetch {
    my $pmid    = $_[0];
    my $results = get(
"http://www.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?rettype=abstract&retmode=text&db=pubmed&id=$pmid"
    );
    return "<pre>" . $results . "</pre>";
}

# ========================
sub link {
    my ($theAttributes) = @_;
    my $pmid = &TWiki::Func::extractNameValuePair( $theAttributes, "pmid" );
    my $link = &TWiki::Func::extractNameValuePair( $theAttributes, "name" );
    $pmid = $_[0] if $pmid eq '';
    return '' if $pmid eq '';
    $link = $pmid if $link eq '';
    my $results =
"[[http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=pubmed&dopt=Abstract&list_uids=$pmid][$link]]";
    return $results;
}

# =========================
sub citelink {
    my $pmid    = $_[0];
    my $results = get(
"http://www.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?rettype=medline&retmode=text&db=pubmed&id=$pmid"
    );

    #create an array for each line
    @string = split /\n/, $results;
    $pcmd = '';

  #initialize empty arrays (otherwise multiple calls will keep appending values)
    $rec->{'AU'} = [];
    $rec->{'TI'} = [];
    $rec->{'SO'} = [];

    #go through each line
    for ( $i = 0 ; $i < @string ; $i++ ) {
        next if $string[$i] =~ /^\s*$/o;

        #store the first six characters
        $cmd = substr $string[$i], 0, 6;
        if ( $cmd =~ /-/ ) {

            #remove spaces and -'s
            $cmd =~ s/ *-.*//o;

            #then store the key
            $pcmd = $cmd;
        }

        #create the key in the array if it does not exist
        if ( !exists $rec->{$pcmd} ) {
            $rec->{$pcmd} = [];
        }

        #add the rest of the line to the array for the specified key
        push @{ $rec->{$pcmd} }, substr( $string[$i], 6 );
    }
    $au = $ti = $so = '';
    if ( exists $rec->{'AU'} ) {
        $au = join( ', ', @{ $rec->{'AU'} } );
    }
    if ( exists $rec->{'TI'} ) {
        $ti = join( ' ', @{ $rec->{'TI'} } );
    }
    if ( exists $rec->{'SO'} ) {
        $so = join( ' ', @{ $rec->{'SO'} } );
    }
    $link =
"[[http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=pubmed&dopt=Abstract&list_uids=$pmid][$ti]]";
    return $au . ".&nbsp;&nbsp;" . $link . "&nbsp;&nbsp;" . $so;
}

# =========================

1;
