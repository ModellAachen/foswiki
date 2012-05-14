# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::ImportExportPlugin


=cut

package Foswiki::Plugins::ImportExportPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

our $VERSION           = '$Rev$';
our $RELEASE           = '0.0.8';
our $SHORTDESCRIPTION  = 'Import and export wiki data';
our $NO_PREFS_IN_TOPIC = 1;

our $checkingLinks = 0;
our %wikiWordsRendered;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean


=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    #plugin enabled, but it does nothing unless you are admin
    return 1 unless ( Foswiki::Func::isAnAdmin() );

    # Example code of how to get a preference value, register a macro
    # handler and register a RESTHandler (remove code you do not need)

    # Set your per-installation plugin configuration in LocalSite.cfg,
    # like this:
    # $Foswiki::cfg{Plugins}{ImportExportPlugin}{ExampleSetting} = 1;
    # See %SYSTEMWEB%.DevelopingPlugins#ConfigSpec for information
    # on integrating your plugin configuration with =configure=.

# Always provide a default in case the setting is not defined in
# LocalSite.cfg.
# my $setting = $Foswiki::cfg{Plugins}{ImportExportPlugin}{ExampleSetting} || 0;

    # Register the _EXAMPLETAG function to handle %EXAMPLETAG{...}%
    # This will be called whenever %EXAMPLETAG% or %EXAMPLETAG{...}% is
    # seen in the topic text.
    #Foswiki::Func::registerTagHandler( 'EXAMPLETAG', \&_EXAMPLETAG );

    # Allow a sub to be called from the REST interface
    # using the provided alias
    Foswiki::Func::registerRESTHandler( 'import', \&doImport );
    Foswiki::Func::registerRESTHandler( 'check',  \&doCheck );

    # Plugin correctly initialized
    return 1;
}

=begin TML

---++ doCheck($session) -> $text


=cut

sub doCheck {
    my ( $session, $subject, $verb, $response ) = @_;

    my $query = $session->{request};
    my $filterlist =
      Foswiki::Sandbox::untaintUnchecked( $query->{param}->{filterlist}[0] );
    my $webs = Foswiki::Sandbox::untaintUnchecked( $query->{param}->{webs}[0] );

    if ( !defined($webs) ) {

        #presume a vague demad for docco
        print
"./rest /ImportExportPlugin/check filterlist=chklinks webs=System fromtype=foswiki\n";
        exit;
    }

    my $output = "\n---++ ImportExportPlugin.check " . $webs . "\n";
    $output .=
"./rest /ImportExportPlugin/check filterlist=$filterlist webs=$webs fromtype=foswiki\n";

    $webs =~ s/,/;/g;

    $filterlist =
        'selectwebs(' 
      . $webs
      . '), skiptopics(ImportExportPluginCheck.*Report), '
      . $filterlist;
    my @filter_funcs = getFilterFuncs($filterlist);

    my $type = lc(
        Foswiki::Sandbox::untaintUnchecked(
            $query->{param}->{fromtype}[0] || 'FS'
        )
    );

    my $handler = getFromHandler( $type, $query, \@filter_funcs );

#TODO: this will eventually be a multi-phase thing - show list of candidates to import, then doit
    $output .= $handler->check();
    $output .= "\n\n" . $handler->finish();
    $output .= "\n   * Set ALLOWTOPICVIEW=AdminGroup\n\n";

    $output .=
        '\n\nreport output to '
      . 'Sandbox.ImportExportPluginCheck'
      . Foswiki::Time::formatTime( time(), '$year$mo$day$hour$min' )
      . 'Report' . "\n\n";
    Foswiki::Func::saveTopicText(
        'Sandbox',
        'ImportExportPluginCheck'
          . Foswiki::Time::formatTime( time(), '$year$mo$day$hour$min' )
          . 'Report',
        $output
    );

    return $output;

}

=begin TML

---++ doImport($session) -> $text

This is an example of a sub to be called by the =rest= script. The parameter is:
   * =$session= - The Foswiki object associated to this session.

Additional parameters can be recovered via the query object in the $session, for example:

my $query = $session->{request};
my $web = $query->{param}->{web}[0];

If your rest handler adds or replaces equivalent functionality to a standard script
provided with Foswiki, it should set the appropriate context in its switchboard entry.
A list of contexts are defined in %SYSTEMWEB%.IfStatements#Context_identifiers.

For more information, check %SYSTEMWEB%.CommandAndCGIScripts#rest

For information about handling error returns from REST handlers, see
Foswiki:Support.Faq1

*Since:* Foswiki::Plugins::VERSION 2.0

=cut

sub doImport {
    my ( $session, $subject, $verb, $response ) = @_;

    my $query = $session->{request};
    my $filterlist =
      Foswiki::Sandbox::untaintUnchecked( $query->{param}->{filterlist}[0] );
    my $webs = Foswiki::Sandbox::untaintUnchecked( $query->{param}->{webs}[0] );
    $webs =~ s/,/;/g;
    my $fspath =
      Foswiki::Sandbox::untaintUnchecked( $query->{param}->{fspath}[0] );

    if ( !defined($webs) ) {

        #presume a vague demad for docco
        print
"./rest /ImportExportPlugin/import filterlist=twiki webs=Technology,Support fromtype=fs fspath=/home/sven/src/twiki_backup\n";
        exit;
    }
    my $output = "\n---++ ImportExportPlugin.import " . $webs . "\n";
    $output .=
"./rest /ImportExportPlugin/import filterlist=$filterlist webs=$webs fromtype=fs fspath=$fspath\n";

    $filterlist = 'selectwebs(' . $webs . '), ' . $filterlist;

    my @filter_funcs = getFilterFuncs($filterlist);

    my $type = lc(
        Foswiki::Sandbox::untaintUnchecked(
            $query->{param}->{fromtype}[0] || 'FS'
        )
    );

    my $handler = getFromHandler( $type, $query, \@filter_funcs );

#TODO: this will eventually be a multi-phase thing - show list of candidates to import, then doit
    $output .= $handler->import();
    $output .= "\n\n" . $handler->finish();
    $output .= "\n   * Set ALLOWTOPICVIEW=AdminGroup\n\n";

    $output .=
        '\n\nreport output to '
      . 'Sandbox.ImportExportPluginImport'
      . Foswiki::Time::formatTime( time(), '$year$mo$day$hour$min' )
      . 'Report' . "\n\n";
    Foswiki::Func::saveTopicText(
        'Sandbox',
        'ImportExportPluginImport'
          . Foswiki::Time::formatTime( time(), '$year$mo$day$hour$min' )
          . 'Report',
        $output
    );

    return $output;

}

sub getFilterFuncs {
    my $filterlist = shift;

    my %filter_funcs;

    foreach my $filter ( split( /,\s*/, $filterlist ) ) {

        #parameters to filters: skip(Delete*) or similar
        my ( $f, $order ) = getFilterFunc($filter);
        if ( defined($f) ) {
            print STDERR "adding filter : $filter ($order)\n";
            $filter_funcs{$order} = $f;
        }
        else {
            print STDERR "SKIPPING filter : $filter\n";
        }
    }
    return @filter_funcs{ sort( keys(%filter_funcs) ) };
}

# filters are called with ($web, $topic, $text, $params) -> ($result, $web, $topic, $text)
# $result can be, nochange, skip or something else

sub getFilterFunc {
    my $filter = shift;

    my $params;
    if ( $filter =~ s/\((.*)\)$// ) {
        $params = $1;
    }

    #TODO: scary, i can call anything?
    eval "use Foswiki::Plugins::ImportExportPlugin::Filters";
    die "can't load Filters" if $@;

    my $funcRef =
      $Foswiki::Plugins::ImportExportPlugin::Filters::switchboard{$filter};
    return ( undef, undef ) unless ( defined($funcRef) );
    if ( defined($params) ) {
        my $originalFuncRef = $funcRef;
        $funcRef = sub {
            $originalFuncRef->( @_, params => $params );
        };
    }
    return ( $funcRef,
        $Foswiki::Plugins::ImportExportPlugin::Filters::switchboard_order{
            $filter} );
}

sub getFromHandler {
    my ( $type, $query, $filterlist ) = @_;

    $type = ucfirst($type);
    my $module = "Foswiki::Plugins::ImportExportPlugin::${type}Handler";

    eval "require $module";
    die "can't load $type handler" if $@;

    my $handler = $module->new( $query, $filterlist );

    return $handler;
}

# The function used to handle the %EXAMPLETAG{...}% macro
# You would have one of these for each macro you want to process.
#sub _EXAMPLETAG {
#    my($session, $params, $topic, $web, $topicObject) = @_;
#    # $session  - a reference to the Foswiki session object
#    #             (you probably won't need it, but documented in Foswiki.pm)
#    # $params=  - a reference to a Foswiki::Attrs object containing
#    #             parameters.
#    #             This can be used as a simple hash that maps parameter names
#    #             to values, with _DEFAULT being the name for the default
#    #             (unnamed) parameter.
#    # $topic    - name of the topic in the query
#    # $web      - name of the web in the query
#    # $topicObject - a reference to a Foswiki::Meta object containing the
#    #             topic the macro is being rendered in (new for foswiki 1.1.x)
#    # Return: the result of processing the macro. This will replace the
#    # macro call in the final text.
#
#    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
#    # $params->{_DEFAULT} will be 'hamburger'
#    # $params->{sideorder} will be 'onions'
#}

=begin TML

---++ renderWikiWordHandler($linkText, $hasExplicitLinkLabel, $web, $topic) -> $linkText
   * =$linkText= - the text for the link i.e. for =[<nop>[Link][blah blah]]=
     it's =blah blah=, for =BlahBlah= it's =BlahBlah=, and for [[Blah Blah]] it's =Blah Blah=.
   * =$hasExplicitLinkLabel= - true if the link is of the form =[<nop>[Link][blah blah]]= (false if it's ==<nop>[Blah]] or =BlahBlah=)
   * =$web=, =$topic= - specify the topic being rendered

Called during rendering, this handler allows the plugin a chance to change
the rendering of labels used for links.

Return the new link text.

*Since:* Foswiki::Plugins::VERSION 2.0

=cut

sub renderWikiWordHandler {
    my ( $linkText, $hasExplicitLinkLabel, $web, $topic ) = @_;
    if ($checkingLinks) {

#print STDERR "--------   * $linkText -> =$web= . =$topic= :: ".($hasExplicitLinkLabel?1:0).":";
#        if ($hasExplicitLinkLabel) {
        $wikiWordsRendered{"$web.$topic"}++;

        #        } else {
        #            $wikiWordsRendered{$linkText}++;
        #        }
    }
    return $linkText;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: SvenDowideit

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
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
