# spidering config

# see http://www.swish-e.org/docs/spider.html
#    and http://twiki.org/cgi-bin/view/Codev/SearchIndexing

# filter out all non-valid urls: assumes twiki server only  (.../do/..)
sub twiki_url_tester {
    my $uri = shift;

    # don't index WebChanges or other pages that list everything
    return 0
      if $uri->path =~ /^(WebIndex|WebTopicList|TopicMap|WebChanges|WebRss)$/;

    # allow all views except ones with any arguments like sortcol
    if (   ( $uri->path =~ /\/view(auth)?\// )
        && ( !( $uri->query() ) ) )
    {
        return 1;
    }

    # allow attachment viewing, but not history or other args
    if (   ( $uri->path =~ /\/pub\// )
        && ( !( $uri->query() ) ) )
    {
        return 1;
    }

    # disallow other stuff: rdiff, attach, edit, etc.
    return 0;
}

# reuse default filtering that includes support for .XLS handling (if Spreadsheet modules installed!)
my ( $filter_sub, $response_sub ) = swish_filter();

# See twiki/lib/TWiki.cfg
#   base_url must be the same as ${defaultUrlHost}${scriptUrlPath}${dispViePath} from that file
my %twiki = (
    base_url    => 'http://twiki.corp.purisma.com/do/view/',
    email       => 'sknutson@purisma.com',
    max_indexed => 15000,

    # delay only 1 sec after filter rejects a topic

    # uncomment next line for testing
    #  debug => 'info,url',
    delay_sec  => 0,
    keep_alive => 1,

    # KEY BIT: this Twiki user must have "plain" template set up!
    credentials    => 'SpideringEngine:easy',
    test_url       => \&twiki_url_tester,
    test_response  => $response_sub,
    filter_content => $filter_sub,
);

@servers = ( \%twiki );
1;
