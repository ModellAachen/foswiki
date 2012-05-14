#! /usr/bin/perl -w
use strict;
use Carp;

#use sigtrap 'handler' => \&my_handler;

#sub my_handler {
#   use Data::Dumper;
#   print Dumper(       );
#}

# TWikiDeploymentSpider
# Purpose: To locate and catelog all reachable TWiki installations
#          so that meaningful knowledge can be obtained about
#             1 the adoption rates of TWiki and its components
#             2 the usage patterns of the installations by their members

# Description:
#    1 Locates TWiki installs (uses Google SOAP API)
#    2 Finds common information from DefaultPreferences
#    2 Catalog users
#    2 Discovers webs
#    3 Writes found information information into a TWiki topic
#
# This script writes Wiki Topics of the form WwwDotSitenameDotOrg in the web Dep
loymentSpider

  # See facts_as_wikitopic for the output format

  package TWikiSite;

sub new {
    my $self = {};
    shift;
    my ($sitename) = (@_);
    $self->{USERS} = undef;
    $self->{SITE}  = $sitename;
    bless($self);    # but see below
    return $self;
}

sub site {
    my $self = shift;
    if (@_) { $self->{SITE} = shift }
    return $self->{SITE};
}

sub home {
    my $self = shift;
    if (@_) { $self->{HOME} = shift }
    return $self->{HOME};
}

sub users {
    my $self = shift;
    if (@_) { @{ $self->{USERS} } = @_ }
    return @{ $self->{USERS} };
}

sub user_count {
    my $self = shift;
    return scalar( @{ $self->{USERS} } );
}

sub version {
    my $self = shift;
    if (@_) { $self->{VERSION} = shift }
    return $self->{VERSION};
}

sub founded {
    my $self = shift;
    if (@_) { $self->{FOUNDED} = shift }
    return $self->{FOUNDED};
}

sub webs {
    my $self = shift;
    if (@_) { @{ $self->{WEBS} } = @_ }
    return @{ $self->{WEBS} };
}

sub web_count {
    my $self = shift;
    return scalar( @{ $self->{WEBS} } );
}

sub statistics {
    my $self = shift;
    my $web = shift || die "which web?";
    if (@_) { @{ $self->{"STATISTICS,$web"} } = @_ }
    return @{ $self->{"STATISTICS,$web"} };
}

sub facts {
    my $self = shift;
    my $ans;
    $ans .= "---+" . $self->site . ":\n";
    $ans .= "\t* home: " . $self->home . "\n";
    $ans .= "\t* founded: " . $self->founded . "\n";
    $ans .= "\t* version: " . $self->version . "\n";
    $ans .= "\t* users: " . $self->user_count . "\n";
    $ans .=
        "\t* webs: "
      . $self->web_count . " ("
      . join( ", ", $self->webs() ) . ")\n";
    return $ans;
}

sub facts_as_wikitopic {
    my $self = shift;
    my $web  = join( ", ", $self->webs() );
    my $ans  = <<EOF;
----+ WwwDotSitenameDotOrg
----++ Vital facts
| Site Address | ${[$self->site()]} |
| Site Suffix | org |
| Site Toolname | SiteName | (I'd use this as the site identifier except I don't
 know that everyone sets it) |
| Home | $self->home |
| Founded | $self->founded() |
| Version | $self->version() |
| Number webs | $self->web_count() |
| Number of users | $self->user_count() |
| Users | http://sitename/..../Main/WikiUsers
| Webs names |
| TWiki prefs | http://sitename/..../TWiki/DefaultPreferences
| Plugins installed |
| Main skin |

---++ Web Statistics
---+++ Web 1
<insert table here> %WEBSTATSCHART%

---++++ Web 2
<insert table here> %WEBSTATSCHART%
EOF
    return $ans;
}

sub facts_stats {
    my $self = shift;
    my $ans;
    foreach my $web ( $self->webs() ) {
        $ans .= "---++ Statistics for $web\n";
        $ans .= join( "\n", $self->statistics($web) );
    }
    return $ans;
}

sub dump {
    my $self = shift;
    use Data::Dumper;
    print Dumper($self);
}

sub asString {
    my $self = shift;
    return $self->{SITE} . "\n\t" . join( "\n\t", @{ $self->{USERS} } ) . "\n";

}

package main;

use Net::Google;
use constant LOCAL_GOOGLE_KEY => 'jeChg/9QFHKhVRBzXIraA2UOzPwHdnvO';

# use constant LOCAL_GOOGLE_KEY => 'R26igvFQFHJE6oQOLzevOoa1lNR2RoIG';

my $google = Net::Google->new( key => LOCAL_GOOGLE_KEY );
my $search = $google->search();

# Search interface

$search->query(qw(WikiUsers add yourself -Changed));
$search->lr(qw(en fr));
$search->ie("utf8");
$search->oe("utf8");
$search->starts_at(1);

# $search->max_results(800);
$search->max_results(1);

# map { print $_->title()."\n"; } @{$search->results()};

# or...
print "\n%TOC%\n";

foreach my $r ( @{ $search->response() } ) {

    #   print "Search time :".$r->searchTime()."\n";

    # returns an array ref of Result objects
    # the same as the $search->results() method
    map { get_details( $_->URL() ); } @{ $r->resultElements() };
}

sub write_debug {
    my ($string) = @_;
    print STDERR $string . "\n";
}

sub get_details {
    use URI::URL;

    my ($twiki_users) = @_;
    write_debug $twiki_users;

    my $users_url = new URI::URL($twiki_users);

    my $site = $users_url->netloc();
    eval { reg_site( $site, $users_url ); };
    print(
        "---+ $site Error\n%RED%$! $@ \n (http://$site ($twiki_users) WebHome n
ot standard?) %ENDCOLOR%\n"
    ) if ($@);
}

sub reg_site {
    my ( $siteurl, $usersurl ) = @_;

    my $baseurl = $usersurl;
    $baseurl =~ s!Main/WikiUsers!!;

    #  print "$siteurl: \n";
    #  print "\t$baseurl \n";
    my $site = new TWikiSite($siteurl);
    my @webs =
      get_wikiweblist( $baseurl . "/TWiki/DefaultPreferences", $siteurl );
    $site->webs(@webs);

    $site->home( get_home($baseurl) );
    $site->users( get_users($usersurl) );

    $site->version( get_version($baseurl) );

    use Date::Manip;
    my $oldest_moyr = Date::Manip::ParseDate("today");
    foreach my $web (@webs) {
        next if ( $web eq "" );    #HACK

        #    print "Getting stats for $web\n";
        my ( $stats, $firstmo ) = get_webstatistics( $baseurl, $web );
        $site->statistics( $web, $stats );
        if ( Date::Manip::Date_Cmp( $firstmo, $oldest_moyr ) < 0 ) {

            #      print "$firstmo is older than $oldest_moyr\n";
            $oldest_moyr = $firstmo;
        }
    }
    $site->founded($oldest_moyr);

    #   $site->dump();

    #   print $site->facts();
    report( $siteurl, $site->facts_as_wikitopic() );

    #   print $site->facts_stats();
    #  print $site->asString();
}

sub report {
    my ( $site, $topic_contents ) = @_;
    my $filename = "SiteReport/$site.txt";
    my $fh       = new IO::File ">$filename";
    unless ( defined $fh ) {
        print STDERR "Can't write to $filename\n";
        return;
    }

    print $fh "$topic_contents\n";
    $fh->close;
}

sub get_version {
    my ($baseurl) = @_;
    my $url = $baseurl . "TWiki/WebHome";

    my @content = ( split /\n/, get($url) );
    my $line;
    my $version;
    foreach $line (@content) {
        next
          unless $line =~ m!This site is running TWiki version <strong>(.*)</str
ong>!;

        #     print $line;
        $version = $1;
        last;
    }

    #  print "VERSION: $version\n\n";
    return $version;
}

sub get_home {
    my ($baseurl) = @_;
    my $url = $baseurl . "TWiki/WebHome";    #HACK
    return $url;
}

sub get_users {
    my ($url) = @_;
    my $content = rawget($url);

    my @arr;
    foreach my $line ( split /\n/, $content ) {
        next unless $line =~ /   */;
        next if $line =~ /name=/;

        #     print "$line:\n";
        my ( $all, $user, $date ) = split /\s*\* (.*?) - (.*)/, $line;

        #     print "\t$user => $date \n";
        push @arr, [ $user => $date ];
    }

    #  my @arr = ("BettyJoMiller" => "27 Jun 2003",
    #          "BonnieJohnson" => "22 Aug 2003",
    #          "MartinCleaver" => "5 Sep 2003"
    #  );
    return (@arr);
}

sub get_skins {

}

sub get_plugins {

}

sub get_wikiweblist {
    my ( $url, $site_url ) = @_;
    my @content = ( split /\n/, get($url) );
    my $line;
    my $webline;
    foreach $line (@content) {
        next unless $line =~ /WEBLIST/;
        $webline = $line;
        last;
    }

    #  print $webline."\n\n";

    my @webs;
    while ( $webline =~ /href\s*=\s*\"([^\"]+)\"/gi ) {
        ( my $web_url = $1 ) =~ s|/edit/|/view/|;
        my $web = $web_url;
        $web =~ s!(.+?)\?.*!$1!;   # remove url parameters (after ?) not that it
        's really needed...?
    $web =~ s!.*/(.*?)/(.*)!$1!;   # take only the webname (NB. WebHome should b
e $2 here;
#    $web_url = "http://$site_url/$web_url" unless $web_url =~ /:/;
    push @webs, $web;
  }

  # local $, = ', '; print @ans;       # change default string to print between 
list elements
  # print "@ans";                      # or, prints spaces between 
  # print map { "[$_] " } @web_urls;   # or, this is handy, too (i like surround
ing the variables with []'s)

  return @webs;
}

sub get_webstatistics {
  my ($baseurl, $web) = @_;


  my $url = $baseurl."$web/WebStatistics";

#  print "$url\n";
  my @content = (split /\n/, rawget($url) );

        my $ans;
        my $line;
        my $lastmoyr = "";
        foreach $line (@content) {
              next unless $line =~ /^\|/;
              next if $line =~ /statDate/;

              #     print $line;
              my ( $junk, $moyr, $views, $saves, $uploads, $topicviews,
                  $topicontribs )
                = s
plit /\|/, $line;
     $ans .= "|$moyr|$views|$saves|$uploads|\n";
     $lastmoyr = $moyr;
  }
  $lastmoyr =~ s/\s(.*)/$1/;
  return ($ans,$lastmoyr);
}



sub get {
 my ($url) = @_;

 # Create a user agent object
  use LWP::UserAgent;
  my $ua = new LWP::UserAgent;

  # Create a request
  my $req = new HTTP::Request GET => $url;

  # Pass request to the user agent and get a response back my $res =
                $ua->request($req);

              # Check the outcome of the response
              if ( $res->is_success ) {

                  #      print $res->content;
              }
              else {
                  print "Couldn't get $url\n";
                  return ("No results");
              }
              return $res->content;
        }

        sub rawget {
              my ($url) = @_;

              # print "rawget $url\n";
              $url .= "?skin=plain&raw=on";
              return get($url);
        }
