# TWiki::Plugins::MultiLangPlugin
# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Useful functions for maintaining a site consisting of several
# TWikis that represent translations of the same content to
# several languages.
#
# Copyright (C) 2005 Frank Lichtenheld, frank@lichtenheld.de,
#                    developed for DENX Software Engineering
# based on TWiki::Plugins::EmtpyPlugin which is
#     Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
#     Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
# partly based on FindElsewherePlugin which is
#     Copyright (C) 2003 Martin Cleaver, (C) 2004 Matt Wilkie
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

# =========================
package TWiki::Plugins::MultiLangPlugin;

use strict;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug
  $dataDirForm $viewUrlForm $scriptUrlForm $scriptPathForm
  @usedSiteLangs %usedSiteLangs $currentLang
  $doListNonExistingTrans $doListCurrentTrans $doFindInOtherLangs
  $doFindOnlyFirstOther $doPluralToSingular $doCrossLangLinks
  $outdatedMinimum $outdatedMaximum
  $originalDoesntExist $translationOutdated $translationTooOutdated
  $translationUpToDate
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'MultiLangPlugin';    # Name of this Plugin

my %langNames = (
    en => 'English',
    de => 'Deutsch',
    es => 'Espanol',
);

my %formNames = (
    VIEWURLFORM    => \$viewUrlForm,
    SCRIPTURLFORM  => \$scriptUrlForm,
    SCRIPTPATHFORM => \$scriptPathForm,
    DATADIRFORM    => \$dataDirForm
);

my %regex;

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    $regex{webNameRegex}  = TWiki::Func::getRegularExpression('webNameRegex');
    $regex{wikiWordRegex} = TWiki::Func::getRegularExpression('wikiWordRegex');
    $regex{mixedAlpha}    = TWiki::Func::getRegularExpression('mixedAlpha');
    $regex{mixedAlphaNum} = TWiki::Func::getRegularExpression('mixedAlphaNum');
    $regex{abbrevRegex}   = TWiki::Func::getRegularExpression('abbrevRegex');
    $regex{singleMixedAlphaNumRegex} = qr/[A-Za-z0-9]/;

    # TODO: getPluginPreferencesFlag is broken with latest stable
    # but works in alpha, for now work around that

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("MULTILANGPLUGIN_DEBUG");

    # Get plugin preferences
    $currentLang = TWiki::Func::getPluginPreferencesValue("WIKILANG") || "en";

    # form strings with @LANG@ var
    $dataDirForm = TWiki::Func::getPluginPreferencesValue("DATADIRFORM")
      || guessForm( TWiki::Func::getDataDir() );
    $viewUrlForm = TWiki::Func::getPluginPreferencesValue("VIEWURLFORM")
      || guessForm(
        TWiki::Func::getViewUrl( $web, $topic ),
        $web   => 'WEB',
        $topic => 'TOPIC',
        view   => 'SCRIPT'
      );
    $scriptUrlForm = TWiki::Func::getPluginPreferencesValue("SCRIPTURLFORM")
      || guessForm(
        TWiki::Func::getUrlHost() . TWiki::Func::getScriptUrlPath() );
    $scriptPathForm = TWiki::Func::getPluginPreferencesValue("SCRIPTPATHFORM")
      || guessForm( TWiki::Func::getScriptUrlPath() );

    # requested languages
    # TODO: guess available languages
    my $langs = TWiki::Func::getPluginPreferencesValue("LANGUAGES")
      || $currentLang;
    my @langs = sort split /\s*,\s*/, $langs;

    # rendering preferences
    $doListNonExistingTrans =
      TWiki::Func::getPreferencesFlag("MULTILANGPLUGIN_LISTNONEXISTANT");
    $doListCurrentTrans =
      TWiki::Func::getPreferencesFlag("MULTILANGPLUGIN_LISTCURRENT");
    $doFindInOtherLangs =
      TWiki::Func::getPreferencesFlag("MULTILANGPLUGIN_FINDINOTHERLANGS");
    $doFindOnlyFirstOther =
      TWiki::Func::getPreferencesFlag("MULTILANGPLUGIN_ONLYFINDFIRSTOTHER");
    $doPluralToSingular =
      TWiki::Func::getPreferencesFlag("MULTILANGPLUGIN_PLURALTOSINGULAR");
    $doCrossLangLinks =
      TWiki::Func::getPreferencesFlag("MULTILANGPLUGIN_CROSSLANGLINKS");
    $outdatedMinimum =
      TWiki::Func::getPluginPreferencesValue("OUTDATEDMINIMUM");
    $outdatedMaximum =
      TWiki::Func::getPluginPreferencesValue("OUTDATEDMAXIMUM");

    # output
    $originalDoesntExist =
      TWiki::Func::getPluginPreferencesValue("DOESNTEXIST_TXT");
    $translationOutdated =
      TWiki::Func::getPluginPreferencesValue("OUTDATED_TXT");
    $translationTooOutdated =
      TWiki::Func::getPluginPreferencesValue("TOOOUTDATED_TXT");
    $translationUpToDate =
      TWiki::Func::getPluginPreferencesValue("UPTODATE_TXT");

    foreach my $l (@langs) {
        my $dir = useForm( $dataDirForm, $l );
        if ( -d $dir ) {
            push @usedSiteLangs, $l;
        }
        else {
            TWiki::Func::writeWarning(
"- ${pluginName}::initPlugin( $web.$topic ): data directory for $l doesn't seem to exist ($dataDirForm => $dir)"
            ) if $debug;
        }
    }
    %usedSiteLangs = map { $_ => 1 } @usedSiteLangs;
    TWiki::Func::writeDebug(
"- ${pluginName}::initPlugin( $web.$topic ): using languages @usedSiteLangs"
    ) if $debug;

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    $_[0] =~ s/%MLP_DATADIRFORM%/$dataDirForm/g;
    $_[0] =~ s/%MLP_VIEWURLFORM%/$viewUrlForm/g;
    $_[0] =~ s/%MLP_SCRIPTURLFORM%/$scriptUrlForm/g;
    $_[0] =~ s/%MLP_SCRIPTPATHFORM%/$scriptPathForm/g;
    $_[0] =~ s/%MLP_USEFORM{(.*?)}%/&renderUseForm($1)/ge;
    $_[0] =~ s/%TRANSLATIONS%/&renderTransList($web, $topic)/ge;
    $_[0] =~ s/%TRANSLATIONCHECK%/&renderTransCheck($web, $topic)/ge;
}

# =========================
sub startRenderingHandler {
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug("- ${pluginName}::startRenderingHandler( $_[1] )")
      if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;

    # copied from FindElseWherePlugin
    $_[0] =~ s/([\s\(])($regex{webNameRegex}\.$regex{wikiWordRegex}
			  |$regex{wikiWordRegex}
			  |\[\[[$regex{mixedAlphaNum}.\s]+\]\]
			  |$regex{webNameRegex}\.$regex{abbrevRegex}
			  |$regex{abbrevRegex})
	  /&findInOtherLangs($_[1],$1,$2,$2,"")/gxeo if $doFindInOtherLangs;
    $_[0] =~ s/([\s\(])\[\[([$regex{mixedAlphaNum}.\s]+)\]\[([^\]]+)\]\]
	  /&findInOtherLangsSpecific($_[1],$1,$2,$3,"")/gxeo if $doFindInOtherLangs;

    # similar to InterwikiPlugin
    $_[0] =~ s/([\s\(])(\[\[)?([$regex{mixedAlpha}]+)
	  :($regex{webNameRegex}\.$regex{wikiWordRegex}
	    |$regex{wikiWordRegex}
	    |$regex{webNameRegex}\.$regex{abbrevRegex}
	    |$regex{abbrevRegex})(\]\])?
		/&handleCrossLangLink($_[1],$1,$2,$3,$4,$5)/gxeo if $doCrossLangLinks;

}

# =========================

=pod

=head1 NAME

TWiki::Plugins::MultiLangPlugin - maintain translations of your TWiki in other TWikis

=head1 INTERFACE

=head2 Plugin Interface

See the TWiki::Plugins documentation

=head2 Internal Interface

MultiLangPlugin uses the following internal functions.
The current language (configured by WIKILANG) is available
globally and is not given to each function call.

=head3 Form Managment

=head4 guessForm( $path )

Replaces every occourence of C</$currentLang/> in $path with C</#LANG#/>
and returns the altered string.

FIXME: document new parameter %subst

=cut

sub guessForm {
    my ( $path, %subst ) = @_;

    TWiki::Func::writeDebug(
        "- ${pluginName}::guessForm( @_ ) (lang=$currentLang)")
      if $debug;

    if ( $path =~ s,/\Q$currentLang\E/,/\#LANG\#/,g ) {
        foreach my $s ( keys %subst ) {
            $path =~ s,\b\Q$s\E\b,\#$subst{$s}\#,g;
        }
        return $path;
    }
    else {
        return "";
    }
}

=pod

=head4 useForm( $form, $lang )

Replaces each occourence of C<#LANG#> in $form with $lang and returns
the altered string. Other substitutions may be supported in the future.

FIXME: document new paramter %subst

=cut

sub useForm {
    my ( $form, $lang, %subst ) = @_;

    $form =~ s/\#LANG\#/$lang/g;
    foreach my $s ( keys %subst ) {
        $form =~ s/\#\Q$s\E\#/$subst{$s}/g;
    }

    return $form;
}

=pod

=head3 Link creation

=head4 makeUrl( $web, $topic, $lang, $script )

Composes (and returns) a URL to $web.$topic in the TWiki for lang $lang.
$script is optional and defaults to 'view'.

=cut

sub makeUrl {
    my ( $web, $topic, $lang, $script ) = @_;
    $script = 'view' unless defined $script;

    # FIXME: Support $extension
    if ( ( $script eq 'view' ) || ( $viewUrlForm =~ /\#SCRIPT\#/o ) ) {
        return useForm(
            $viewUrlForm, $lang,
            SCRIPT => $script,
            WEB    => $web,
            TOPIC  => $topic
        );
    }
    else {
        return useForm( $scriptUrlForm, $lang ) . "/$script/$web/$topic";
    }
}

=pod

=head4 makeLink( $web, $topic, $lang, $linkText, $script )

Composes (and returns) a complete HTML anchor to $web.$topic in
the TWiki for lang $lang. The anchor will have the class
C<translationLink>. $script is optional and defaults to 'view'.

=cut

sub makeLink {
    my ( $web, $topic, $lang, $linkText, $script ) = @_;
    $script = 'view' unless defined $script;

    my $url = makeUrl( $web, $topic, $lang, $script );
    my $ln = $langNames{$lang} || '';
    return
"<a class=\"translationLink\" rel=\"alternate\" lang=\"$lang\" title=\"$ln\" href=\"$url\">$linkText</a>";
}

=pod

=head3 Information extraction from other TWikis

=head4 topicExists( $lang, $web, $topic )

Like TWiki::Func::topicExists but with an additional $lang parameter.

=cut

sub topicExists {
    my ( $lang, $web, $topic ) = @_;

    return -e useForm( $dataDirForm, $lang ) . "/$web/$topic.txt";
}

=pod

=head4 getTransForTopic( $web, $topic )

Get a list of all languages the topic is translated to.

=cut

sub getTransForTopic {
    my ( $web, $topic ) = @_;

    return grep { &topicExists( $_, $web, $topic ) } @usedSiteLangs;
}

=pod

=head4 getRevDiff( $lang, $web, $topic, $rev )

Get the difference between the current revision of
$web.$topic in TWiki $lang and $rev. Returns an integer and
C<undef> in case of any error. The error will be logged to
the debug log if debugging is enabled for this plugin.

LIMITATIONS: Uses the meta data in the topic file not RCS information or
the like. Doesn't repect the used TWiki::Store implementation, just
assumes the default. Only supports revisions "1.x".

=cut

sub getRevDiff {
    my ( $lang, $web, $topic, $rev ) = @_;

    open my $fh, useForm( $dataDirForm, $lang ) . "/$web/$topic.txt" or do {
        TWiki::Func::writeDebug(
"- ${pluginName}::getRevDiff( $lang, $web, $topic, $rev ): file not found"
        ) if $debug;
        return undef;
    };

    my $origRev;
    while (<$fh>) {
        next unless /^\%/;

        if (/^\%META:TOPICINFO\{.*\sversion=\"(\d+)\.(\d+)\"/) {
            $origRev = $2;
            die "D'oh!" unless $1 == 1;    # TODO
            last;
        }
    }
    unless ($origRev) {
        TWiki::Func::writeDebug(
"- ${pluginName}::getRevDiff( $lang, $web, $topic, $rev ): revision not found"
        ) if $debug;
        return undef;
    }

    TWiki::Func::writeDebug(
"- ${pluginName}::getRevDiff( $lang, $web, $topic, $rev ): revDiff = $origRev - $rev"
    ) if $debug;

    return $origRev - $rev;
}

=pod

=head3 Rendering

=head4 renderTransList( $web, $topic )

Render %TRANSLATIONS%. Not yet documented.

=cut

sub renderTransList {
    my ( $web, $topic ) = @_;

    TWiki::Func::writeDebug(
        "- ${pluginName}::renderTransList( $web, $topic ) (lang=$currentLang)")
      if $debug;

    my @existingTrans = getTransForTopic( $web, $topic );
    my @links = ();

    foreach my $t (@existingTrans) {
        next if ( $t eq $currentLang ) && !$doListCurrentTrans;
        push @links, makeLink( $web, $topic, $t, $langNames{$t} );
    }

    # TODO: sort (use langcmp from Debian website?)
    return join( " ", @links );
}

# purely internal
sub _replaceLinkAttrs {
    my ( $text, $lang, $web, $topic ) = @_;

    TWiki::Func::writeDebug(
        "- ${pluginName}::replaceLinkAttrs( \"$text\", $lang, $web, $topic )")
      if $debug;

    my $url = makeUrl( $web, $topic, $lang, 'view' );
    $text =~ s/\#LINKATTRS\#/href="$url" lang="$lang"/g;

    return $text;
}

=pod

=head4 renderTransCheck( $web, $topic )

Render %TRANSLATIONCHECK%. Not yet documented.

=cut

sub renderTransCheck {
    my ( $web, $topic ) = @_;

    TWiki::Func::writeDebug(
        "- ${pluginName}::renderTransCheck( $web, $topic ) (lang=$currentLang)")
      if $debug;

    my $translatedLang =
      TWiki::Func::expandCommonVariables( '%FORMFIELD{"TranslatedLanguage"}%',
        $topic, $web )
      || "";
    my $translatedRev =
      TWiki::Func::expandCommonVariables( '%FORMFIELD{"TranslatedRevision"}%',
        $topic, $web )
      || "";

    $translatedRev =~ s/^(\d+)\.(\d+)/$2/;

    return "" unless $translatedRev;

    TWiki::Func::writeDebug(
"- ${pluginName}::renderTransCheck( $web, $topic ): $translatedLang/$translatedRev"
    ) if $debug;

    my $revDiff = getRevDiff( $translatedLang, $web, $topic, $translatedRev );
    unless ( defined($revDiff) ) {
        return _replaceLinkAttrs( $originalDoesntExist, $translatedLang, $web,
            $topic );
    }

    if ( $revDiff >= $outdatedMaximum ) {
        return _replaceLinkAttrs( $translationTooOutdated, $translatedLang,
            $web, $topic );
    }
    elsif ( $revDiff >= $outdatedMinimum ) {
        return _replaceLinkAttrs( $translationOutdated, $translatedLang, $web,
            $topic );
    }
    else {
        return _replaceLinkAttrs( $translationUpToDate, $translatedLang, $web,
            $topic );
    }
}

=pod

=head4 renderUseForm( $text )

Render %MLP_USEFORM%. Not yet documented.

=cut

sub renderUseForm {
    my ($text) = @_;

    TWiki::Func::writeDebug("- ${pluginName}::renderUseForm( \"$text\" )")
      if $debug;

    my $form = TWiki::Func::extractNameValuePair($text) || "notExistant";
    unless ( exists $formNames{$form} ) {
        TWiki::Func::writeWarning(
"- ${pluginName}::renderUseForm( \"$text\" ): $form is no known form name"
        );
        return $text;
    }

    my $lang = TWiki::Func::extractNameValuePair( $text, 'lang' );

    return useForm( ${ $formNames{$form} }, $lang );
}

# =========================
# begin of code based on FindElsewherePlugin

# purely internal
sub _makeSingular {
    my ($theWord) = @_;

    $theWord =~ s/ies$/y/o;          # plurals like policy / policies
    $theWord =~ s/sses$/ss/o;        # plurals like address / addresses
    $theWord =~ s/([Xx])es$/$1/o;    # plurals like box / boxes
    $theWord =~
      s/([A-Za-rt-z])s$/$1/o;    # others, excluding ending ss like address(es)
    return $theWord;
}

=pod

=head4 findInOtherLangs( $web, $preamble, $topic, $linkText, $anchor )

Links WikiWords to other languages if they can't be linked in the current
TWiki. The actual parsing is done in the plugin part.

Based on TWiki::Plugins::FindElsewherePlugin which in turn based their
function on TWiki::Func::internalLink.

PROBLEMS: It would be good to reduce the amount of code copied
between these three modules, though I don't have any idea yet how.

=cut

sub findInOtherLangsSpecific {

    my ( $theWeb, $thePreamble, $theTopic, $theLinkText, $theAnchor ) = @_;

    TWiki::Func::writeDebug(
"- ${pluginName}::findInOtherLangsSpecific( $theWeb, \"$thePreamble\", $theTopic, $theLinkText, $theAnchor )"
    ) if $debug;

    my $oldText = $thePreamble . $theTopic;

    my $newText =
      findInOtherLangs( $theWeb, $thePreamble, $theTopic, $theLinkText,
        $theAnchor );

    my $result;
    if ( $oldText eq $newText ) {
        $result = "$thePreamble\[[$theTopic][$theLinkText]]";
    }
    else {
        $result = $newText;
    }

    TWiki::Func::writeDebug(
        "- ${pluginName}::findInOtherLangsSpecific(): return \"$result\"")
      if $debug;

    return $result;
}

sub findInOtherLangs {

    # copied from FindElseWherePlugin

    my ( $theWeb, $thePreamble, $theTopic, $theLinkText, $theAnchor ) = @_;

    TWiki::Func::writeDebug(
"- ${pluginName}::findInOtherLangs( $theWeb, \"$thePreamble\", $theTopic, $theLinkText, $theAnchor )"
    ) if $debug;

    # preserve link style formatting
    my $oldTheTopic = $theTopic;

    if ( $theTopic =~ /($regex{webNameRegex})\.($regex{wikiWordRegex})/o ) {
        ( $theWeb, $theTopic ) = ( $1, $2 );
    }

    # Turn spaced-out names into WikiWords - upper case first letter of
    # whole link, and first of each word.
    $theTopic =~ s/^(.)/\U$1/o;
    $theTopic =~ s/\s($regex{singleMixedAlphaNumRegex})/\U$1/go;
    $theTopic =~ s/\[\[($regex{singleMixedAlphaNumRegex})(.*)\]\]/\u$1$2/o;

    my $text = $thePreamble;

    # Look in the current TWiki, return when found
    my $exist = &TWiki::Func::topicExists( $theWeb, $theTopic );
    if ( !$exist ) {
        if ( ($doPluralToSingular) && ( $theTopic =~ /s$/ ) ) {
            my $theTopicSingular = _makeSingular($theTopic);
            if ( &TWiki::Func::topicExists( $theWeb, $theTopicSingular ) ) {
                &TWiki::Func::writeDebug(
                    "- $theTopicSingular was found in $theWeb.")
                  if $debug;
                $text .= $oldTheTopic;    # leave it as we found it
                return $text;
            }
        }
    }
    else {
        &TWiki::Func::writeDebug("- $theTopic was found in $theWeb.") if $debug;
        $text .= $oldTheTopic;            # leave it as we found it
        return $text;
    }

    # Look for translations, return when found
    my @topicLinks;
    foreach my $otherLang (@usedSiteLangs) {

        my $exist = topicExists( $otherLang, $theWeb, $theTopic );
        if ( !$exist ) {
            if ( ($doPluralToSingular) && ( $theTopic =~ /s$/ ) ) {
                my $theTopicSingular = _makeSingular($theTopic);
                if ( topicExists( $otherLang, $theWeb, $theTopicSingular ) ) {
                    &TWiki::Func::writeDebug(
                        "- $theWeb.$theTopicSingular was found in $otherLang.")
                      if $debug;
                    push( @topicLinks, [ $theWeb, $theTopic, $otherLang ] );
                }
            }
        }
        else {
            &TWiki::Func::writeDebug(
                "- $theWeb.$theTopic was found in $otherLang.")
              if $debug;
            push( @topicLinks, [ $theWeb, $theTopic, $otherLang ] );
        }
    }

    if (   ( @topicLinks == 1 )
        || ( ( @topicLinks > 1 ) && $doFindOnlyFirstOther ) )
    {

        # Prepend WikiWords with <nop>, preventing double links
        $theLinkText =~ s/([\s\(])($regex{wikiWordRegex})/$1<nop>$2/go;
        $text .= makeLink( @{ $topicLinks[0] }, $theLinkText );
    }
    elsif ( @topicLinks > 1 ) {

        # If link text [[was in this form]] <em> it
        #$theLinkText =~ s/\[\[(.*)\]\]/<em>$1<\/em>/go;
        # Prepend WikiWords with <nop>, preventing double links
        $theLinkText =~ s/([\s\(])($regex{wikiWordRegex})/$1<nop>$2/go;
        $text .= "<nop>$theLinkText<sup>(";
        $text .= join( ",",
            map { my $otherLang = $_->[-1]; makeLink( @$_, $otherLang ) }
              @topicLinks )
          . ")</sup>";
    }
    else {
        &TWiki::Func::writeDebug(
            "- $theTopic is not in any of these languages: @usedSiteLangs.")
          if $debug;
        $text .= $oldTheTopic;
    }

    return $text;

}

# end of code based on FindElsewherePlugin
# =================

=pod

=head4 handleCrossLangLink( $web, $preamble, $openSquareBrack, $lang, $topic, $closeSquareBrack )

For handling links of the form lang:Web.Topic, the actual parsing is done
in the plugin part.

=cut

sub handleCrossLangLink {
    my ( $theWeb, $linkPrefix, $openSquareBrack, $langPrefix, $theTopic,
        $closeSquareBrack )
      = @_;

    TWiki::Func::writeDebug(
"- ${pluginName}::handleCrossLangLink( $theWeb, $linkPrefix, $openSquareBrack, $langPrefix, $theTopic, $closeSquareBrack )"
    ) if $debug;

    $openSquareBrack  ||= "";
    $closeSquareBrack ||= "";

    return "$linkPrefix$openSquareBrack$langPrefix:$topic$closeSquareBrack"
      if $openSquareBrack xor $closeSquareBrack;    # shouldn't happen

    my $theOldTopic = $theTopic;

    if ( $theTopic =~ /($regex{webNameRegex})\.($regex{wikiWordRegex})/o ) {
        ( $theWeb, $theTopic ) = ( $1, $2 );
    }

    return $linkPrefix
      . makeLink( $theWeb, $theTopic, $langPrefix, $theOldTopic );
}

1;
__END__

=head1 BUGS

See data/TWiki/MultiLangPlugin.txt in the source code or
%SYSTEMWEB%.MultiLangPlugin if you installed it in your TWiki.

=head1 COPYRIGHT

Copyright (C) 2005 Frank Lichtenheld, frank@lichtenheld.de, developed
for DENX Software Engineering

based on TWiki::Plugins::EmtpyPlugin which is
 Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
 Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com

partly based on FindElsewherePlugin which is
 Copyright (C) 2003 Martin Cleaver, (C) 2004 Matt Wilkie

This plugin is distributed under the terms of the GNU Public
License, Version 2. See the source code for more details.

=head1 SEE ALSO

TWiki, TWiki::Plugins, TWiki::Func, TWiki::Plugins::FindElsewherePlugin
