#!/usr/bin/perl -w
# $Id: install_foswiki.cgi 7202 2005-10-28 20:36:14Z WillNorris $
# Copyright 2004,2005, 2010 Will Norris.  All Rights Reserved.
# License: GPL
use strict;
++$|;

package Foswiki::Contrib::FoswikiInstallerContrib;

use vars qw( $VERSION );
$VERSION = '$Rev$';

################################################################################
use File::Path qw( mkpath rmtree );
use CGI qw( :standard );
use FindBin;
use CGI::Carp qw( fatalsToBrowser );
use File::Copy qw( cp mv );
use File::Basename qw( basename );
use English;
use Scalar::Util qw( tainted );
use Data::Dumper qw( Dumper );

#use Archive::Zip;
################################################################################

# parameters
# module: module filename relative to components (eg, kernels/Foswiki_trunk.zip or extension/BlogPlugin.zip)
sub _InstallFoswikiExtension {
    my ($p) = @_;
    my $tmpInstall     = $p->{tmpInstall}     or die "tmpInstall";
    my $module         = $p->{module}         or die "module";
    my $mapFoswikiDirs = $p->{mapFoswikiDirs} or die "mapFoswikiDirs";
    my $localDirConfig = $p->{localDirConfig} or die "localDirConfig";
    my $perl = $p->{perl} || $EXECUTABLE_NAME;

    my $plugins = {};
    my @text;

    my $INSTALL = "$tmpInstall/INSTALL/";
    $INSTALL =~ /(.*)/;
    $INSTALL = $1;
    die "INSTALL still tainted" if tainted $INSTALL;
    -d $INSTALL && rmtree $INSTALL;
    mkpath $INSTALL;

    die "module tainted" if tainted $module;

    my ($name) = ( basename $module ) =~ /(.*)\./;
    die "name is tainted" if tainted $name;

    print STDERR "FoswikiInstallerContrib: Installing $name\n";
    my $q = CGI->new() or die $!;
    push @text, $q->b($name);

    #    $ENV{TMPDIR} =~ /(.*)/;
    #    $ENV{TMPDIR} = $1;

    my $archive = Archive::Zip::CommandLine->new($module)
      or warn
qq{Archive::Zip::CommandLine new failed [$module] - can't install "$name"},
      return 0;
    $archive->extractTree( '', $INSTALL );

    foreach my $file ( $archive->memberNames ) {

        # TODO: rename $base to something more descriptive (like ...?)
        next unless my ( $path, $base ) = $file =~ m|^([^/]+)(/.*)$|;

        my $map = $mapFoswikiDirs->{$path}
          or warn "no mapping for [$path]", next;
        my $dirDest = $map->{dest}
          or die "no destination directory for [$path] " . Dumper($map);

     # handle directories (path ends with /?, if so, mirror directory structure)
        mkpath("$dirDest/$base"), next if $base =~ m|/$|;

        push @text, $file;

        # install the file by moving it from the staging area
        my $destFile = "$dirDest/$base";
        mv( "$INSTALL/$file", $destFile )
          or warn "$INSTALL/$file -> $destFile: $!";
        chmod $map->{perms}, $destFile if $map->{perms};

    # only Plugins have to be enabled (i.e., Contribs and Skins are "always on")
        if ( my ($plugin) = $file =~ m|^lib/Foswiki/Plugins/(.+Plugin).pm$| ) {
            ++$plugins->{$plugin};
        }

        # semi-KLUDGEy implementation to support ScriptSuffix
        if ( $path eq 'bin' && $base !~ /\./ ) {  # process extension-less files
            my $origFile = $destFile;
            $destFile .= $localDirConfig->{ScriptSuffix};
            mv( $origFile, $destFile ) or die "$origFile -> $destFile: $!";

            # TODO: use an exception here!!!
            # patch perl path for local installation
            local $/ = undef;
            open( BIN, '<', $destFile )
              or warn "unable to change perl path for $destFile: $!", next;
            my $bin = <BIN>;
            close BIN;
            $bin =~ s|/usr/bin/perl|$perl|;

            open( BIN, '>', $destFile )
              or warn "unable to change perl path for $destFile: $!", next;
            print BIN $bin;
            close BIN;
        }
    }

    rmtree $INSTALL;

    return ( \@text, 1, $plugins );
}

################################################################################
################################################################################
package Archive::Zip::CommandLine;

use constant AZ_OK    => 0;
use constant AZ_ERROR => 2;

sub new {
    my $class = shift;
    my $self = bless( { 'fileName' => '' }, $class );

    #    $self->{'members'} = [];
    if (@_) {
        my $status = $self->read(@_);
        return $status == AZ_OK ? $self : undef;
    }
    return $self;
}

sub read {
    my ( $self, $filename ) = @_;
    $self->{fileName} = Cwd::abs_path($filename);
    return -e $filename
      ? AZ_OK
      : AZ_ERROR;
}

sub extractTree {
    my ( $self, undef, $tmpInstall ) = @_;

    $self->{extractedDir} = $tmpInstall;
    system( 'unzip', '-qq', $self->{fileName}, '-d' => $self->{extractedDir} );
}

sub memberNames {
    my ($self) = @_;
    chomp( my @a = grep { !/^\.$/ } `cd $self->{extractedDir}; find .` );
    @a = map { $_ .= '/' if -d "$self->{extractedDir}/$_"; $_ } @a;
    @a = map { s|^(\./)||; $_ } @a;
    return @a;
}

################################################################################

1;
