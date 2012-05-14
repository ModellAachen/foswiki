# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006 Will Norris. All Rights Reserved.
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
# As per the GPL, removal of this notice is prohibited.

=pod
---+ package TWiki::UI::Install

UI delegate for install function

=cut

package TWiki::UI::Install;

use strict;
use integer;

use TWiki;
use TWiki::UI;
use TWiki::Contrib::TWikiInstallerContrib;
use FindBin;
use TWiki::Sandbox;
use File::Path qw( mkpath );
use File::Basename qw( basename );

use Scalar::Util qw( tainted );

=pod

---++ StaticMethod install( $session, $web, $topic, $scruptUrl, $query )
=install= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.

Perform a TWikiExtension installation within an already-running TWiki installation.

| =url= | URL of plugin to install |

=cut

sub install {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $store = $session->{store};

    my $progDir = $FindBin::Bin;
    $progDir =~ /(.+)/;
    $progDir = $1;
    die "progDir is tainted" if tainted $progDir;

    my $installOptions = {
        tmpInstall => '/tmp/twiki/',    # SMELL

        #	module => $moduleFilename,

        mapTWikiDirs => {
            lib       => { dest => $::twikiLibPath },             # SMELL?
            pub       => { dest => $TWiki::cfg{PubDir} },
            data      => { dest => $TWiki::cfg{DataDir} },
            templates => { dest => $TWiki::cfg{TemplateDir} },
            bin       => { dest => $progDir, perms => 0755, },    # SMELL?
            locale    => { dest => $TWiki::cfg{LocalesDir} },

            #	    log => ?,
        },

        localDirConfig => {
            DefaultUrlHost => $TWiki::cfg{DefaultUrlHost},
            ScriptUrlPath  => $TWiki::cfg{ScriptUrlPath},
            ScriptSuffix   => $TWiki::cfg{ScriptSuffix},
            PubUrlPath     => $TWiki::cfg{PubUrlPath},
            PubDir         => $TWiki::cfg{PubDir},
            TemplateDir    => $TWiki::cfg{TemplateDir},
            DataDir        => $TWiki::cfg{DataDir},
            LocalesDir     => $TWiki::cfg{LocalesDir},
            LogDir         => $TWiki::cfg{LogDir},
        },

    };

    my $url = $query->param('url') || '';

    # FIX: use Sandbox
    $url =~ /(.*)/;
    $url = $1;
    die "url still tained" if tainted $url;

    # TODO: check url
    # TODO: verify url (trusted sites, .md5, or what???)

    -d $installOptions->{tmpInstall} || mkpath( $installOptions->{tmpInstall} );
    my ( $module, $error ) = _getUrl( { url => $url } );
    my $moduleFilename = "$installOptions->{tmpInstall}/" . basename($url);
    die "moduleFilename tainted" if tainted $moduleFilename;
    open( MODULE, '>', $moduleFilename ) or die $!;
    binmode(MODULE);
    print MODULE $module;
    close MODULE;

    my ( $text, $success, $plugins ) =
      TWiki::Contrib::TWikiInstallerContrib::_InstallTWikiExtension(
        { %$installOptions, module => $moduleFilename } );

    unlink $moduleFilename;

    open( LOCALSITE_CFG, '>>',
        $installOptions->{mapTWikiDirs}->{lib}->{dest} . '/LocalSite.cfg' )
      or die $!;

    # LocalSite.cfg
    foreach my $plugin ( sort keys %$plugins ) {
        print LOCALSITE_CFG "\$TWiki::cfg{Plugins}{$plugin}{Enabled} = 1;\n";
    }
    print LOCALSITE_CFG "1;\n";
    close LOCALSITE_CFG;

    my ($pluginTopicName) = ( basename $moduleFilename ) =~ /(.*)\./;
    $session->redirect(
        $session->getScriptUrl(
            1, 'view', $TWiki::cfg{SystemWebName},
            $pluginTopicName
        )
    );
}

################################################################################

# url:
sub _getUrl {
    my ($p) = @_;
    my $url = $p->{url} or die qq{required parameter "url" not specified};

    use LWP::UserAgent;
    use HTTP::Request;
    use HTTP::Response;

    my $ua = LWP::UserAgent->new() or die $!;
    $ua->agent("TWiki remote installer v0.0.1");
    my $req = HTTP::Request->new( GET => $url );

    # TODO: what about http vs. https ?
    $req->referer("$ENV{SERVER_NAME}:$ENV{SERVER_PORT}$ENV{SCRIPT_NAME}");
    my $response = $ua->request($req);

    return $response->is_error()
      ? ( undef, $response->status_line )
      : ( $response->content(), '' );
}

################################################################################

1;
