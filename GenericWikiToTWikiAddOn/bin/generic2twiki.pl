# This script migrates a wiki based on the original wiki code to a TWiki-based
#  wiki.  Note that it will overwrite any topics in your destination site that
#  have conflicting names, so it might be best to dedicate an entire site to
#  the one you're migrating.  TWiki supports multiple sites (see the TWiki docs)

# JamesTillman <JamesTillman@fdle.state.fl.us> or <jtillman@bigfoot.com>
# http://twiki.org/cgi-bin/view/Main/?topic=JamesTillman

use LWP;
use Data::Dumper;

use strict;
use vars qw/ $VERSION /;
use URI::Escape;

$VERSION = '0.1';

use constant DEBUG => 0;

# Set the following values if your Wikis require authentication
# in order to edit topics.
#
# Leave the WIKI_PORT and WIKI_REALM empty unless you use
#  Windows-based NT authentication on your wiki.  In that case,
#  for WIKI_PORT, you must use domainname:port, such as www.mywiki.com:80
#  and leave WIKI_REALM blank (don't forget to put your NT domain name in
#  front of your user id like this:  DOMAIN\UserID)
#
use constant DEST_WIKI_UID   => '';
use constant DEST_WIKI_PWD   => '';
use constant DEST_WIKI_PORT  => '';
use constant DEST_WIKI_REALM => '';
use constant SRC_WIKI_UID    => '';
use constant SRC_WIKI_PWD    => '';
use constant SRC_WIKI_PORT   => '';
use constant SRC_WIKI_REALM  => '';

# These two urls should point to the wiki server you're migrating to.  Be sure to
# change mynewwiki.com and WikiName to the correct values for your environment.
# The default Wiki name in TWiki is "Main"
use constant DEST_SAVE_URL =>
  'http://mynewwiki.com/wiki/bin/save/WikiName/$TOPIC$';
use constant TOPIC_SRC_URL =>
  'http://mynewwiki.com/wiki/bin/view/WikiName/$TOPIC$';

# The server name in this url should be changed to match the URL you would use
#  to access the topics on the wiki you're migrating away from.  In this example,
#  the wiki script is named wiki.pl and is in the cgi-bin directory.  This is
#  probably not the same as your configuration.  The text after the ? in the url
#  should probably not have to change.
use constant SRC_EDIT_URL =>
  'http://myoldwiki.com/cgi-bin/wiki.pl?action=edit&id=$TOPIC$';

# change SRC_HOME_TOPIC to match the starting topic for your old wiki.  On
# the original wiki.pl script, this is usually "HomePage"
use constant SRC_HOME_TOPIC => 'HomePage';

# Change this topic if you wish for your migrated wiki's home page to be placed somewhere
# other than the beginning page of your new wiki (WebHome is TWiki's default start topic)
use constant DEST_HOME_TOPIC => 'WebHome';

use constant TEXT_EXTRACT_REGEX => qr|wrap="virtual">(.+)</textarea>|is;

# Replace "WikiName" with the name of your destination wiki (as you did above in
#  DEST_SAVE_URL and DEST_TOPIC_URL).
use constant TOPIC_EXTRACT_REGEX =>
qr|<a href="/wiki/bin/edit/WikiName/(\w+)\?topicparent=([a-zA-Z0-9.]+)">\?</a>|i;

# This shouldn't have to change, since it is TWiki-specific
use constant DEST_POST_DATA =>
  'cmd=&formtemplate=&topicparent=$PARENT$&text=$TEXT$';

# These filter regexes are for converting original Wiki syntax to the extended
#  Twiki syntax.  You may need to change these if your wiki syntax is non-standard.
use constant FILTER_REGEXES => [
    [ qr|^\*|       => '   *' ],
    [ qr|\t|        => '   ' ],
    [ qr|'''|       => '*' ],
    [ qr|''|        => '_' ],
    [ qr|1\. |      => '1 ' ],
    [ qr|^\s+(.)\$| => '<verbatim>\n$1</verbatim>' ],
];

my $ua = LWP::UserAgent->new(
    agent                 => "Wiki Migrator $VERSION",
    keep_alive            => 1,
    timeout               => 30,
    requests_redirectable => [ 'GET', 'HEAD', 'POST' ]
);

if (DEST_WIKI_PORT) {
    $ua->credentials( DEST_WIKI_PORT, DEST_WIKI_REALM, DEST_WIKI_UID,
        DEST_WIKI_PWD );
}
if (SRC_WIKI_PORT) {
    $ua->credentials( SRC_WIKI_PORT, SRC_WIKI_REALM, SRC_WIKI_UID,
        SRC_WIKI_PWD );
}

my $dest_home_topic = DEST_HOME_TOPIC;
my $src_home_topic  = SRC_HOME_TOPIC;

my $topics = {};

print "Migrating topic $src_home_topic\n";
migrate_topic( $src_home_topic, $dest_home_topic );
print "Extracting topics from $dest_home_topic\n";
extract_topics( $dest_home_topic, $topics );

while ( keys %$topics ) {
    my ($src_topic) = keys %$topics;
    delete $topics->{$src_topic};

    print "Migrating topic $src_topic\n";
    migrate_topic( $src_topic, $src_topic, $topics->{$src_topic} );
    print "Extracting topics from $src_topic\n";
    extract_topics( $src_topic, $topics );
    print Dumper $topics;
}

sub extract_topics {
    my ( $parent_topic, $topics ) = @_;

    my $current_src_url = TOPIC_SRC_URL;

    $current_src_url =~ s/\$TOPIC\$/$parent_topic/g;

    my $request = HTTP::Request->new( GET => $current_src_url );
    if (DEST_WIKI_UID) {
        $request->authorization_basic( DEST_WIKI_UID, DEST_WIKI_PWD );
    }
    my $response = $ua->request($request);

    my $regex = TOPIC_EXTRACT_REGEX;
    print "Using this regex for extraction:\n$regex\n" if (DEBUG);
    if ( $response->is_success($response) ) {
        my $src_html = $response->content();
        print "HTML for extraction:\n$src_html\n" if (DEBUG);
        while ( $src_html =~ /$regex/g ) {
            my ( $topic, $parent_topic ) = ( $1, $2 );
            if ( !$topics->{$topic} ) {
                $topics->{$topic} = $parent_topic;
            }
        }
        print scalar( keys(%$topics) ) . " topics extracted.\n" if DEBUG;
    }
    else {
        print "Topic extraction failed for $parent_topic:\n";
        print $response->as_string();
    }
}

sub migrate_topic {
    my ( $src_topic, $dest_topic, $topic_parent ) = @_;

    my $current_src_url   = SRC_EDIT_URL;
    my $current_dest_url  = DEST_SAVE_URL;
    my $current_post_data = DEST_POST_DATA;

    $current_src_url  =~ s/\$TOPIC\$/$src_topic/g;
    $current_dest_url =~ s/\$TOPIC\$/$dest_topic/g;

    my $request = HTTP::Request->new( GET => $current_src_url );
    if ( SRC_WIKI_UID && !SRC_WIKI_PORT ) {
        $request->authorization_basic( SRC_WIKI_UID, SRC_WIKI_PWD );
    }

    my $response = $ua->request($request);
    my $topic_text;
    if ( $response->is_success($response) ) {
        my $edit_html = $response->content();
        ($topic_text) = $edit_html =~ TEXT_EXTRACT_REGEX;
        filter_text( \$topic_text );
        print "Topic text is\n$topic_text\n" if DEBUG;
    }
    else {
        print "\nTopic text retrieval for $src_topic failed:\n";
        print $response->as_string();
    }

    my $topic_parent = uri_escape($topic_parent);
    my $topic_text   = uri_escape($topic_text);

    $current_post_data =~ s/\$PARENT\$/$topic_parent/g;
    $current_post_data =~ s/\$TEXT\$/$topic_text/g;

    print "Posting new topic text to $current_dest_url\n" if DEBUG;

    $request = HTTP::Request->new( POST => $current_dest_url );
    $request->content($current_post_data);

    if ( DEST_WIKI_UID && !DEST_WIKI_PORT ) {
        $request->authorization_basic( DEST_WIKI_UID, DEST_WIKI_PWD );
    }

    my $response = $ua->request($request);
    if ( $response->is_success ) {
        print $response->as_string() if DEBUG;
        print "+\n";
    }
    else {
        print "-\n";
        print $response->as_string();
    }
}

sub filter_text {
    my ($text_ref) = @_;
    my $filter_regexes = FILTER_REGEXES;
    foreach my $substitution (@$filter_regexes) {
        my ( $regex, $replacement ) = @$substitution;
        $$text_ref =~ s/$regex/$replacement/mg;
    }
}
