# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
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

=pod

---+ package Foswiki::Plugins::GeoPlugin

=cut

package Foswiki::Plugins::GeoPlugin;
use strict;

require Foswiki::Func;
require Foswiki::Plugins;

#use Data::Dumper qw( Dumper );

our $VERSION = '$Rev: 2990 $';
our $RELEASE = '$Date: 2009-03-10T18:21:06.426681Z $';
our $SHORTDESCRIPTION =
'geo-location services, providing lookup features from IP address, domain name, or physical address';
our $NO_PREFS_IN_TOPIC = 1;

################################################################################

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Example code of how to get a preference value, register a macro
    # handler and register a RESTHandler (remove code you do not need)

    Foswiki::Func::registerTagHandler( GEO => \&_GEOTAG );
    Foswiki::Func::registerTagHandler(
        REMOTE_IP_ADDRESS => \&_REMOTE_IP_ADDRESS );

    # Plugin correctly initialized
    return 1;
}

################################################################################

sub _REMOTE_IP_ADDRESS {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    return $session->{request}->{remote_address};
}

# TODO: time_zone
my @mirror_fields = qw( country_code latitude longitude
  time_zone
  region city postal_code
  area_code
  metro_code
  country_name
  continent_code
);
my @display_fields = ( @mirror_fields, qw( method ) );

################################################################################

sub _GEOTAG {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    my $query  = $params->{_DEFAULT};
    my $format = $params->{format}
      || (
        '| $query | ' . join( ' | ', map { "\$$_" } @display_fields ) . ' |' )
      || '$country_code ($lat,$lng)';

    my $text = '';
    my $result;

    $result->{query} = $query;

# SMELL: there is an even better IP regular expression (one that won't match 256.300.400.1500, for example)
#    if ( $query =~ m{^(\d+\.){3}\d+$} or $query =~ m{\.} ) {
    if ( $query =~ m{^\d+\.\d+\.\d+\.\d+$} or $query =~ m{\.} ) {

        # only CPAN:Geo::IP can handle IP addresses
        require Geo::IP;
        my $gi =
          ( $session->{GeoPlugin}->{geo_ip}->{self} ||=
              Geo::IP->open('/usr/local/share/GeoIP/GeoLiteCity.dat') )
          ;    #, 'GEOIP_STANDARD' ) );

        my $cache =
          $session->{GeoPlugin}->{geo_ip}->{cache}->{$query}->{result};

        #	$text .= '<pre>cache=' . Dumper( $cache ) . '</pre>';
        my $record = $cache || $gi->record_by_name($query);

        #	$text .= '<pre>record=' . Dumper($record) . '</pre>';
        if ($record) {
            foreach my $field (@mirror_fields) {

                # TODO: remove '?' when done debugging/development
                $result->{$field} = $record->$field || '';    #'?';
            }
        }

        # mirror to (lat,lng) versions of (latitude,longitude)
        $result->{lat} = $result->{latitude};
        $result->{lng} = $result->{longitude};

        $result->{method} = 'Geo::IP';

        $session->{GeoPlugin}->{geo_ip}->{cache}->{$query}->{result} = $record;

    }
    else {

# only Geo::GeoNames can do physical address lookup (and only to a certain degree, at that :/ )

        require Geo::GeoNames;
        my $geo =
          ( $session->{GeoPlugin}->{geo_geonames} ||= Geo::GeoNames->new() );

=pod

            'population' => '1640589',
	   'elevation' => {},
            'adminName1' => 'Jalisco',
            'fclName' => 'city, village,...',
				   'adminCode2' => {},
            'geonameId' => '4005539',
	   'timezone' => {
                    'dstOffset' => '-5.0',
                    'content' => 'America/Mexico_City',
                  'gmtOffset' => '-6.0'
	    },
            'fcode' => 'PPL',
            'fcodeName' => 'populated place',
            'adminCode1' => '14',
	    'adminName2' => {},
            'fcl' => 'P'
=cut

        my $geo_map = {
            country_code   => 'countryCode',
            country_name   => 'countryName',
            region         => 'adminName1',
            city           => 'name',
            postal_code    => undef,
            latitude       => 'lat',
            lat            => 'lat',
            longitude      => 'lng',
            lng            => 'lng',
            area_code      => undef,
            metro_code     => undef,
            continent_code => 'continentCode',
        };

        my $record = $geo->search( q => $query, maxRows => 1, style => 'FULL' );

        #	print STDERR Dumper( $record );
        if ( scalar @$record ) {

            #	    print STDERR "record=", Dumper( $record );
            $record = $record->[0] if exists $record->[0];
            foreach my $field (@mirror_fields) {
                my $key = $geo_map->{$field};

                # TODO: remove '?' when done debugging/development
                $result->{$field} = defined $key ? $record->{$key} : '';   #'?';
            }
            $result->{time_zone} = $record->{timezone}->{content};
        }
        $result->{method} = 'Geo::GeoNames';
    }

    #    $text .= "<pre>query=[$query]</pre><br/>\n";
    $text .= _format( $format, $result );

    return $text;
}

sub _format {
    my ( $format, $record ) = @_;
    my $text = $format;

    #    $text .= "_format($format,".Dumper($record).")<br/>\n";
    return '' unless $record;

    my @var_fields = ( @display_fields, qw( query lat lng ) );
    foreach my $field (@var_fields) {
        $record->{$field} && $text =~ s{\$$field}{$record->{$field}}ge;
    }

    #    my $query = '=%<nop>GEO{"' . $record->{query} . '"}%=';
    #    $text =~ s{\$query}{$query}ge;

    return $text;
}

1;
__END__
This copyright information applies to the GeoPlugin:

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# GeoPlugin is # This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.
