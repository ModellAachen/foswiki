# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
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

---+ package Foswiki::Plugins::DebianRepositoryPlugin

=cut

package Foswiki::Plugins::DebianRepositoryPlugin;

# Always use strict to enforce variable scoping
use strict;

require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version
require Foswiki::Sandbox;    # for running external commands

our $VERSION = '$Rev: 7889 $'; # must be like this because of a Foswiki restriction
our $RELEASE = '0.2.0';
our $SHORTDESCRIPTION =
  'automatically creates a Debian repository listing .deb attachments';
our $NO_PREFS_IN_TOPIC = 1;

use Cwd;
use File::Basename;
use vars qw(
  $debian_repository_tool
  $initialization_error_message
);

BEGIN {
    $debian_repository_tool =
      Cwd::abs_path( dirname(__FILE__) . '/../../../tools/debian-repository' );
    my ( $output, $exit ) = Foswiki::Sandbox->sysCommand(
        "$debian_repository_tool --check-dependencies");
    if ( $exit > 0 ) {
        $initialization_error_message = $output;
    }
}

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Plugin correctly initialized
    return 1;
}

sub earlyInitPlugin {
    return $initialization_error_message;
}

sub afterAttachmentSaveHandler {
    my ( $attrHashRef, $topic, $web ) = @_;
    my $filename = $attrHashRef->{attachment};
    if ( $filename =~ /\.deb$/ ) {
        my $webPubDir = $Foswiki::cfg{PubDir} . '/' . $web;
        my $repoName =
          Foswiki::Func::getPreferencesValue( 'DEBIAN_REPOSITORY_NAME', $web )
          || 'debian';
        my $topics =
          Foswiki::Func::getPreferencesValue( 'DEBIAN_REPOSITORY_TOPICS', $web )
          || '';
        my @topics =
          grep { $_ =~ m/$Foswiki::regex{webNameRegex}/ }
          split( /\s+/, $topics );
        my $command = "$debian_repository_tool %DIRECTORY|F% %REPONAME|S%"
          . ( join( ' ', map { ' ' . $_ } @topics ) );
        Foswiki::Sandbox->sysCommand(
            $command,
            DIRECTORY => $webPubDir,
            REPONAME  => $repoName
        );
    }
}

1;
__END__
This copyright information applies to the DebianRepositoryPlugin:

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# DebianRepositoryPlugin is # This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.
