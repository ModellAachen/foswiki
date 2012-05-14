# See bottom of file for license and copyright details
#
# Publish site (generate static HTML)
#
package Foswiki::Plugins::PublishPlugin;

use strict;
use warnings;

use Foswiki       ();
use Foswiki::Func ();
use Error qw( :try );
use Assert;

our $VERSION = '$Rev$';
our $RELEASE = '2.3.2';
our $SHORTDESCRIPTION =
'Generate static output (HTML, PDF) optionally upload (FTP) the output to a publishing site.';

sub initPlugin {
    unless ( defined $Foswiki::cfg{PublishPlugin}{Dir} ) {
        die
"Can't publish because {PublishPlugin}{Dir} was not set. Please notify your Wiki administrator";
    }
    unless ( $Foswiki::cfg{PublishPlugin}{URL} ) {
        die
"Can't publish because {PublishPlugin}{URL} was not set. Please notify your Wiki administrator";
    }
    if (   !-d $Foswiki::cfg{PublishPlugin}{Dir}
        && !-e $Foswiki::cfg{PublishPlugin}{Dir} )
    {
        mkdir( $Foswiki::cfg{PublishPlugin}{Dir}, 0777 )
          || die "Cannot mkdir {PublishPlugin}{Dir}";
    }
    unless ( -d $Foswiki::cfg{PublishPlugin}{Dir}
        && -w $Foswiki::cfg{PublishPlugin}{Dir} )
    {
        die
"Can't publish because no useable {PublishPlugin}{Dir} was found. Please notify your Wiki administrator";
    }

    Foswiki::Func::registerRESTHandler( 'publish', \&_publishRESTHandler );
    Foswiki::Func::registerTagHandler( 'PUBLISHERS_CONTROL_CENTRE',
        \&_publishControlCentre );
    return 1;    # coupersetique
}

sub _publishRESTHandler {

    require Foswiki::Plugins::PublishPlugin::Publisher;
    die $@ if $@;

    my $publisher = new Foswiki::Plugins::PublishPlugin::Publisher(
        $Foswiki::Plugins::SESSION);

    $Foswiki::cfg{PublishPlugin}{Dir} .= '/'
      unless $Foswiki::cfg{PublishPlugin}{Dir} =~ m#/$#;
    $Foswiki::cfg{PublishPlugin}{URL} .= '/'
      unless $Foswiki::cfg{PublishPlugin}{URL} =~ m#/$#;

    my $query = Foswiki::Func::getCgiQuery();
    if ( defined $query->param('control') ) {

        # Control UI
        $publisher->control($query);
    }
    else {
        my $webs = $query->param('web')
          || $Foswiki::Plugins::SESSION->{webName};
        $query->delete('web');
        $webs =~ m#([\w/.,\s]*)#;    # clean up and untaint

        $publisher->publish( split( /[,\s]+/, $1 ) );
    }
    $publisher->finish();
}

sub _display {
    my $msg = join( '', @_ );
    if ( defined $Foswiki::Plugins::SESSION->{response}
        && !Foswiki::Func::getContext()->{command_line} )
    {
        $Foswiki::Plugins::SESSION->{response}->print($msg);
    }
    else {
        print $msg;
    }
}

# Allow manipulation of $Foswiki::cfg{PublishPlugin}{Dir}
sub _publishControlCentre {
    my ( $session, $params, $topic, $web, $topicObject ) = @_;

    my $query = Foswiki::Func::getCgiQuery();

    # Check access to this interface!
    if ( defined &Foswiki::Func::isAnAdmin && !Foswiki::Func::isAnAdmin() ) {
        return CGI::span( { class => 'foswikiAlert' },
            "Only admins can access the control interface" );
    }

    # Old code doesn't have isAnAdmin so will allow access to
    # the control UI for everyone. Caveat emptor.

    my $output = CGI::p(<<HERE);
<h1>Publishers Control Interface</h1>
This interface lets you perform basic management operations
on published output files and directories. Click on the name of the
output file to visit it.
HERE
    $output .= $query->Dump() if DEBUG;
    my $action = $query->param('action') || '';
    $query->delete('action');    # delete so we can redefine them
    my $file = $query->param('file');
    $query->delete('file');

    if ( $action eq 'delete' ) {
        $file =~ m#([\w./\\]+)#;    # untaint
        if ( -e "$Foswiki::cfg{PublishPlugin}{Dir}/$1" ) {
            File::Path::rmtree("$Foswiki::cfg{PublishPlugin}{Dir}/$1");
            $output .= CGI::p("$1 deleted");
        }
        else {
            $output .= CGI::p("Cannot delete $1 - no such file");
        }
    }
    if ( opendir( D, $Foswiki::cfg{PublishPlugin}{Dir} ) ) {
        my @files = grep( !/^\./, readdir(D) );
        if ( scalar(@files) ) {
            $output .= CGI::start_table();
            foreach $file (@files) {
                my $link = "$Foswiki::cfg{PublishPlugin}{URL}/$file";
                $link = CGI::a( { href => $link }, $file );
                my @cols   = ( CGI::th($link) );
                my $delcol = CGI::start_form(
                    {
                        action =>
                          Foswiki::Func::getScriptUrl( $web, $topic, 'view' ),
                        method => 'POST',
                        name   => $file
                    }
                );
                $delcol .= CGI::submit(
                    {
                        type => 'button',
                        name => 'Delete'
                    }
                );
                $delcol .= "<input type='hidden' name='file' value='$file'/>";
                $delcol .=
                  "<input type='hidden' name='action' value='delete' />";
                $delcol .= "<input type='hidden' name='control' value='1' />";
                $delcol .= CGI::end_form();
                push( @cols, $delcol );
                $output .= CGI::Tr( { valign => "baseline" },
                    join( '', map { CGI::td($_) } @cols ) );
            }
            $output .= CGI::end_table();
        }
        else {
            $output .= "The output directory is currently empty";
        }
    }
    else {
        $output .= "Failed to open '$Foswiki::cfg{PublishPlugin}{Dir}': $!";
    }

    return $output;
}

1;
__END__
#
# Copyright (C) 2001 Motorola
# Copyright (C) 2001-2007 Sven Dowideit, svenud@ozemail.com.au
# Copyright (C) 2002, Eric Scouten
# Copyright (C) 2005-2011 Crawford Currie, http://c-dot.co.uk
# Copyright (C) 2006 Martin Cleaver, http://www.cleaver.org
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
#
# Removal of this notice in this or derivatives is forbidden.
