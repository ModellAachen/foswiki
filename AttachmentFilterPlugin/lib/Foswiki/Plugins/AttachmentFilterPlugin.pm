# This script Copyright (c) 2008 Impressive.media
# and distributed under the GPL (see below)
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

package Foswiki::Plugins::AttachmentFilterPlugin;

use strict;

use Foswiki::OopsException;
use File::MMagic;
use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev: 12445$';

$RELEASE = 'Dakar';

$SHORTDESCRIPTION =
'This plugin filters attachment by their content type and allows to block specific attachments';
$NO_PREFS_IN_TOPIC = 1;

$pluginName = 'AttachmentFilterPlugin';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }
    return 1;
}

sub beforeAttachmentSaveHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ###   my( $attrHashRef, $topic, $web ) = @_;
    my $web     = $_[2];
    my $topic   = $_[1];
    my $attribs = $_[0];
    my $mm      = new File::MMagic;    # use internal magic file
      # $mm = File::MMagic->new('/etc/magic'); # use external magic file
      #   # $mm = File::MMagic->new('/usr/share/etc/magic'); # if you use Debian
      #     $res = $mm->checktype_filename("/somewhere/unknown/file");
    my $fileType = $mm->checktype_filename( $attribs->{'tmpFilename'} );

    my $allowedTypes =
      $Foswiki::cfg{Plugins}{AttachmentFilterPlugin}{AllowedFiltypes};

    if ( $allowedTypes =~ m/$fileType/ ) {

        # everything is ok
    }
    else {    # forbidden filetype
        throw Foswiki::OopsException(
            'attention',
            def    => "generic",
            web    => $web,
            topic  => $topic,
            keep   => 1,
            params => [
                    'You cannot upload this attachment: '
                  . $attribs->{'attachment'}
                  . ". The type($fileType) is forbidden, please ask your administrator for further informations"
            ]
        );
    }
}

1;
