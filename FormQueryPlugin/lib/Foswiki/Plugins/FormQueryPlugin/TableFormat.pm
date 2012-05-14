#
# Copyright (C) Motorola 2003 - All rights reserved
#
package Foswiki::Plugins::FormQueryPlugin::TableFormat;

use strict;

use Foswiki::Contrib::DBCacheContrib::MemMap;
use Assert;

# PRIVATE cache of table formats
my %cache;
my $stdClass   = 'twikiTable fqpTable';
my $htmltables = 0;                       # Do not expand tables to HTML here
my $TranslationToken = "\0";    # Null not allowed in charsets used with Foswiki

# PUBLIC
# A new TableFormat is either generated or may be satisfied from
# the cache
sub new {
    my ( $class, $attrs ) = @_;
    my $this = bless( {}, $class );
    my $format = $attrs->{format};

    my $header = $attrs->{header};
    my $footer = $attrs->{footer};
    my $sort   = $attrs->{sort} || $attrs->{order};

    if ( defined($header) ) {
        if ( $header =~ s/^\|(.*)\|$/$1/ ) {
            if ($htmltables) {

               # expand twiki-format table header. We have to format here rather
               # than allowing Foswiki to do it because we need to colour and
               # align rows.
                $header = CGI::start_table( { class => $stdClass } )
                  . CGI::Tr(
                    { class => $stdClass },
                    join( '',
                        map { CGI::th( { class => $stdClass }, " $_ " ) }
                          split( /\|/, $header ) )
                  );
                $footer = CGI::end_table() unless ( defined($footer) );
            }
            else {
                $header = "|$header|\n";
            }
        }
        else {
            $header .= "\n";
        }
    }

    if ( $format && defined( $cache{$format} ) ) {
        $header = $cache{$format}->{header} unless ( defined($header) );
        $footer = $cache{$format}->{footer} unless ( defined($footer) );
        $sort   = $cache{$format}->{sort}   unless ( defined($sort) );
        $format = $cache{$format}->{format};
    }

    if ( defined($footer) && !$htmltables ) {
        $footer = "\n$footer";
    }

    $this->{header} = $header;
    $this->{footer} = $footer;
    $this->{format} = $format;

    $this->{sort} = $sort;
    if (   $htmltables
        && $format =~ s/^\s*\|(.*)\|\s*$/<tr valign=top><td> $1 <\/td><\/tr>/o )
    {
        $format =~ s/\|/ <\/td><td> /go;
    }

    $this->{help_undefined} = $attrs->{help};

    return $this;
}

# PUBLIC STATIC add a format to the static cache
sub addToCache {
    my ( $this, $name ) = @_;

    $cache{$name} = $this;

    return $this;
}

# PRIVATE STATIC fields used in sorting; entries are hashes
my @compareFields;

# PRIVATE STATIC compare function for sorting
sub _compare {
    my ( $va, $vb );
    foreach my $field (@compareFields) {
        if ( $field->{reverse} ) {

            # reverse sort this field
            $va = $b->get( $field->{name} );
            $vb = $a->get( $field->{name} );
        }
        else {
            $va = $a->get( $field->{name} );
            $vb = $b->get( $field->{name} );
        }
        if ( defined($va) && defined($vb) ) {
            my $cmp;
            if ( $field->{numeric} ) {
                $cmp = $va <=> $vb;
            }
            else {
                $cmp = $va cmp $vb;
            }
            return $cmp unless ( $cmp == 0 );
        }
    }
    return 0;
}

sub _breakName {
    my ( $text, $args ) = @_;
    $text = '' unless defined $text;

    return $text unless $args;

    my @params = split( /[\,\s]+/, $args, 2 );
    if (@params) {
        my $len = $params[0] || 1;
        $len = 1 if ( $len < 1 );
        my $sep = '- ';
        $sep = $params[1] if ( @params > 1 );
        if ( $sep =~ /^\.\.\./i ) {

            # make name shorter like 'ThisIsALongTop...'
            $text =~ s/(.{$len})(.+)/$1.../s;

        }
        else {

            # split and hyphenate the topic like 'ThisIsALo- ngTopic'
            $text =~ s/(.{$len})/$1$sep/gs;
            $text =~ s/$sep$//;
        }
    }
    return $text;
}

sub getTextPattern {
    my ( $text, $pattern ) = @_;

    $pattern =~
      s/([^\\])([\$\@\%\&\#\'\`\/])/$1\\$2/go;    # escape some special chars

    my $OK = 0;
    eval { $OK = ( $text =~ s/$pattern/$1/is ); };
    $text = '' unless ($OK);

    return $text;
}

# PUBLIC
# Format an array as a table according to the formatting
# instructions in {format}
sub formatTable {
    my ( $this, $entries, $theSeparator, $newLine, $sr, $rc, $topic, $web ) =
      @_;
    return CGI::span( { class => 'twikiAlert' }, 'Empty table' )
      if ( $entries->size() == 0 );
    my $mixedAlpha = $Foswiki::regex{mixedAlpha};
    if ($theSeparator) {
        $theSeparator =~ s/\$n\(\)/\n/gos;    # expand "$n()" to new line
        $theSeparator =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos;
    }
    if ($newLine) {
        $newLine =~ s/\$n\(\)/\n/gos;                # expand "$n()" to new line
        $newLine =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos;
    }

    if ( $entries->size() > 1 && defined( $this->{sort} ) ) {
        @compareFields = ();
        foreach my $field ( split( /\s*,\s*/, $this->{sort} ) ) {
            my $numeric = 0;
            my $reverse = 0;
            $field =~ s/^\#-/-\#/o;
            $reverse = 1 if ( $field =~ s/^-//o );
            $numeric = 1 if ( $field =~ s/^\#//o );
            push(
                @compareFields,
                {
                    name    => $field,
                    reverse => $reverse,
                    numeric => $numeric
                }
            );
        }
        @{ $entries->{values} } = sort _compare @{ $entries->{values} };
    }
    my $session = $Foswiki::Plugins::SESSION;

    $sr = 0 if ( !defined($sr) || $sr < 0 );
    $rc = $entries->size() if ( !defined($rc) || $rc < 0 );
    my $rows  = "";
    my $cnt   = 0;
    my $users = $session->{users};
    foreach my $sub ( $entries->getValues() ) {
        if ( $cnt >= $sr && $cnt < $sr + $rc ) {
            my $row = $this->{format} || '';

            my $topic = $sub->get("topic");
            if ($topic) {

                # handle special table format
                $row =~ s/\$topic\(([^\)]*)\)/
                  _breakName(
                      _expandField($this, "topic", $sub), $1)/ges;
                $row =~ s/\$topic/$topic/ges;
                $row =~ s/\$summary\(([^\)]*)\)/
                  $session->{renderer}->makeTopicSummary(
                      $sub->get("text"), $topic, $web, $1 )/ges;
                $row =~ s/\$summary/$session->{renderer}->makeTopicSummary(
                    $sub->get("text"), $topic, $web )/ges;
                $row =~ s/\$parent\(([^\)]*)\)/_breakName(
                    $sub->get("parent"), $1 )/ges;
                $row =~ s/\$parent/$sub->get("parent")/ges;
                $row =~ s/\$formfield\(\s*([^\)\,]*)\s*(?:\,\s*([^\)]*))?\s*\)/
                  _breakName( $sub->get($1||''), $2)/ges;
                $row =~ s/\$formname/$sub->get("form")/ges;
                $row =~ s/\$pattern\((.*?\s*\.\*)\)/
                  getTextPattern( $sub->get("text"), $1 )/ges;
                $row =~ s/\$web/$sub->get("web")/ges;
                my ( $junk, $name, $ut ) =
                  Foswiki::Func::checkTopicEditLock( $sub->get("web"), $topic,
                    '' );
                $name ||= '';
                $row =~ s/\$locked/$name/gs;
                my $info = $sub->get("info");

                if ($info) {
                    $row =~ s/\$date/&Foswiki::Time::formatTime(
                        $info->get("date") )/ges;
                    $row =~ s/\$isodate/&Foswiki::Search::revDate2ISO(
                        $info->get("date") )/ges;
                    $row =~ s/\$rev/$info->get("version")/ges;
                    if ( $users->can('findUser') ) {
                        my $user = $users->findUser( $info->get("author") );
                        $row =~ s/\$wikiusername/$user->webDotWikiName()/ges;
                        $row =~ s/\$wikiname/$user->wikiName()/ges;
                        $row =~ s/\$username/$user->login()/ges;
                    }
                    else {
                        my $user = $info->get("author");
                        $row =~
                          s/\$wikiusername/$users->webDotWikiName($user)/ges;
                        $row =~ s/\$wikiname/$users->wikiName($user)/ges;
                        $row =~ s/\$username/$users->login($user)/ges;
                    }
                }
                $row =~
s/\$createdate/Foswiki::Search::_getRev1Info( $sub->get("web"), $topic, "date" )/ges;
                $row =~
s/\$createusername/Foswiki::Search::_getRev1Info( $sub->get("web"), $topic, "username" )/ges;
                $row =~
s/\$createwikiname/Foswiki::Search::_getRev1Info( $sub->get("web"), $topic, "wikiname" )/ges;
                $row =~
s/\$createwikiusername/Foswiki::Search::_getRev1Info( $sub->get("web"), $topic, "wikiusername" )/ges;
            }

            $row =~ s/\r?\n/$newLine/gos if ($newLine);
            if ($theSeparator) {
                $row .= $theSeparator;
            }
            else {
                $row =~ s/([^\n])$/$1\n/os;    # add new line at end if needed
            }
            $row =~ s/\$formatTime\((.*?)(?:,\s*'([^']*?)')?\)/
              Foswiki::Func::formatTime(
                  _expandField($this, $1, $sub), $2)/geo;

            ## TW Below is almost like Foswiki::expandStandardEscapes
            ## were it not for the $TranslationToken
            $row =~ s/\$n\(\)/\n/gos;          # expand "$n()" to new line
            $row =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos;  # expand "$n" to new line
            $row =~
              s/\$nop(\(\))?//gos;    # remove filler, useful for nested search
            $row =~ s/\$quot(\(\))?/\"/gos;      # expand double quote
            $row =~ s/\$percnt(\(\))?/\%/gos;    # expand percent
            $row =~
              s/\$dollar(\(\))?/${TranslationToken}dollar${TranslationToken}/gos
              ;                                  # expand dollar

            # expand fields
            $row =~
s/\$([\w\.]+)\[(.*?)\]/_expandTable($this, $1, $2, $sub, $theSeparator, $newLine)/geo;
            $row =~ s/\$(\w+(?:.\w+)*)/_expandField($this, $1, $sub)/geo;

            # expand $dollar
            $row =~ s/${TranslationToken}dollar${TranslationToken}/\$/gos;

            $rows .= $row;
        }
        $cnt++;
    }

    if ($theSeparator) {
        $rows =~ s/$theSeparator$//s;    # remove separator at end
    }
    else {
        $rows =~ s/\n$//os;              # remove trailing new line
    }
    $rows = $this->{header} . $rows if ( defined( $this->{header} ) );
    $rows = $rows . $this->{footer} if ( defined( $this->{footer} ) );

    return $rows;
}

sub _expandField {
    my ( $this, $vbl, $map ) = @_;
    ASSERT( ref($map) ) if DEBUG;
    my $ret = $map->get($vbl);
    if ( !defined($ret) ) {

        # backward compatibility; if the vbl is not defined in the
        # hash, and it has a field called "form" that expands to the
        # name of another subfield that is a hash, then look that up instead.
        # This copes with the "old" style whereby form fields were
        # placed direct in the topic, though this usage is not documented.
        my $form = $map->get("form");
        if ( defined($form) ) {
            $form = $map->get($form);
            if ( defined($form) ) {
                $ret = $form->get($vbl);
            }
        }
    }

    if ( !defined($ret) ) {
        if ( $this->{help_undefined} ) {
            $ret = CGI::span( { class => 'twikiAlert' },
                "Undefined field <nop>$vbl" )
              . " (defined fields are: "
              . CGI::code( join( ', <nop>', grep { !/^\./ } $map->getKeys() ) );
        }
        else {
            $ret = "";
        }
    }
    return $ret;
}

sub _expandTable {
    my ( $this, $vbl, $fmt, $map, $theSeparator, $newLine ) = @_;
    ASSERT( ref($map) ) if DEBUG;
    my $table = $map->get($vbl);
    if ( !defined($table) ) {
        if ( $this->{help_undefined} ) {
            return CGI::span(
                { class => 'twikiAlert' },
                "Undefined field <nop>$vbl"
              ),
              " (defined fields are: "
              . CGI::code( join( ', <nop>', grep { !/^\./ } $map->getKeys() ) );
        }
        else {
            return "";
        }
    }
    my $attrs = new Foswiki::Contrib::DBCacheContrib::MemMap( initial => $fmt );
    my $format = new Foswiki::Plugins::FormQueryPlugin::TableFormat($attrs);

    return $format->formatTable( $table, $theSeparator, $newLine );
}

sub toString {
    my $this = shift;
    return unless $this;
    return
        "Format{ header=\""
      . $this->{header}
      . "\" format=\""
      . $this->{format}
      . "\" sort=\""
      . $this->{sort} . "\"}";
}

sub toTable {

    # This does not expand any calculations when constructing the table
    # (i.e., %CALC% embeded in the table itself)

    my ( $this, $entries, $sr, $rc, $topic, $web ) = @_;

    return CGI::span( { class => 'twikiAlert' }, 'Empty table' )
      if ( $entries->size() == 0 );

    # Initialize SpreadSheetPlugin
    use Foswiki::Plugins::SpreadSheetPlugin       ();
    use Foswiki::Plugins::SpreadSheetPlugin::Calc ();
    Foswiki::Plugins::SpreadSheetPlugin::initPlugin( $topic, $web );
    @Foswiki::Plugins::SpreadSheetPlugin::Calc::tableMatrix = ();
    my $cell = "";
    my @row  = ();

    if ( $entries->size() > 1 && defined( $this->{sort} ) ) {
        @compareFields = ();
        foreach my $field ( split( /\s*,\s*/, $this->{sort} ) ) {
            my $numeric = 0;
            my $reverse = 0;
            $field =~ s/^\#-/-\#/o;
            $reverse = 1 if ( $field =~ s/^-//o );
            $numeric = 1 if ( $field =~ s/^\#//o );
            push(
                @compareFields,
                {
                    name    => $field,
                    reverse => $reverse,
                    numeric => $numeric
                }
            );
        }
        @{ $entries->{values} } = sort _compare @{ $entries->{values} };
    }

    $sr = 0 if ( !defined($sr) || $sr < 0 );
    $rc = $entries->size() if ( !defined($rc) || $rc < 0 );
    my $cnt = 0;
    $Foswiki::Plugins::SpreadSheetPlugin::Calc::rPos = -1;
    $Foswiki::Plugins::SpreadSheetPlugin::Calc::cPos = -1;
    foreach my $sub ( $entries->getValues() ) {
        if ( ref($sub) && $cnt >= $sr && $cnt < $sr + $rc ) {
            my $line = $this->{format};

            #not sure what the next line is for
            $line =~
              s/\$([\w\.]+)\[(.*?)\]/_expandTable($this, $1, $2, $sub)/ge;
            $line =~ s/\$(\w+(?:\.\w+)*)/_expandField($this, $1, $sub)/ge;

            # The next seems to wipe out everything if not formatted as table
            $line =~ s/^(\s*\|)(.*)\|\s*$/$2/o;
            @row = split( /\|/o, $line, -1 );
            push @Foswiki::Plugins::SpreadSheetPlugin::Calc::tableMatrix,
              [@row];
            $Foswiki::Plugins::SpreadSheetPlugin::Calc::rPos++
              if $Foswiki::Plugins::SpreadSheetPlugin::Calc::rPos < 0;
            $Foswiki::Plugins::SpreadSheetPlugin::Calc::rPos++;
        }
        $cnt++;
    }

    return "";
}

1;
