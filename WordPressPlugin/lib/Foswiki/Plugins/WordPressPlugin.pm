# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright 2009 SvenDowideit@fosiki.com
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

=pod

---+ package Foswiki::Plugins::WordPressPlugin


=cut

package Foswiki::Plugins::WordPressPlugin;

use strict;

require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version

our $VERSION          = '$Rev: 3193 $';
our $RELEASE          = '$Date: 2009-03-20 03:32:09 +1100 (Fri, 20 Mar 2009) $';
our $SHORTDESCRIPTION = 'post a topic to your WordPress blog';
our $NO_PREFS_IN_TOPIC = 1;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

*REQUIRED*

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using =Foswiki::Func::writeWarning= and return 0. In this case
%<nop>FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

__Note:__ Please align macro names with the Plugin name, e.g. if
your Plugin is called !FooBarPlugin, name macros FOOBAR and/or
FOOBARSOMETHING. This avoids namespace issues.

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    #    Foswiki::Func::registerTagHandler( 'EXAMPLETAG', \&_EXAMPLETAG );
    Foswiki::Func::registerRESTHandler( 'post', \&postTopic );

    # Plugin correctly initialized
    return 1;
}

=begin TML

---++ post($session) -> $text

This is an example of a sub to be called by the =rest= script. The parameter is:
   * =$session= - The Foswiki object associated to this session.

Additional parameters can be recovered via de query object in the $session.

For more information, check %SYSTEMWEB%.CommandAndCGIScripts#rest

For information about handling error returns from REST handlers, see
Foswiki::Support.Faq1

*Since:* Foswiki::Plugins::VERSION 2.0

supported post values are
   title - string
   description - body of your post, string
   mt_excerpt - string
   mt_text_more - boolean?
   mt_allow_comments - boolean?
   mt_allow_pings - boolean?
   mt_tb_ping_urls - boolean?
   dateCreated - cant figure out the right string
   categories - array ref

=cut

sub postTopic {
    my ($session) = @_;

    use WordPress::Post;

    my $o = WordPress::Post->new(
        {
            proxy    => $Foswiki::cfg{WordPressPlugin}{Host},
            username => $Foswiki::cfg{WordPressPlugin}{User},
            password => $Foswiki::cfg{WordPressPlugin}{Password}
        }
    );

    my $reqTopic = Foswiki::Func::getRequestObject()->param('topic');
    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef, $reqTopic );
    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

    my $title = "$web $topic";
    if ( $text =~ /^\s*---\+*/m ) {
        $text =~ s/^\s*---\+*(.*)\n//m;
        $title = $1;
        $title =~ s/^[!\s]*//;
        $title =
          Foswiki::Func::expandCommonVariables( $title, $topic, $web, $meta );
    }

    #remove commented out html..
    $text =~ s/<!--.*?-->//gs;

    my $renderedText =
      Foswiki::Func::expandCommonVariables( $text, $topic, $web, $meta );
    my $html = Foswiki::Func::renderText( $renderedText, $web, $topic );

    my $id = $o->post(
        {
            title       => $title,
            description => $html,
        }
    );

    if ( $id eq 0 ) {
        return "Error posting to blog, see error log for more information";
    }

    return 'topic posted: ' . $id;
}

1;
__END__
This copyright information applies to the WordPressPlugin:

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# WordPressPlugin is # This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.
