# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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
# =========================
#
# This WeatherPlugin (C) 2004 Andre Bonhote, COLT Telecom <andre@colt.net>
#

# =========================
package TWiki::Plugins::WeatherPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $partnerId $license
);

use Weather::Com;

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'WeatherPlugin';

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG");

 # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $partnerId = TWiki::Func::getPluginPreferencesValue("PARTNERID");
    $license   = TWiki::Func::getPluginPreferencesValue("LICENSE");

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    $_[0] =~ s:%WEATHER{(.*?)}%:&_handleWeatherTag($1,$2):geo;
}

sub _handleWeatherTag {
    my ($city) = @_;
    my $return = "";

    my %params = (
        'current'    => 1,
        'partner_id' => $partnerId,
        'license'    => $license,
    );

    TWiki::Func::writeDebug("- TWiki::Plugins::${pluginName} - $city")
      if $debug;

  BLOCK: {
        unless ($city) {
            TWiki::Func::writeDebug(
                "- TWiki::Plugins::${pluginName} - No city given")
              if $debug;
            last BLOCK;
        }
        my $request = new Weather::Com(%params);

        if ( $city =~ /^[A-Z]{4}[0-9]{4}$/ ) {
            my $weather = $request->get_weather($city);
            my $temp    = $weather->{cc}->{tmp} . " " . $weather->{head}->{ut};
            my $humi    = $weather->{cc}->{hmid};
            my $icon    = $weather->{cc}->{icon};
            my $ccity   = $weather->{loc}->{dnam};

            $return .= qq(
<div><table bgcolor="#eeeeee">
  <tr><td align='center'><em>$ccity</em></td></tr>
  <tr><td align='center'><img src="/images/weather/32/$icon.png" alt="icon"></td></tr>
  <tr><td align='center'>$temp / $humi%</td></tr>
</table></div>
);

        }
        else {
            my $location = $request->search($city);

            foreach ( keys %{$location} ) {
                my $weather = $request->get_weather($_);
                my $temp = $weather->{cc}->{tmp} . " " . $weather->{head}->{ut};
                my $humi = $weather->{cc}->{hmid};
                my $icon = $weather->{cc}->{icon};
                my $ccity = $weather->{loc}->{dnam};

                $return .= qq(
<div><table bgcolor="#eeeeee">
  <tr><td align='center'><em>$ccity</em></td></tr>
  <tr><td align='center'><img src="/images/weather/32/$icon.png" alt="icon"></td></tr>
  <tr><td align='center'>$temp / $humi%</td></tr>
</table></div>
);

            }
        }
    }

    return $return;

}

1;
