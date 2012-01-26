# See bottom of file for default license and copyright information

=begin TML

---+ package ImmediateNotifyPlugin

=cut

package Foswiki::Plugins::ImmediateNotifyPlugin::Twitter;

use strict;

require Foswiki::Func;    # The plugins API

require Net::Twitter;
require WWW::Shorten::Bitly;


=begin TML

---++ afterSaveHandler($text, $topic, $web, $error, $meta )
   * =$text= - the text of the topic _excluding meta-data tags_
     (see beforeSaveHandler)
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$error= - any error string returned by the save.
   * =$meta= - the metadata of the saved topic, represented by a Foswiki::Meta object 

This handler is called each time a topic is saved.

*NOTE:* meta-data is embedded in $text (using %META: tags)

*Since:* Foswiki::Plugins::VERSION 2.0

=cut

sub afterSaveHandler {
    my ( $text, $topic, $web, $error, $meta ) = @_;

    # You can work on $text in place by using the special perl
    # variable $_[0]. These allow you to operate on $text
    # as if it was passed by reference; for example:
    # $_[0] =~ s/SpecialString/my alternative/ge;

    return if(grep(/^$web$/,@excludeWebs));

    my $tweet=$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{Template} || '$user $action topic $web.$topic $url';

    my $action='saved';
    $action='created' if($isNewTopic{$$});

    my $user=$Foswiki::Plugins::SESSION->{'user'};

    # only shorten url if url is actually used
    my $url=Foswiki::Func::getViewUrl($web,$topic);
    if( ($tweet=~/\$url/) and (defined($Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{BitlyUser})) ) {
      $url=WWW::Shorten::Bitly::makeashorterlink(
	$url,
	$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{BitlyUser},
        $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{BitlyKey}
      );
    }

    $tweet=~s/\$web/$web/g;
    $tweet=~s/\$topic/$topic/g;  
    $tweet=~s/\$action/$action/g;
    $tweet=~s/\$user/$user/g;
    $tweet=~s/\$url/$url/g;

    Foswiki::Func::writeDebug("tweet: $tweet");

    my $twitter = Net::Twitter->new(
      traits   => [qw/API::REST/],
      username => $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{StatusUser},
      password => $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{StatusPassword}
    );

    my $result = $twitter->update($tweet);

    Foswiki::Func::writeDebug("result for twitter update: ".join(', ',keys %{$result}));

}


1;
__END__
This copyright information applies to the EmptyPlugin:

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# EmptyPlugin is Copyright (C) 2008 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
# Additional copyrights apply to some or all of the code as follows:
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
#
# This license applies to EmptyPlugin *and also to any derivatives*
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.
