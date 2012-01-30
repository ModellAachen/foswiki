# See bottom of file for license and copyright information
package Foswiki::Plugins::ActionTrackerPlugin::Options;

use Assert;
my $src =  ((DEBUG) ? '' : '_src');

# Define a global so that submodules can access options without needing the
# result of the load. Nasty, but this is refactored over existing code, so
# pragmatic.

my %defaults = (
    CSS   => "%PUBURL%/%SYSTEMWEB%/ActionTrackerPlugin/styles$src.css",
    DEBUG => '0',
    DEFAULTDUE    => 9999999999,                             # far in the future
    EDITBOXHEIGHT => '%EDITBOXHEIGHT%',
    EDITBOXWIDTH  => '%EDITBOXWIDTH%',
    EDITFORMAT    => '| $who | $due | $state | $notify |',
    EDITHEADER          => '| Assigned to | Due date | State | Notify |',
    EDITFOOTER			=> '',
    EDITORIENT          => 'rows',
    ENABLESTATESHORTCUT => '1',
    EXTRAS              => '',
    NOPREVIEW           => '1',
    NOTIFYCHANGES       => '$who,$due,$state,$text',
    TABLEFORMAT => '| $who | $due | $text $link | $state | $notify | $edit |',
    TABLEHEADER => '| Assigned to | Due date | Description | State | Notify ||',
    TABLEFOOTER => '',
    TABLEORIENT => 'cols',
    TEXTFORMAT  => 'Action for $who, due $due, $state$n$text$n$link$n'
);

our %options = %defaults;

sub load {
    # Set defaults, will be overwritten by user prefs
    %options = %defaults;

    require Foswiki::Func;
    foreach my $ky ( keys %options ) {
        my $sk = 'ACTIONTRACKERPLUGIN_' . $ky;
        my $skv = Foswiki::Func::getPreferencesValue($sk);
	next unless ( defined $skv || defined $options{$ky} );
        if ( !defined $skv ) {
	    # Copy back into preferences so it gets expanded in templates
	    $skv = $options{$ky};
	    Foswiki::Func::setPreferencesValue( $sk, $skv );
	}
	# SMELL: this should be done when the template is used
	$options{$ky} = Foswiki::Func::expandCommonVariables( $skv );
    }

    return \%options;
}

1;
__END__

Copyright (C) 2007-2011 Crawford Currie http://c-dot.co.uk

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at 
http://www.gnu.org/copyleft/gpl.html

