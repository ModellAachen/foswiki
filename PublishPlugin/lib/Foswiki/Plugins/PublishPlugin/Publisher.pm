# See bottom of file for license and copyright details
package Foswiki::Plugins::PublishPlugin::Publisher;

use strict;

use Foswiki;
use Foswiki::Func;
use Error ':try';
use Assert;
use Foswiki::Plugins::PublishPlugin::PageAssembler;

sub CHECKLEAK { 0 }

BEGIN {
    if (CHECKLEAK) {
        eval "use Devel::Leak::Object qw{ GLOBAL_bless };";
        die $@ if $@;
        $Devel::Leak::Object::TRACKSOURCELINES = 1;
    }
}

my %parameters = (
    debug         => { default   => 0 },
    enableplugins => { validator => \&_validateList },
    exclusions    => { default   => '', validator => \&_wildcard2RE },
    format        => { default   => 'file', validator => \&_validateWord },
    history => {
        default   => 'PublishPluginHistory',
        validator => \&_validateTopicName
    },
    inclusions  => { default => '.*', validator => \&_wildcard2RE },
    preferences => { default => '' },
    publishskin => { validator => \&_validateList },
    relativedir => { default   => '', validator => \&_validateRelPath },
    rsrcdir => {
        default   => 'rsrc',
        validator => sub {
            my ( $v, $k ) = @_;
            $v = _validateRelPath( $v, $k );
            die "Invalid $k: '$v'" if $v =~ /^\./;
            return "/$v";
          }
    },
    templates => { default => 'view', validator => \&_validateList },
    topiclist => {
        default        => '',
        allowed_macros => 1,
        validator      => \&_validateTopicNameList
    },
    topicsearch => { default => '', validator => \&_validateRE },
    versions => { validator => \&_validateList },

    # Renamed options
    filter   => { renamed => 'topicsearch' },
    instance => { renamed => 'relativedir' },
    genopt   => { renamed => 'extras' },
    skin     => { renamed => 'publishskin' }
);

sub _wildcard2RE {
    my $v = shift;
    $v =~ s/([*?])/.$1/g;
    $v =~ s/,/|/g;
    return _validateRE( $v, @_ );
}

sub _validateRE {
    my $v = shift;

    # SMELL: do a much better job of this!
    $v =~ /^(.*)$/;
    return $1;
}

sub _validateDir {
    my $v = shift;
    if ( -d $v ) {
        $v =~ /(.*)/;
        return $1;
    }
    my $k = shift;
    die "Invalid $k: '$v'";
}

sub _validateList {
    my $v = shift;
    if ( $v =~ /^([\w,. ]*)$/ ) {
        return $1;
    }
    my $k = shift;
    die "Invalid $k: '$v'";
}

sub _validateTopicNameList {
    my ( $v, $k ) = @_;
    my @ts;
    foreach my $t ( split( /\s*,\s*/, $v ) ) {
        push( @ts, _validateTopicName( $t, $k ) );
    }
    return join( ',', @ts );
}

sub _validateTopicName {
    my $v = shift;
    unless ( defined &Foswiki::Func::isValidTopicName ) {

        # Old code doesn't have this. Caveat emptor.
        return Foswiki::Sandbox::untaintUnchecked($v);
    }
    if ( Foswiki::Func::isValidTopicName( $v, 1 ) ) {
        return Foswiki::Sandbox::untaintUnchecked($v);
    }
    my $k = shift;
    die "Invalid $k: '$v'";
}

sub _validateWord {
    my $v = shift;
    if ( $v =~ /^(\w+)$/ ) {
        return $1;
    }
    my $k = shift;
    die "Invalid $k: '$v'";
}

sub validateFilenameList {
    my ( $v, $k ) = @_;
    my @ts;
    foreach my $t ( split( /\s*,\s*/, $v ) ) {
        push( @ts, _validateFilename( $t, $k ) );
    }
    return join( ',', @ts );
}

sub validateFilename {
    my $v = shift;
    if ( $v =~ /^([\w ]*)$/ ) {
        return $1;
    }
    my $k = shift;
    die "Invalid $k: '$v'";
}

sub _validateRelPath {
    my $v = shift;
    $v .= '/';
    $v =~ s#//+#/#;
    $v =~ s#^/##;
    if ( $v =~ m#^(.*)$# ) {
        my $d = $1;
        return $d;
    }
    my $k = shift;
    die "Invalid $k: '$v'";
}

sub new {
    my ( $class, $session ) = @_;

    my $this = bless(
        {
            session         => $session,
            templatesWanted => 'view',

            # used to prefix alternate template renderings
            templateLocation => '',

            # this records which templates (e.g. view, viewprint, viuehandheld,
            # etc) have been referred to and thus should be generated.
            templatesReferenced => {},

            # serial number for giving unique names to external resources
            nextExternalResourceNumber => 0,
        },
        $class
    );
    my $query = Foswiki::Func::getCgiQuery();
    my $data;
    if ( $query && $query->param('configtopic') ) {
        $this->{configtopic} = $query->param('configtopic');
        $query->delete('configtopic');
        $data = $this->_loadConfigTopic();
    }
    elsif ($query) {
        $data = $query->Vars;
    }

    # Try and build the generator first, so we can pull in param defs
    $data->{format} ||= 'file';
    die "Bad format" unless $data->{format} =~ /^(\w+)$/;
    $this->{generator} = 'Foswiki::Plugins::PublishPlugin::' . $1;
    eval 'use ' . $this->{generator};

    if ($@) {
        die "Failed to initialise '$data->{format}' generator: $@";
    }

    foreach my $phash ( \%parameters, $this->{generator}->param_schema() ) {
        foreach my $k ( keys %$phash ) {
            if ( defined( $data->{$k} ) ) {
                my $v = $data->{$k};
                $this->_setArg( $k, $v, $phash );
                $query->delete($k) if $query;
            }
            else {
                $this->{$k} = $phash->{$k}->{default};
            }
        }
    }

    # 'compress' undocumented but retained for compatibility
    if ( $query && defined $query->param('compress') ) {
        my $v = $query->param('compress');
        if ( $v =~ /(\w+)/ ) {
            $this->{format} = $1;
        }
    }

    $this->{publishskin} ||= Foswiki::Func::getPreferencesValue('PUBLISHSKIN')
      || 'basic_publish';

    $this->{historyText} = '';
    return $this;
}

sub finish {
    my $this = shift;
    $this->{session} = undef;
}

sub _setArg {
    my ( $this, $k, $v, $phash ) = @_;
    my $spec = $phash->{$k};
    $k = $spec->{renamed}
      if defined $spec->{renamed};
    if ( defined $spec->{allowed_macros} ) {
        $v = Foswiki::Func::expandCommonVariables($v);
    }
    if ( $spec->{default} && $v eq $spec->{default} ) {
        $this->{$k} = $spec->{default};
    }
    elsif ( defined $spec->{validator} ) {
        $this->{$k} = &{ $spec->{validator} }( $v, $k );
        ASSERT( UNTAINTED( $this->{$k} ), $k ) if DEBUG;
    }
    else {
        $this->{$k} = $v;
    }
}

sub _loadConfigTopic {
    my ($this) = @_;

    # Parameters are defined in config topic
    my ( $cw, $ct ) =
      Foswiki::Func::normalizeWebTopicName( $this->{web},
        $this->{configtopic} );
    unless ( Foswiki::Func::topicExists( $cw, $ct ) ) {
        die "Specified configuration topic $cw.$ct does not exist!\n";
    }

    # Untaint verified web and topic names
    $cw = Foswiki::Sandbox::untaintUnchecked($cw);
    $ct = Foswiki::Sandbox::untaintUnchecked($ct);
    my ( $cfgm, $cfgt ) = Foswiki::Func::readTopic( $cw, $ct );
    unless (
        Foswiki::Func::checkAccessPermission(
            "VIEW", $this->{publisher}, $cfgt, $ct, $cw
        )
      )
    {
        die "Access to $cw.$ct denied";
    }

    $cfgt =
      Foswiki::Func::expandCommonVariables( $cfgt, $this->{configtopic},
        $this->{web}, $cfgm );

    # SMELL: common preferences parser?
    my %data;
    foreach my $line ( split( /\r?\n/, $cfgt ) ) {
        next
          unless $line =~
              /^\s+\*\s+Set\s+(?:PUBLISH_)?([A-Z]+)\s*=\s*(.*?)\s*$/;

        my $k = lc($1);
        my $v = $2;

        $data{$k} = $v;
    }
    return \%data;
}

sub publish {
    my ( $this, @webs ) = @_;

    $this->{publisher} = Foswiki::Func::getWikiName();

    #don't add extra markup for topics we're not linking too
    # NEWTOPICLINKSYMBOL LINKTOOLTIPINFO
    if ( defined $Foswiki::Plugins::SESSION->{renderer} ) {
        $Foswiki::Plugins::SESSION->{renderer}->{NEWLINKSYMBOL} = '';
    }
    else {
        $Foswiki::Plugins::SESSION->renderer()->{NEWLINKSYMBOL} = '';
    }

    # Disable unwanted plugins
    my $enabledPlugins  = '';
    my $disabledPlugins = '';
    my @pluginsToEnable;

    if ( $this->{enableplugins} ) {
        @pluginsToEnable = split( /[, ]+/, $this->{enableplugins} );
    }

    foreach my $plugin ( keys( %{ $Foswiki::cfg{Plugins} } ) ) {
        next unless ref( $Foswiki::cfg{Plugins}{$plugin} ) eq 'HASH';
        my $enable = $Foswiki::cfg{Plugins}{$plugin}{Enabled};
        if ( scalar(@pluginsToEnable) > 0 ) {
            $enable = grep( /\b$plugin\b/, @pluginsToEnable );
            $Foswiki::cfg{Plugins}{$plugin}{Enabled} = $enable;
        }
        $enabledPlugins .= ', ' . $plugin if ($enable);
        $disabledPlugins .= ', ' . $plugin unless ($enable);
    }

    # Generate the progress information screen (based on the view template)
    my ( $header, $footer ) = ( '', '' );
    unless ( Foswiki::Func::getContext()->{command_line} ) {

        # running from CGI
        if ( defined $Foswiki::Plugins::SESSION->{response} ) {
            $Foswiki::Plugins::SESSION->generateHTTPHeaders();
            $Foswiki::Plugins::SESSION->{response}
              ->print( CGI::start_html( -title => 'Foswiki: Publish' ) );
        }
        ( $header, $footer ) = $this->_getPageTemplate();
    }

    $this->logInfo( '',          "<h1>Publishing Details</h1>" );
    $this->logInfo( "Publisher", $this->{publisher} );
    $this->logInfo( "Date",      Foswiki::Func::formatTime( time() ) );
    $this->logInfo( "Dir",
        "$Foswiki::cfg{PublishPlugin}{Dir}$this->{relativedir}" );
    $this->logInfo( "URL",
        "$Foswiki::cfg{PublishPlugin}{URL}$this->{relativeurl}" );
    $this->logInfo( "Web(s)", join( ', ', @webs ) );
    $this->logInfo( "Versions topic", $this->{versions} )
      if $this->{versions};
    $this->logInfo( "Content Generator", $this->{format} );
    $this->logInfo( "Config topic",      $this->{configtopic} )
      if $this->{configtopic};
    $this->logInfo( "Skin", $this->{publishskin} );

    # Push preference values. Because we use session preferences (preferences
    # that only live as long as the request) these values will not persist.
    if ( $this->{preferences} ) {
        foreach my $setting ( split( /\r?\n/, $this->{preferences} ) ) {
            if ( $setting =~ /^(\w+)\s*=(.*)$/ ) {
                my ( $k, $v ) = ( $1, $2 );
                Foswiki::Func::setPreferencesValue( $k, $v );
                $this->logInfo( "Preference", "$k=$v" );
            }
        }
    }
    $this->logInfo( "Templates",         $this->{templates} );
    $this->logInfo( "Topic list",        $this->{topiclist} );
    $this->logInfo( "Inclusions",        $this->{inclusions} );
    $this->logInfo( "Exclusions",        $this->{exclusions} );
    $this->logInfo( "Content Filter",    $this->{topicsearch} );
    $this->logInfo( "Generator Options", $this->{extras} );
    $this->logInfo( "Enabled Plugins",   $enabledPlugins );
    $this->logInfo( "Disabled Plugins",  $disabledPlugins );

    my $firstWeb = $webs[0];

    my ( $hw, $ht ) =
      Foswiki::Func::normalizeWebTopicName( $firstWeb, $this->{history} );
    unless (
        Foswiki::Func::checkAccessPermission(
            'CHANGE', Foswiki::Func::getWikiName(),
            undef, $ht, $hw
        )
      )
    {
        $this->logError( <<TEXT, $footer );
Can't publish because $this->{publisher} can't CHANGE
$hw.$ht.
This topic must be editable by the user doing the publishing.
TEXT
        return;
    }
    $this->{history} = "$hw.$ht";

    foreach my $web (@webs) {
        $this->_publishWeb($web);
    }

    my ( $meta, $text ) = Foswiki::Func::readTopic( $hw, $ht );
    my $history =
      Foswiki::Func::loadTemplate( 'publish_history', $this->{publishskin} );

    # See if we have history template. Unfortunately for compatibility
    # reasons, Func::readTemplate doesn't distinguish between no template
    # and an empty template :-(
    if ($history) {

        # Expand macros *before* we include the history text so we pick up
        # session preferences.
        Foswiki::Func::setPreferencesValue( 'PUBLISHING_HISTORY',
            $this->{historyText} );
        $history = Foswiki::Func::expandCommonVariables($history);
    }
    elsif ( Foswiki::Func::topicExists( $hw, $ht ) ) {

        # No template, use the last publish run (legacy)
        $text ||= '';
        $text =~ s/(^|\n)---\+ Last Published\n.*$//s;
        $history =
"$text---+ Last Published\n<noautolink>\n$this->{historyText}\n</noautolink>";
    }
    else {

        # No last run, make something up
        $history =
"---+ Last Published\n<noautolink>\n$this->{historyText}\n</noautolink>";
    }
    Foswiki::Func::saveTopic( $hw, $ht, $meta, $history,
        { minor => 1, forcenewrevision => 1 } );
    my $url = Foswiki::Func::getScriptUrl( $hw, $ht, 'view' );
    $this->logInfo( "History saved in", "<a href='$url'>$url</a>" );

    Foswiki::Plugins::PublishPlugin::_display($footer);
}

sub _publishWeb {
    my ( $this, $web ) = @_;

    $this->{web} = $web;

    $this->logInfo( '', "<h1>Publishing web '$web'</h1>" );
    if ( $this->{versions} ) {
        $this->{topicVersions} = {};
        my ( $vweb, $vtopic ) =
          Foswiki::Func::normalizeWebTopicName( $web, $this->{versions} );
        die "Versions topic $vweb.$vtopic does not exist"
          unless Foswiki::Func::topicExists( $vweb, $vtopic );
        my ( $meta, $text ) = Foswiki::Func::readTopic( $vweb, $vtopic );
        $text =
          Foswiki::Func::expandCommonVariables( $text, $vtopic, $vweb, $meta );
        my $pending;
        my $count = 0;
        foreach my $line ( split( /\r?\n/, $text ) ) {

            if ( defined $pending ) {
                $line =~ s/^\s*//;
                $line = $pending . $line;
                undef $pending;
            }
            if ( $line =~ s/\\$// ) {
                $pending = $line;
                next;
            }
            if ( $line =~ /^\s*\|\s*(.*?)\s*\|\s*(?:\d\.)?(\d+)\s*\|\s*$/ ) {
                my ( $t, $v ) = ( $1, $2 );
                ( $vweb, $vtopic ) =
                  Foswiki::Func::normalizeWebTopicName( $web, $t );
                $this->{topicVersions}->{"$vweb.$vtopic"} = $v;
                $count++;
            }
        }
        die "Versions topic $vweb.$vtopic contains no topic versions"
          unless $count;
    }

    my @templatesWanted = split( /[, ]+/, $this->{templates} );

    foreach my $template (@templatesWanted) {
        next unless $template;
        $this->{templatesReferenced}->{$template} = 1;
        my $dir = "$Foswiki::cfg{PublishPlugin}{Dir}$this->{relativedir}"
          . $this->_dirForTemplate($template);

        File::Path::mkpath($dir);

        $this->{archive} = $this->{generator}->new( $this, $dir, $this );

        $this->publishUsingTemplate($template);

        my $landed = $this->{archive}->close();

        $this->logInfo( "Published To", <<LINK);
<a href="$Foswiki::cfg{PublishPlugin}{URL}$this->{relativedir}$landed">$landed</a>
LINK
        Devel::Leak::Object::checkpoint() if CHECKLEAK;
    }

    # check the templates referenced, and that everything referenced
    # has been generated.
    my @templatesReferenced = sort keys %{ $this->{templatesReferenced} };
    @templatesWanted = sort @templatesWanted;

    my @difference = arrayDiff( \@templatesReferenced, \@templatesWanted );
    if ( $#difference > 0 ) {
        $this->logInfo( "Templates Used", join( ",", @templatesReferenced ) );
        $this->logInfo( "Templates Specified", join( ",", @templatesWanted ) );
        $this->logWarn(<<BLAH);
There is a difference between the templates you specified and what you
needed. Consider changing the TEMPLATES setting so it has all Templates
Used.
BLAH
    }
}

# get a template for presenting output / interacting (*not* used
# for published content)
sub _getPageTemplate {
    my ($this) = @_;

    my $query = Foswiki::Func::getCgiQuery();
    my $topic = $query->param('publishtopic') || $this->{session}->{topicName};
    my $tmpl  = Foswiki::Func::readTemplate('view');

    $tmpl =~ s/%META{.*?}%//g;
    for my $tag (qw( REVTITLE REVARG REVISIONS MAXREV CURRREV )) {
        $tmpl =~ s/%$tag%//g;
    }
    my ( $header, $footer ) = split( /%TEXT%/, $tmpl );
    $header =
      Foswiki::Func::expandCommonVariables( $header, $topic, $this->{web} );
    $header = Foswiki::Func::renderText( $header, $this->{web} );
    $header =~ s/<nop>//go;
    Foswiki::Func::writeHeader();
    Foswiki::Plugins::PublishPlugin::_display $header;

    $footer =
      Foswiki::Func::expandCommonVariables( $footer, $topic, $this->{web} );
    $footer = Foswiki::Func::renderText( $footer, $this->{web} );
    return ( $header, $footer );
}

# from http://perl.active-venture.com/pod/perlfaq4-dataarrays.html
sub arrayDiff {
    my ( $array1, $array2 ) = @_;
    my ( @union, @intersection, @difference );
    @union = @intersection = @difference = ();
    my %count = ();
    foreach my $element ( @$array1, @$array2 ) { $count{$element}++ }
    foreach my $element ( keys %count ) {
        push @union, $element;
        push @{ $count{$element} > 1 ? \@intersection : \@difference },
          $element;
    }
    return @difference;
}

sub logInfo {
    my ( $this, $header, $body ) = @_;
    $body ||= '';
    if ( defined $header and $header ne '' ) {
        $header = CGI::b("$header:&nbsp;");
    }
    else {
        $header = '';
    }
    Foswiki::Plugins::PublishPlugin::_display( $header, $body, CGI::br() );
    $this->{historyText} .= "$header$body%BR%\n";
}

sub logWarn {
    my ( $this, $message ) = @_;
    Foswiki::Plugins::PublishPlugin::_display(
        CGI::span( { class => 'foswikiAlert' }, $message ) );
    Foswiki::Plugins::PublishPlugin::_display( CGI::br() );
    $this->{historyText} .= "%ORANGE% *WARNING* $message %ENDCOLOR%%BR%\n";
}

sub logError {
    my ( $this, $message ) = @_;
    Foswiki::Plugins::PublishPlugin::_display(
        CGI::span( { class => 'foswikiAlert' }, "ERROR: $message" ) );
    Foswiki::Plugins::PublishPlugin::_display( CGI::br() );
    $this->{historyText} .= "%RED% *ERROR* $message %ENDCOLOR%%BR%\n";
}

#  Publish a set of topics using the given template (e.g. view)
sub publishUsingTemplate {
    my ( $this, $template ) = @_;

    # Get list of topics
    my @topics;

    if ( $this->{topiclist} ) {
        @topics = map {
            my ( $w, $t ) =
              Foswiki::Func::normalizeWebTopicName( $this->{web}, $_ );
            "$w.$t"
        } split( /[,\s]+/, $this->{topiclist} );
    }
    else {
        @topics =
          map { "$this->{web}.$_" } Foswiki::Func::getTopicList( $this->{web} );
    }

    # Choose template. Note that $template_TEMPLATE can still override
    # this in specific topics.
    my $tmpl = Foswiki::Func::readTemplate( $template, $this->{publishskin} );
    die "Couldn't find template\n" if ( !$tmpl );
    my $filetype = _filetypeForTemplate($template);

    # Attempt to render each included page.
    my %copied;
    foreach my $topic (@topics) {
        next if $topic eq $this->{history};    # never publish this
        ( my $web, $topic ) =
          Foswiki::Func::normalizeWebTopicName( $this->{web}, $topic );
        try {
            my $dispo = '';
            if ( $this->{inclusions} && $topic !~ /^($this->{inclusions})$/ ) {
                $dispo = 'not included';
            }
            elsif ($this->{exclusions}
                && $topic =~ /^($this->{exclusions})$/ )
            {
                $dispo = 'excluded';
            }
            else {
                my $rev =
                  $this->publishTopic( $web, $topic, $filetype, $template,
                    $tmpl, \%copied )
                  || '0';
                $dispo = "Rev $rev published";
                $topic = '<a href="'
                  . Foswiki::Func::getScriptUrl( $web, $topic, 'view',
                    rev => $rev )
                  . '">'
                  . $topic . '</a>';
            }
            $this->logInfo( $topic, $dispo );
        }
        catch Error::Simple with {
            my $e = shift;
            $this->logError(
                "$web.$topic not published: " . ( $e->{-text} || '' ) );
        };

        # Prevent slowdown and unnecessary memory use if templates are
        # frequently reloaded, for some 1.1.x versions of Foswiki.
        # This is NOT a likely condition, and it is only known to manifest
        # when there are additional problems in the data being published.
        # However, if there is something wrong in the publishing configuration,
        # then it is possible for many pages to have at least one inline alert,
        # and Foswiki::inlineAlert reloads its template each time it is called
        # (at least, it does for some versions of Foswiki).
        # This can be problem when publishing several hundred topics.
        # Sure - the publishing configuration should be fixed,
        # but it can be tricky to debug that configuration if Apache is
        # killing the publishing process.
        if (   $Foswiki::cfg{PublishPlugin}{PurgeTemplates}
            && $Foswiki::Plugins::SESSION->can('templates')
            and $Foswiki::Plugins::SESSION->{templates}
            and ref $Foswiki::Plugins::SESSION->{templates}
            and $Foswiki::Plugins::SESSION->{templates}->can('finish') )
        {
            $Foswiki::Plugins::SESSION->{templates}->finish();
            undef $Foswiki::Plugins::SESSION->{templates};
        }

        Devel::Leak::Object::checkpoint() if CHECKLEAK;
    }
}

#  Publish one topic from web.
#   * =$topic= - which topic to publish (web.topic)
#   * =$filetype= - which filetype (pdf, html) to use as a suffix on the file generated

#   * =\%copied= - map of copied resources to new locations
sub publishTopic {
    my ( $this, $w, $t, $filetype, $template, $tmpl, $copied ) = @_;

    # Read topic data.

    my ( $meta, $text );
    my $publishedRev =
        $this->{topicVersions}
      ? $this->{topicVersions}->{"$w.$t"}
      : undef;

    my $topic = "$w.$t";

    ( $meta, $text ) = Foswiki::Func::readTopic( $w, $t, $publishedRev );
    unless ($publishedRev) {
        my $d;
        ( $d, $d, $publishedRev, $d ) =
          Foswiki::Func::getRevisionInfo( $w, $t );
    }

    unless (
        Foswiki::Func::checkAccessPermission(
            "VIEW", $this->{publisher}, $text, $t, $w
        )
      )
    {
        $this->logError("View access to $topic denied");
        return;
    }

    if ( $this->{topicsearch} && $text =~ /$this->{topicsearch}/ ) {
        $this->logInfo( $topic, "excluded by filter" );
        return;
    }

    # clone the current session
    my %old;
    my $query = Foswiki::Func::getCgiQuery();
    $query->param( 'topic', $topic );

    if ( defined &Foswiki::Func::pushTopicContext ) {

        # In 1.0.6 and earlier, have to handle some session tags ourselves
        # because pushTopicContext doesn't do it. **
        if ( defined $Foswiki::Plugins::SESSION->{SESSION_TAGS} ) {
            foreach my $macro (
                qw(BASEWEB BASETOPIC
                INCLUDINGWEB INCLUDINGTOPIC)
              )
            {
                $old{$macro} = Foswiki::Func::getPreferencesValue($macro);
            }
        }
        Foswiki::Func::pushTopicContext( $w, $t );
        if ( defined $Foswiki::Plugins::SESSION->{SESSION_TAGS} ) {

            # see ** above
            my $stags = $Foswiki::Plugins::SESSION->{SESSION_TAGS};
            $stags->{BASEWEB}        = $w;
            $stags->{BASETOPIC}      = $t;
            $stags->{INCLUDINGWEB}   = $w;
            $stags->{INCLUDINGTOPIC} = $t;
        }

        # Remove disabled plugins from the context
        foreach my $plugin ( keys( %{ $Foswiki::cfg{Plugins} } ) ) {
            next unless ref( $Foswiki::cfg{Plugins}{$plugin} ) eq 'HASH';
            my $enable = $Foswiki::cfg{Plugins}{$plugin}{Enabled};
            Foswiki::Func::getContext()->{"${plugin}Enabled"} = $enable;
        }
    }
    else {

        # Create a new session so that the contexts are correct. This is
        # really, really inefficient, but is essential to maintain correct
        # prefs if we don't have a modern Func
        $old{SESSION} = $Foswiki::Plugins::SESSION;
        $Foswiki::Plugins::SESSION = new Foswiki( $this->{publisher}, $query );
    }

    # Because of Item5388, we have to re-read the topic to get the
    # right session in the $meta. This could be done by patching the
    # $meta object, but this should be longer-lasting.
    # $meta has to have the right session otherwise $WEB and $TOPIC
    # won't work in %IF statements.
    ( $meta, $text ) = Foswiki::Func::readTopic( $w, $t, $publishedRev );

    $Foswiki::Plugins::SESSION->enterContext( 'can_render_meta', $meta );

    # Allow a local definition of VIEW_TEMPLATE to override the
    # template passed in (unless this is disabled by a global option)
    my $override = Foswiki::Func::getPreferencesValue('VIEW_TEMPLATE');
    if ($override) {
        $tmpl =
          Foswiki::Func::readTemplate( $override, $this->{publishskin}, $w );
        $this->logInfo( $topic, "has a VIEW_TEMPLATE '$override'" );
    }

    my ( $revdate, $revuser, $maxrev );
    ( $revdate, $revuser, $maxrev ) = $meta->getRevisionInfo();
    if ( ref($revuser) ) {
        $revuser = $revuser->wikiName();
    }

    # Expand and render the topic text
    $text = Foswiki::Func::expandCommonVariables( $text, $t, $w, $meta );

    my $newText = '';
    my $tagSeen = 0;
    my $publish = 1;
    foreach my $s ( split( /(%STARTPUBLISH%|%STOPPUBLISH%)/, $text ) ) {
        if ( $s eq '%STARTPUBLISH%' ) {
            $publish = 1;
            $newText = '' unless ($tagSeen);
            $tagSeen = 1;
        }
        elsif ( $s eq '%STOPPUBLISH%' ) {
            $publish = 0;
            $tagSeen = 1;
        }
        elsif ($publish) {
            $newText .= $s;
        }
    }
    $text = $newText;

    # Expand and render the template
    $tmpl = Foswiki::Func::expandCommonVariables( $tmpl, $t, $w, $meta );

    # Inject the text into the template. The extra \n is required to
    # simulate the way the view script splits up the topic and reassembles
    # it around newlines.
    $text = "\n$text" unless $text =~ /^\n/s;

    $tmpl =~ s/%TEXT%/$text/;

    # legacy
    $tmpl =~ s/<nopublish>.*?<\/nopublish>//gs;

    $tmpl =~ s/.*?<\/nopublish>//gs;
    $tmpl =~ s/%MAXREV%/$maxrev/g;
    $tmpl =~ s/%CURRREV%/$maxrev/g;
    $tmpl =~ s/%REVTITLE%//g;

    # trim spaces at start and end
    $tmpl =~ s/^[[:space:]]+//s;    # trim at start
    $tmpl =~ s/[[:space:]]+$//s;    # trim at end

    $tmpl = Foswiki::Func::renderText( $tmpl, $w );

    $tmpl = Foswiki::Plugins::PublishPlugin::PageAssembler::assemblePage( $this,
        $tmpl );

    if ( $Foswiki::Plugins::VERSION and $Foswiki::Plugins::VERSION >= 2.0 )
    {

        # Note: Foswiki 1.1 supplies this same header text
        # when dispatching completePageHandler.
        my $CRLF = "\x0D\x0A";
        my $hdr  = "Content-type: text/html$CRLF$CRLF";
        $Foswiki::Plugins::SESSION->{plugins}
          ->dispatch( 'completePageHandler', $tmpl, $hdr );
    }

    $tmpl =~ s|( ?) *</*nop/*>\n?|$1|gois;

    # Remove <base.../> tag
    $tmpl =~ s/<base[^>]+\/>//i;

    # Remove <base...>...</base> tag
    $tmpl =~ s/<base[^>]+>.*?<\/base>//i;

    # Clean up unsatisfied WikiWords.
    $tmpl =~ s/<span class="foswikiNewLink">(.*?)<\/span>/
      $this->_handleNewLink($1)/ge;

    # Copy files from pub dir to rsrc dir in static dir.
    my $hs = $ENV{HTTP_HOST} || "localhost";

    # Find and copy resources attached to the topic
    my $pub = Foswiki::Func::getPubUrlPath();
    $tmpl =~
      s!(['"\(])($Foswiki::cfg{DefaultUrlHost}|https?://$hs)?$pub/(.*?)(\1|\))!
      $1.$this->_rsrcpath( $w ,$this->_copyResource($3, $copied) ).$4!ge;

    my $ilt;

    # Modify local links relative to server base
    $ilt =
      $Foswiki::Plugins::SESSION->getScriptUrl( 0, 'view', 'NOISE', 'NOISE' );
    $ilt  =~ s!/NOISE/NOISE.*$!!;
    $tmpl =~ s!href=(["'])$ilt/(.*?)\1!"href=$1".$this->_topicURL($2).$1!ge;

    # Modify absolute topic links.
    $ilt =
      $Foswiki::Plugins::SESSION->getScriptUrl( 1, 'view', 'NOISE', 'NOISE' );
    $ilt  =~ s!/NOISE/NOISE.*$!!;
    $tmpl =~ s!href=(["'])$ilt/(.*?)\1!"href=$1".$this->_topicURL($2).$1!ge;

    # Modify topic-relative TOC links to strip out parameters (but not anchor)
    $tmpl =~ s!href=(["'])\?.*?(\1|#)!href=$1$2!g;

    # replace any external template references
    $tmpl =~ s!href=["'](.*?)\?template=(\w*)(.*?)["']!
      $this->_rewriteTemplateReferences($tmpl, $1, $2, $3)!e;

    # Handle image tags using absolute URLs not otherwise satisfied
    $tmpl =~ s!(<img\s+.*?\bsrc=)(["'])(.*?)\2(.*?>)!
      $1.$2.$this->_rsrcpath( $w, $this->_handleURL($3,\($this->{nextExternalResourceNumber})) ).$2.$4!ge;

    $tmpl =~ s/<nop>//g;

    # Write the resulting HTML.
    $w =~ s#\.#/#g;
    $this->{archive}->addString( $tmpl, "$w/$t$filetype" );

    if ( defined &Foswiki::Func::popTopicContext ) {
        Foswiki::Func::popTopicContext();
        if ( defined $Foswiki::Plugins::SESSION->{SESSION_TAGS} ) {

            # In 1.0.6 and earlier, have to handle some session tags ourselves
            # because pushTopicContext doesn't do it. **
            foreach my $macro (
                qw(BASEWEB BASETOPIC
                INCLUDINGWEB INCLUDINGTOPIC)
              )
            {
                $Foswiki::Plugins::SESSION->{SESSION_TAGS}{$macro} =
                  $old{$macro};
            }
        }

    }
    else {
        $Foswiki::Plugins::SESSION = $old{SESSION};    # restore session
    }

    return $publishedRev;
}

# rewrite
#   Topic?template=viewprint%REVARG%.html?template=viewprint%REVARG%
# to
#   _viewprint/Topic.html
#
#   * =$this->{web}=
#   * =$tmpl=
#   * =$topic=
#   * =$template=
# return
#   *
# side effects

sub _rewriteTemplateReferences {
    my ( $this, $tmpl, $topic, $template, $redundantduplicate ) = @_;

# for an unknown reason, these come through with doubled up template= arg
# e.g.
# http://.../site/instance/Web/WebHome?template=viewprint%REVARG%.html?template=viewprint%REVARG%
#$link:
# Web/ContactUs?template=viewprint%REVARG%.html? "
    $topic =~ s#\.#/#g;
    my $newLink =
        $Foswiki::cfg{PublishPlugin}{URL}
      . $this->_dirForTemplate($template)
      . $topic
      . _filetypeForTemplate($template);
    $this->{templatesReferenced}->{$template} = 1;
    return "href='$newLink'";
}

# Where alternative templates (e.g. viewprint) renderings end up
# This gets appended onto puburl and pubdir
# The web is prefixed before this.
# Do not prepend with a /
sub _dirForTemplate {
    my ( $this, $template ) = @_;
    return '' if ( $template eq 'view' );
    return $template unless $this->{templateLocation};
    return "$this->{templateLocation}/$template/";
}

# SMELL this needs to be table driven
sub _filetypeForTemplate {
    my ($template) = @_;
    return '.pdf' if ( $template eq 'viewpdf' );
    return '.html';
}

#  Copy a resource (image, style sheet, etc.) from pub/%WEB% to
#   static HTML's rsrc directory.
#   * =$this->{web}= - name of web
#   * =$rsrcName= - name of resource (relative to pub/%WEB%)
#   * =\%copied= - map of copied resources to new locations
sub _copyResource {
    my ( $this, $srcName, $copied ) = @_;
    my $rsrcName = $srcName;

    # Trim the resource name, as they can sometimes pick up whitespaces
    $rsrcName =~ /^\s*(.*?)\s*$/;
    $rsrcName = $1;

    # SMELL WARNING (Martin Cleaver)
    # This is covers up a case such as where rsrcname comes through like
    # configtopic=PublishTestWeb/WebPreferences/favicon.ico
    # this should be just WebPreferences/favicon.ico
    # I've searched for hours and so here's a workaround
    if ( $rsrcName =~ m/configtopic/ ) {
        $this->logError("rsrcName '$rsrcName' contains literal 'configtopic'");
        $rsrcName =~ s!.*?/(.*)!$this->{web}/$1!;
        $this->logError("--- FIXED UP to $rsrcName");
    }

    # See if we've already copied this resource.
    unless ( exists $copied->{$rsrcName} ) {

        # strip off things like ?version=wossname arguments appended to .js
        my $bareRsrcName = $rsrcName;
        $bareRsrcName =~ s/\?.*//o;

        # Nope, it's new. Gotta copy it to new location.
        # Split resource name into path (relative to pub/%WEB%) and leaf name.
        my $file = $bareRsrcName;
        $file =~ s(^(.*)\/)()o;
        my $path = "";
        if ( $bareRsrcName =~ "/" ) {
            $path = $bareRsrcName;
            $path =~ s(\/[^\/]*$)()o;    # path, excluding the basename
        }

        # Copy resource to rsrc directory.
        my $pubDir = Foswiki::Func::getPubDir();
        my $src    = "$pubDir/$bareRsrcName";
        if ( -r "$pubDir/$bareRsrcName" ) {
            $this->{archive}->addDirectory( $this->{rsrcdir} );
            $this->{archive}->addDirectory("$this->{rsrcdir}/$path");
            my $dest = "$this->{rsrcdir}/$path/$file";
            $dest =~ s!//!/!g;
            if ( -d $src ) {
                $this->{archive}->addDirectory( $src, $dest );
            }
            else {
                $this->{archive}->addFile( $src, $dest );
            }

            # Record copy so we don't duplicate it later.
            $copied->{$rsrcName} = $dest;
        }
        else {
            $this->logError("$src is not readable");
        }

        # check css for additional resources, ie, url()
        if ( $bareRsrcName =~ /\.css$/ ) {
            my @moreResources = ();
            my $fh;
            if ( open( $fh, '<', $src ) ) {
                local $/;
                binmode($fh);
                my $data = <$fh>;
                close($fh);
                $data =~ s#\/\*.*?\*\/##gs;    # kill comments
                foreach my $line ( split( /\r?\n/, $data ) ) {
                    if ( $line =~ /url\(["']?(.*?)["']?\)/ ) {
                        push @moreResources, $1;
                    }
                }
                my $pub = Foswiki::Func::getPubUrlPath();
                foreach my $resource (@moreResources) {

                    # recurse
                    if ( $resource !~ m!^/! ) {

                        # if the url is not absolute, assume it's
                        # relative to the current path
                        $resource = $path . '/' . $resource;
                    }
                    else {
                        if ( $resource =~ m!$pub/(.*)! ) {
                            my $old = $resource;
                            $resource = $1;
                        }
                    }
                    $this->_copyResource( $resource, $copied );
                }
            }
        }
    }
    return $copied->{$rsrcName} if $copied->{$rsrcName};
    $this->logError("MISSING RESOURCE $rsrcName");
    return "MISSING RESOURCE $rsrcName";
}

sub _topicURL {
    my ( $this, $path ) = @_;
    my $extra = '';

    if ( $path && $path =~ s/([#\?].*)$// ) {
        $extra = $1;

        # no point in passing on script params; we are publishing
        # to static HTML.
        $extra =~ s/\?.*?(#|$)/$1/;
    }

    $path ||= $Foswiki::cfg{HomeTopicName};
    $path .= $Foswiki::cfg{HomeTopicName} if $path =~ /\/$/;

    # Normalise
    my $web = join( '/', split( /[\/\.]+/, $this->{web} ) );
    $path = join( '/', split( /[\/\.]+/, $path ) );

    # make a path relative to the web
    $path = File::Spec->abs2rel( $path, $web );
    $path .= '.html';

    return $path . $extra;
}

sub _handleURL {
    my ( $this, $src, $extras ) = @_;

    my $data;
    if ( defined(&Foswiki::Func::getExternalResource) ) {
        my $response = Foswiki::Func::getExternalResource($src);
        return $src if $response->is_error();
        $data = $response->content();
    }
    else {
        return $src unless $src =~ m!^([a-z]+)://([^/:]*)(:\d+)?(/.*)$!;
        my $protocol = $1;
        my $host     = $2;
        my $port     = $3 || 80;
        my $path     = $4;

        # Early getUrl didn't support protocol
        if ( $Foswiki::Plugins::SESSION->{net}->can('_getURLUsingLWP') ) {
            $data =
              $Foswiki::Plugins::SESSION->{net}
              ->getUrl( $protocol, $host, $port, $path );
        }
        else {
            $data =
              $Foswiki::Plugins::SESSION->{net}->getUrl( $host, $port, $path );
        }
    }

    # Note: no extension; rely on file format.
    # Images are pretty good that way.
    my $file = '___extra' . $$extras++;
    $this->{archive}->addDirectory( $this->{rsrcdir} );

    my $fpath = "$this->{rsrcdir}/$file";
    $this->{archive}->addString( $data, $fpath );
    return $fpath;
}

# Returns a pattern that will match the HTML used to represent an
# unsatisfied link. THIS IS NASTY, but I don't know how else to do it.
# SMELL: another case for a WysiwygPlugin-style rendering engine
sub _handleNewLink {
    my ( $this, $link ) = @_;
    $link =~ s!<a .*?>!!gi;
    $link =~ s!</a>!!gi;
    return $link;
}

# return a relative path to a resource given a location to a resource
# and the path to the current output directory.  the various stages of
# cleanup may cause a path to get run through this function multiple
# times; make sure that we only modify the path the first time.
sub _rsrcpath {

    my ( $this, $odir, $rsrcloc ) = @_;

    # if path is already relative, return it
    return $rsrcloc if $rsrcloc =~ m{^\.+/};

    # relative path to rsrc dir from output dir
    my $nloc = File::Spec->abs2rel( $rsrcloc, $odir );

    # ensure there's an explicit relative path so it can
    # be identified next time 'round
    $nloc = './' . $nloc unless $nloc =~ /^\./;

    return $nloc;
}

1;
__END__
#
# Copyright (C) 2001 Motorola
# Copyright (C) 2001-2007 Sven Dowideit, svenud@ozemail.com.au
# Copyright (C) 2002, Eric Scouten
# Copyright (C) 2005-2008 Crawford Currie, http://c-dot.co.uk
# Copyright (C) 2006 Martin Cleaver, http://www.cleaver.org
# Copyright (C) 2010 Arthur Clemens, http://visiblearea.com
# Copyright (C) 2010 Michael Tempest
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
# Removal of this notice in this or derivatives is forbidden.
