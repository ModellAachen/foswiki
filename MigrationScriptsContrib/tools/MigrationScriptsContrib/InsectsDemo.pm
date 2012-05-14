#!/usr/bin/perl -w
# See bottom of file for default license and copyright information

package InsectsDemo;
use strict;
use warnings;

# Adjust these variables to suit your own data/requirements
my $formname =
  $Foswiki::cfg{SystemWebName} . '.MigrationScriptsInsectsDemo.InsectsDemoForm';
my ( $csvtopic, $csvfile ) = (
    $Foswiki::cfg{SystemWebName} . '.MigrationScriptsInsectsDemo',
    'Insecta.csv'
);
my $csvurl =
'http://www.environment.gov.au/biodiversity/abrs/online-resources/fauna/afd-data/insecta.zip';
my $csvTopicObj;
my $saveweb = $Foswiki::cfg{SystemWebName} . '.MigrationScriptsInsectsDemo';
my $asUser  = 'admin';

# The elements in this array are columns in the CSV file. Each element is a
# hash representing a row in a DataForms definition table. This schema has is
# used twice:
#   1 For generating a DataForms definition topic used on each data topic
#   representing a row of CSV data
#   1 For mapping & processing each row of CSV data into a topic
#
# There are a couple of "special" schema lines that can look like this:
#    * {split_fn => \&some_fn} - CSV cell in, multiple formfields out. Split
#    into formfields using some_fn($topicObj, $csvvalue) and returns an array of
#    META:FIELD hashes suitable for passing into Foswiki::Meta::putKeyed when
#    the CSV value is defined, and when it isn't, returns an array of schema
#    definition hashrefs. For example, consider a CSV file with two columns,
#    PersonID and FullName, but you want the data topic to have separate First,
#    middle and LastName fields:
#
#   {name => 'PersonID', type => 'label', attributes => 'H'},
#   {split_fn => \&split_fullname}...
#
#   The job of split_fn is to take the $csvvalue (Eg. "John Fred Smith") and split it into
#   several elements looking something like this:
#
#   {name => 'FirstName', title => 'First name', type => 'text', size => '100', value => 'John'},
#   {name => 'MiddleName', title => 'Middle name', type => 'text', size => '100', value => 'Fred'},
#   {name => 'LastName', title => 'Last name', type => 'text', size => '100', value => 'Smith'}
#
#   * {skip_fn => \&some_fn2} - CSV cell in, no formfields out. You may wish
#   to accumulate multiple CSV cells for later (useful for making a formfield
#   derived from multiple CSV columns). For example, consider a CSV file with
#   four columns, PersonID, FirstName, MiddleName and LastName, but you want
#   the data topic to represent the three name parts as one FullName field:
#
#   {name => 'PersonID', type => 'label', attributes => 'H'},
#   {skip_fn => \&get_firstName},
#   {skip_fn => \&get_middlename},
#   {split_fn => \&do_fullname}...
#
#   The job of get_firstname & get_middlename would be to remember "John" &
#   "Fred", then do_fullname would return a single-element array which contains
#   a concatenation of first + middle + lastnames, looking ultimately like
#
#   {name => 'FullName', title => 'Full name', type => 'text', size => '100', value => "$first $middle $last"}
#
#   * {do_fn => \&some_fn3} - generate formfields. Is passed the $topicObj
#   for the current CSV row, but the job of this method is usually to add a
#   field which is not derived from the CSV file. For example, do_importmeta
#   adds formfields to help identify which CSV file an imported topic came from,
#   and what version it was:
#
#   {name => 'ImportTopic', type => 'label', attr => 'H'},
#   {name => 'ImportTopicRev', type => 'label', attr => 'H'},
#   {name => 'ImportTopicAttachment', type => 'label', attr => 'H'},
#   {name => 'ImportTopicAttachmentRev', type => 'label', attr => 'H'}
my @schema;

sub gen_schema {
    my $csv = Text::CSV->new(
        { auto_diag => 1, binary => 1 } )    # should set binary attribute.
      or die "Cannot use CSV: " . Text::CSV->error_diag();
    my ($topicObj) =
      Foswiki::Func::readTopic(
        Foswiki::Func::normalizeWebTopicName( $saveweb, $csvtopic ) );
    my $fh = $topicObj->openAttachment( $csvfile, '<' );

    foreach my $cell ( @{ $csv->getline($fh) } ) {
        push(
            @schema,
            {
                name  => $cell,
                title => $cell,
                type  => 'text',
                size  => '100'
            }
        );
    }
    $csv->eof or $csv->error_diag();
    close($fh);

    return;
}

BEGIN {
    my $goodlibpath = eval {
        require 'setlib.cfg';
        1;
    };
    if ( not $goodlibpath ) {
        die(<<"HERE");
Please start the script with your Foswiki's bin directory in the perl LIB path,
Eg. perl -w -I /var/lib/foswiki/bin ./InsectsDemo.pm
\tThe error was: '$!'
HERE
    }
    require 'LocalSite.cfg';
    $Foswiki::cfg{Engine} = 'Foswiki::Engine::CLI';
    require Carp;
    $SIG{__DIE__}        = \&Carp::confess;
    $ENV{FOSWIKI_ACTION} = 'view';
}

use Assert;
use Data::Dumper;
use Text::CSV;
use LWP::UserAgent;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Spec;
use Foswiki();
use Foswiki::Func();
use Foswiki::Meta();
use Foswiki::Contrib::MigrationScriptsContrib();

my $session = Foswiki->new($asUser);

sub split_authority {
    my ( $topicObject, $count, $csvcell, $csvrow, $csvcol, $schemaRowI ) = @_;
    my $Authority = {
        name  => 'Authority',
        title => 'Authority (author)',
        type  => 'text',
        size  => '100'
    };
    my $Year = {
        name  => 'AuthorityYear',
        title => 'Year published',
        type  => 'text',
        size  => '10'
    };

    if ( $topicObject and defined $csvcell ) {
        $csvcell =~ /\w,\s*(\d{4,4})\b/;
        ( $Authority->{value}, $Year->{value} ) = ( $csvcell || '', $1 || '' );
    }

    return ( $Authority, $Year );
}

sub do_importmeta {
    my ( $topicObject, $count, $csvcell, $csvrow, $csvcol, $schemaRowI ) = @_;
    my $ImportTopic = { name => 'ImportTopic', type => 'label', attr => 'H' };
    my $ImportTopicRev =
      { name => 'ImportTopicRev', type => 'label', attr => 'H' };
    my $ImportTopicAttachment =
      { name => 'ImportTopicAttachment', type => 'label', attr => 'H' };
    my $ImportTopicAttachmentRev =
      { name => 'ImportTopicAttachmentRev', type => 'label', attr => 'H' };
    my $ImportTopicAttachmentRow =
      { name => 'ImportTopicAttachmentRow', type => 'label', attr => 'H' };
    my @fields;

    if ($topicObject) {
        $ImportTopic->{value} = $csvtopic;
        $ImportTopicRev->{value} =
          '' . $csvTopicObj->getRevisionInfo()->{version};    #Force string
        $ImportTopicAttachment->{value}    = $csvfile;
        $ImportTopicAttachmentRev->{value} = ''
          . $csvTopicObj->getAttachmentRevisionInfo($csvfile)
          ->{version};                                        #Force string
        $ImportTopicAttachmentRow->{value} = '' . $count;
    }

    @fields = (
        $ImportTopic, $ImportTopicRev, $ImportTopicAttachment,
        $ImportTopicAttachmentRev, $ImportTopicAttachmentRow
    );

    return @fields;
}

sub gen_schemaline {
    my ($field) = @_;
    my $defaults = { type => 'richtext' };
    my @line;

    foreach my $bit (qw(name type size values title attributes)) {
        if ( $field->{$bit} ) {
            push( @line, ' ' . $field->{$bit} . ' ' );
        }
        elsif ( $defaults->{$bit} ) {
            push( @line, ' ' . $defaults->{$bit} . ' ' );
        }
        else {
            push( @line, ' ' );
        }
    }

    return '|' . join( '|', @line ) . '|';
}

sub gen_form {
    my @lines = (
'| *Name* | *Type* | *Size* | *Values* | *Tooltip message* | *Attributes* |'
    );

    foreach my $property (@schema) {
        if ( exists $property->{split_fn} ) {
            foreach my $splitproperty ( $property->{split_fn}->() ) {
                push( @lines, gen_schemaline($splitproperty) );
            }
        }
        elsif ( exists $property->{skip_fn} ) {
        }
        elsif ( exists $property->{do_fn} ) {
            foreach my $splitproperty ( $property->{do_fn}->() ) {
                push( @lines, gen_schemaline($splitproperty) );
            }
        }
        else {
            push( @lines, gen_schemaline($property) );
        }
    }

    return join( "\n", @lines );
}

sub set_up {
    my ( $formWeb, $formTopic ) =
      Foswiki::Func::normalizeWebTopicName( $saveweb, $formname );
    my $formTopicObj;

    if ( not Foswiki::Func::webExists($saveweb) ) {
        Foswiki::Func::createWeb( $saveweb, '_default' );
    }
    if ( not Foswiki::Func::webExists($formWeb) ) {
        Foswiki::Func::createWeb( $formWeb, '_default' );
    }
    $formTopicObj =
      Foswiki::Meta->new( $session, $formWeb, $formTopic, gen_form() );
    $formTopicObj->save();
    $formTopicObj->finish();

    return;
}

sub genFIELDs {
    my ( $topicObject, $count, $csvRow, @csvcol2schemarow ) = @_;
    my @fields;
    my $csvColI = 0;

    if ( not scalar(@csvcol2schemarow) ) {
        my $num = scalar( @{$csvRow} );

        if ( $num < scalar(@schema) ) {
            $num = scalar(@schema);
        }
        @csvcol2schemarow = 0 .. ( $num - 1 );
    }

    # Loop over a list of schema rows
    foreach my $schemaRowI (@csvcol2schemarow) {
        my $schemaRow = $schema[$schemaRowI];

        if ( exists $schemaRow->{split_fn} ) {
            my @splitfields = $schemaRow->{split_fn}->(
                $topicObject, $count, $csvRow->[$csvColI], $csvRow, $csvColI,
                $schemaRowI
            );

            if ( scalar(@splitfields) ) {
                push( @fields, @splitfields );
            }
            $csvColI += 1;
        }
        elsif ( exists $schemaRow->{skip_fn} ) {
            if ( defined $schemaRow->{skip_fn} ) {
                $schemaRow->{skip_fn}->(
                    $topicObject, $count, $csvRow->[$csvColI], $csvRow,
                    $csvColI, $schemaRowI
                );
            }
            $csvColI += 1;
        }
        elsif ( exists $schemaRow->{do_fn} ) {
            my @splitfields = $schemaRow->{do_fn}->(
                $topicObject, $count, $csvRow->[$csvColI], $csvRow, $csvColI,
                $schemaRowI
            );

            if ( scalar(@splitfields) ) {
                push( @fields, @splitfields );
            }
        }
        else {
            my %field = %{$schemaRow};    #make a copy

            $field{value} = $csvRow->[$csvColI];
            push( @fields, \%field );
            $csvColI += 1;
        }
    }

    return @fields;
}

sub createTopic {
    my ( $count, $row ) = @_;
    my $topicname = 'Insect' . sprintf( "%06d", $count );
    my $topicObject;
    my @rowFields;

    $topicname =~ s/[\W]/_/g;
    print "Creating $topicname, count $count...\n";
    ($topicObject) = Foswiki::Func::readTopic( $saveweb, $topicname );
    @rowFields = genFIELDs( $topicObject, $count, $row );
    $topicObject->put( 'FORM', { name => $formname } );
    $topicObject->putAll( 'FIELD', @rowFields );
    $topicObject->save();
    $topicObject->finish();

    return;
}

sub run {
    my ($input) = @_;
    my $count   = 0;
    my $csv     = Text::CSV->new(
        { auto_diag => 1, binary => 1 } )    # should set binary attribute.
      or die "Cannot use CSV: " . Text::CSV->error_diag();
    ($csvTopicObj) =
      Foswiki::Func::readTopic(
        Foswiki::Func::normalizeWebTopicName( $saveweb, $csvtopic ) );
    my $fh;

    $fh = $csvTopicObj->openAttachment( $csvfile, '<' );
    $csv->getline($fh);                      #skip the first line
    while ( my $row = $csv->getline($fh) ) {
        createTopic( $count, $row );
        $count = $count + 1;
    }
    $csv->eof or $csv->error_diag();
    close $fh;
    $csv->eol("\n");

    return;
}

sub get_csv {
    my $ua = LWP::UserAgent->new();

    $ua->timeout(15);
    ($csvTopicObj) = Foswiki::Func::readTopic(
        Foswiki::Func::normalizeWebTopicName(
            $Foswiki::cfg{SystemWebName}, $csvtopic
        )
    );

    if ( not $csvTopicObj->hasAttachment($csvfile) ) {
        my $tmpdir = Foswiki::Func::getWorkArea('MigrationScriptsContrib');
        my $response;

        print "Downloading to $csvtopic/$csvfile from $csvurl\n";
        $response = $ua->get($csvurl);
        if ( $response->is_success ) {

            #        if (1) {
            my $zipfile = File::Spec->catfile( File::Spec->splitdir($tmpdir),
                'archive.zip' );
            my $csvpath =
              File::Spec->catfile( File::Spec->splitdir($tmpdir), $csvfile );
            my $zip = Archive::Zip->new();

            # SMELL: Why does this need to be untainted?
            $zipfile =~ /^(.*)$/;
            $zipfile = $1;
            print "Working on $zipfile\n";
            open( my $fh, '>', $zipfile ) or die $!;
            binmode $fh;
            print $fh $response->content;
            close($fh);

            if ( $zip->read($zipfile) == AZ_OK ) {
                my $zipmember = $zip->memberNamed($csvfile);
                $zipmember->extractToFileNamed($csvpath);
                print "Extracting $csvfile from $zipfile\n";
                $zip->extractMember($csvfile);
                print "Attaching $csvfile to $csvtopic\n";
                open( my $fh, '<', $csvpath ) or die $!;
                $csvTopicObj->attach(
                    name    => $csvfile,
                    stream  => $fh,
                    comment => 'Added by '
                      . $Foswiki::cfg{ToolsDir}
                      . '/InsectsDemo.pm'
                );
                close($fh);
            }
            else {
                die "Failed to read $zipfile";
            }
        }
    }

    return;
}

get_csv();
gen_schema();
set_up();
run();

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2011 Paul.W.Harvey@csiro.au, TRIN http://trin.org.au/ &
Centre for Australian National Biodiversity Research http://anbg.gov.au/cpbr
Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
