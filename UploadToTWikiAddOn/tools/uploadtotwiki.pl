#!/usr/bin/perl -w
#
# Quick & dirty utility to attach a local file to a TWiki topic
# via http. Add-on home is at
# http://twiki.org/cgi-bin/view/Plugins/UploadToTWikiAddOn
#
# (Utility for Foswiki - The Free and Open Source Wiki, http://foswiki.org/)
#
# Copyright (C) 2007 Peter Thoeny, peter@structuredwikis.com
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

my $toolName = 'uploadtotwiki/2007-02-12';

use strict;

unless ( $ARGV[2] ) {
    print
"Utility to attach files to any TWiki topic. Copyright (C) 2007, Peter\@Thoeny.org\n";
    print
      "Add-on home: http://twiki.org/cgi-bin/view/Plugins/UploadToTWikiAddOn\n";
    print "Usage:\n";
    print
"  ./uploadtotwiki.pl -l <login> -c <comment> -h 1 <file(s)> <TWiki URL>\n";
    print "Parameters:\n";
    print "  -l login      - login name of TWiki account (optional)\n";
    print "  -p password   - password of TWiki account (optional)\n";
    print "  -c 'comment'  - comment of attached file (default: 'Uploaded by "
      . $toolName . "')\n";
    print "  -h 1          - hide attachment, 0 or 1 (default: 0)\n";
    print
"  -i 1          - inline attachment, e.g create link in topic text (default: 0)\n";
    print
"  -d 60         - delay in seconds between uploads of multiple files (default: 30)\n";
    print "  file(s)       - one or more local files to upload (required)\n";
    print
"  URL           - view URL of TWiki topic, http or https protocol (required, must be last)\n";
    print "Example:\n";
    print
"  ./uploadtotwiki.pl -l MyWikiName *.gif http://twiki.org/cgi-bin/view/Sandbox/UploadTest\n";
    exit 1;
}

my $switch = '';
my %opts   = ();
my @files  = ();
foreach my $item (@ARGV) {
    if ($switch) {
        $opts{$switch} = $item;
        $switch = '';
    }
    elsif ( $item =~ /^-([a-zA-Z0-9]+)$/ ) {
        $switch = $1;
    }
    else {
        push( @files, $item );
    }
}
my $login    = $opts{l}    || '';
my $password = $opts{p}    || '';
my $comment  = $opts{c}    || "Uploaded by $toolName";
my $hide     = $opts{h}    || '';
my $link     = $opts{i}    || '';
my $delay    = $opts{d}    || '30';
my $url      = pop(@files) || '';

exit uploadFile( $comment, $hide, $link, $delay, $url, @files );

# =========================
sub uploadFile {
    my ( $theComment, $theHide, $theLink, $theDelay, $theUrl, @theFiles ) = @_;

    require LWP;
    if ($@) {
        print STDERR "Error: LWP is not installed; cannot upload\n";
        return 0;
    }
    my $ua = UploadToTWiki::UserAgent->new();
    $ua->agent($toolName);
    push @{ $ua->requests_redirectable }, 'POST';

    my $uploadUrl = $theUrl;
    unless ( $uploadUrl =~ /^https?:/ ) {
        print STDERR "Error: Only http and https protocols are supported\n";
        return 0;
    }
    unless ( $uploadUrl =~ s|/view|/upload| ) {
        print STDERR "Error: This is not the URL of a TWiki topic\n";
        return 0;
    }

    my $todo = scalar(@theFiles);
    unless ($todo) {
        print STDERR "Error: No files specified to upload\n";
        return 0;
    }

    foreach my $file (@theFiles) {
        unless ( -e $file ) {
            print STDERR "Error: File $file does not exist\n";
            return 0;
        }

        my $fileName = $file;
        $fileName =~ s|.*/||;

        print "Uploading $file to $theUrl\n";

        my $response = $ua->post(
            $uploadUrl,
            [
                'filename'    => $fileName,
                'filepath'    => [$file],
                'filecomment' => $theComment,
                'hidefile'    => $theHide,
                'createlink'  => $theLink
            ],
            'Content_Type' => 'form-data'
        );

        if ( $response->is_success ) {
            print "... upload finished\n";
        }
        else {
            print STDERR "Error: " . $response->status_line . "\n";
            return 0;
        }
        $todo--;
        if ($todo) {
            print "Wait for $theDelay seconds (be nice to the server)\n";
            sleep($theDelay);
        }
    }
    return 1;
}

# =========================
{

    package UploadToTWiki::UserAgent;

    use LWP::UserAgent;
    our @ISA = qw( LWP::UserAgent );

    sub new {
        my ( $class, $id ) = @_;
        my $this = $class->SUPER::new();
        $this->{domain} = $id;
        return $this;
    }

    sub get_basic_credentials {
        my ( $this, $realm, $uri ) = @_;
        my $host = $uri->host_port();
        $host =~ s/\:[0-9]*$//;
        local $/ = "\n";
        unless ($login) {
            print("Enter TWiki login name for $host: ");
            $login = <STDIN>;
            chomp($login);
        }
        unless ($password) {
            print("Enter password for $login at $host: ");
            system('stty -echo');
            $password = <STDIN>;
            system('stty echo');
            print "\n";
            chomp($password);
        }
        return ( $login, $password );
    }
}

# EOF
