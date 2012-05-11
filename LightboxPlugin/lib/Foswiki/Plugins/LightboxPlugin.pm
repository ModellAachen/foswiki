# See bottom of file for default license and copyright information

=pod

---+ package LightboxPlugin

This is a Foswiki plugin to add hooks to the lightbox javascript package.

=cut

# change the package name and $pluginName!!!
package Foswiki::Plugins::LightboxPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName $debug %default);

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package. This should always be in the format
# $Rev: 9771 $ so that Foswiki can determine the checked-in status of the
# extension.
our $VERSION = '$Rev: 9813 $';

# $RELEASE is used in the "Find More Extensions" automation in configure.
# It is a manually maintained string used to identify functionality steps.
# You can use any of the following formats:
# tuple   - a sequence of integers separated by . e.g. 1.2.3. The numbers
#           usually refer to major.minor.patch release or similar. You can
#           use as many numbers as you like e.g. '1' or '1.2.3.4.5'.
# isodate - a date in ISO8601 format e.g. 2009-08-07
# date    - a date in 1 Jun 2009 format. Three letter English month names only.
# Note: it's important that this string is exactly the same in the extension
# topic - if you use %$RELEASE% with BuildContrib this is done automatically.
our $RELEASE = '26 Nov 2010';

# Name of this Plugin, only used in this module
$pluginName = 'LightboxPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in


=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.2 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Example code of how to get a preference value, register a variable handler
    # and register a RESTHandler. (remove code you do not need)

    # Get plugin preferences, variables defined by:
    #   * Set EXAMPLE = ...
    $debug = Foswiki::Func::getPreferencesValue("\U$pluginName\E_DEBUG");
    $default{'border'} =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_BORDER")
      || "1px dashed #22638c";
    $default{'float'} =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_FLOAT") || "right";

    # There is also an equivalent:
    # $exampleCfgVar = Foswiki::Func::getPluginPreferencesValue( 'EXAMPLE' );
    # that may _only_ be called from the main plugin package.

    # $exampleCfgVar ||= 'default'; # make sure it has a value

    Foswiki::Func::registerTagHandler( 'LIGHTBOX', \&_LIGHTBOX );

    # Plugin correctly initialized
    return 1;
}

# The function is used to handle the %EXAMPLETAG{...}% variable
# You would have one of these for each variable you want to process.
sub _LIGHTBOX {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    # $session  - a reference to the Foswiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a Foswiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the variable

    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # $params->{sideorder} will be 'onions'

    my $tmb  = $params->{thumbnail};
    my $img  = $params->{image};
    my $txt  = $params->{caption} || '';
    my $long = $params->{fullcaption} || $txt;

    my $border = $params->{border} || $default{'border'};
    my $float  = $params->{float}  || $default{'float'};

    my $a =
        '<div class="section clearfix" align="' 
      . $float
      . '" style="border:'
      . $border
      . ';padding:4px; position: relative; float: '
      . $float . ';">';

    $a .= '<div class="thumbnail">';
    $a .=
        '<a href="%ATTACHURLPATH%/' 
      . $img
      . '" rel="lightbox" title="'
      . $long
      . '"><img src="%ATTACHURLPATH%/'
      . $tmb
      . '"  alt="'
      . $txt
      . '"meeting King"/></a>';
    $a .= '</div></div>';

    &addLightboxJS;

    return $a;
}

sub commonTagsHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    Foswiki::Func::writeDebug(
        "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;

    $_[0] =~
      s/%BEGINLIGHTBOX{(.*?)}%(.*?)%ENDLIGHTBOX%/&handleLightBox($1,$2)/ges;

}

sub addLightboxJS {
    my $header =
'<link rel="stylesheet" href="%PUBURL%/%SYSTEMWEB%/LightboxPlugin/lightbox.css" type="text/css" media="screen" />'
      . '<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/LightboxPlugin/lightbox.js"></script>';

    Foswiki::Func::addToHEAD( 'LIGHTBOX_JS', $header );
}

sub handleLightBox {
    my ( $prefs, $text ) = @_;

    my %opts = (
        'caption' => '',
        'border'  => $default{'border'},
        'float'   => $default{'float'}
    );

    my %opts2 = Foswiki::Func::extractParameters($prefs);
    foreach my $k ( keys %opts2 ) {
        my $b = $opts2{$k};

        # remove leading/trailing whitespace from key names
        ( my $a = $k ) =~ s/^\s*|\s*$//;

        $opts{$a} = $b;
    }

    my $ret =
        '<div class="section clearfix" align="'
      . $opts{'float'}
      . '" style="border:'
      . $opts{'border'}
      . ';padding:4px; position: relative; float: '
      . $opts{'float'} . ';">';

    $ret .= '<div class="thumbnail">';
    $ret .=
        '<a href="%ATTACHURLPATH%/'
      . $opts{'image'}
      . '" rel="lightbox" title="'
      . $opts{'caption'} . '">';
    $ret .= '<img src="%ATTACHURLPATH%/' . $opts{'thumbnail'} . '" /></a><br>';
    $ret .= $text;
    $ret .= '</div></div>';

    &addLightboxJS;

    return ($ret);
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

ported from TWiki in Oct 2009, W. Scott Hoge

Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.
Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
