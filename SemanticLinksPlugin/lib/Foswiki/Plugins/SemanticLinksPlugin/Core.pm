# See bottom of file for default license and copyright information

=begin TML

---+ package SemanticLinksPlugin

=cut

package Foswiki::Plugins::SemanticLinksPlugin::Core;
use strict;
use warnings;

use Assert;
use Foswiki::Func ();    # The plugins API

use constant TRACE => 0;
require Data::Dumper if TRACE;

my %templates;
my %semanticlinks;
my %nsemanticlinks;
my %metasemanticlinks;
my %metansemanticlinks;
my %propertyattributes;
my %links;
my $nlinks;
my $restResult;
my $baseWeb;

#From Foswiki::Render
my $STARTWW  = qr/^|(?<=[\s\(])/m;
my $ENDWW    = qr/$|(?=[\s,.;:!?)])/m;
my %hardvars = (
    HOMETOPIC       => $Foswiki::cfg{HomeTopicName},
    WEBPREFSTOPIC   => $Foswiki::cfg{WebPrefsTopicName},
    WIKIUSERSTOPIC  => $Foswiki::cfg{UsersTopicName},
    STATISTICSTOPIC => $Foswiki::cfg{Stats}{TopicName},
    NOTIFYTOPIC     => $Foswiki::cfg{NotifyTopicName},
    WIKIPREFSTOPIC  => $Foswiki::cfg{SitePrefsTopicName},
    SYSTEMWEB       => $Foswiki::cfg{SystemWebName},
    USERSWEB        => $Foswiki::cfg{UsersWebName},
    TRASHWEB        => $Foswiki::cfg{TrashWebName},
    SANDBOXWEB      => $Foswiki::cfg{SandboxWebName}
);
my (
    $PROPERTY,              #0
    $VALUE,                 #1
    $VALUEQUERY,            #2
    $VALUEANCHOR,           #3
    $PROPERTYATTRIBUTES,    #4
    $TEXT,                  #5
    $PROPERTYWEB,           #6
    $PROPERTYTOPIC,         #7
    $VALUEWEB,              #8
    $VALUETOPIC,            #9
    $PROPERTYSEQ            #10
) = ( 0 .. 10 );
my %tokenidents = (
    '$property' => {
        _     => $PROPERTY,
        web   => $PROPERTYWEB,
        topic => $PROPERTYTOPIC,
        seq   => $PROPERTYSEQ
    },
    '$propertyweb'   => $PROPERTYWEB,
    '$propertytopic' => $PROPERTYTOPIC,
    '$value'         => {
        _prefixes => {
            qquery  => '?',
            aanchor => '#'
        },
        _       => $VALUE,
        query   => $VALUEQUERY,
        qquery  => $VALUEQUERY,
        anchor  => $VALUEANCHOR,
        aanchor => $VALUEANCHOR,
        web     => $VALUEWEB,
        topic   => $VALUETOPIC
    },
    _prefixes => {
        valueqquery  => '?',
        valueaanchor => '#'
    },
    '$valueweb'     => $VALUEWEB,
    '$valuetopic'   => $VALUETOPIC,
    '$valuequery'   => $VALUEQUERY,
    '$valueqquery'  => $VALUEQUERY,
    '$valueanchor'  => $VALUEANCHOR,
    '$valueaanchor' => $VALUEANCHOR,
    '$text'         => $TEXT
);

sub init {
    %templates          = ();
    %propertyattributes = ();
    %semanticlinks      = ();
    %nsemanticlinks     = ();
    %metasemanticlinks  = ();
    %metansemanticlinks = ();
    %links              = ();
    $nlinks             = 1;
    $restResult         = undef;
    $baseWeb            = undef;
}

=begin TML
---++ preRenderingHandler( $text, \%map )
   * =$text= - text, with the head, verbatim and pre blocks replaced
   with placeholders
   * =\%removed= - reference to a hash that maps the placeholders to
   the removed blocks.

Handler called immediately before Foswiki syntax structures (such as lists) are
processed, but after all variables have been expanded. Use this handler to
process special syntax only recognised by your plugin.

... snip ... refer to EmptyPlugin.pm

=cut

sub preRenderingHandler {
    my ( $text, $pMap ) = @_;
    my $linkHandler = \&renderLink;

    if ( not defined $pMap ) {

        # SMELL: are we really being called from beforeSaveHandler()?
        $linkHandler = \&stashSemLink;
    }
    else {
        %semanticlinks      = ();
        %nsemanticlinks     = ();
        %metasemanticlinks  = ();
        %metansemanticlinks = ();
        %propertyattributes = ();
    }

    # You can work on $text in place by using the special perl
    # variable $_[0]. These allow you to operate on $text
    # as if it was passed by reference; for example:
    # $_[0] =~ s/SpecialString/my alternative/ge;
    # Handle [[][] and [[]] links
    # Change '![[...'  to ' [<nop>[...' to protect from further rendering
    print STDERR "Here's the text: '$text'\n" if TRACE;
    $_[0] =~ s/(^|\s)\!\[\[/$1\[<nop>\[/gm;

    # Change ' [[$1::$2?$3#$4|$5]] '
    $_[0] =~
s/\[\[([^:][^\|\]\n?]+?)::([^\|\]\n?\#]+)(\?[^\|\]\n\#]+)?(\#[^\|\]\n]+)?\|([^\]\n]+)\]\]/&{$linkHandler}( $1, $2, $3, $4, undef, $5 )/ge;

    # Change ' [[$1::$2?$4#$6 {$7}][$9]] '
    $_[0] =~
s/\[\[([^:][^\]\n?]+?)::([^\]\n?\#\{]+?)(\?([^\]\n\#\{]+?))?(\#([^\]\n\{]+?))?(\s*\{[^\]\n]+)?\](\[([^\]\n]+)\])?\]/&{$linkHandler}( $1, $2, $4, $6, $7, $9 )/ge;

    # Change ' [[:...' to ' [[... ' so the link will be handled by Foswiki core
    $_[0] =~ s/(^|\s)[^!]?\[\[:/$1\[\[/gm;

    return;
}

# SMELL: Reproducing Foswiki::Render, but only partially (links have ~500 LOC!)
# What about protocol:// links? Interwiki:links? email@address.es?
# TODO: Allow values which aren't links. This would require special meta on
# the property topic. For now you can cheat by using your own
# SemanticLinksPlugin::MissingLink template on the property topic.
sub renderLink {
    my (@attrs) = @_;
    print STDERR "In renderLink() with args: " . Data::Dumper->Dump( \@attrs )
      if TRACE;
    my $semlink = _getSemLinkData( $attrs[$PROPERTY], $attrs[$VALUE] );
    my $templatetxt;
    my $tmplName = '';

    push( @attrs,
        $semlink->{propertyweb}, $semlink->{propertytopic},
        $semlink->{valueweb},    $semlink->{valuetopic},
        $semlink->{propertyseq} );
    if ( $attrs[$TEXT] ) {
        $tmplName = 'WithText';
    }
    if (
        Foswiki::Func::topicExists(
            $semlink->{valueweb}, $semlink->{valuetopic}
        )
      )
    {
        $tmplName = 'Link' . $tmplName;
    }
    else {
        $tmplName = 'MissingLink' . $tmplName;
    }

    $templatetxt = getTemplate( $semlink->{propertyweb},
        $semlink->{propertytopic}, $tmplName );
    $templatetxt =~
s/(\$[a-z]+)(\(\s*([^\)]+)\s*\))?/_expandToken($1, $3, \@attrs, \%tokenidents )/ge;

    return Foswiki::Func::expandCommonVariables($templatetxt);
}

sub _expandToken {
    my ( $token, $args, $attrs, $ident ) = @_;
    my $val;

    ASSERT( ref($ident) eq 'HASH' )  if DEBUG;
    ASSERT( ref($attrs) eq 'ARRAY' ) if DEBUG;
    if ( exists $ident->{$token} ) {
        $val = $ident->{$token};
        if ( ref($val) eq 'HASH' ) {
            $val = _expandToken( $args || '_', undef, $attrs, $val );
        }
        elsif ( not ref($val) ) {
            $val = $attrs->[$val] || '';
        }
        elsif ( ref($val) eq 'CODE' ) {
            ASSERT( exists $ident->{_} ) if DEBUG;
            ASSERT( defined $attrs->[ $ident->{_} ] ) if DEBUG;
            $val = $val->( $attrs->[ $ident->{_} ] );
        }
        else {
            ASSERT(0) if DEBUG;
        }
        if (    exists $ident->{_prefixes}
            and exists $ident->{_prefixes}->{$token} )
        {
            $val = $ident->{_prefixes}->{$token} . $val;
        }
    }
    else {
        $val = $token;
    }

    return $val;
}

sub _getTemplateFromExplicitDef {
    my ( $property, $tmplName ) = @_;

    return Foswiki::Func::expandTemplate(
        'SemanticLinksPlugin::' . $property . '::' . $tmplName );
}

sub _getRequestObject {
    my $req;

    if ( defined &Foswiki::Func::getRequestObject ) {

        # Foswiki >= 1.1
        $req = Foswiki::Func::getRequestObject();
    }
    else {

        # Foswiki <= 1.0
        $req = Foswiki::Func::getCgiQuery();
    }

    return $req;
}

sub _getTemplateFromPropertyTopic {
    my ( $web, $topic, $tmplName, $custTMPL ) = @_;
    my $tmpl;

    if ( Foswiki::Func::topicExists( $web, $topic ) ) {
        Foswiki::Func::readTemplate( $web . '.' . $topic, '' );
        if ($custTMPL) {
            $tmpl = Foswiki::Func::expandTemplate(
                'SemanticLinksPlugin::' . $custTMPL . '::' . $tmplName );
        }
        if ( not $tmpl ) {
            $tmpl = Foswiki::Func::expandTemplate(
                'SemanticLinksPlugin::' . $tmplName );
        }
    }

    return $tmpl;
}

sub _getTemplateFromSkinPath {
    my ($tmplName) = @_;

    Foswiki::Func::readTemplate('semanticlinksplugin');

    return Foswiki::Func::expandTemplate( 'SemanticLinksPlugin::' . $tmplName );
}

# Lazy-load templates, only when we need them.
sub getTemplate {
    my ( $propertyweb, $propertytopic, $tmplName ) = @_;
    my $property = $propertyweb . '.' . $propertytopic;
    my $custTMPL =
         _getRequestObject()->param('SEMANTICLINKSPLUGIN_TMPL')
      || Foswiki::Func::getPreferencesValue('SEMANTICLINKSPLUGIN_TMPL')
      || 0;
    my $tmpl;

    if ( not $templates{$property}{$tmplName}{$custTMPL} ) {
        $tmpl = _getTemplateFromExplicitDef( $property, $tmplName );
        if ( not $tmpl ) {
            $tmpl = _getTemplateFromPropertyTopic( $propertyweb, $propertytopic,
                $tmplName, $custTMPL );
            if ( not $tmpl ) {
                $tmpl = _getTemplateFromSkinPath($tmplName);
            }
        }

        # Zap the escaped newlines
        $tmpl =~ s/\\\n//smg;
        $templates{$property}{$tmplName}{$custTMPL} = $tmpl;
    }

    return $templates{$property}{$tmplName}{$custTMPL};
}

=begin TML

---++ beforeSaveHandler($text, $topic, $web, $meta )
   * =$text= - text _with embedded meta-data tags_
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - the metadata of the topic being saved, represented by a Foswiki::Meta object.

   This handler is called each time a topic is saved.

   *NOTE:* meta-data is embedded in =$text= (using %META: tags). If you modify
   the =$meta= object, then it will override any changes to the meta-data
   embedded in the text. Modify *either* the META in the text *or* the =$meta=
   object, never both. You are recommended to modify the =$meta= object rather
   than the text, as this approach is proof against changes in the embedded
   text format.

   *Since:* Foswiki::Plugins::VERSION = 2.0

=cut

sub beforeSaveHandler {
    my ( $text, $topic, $web, $topicObject ) = @_;
    my %DATA = _parse( $topicObject->getEmbeddedStoreForm(), $topicObject );

    foreach my $META ( keys %DATA ) {
        $topicObject->putAll( $META, @{ $DATA{$META} } );
    }

    return;
}

# Parse $text for links, using topic/web/topicObject as context
sub _parse {
    my ( $text, $topicObject ) = @_;
    my $web   = $topicObject->web();
    my $topic = $topicObject->topic();

    init();
    $hardvars{WEB}       = $web;
    $hardvars{TOPIC}     = $topic;
    $hardvars{BASEWEB}   = $web;
    $hardvars{BASETOPIC} = $topic;
    $baseWeb             = $web;
    $topicObject->remove('LINK');
    $topicObject->remove('SLVALUE');
    $topicObject->remove('SLPROPERTY');

    # Expand prefs
    $text =~ s/(%([A-Z]+)%)/
        Foswiki::Func::getPreferencesValue($2) || $hardvars{$2} || $1/gex;

    return (
        semanticLinksSaveHandler( $text, $topic, $web, $topicObject ),
        plainLinksSaveHandler( $text, $topic, $web, $topicObject )
    );
}

sub plainLinksSaveHandler {
    my ( $text, $topic, $web, $topicObject ) = @_;

    $text =~
s/\[\[[:]?\s*([^\]\n\?\#]+?)(\?([^\]\n\#]+?))?(\#([^\]\n]+?))?\s*\](\[([^\]\n]+?)\])?\]/stashPlainLink(undef, 'bracket', $1, $3, $5, $6)/ge;

    # From Foswiki::Render
    $text =~ s/(^|(?<!url)[-*\s(|])
               ($Foswiki::regex{linkProtocolPattern}:
                   ([^\s<>"]+[^\s*.,!?;:)<|]))/
                     stashPlainLink( 'external', 'autolink', $2)/gex;

    # From Foswiki::Render
    $text =~ s/$STARTWW
        (($Foswiki::regex{webNameRegex})\.)?
        ($Foswiki::regex{wikiWordRegex}|
        $Foswiki::regex{abbrevRegex})
        ($Foswiki::regex{anchorRegex})?/
        stashPlainLink('internal', 'autolink', ($1 || '') . $3, undef, $4)/gexm;

    return ( 'LINK' => [ values %links ] );
}

sub stashPlainLink {
    my ( $scope, $type, $address, $query, $anchor, $text ) = @_;
    my $dostash = 1;

    if ( not exists $links{$address} ) {
        if (   ( $scope and $scope eq 'external' )
            or ( $address =~ /^$Foswiki::regex{linkProtocolPattern}:/ ) )
        {
            $links{$address} = {
                name    => $nlinks,
                address => $address,
                scope   => 'external'
            };
            if ($type) {
                $links{$address}->{type} = $type;
            }
            $nlinks += 1;
            $dostash = 0;
        }
        elsif (    # TLA abbreviations
                $scope
            and $scope eq 'internal'
            and $type
            and $type eq 'autolink'
            and $address =~ /^$Foswiki::regex{abbrevRegex}$/
            and not Foswiki::Func::topicExists(
                Foswiki::Func::normalizeWebTopicName(
                    $Foswiki::Plugins::SESSION->{webName}, $address
                )
            )
          )
        {
            $dostash = 0;
        }
        if ($dostash) {
            my ( $web, $topic, $rev ) = Foswiki::Func::normalizeWebTopicName(
                $Foswiki::Plugins::SESSION->{webName}, $address );
            my $name = $web . '__' . $topic;

            if ( defined $rev ) {
                $name .= '@' . $rev;
                $links{$name}->{rev} = $rev;
            }
            if ( not exists $links{$name} ) {
                $links{$name} = {
                    name    => $nlinks,
                    web     => $web,
                    topic   => $topic,
                    address => "$web.$topic",
                    scope   => 'internal'
                };
                if ($type) {
                    $links{$name}->{type} = $type;
                }
                $nlinks += 1;
            }
        }
    }

    return '';
}

sub semanticLinksSaveHandler {
    my ( $text, $topic, $web, $topicObject ) = @_;
    my %DATA;
    my @propertyaddresses;

    # Instead of rendering, linkHandler will be set to stashSemLink() which
    # populates the %semanticlinks hash.
    preRenderingHandler( $_[0] );

    @propertyaddresses = keys %semanticlinks;
    if ( scalar(@propertyaddresses) ) {
        my @SLPROPERTY;
        my @SLVALUE;
        my @SLMETAPROPERTY;
        my @SLMETAVALUE;

        # In a perfect world, we'd have query syntax sufficient to avoid needing
        # the SLPROPERTY type at all. For now, SLPROPERTIES can tell a wiki app
        # what distinct properties are present on a given topic.
        while ( my ( $property, $num ) = each %nsemanticlinks ) {
            push(
                @SLPROPERTY,
                {
                    name => $property,
                    num  => $num
                }
            );
        }
        while ( my ( $property, $num ) = each %metansemanticlinks ) {
            push(
                @SLMETAPROPERTY,
                {
                    name => $property,
                    num  => $num
                }
            );
        }
        foreach my $propertyaddress (@propertyaddresses) {
            while ( my ( $valueaddress, $VALUE ) =
                each %{ $semanticlinks{$propertyaddress} } )
            {
                if ( $valueaddress ne '_topic' ) {
                    my $metaprops =
                      $metasemanticlinks{$propertyaddress}{$valueaddress};

                    delete $VALUE->{propertytopic};
                    push( @SLVALUE, $VALUE );
                    stashPlainLink( 'internal', 'semantic',
                        $VALUE->{valueaddress} );
                    if ($metaprops) {
                        ASSERT( ref($metaprops) eq 'HASH' ) if DEBUG;
                        while ( my ( $metapropaddr, $metavals ) =
                            each %{$metaprops} )
                        {
                            while ( my ( $metavaladdr, $meta ) =
                                each %{$metavals} )
                            {
                                if ( $metavaladdr ne '_topic' ) {
                                    push( @SLMETAVALUE, $meta );
                                    stashPlainLink( 'internal', 'semanticmeta',
                                        $meta->{valueaddress} );
                                }
                            }
                        }
                    }
                }
            }
        }
        @SLVALUE = sort { $a->{propertyseq} <=> $b->{propertyseq} } @SLVALUE;
        $DATA{SLPROPERTY} = [@SLPROPERTY];
        $DATA{SLVALUE}    = [@SLVALUE];
        @SLMETAVALUE =
          sort { $a->{propertyseq} <=> $b->{propertyseq} } @SLMETAVALUE;
        $DATA{SLMETAPROPERTY} = [@SLMETAPROPERTY];
        $DATA{SLMETAVALUE}    = [@SLMETAVALUE];

        # These are unused legacy types
        $DATA{SLPROPERTYVALUE} = [];
        $DATA{SLPROPERTIES}    = [];
    }

    return %DATA;
}

sub _getSemLinkData {
    my ( $property, $value ) = @_;
    my $semlink;
    my ( $propertyweb, $propertytopic ) = Foswiki::Func::normalizeWebTopicName(
        Foswiki::Func::getPreferencesValue(
            'SEMANTICLINKSPLUGIN_DEFAULT_PROPERTYWEB')
          || $Foswiki::Plugins::SESSION->{webName},
        $property
    );
    my $propertyaddress = $propertyweb . '.' . $propertytopic;
    my $valueaddress;
    my $valueweb;
    my $valuetopic;
    print STDERR "_getSemLinkData($property, $value)\n" if TRACE;

    if ( not exists $propertyattributes{DEFAULT_VALUEWEB}{$propertyaddress} ) {
        print STDERR "No valueweb entry for property '$propertyaddress'\n"
          if TRACE;
        my ($propertyTopicObj) =
          Foswiki::Func::readTopic( $propertyweb, $propertytopic );

        if ( $propertyTopicObj->haveAccess('VIEW') ) {
            print STDERR "have access to property '$propertyaddress'\n"
              if TRACE;
            my $defweb = $propertyTopicObj->getPreference(
                'SEMANTICLINKSPLUGIN_DEFAULT_VALUEWEB');
            if ($defweb) {
                print STDERR
                  "got defaultweb '$defweb' from property '$propertyaddress'\n"
                  if TRACE;
                $propertyattributes{DEFAULT_VALUEWEB}{$propertyaddress} =
                  $defweb;
            }
            else {
                print STDERR "go defaultweb on property '$propertyaddress'\n"
                  if TRACE;
            }
        }
        else {

            print STDERR "no access to property '$propertyaddress'\n" if TRACE;

            # Don't bother checking for VIEW access again
            $propertyattributes{DEFAULT_VALUEWEB}{$propertyaddress} = undef;
        }
    }
    ( $valueweb, $valuetopic ) = Foswiki::Func::normalizeWebTopicName(
        $propertyattributes{DEFAULT_VALUEWEB}{$propertyaddress}
          || $Foswiki::Plugins::SESSION->{webName},
        $value
    );
    $valueaddress = $valueweb . '.' . $valuetopic;
    $semlink      = $semanticlinks{$propertyaddress}{$valueaddress};
    if ( not exists $nsemanticlinks{$propertytopic} ) {
        print STDERR "adding '$propertytopic'\n" if TRACE;
        $nsemanticlinks{$propertytopic} = 1;
    }
    elsif ( not defined $semlink ) {
        print STDERR "counting '$propertytopic'\n" if TRACE;
        $nsemanticlinks{$propertytopic} += 1;
    }
    if ( not defined $semanticlinks{$propertyaddress}{_topic} ) {
        print STDERR "No propertytopic\n" if TRACE;
        $semanticlinks{$propertyaddress}{_topic} = $propertytopic;
    }
    if ( not defined $semlink ) {
        print STDERR "No semlinkdata!\n" if TRACE;
        $semlink = {
            name     => $propertytopic . '__' . $nsemanticlinks{$propertytopic},
            property => $property,
            propertyaddress => $propertyaddress,
            propertyweb     => $propertyweb,
            propertytopic   => $propertytopic,
            value           => $value,
            valueaddress    => $valueaddress,
            valueweb        => $valueweb,
            valuetopic      => $valuetopic,
            propertyseq     => $nsemanticlinks{$propertytopic}
        };
        $semanticlinks{$propertyaddress}{$valueaddress} = $semlink;
    }
    print STDERR Data::Dumper->Dump( [$semlink] ) if TRACE;

    return $semlink;
}

sub _getMetaSemLinkData {
    my ( $property, $value, $of ) = @_;
    my $ofpropaddr = $of->{propertyaddress};
    my $ofvaladdr  = $of->{valueaddress};
    my $metasemlink;
    my ( $propertyweb, $propertytopic ) = Foswiki::Func::normalizeWebTopicName(
        Foswiki::Func::getPreferencesValue(
            'SEMANTICLINKSPLUGIN_DEFAULT_PROPERTYWEB')
          || $Foswiki::Plugins::SESSION->{webName},
        $property
    );
    my $propertyaddress = $propertyweb . '.' . $propertytopic;
    my $valueaddress;
    my $valueweb;
    my $valuetopic;

    if ( not exists $propertyattributes{DEFAULT_VALUEWEB}{$propertyaddress} ) {
        my ($propertyTopicObj) =
          Foswiki::Func::readTopic( $propertyweb, $propertytopic );

        if ( $propertyTopicObj->haveAccess('VIEW') ) {
            my $defweb = $propertyTopicObj->getPreference(
                'SEMANTICLINKSPLUGIN_DEFAULT_VALUEWEB');
            if ($defweb) {
                $propertyattributes{DEFAULT_VALUEWEB}{$propertyaddress} =
                  $defweb;
            }
        }
        else {

            # Don't bother checking for VIEW access again
            $propertyattributes{DEFAULT_VALUEWEB}{$propertyaddress} = undef;
        }
    }
    ( $valueweb, $valuetopic ) = Foswiki::Func::normalizeWebTopicName(
        $propertyattributes{DEFAULT_VALUEWEB}{$propertyaddress}
          || $Foswiki::Plugins::SESSION->{webName},
        $value
    );
    $valueaddress = $valueweb . '.' . $valuetopic;
    $metasemlink =
      $metasemanticlinks{$ofpropaddr}{$ofvaladdr}{$propertyaddress}
      {$valueaddress};
    if ( not exists $metansemanticlinks{$propertytopic} ) {
        $metansemanticlinks{$propertytopic} = 1;
    }
    elsif ( not defined $metasemlink ) {
        $metansemanticlinks{$propertytopic} += 1;
    }
    if (
        not
        defined $metasemanticlinks{$ofpropaddr}{$ofvaladdr}{$propertyaddress}
        {_topic} )
    {
        $metasemanticlinks{$ofpropaddr}{$ofvaladdr}{$propertyaddress}{_topic} =
          $propertytopic;
    }
    if ( not defined $metasemlink ) {
        $metasemlink = {
            name => $propertytopic . '__' . $metansemanticlinks{$propertytopic},
            property          => $property,
            propertyaddress   => $propertyaddress,
            propertyweb       => $propertyweb,
            propertytopic     => $propertytopic,
            value             => $value,
            valueaddress      => $valueaddress,
            valueweb          => $valueweb,
            valuetopic        => $valuetopic,
            propertyseq       => $metansemanticlinks{$propertytopic},
            ofname            => $of->{name},
            ofvalueweb        => $of->{valueweb},
            ofvaluetopic      => $of->{valuetopic},
            ofvalueaddress    => $of->{valueaddress},
            ofproperty        => $of->{property},
            ofpropertyweb     => $of->{propertyweb},
            ofpropertyaddress => $of->{propertyaddress},
            ofpropertyseq     => $of->{propertyseq},
            offragment        => $of->{fragment}
        };
        $metasemanticlinks{$ofpropaddr}{$ofvaladdr}{$propertyaddress}
          {$valueaddress} = $metasemlink;
    }

    return '';
}

sub stashSemLink {
    my ( $property, $value, $valuequery, $valueanchor, $metaproperties, $text )
      = @_;
    my $semlink = _getSemLinkData( $property, $value );

    if ($valueanchor) {
        $semlink->{fragment} = $valueanchor;
    }
    if ($metaproperties) {
        $metaproperties =~
          s/\{\s*(.*?)::([^\}]+)\s*\}/_getMetaSemLinkData($1, $2, $semlink)/gem;
    }

    return '';
}

# Inspired by MongoDBPlugin's update handler :-)
sub restReparseHandler {
    my ($session) = @_;
    my $query;
    my $webParam;
    my $topicParam;
    my $recurse;
    my @webNames;

    $restResult = '';
    if ( defined &Foswiki::Func::getRequestObject ) {
        $query = Foswiki::Func::getRequestObject();
    }
    else {
        $query = Foswiki::Func::getCgiQuery();
    }
    $webParam =
         $query->param('updateweb')
      || $Foswiki::cfg{SandboxWebName}
      || 'Sandbox';
    $topicParam = $query->param('updatetopic');
    $recurse =
      Foswiki::Func::isTrue( $query->param('recurse'), ( $webParam eq 'all' ) );
    if ($recurse) {

        if ( $webParam eq 'all' ) {
            $webParam = undef;
        }
        @webNames = Foswiki::Func::getListOfWebs( '', $webParam );
    }
    unshift( @webNames, $webParam ) if ( defined($webParam) );

    _report("<pre>\nImporting:\n");
    foreach my $web (@webNames) {
        my @topics;
        my $count = 0;

        if ($topicParam) {
            @topics = ($topicParam);
        }
        else {
            @topics = Foswiki::Func::getTopicList($web);
        }
        _report("$web\n\tupdating ");
        foreach my $topic (@topics) {
            my ($topicObj)  = Foswiki::Func::readTopic( $web, $topic );
            my ($otopicObj) = Foswiki::Func::readTopic( $web, $topic );

            if ( $topicObj->haveAccess('CHANGE') ) {
                beforeSaveHandler( $topicObj->getEmbeddedStoreForm(),
                    $topic, $web, $topicObj );
                if ( $topicObj->count('LINK') or $topicObj->count('SLVALUE') ) {
                    if ( _different( $topicObj, $otopicObj ) ) {
                        _report("$topic, ");
                        $topicObj->save();
                    }
                    else {

                        #$result .= "\t$topic remains unchanged\n";
                    }
                }
            }
            else {
                _report("\nFAILED: no permission to CHANGE $web.$topic\n\n");
            }
            if ( ( $count % 200 ) == 0 ) {
                _report("\n\tRe-parsed $count (doing $topic)...\n\tupdating ");
            }
            $count += 1;
        }
    }
    return ( $restResult || '' ) . "\n\n</pre>";
}

sub _report {
    my ($text) = @_;

    if ( Foswiki::Func::getContext()->{'command_line'} ) {
        print STDERR $text;
    }
    else {
        $restResult .= $text;
    }

    return;
}

sub _different {
    my ( $a, $b ) = @_;
    my $different;

    if ( _checkTHING( 'LINK', $a, $b ) ) {
        $different = 1;
    }
    elsif ( _checkTHING( 'SLVALUE', $a, $b ) ) {
        $different = 1;
    }
    elsif ( _checkTHING( 'METASLVALUE', $a, $b ) ) {
        $different = 1;
    }

    return $different;
}

sub _checkTHING {
    my ( $type, $a, $b ) = @_;
    my %A  = map { $_->{name} => $_ } $a->find($type);
    my @a  = keys(%A);
    my $nA = scalar(@a);
    my %B  = map { $_->{name} => $_ } $b->find($type);
    my $different;

    if ( $nA != scalar( keys %B ) ) {

        #_report("Different number of keys in $type");
        $different = 1;
    }
    else {
        my $i = 0;

        while ( $i < $nA and not $different ) {
            my $aKey = $a[$i];

            if ( defined $A{$aKey} and defined $B{$aKey} ) {
                $different = _checkHash( $A{$aKey}, $B{$aKey} );
                if ($different) {

    #_report("Different in $type $aKey: A was $A{$aKey} and B was $B{$aKey}\n");
                }
            }
            elsif ( defined $A{$aKey} or defined $B{$aKey} ) {
                $different = 1;

 #_report("Different in $type $aKey: one was defined where the other wasn't\n");
            }
            $i += 1;
        }
    }

    return $different;
}

sub _checkHash {
    my ( $A, $B ) = @_;
    my @a  = keys %{$A};
    my $nA = scalar(@a);
    my $different;
    my $i = 0;

    while ( $i < $nA and not $different ) {
        my $aKey   = $a[$i];
        my $aValue = $A->{$aKey};
        my $bValue = $B->{$aKey};

        if (
            exists $B->{$aKey}
            and ( ( defined $aValue and defined $bValue and $aValue eq $bValue )
                or not( defined $aValue or defined $bValue ) )
          )
        {

            # The same :-)
        }
        else {
            $different = 1;

  #_report("Different in val key $aKey, A was $aValue and B was $B->{$aKey}\n");
        }
        $i += 1;
    }

    return $different;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2012 Paul.W.Harvey@csiro.au, http://trin.org.au
Copyright (C) 2010-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
