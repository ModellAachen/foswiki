# See bottom of file for license and copyright information
package Foswiki::Plugins::ActionTrackerPlugin;

use strict;
use Assert;
use Error qw( :try );

use Foswiki::Func ();
use Foswiki::Plugins ();

our $VERSION = '$Rev$';
our $RELEASE = '2.4.9';
our $SHORTDESCRIPTION =
    'Adds support for action tags in topics, and automatic notification of action statuses';
our $initialised = 0;

my $doneHeader   = 0;
my $actionNumber = 0;
my $defaultFormat;

# Map default options
our $options;

sub initPlugin {

    $initialised = 0;
    $doneHeader  = 0;

    Foswiki::Func::registerRESTHandler( 'update', \&_updateRESTHandler );

    Foswiki::Func::registerTagHandler( 'ACTIONSEARCH', \&_handleActionSearch,
				       'context-free' );
    use Foswiki::Contrib::JSCalendarContrib;
    if ( $@ || !$Foswiki::Contrib::JSCalendarContrib::VERSION ) {
        Foswiki::Func::writeWarning( 'JSCalendarContrib not found ' . $@ );
    }
    else {
        Foswiki::Contrib::JSCalendarContrib::addHEAD('foswiki');
    }

    return 1;
}

sub commonTagsHandler {
    my ( $otext, $topic, $web, $meta ) = @_;

    return unless ( $_[0] =~ m/%ACTION.*{.*}%/o );

    return unless lazyInit( $web, $topic );

    # Format actions in the topic.
    # Done this way so we get tables built up by
    # collapsing successive actions.
    my $as = Foswiki::Plugins::ActionTrackerPlugin::ActionSet::load(
	$web, $topic, $otext, 1 );
    my $actionGroup;
    my $text = '';

    foreach my $entry ( @{ $as->{ACTIONS} } ) {
        if ( ref($entry) ) {
            if ( !$actionGroup ) {
                $actionGroup =
		    new Foswiki::Plugins::ActionTrackerPlugin::ActionSet();
            }
            $actionGroup->add($entry);
        }
        elsif ( $entry =~ /(\S|\n\s*\n)/s ) {
            if ($actionGroup) {
                $text .=
		    $actionGroup->formatAsHTML(
			$defaultFormat, 'href', 'atpDef' );
                $actionGroup = undef;
            }
            $text .= $entry;
        }
    }
    if ($actionGroup) {
        $text .=
	    $actionGroup->formatAsHTML( $defaultFormat, 'href', 'atpDef' );
    }

    $_[0] = $text;

    # COVERAGE OFF debug only
    if ( $options->{DEBUG} ) {
        $_[0] =~
	    s/%ACTIONNOTIFICATIONS{(.*?)}%/_handleActionNotify($web, $1)/geo;
    }

    # COVERAGE ON

}

# This handler is called by the edit script just before presenting
# the edit text in the edit box.
# We use it to populate the actionform.tmpl template, which is then
# inserted in the edit.action.tmpl as the %UNENCODED_TEXT%.
# We process the %META fields from the raw text of the topic and
# insert them as hidden fields in the form, so the topic is
# fully populated. This allows us to call either 'save' or 'preview'
# to terminate the edit, as selected by the NOPREVIEW parameter.
sub beforeEditHandler {

    #my( $text, $topic, $web, $meta ) = @_;

    if ( Foswiki::Func::getSkin() =~ /\baction\b/ ) {
        return _beforeActionEdit(@_);
    }
    else {
        return _beforeNormalEdit(@_);
    }
}

sub _beforeNormalEdit {

    #my( $text, $topic, $web, $meta ) = @_;
    # Coarse method of testing if modern action syntax is used
    my $oc = scalar( $_[0] =~ m/%ACTION{.*?}%/g );
    my $cc = scalar( $_[0] =~ m/%ENDACTION%/g );

    if ( $cc < $oc ) {
        return unless lazyInit( $_[2], $_[1] );

        my $as =
	    Foswiki::Plugins::ActionTrackerPlugin::ActionSet::load( $_[2], $_[1],
								    $_[0], 1 );
        $_[0] = $as->stringify();
    }
}

# Note: a simple return will effectively ignore the action tracker for
# purposes of this edit. However the skin template will still be expanded,
# so for clean error handling, make sure $_[0] is set to something.
sub _beforeActionEdit {
    my ( $text, $topic, $web, $meta ) = @_;

    return unless lazyInit( $web, $topic );

    my $query = Foswiki::Func::getCgiQuery();

    my $uid = $query->param('atp_action');
    unless (defined $uid) {
	$_[0] = "Bad URL parameters; atp_action is not set";
	return;
    }

    # actionform.tmpl is a sub-template inserted into the parent template
    # as %TEXT%. This is done so we can use the standard template mechanism
    # without screwing up the content of the subtemplate.
    my $tmpl =
	Foswiki::Func::readTemplate( 'actionform', Foswiki::Func::getSkin() );

    # Here we want to show the current time in same time format as the user
    # sees elsewhere in his browser on Foswiki.
    my $date =
	Foswiki::Func::formatTime( time(), undef,
				   $Foswiki::cfg{DisplayTimeValues} );

    die unless ($date);

    $tmpl =~ s/%DATE%/$date/g;
    my $user = Foswiki::Func::getWikiUserName();
    $tmpl =~ s/%WIKIUSERNAME%/$user/go;
    $tmpl = Foswiki::Func::expandCommonVariables( $tmpl, $topic, $web );
    $tmpl = Foswiki::Func::renderText( $tmpl, $web );

    # The 'command' parameter is used to signal to the afterEditHandler and
    # the beforeSaveHandler that they have to handle the fields of the
    # edit differently
    my $fields = CGI::hidden( -name => 'closeactioneditor', -value => 1 );
    $fields .= CGI::hidden( -name => 'cmd', -value => "" );

    # write in hidden fields
    if ($meta) {
        $meta->forEachSelectedValue( qr/FIELD/, undef, \&_hiddenMeta,
				     { text => \$fields } );
    }

    # Find the action.
    my $as =
	Foswiki::Plugins::ActionTrackerPlugin::ActionSet::load( $web, $topic,
								$text, 1 );

    my ( $action, $pre, $post ) = $as->splitOnAction($uid);
    # Make sure the action currently exists
    unless( $action ) {
	$_[0] = "Action does not exist - cannot edit";
	return
    };

    # Add revision info to support merging
    my $info = $meta->getRevisionInfo();
    $fields .= CGI::hidden( -name => 'originalrev',
			    -value => "$info->{version}_$info->{date}" );

    $tmpl =~ s/%UID%/$uid/go;

    my $submitCmd     = "preview";
    my $submitCmdName = "Preview";
    my $submitCmdOpt  = "";

    if ( $options->{NOPREVIEW} ) {
        $submitCmd     = "save";
        $submitCmdName = "Save";
        $submitCmdOpt  = "?unlock=on";
    }

    $tmpl =~ s/%SUBMITCMDNAME%/$submitCmdName/go;
    $tmpl =~ s/%SUBMITCMDOPT%/$submitCmdOpt/go;
    $tmpl =~ s/%SUBMITCOMMAND%/$submitCmd/go;

    my $fmt = new Foswiki::Plugins::ActionTrackerPlugin::Format(
        $options->{EDITHEADER},
        $options->{EDITFORMAT},
        $options->{EDITFOOTER},
        $options->{EDITORIENT},
        "", ""
	);
    my $editable = $action->formatForEdit($fmt);
    $tmpl =~ s/%EDITFIELDS%/$editable/o;

    $tmpl =~ s/%EBH%/$options->{EDITBOXHEIGHT}/go;
    $tmpl =~ s/%EBW%/$options->{EDITBOXWIDTH}/go;

    $text = $action->{text};

    # Process the text so it's nice to edit. This gets undone in Action.pm
    # when the action is saved.
    $text =~ s/^\t/   /gos;
    $text =~ s/<br( \/)?>/\n/gios;
    $text =~ s/<p( \/)?>/\n\n/gios;

    $tmpl =~ s/%TEXT%/$text/go;
    $tmpl =~ s/%HIDDENFIELDS%/$fields/go;

    $_[0] = $tmpl;
}

sub _hiddenMeta {
    my ( $value, $options ) = @_;

    my $name = $options->{_key};
    ${ $options->{text} } .= CGI::hidden( -name => $name, -value => $value );
    return $value;
}

# This handler is called by the preview script just before
# presenting the text.
# The skin name is passed over from the original invocation of
# edit so if the skin is "action" we know we have been editing
# an action and have to recombine fields to create the
# actual text.
# Metadata is handled by the preview script itself.
sub afterEditHandler {
    my ( $text, $topic, $web ) = @_;

    my $query = Foswiki::Func::getCgiQuery();
    return unless ( $query->param('closeactioneditor') );

    return unless lazyInit( $web, $topic );

    my ( $ancestorRev, $ancestorDate ) = (0, 0);
    my $origin = $query->param('originalrev');
    ASSERT(defined($origin)) if DEBUG;

    if ($origin =~ /^(\d+)_(\d+)$/) {
	( $ancestorRev, $ancestorDate ) = ( $1, $2 );
    }

    # Get the most recently saved rev
    (my $meta, $text) = Foswiki::Func::readTopic($web, $topic);
    my $info = $meta->getRevisionInfo();
    my $mustMerge = ($ancestorRev ne $info->{version}
		     || $ancestorDate && $info->{date}
		     && $ancestorDate ne $info->{date});

    my $latest_as = Foswiki::Plugins::ActionTrackerPlugin::ActionSet::load(
	$web, $topic, $text, 1);

    my $uid = $query->param("uid");
    ASSERT(defined($uid)) if DEBUG;

    my $latest_act = $latest_as->search(
	new Foswiki::Attrs('uid="' . $uid . '"'))->first;

    my $new_act =
	Foswiki::Plugins::ActionTrackerPlugin::Action::createFromQuery(
	    $_[2], $_[1], $latest_act->{ACTION_NUMBER}, $query );

    unless (UNIVERSAL::isa($latest_act, 'Foswiki::Plugins::ActionTrackerPlugin::Action')) {
	# If the edited action was not found in the latest rev, then force it in (it may
	# have been removed in another parallel edit)
	$latest_act = $new_act;
	$latest_as->add($new_act);
    }

    # See if we can get a common ancestor for merging
    my $old_act;
    if ($mustMerge) {

	# If we have to merge, we need the ancestor root of the action to
	# do a three-way merge.
	# If the previous revision was generated by a reprev,
	# then the original is lost and we can't 3-way merge
	unless ($info->{reprev} && $info->{version}
	    && $info->{reprev} == $info->{version} ) {

	    my ($ances_meta, $ances_text) = Foswiki::Func::readTopic($web, $topic, $ancestorRev);
	    my $ances = Foswiki::Plugins::ActionTrackerPlugin::ActionSet::load(
		$web, $topic, $ances_text, $ancestorRev);
	    $old_act = $ances->search(
		new Foswiki::Attrs('uid="' . $uid . '"'))->first;
	}
    }

    $latest_act->updateFromCopy($new_act, $mustMerge, $info->{version}, $ancestorRev, $old_act);
    $latest_act->populateMissingFields();
    $text = $latest_as->stringify();

    # take the opportunity to fill in the missing fields in actions
    _addMissingAttributes( $text, $_[1], $_[2] );

    $_[0] = $text;
}

# Process the actions and add UIDs and other missing attributes
sub beforeSaveHandler {
    my ( $text, $topic, $web ) = @_;

    return unless $text;

    return unless lazyInit( $web, $topic );

    my $query = Foswiki::Func::getCgiQuery();
    return unless ($query);

    if ( $query->param('closeactioneditor') ) {

        # this is a save from the action editor. Text will just be the text of the action - we
	# must recover the rest from the topic on disc.

        # Strip pre and post metadata from the text
        my $premeta  = "";
        my $postmeta = "";
        my $inpost   = 0;
        my $text     = "";
        foreach my $line ( split( /\r?\n/, $_[0] ) ) {
            if ( $line =~ /^%META:[^{]+{[^}]*}%/ ) {
                if ($inpost) {
                    $postmeta .= "$line\n";
                }
                else {
                    $premeta .= "$line\n";
                }
            }
            else {
                $text .= "$line\n";
                $inpost = 1;
            }
        }

        # compose the text
        afterEditHandler( $text, $topic, $web );

        # reattach the metadata
        $text .= "\n" unless $text =~ /\n$/s;
        $postmeta = "\n$postmeta" if $postmeta;
        $_[0] = $premeta . $text . $postmeta;
    }
    else {

        # take the opportunity to fill in the missing fields in actions
        _addMissingAttributes( $_[0], $topic, $web );
    }
}

# PRIVATE Add missing attributes to all actions that don't have them
sub _addMissingAttributes {

    #my ( $text, $topic, $web ) = @_;
    my $text = "";
    my $descr;
    my $attrs;
    my $gathering;
    my $processAction = 0;
    my $an            = 0;
    my %seenUID;

    my $as =
	Foswiki::Plugins::ActionTrackerPlugin::ActionSet::load( $_[2], $_[1],
								$_[0], 1 );

    foreach my $action ( @{ $as->{ACTIONS} } ) {
        next unless ref($action);
        $action->populateMissingFields();
        if ( $seenUID{ $action->{uid} } ) {

            # This can happen if there has been a careless
            # cut and paste. In this case, the first instance
            # of the action gets the old UID. This may banjax
            # change notification, but it's better than the
            # alternative!
            $action->{uid} = $action->getNewUID();
        }
        $seenUID{ $action->{uid} } = 1;
    }
    $_[0] = $as->stringify();
}

# =========================
# Perform filtered search for all actions
sub _handleActionSearch {
    my ( $session, $attrs, $topic, $web ) = @_;

    return unless lazyInit( $web, $topic );

    # use default format unless overridden
    my $fmt;
    my $fmts    = $attrs->remove('format');
    my $plain   = Foswiki::Func::isTrue($attrs->remove('nohtml'));
    my $hdrs    = $attrs->remove('header');
    my $foot    = $attrs->remove('footer');
    my $sep     = $attrs->remove('separator');
    my $orient  = $attrs->remove('orient');
    my $sort    = $attrs->remove('sort');
    my $reverse = $attrs->remove('reverse');
    if ( defined($fmts) || defined($hdrs) || defined($orient) || defined($foot) ) {
        $fmts   = $defaultFormat->getFields()      unless ( defined($fmts) );
        $hdrs   = $defaultFormat->getHeaders()     unless ( defined($hdrs) );
        $foot   = $defaultFormat->getFooters()     unless ( defined($foot) );
        $orient = $defaultFormat->getOrientation() unless ( defined($orient) );
        $fmt = new Foswiki::Plugins::ActionTrackerPlugin::Format(
	    $hdrs, $fmts, $foot, $orient, $fmts, '' );
    }
    else {
        $fmt = $defaultFormat;
    }

    my $actions =
	Foswiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWebs(
	    $web, $attrs, 0 );
    $actions->sort( $sort, $reverse );
    my $result;
    if ($plain) {
	$result = $actions->formatAsString( $fmt );
    } else {
	$result = $actions->formatAsHTML( $fmt, 'href', 'atpSearch' );
    }
    return $result;
}

# Lazy initialize of plugin 'cause of performance
sub lazyInit {
    my ( $web, $topic ) = @_;

    return 1 if $initialised;

    Foswiki::Plugins::JQueryPlugin::registerPlugin(
	'ActionTracker',
	'Foswiki::Plugins::ActionTrackerPlugin::JQuery');
    unless( Foswiki::Plugins::JQueryPlugin::createPlugin(
		'ActionTracker', $Foswiki::Plugins::SESSION )) {
	die 'Failed to register JQuery plugin';
    }

    require Foswiki::Attrs;
    require Foswiki::Plugins::ActionTrackerPlugin::Options;
    require Foswiki::Plugins::ActionTrackerPlugin::Action;
    require Foswiki::Plugins::ActionTrackerPlugin::ActionSet;
    require Foswiki::Plugins::ActionTrackerPlugin::Format;

    $options = Foswiki::Plugins::ActionTrackerPlugin::Options::load();

    # Add the ATP CSS (conditionally included from $options, which is why
    # it's not done in the JQuery plugin decl)
    Foswiki::Func::addToZone("head", "JQUERYPLUGIN::ActionTracker::CSS", <<"HERE");
<link rel='stylesheet' href='$Foswiki::Plugins::ActionTrackerPlugin::options->{CSS}' type='text/css' media='all' />
HERE

    $defaultFormat = new Foswiki::Plugins::ActionTrackerPlugin::Format(
        $options->{TABLEHEADER}, $options->{TABLEFORMAT}, $options->{TABLEFOOTER},
        $options->{TABLEORIENT}, $options->{TEXTFORMAT},
        $options->{NOTIFYCHANGES}
	);

    if ( $options->{EXTRAS} ) {
        my $e = Foswiki::Plugins::ActionTrackerPlugin::Action::extendTypes(
            $options->{EXTRAS} );

        # COVERAGE OFF safety net
        if ( defined($e) ) {
            Foswiki::Func::writeWarning(
                "- Foswiki::Plugins::ActionTrackerPlugin ERROR $e");
        }

        # COVERAGE ON
    }

    $initialised = 1;

    return 1;
}

# PRIVATE return formatted actions that have changed in all webs
# Debugging only
# COVERAGE OFF debug only
sub _handleActionNotify {
    my ( $web, $expr ) = @_;

    eval 'require Foswiki::Plugins::ActionTrackerPlugin::ActionNotify';
    if ($@) {
        Foswiki::Func::writeWarning("ATP: $@");
        return;
    }

    my $text =
	Foswiki::Plugins::ActionTrackerPlugin::ActionNotify::doNotifications(
	    $web, $expr, 1 );

    $text =~ s/<html>/<\/pre>/gios;
    $text =~ s/<\/html>/<pre>/gios;
    $text =~ s/<\/?body>//gios;
    return "<!-- from an --> <pre>$text</pre> <!-- end from an -->";
}

# COVERAGE ON

sub _updateRESTHandler {
    my $session = shift;
    my $query   = Foswiki::Func::getCgiQuery();
    try {
        my $topic = $query->param('topic');
        my $web;
        ( $web, $topic ) =
	    Foswiki::Func::normalizeWebTopicName( undef, $topic );
        lazyInit( $web, $topic );
        _updateSingleAction( $web, $topic, $query->param('uid'),
			     $query->param('field') => $query->param('value') );
        print CGI::header( 'text/plain', 200 );    # simple message
    }
    catch Error::Simple with {
        my $e = shift;
        print CGI::header( 'text/plain', 500 );
        print $e->{-text};
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        print CGI::header( 'text/plain', 500 );
        print $e->stringify();
    };
    return undef;
}

sub _updateSingleAction {
    my ( $web, $topic, $uid, %changes ) = @_;

    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

    my $descr;
    my $attrs;
    my $gathering;
    my $processAction = 0;
    my $an            = 0;
    my %seenUID;

    my $as =
	Foswiki::Plugins::ActionTrackerPlugin::ActionSet::load( $web, $topic,
								$text, 1 );

    foreach my $action ( @{ $as->{ACTIONS} } ) {
        if ( ref($action) ) {
            if ( $action->{uid} == $uid ) {
                foreach my $key ( keys %changes ) {
                    $action->{$key} = $changes{$key};
                }
            }
        }
    }
    Foswiki::Func::saveTopic( $web, $topic, $meta, $as->stringify(),
			      { comment => 'atp save' } );
}

1;
__END__

Copyright (C) 2002-2003 Motorola UK Ltd - All rights reserved
Copyright (C) 2004-2011 Crawford Currie http://c-dot.co.uk

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at 
http://www.gnu.org/copyleft/gpl.html

