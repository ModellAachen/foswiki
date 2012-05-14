# See bottom of file for default license and copyright information

# TODO: Add directory and file sorting options.
# TODO: Add support for non-Unixy file separators.

package Foswiki::Plugins::FSBrowserPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

use File::Find;

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package. This should always be in the format
# $Rev$ so that Foswiki can determine the checked-in status of the
# extension.
our $VERSION = '$Rev$';

# $RELEASE is used in the "Find More Extensions" automation in configure.
# It is a manually maintained string used to identify functionality steps.
# Note: it's important that this string is exactly the same in the extension
# topic - if you use %$RELEASE% with BuildContrib this is done automatically.
our $RELEASE = '0.1.0';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION =
  'A plugin to enable browsing of a filesystem hierarchy.';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use
# preferences set in the plugin topic. This is required for compatibility
# with older plugins, but imposes a significant performance penalty, and
# is not recommended.

our $NO_PREFS_IN_TOPIC = 1;

# The root directory of the web server Foswiki is running on.
my $serverroot;

# Users should not be able to anything outside of this hierarchy.
my $pubroot;

# The root of the hierarchy which is to be displayed.
my $browseroot = '/';

# Temporary hash for hierarchy.
my %fshash;

# The filesystem tree we'll create, in Foswiki list-style format.
my $fstree = '';

# Maximum depth of the hierarchy to be displayed.
my $maxdepth;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Set your per-installation plugin configuration in LocalSite.cfg,
    # like this:
    # $Foswiki::cfg{Plugins}{FSBrowserPlugin}{ServerRoot} = '/var/www';

    # Always provide a default in case the setting is not defined in
    # LocalSite.cfg.
    $serverroot = $Foswiki::cfg{Plugins}{FSBrowserPlugin}{ServerRoot}
      || '/var/www';

    $pubroot = $serverroot . $Foswiki::cfg{PubUrlPath};

    # Register the _FSBROWSER function to handle %FSBROWSER{...}%
    # This will be called whenever %FSBROWSER% or %FSBROWSER{...}% is
    # seen in the topic text.
    Foswiki::Func::registerTagHandler( 'FSBROWSER', \&_FSBROWSER );

    # Plugin correctly initialized
    return 1;
}

# The function used to handle the %FSBROWSER{...}% macro

sub _FSBROWSER {

    my ( $session, $params, $topic, $web, $topicObject ) = @_;

    # $session  - a reference to the Foswiki session object
    #             (you probably won't need it, but documented in Foswiki.pm)
    # $params=  - a reference to a Foswiki::Attrs object containing
    #             parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             (unnamed) parameter.
    # $topic    - name of the topic in the query
    # $web      - name of the web in the query
    # $topicObject - a reference to a Foswiki::Meta object containing the
    #             topic the macro is being rendered in (new for foswiki 1.1.x)
    # Return: the result of processing the macro. This will replace the
    # macro call in the final text.

    if ( defined $params->{_DEFAULT} ) {
        $browseroot = $params->{_DEFAULT};
    }

    if ( $browseroot =~ m|\.\./| ) {
        return
"!FSBrowserPlugin error: Relative paths not permitted in path specification.";
    }

    $browseroot = $pubroot . $browseroot;

    if ( defined $params->{maxdepth} ) {
        $maxdepth = $params->{maxdepth};
    }

    find( { wanted => \&wanted, untaint => 1 }, ($browseroot) );

    my $currentdepth;
    my $name;

    foreach my $filepath ( sort keys { uc($a) cmp uc($b) } %fshash ) {
        $currentdepth = $fshash{$filepath}{depth};
        $name         = $fshash{$filepath}{name};
        $fstree = $fstree . '   ' x $currentdepth . "* [[$filepath][$name]]\n";
    }

    return $fstree;

}

sub wanted {

    my $filepath;
    my $locationpath;
    my $name;
    my $currentdepth = 0;

    # $File::Find::dir is the current directory name.
    # $_ is the current filename within that directory.
    # $File::Find::name is the complete pathname to the file.

    $filepath     = $File::Find::name;
    $locationpath = $File::Find::name;
    $filepath     =~ s/$serverroot(.*)/$1/;
    $locationpath =~ s/$pubroot(.*)/$1/;

    while ( $locationpath =~ m|/|g ) { $currentdepth++; }

    if ( defined $maxdepth ) {
        if ( $currentdepth > $maxdepth ) {
            return;
        }
    }

    # Don't display '.' or 'hidden' dot-files.
    unless ( $_ =~ '^\.' ) {

        $name = $File::Find::name;
        $name =~ s|.*/(.*)$|$1|;

        $fshash{$filepath} = { depth => $currentdepth, name => $name };

    }

}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: AlexisHazell

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
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
