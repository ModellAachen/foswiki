# See bottom of file for default license and copyright information

=begin TML

---+ package RepositoryPlugin

The RepositoryPlugin is part of the BuildContrib which provides the other tools
to run from a repository checkout.

Repo Plugin will determine if a Foswiki install is running from a SVN or git
checkout, and will parse out information about the repo, including current
revision, for reporting in a topic.

For this initial version:

   * Assumes that the git and svn commands are on the default path
   * Assumes that the repo root is one level up from the current directory

=cut

package Foswiki::Plugins::RepositoryPlugin;

# Always use strict to enforce variable scoping
use strict;

require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version
use Cwd;

#

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package.
# This should always be $Rev$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
our $VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
our $RELEASE = '0.1';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION =
'Repo Plugin - Displays information about the repository if running from a git or svn checkout';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use
# preferences set in the plugin topic. This is required for compatibility
# with older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, leave $NO_PREFS_IN_TOPIC at 1 and use
# =$Foswiki::cfg= entries set in =LocalSite.cfg=, or if you want the users
# to be able to change settings, then use standard Foswiki preferences that
# can be defined in your %USERSWEB%.SitePreferences and overridden at the web
# and topic level.
our $NO_PREFS_IN_TOPIC = 1;
our $REPO_TYPE         = '';    # Global - can be cached by persistent perl

my $svnbin;
my $gitbin;
my $rootdir;
my %repoInfo;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeDebug( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    $svnbin = $Foswiki::cfg{Plugins}{RepositoryPlugin}{svnProgram}
      || 'svn';

    $gitbin = $Foswiki::cfg{Plugins}{RepositoryPlugin}{gitProgram}
      || 'git';

    $rootdir = $Foswiki::cfg{Plugins}{RepositoryPlugin}{rootDir}
      || '../';

    Foswiki::Func::registerTagHandler( 'REPO', \&_REPO );

    # Plugin correctly initialized
    return 1;
}

=begin TML

---++ _REPO
Primary macro for the REPO Plugin.  Returns basic information about the current repository

  %<nop>REPO{}%

  %<nop>REPO{module="Foswiki::Plugins::MyPlugin"}%   Get information on the specified Foswiki module.
  %<nop>REPO{web="Web" topic="topic" attachment="attach"}%   Get information on a specific topic or attachment.

Note.  In the case of pseudo-installed files,  the file is dereferenced from the symlink to the absolute file name.  Information on that file is reported.

=cut

sub _REPO {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    my $module = $params->{module} || '';

    my $web     = $params->{web}      || $theWeb;
    my $topic   = $params->{topic}    || $theTopic;
    my $default = $params->{_DEFAULT} || '';

    if ( Scalar::Util::tainted($web) ) {
        $web = Foswiki::Sandbox::untaint( $web,
            \&Foswiki::Sandbox::validateWebName );
    }

    if ( Scalar::Util::tainted($topic) ) {
        $topic = Foswiki::Sandbox::untaint( $topic,
            \&Foswiki::Sandbox::validateTopicName );
    }

    ( $web, $topic ) = Foswiki::Func::normalizeWebTopicName( $web, $topic );

    return
'<blockquote class="foswikiAlert"> %X% Error:  =module= and =web / topic= parameters cannot be combined. </blockquote>'
      if ( $module && ( $params->{web} || $params->{topic} ) );

    my $thisfile;

    if ($module) {
        return
'<blockquote class="foswikiAlert"> %X% Error:  Only Foswiki modules can be queried </blockquote>'
          unless ( $module =~ m/^Foswiki/ );
        $module =~ s/[^\w:]//g;

        $module =~ s#::#/#g;
        foreach my $inc (@INC) {
            if ( -f "$inc/$module.pm" ) {
                $thisfile = "$inc/$module.pm";
                last;
            }
        }
    }
    else {
        $thisfile = $Foswiki::cfg{DataDir} . '/' . $web . '/' . $topic . '.txt';
    }

    my $absfile;

    # Deference symbolic links - typically used in pseudo-install
    if ( -l $thisfile ) {
        $absfile = readlink $thisfile;
        $absfile ||= '';
    }

    $absfile ||= $thisfile;
    my $exit;

    my $repoRoot = _findRepoRoot($absfile);
    return "*Unable to find git root:* =$absfile= " unless ($repoRoot);

    my $repoLoc = "--git-dir=$repoRoot/.git --work-tree=$repoRoot";

    if ( $default eq 'svninfo' ) {
        my ($curdir) = getcwd =~ m/^(.*)$/;
        chdir($repoRoot);
        ( my $repoInfo, $exit ) =
          Foswiki::Sandbox->sysCommand( "$gitbin $repoLoc svn info", );
        chdir($curdir);
        my $report .= " " . '<verbatim>' . $repoInfo . '</verbatim>'
          unless $exit;

        return $report;
    }
    elsif ( $default eq 'status' ) {

        #my ($curdir) = getcwd =~ m/^(.*)$/;
        #chdir($repoRoot);
        ( my $repoInfo, $exit ) =
          Foswiki::Sandbox->sysCommand( "$gitbin $repoLoc status -uno", );

        #chdir($curdir);
        my $report .= " " . '<verbatim>' . $repoInfo . '</verbatim>'
          unless $exit;

        return $report;
    }
    else {

        ( my $fileStatus, $exit ) = Foswiki::Sandbox->sysCommand(
            "$gitbin $repoLoc status --porcelain  $absfile ",
        );

        $fileStatus = substr( $fileStatus, 0, 2 );

        return "*File not known to git:* =$absfile= "
          if ( $fileStatus eq '??' );

        my $status =
            $fileStatus =~ m/\ [MD]/  ? 'Modified, not updated in index'
          : $fileStatus =~ m/M[\ MD]/ ? 'updated in index'
          : $fileStatus =~ m/A[\ MD]/ ? 'added to index'
          : $fileStatus =~ m/D[\ M]/  ? 'deleted from index'
          : $fileStatus =~ m/R[\ MD]/ ? 'renamed in index'
          : $fileStatus =~ m/C[\ MD]/ ? 'copied in index'
          : $fileStatus eq '' ? 'up to date'
          :                     'unknown';

        ( my $topicinfo, $exit ) =
          Foswiki::Sandbox->sysCommand( "$gitbin $repoLoc log -1  $absfile ", );

        my $report = "*Repo file:* =$absfile= \n\n*Repo root:* $repoRoot\n\n";

        $report .= "*File Status:* ($fileStatus) - $status\n\n";

        $report .=
          "*Last Commit:* \n" . '<verbatim>' . $topicinfo . '</verbatim>'
          unless $exit;

        return $report;
    }

###
### DEAD CODE
###
    my ( $gitinfo, $gexit ) =
      Foswiki::Sandbox->sysCommand( "$gitbin $repoLoc svn info ", );

    $repoInfo{type} = 'git'
      unless ( $gexit || $gitinfo =~ m/Not a git repository/ );

    my ( $svninfo, $sexit ) =
      Foswiki::Sandbox->sysCommand( "$svnbin $repoLoc info ", );
    $repoInfo{type} = 'svn'
      unless ( $sexit || $svninfo =~ m/not a working copy/ );

    my $cmd = $params->{_DEFAULT} || '';

    if ( $cmd eq 'date' ) {
        my ( $output, $exit ) =
          Foswiki::Sandbox->sysCommand( "$gitbin log -1 ", );
        ($output) = $output =~ /^Date:\s+(.*)$/m;
        return "<verbatim>($output)</verbatim>";
    }
    elsif ( $cmd eq 'author' ) {
        my ( $output, $exit ) =
          Foswiki::Sandbox->sysCommand( "$gitbin log -1 ", );
        ($output) = $output =~ /^Author:\s+(.*)$/m;
        return "<verbatim>($output)</verbatim>";
    }
    elsif ( $cmd eq 'log' ) {
        my ( $output, $exit ) =
          Foswiki::Sandbox->sysCommand( "$gitbin log -5 ", );
        return "<verbatim>($output)</verbatim>";
    }
    elsif ( $cmd eq 'branch' ) {
        my ( $output, $exit ) =
          Foswiki::Sandbox->sysCommand( "$gitbin branch", );
        ($output) = $output =~ /^\*(.*)$/m;
        return "$output";
    }
    else {
        return $repoInfo{type};
    }

}

sub _findRepoRoot {

    my $repoFile = shift;    # full path of a file in repo

    my ( $vol, $dir, $file ) = File::Spec->splitpath($repoFile);
    my @dirs = File::Spec->splitdir($dir);
    my $repoRoot;

    while ( scalar @dirs > 1 ) {
        $repoRoot = File::Spec->catdir(@dirs);

        #print STDERR "Trying $repoRoot \n";
        last if ( -d "$repoRoot/.git" );
        pop(@dirs);
    }

    return $repoRoot if ( -d "$repoRoot/.git" );

    return 0;
}

1;
__END__
This copyright information applies to the RepositoryPlugin:

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# RepositoryPlugin is Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
# Additional copyrights apply to some or all of the code as follows:
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
#
# This license applies to RepositoryPlugin *and also to any derivatives*
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
