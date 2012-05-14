# See bottom of file for license and copyright information
package Foswiki::Form::Datetime;

use strict;
use warnings;

use Foswiki::Form::FieldDefinition ();
our @ISA = ('Foswiki::Form::FieldDefinition');

use DateTime::Format::Strptime;

# Predefine local time for performance
our $LOCAL_TZ = DateTime::TimeZone->new( name => 'local' );

# Create 4 possible date parsers
# This could probably done smarter, see parseDateTime below.

# Parser: timezone offset plus timezone name
our $PARSER_TZOFFSET_TZNAME = DateTime::Format::Strptime->new(
    pattern   => '%Y-%m-%d %H:%M:%S %z %O'
);

# Parser: timezone name
our $PARSER_TZNAME = DateTime::Format::Strptime->new(
    pattern   => '%Y-%m-%d %H:%M:%S %O'
);

# Parser: timezone offset
our $PARSER_TZOFFSET = DateTime::Format::Strptime->new(
    pattern   => '%Y-%m-%d %H:%M:%S %z'
);

# Parser: simple
our $PARSER = DateTime::Format::Strptime->new(
    pattern   => '%Y-%m-%d %H:%M:%S'
);

our $ISO_FORMAT = '%Y-%m-%dT%H:%M:%S%z';


=begin TML

Stores a date value (epoch seconds) together with the human readable ISO date string equivalent.

=cut

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    my $size  = $this->{size} || '';
    $size =~ s/[^\d]//g;
    $size = 40 if ( !$size || $size < 1 );
    $this->{size} = $size;
    $this->{showLocalTime} = 1; # translate dates to local time?
    return $this;
}

=begin TML

Translates a date string to local time and formatted using the Configure setting {DefaultDateTimeFormat}.

=cut

sub renderValueForDisplay {
    my ( $this, $dateString ) = @_;

    if ($dateString) {
        if ($this->{showLocalTime}) {
            my $dateTime = parseDateTime($dateString);
            $dateTime->set_time_zone( $LOCAL_TZ );
            return $dateTime->strftime( $Foswiki::cfg{DefaultDateTimeFormat} );
        } else {
            return $dateString;
        }
    }
    else {
        return '';
    }
}

=begin TML

Renders the edit field without any date translation.
The field attribute 'data-isodate' is added for working with JavaScript and contains the date in ISO 8601 format.

=cut

sub renderForEdit {
    my ( $this, $topicObject, $dateString ) = @_;

    my $dateTime = parseDateTime($dateString);
    $dateTime->set_time_zone( $LOCAL_TZ );
    my $isodate = $dateTime->iso8601();
    my $timezone = $dateTime->strftime('%z');
    
    my $fieldHtml = CGI::textfield(
        {
            name  => $this->{name},
            id    => 'id' . $this->{name},
            size  => $this->{size},
            value => $dateString,
            class => $this->can('cssClasses')
            ? $this->cssClasses( 'foswikiInputField',
                'foswikiEditFormDateField' )
            : 'foswikiInputField foswikiEditFormDateField',
            'data-isodate' => $isodate,
            'data-timezone_offset' => $timezone
        }
    );

    return ( '', $fieldHtml );
}

=begin TML

---++ ObjectMethod createMetaKeyValues( $query, $meta, $keyvalues ) -> $keyvalues

Store epoch value for faster sorting.

=cut

sub createMetaKeyValues {
    my ( $this, $query, $meta, $keyvalues ) = @_;

	my $dateTime = parseDateTime( $keyvalues->{value} );
	if ( defined $dateTime ) {
		$keyvalues->{epoch} = $dateTime->epoch();
	}
    return $keyvalues;
}

=begin TML

---++ StaticMethod parseDateTime( $dateString ) -> $dateTime

Tries to create a DateTime object from a date string.

Another way of doing this is using DateTime::Format::Builder (http://search.cpan.org/~drolsky/DateTime-Format-Builder/) but I haven't found out how it can return just the first right parser. -- AC

=cut

sub parseDateTime {
    my ($dateString) = @_;

    my $dateTime;
    eval {
        $dateTime =
          $PARSER_TZOFFSET_TZNAME->parse_datetime(
            $dateString);
#        print STDERR "PARSER_TZOFFSET_TZNAME:$dateTime\n" if $dateTime;
    } or do {
        eval {
            $dateTime =
              $PARSER_TZOFFSET->parse_datetime(
                $dateString);
            print STDERR "PARSER_TZOFFSET:$dateTime\n" if $dateTime;
        } or do {
            eval {
                $dateTime =
                  $PARSER_TZNAME->parse_datetime(
                    $dateString);
                print STDERR "PARSER_TZNAME:$dateTime\n" if $dateTime;
            } or do {
                eval {
                    $dateTime =
                      $PARSER->parse_datetime(
                        $dateString);
                    print STDERR "PARSER:$dateTime\n" if $dateTime;
                } or do {

                    #
                };
            };
        };
    };
    return $dateTime;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
