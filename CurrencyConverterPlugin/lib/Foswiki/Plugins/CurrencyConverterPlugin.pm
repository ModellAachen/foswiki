# CurrencyConverter.pm
# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# For CurrencyConverter.pm:
# Copyright (C) 2010, Henrik Rusche, h.rusche@wikki-gmbh.de
# Copyright (C) 2010, Oliver Krüger, oliver@wiki-one.net
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

package Foswiki::Plugins::CurrencyConverterPlugin;

use strict;
require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version

our $VERSION = '$Rev: 1$';

our $SHORTDESCRIPTION = 'Currency Converter using a mysql database';

our $NO_PREFS_IN_TOPIC = 1;

#=begin TML
#=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Register the macros
    Foswiki::Func::registerTagHandler( 'CONVERTCUR', \&_convertCurrency );

    # Plugin correctly initialized
    return 1;
}

sub _convertCurrency {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    #printf STDERR "%i\n", exists($params->{amount});

    my $amount = 1;
    if ( exists( $params->{amount} ) ) {
        $amount = defined( $params->{amount} ) ? $params->{amount} : 0.0;
    }
    my $from = $params->{from} || "EUR";
    my $to   = $params->{to}   || "EUR";

    my $date;
    if ( exists( $params->{date} ) ) {
        $date = $params->{date};
    }
    else {
        my @d = (localtime)[ 5, 4, 3 ];
        $d[0] += 1900;
        $d[1] += 1;
        $date = sprintf( "%s-%s-%s", @d );
    }

    #printf STDERR "%s, %s, %s, %f\n", $from, $to, $date, $amount;

    require DBI;

    my $dbname   = "currency";
    my $username = "guest";
    my $pw       = "";

    my $db =
      DBI->connect( "DBI:mysql:$dbname", $username, $pw, { RaiseError => 1 } )
      || print STDERR("Error accessing database: $@");

    if ( $from eq $to ) {
        return $amount;
    }
    elsif ( $from eq "EUR" ) {
        return $amount * fetch_rate_EUR( $db, $to, $date );
    }
    elsif ( $to eq "EUR" ) {
        return $amount / fetch_rate_EUR( $db, $from, $date );
    }
    else {
        return $amount * fetch_rate_derived( $db, $to, $from, $date );
    }
}

sub fetch_rate_EUR {
    my ( $db, $to, $date ) = @_;

    my $req;
    eval {
        $req = $db->prepare(
            sprintf(
"SELECT rate FROM $to WHERE date <= '%s' ORDER BY date DESC LIMIT 1;",
                $date )
        );
        $req->execute;
    };

    if ($@) {
        print STDERR "Error accessing database: $@\n";
        return;
    }

    return $req->fetchrow_array();
}

sub fetch_rate_derived {
    my ( $db, $to, $from, $date ) = @_;

    my $req;
    eval {
        $req = $db->prepare(
            sprintf(
"SELECT $to.rate/$from.rate FROM $to,$from WHERE $to.date = $from.date AND $to.date <= '%s' ORDER BY $to.date DESC LIMIT 1;",
                $date )
        );
        $req->execute;
    };

    if ($@) {
        print STDERR "Error accessing database: $@\n";
        return;
    }

    return $req->fetchrow_array();
}

