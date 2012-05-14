# /usr/bin/perl -w
use strict;

#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
################################################################################
package TWiki::Plugins::PageStatsPlugin;
use vars qw( @ISA $VERSION $RELEASE );

use TWiki::Plugins::OoPlugin;

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

@ISA = ('TWiki::Plugins::OoPlugin');

sub new {
    my $classname = shift;
    my $self      = $classname->SUPER::new(@_);
    $self->_init(@_);
    return $self;
}

sub DESTROY {
    my $self = shift;
}

sub _init {
    my $self = shift;
    $self->SUPER::_init(@_);

# Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
#    $exampleCfgVar = $thePlugin->getPreferencesValue( 'shortdescription' ) || 'defaultValue';

    $self->init_();
    return 1;
}

################################################################################

sub handlePageStats {
    my ($attributes) = @_;

    my $topic =
         &TWiki::Func::extractNameValuePair( $attributes, "" )
      || scalar &TWiki::Func::extractNameValuePair( $attributes, "topic" )
      || $TWiki::topicName;
    my $web = scalar &TWiki::Func::extractNameValuePair( $attributes, "web" )
      || $TWiki::webName;

    #    my ( $meta, $page ) = &TWiki::Func::readTopic( $web, $topic );
    #    my @text = $meta->find( 'FILEATTACHMENT' );

    my $dd = TWiki::Func::getDataDir();

 #my @pagestats = `grep $web\\.$topic $dd/log*.txt | grep -E \\(view\\|save\\)`;
    opendir DATADIR, $dd or die "Can't open DataDir: $!";
    my @pagestats = ();
    foreach my $l ( grep /^log.*\.txt$/, readdir DATADIR ) {
        open( my $logfile, "< $dd/$l" ) or next;
        while (<$logfile>) {
            push @pagestats, $_ if /$web\.$topic/ && /view|save/;
        }
    }
    closedir DATADIR;

    my $maxEntries =
         scalar &TWiki::Func::extractNameValuePair( $attributes, "max" )
      || scalar @pagestats;
    $maxEntries = scalar @pagestats if $maxEntries > scalar @pagestats;

#    &TWiki::Func::writeDebug( "dataDir=[$TWiki::dataDir]" ) if $debug;
#    &TWiki::Func::writeDebug( "topic=[$topic], web=[$web], max=[$maxEntries]" ) if $debug;

    my @rpagestats = ( reverse @pagestats )[ 0 .. $maxEntries - 1 ];
    my $pagestats  = '';
    map { s/^(.+?log\d{6}\.txt:)//, s/ (save) / *$1* /, $pagestats .= "$_" }
      @rpagestats;

    return
        qq{<div class="PageStats">\n}
      . "Page Stats<br/>\n"
      . "| *timestamp* | *user* | *action* | *page* | *?* | *ip address* |\n"
      . $pagestats
      . '</div>';
}

sub _commonTagsHandler {
    my $self = shift;
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    $self->SUPER::_commonTagsHandler(@_);

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%
    $_[0] =~ s|%PAGESTATS%|handlePageStats()|geo;
    $_[0] =~ s|%PAGESTATS{(.*?)}%|handlePageStats($1)|geo;
}

################################################################################

use vars qw( $thePlugin );

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;
    $thePlugin = __PACKAGE__->new(
        topic      => $topic,
        web        => $web,
        user       => $user,
        installWeb => $installWeb,
        name       => 'PageStats',
    );
    return 1;
}

################################################################################

1;
