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

---+ package Foswiki::Plugins::TopSecretPlugin

When developing a plugin it is important to remember that

Foswiki is tolerant of plugins that do not compile. In this case,
the failure will be silent but the plugin will not be available.
See %SYSTEMWEB%.InstalledPlugins for error messages.

__NOTE:__ Foswiki:Development.StepByStepRenderingOrder helps you decide which
rendering handler to use. When writing handlers, keep in mind that these may
be invoked

on included topics. For example, if a plugin generates links to the current
topic, these need to be generated before the =afterCommonTagsHandler= is run.
After that point in the rendering loop we have lost the information that
the text had been included from another topic.

=cut

package Foswiki::Plugins::TopSecretPlugin;
use strict;

require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version

our $VERSION          = '$Rev: 3193 $';
our $RELEASE          = '$Date: 2009-03-19 17:32:09 +0100 (Do, 19 Mrz 2009) $';
our $SHORTDESCRIPTION = 'Hides away some topic content with pseudo-encryption.';
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

    # Plugin correctly initialized
    return 1;
}

=begin TML

---++ commonTagsHandler($text, $topic, $web, $included, $meta )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$included= - Boolean flag indicating whether the handler is
     invoked on an included topic
   * =$meta= - meta-data object for the topic MAY BE =undef=
This handler is called by the code that expands %<nop>MACROS% syntax in
the topic body and in form fields. It may be called many times while
a topic is being rendered.

Only plugins that have to parse the entire topic content should implement
this function. For expanding macros with trivial syntax it is *far* more
efficient to use =Foswiki::Func::registerTagHandler= (see =initPlugin=).

Internal Foswiki macros, (and any macros declared using
=Foswiki::Func::registerTagHandler=) are expanded _before_, and then again
_after_, this function is called to ensure all %<nop>MACROS% are expanded.

*NOTE:* when this handler is called, &lt;verbatim> blocks have been
removed from the text (though all other blocks such as &lt;pre> and
&lt;noautolink> are still present).

*NOTE:* meta-data is _not_ embedded in the text passed to this
handler. Use the =$meta= object.

*Since:* $Foswiki::Plugins::VERSION 2.0

=cut

sub commonTagsHandler {
    my ( $text, $topic, $web, $included, $meta ) = @_;
    my $query = Foswiki::Func::getCgiQuery();

    if ( $text =~ m/(?:<|&lt;)encrypted(?:>|&gt;)/ ) {
        if ( $query->param("answer") eq "42" ) {
            $_[0] =~
s/(?:<|&lt;)encrypted(?:>|&gt;)(.*?)(?:<|&lt;)\/encrypted(?:>|&gt;)/&_rot13($1, "", "")/seg;
        }
        else {
            $_[0] =~
s/(?:<|&lt;)encrypted(?:>|&gt;)(.*?)(?:<|&lt;)\/encrypted(?:>|&gt;)/$1/sg;
        }
    }
}

=begin TML

---++ beforeSaveHandler($text, $topic, $web, $meta )
   * =$text= - text _with embedded meta-data tags_
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - the metadata of the topic being saved, represented by a Foswiki::Meta object.

This handler is called each time a topic is saved.

*NOTE:* meta-data is embedded in =$text= (using %META: tags). If you modify
the =$meta= object, then it will override any changes to the meta-data
embedded in the text. Modify *either* the META in the text *or* the =$meta=
object, never both. You are recommended to modify the =$meta= object rather
than the text, as this approach is proof against changes in the embedded
text format.

*Since:* Foswiki::Plugins::VERSION = 2.0

=cut

sub beforeSaveHandler {
    my ( $text, $topic, $web ) = @_;

    if ( $text =~ m/(?:<|&lt;)secret(?:>|&gt;)/ ) {
        $_[0] =~
s/(?:<|&lt;)secret(?:>|&gt;)(.*?)(?:<|&lt;)\/secret(?:>|&gt;)/&_rot13($1, "<encrypted>", "<\/encrypted>")/seg;
    }
}

sub _rot13 {
    my $text = $_[0] || "";
    my $pre  = $_[1] || "";
    my $post = $_[2] || "";

    map { tr/a-zA-Z/n-za-mN-ZA-M/; $_ } $text;

    return $pre . $text . $post;
}

1;
__END__
This copyright information applies to the TopSecretPlugin:

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# TopSecretPlugin (c) 2009 by Foswiki:Main.OliverKrueger
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.
