package TWiki::Contrib::CommandSet::Apache;

use strict;
use TWiki::Contrib::CommandSet::Apache::Httpd;
use TWiki::Contrib::CommandSet::Apache::Conf;
use TWiki::Contrib::TWikiShellContrib::Help qw{assembleHelp};

=pod
---++ TWiki::Contrib::CommandSet::Apache

Used to manipulate the apache config file that needs to be modified to install twiki (usually the httpd.conf, but can be any file)

| *Command* | *Description* |
| apache | Shows the summary for the apache subcommands |
| apache add  | Adds a TWiki configuration to Apache |
| apache delete | Removes a TWiki configuration from Apache |

=cut

my $apacheAdd = {
    "SMRY"        => 'Adds a TWiki configuration to Apache',
    "SYNOPSIS"    => " apache add <basepath>",
    "DESCRIPTION" => " This command will install the current \$TWIKI_ROOT
 in the Apache config file specified during TWikiShell 
 configuration. The installed TWiki will be under 
 <basepath>
 It scans the file for the =<IfModule mod_alias.c>= line 
 to determine where to put the install information.
 This command creates a tipical *secured* twiki install, 
 that is, only bin and pub will be visible from the browser.

 A backup of the original file is made before the changes are 
 applied.
",
    "EXAMPLE" => " twikishell apache add MyTWikiInstall

    Will add the following lines to the Apache config file:

    ##################################BEGIN MyTWikiInstall
    alias /MyTWikiInstall/pub \$TWIKI_ROOT/pub

    <Directory \"\$TWIKI_ROOT/pub\">
         AllowOverride All
         Allow From All
    </Directory>

    alias /MyTWikiInstall/bin \$TWIKI_ROOT/bin
    
    <Directory \"\$TWIKI_ROOT/bin\">
         AllowOverride All
         Allow From All
        Options ExecCGI
        SetHandler cgi-script
    </Directory>
    #################################################

    Thus installing \$TWIKI_ROOT in the /MyTWikiInstall path
"
};

my $apacheDelete = {
    "SMRY"     => 'Removes a TWiki configuration created by =apache add=',
    "SYNOPSIS" => " apache delete <basepath>",
    "DESCRIPTION" =>
      " This command will delete from the Apache config file the install
 created by =apache add= that is pointed by <basepath>.

 It will look for the first line created by the =apache add= subcommand. 
 A backup of the original file is made before the changes are applied.

",
    "EXAMPLE" => " twikishell apache delete MyTWikiInstall

    Will look for the line 
        ##################################BEGIN MyTWikiInstall

    and delete that installation.
"
};

sub smry { return "Add and remove the TWiki Apache configuration."; }

sub help {
    return
        "Add and remove the TWiki Apache configuration:\n apache add  - "
      . smry_add()
      . "\n apache delete  - "
      . smry_delete() . "\n";
}
sub run { print help(); }

sub run_delete {
    deleteInstallFromApacheConfig(@_);
}

sub run_add {
    addInstallToApacheConfig(@_);
}

sub help_delete {
    return assembleHelp( $apacheDelete, "SYNOPSIS", "DESCRIPTION", "EXAMPLE" );
}

sub help_add {
    return assembleHelp( $apacheAdd, "SYNOPSIS", "DESCRIPTION", "EXAMPLE" );
}

sub smry_delete {
    return $apacheDelete->{'SMRY'};
}

sub smry_add {
    return $apacheAdd->{'SMRY'};
}

sub onImport {

    # Not all users who have this module installed will want to use it
    # Tell them what to do to do so.
    print "module loaded - run configure to use it\n";

    #    configure(@_);
}

1;
