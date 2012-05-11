# Partially derived from bin/edit and /lib/TWiki/UI/Edit.pm; omitted topic
# creation related code

=pod
# Rewrite slightly so that it uses the refactored TWiki::UI::Edit;
# we can do:

sub edit {
    my $session = shift;
    my ( $text, $tmpl ) = init_edit( $session, 'editsection' );
    ( $text, $tmpl ) = HANDLE_PRE_AND_POST();
    finalize_edit ( $session, $text, $tmpl );
}

=cut

package TWiki::Contrib::EditContrib;

use vars qw( $VERSION );

use strict;
use CGI::Carp qw(fatalsToBrowser);
use CGI;
use TWiki;
use TWiki::UI;
use TWiki::UI::Save;
use Error qw( :try );
use TWiki::OopsException;

$VERSION = 1.001;

BEGIN {
    if ( substr( $TWiki::RELEASE, 8 ) >= 1 ) {
        require TWiki::Contrib::EditContrib::Include41;
        $TWiki::functionTags{INCLUDE} =
          \&TWiki::Contrib::EditContrib::Include41::_INCLUDE;
    }
    elsif ( substr( $TWiki::RELEASE, 8 ) == 0 ) {
        require TWiki::Contrib::EditContrib::Include40;
        $TWiki::functionTags{INCLUDE} =
          \&TWiki::Contrib::EditContrib::Include40::_INCLUDE;
    }
}

# =========================
##### Note done yet
sub handleUrlParam {

    #my( $theParam ) = @_;
    return TWiki::handleUrlParam(@_);
}

# =========================
sub init_edit {
    my $session = shift;

    $session->enterContext('edit');
    my $query   = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic   = $session->{topicName};
    my $user    = $session->{user};

    # empty means edit both form and text, "form" means edit form only,
    # "text" means edit text only

    my $onlyWikiName = TWiki::isTrue( $query->param('onlywikiname') );
    my $onlyNewTopic = TWiki::isTrue( $query->param('onlynewtopic') );
    my $store        = $session->{store};

    TWiki::UI::checkWebExists( $session, $webName, $topic, 'edit' );
    TWiki::UI::checkMirror( $session, $webName, $topic );

    my $topicExists = $store->topicExists( $webName, $topic );

    # If you want to edit, you have to be able to view and change.
    TWiki::UI::checkAccess( $session, $webName, $topic, 'view',   $user );
    TWiki::UI::checkAccess( $session, $webName, $topic, 'change', $user );

    # Check lease, unless we have been instructed to ignore it
    # or if we are using the 10X's topic name for dynamic topic names
    my $breakLock = $query->param('breaklock') || '';
    unless ( $breakLock || ( $topic =~ /X{10}/ ) ) {
        my $lease = $store->getLease( $webName, $topic );
        if ($lease) {
            my $who = $lease->{user}->webDotWikiName();

            if ( $who ne $user->webDotWikiName() ) {

                # redirect; we are trying to break someone else's lease
                my ( $future, $past );
                my $why = $lease->{message};
                my $def;
                my $t = time();
                if ( $t > $lease->{expires} ) {

                    # The lease has expired, but see if we are still
                    # expected to issue a "less forceful' warning
                    if (   $TWiki::cfg{LeaseLengthLessForceful} < 0
                        || $t < $lease->{expires} +
                        $TWiki::cfg{LeaseLengthLessForceful} )
                    {
                        $def = 'lease_old';
                        $past =
                          TWiki::Time::formatDelta( $t - $lease->{expires},
                            $session->{i18n} );
                        $future = '';
                    }
                }
                else {

                    # The lease is active
                    $def  = 'lease_active';
                    $past = TWiki::Time::formatDelta( $t - $lease->{taken},
                        $session->{i18n} );
                    $future = TWiki::Time::formatDelta( $lease->{expires} - $t,
                        $session->{i18n} );
                }
                if ($def) {

                    # use a 'keep' redirect to ensure we pass parameter
                    # values in the query on to the oops script
                    throw TWiki::OopsException(
                        'leaseconflict',
                        keep   => 1,
                        def    => $def,
                        web    => $webName,
                        topic  => $topic,
                        params => [ $who, $past, $future ]
                    );
                }
            }
        }
    }

    # Prevent editing existing topic?
    if ( $onlyNewTopic && $topicExists ) {

        # Topic exists and user requested oops if it exists
        throw TWiki::OopsException(
            'attention',
            def   => 'topic_exists',
            web   => $webName,
            topic => $topic
        );
    }

    # prevent non-Wiki names?
    if (   ($onlyWikiName)
        && ( !$topicExists )
        && ( !TWiki::isValidTopicName($topic) ) )
    {

        # do not allow non-wikinames, redirect to view topic
        # SMELL: this should be an oops, shouldn't it?
        $session->redirect(
            $session->getScriptUrl( 1, 'view', $webName, $topic ) );
        return;
    }

    return ( $session, $topicExists );
}

# =========================
sub edit {

    my $session = shift;
    my $topicExists;
    ( $session, $topicExists ) = init_edit($session);
    my $query         = $session->{cgiQuery};
    my $webName       = $session->{webName};
    my $topic         = $session->{topicName};
    my $store         = $session->{store};
    my $saveCmd       = $query->param('cmd') || '';
    my $editaction    = lc( $query->param('action') ) || "";
    my $skin          = $session->getSkin();
    my $origurl       = $query->param('redirectto') || '';
    my $templateTopic = $query->param('templatetopic') || '';
    my $formTemplate  = $query->param('formtemplate') || '';
    my $user          = $session->{user};
    my $theParent     = $query->param('topicparent') || '';
    my $ptext         = $query->param('text');
    my $meta          = '';
    my $text          = '';
    my $extra         = '';

    return unless ($query);
    if ($topicExists) {
        ( $meta, $text ) = $store->readTopic( undef, $webName, $topic, undef );
    }

    if ( $saveCmd && !$session->{user}->isAdmin() ) {
        throw TWiki::OopsException(
            'accessdenied',
            def    => 'only_group',
            web    => $webName,
            topic  => $topic,
            params => $TWiki::cfg{UsersWebName} . '.'
              . $TWiki::cfg{SuperAdminGroup}
        );
    }

    my $templateWeb = $webName;

    # Get edit template, standard or a different skin
    #### Removed a chunk here. Figure out how we can get the right
    #### template by using the editaction url parameter

    my $tmpl = $session->{templates}->readTemplate( "editsection", $skin );

    unless ($topicExists) {
        if ($templateTopic) {
            ( $templateWeb, $templateTopic ) =
              $session->normalizeWebTopicName( $templateWeb, $templateTopic );

            unless ( $store->topicExists( $templateWeb, $templateTopic ) ) {
                throw TWiki::OopsException(
                    'accessdenied',
                    def    => 'no_such_topic',
                    web    => $templateWeb,
                    topic  => $templateTopic,
                    params => ['templatetopic']
                );
            }

            ( $meta, $text ) =
              $store->readTopic( $session->{user}, $templateWeb, $templateTopic,
                undef );
        }
        else {
            ( $meta, $text ) =
              TWiki::UI::readTemplateTopic( $session, 'WebTopicEditTemplate' );
        }

        $extra = "(not exist)";

        # If present, instantiate form
        if ( !$formTemplate ) {
            my $form = $meta->get('FORM');
            $formTemplate = $form->{name} if $form;
        }

        $text = $session->expandVariablesOnTopicCreation( $text, $user );
        $tmpl =~ s/%NEWTOPIC%/1/;
    }
    else {
        $tmpl =~ s/%NEWTOPIC%//;
    }
    $tmpl =~ s/%TEMPLATETOPIC%/$templateTopic/;

    # override with parameter if set
    $text = $ptext if defined $ptext;

    # Insert the rev number/date we are editing. This will be boolean false if
    # this is a new topic.
    if ($topicExists) {
        my ( $orgDate, $orgAuth, $orgRev ) = $meta->getRevisionInfo();
        $tmpl =~ s/%ORIGINALREV%/${orgRev}_$orgDate/g;
    }
    else {
        $tmpl =~ s/%ORIGINALREV%/0/g;
    }

    # parent setting
    if ( $theParent eq 'none' ) {
        $meta->remove('TOPICPARENT');
    }
    elsif ($theParent) {
        my $parentWeb;
        ( $parentWeb, $theParent ) =
          $session->normalizeWebTopicName( $webName, $theParent );
        if ( $parentWeb ne $webName ) {
            $theParent = $parentWeb . '.' . $theParent;
        }
        $meta->put( 'TOPICPARENT', { name => $theParent } );
    }
    $tmpl =~ s/%TOPICPARENT%/$theParent/;

    if ($formTemplate) {
        $meta->remove('FORM');
        if ( $formTemplate ne 'none' ) {
            $meta->put( 'FORM', { name => $formTemplate } );
        }
        else {
            $meta->remove('FORM');
        }
        $tmpl =~ s/%FORMTEMPLATE%/$formTemplate/go;
    }

    if ($saveCmd) {
        $text =
          $store->readTopicRaw( $session->{user}, $webName, $topic, undef );
    }

    $session->{plugins}->beforeEditHandler( $text, $topic, $webName, $meta )
      unless ($saveCmd);

    if ( $TWiki::cfg{Log}{edit} ) {

        # write log entry
        $session->writeLog( 'edit', $webName . '.' . $topic, $extra );
    }

    $tmpl =~ s/\(edit\)/\(edit cmd=$saveCmd\)/go if $saveCmd;

    $tmpl =~ s/%CMD%/$saveCmd/go;
    $session->enterContext( 'can_render_meta', $meta );

    $tmpl = $session->handleCommonTags( $tmpl, $webName, $topic );
    $tmpl = $session->{renderer}->getRenderedVersion( $tmpl, $webName, $topic );

    # Don't want to render form fields, so this after getRenderedVersion
    my $formMeta = $meta->get('FORM');
    my $form     = '';
    my $formText = '';
    $form = $formMeta->{name} if ($formMeta);
    if ( $form && !$saveCmd ) {
        my $getValuesFromFormTopic = ( $formTemplate && !$ptext );

        # if there's a form template, then pull whatever values exist in
        # the query into the meta, overriding the values in the topic.
        my $formDef = new TWiki::Form( $session, $templateWeb, $form );
        unless ($formDef) {
            throw TWiki::OopsException(
                'attention',
                def    => 'no_form_def',
                web    => $session->{webName},
                topic  => $session->{topicName},
                params => [ $templateWeb, $form ]
            );
        }
        $formDef->getFieldValuesFromQuery( $session->{cgiQuery}, $meta, 1 );

        # and render them for editing
        if ( $editaction eq "text" ) {
            $formText =
              $formDef->renderHidden( $meta, $getValuesFromFormTopic );
        }
        else {
            $formText =
              $formDef->renderForEdit( $webName, $topic, $meta,
                $getValuesFromFormTopic );
        }
    }
    elsif ( !$saveCmd
        && $session->{prefs}->getWebPreferencesValue( 'WEBFORMS', $webName ) )
    {
        $formText = $session->{templates}->readTemplate( "addform", $skin );
        $formText = $session->handleCommonTags( $formText, $webName, $topic );
    }
    $tmpl =~ s/%FORMFIELDS%/$formText/g;

    $tmpl =~ s/%FORMTEMPLATE%//go;    # Clear if not being used
    my $p = $session->{prefs};

    # Table

    my $width = $p->getPreferencesValue( "SECTIONEDITBOXWIDTH", $webName )
      || $p->getPreferencesValue( "EDITBOXWIDTH", $webName );
    my $height = $p->getPreferencesValue( "SECTIONEDITBOXHEIGHT", $webName )
      || $p->getPreferencesValue( "EDITBOXHEIGHT", $webName );
    my $style = $p->getPreferencesValue( "SECTIONEDITBOXSTYLE", $webName )
      || $p->getPreferencesValue( "EDITBOXSTYLE", $webName );
    $tmpl =~ s/%SECTIONEDITBOXWIDTH%/$width/go;
    $tmpl =~ s/%SECTIONEDITBOXHEIGHT%/$height/go;
    $tmpl =~ s/%SECTIONEDITBOXSTYLE%/$style/go;
    $tmpl =~ s/%ORIGURL%/$origurl/go;

    return ( $session, $text, $tmpl );

}

# TW: The following concoction is to work around a problem with
# Firefox which eats leading and trailing newlines on text passed
# as hidden URL parameter
sub protect {
    return ' ' . $_[0] . ' ';
}

sub unprotect {
    return substr( $_[0], 1, -1 );
}

# =========================
sub finalize_edit {
####    my ( $session, $pretxt, $sectxt, $postxt, $pretxtRender, $postxtRender ) = @_;
    my ( $session, $pretxt, $sectxt, $postxt, $pretxtRender, $postxtRender,
        $tmpl )
      = @_;

    # $_[6] is template
    #### Why is this necessary?
    #### For right now, just pass tmpl

    my $query   = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic   = $session->{topicName};
    my $store   = $session->{store};
    my $user    = $session->{user};

    # apptype is undocumented legacy
    my $cgiAppType =
         $query->param('contenttype')
      || $query->param('apptype')
      || 'text/html';

    $pretxt = TWiki::entityEncode($pretxt);
    $pretxt = protect($pretxt);
    $tmpl =~ s/%PRETEXTFIELD%/$pretxt/go;
    $postxt = TWiki::entityEncode($postxt);
    $postxt = protect($postxt);
    $tmpl =~ s/%POSTEXTFIELD%/$postxt/go;

    ##AS added hook for plugins that want to do heavy stuff
    #TW: Does not appear to be in Edit.pm
    $session->{plugins}->beforeEditHandler( $sectxt, $topic, $webName );
    ##/AS

    $tmpl =~ s/%UNENCODED_TEXT%/$sectxt/g;

    #### quoteForXml included in entityEncode
    #### $sectxt = &TWiki::Contrib::EditContrib::quoteForXml($sectxt);
    $sectxt = TWiki::entityEncode($sectxt);
    $sectxt = $sectxt;
    $tmpl =~ s/%TEXT%/$sectxt/g;

    $store->setLease( $webName, $topic, $user, $TWiki::cfg{LeaseLength} );

    ## TW: Is this tstill needed?
    if ( $sectxt =~ /^\n/o ) {
        $tmpl =~
          s/%TEXTDETAIL%/<input type="hidden" name="newline" value="t" \/>/go;
    }
    else {
        $tmpl =~ s/%TEXTDETAIL%//go;
    }

    if ($pretxtRender) {
        #### quoteForXml included in entityEncode
        #### $pretxtRender = &TWiki::Contrib::EditContrib::quoteForXml($pretxtRender);
        #### don't think we still do the tab encoding
        $pretxtRender =~ s/ {3}/\t/go;
        $pretxtRender =
          $session->handleCommonTags( $pretxtRender, $webName, $topic );

        # Same as TWiki::Func::renderText( $pretxtRender )
        $pretxtRender =
          $session->{renderer}
          ->getRenderedVersion( $pretxtRender, $webName, $topic );

        # Disable links and inputs in the text
        $pretxtRender =~
          s#<a\s[^>]*>(.*?)</a>#<span class="twikiEmulatedLink">$1</span>#gis;
        $pretxtRender =~
          s/<(input|button|textarea) /<$1 disabled="disabled"/gis;
        $pretxtRender =~ s(</?form(|\s.*?)>)()gis;
        $pretxtRender =~ s/(<[^>]*\bon[A-Za-z]+=)('[^']*'|"[^"]*")/$1''/gis;

        $tmpl =~ s/%PRETEXT%/$pretxtRender/go;
    }
    else {
        $tmpl =~ s/%PRETEXT%//go;
    }

    if ($postxtRender) {
        #### quoteForXml included in entityEncode
        #### $postxtRender = &TWiki::Contrib::EditContrib::quoteForXml($postxtRender);
        #### don't think we still do the tab encoding
        $postxtRender =~ s/ {3}/\t/go;
        $postxtRender =
          $session->handleCommonTags( $postxtRender, $webName, $topic );

        # Same as TWiki::Func::renderText( $pretxtRender )
        $postxtRender =
          $session->{renderer}
          ->getRenderedVersion( $postxtRender, $webName, $topic );

        # Disable links and inputs in the text
        $postxtRender =~
          s#<a\s[^>]*>(.*?)</a>#<span class="twikiEmulatedLink">$1</span>#gis;
        $postxtRender =~
          s/<(input|button|textarea) /<$1 disabled="disabled"/gis;
        $postxtRender =~ s(</?form(|\s.*?)>)()gis;
        $postxtRender =~ s/(<[^>]*\bon[A-Za-z]+=)('[^']*'|"[^"]*")/$1''/gis;

        $tmpl =~ s/%POSTEXT%/$postxtRender/go;
    }
    else {
        $tmpl =~ s/%POSTEXT%//go;
    }

    $tmpl =~ s|( ?) *</*nop/*>\n?|$1|gois;    # remove <nop> tags

    $session->writeCompletePage( $tmpl, 'edit', $cgiAppType );
}

# =========================
sub addSection {
    my $session = shift;

    $session->enterContext('edit');
    my $text = '';
    my $tmpl = '';
    ( $session, $text, $tmpl ) = &edit($session);

    my $query    = $session->{cgiQuery};
    my $webName  = $session->{webName};
    my $topic    = $session->{topicName};
    my $preamble = $query->param('pretxt') || '';
    my $posamble = $query->param('postxt') || '';
    my $attrs    = new TWiki::Attrs( $query->param('mapping') || '' );

    $preamble =~ s/\\n/\n/g;
    $preamble =~ s/%HTML{(.*)}%/<$1>/go;
    $posamble =~ s/\\n/\n/g;
    $posamble =~ s/%HTML{(.*)}%/<$1>/go;
    foreach my $i ( keys %$attrs ) {
        next if $i eq "_RAW";
        my $inew = $query->param( $attrs->{$i} );
        $preamble =~ s/$i/$inew/g;
        $posamble =~ s/$i/$inew/g;
    }

    my $sectxt = "";
    my $pretxt = $text . $preamble;
    my $postxt = $posamble;

    finalize_edit( $session, $pretxt, $sectxt, $postxt, '', '', $tmpl );

}

# =========================
sub saveSection {
    my $session = shift;

    $TWiki::Plugins::SESSION = $session;
    my $query = TWiki::Func::getCgiQuery();

    # update text url param
    my $text =
        unprotect( $query->param('pretxt') )
      . $query->param('text')
      . unprotect( $query->param('postxt') );
    $query->param( -name => "text", -value => $text );

    # call original save
    TWiki::UI::Save::save($session);
}

# =========================
# take the REQUEST_URI, strip off the PATH_INFO from the end, the last word
# is the action; this is done that complicated as there may be different
# paths for the same action depending on the apache configuration (
# rewrites, aliases)
sub getCgiAction {

    my $pathInfo  = $ENV{'PATH_INFO'}   || '';
    my $theAction = $ENV{'REQUEST_URI'} || '';
    if ( $theAction =~ /^.*?\/([^\/]+)$pathInfo.*$/ ) {
        $theAction = $1;
    }
    else {
        $theAction = 'view';
    }

    return $theAction;
}

1;
