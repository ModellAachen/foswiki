###usr/bin/perl -w
#
# @(#)$Id: cache.pl 13643 2007-05-06 09:04:07Z WillNorris $ GNU (C) by Peter Klausner 2003
#

# customize manually to save TWiki load & compile time...
$sep   = "__";                   # "?" as in URLs doesn't work on windows
$data  = "c:/opt/twiki/data";
$cache = "c:/opt/twiki/cache";
$render  = "perl c:/opt/twiki/bin/render.pl"; # you might need full path!
$webhome = "WebHome";
$maxage  = 24 * 14;                           # default expiration after ~ hours

# initialize data...
use CGI::Carp;
my $mtime = 9;
my $query = $ENV{'QUERY_STRING'};
my $path  = $ENV{'PATH_INFO'};

# extend path if just dir = web given:
$path =~ s:/*$:/$webhome: if -d "$data$path";

# strip out special caching parm maxage:
$query      =~ s/^maxage=([0-9.-]+)&*// and $maxage = $1
  or $query =~ s/&maxage=([0-9.-]+)//   and $maxage = $1;

# the file names are:
$source = "$data$path.txt";
$entry  = "$cache$path$sep$query";

# handle max age parm...
if ( $maxage == 0 ) {    # re-render on _any_ change in web, i.e.
    $source =~ s:/[^/]*$::;    # compare with directory date
    $maxage = 9999;
}
elsif ( $maxage < 0 ) {        # force flushing cache
    unlink <$cache$path$sep*>;
}

# get times:
my $t_cache  = ( stat "$entry" )[$mtime];
my $t_change = ( stat "$source" )[$mtime];

if (
    ( $t_cache > $t_change )    # cached copy is newer
    and ( $t_cache + $maxage * 3600 > time() )
  )                             # and expires in the future
{
    print STDERR "get s:$source c:$t_cache s:$t_change m:$maxage\n";
    open CACHE, "<$entry" or die "can't open $entry, $!";
    while (<CACHE>) { print; }    # start sending asap
    close CACHE;
}
else {
    print STDERR "put s:$source c:$t_cache s:$t_change m:$maxage\n";
    open RENDER, "$render @ARGV |" or die "can't render: $!";
    open CACHE, ">$entry";        # ignore error
    while (<RENDER>) {
        print;
        print CACHE;
    }
    close CACHE;
    close RENDER;
}

