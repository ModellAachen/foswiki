#
# Author:	Alan Burlison - alan@bleaklow.com
# Version:	0.03
# Date:		27 Jan 2003
# License:	This is released under the Perl Artistic license.
#
# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# This is a nearly empty stub only used to register installation of the
# MailToTWiki addon and strip out the TWiki variable that it uses -
# the real work is done in the mailtotwiki script.
#
# See the MailToTWikiPlugin topic for full documentation.
#

package TWiki::Plugins::MailToTWikiPlugin;

our $VERSIO$Rev$';
our $PluginName = q{MailToTWikiPlugin};

#
# Marker for specifying where mail should be inserted.
# NOTE: This MUST be the same as the value in mailtotwiki.
#
our $InsertMarker = qr[(?<!<nop>)%{?MAILTOTWIKI_INSERT_HERE}?%];

#
# Initialise.
#
sub initPlugin {

    # Check Plugins.pm version.
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $PluginName and Plugins.pm");
        return 0;
    }
    return (1);
}

#
# Strip out the insertion marker.
#
sub commonTagsHandler {

    # my ($text, $topic, $web) = @_;

    # Out, dammned spot!
    $_[0] =~ s/\s*$InsertMarker\s*//g;
}

1;
