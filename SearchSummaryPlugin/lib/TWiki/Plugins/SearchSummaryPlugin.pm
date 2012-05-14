package TWiki::Plugins::SearchSummaryPlugin;

use strict;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC );

$VERSION           = '$Rev$';
$RELEASE           = '0.01';
$SHORTDESCRIPTION  = 'Change the way search summaries are displayed';
$NO_PREFS_IN_TOPIC = 1;

my $TMLTRUNC   = 162;
my $PLAINTRUNC = 70;
my $MINTRUNC   = 16;

# max number of lines in a summary (best to keep it even)
my $SUMMARYLINES = 6;

use vars qw( %official %params );

sub searchWeb {
    my $this = shift;
    %params = @_;
    return &{ $official{searchWeb} }( $this, @_ );
}

sub makeTopicSummary {
    my ( $this, $text, $topic, $web, $flags ) = @_;
    my $type  = $params{type}   || '';
    my $terms = $params{search} || '';

    my $prefs    = $this->{session}->{prefs};
    my $cssClass = $prefs->getPreferencesValue('SEARCHSUMMARYPLUGIN_CSSCLASS')
      || 'twikiAlert';
    my $context = $prefs->getPreferencesValue('SEARCHSUMMARYPLUGIN_CONTEXT')
      || 30;

    # limit to n chars
    my $trunc = $flags || '';
    unless ( $trunc =~ s/^.*?([0-9]+).*$/$1/ ) {
        $trunc = $TMLTRUNC;
    }
    $trunc = $MINTRUNC if ( $trunc < $MINTRUNC );

    my @caller = caller();
    if (   !length($terms)
        || $type ne 'word' && $type ne 'keyword' && $type ne 'literal'
        || $caller[0] ne 'TWiki::Search' )
    {
        return
          &{ $TWiki::Plugins::SearchSummaryPlugin::official{makeTopicSummary} }(
            @_);
    }

    $text = $this->TML2PlainText( $text, $web, $topic, $flags );
    $text =~ s/\n+/ /g;

    my $keystrs;
    my $length = 0;
    if ( $type eq 'literal' ) {
        $keystrs = quotemeta($terms);
    }
    else {
        my @strs;
        $terms =~ s/\"(.*?)\"/sprintf("\0%02d",push(@strs,$1))/ge;
        $terms =~ s/[-+]\s+//go;
        my $stopWords = $prefs->getPreferencesValue('SEARCHSTOPWORDS') || '';
        $stopWords =~ s/[\s\,]+/\|/go;
        $stopWords =~ s/[\(\)]//go;

        $keystrs = join( '|',
            map { s/^\+//o; quotemeta($_) }
              grep { !/^($stopWords)$/i }
              map { s/\0(\d\d)/$strs[$1 - 1]/g; $_ }
              grep { !/^-/i }
              split( /[\s]+/, $terms ) );
    }

    $keystrs = "(?i:$keystrs)"
      unless TWiki::Func::isTrue( $params{casesensitive} );

    if ( $topic =~ /$keystrs/ ) {

        # IF the matching string data is in the topic name summary
        # processing acts as default with no processing.
        return
          &{ $TWiki::Plugins::SearchSummaryPlugin::official{makeTopicSummary} }(
            @_);
    }

    # Split the text on the search terms
    my @segs = split( /($keystrs)/, $text );

    if ( scalar(@segs) < 2 ) {
        return
          &{ $TWiki::Plugins::SearchSummaryPlugin::official{makeTopicSummary} }(
            @_);
    }

    my $preceded = 0;
    foreach my $i ( 0 .. $#segs ) {
        if ( $segs[$i] =~ /^($keystrs)$/ ) {
            $segs[$i] = CGI::span( { class => $cssClass }, $1 );
            $length += length($1);
        }
        else {
            if ( $i > 0 ) {
                if ( $i < $#segs ) {

                    # IF the matching string is mid body text the summary will
                    # display x chars to the left and right of the matching
                    # data.
                    if ( length( $segs[$i] ) > 2 * $context ) {
                        $segs[$i] =~
s/(.{$context}).*(.{$context})/$this->protectPlainText($1).'&hellip;'.$this->protectPlainText($2)/eo;
                    }
                }
                else {

                    # IF the matching string is at the start or end of the
                    # topic body the mutual offset will not be maintained
                    # pushing the character offset to be great one side.
                    if ( length( $segs[$i] ) > $context ) {
                        $segs[$i] =~
s/(.{$context}).*$/$this->protectPlainText($1).'&hellip;'/eo;
                    }
                }
            }
            else {

                # IF the matching string is at the start or end of the topic
                # body the mutual offset will not be maintained pushing the
                # character offset to be great one side.
                if ( length( $segs[$i] ) > $context ) {
                    $segs[$i] =~
s/.*?(.{$context})$/'&hellip;'.$this->protectPlainText($1)/eo;
                }
            }
            $length += length( $segs[$i] );
        }
        if ( $length >= $trunc ) {
            splice( @segs, $i + 1 );
            push( @segs, '&hellip;' );
            last;
        }
    }

    $text = join( '', @segs );

    return $text;
}

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    eval "use TWiki::Render";
    if ($@) {
        die
"SearchSummaryPlugin could not load the TWiki::Render module. The error message was $@";
    }

    eval "use TWiki::Search";
    if ($@) {
        die
"SearchSummaryPlugin could not load the TWiki::Search module. The error message was $@";
    }

    # Monkey-patch the core

    if (
        !defined(&TWiki::Render::makeTopicSummary)

        #           || !defined(&TWiki::Render::searchWeb)
        #            || !defined(&TWiki::Render::TML2PlainText)
        #              || !defined(&TWiki::Render::protectPlainText)
      )
    {

        # No can do
        die
"SearchSummaryPlugin is installed and enabled in a TWiki version that cannot support it. Please uninstall the plugin.";
    }

    no warnings 'redefine';
    $official{makeTopicSummary} = \&TWiki::Render::makeTopicSummary
      unless $official{makeTopicSummary};
    *TWiki::Render::makeTopicSummary = \&makeTopicSummary;

    $official{searchWeb} = \&TWiki::Search::searchWeb
      unless $official{searchWeb};
    *TWiki::Search::searchWeb = \&searchWeb;

    return 1;
}

1;
