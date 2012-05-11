# Foswiki - The Free and Open Source Wiki, http://foswiki.org/

package TWiki::Contrib::EditContrib::Include41;

use strict;
use TWiki;

sub _INCLUDE {
    my ( $this, $params, $includingTopic, $includingWeb ) = @_;

    # remember args for the key before mangling the params
    my $args = $params->stringify();

    # Remove params, so they don't get expanded in the included page
    my $path    = $params->remove('_DEFAULT') || '';
    my $pattern = $params->remove('pattern');
    my $rev     = $params->remove('rev');
    my $section = $params->remove('section');
    my $raw     = $params->remove('raw') || '';
    my $warn    = $params->remove('warn')
      || $this->{prefs}->getPreferencesValue('INCLUDEWARNING');

    if ( $path =~ /^https?\:/ ) {

        # include web page
        return $this->_includeUrl( $path, $pattern, $includingWeb,
            $includingTopic, $raw, $params, $warn );
    }

    $path =~ s/$TWiki::cfg{NameFilter}//go;    # zap anything suspicious
    if ( $TWiki::cfg{DenyDotDotInclude} ) {

        # Filter out '..' from filename, this is to
        # prevent includes of '../../file'
        $path =~ s/\.+/\./g;
    }
    else {

        # danger, could include .htpasswd with relative path
        # SMELL: this hack is a bit pointless, really.
        $path =~ s/passwd//gi;                 # filter out passwd filename
    }

    # make sure we have something to include. If we don't do this, then
    # normalizeWebTopicName will default to WebHome. Item2209.
    unless ($path) {

        # SMELL: could do with a different message here, but don't want to
        # add one right now because translators are already working
        return $this->_includeWarning( $warn, 'topic_not_found', '""', '""' );
    }

    my $text = '';
    my $meta = '';
    my $includedWeb;
    my $includedTopic = $path;
    $includedTopic =~ s/\.txt$//;    # strip optional (undocumented) .txt

    ( $includedWeb, $includedTopic ) =
      $this->normalizeWebTopicName( $includingWeb, $includedTopic );

    # See Codev.FailedIncludeWarning for the history.
    unless ( $this->{store}->topicExists( $includedWeb, $includedTopic ) ) {
        return $this->_includeWarning( $warn, 'topic_not_found', $includedWeb,
            $includedTopic );
    }

    # prevent recursive includes. Note that the inclusion of a topic into
    # itself is not blocked; however subsequent attempts to include the
    # topic will fail. There is a hard block of 99 on any recursive include.
    my $key = $includingWeb . '.' . $includingTopic;
    my $count = grep( $key, keys %{ $this->{includes} } );
    $key .= $args;
    if ( $this->{includes}->{$key} || $count > 99 ) {
        return $this->_includeWarning( $warn, 'already_included',
            "$includedWeb.$includedTopic", '' );
    }

    my %saveTags  = %{ $this->{SESSION_TAGS} };
    my $prefsMark = $this->{prefs}->mark();

    $this->{includes}->{$key}             = 1;
    $this->{SESSION_TAGS}{INCLUDINGWEB}   = $includingWeb;
    $this->{SESSION_TAGS}{INCLUDINGTOPIC} = $includingTopic;

    # copy params into session tags
    foreach my $k ( keys %$params ) {
        $this->{SESSION_TAGS}{$k} = $params->{$k};
    }

    ( $meta, $text ) =
      $this->{store}->readTopic( undef, $includedWeb, $includedTopic, $rev );

    unless (
        $this->{security}->checkAccessPermission(
            'VIEW', $this->{user},  $text,
            $meta,  $includedTopic, $includedWeb
        )
      )
    {
        if ( isTrue($warn) ) {
            return $this->inlineAlert( 'alerts', 'access_denied',
                $includedTopic );
        }    # else fail silently
        return '';
    }

    $this->{plugins}
      ->beforeCommonTagsHandler( $text, $includedTopic, $includedWeb );

    # remove everything before and after the selected include block
    if ( !$section ) {
        $text =~ s/.*?%STARTINCLUDE%//s;
        $text =~ s/%STOPINCLUDE%.*//s;
    }

    # handle sections
    my ( $ntext, $sections ) = TWiki::parseSections($text);

    my $interesting = ( defined $section );
    if ( scalar(@$sections) ) {

        # Rebuild the text from the sections
        $text = '';
        foreach my $s (@$sections) {
            if (   $section
                && $s->{type} eq 'section'
                && $s->{name} eq $section )
            {
                $text .= substr( $ntext, $s->{start}, $s->{end} - $s->{start} );
                $interesting = 1;
                last;
            }
            elsif ( $s->{type} eq 'include' && !$section ) {
                $text .= substr( $ntext, $s->{start}, $s->{end} - $s->{start} );
                $interesting = 1;
            }
        }
    }

    # If there were no interesting sections, restore the whole text
    $text = $ntext unless $interesting;

    $text = TWiki::applyPatternToIncludedText( $text, $pattern ) if ($pattern);

    $this->_expandAllTags( \$text, $includedTopic, $includedWeb );

    # 4th parameter tells plugin that its called for an included file
    $this->{plugins}
      ->commonTagsHandler( $text, $includedTopic, $includedWeb, 1 );

   # We have to expand tags again, because a plugin may have inserted additional
   # tags.
    $this->_expandAllTags( \$text, $includedTopic, $includedWeb );

    # If needed, fix all 'TopicNames' to 'Web.TopicNames' to get the
    # right context
    # SMELL: This is a hack.
    if ( $includedWeb ne $includingWeb ) {
        my $removed = {};

        # Must handle explicit [[]] before noautolink
        # '[[TopicName]]' to '[[Web.TopicName][TopicName]]'
        $text =~
          s/\[\[([^\]]+)\]\]/&TWiki::_fixIncludeLink( $includedWeb, $1 )/geo;

        # '[[TopicName][...]]' to '[[Web.TopicName][...]]'
        $text =~
s/\[\[([^\]]+)\]\[([^\]]+)\]\]/&TWiki::_fixIncludeLink( $includedWeb, $1, $2 )/geo;

        unless (
            TWiki::isTrue( $this->{prefs}->getPreferencesValue('NOAUTOLINK') ) )
        {

            # Handle WikiWords
            $text =
              $this->{renderer}->takeOutBlocks( $text, 'noautolink', $removed );
        }

        # 'TopicName' to 'Web.TopicName'
        $text =~
s/(^|[\s(])($TWiki::regex{webNameRegex}\.$TWiki::regex{wikiWordRegex})/$1$TWiki::TranslationToken$2/go;
        $text =~
          s/(^|[\s(])($TWiki::regex{wikiWordRegex})/$1$includedWeb\.$2/go;
        $text =~ s/(^|[\s(])$TWiki::TranslationToken/$1/go;

        $this->{renderer}->putBackBlocks( \$text, $removed, 'noautolink' );
    }

    # handle tags again because of plugin hook
    $this->_expandAllTags( \$text, $includedTopic, $includedWeb );

    # restore the tags
    delete $this->{includes}->{$key};
    %{ $this->{SESSION_TAGS} } = %saveTags;

    $this->{prefs}->restore($prefsMark);
    $text =~ s/^[\r\n]+/\n/;
    $text =~ s/[\r\n]+$/\n/;

    return $text;
}

1;
