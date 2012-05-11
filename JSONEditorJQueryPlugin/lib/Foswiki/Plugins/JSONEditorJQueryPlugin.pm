# See bottom of file for default license and copyright information

=begin TML

---+ package JSONEditorJQueryPlugin

=cut

package Foswiki::Plugins::JSONEditorJQueryPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

our $VERSION = '$Rev$';

our $RELEASE = '03 Mar 2010';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION =
  'lightweight tree editor of JSON data, using RestPlugin to GET and SET';

our $NO_PREFS_IN_TOPIC = 1;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }
    if ( $Foswiki::cfg{Plugins}{JQueryPlugin}{Enabled} ) {
        require Foswiki::Plugins::JQueryPlugin;
        Foswiki::Plugins::JQueryPlugin::registerPlugin( "JSONEditor",
            'Foswiki::Plugins::JSONEditorJQueryPlugin::JSONEDITOR' );
    }

    # Plugin correctly initialized
    return 1;
}

1;
__END__
This copyright information applies to the JSONEditorJQueryPlugin:

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# JSONEditorJQueryPlugin is # This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the root of this distribution.
