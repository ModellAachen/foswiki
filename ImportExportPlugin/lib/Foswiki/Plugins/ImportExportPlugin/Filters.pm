# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::ImportExportPlugin::Filters

filters for importing

=cut

package Foswiki::Plugins::ImportExportPlugin::Filters;

# Always use strict to enforce variable scoping
use strict;
use warnings;
use Foswiki::Plurals;
use Error qw( :try );

our %switchboard = (
    selectwebs   => \&selectwebs,
    selecttopics => \&selecttopics,
    skiptopics   => \&skiptopics,
    twiki        => \&twiki,
    chklinks     => \&chkLinks,
    text_regex   => \&text_regex,
    userweb      => \&userweb
);

#use to order the filters.
our %switchboard_order = (
    selectwebs   => 0,
    selecttopics => 1,
    skiptopics   => 2,
    twiki        => 3,
    chklinks     => 4,
    text_regex   => 5,
    userweb      => 6
);

#used for TWiki conversions
our $oldTWikiWebtopics = '('
  . join(
    '|',
    (
        keys(
            %{
                $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}
                  {TWikiWebTopicNameConversion}
              }
        )
    )
  ) . ')';
our $oldMainWebtopics = '('
  . join(
    '|',
    (
        keys(
            %{
                $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}
                  {MainWebTopicNameConversion}
              }
        )
    )
  ) . ')';

=begin TML

TODO( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params ) -> ( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params )

TODO: need to add the following filters
   * html - convert a set of html files to foswiki format, need a remove_prefix, remove_postfix, html2tml, 
   * rename webs - list of from -> to conversions, including some mechanism to merge webs together (drop dups, merge dupes, rename second dup..)
   * skipdistrotopics - work out what topics are unmodified by wiki users (ie, shipped in the release) and skip those that were from the old (or twiki) release
   * check / fix up attachments - ./rest /UpdateAttachmentsPlugin/update -topic Web
   * initialise Tags (given a tag, tag that topic if the topic contains the tag word) - 
      *    my $cmd = "grep '\\-\\-\\-+' ../data/$params{web}/*.txt | grep -s $tag | sed 's/..\\/data\\/$params{web}\\//.\\/rest \\/TagMePlugin\\/addTag tag=$tag webtopic=$params{web}./' | sed 's/.txt.*//' | sh";


=cut

=begin TML

---++ ClassMethod nothing( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params ) -> ( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params )

does nothing - copy to create a new filter.

=cut

sub nothing {
    my %params = @_;

    return %params;
}

=begin TML

---++ ClassMethod text_regex( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params ) -> ( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params )

runs a regex over the topic text (only)

uses 2 params, separated by a ; eg:
   * text_regex(TWiki;Wiki)

=cut

sub topic_regex {
    my %params = @_;

    my ( $m, $r ) = split( /(?!\\);/, $params{params} );
    if ( defined($r) ) {
        if ( $params{text} =~ s/$m/$r/ge ) {
            $params{result} .=
              "topic_regex($params{web}, $params{topic}, $params{params})\n";
        }
    }

    return %params;
}

=begin TML

---++ ClassMethod chkLinks( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params ) -> ( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params )

   * chkLinks - check for URLs and wiki links, report on them with frequency, broken link, missing topic, html links to in-wiki topics
      * TODO: plus a 'fixup' option :)

=cut

my %testedLinkCache;

sub chkLinks {
    my %params = @_;

    #TODO: search url  links to topics (and add fixup)
    #TODO: does not do plurals, even thought Foswiki core does
    #print STDERR "chkLinks($params{topic})\n";
    $Foswiki::Plugins::ImportExportPlugin::checkingLinks     = 1;
    %Foswiki::Plugins::ImportExportPlugin::wikiWordsRendered = ();

    #test for bad links in rendered html
    my $html;
    eval {
        $params{expanded_tml} =
          Foswiki::Func::expandCommonVariables( $params{text}, $params{topic},
            $params{web} );
        $params{expanded_html} = $html =
          Foswiki::Func::renderText( $params{expanded_tml}, $params{web},
            $params{topic} );
    };
    if ($@) {
        $params{crash}  = $@;
        $params{result} = 'crash';
    }
    else {
        my %links;
        $html =~ s/href=['"](.*?)['"]/$links{$1}++/gem;

        #remove links to things that exist - start with renderWikiWordHandler
        foreach my $link (
            keys(%Foswiki::Plugins::ImportExportPlugin::wikiWordsRendered) )
        {
            if ( not exists $testedLinkCache{$link} ) {
                my $webtopic = $link;
                my ( $lweb, $ltopic ) =
                  Foswiki::Func::normalizeWebTopicName( $params{web},
                    $webtopic );

                #lets see if we can detect ANCRONYMs
                my $renderedlink =
                  Foswiki::Func::internalLink( '', $lweb, $ltopic, $ltopic );
                $testedLinkCache{$link} = 'nolink'
                  if ( $renderedlink eq $ltopic );

#print STDERR "OOOOOOOOOO $link($params{web}, $webtopic): $lweb, $ltopic => $renderedlink\n"
                if ( not exists $testedLinkCache{$link} ) {
                    $testedLinkCache{$link} =
                      Foswiki::Func::topicExists( $lweb, $ltopic );
                    if ( not $testedLinkCache{$link} ) {

                        # topic not found - try to singularise
                        my $singular =
                          Foswiki::Plurals::singularForm( $lweb, $ltopic );
                        if ($singular) {
                            $testedLinkCache{$link} =
                              Foswiki::Func::topicExists( $lweb, $singular );
                        }
                    }
                }
            }

     #should not delete things that are not wikiwords unless the user selects it

            if ( $testedLinkCache{$link} ) {
                delete $Foswiki::Plugins::ImportExportPlugin::wikiWordsRendered{
                    $link };
            }
        }

        my $restBase = Foswiki::Func::getScriptUrl( undef, undef, 'rest' );
        my $restBasePath =
          Foswiki::Func::getScriptUrlPath( undef, undef, 'rest' );
        my $viewBase = Foswiki::Func::getScriptUrl( undef, undef, 'view' );
        my $viewBasePath =
          Foswiki::Func::getScriptUrlPath( undef, undef, 'view' );
        if ( $viewBasePath =~ /^https?:\/\/(.*?)\/(.*)$/ ) {
            $viewBasePath = $2;
        }
        my $editBase = Foswiki::Func::getScriptUrl( undef, undef, 'edit' );
        my $editBasePath =
          Foswiki::Func::getScriptUrlPath( undef, undef, 'edit' );
        my $scriptBase = Foswiki::Func::getScriptUrl( undef, undef );
        my $scriptBasePath = Foswiki::Func::getScriptUrlPath( undef, undef );
        if ( $scriptBasePath =~ /^https?:\/\/(.*?)\/(.*)$/ ) {
            $scriptBasePath = $2;
        }

#TODO: validate that bin URL's are to scripts that exist? this might be dangerous wrt apache rewrites

        my $pubPath = Foswiki::Func::getPubUrlPath();
        my $pubDir  = Foswiki::Func::getPubDir();
        my $urlHost = Foswiki::Func::getUrlHost();

        $urlHost =~ s/\//\\\//g;

        foreach my $link ( keys(%links) ) {

            if ( not exists $testedLinkCache{$link} ) {
                if ( $link =~ /^(mailto|ftp|file|irc)/ ) {

                    #ignoring email, ftp, file ... links
                    $testedLinkCache{$link} = $1;    #fake it being OK
                }
                elsif ( $link =~ /^[#\?]/ ) {

#this is a TOC link to the topic itself, just that it get rendered very poorly by the restHandler context
                    $testedLinkCache{$link} = 'rest';    #fake it being OK
                }
                elsif ( $link =~ /($restBase|$restBasePath)/ ) {

#the text rendering is using this rest handler as the basurl for tableedit and stuff.
                    $testedLinkCache{$link} = 'rest';    #fake it being OK
                }
                elsif ( ( $link =~ /^https?/i ) && !( $link =~ /^$urlHost/i ) )
                {

#try to ignore url's that are not ours
#TODO: this is dangerous, as we'll be ignoring url's from which the wiki data came
#TODO: create list and report on external links separatly - optionally follow the link!
                    $testedLinkCache{$link} = 'EXTERNAL LINK'; #fake it being OK

                    #print STDERR "EXTERNAL LINK: $link\n";
                }
                else {
                    my $webtopic = $link;
                    $webtopic =~ s/[\#\?].*$//;

                 #print STDERR "==== $webtopic - $scriptBase|$scriptBasePath\n";
                 #$webtopic =~ /($scriptBase|$scriptBasePath)(\/[a-z]+\/)(.*)$/;
                 #print STDERR "====== $1, $2, $3\n";
                    if ( $webtopic =~ /($editBase|$editBasePath)(.*)$/ ) {

#                    my ($w, $t) = Foswiki::Func::normalizeWebTopicName('', $2);
#                   if (exists $testedLinkCache{"$w.$t"}) {
#this is an edit link to a topic thats listed in a WikiWord link so we don't want to list it twice
                        $testedLinkCache{$link} = 'duplicate';

                        #                   }
                    }
                    elsif ( $webtopic =~
/($scriptBase|$scriptBasePath)\/(configure|statistics|rdiff)/
                      )
                    {
                        $testedLinkCache{$link} = $2;    #fake it being OK
                    }
                    elsif ( $webtopic =~
                        /($scriptBase|$scriptBasePath)(\/[a-z]+\/)(.*)$/ )
                    {
                        my ( $w, $t ) =
                          Foswiki::Func::normalizeWebTopicName( '', $3 );
                        $testedLinkCache{$link} =
                          Foswiki::Func::topicExists( $w, $t );
                        $testedLinkCache{$link} = 'rest'
                          if ( $params{web} eq 'ImportExportPlugin'
                            || $params{topic} eq 'check'
                            || $params{topic} eq 'Check' );
                        $testedLinkCache{$link} = 'rest'
                          if ( $w eq 'ImportExportPlugin'
                            || $t eq 'check'
                            || $t eq 'Check' );
                    }
                    elsif ( $webtopic =~ /.*$pubPath(.*)/ ) {
                        if ( -e $pubDir . $1 ) {
                            $testedLinkCache{$link} = 'attachment exists';
                        }
                    }
                    elsif ( $webtopic =~ /($viewBase|$viewBasePath)(.*)$/ ) {

                        #ShorterUrl setup?
                        my ( $w, $t ) =
                          Foswiki::Func::normalizeWebTopicName( '', $2 );
                        $testedLinkCache{$link} =
                          Foswiki::Func::topicExists( $w, $t );
                        $testedLinkCache{$link} = 'rest'
                          if ( $params{web} eq 'ImportExportPlugin'
                            || $params{topic} eq 'check'
                            || $params{topic} eq 'Check' );
                        $testedLinkCache{$link} = 'rest'
                          if ( $w eq 'ImportExportPlugin'
                            || $t eq 'check'
                            || $t eq 'Check' );
                    }
                    else {

                        #detection fail
                    }
                }
            }
            if ( $testedLinkCache{$link} ) {
                delete $links{$link};
            }
        }

        $params{result} = "\n      * " . join( "\n      * ", keys(%links) )
          if ( scalar( keys(%links) ) > 0 );
        $params{result} .= "\n      * WW: "
          . join( "\n      * WW: ",
            keys(%Foswiki::Plugins::ImportExportPlugin::wikiWordsRendered) )
          if (
            scalar(
                keys(%Foswiki::Plugins::ImportExportPlugin::wikiWordsRendered)
            ) > 0
          );

        my @links = (
            keys(%links),
            keys(%Foswiki::Plugins::ImportExportPlugin::wikiWordsRendered)
        );
        $params{links} = \@links if ( scalar(@links) > 0 );
    }
    return %params;
}

=begin TML

---++ ClassMethod skiptopics( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params ) -> ( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params )

   * skiptopics - Skip topics named in list - used to skip this plugin's check reports when checking

=cut

sub skiptopics {
    my %params = @_;

    map { $params{result} = 'skip' if ( $params{topic} =~ /$_/ ); }
      split( /;\s*/, $params{params} );

    return %params;
}

=begin TML

---++ ClassMethod selecttopics( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params ) -> ( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params )

   * selecttopics - Skip topics other than those named in list

=cut

sub selecttopics {
    my %params = @_;

    my @selecttopics = split( /;\s*/, $params{params} );
    if ( !grep( /$params{topic}/, @selecttopics ) ) {
        $params{result} = 'skip';
    }

    return %params;
}

=begin TML

---++ ClassMethod userweb( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params ) -> ( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params )

   * userweb(fromwikitype;fromwebname) - used to import a USERWEB (Main by default) from a potentially old installation to this wiki (hardcoded to import to Main web atm)
      * fromwebtype - twiki or foswiki (default to foswiki)
      * userwebname - webname to import users from (defaults to Main)
   * uses the TCP hash to convert topic names from twiki to foswiki
   * assumes TopicuserMapping
   * TODO: should really try to deal with htpasswd file too?


=cut

sub userweb {
    my %params = @_;

    my ( $wikitype, $userwebname ) = split( /;\s*/, $params{params} );
    $wikitype    = 'foswiki' unless ( defined($wikitype) );
    $userwebname = 'Main'    unless ( defined($userwebname) );

    if ( $params{web} eq $userwebname ) {
        $params{topic} =~
          s/^$oldMainWebtopics$/_TCP_replace('Main', $1, \$params{result})/e;

        #first stab, don't overwrite any existing topics
        if ( $params{type} eq 'topic' ) {
            if ( Foswiki::Func::topicExists( 'Main', $params{topic} ) ) {
                $params{result} = 'skip';
            }
        }
        else {
            if (
                Foswiki::Func::attachmentExists(
                    'Main', $params{topic}, $params{filename}
                )
              )
            {
                $params{result} = 'skip';
            }
        }
        if ( $params{result} ne 'skip' ) {
            if ( $params{web} ne 'Main' ) {
                $params{result} .= ",userweb($params{web} Main.$params{topic})";
                $params{web} = 'Main';
            }
        }

        #TODO: need to copy over AdminGroup membership
        #TODO: consider web and twiki preferences - at minimum ACLs
        #TODO: how to detect user customisations?
        #TODO: look for links that change is the userwebname has changed.
    }

#TODO: look for links to the old Main web and re-write :/ this is __hard__ (probably need to leverage the chkLink functionality after the fact.)

    return %params;
}

=begin TML

---++ ClassMethod selectwebs( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params ) -> ( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params )

   * selectwebs - only import a specified list of webs (csv in $params{params}), skip the others.

=cut

sub selectwebs {
    my %params = @_;

    my @selectedwebs = split( /;\s*/, $params{params} );
    if ( grep( /$params{web}/, @selectedwebs ) ) {

        #in
    }
    else {
        $params{result} = 'skipweb';
    }

    return %params;
}

=begin TML

---++ ClassMethod twiki( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params ) -> ( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params )

   1 convert topic text that refers to TWiki topics who's names have changed
      * attachments?
   2 Main web renames and migration is left to the userweb filter


report on everything that you did!
   


=cut

sub twiki {
    my %params = @_;

    if ( $params{web} eq 'TWiki' ) {

     #if someone's importing the TWiki web, lets presume its accidental and not.
        $params{result} = 'skip';
    }
    else {

        #apply link conversions from TCP to text
        $params{text} =~
s/((TWiki\.)?$oldTWikiWebtopics)/_TCP_replace('TWiki', $1, \$params{result})/gem
          if ( defined( $params{text} ) );
        $params{text} =~
          s/$oldMainWebtopics/_TCP_replace('Main', $1, \$params{result})/gem
          if ( defined( $params{text} ) );

        #special variables
        $params{text} =~ s/TWIKIWEB/$params{result}.='textchange';'SYSTEMWEB'/ge
          if ( defined( $params{text} ) );
        $params{text} =~ s/MAINWEB/$params{result}.='textchange';'USERSWEB'/ge
          if ( defined( $params{text} ) );

    }

    return %params;
}

sub _TCP_replace {
    my $web       = shift;
    my $topic     = shift;
    my $resultRef = shift;

    my $webPrefix = '';
    if ( $topic =~ s/^TWiki\.// ) {
        $webPrefix = 'System.';
    }

    $$resultRef .= " replace($topic)";
    return $webPrefix
      . $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}
      { $web . 'WebTopicNameConversion' }{$topic};
}

=begin TML

---++ ClassMethod converturls( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params ) -> ( result=>$params{result}, web=>$params{web}, topic=>$params{topic}, text=>$params{text}, attachment=>$file, params=>$params )

   * converturls - convert literal URL's to topic links
        * start with http(s?)://host/view/ and http(s?)://host/pub/
        * can i add regex safely?
        * then add SCRIPTURL/view
        * think about pub, and other

TODO: actually, this is hard, and given that we'll be dns directing all old host links to the new setup, we don't need it

=cut

sub converturls {
    my %params = @_;

    my @urls = split( /;\s*/, $params{params} );
    foreach my $url (@urls) {

        #        $params{text} =~ s/($url)(.*?)([])/convertUrl()/gem;
    }

    return %params;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: SvenDowideit

Copyright (C) 2012 SvenDowideit@fosiki.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
