package Foswiki::Plugins::ICalPlugin::DataICal;

# alternative workaround see http://foswiki.org/Support/Question590
#
# Data::ICal is broken. This problem has been reported to the CPAN
# maintainer, and awaits a fix. There may already be a new version
# on CPAN, or you can patch it locally if you have the skills:
# --- /usr/local/share/perl/5.10.1/Data/ICal/Entry.pm    2010-07-01 16:51:12.000000000 +0100
# +++ /usr/local/share/perl/5.10.1/Data/ICal/Entry.pm    2010-07-01 17:01:55.000000000 +0100
# MESSAGE
#         $e .= <<'MESSAGE';
# @@ -487,5 +487,6 @@
#      die "Can't parse VALARM with action $action"
#          unless exists $_action_map{$action};
# -    my $alarm_class = "Data::ICal::Entry::Alarm::" . $_action_map{$action};
# +    my $x = $_action_map{$action};
# +    my $alarm_class = "Data::ICal::Entry::Alarm::" . $x;
#      eval "require $alarm_class";
#      die "Failed to require $alarm_class : $@" if $@;

use warnings;
use strict;

use Data::ICal ();
our @ISA = ('Data::ICal');

sub parse_object {
    my ( $self, $object ) = @_;

    my $type = lc($object->{type} || '');

    if ($type eq 'vtodo') {
      return {};
    }

    if ($type eq 'vevent') {
      # clear all subobjects of events;
      # at least valarms provokes an Insecure dependency in eval while running with -T switch warning
      $object->{objects} = undef;
    }


    return $self->SUPER::parse_object($object);
}

1;
