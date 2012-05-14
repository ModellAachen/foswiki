# See end of file for license and copyright information
package Foswiki::Plugins::JQTablePlugin;

use strict;
use Assert;

use Foswiki::Func                  ();    # The plugins API
use Foswiki::Plugins               ();    # For the API version
use Foswiki::Plugins::JQueryPlugin ();

our $VERSION = '$Rev: 5771 $';
our $RELEASE = '1.1.2';
our $SHORTDESCRIPTION =
  'Javascript implementation of the classic TablePlugin, using JQuery';
our $NO_PREFS_IN_TOPIC = 1;
our $DEFAULT_TABLE_SETTINGS =
'tableborder="1" valign="top" headercolor="#fff" headerbg="#687684" headerbgsorted="#345" databg="#fff,#edf4f9" databgsorted="#f1f7fc,#ddebf6" tablerules="rows" headerrules="cols"';
our %pluginAttributes;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    Foswiki::Plugins::JQueryPlugin::registerPlugin( 'tablesorter',
        'Foswiki::Plugins::JQTablePlugin::TableSorter' );

    my $src = DEBUG() ? '.uncompressed' : '';
    my $sort = Foswiki::Func::getPreferencesValue('TABLEPLUGIN_SORT') || 'all';

    if ( $sort =~ /^(all|attachments)/ ) {

        # In this special case, the tablesorter is always required
        Foswiki::Plugins::JQueryPlugin::createPlugin('tablesorter');
        Foswiki::Func::addToZone( 'head', 'JQTABLEPLUGIN::SORT', <<HERE);
<meta name="foswiki.JQTablePlugin.sort" content="$sort" />
HERE
    }

    # if the TablePlugin isn't there to handle table formatting, then
    # enable JS to do it.
    if ( !$Foswiki::cfg{Plugins}{TablePlugin}{Enabled} ) {
        Foswiki::Func::registerTagHandler( 'TABLE', \&_TABLE );
    }
    return 1;
}

sub _TABLE {
    my ( $session, $params, $topic, $web ) = @_;

    Foswiki::Plugins::JQueryPlugin::createPlugin('tablesorter');

    _readPluginSettings() if !%pluginAttributes;
    my %p = %pluginAttributes;
    while ( my ( $k, $v ) = each %$params ) {
        next if $k =~ /^_/ && $k ne '_DEFAULT';
        $p{$k} = $v;
    }
    return CGI::div(
        {
            class => 'jqtp_process',
            style => 'display:none',

            # Note: manual JSON generator, due to amazing slowness
            # of CPAN JSON module
            title => join( ',', map { "'$_':'$p{$_}'" } keys %p ),
        },
        ''
    );
}

# Copied from TablePlugin
sub _readPluginSettings {
    my $configureAttrStr =
      $Foswiki::cfg{Plugins}{TablePlugin}{DefaultAttributes};
    my $pluginAttrStr =
      Foswiki::Func::getPreferencesValue('TABLEPLUGIN_TABLEATTRIBUTES');

    $configureAttrStr ||= $DEFAULT_TABLE_SETTINGS;

    $configureAttrStr = Foswiki::Func::expandCommonVariables($configureAttrStr)
      if $configureAttrStr;
    $pluginAttrStr = Foswiki::Func::expandCommonVariables($pluginAttrStr)
      if $pluginAttrStr;

    my %configureParams = Foswiki::Func::extractParameters($configureAttrStr);
    my %pluginParams    = Foswiki::Func::extractParameters($pluginAttrStr);

    %pluginAttributes = ( %configureParams, %pluginParams );
}

1;
__END__
Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/

JQTablePlugin is copyright (C) Crawford Currie http://c-dot.co.uk

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

For licensing info read LICENSE file in the root of this distribution.
