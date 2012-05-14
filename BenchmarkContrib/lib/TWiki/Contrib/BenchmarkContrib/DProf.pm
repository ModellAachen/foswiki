# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 1999-2006 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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

---+ package Contrib::BenchmarkContrib::DProf

This package supports Perl's =Devel::DProf= profiler, which is part
of the standard distribution.

=cut

use strict;

use File::Spec;
use File::Path;

# This is a constant in the current module
my $profiler = 'DProf';

package TWiki::Contrib::BenchmarkContrib::DProf;

sub profile {
    my $package = shift;
    my ( $twiki, $script_name, $benchmarkWeb ) = @_;

    my $query = $twiki->{cgiQuery};

    # what to profile - these values are provided by TWiki::UI
    my $web   = $twiki->{webName};
    my $topic = $twiki->{topicName};

    my $skin = $query->param('pskin') || '';
    ($skin) = $skin =~ /([\w\d._-]+)/;
    $skin ||= $twiki->getSkin();

    my $pparams = $query->param('pparams') || '';

    my $store = $twiki->{store};
    if ( !$store->topicExists( $web, $topic ) ) {
        throw TWiki::OopsException(
            'accessdenied',
            def    => 'no_such_topic',
            web    => $web,
            topic  => $topic,
            params => $script_name
        );
    }

    # extract the parameters which are "private" to profile
    my $method = $query->param('method') || 'view';
    ($method) = $method =~ /(\w+)/;
    $method .= $TWiki::cfg{ScriptSuffix};

    my $configuration = $query->param('config');
    my $conf_par =
      $configuration ? "-I../lib -mConfigurations::$configuration " : '';

    # admins are allowed to change wikiname of viewer
    my $user     = $twiki->{user};
    my $wikiname = $twiki->{users}->getWikiName($user);
    my $viewer   = $query->param('viewer') || $wikiname;
    ($viewer) = $viewer =~ /($TWiki::regex{wikiWordRegex})/;
    if ( $viewer ne $wikiname ) {
        if ( $twiki->{users}->isAdmin($user) ) {
            my $users = $query->{users};
            my $login = $users->findUser( $viewer, $viewer, "don't create" );
            if ($login) {

                # (Ab)use the fact that the environment variable
                # usually supplied by the server gets pretty high
                # precedence, regardless of login configuration
                $ENV{REMOTE_USER} = $login;
            }
        }
        else {
            $viewer = $wikiname;
        }
    }

    # FIXME: There should be a module per profiler, and an else branch

    # run the TWiki script
    #    * as a command line script, so that we don't have to set up a
    #      complete CGI %ENV hash
    #    * for that, we have to kill $ENV{GATEWAY_INTERFACE} to make
    #      sure that TWiki will use command_line syntax instead of CGI.pm
    #    * capturing STDOUT
    #    * redirecting profiling output to a temporary file
    my $tempfile = File::Spec->tmpdir() . "/profile.$$";
    $ENV{PERL_DPROF_OUT_FILE_NAME} = $tempfile;    # per spec of DProf.pm
    $ENV{GATEWAY_INTERFACE}        = '';
    my $stdout =
`perl -T -d:$profiler $conf_par $method -user $viewer -skin $skin $web.$topic`;

    my $revision = $twiki->{store}->getRevisionNumber( $web, $topic );

    my $profile = `dprofpp -O1000 $tempfile`;
    unlink "$tempfile"
      or warn "Could not unlink temporary file '$tempfile': '$!'";

    # repair that braindead line length limitation of vanilla dprofpp
    my @profile_lines = split /\n/, $profile;
    my @output_lines  = ();
    my $output_line   = '';
    my $current_line  = '';
    my $total_elapsed = 0;
    my $total_usersys = 0;
    my @field_names   = ();
  LINE:

    for my $current_line (@profile_lines) {
        if ( $current_line =~ /^\s*0+.0+\s/ ) {
            last LINE;
        }
        if ( $current_line =~ /Total Elapsed Time\s*=\s*(\d+.\d+)/ ) {
            $total_elapsed = $1;
            next LINE;
        }
        if ( $current_line =~ /User\+System Time\s*=\s*(\d+.\d+)/ ) {
            $total_usersys = $1;
            next LINE;
        }
        if ( $current_line =~ /Exclusive/ ) {
            next LINE;
        }
        if ( $current_line =~ /^\s*%Time/ ) {
            @field_names = split " ", $current_line;
            next LINE;
        }
        if ( $current_line =~ s/\s{35}[\s\d.]+// ) {
            $output_line .= $current_line;
        }
        else {
            push @output_lines, $output_line if $output_line;
            $output_line = $current_line;
        }
    }
    push @output_lines, $current_line if $current_line;
    $profile = join "\n", @output_lines;

    #my ($PTime,$ExclSec,$CumulS,$NCalls,$secpercall,$csecpercall,$name);

    # prepare the text to be written
    my $text = <<"EOT";
---+ Performance Profile for [[$web.$topic]]

\%INCLUDE{"$benchmarkWeb.WebHome" section="benchmarkform" PROFILER="$profiler" PROFILEMETHOD="$method" PROFILEREVISION="$revision" PROFILESKIN="$skin" PROFILETOPIC="$topic" PROFILEVIEWER="$viewer" PROFILEWEB="$web"}%
<noautolink>
|  *Total Elapsed Time:* ||||  $total_elapsed sec ||
|    *User+System Time:* ||||  $total_usersys sec ||
EOT
    $text .= '|  ' . join( '  |  ', map { "*$_*" } @field_names ) . "  |\n";
    for my $line (@output_lines) {
        my $tr = '|  ' . join( ' |  ', split( " ", $line ) ) . "  |\n";
        $tr =~ s/  (\S+)  |$/ $1  |/;
        $text .= $tr;
    }
    $text .= "</noautolink>\n";

    # prepare for saving the topic by running TWiki::UI::Save::save
    $twiki->{webName}   = $benchmarkWeb;
    $twiki->{topicName} = "${web}_${topic}_XXXXXXXXXX";

    # delete the parameters which are private to the profiler
    $query->delete(qw(method profiler config));

    # and provide the parameters which save needs
    $query->param( -name => 'text', -value => $text );

    $twiki->leaveContext($script_name);
    $twiki->enterContext('save');
    TWiki::UI::Save::save($twiki);
}

"Hooray";    # Just 1; would do as well, of course ;-)
