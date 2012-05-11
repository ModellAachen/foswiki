# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2010 Sven Dowideit SvenDowideit@fosiki.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#

=pod

---+ package ComponentEditPlugin

By default it will pop up a floating div window containing a simple textarea, but in combination with registered tag syntax, can generate tag specific UI's (!%SEARCH% is the demo example)

The tag specific UI's require a round trip to the server, but the default can be used without.

=cut

use strict;

package Foswiki::Plugins::ComponentEditPlugin;

use Foswiki::Attrs;
use CGI;
use HTML::Entities;

use vars
  qw( $VERSION $pluginName $debug  $currentWeb %vars %sectionIds $templateText $WEB $TOPIC %syntax);

$VERSION    = '0.100';
$pluginName = 'ComponentEditPlugin';    # Name of this Plugin

my %syntax = (
    GROUPINFO => {
        DOCUMENTATION => {
            type  => 'DOCCO',
            DOCCO => 'retrieve details about a Group'
        },
        _DEFAULT => {
            type             => 'text',
            defaultparameter => 1,
            default          => '',
            DOCCO =>
'If the groupname is specified, GROUPINFO returns a comma-separated list of users in that group, if its empty, a comma-separated list of all groups '
        },
        header => {
            type    => 'text',
            default => '',
            DOCCO =>
'Custom format results: see FormattedSearch for usage, variables & examples'
        },
        format => {
            type    => 'text',
            default => '',
            DOCCO =>
              '• $name expands to the group name, and (for users list only)
• $wikiname, $username and $wikiusername to the relevant strings.
• $allowschange returns 0 (false) or 1 (true) if that group can be modified by the current user.
• $allowschange(UserWikiName)'
        },
        footer => {
            type    => 'text',
            default => '',
            DOCCO =>
'Custom format results: see FormattedSearch for usage, variables & examples'
        },
        separator => {
            type    => 'text',
            default => '',
            DOCCO   => 'Line separator between hits'
        },
        limit => {
            type    => 'text',
            default => '',
            DOCCO =>
'Limit the number of results returned. This is done after sorting if order is specified'
        },
        limited => {
            type    => 'text',
            default => '',
            DOCCO =>
'If limit is set, and the list is truncated, this text will be added at the end of the list '
        },
    },
    SEARCH => {
        DOCUMENTATION => {
            type  => 'DOCCO',
            DOCCO => 'Inline search, shows a search result embedded in a topic'
        },
        search => {
            type             => 'text',
            defaultparameter => 1,
            default          => '',
            DOCCO =>
'Search term. Is a keyword search, literal search or regular expression search, depending on the type parameter. SearchHelp has more'
        },
        web => {
            type    => 'text',
            default => '',
            DOCCO =>
'Comma-separated list of webs to search. The special word all means all webs that doe not have the NOSEARCHALL variable set to on in their WebPreferences. You can specifically exclude webs from an all search using a minus sign - for example, web="all,-Secretweb".'
        },
        topic => {
            type    => 'text',
            default => '',
            DOCCO =>
'Limit search to topics: A topic, a topic with asterisk wildcards, or a list of topics separated by comma.'
        },
        excludetopic => {
            type    => 'text',
            default => '',
            DOCCO =>
'Exclude topics from search: A topic, a topic with asterisk wildcards, or a list of topics separated by comma.'
        },
        header => {
            type    => 'text',
            default => '',
            DOCCO =>
'Custom format results: see FormattedSearch for usage, variables & examples'
        },
        format => {
            type    => 'text',
            default => '',
            DOCCO =>
'Expand variables before applying a FormattedSearch on a search hit. Useful to show the expanded text, e.g. to show the result of a SpreadSheetPlugin %CALC{}% instead of the formula'
        },
        footer => {
            type    => 'text',
            default => '',
            DOCCO =>
'Custom format results: see FormattedSearch for usage, variables & examples'
        },
        separator => {
            type    => 'text',
            default => '',
            DOCCO   => 'Line separator between hits'
        },
        type => {
            type    => 'options',
            option  => [ 'keyword', 'literal', 'regex' ],
            default => '',
            DOCCO =>
'Do a keyword search like soap "web service" -shampoo; a literal search like web service; or RegularExpression search like soap;web service;!shampoo'
        },
        scope => {
            type    => 'options',
            option  => [ 'topic', 'text', 'all' ],
            default => 'text',
            DOCCO =>
'Search topic name (title); the text (body) of topic; or all (both)'
        },
        order => {
            type    => 'text',
            default => '',
            DOCCO =>
'Sort the results of search by the topic names, topic creation time, last modified time, last editor, or named field of DataForms. The sorting is done web by web; if you want to sort across webs, create a formatted table and sort it with TablePlugin\'s initsort. Note that dates are sorted most recent date last (i.e at the bottom of the table).'
        },
        limit => {
            type    => 'text',
            default => '',
            DOCCO =>
'Limit the number of results returned. This is done after sorting if order is specified'
        },
        date => {
            type    => 'text',
            default => '',
            DOCCO =>
'limits the results to those pages with latest edit time in the given TimeInterval.'
        },
        reverse => {
            type    => 'onoff',
            default => 'off',
            DOCCO   => 'Reverse the direction of the search'
        },
        casesensitive => {
            type    => 'onoff',
            default => 'off',
            DOCCO   => 'Case sensitive search'
        },
        bookview => {
            type    => 'onoff',
            default => 'off',
            DOCCO   => 'show complete topic text'
        },
        nosummary => {
            type    => 'onoff',
            default => 'off',
            DOCCO   => 'Show topic title only'
        },
        nosearch => {
            type    => 'onoff',
            default => 'off',
            DOCCO   => 'Suppress search string'
        },
        noheader => {
            type    => 'onoff',
            default => 'off',
            DOCCO   => 'Suppress search header '
        },
        nototal => {
            type    => 'onoff',
            default => 'off',
            DOCCO   => 'Do not show number of topics found'
        },
        zeroresults => {
            type    => 'onoff',
            default => 'off',
            DOCCO   => 'Suppress all output if there are no hits'
        },
        noempty => {
            type    => 'onoff',
            default => 'off',
            DOCCO   => 'Suppress results for webs that have no hits.'
        },
        expandvariables => {
            type    => 'onoff',
            default => 'off',
            DOCCO =>
'Expand variables before applying a FormattedSearch on a search hit. Useful to show the expanded text, e.g. to show the result of a SpreadSheetPlugin %CALC{}% instead of the formula'
        },
        multiple => {
            type    => 'onoff',
            default => 'off',
            DOCCO =>
'Multiple hits per topic. Each hit can be formatted. The last token is used in case of a regular expression ";" and search'
        },
        nofinalnewline => {
            type    => 'onoff',
            default => 'off',
            DOCCO =>
'If on, the search variable does not end in a line by itself. Any text continuing immediately after the search variable on the same line will be rendered as part of the table generated by the search, if appropriate.'
        },
        recurse => {
            type    => 'onoff',
            default => 'on',
            DOCCO   => 'Recurse into subwebs, if subwebs are enabled.'
        },
    }
);

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

not used for plugins specific functionality at present

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    Foswiki::Func::registerRESTHandler( 'getEdit', \&getEdit );

    $WEB          = $web;
    $TOPIC        = $topic;
    $templateText = '';

    # Plugin correctly initialized
    return 1;
}

#a rest method
sub getEdit {
    my ($session) = shift;
    my $tml = decode_entities( $session->{cgiQuery}->param('tml') );

#TODO: don't want to get distracted by this til the old code works - need to de unicode the URI, or?
    $tml =~ s/\xa0/ /g;

    #TODO: very naive multi-line removeal
    $tml =~ s/"\s*\n/"/g;

    #print STDERR "---- ($tml)---\n";

    my $helperform = '';

    #TODO: hand coded dumbness - go find the MarcoRegex..
    $tml =~ /%([A-Z]*){(.*)}%/;
    if ( defined($1) ) {
        my $type   = $1;
        my $search = $2;

        #TODO: need to work out howto do multi-line MACROs
        my $attrs = new Foswiki::Attrs($search);

        $helperform =
          CGI::start_table( { border => 0, class => 'foswikiFormTable' } );

        my @rows;

        #put DOCCO and defaultparameter first
        $helperform .= CGI::Tr( CGI::th($type), CGI::th('Value'), );

        $helperform .=
          CGI::hidden( -name => 'foswikitagname', -default => $type );

        foreach my $param_keys ( keys( %{ $syntax{$type} } ) ) {
            next if ( $param_keys eq 'DOCUMENTATION' );

            my $value = getHtmlControlFor( $type, $param_keys, $attrs );

            my @docco_attrs;
            push( @docco_attrs,
                title => $syntax{$type}->{$param_keys}->{DOCCO} );

            my $_DEFAULT_TAG = $syntax{$type}->{$param_keys}->{defaultparameter}
              || 0;
            my $line = CGI::Tr( CGI::td( {@docco_attrs}, $param_keys ),
                CGI::td($value), );
            if ($_DEFAULT_TAG) {
                unshift( @rows, $line );
            }
            else {
                push( @rows, $line );
            }
        }
        $helperform .= join( "\n", @rows );
        $helperform .= CGI::end_table();
    }
    else {

        #not a tag?
    }

    #TODO: evaluate the MAKETEXT's, and the variables....
    my $textarea =
      Foswiki::Func::readTemplate( 'componenteditplugin', 'popup' );
    $textarea = Foswiki::Func::expandCommonVariables( $textarea, $TOPIC, $WEB );

    my $jscript =
      Foswiki::Func::readTemplate( 'componenteditplugin', 'javascript' );
    my $pluginPubUrl =
        Foswiki::Func::getPubUrlPath() . '/'
      . Foswiki::Func::getTwikiWebname() . '/'
      . $pluginName;
    $jscript =~ s/%PLUGINPUBURL%/$pluginPubUrl/g;
    $jscript = Foswiki::Func::expandCommonVariables( $jscript, $TOPIC, $WEB );

    #unhide div
    $textarea =~ s/display:none;/display:inline;/g;

    $textarea =~ s/COMPONENTEDITPLUGINCUSTOM/$helperform/e;
    $textarea =~ s/COMPONENTEDITPLUGINTML/$tml/e;

    return $jscript . "\n" . $textarea;
}

##############################################################
#supporting functions

#return false if this plugin should not be active for this call
sub pluginApplies {
    my $scriptContext = shift;

    if ( $Foswiki::Plugins::VERSION > 1.025 ) {
        return 0 unless ( Foswiki::Func::getContext()->{$scriptContext} );
    }
    else {
        return 0 unless ( Foswiki::getPageMode() eq 'html' );
        if (   $ENV{"SCRIPT_FILENAME"}
            && $ENV{"SCRIPT_FILENAME"} =~ /^(.+)\/([^\/]+)$/ )
        {
            my $script = $2;
            return 0 unless ( $script eq $scriptContext );
        }
    }

    #lets only apply to the skins i've tested on (nat, pattern, classic, koala)
    return 0
      unless ( grep { Foswiki::Func::getSkin() eq $_ }
        ( 'nat', 'pattern', 'classic', 'koala' ) );

    my $cgiQuery = Foswiki::Func::getCgiQuery();

    #lets only work in text/html....
    #and not with any of the 'special' options (rev=, )
    my $getViewRev         = $cgiQuery->param('rev');
    my $getViewRaw         = $cgiQuery->param('raw');
    my $getViewContentType = $cgiQuery->param('contenttype');
    my $getViewTemplate    = $cgiQuery->param('template');
    return 0
      if ( ( defined($getViewRev) )
        || ( defined($getViewRaw) )
        || ( defined($getViewContentType) )
        || ( defined($getViewTemplate) ) );

    return 1;    #TRUE
}

sub getHtmlControlFor {
    my ( $TMLtype, $param_key, $attrs ) = @_;

    my $value;
    if ( defined( $syntax{$TMLtype}->{$param_key}->{defaultparameter} )
        && $syntax{$TMLtype}->{$param_key}->{defaultparameter} eq 1 )
    {
        $value = $attrs->{_DEFAULT} || $attrs->{$param_key} || '';
    }
    else {
        $value = $attrs->{$param_key} || '';
    }

##SPECIAL TYPE Shortcuts
    if ( $syntax{$TMLtype}->{$param_key}->{type} eq 'onoff' ) {
        $syntax{$TMLtype}->{$param_key}->{type} = 'options';
        $syntax{$TMLtype}->{$param_key}->{option} = [ 'on', 'off' ];
    }

    my $control;
    if ( $syntax{$TMLtype}->{$param_key}->{type} eq 'text' ) {
        $control = CGI::textfield(
            -class => 'foswikiInputField',
            -name  => $param_key,
            -size  => 40,
            -value => $value,
            -title => $syntax{$TMLtype}->{$param_key}->{default},
            -onchange =>
              'Foswiki.ComponentEditPlugin.inputFieldModified(event)',
            -onkeyup => 'Foswiki.ComponentEditPlugin.inputFieldModified(event)',
            -foswikidefault => $syntax{$TMLtype}->{$param_key}->{default},
            -defaultparameter =>
              $syntax{$TMLtype}->{$param_key}->{defaultparameter}
        );
    }
    elsif ( $syntax{$TMLtype}->{$param_key}->{type} eq 'dropdown' ) {

        #        ASSERT( ref( $options )) if DEBUG;
        my $choices = '';
        foreach my $item ( $syntax{$TMLtype}->{$param_key}->{option} ) {
            my $selected = ( $item eq $value );
            $item =~ s/<nop/&lt\;nop/go;
            if ($selected) {
                $choices .= CGI::option( { selected => 'selected' }, $item );
            }
            else {
                $choices .= CGI::option($item);
            }
        }
        $control = CGI::Select(
            {
                name  => $param_key,
                title => $syntax{$TMLtype}->{$param_key}->{default},
                onchange =>
                  'Foswiki.ComponentEditPlugin.inputFieldModified(event)',
                foswikidefault => $syntax{$TMLtype}->{$param_key}->{default},
                defaultparameter =>
                  $syntax{$TMLtype}->{$param_key}->{defaultparameter}
            },
            $choices
        );

    }
    elsif ( $syntax{$TMLtype}->{$param_key}->{type} eq 'options' ) {
        my $options = $syntax{$TMLtype}->{$param_key}->{option};

        #        ASSERT( ref( $options )) if DEBUG;
        my $selected = '';
        my %radio_attrs;
        foreach my $item (@$options) {
            $radio_attrs{$item} = {
                class          => 'foswikiRadioButton',
                label          => $item,
                foswikidefault => $syntax{$TMLtype}->{$param_key}->{default},
                defaultparameter =>
                  $syntax{$TMLtype}->{$param_key}->{defaultparameter}
            };    #$session->handleCommonTags( $item, $web, $topic ) };

            $selected = $item if ( $item eq $value );
        }

        $control = CGI::radio_group(
            -name    => $param_key,
            -values  => $options,
            -default => $value || $syntax{$TMLtype}->{$param_key}->{default},

            #                                   -columns => $size,
            -attributes => \%radio_attrs,
            -onchange =>
              'Foswiki.ComponentEditPlugin.inputFieldModified(event)',
        );
    }
    else {
        $control = $value;
    }

    return $control;
}

1;
