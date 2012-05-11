
package Foswiki::Plugins::GitPlugin::GitRun;

use strict;
use Assert;

sub render {
    my ( $template, %params ) = @_;
    my $this;

    my @args = $Foswiki::sandbox->_buildCommandLine( $template, %params );

    my $command;
    foreach my $attribute (@args) {
        $command .= $attribute . ' ';
    }

    return unless defined $command;

    my $scriptPath = Foswiki::Func::getWorkArea('GitPlugin');
    $scriptPath .= '/ssh.sh';
    my $keyPath = $Foswiki::cfg{Git}{SSHKey};
    my $gitRoot = $Foswiki::cfg{Git}{root};

    my $gitplPath = "$Foswiki::cfg{ScriptDir}/../lib";
    $gitplPath .= '/Foswiki/Plugins/GitPlugin/git.pl';

    my $gitPath  = $Foswiki::cfg{Git}{Path};
    my $perlPath = '/usr/bin/perl';
    my $execCmd =
"$perlPath %PL|F% %SCRIPT|F% %GITROOT|F% %KEYPATH|F% %GITPATH|F% %GITCOMMAND%";

    my $sandbox = $Foswiki::sandbox;

    my ( $outPut, $status ) = $sandbox->sysCommand(
        $execCmd,
        PL         => $gitplPath,
        SCRIPT     => $scriptPath,
        GITROOT    => $gitRoot,
        KEYPATH    => $keyPath,
        GITPATH    => $gitPath,
        GITCOMMAND => $command,
    );
    return ( $outPut, $status );
}

1;
