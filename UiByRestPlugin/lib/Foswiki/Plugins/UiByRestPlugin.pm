# This script Copyright (c) 2009 Collaborganize  ( www.collaborganize.com )
# and distributed under the GPL (see below)
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
# Author: Eugen Mayer, Oliver Krueger

# =========================
package Foswiki::Plugins::UiByRestPlugin;

# =========================
use strict;
use warnings;
use Error qw(:try);

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package.
use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

# This should always be $Rev: 12445$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 12445$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '0.1';

# Short description of this plugin
# One line description, is shown in the %FoswikiWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION =
'Provides rest handler for the common UI actions like rename/login/attach etc.';

# Name of this Plugin, only used in this module
$pluginName = 'UiByRestPlugin';

# =========================
my $jqPluginName = "JQueryCompatibilityModePlugin";

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # do-some-UI-action rest handlers
    # 2-letter shortcuts for limited-url-length environments
    Foswiki::Func::registerRESTHandler( 'login', \&_login );

    # ********* TOPIC **********
    Foswiki::Func::registerRESTHandler( 'topic_rename',  \&_renameTopic );
    Foswiki::Func::registerRESTHandler( 'tr',            \&_renameTopic );
    Foswiki::Func::registerRESTHandler( 'topic_move',    \&_moveTopic );
    Foswiki::Func::registerRESTHandler( 'tm',            \&_moveTopic );
    Foswiki::Func::registerRESTHandler( 'revision_list', \&_listRevisions );
    Foswiki::Func::registerRESTHandler( 'rl',            \&_listRevisions );
    Foswiki::Func::registerRESTHandler( 'revision_compare',
        \&_compareRevisions );
    Foswiki::Func::registerRESTHandler( 'rc', \&_compareRevisions );
    Foswiki::Func::registerRESTHandler( 'revision_restore',
        \&_restoreRevision );
    Foswiki::Func::registerRESTHandler( 'rs',             \&_restoreRevision );
    Foswiki::Func::registerRESTHandler( 'parent_set',     \&_setParent );
    Foswiki::Func::registerRESTHandler( 'pa',             \&_setParent );
    Foswiki::Func::registerRESTHandler( 'preference_set', \&_setPreference );
    Foswiki::Func::registerRESTHandler( 'ps',             \&_setPreference );
    Foswiki::Func::registerRESTHandler( 'preference_get', \&_getPreference );
    Foswiki::Func::registerRESTHandler( 'pg',             \&_getPreference );
    Foswiki::Func::registerRESTHandler( 'child_get',      \&_getChildTopics );
    Foswiki::Func::registerRESTHandler( 'cg',             \&_getChildTopics );
    Foswiki::Func::registerRESTHandler( 'backlink_get',   \&_getBacklinks );
    Foswiki::Func::registerRESTHandler( 'bg',             \&_getBacklinks );

    # ********* ATTACHMENT **********
    Foswiki::Func::registerRESTHandler( 'attachment_move', \&_moveAttachment );
    Foswiki::Func::registerRESTHandler( 'am',              \&_moveAttachment );
    Foswiki::Func::registerRESTHandler( 'attachment_rename',
        \&_renameAttachment );
    Foswiki::Func::registerRESTHandler( 'ar', \&_renameAttachment );
    Foswiki::Func::registerRESTHandler( 'attachment_replace',
        \&_replaceAttachment );
    Foswiki::Func::registerRESTHandler( 'arepl', \&_replaceAttachment );
    Foswiki::Func::registerRESTHandler( 'attachment_add', \&_addAttachment );
    Foswiki::Func::registerRESTHandler( 'aadd',           \&_addAttachment );
    Foswiki::Func::registerRESTHandler( 'attachment_versions',
        \&_versionsAttachment );
    Foswiki::Func::registerRESTHandler( 'aver', \&_versionsAttachment );

    # ********* WEB **********
    Foswiki::Func::registerRESTHandler( 'web_rename', \&_renameWeb );
    Foswiki::Func::registerRESTHandler( 'wr',         \&_renameWeb );
    Foswiki::Func::registerRESTHandler( 'web_move',   \&_moveWeb );
    Foswiki::Func::registerRESTHandler( 'wm',         \&_moveWeb );
    Foswiki::Func::registerRESTHandler( 'web_create', \&_createWeb );
    Foswiki::Func::registerRESTHandler( 'wc',         \&_createWeb );

    # request-a-UI-form ( template ) rest handlers
    Foswiki::Func::registerRESTHandler( 'trform',    \&_renameTopicForm );
    Foswiki::Func::registerRESTHandler( 'tmform',    \&_moveTopicForm );
    Foswiki::Func::registerRESTHandler( 'loginform', \&_loginForm );
    Foswiki::Func::registerRESTHandler( 'areplform', \&_replaceAttachmentForm );
    Foswiki::Func::registerRESTHandler( 'aaddform',  \&_addAttachmentForm );
    Foswiki::Func::registerRESTHandler( 'averform', \&_versionsAttachmentForm );
    Foswiki::Func::registerRESTHandler( 'atablform', \&_tableAttachmenstForm );
    return 1;
}

sub _showTemplate {
    my ( $topic, $web, $skin, $templatename ) = @_;

    my $template = Foswiki::Func::loadTemplate( $templatename, $skin, undef );
    return Foswiki::Func::expandCommonVariables( $template, $topic, $web,
        undef );
}

=begin TML

---++ _login( $session )
Perform a login and return eventually a login form

=cut

sub _login {
    my $session = shift;
    use Foswiki::Plugins::UiByRestPlugin::Login;
    return Foswiki::Plugins::UiByRestPlugin::Login::do($session);
}

=begin TML

---++ _loginForm( $session )
return the Login form

=cut

sub _loginForm {
    my $session = shift;
    use Foswiki::Plugins::UiByRestPlugin::Login;
    return Foswiki::Plugins::UiByRestPlugin::Login::template($session);
}

=begin TML

---++ _renameTopicForm( $session )
Return the template which is defined for renaming a topic ( renametopic.YOURSKIN.tmpl )
=cut

sub _renameTopicForm {
    my $session = shift;
    use Foswiki::Plugins::UiByRestPlugin::TopicRename;
    return Foswiki::Plugins::UiByRestPlugin::TopicRename::template($session);
}

=begin TML

---++ _renameTopic( $session )
This is a wrapper substitute for the rename bin script.

It checks the prerequisites and sets the following status codes:
400 : url parameter(s) are missing
400 : newtopic is not valid (non) wikiword
401 : access denied for unauthorized user
403 : the user is not allowed to RENAME the topic
404 : the source topic does not exist
409 : the target topic already exists

newweb url parameter will be replaces with source webname.

Return:
In case of an error, the renametopic template is returned.
In case of no error, the Manage:rename() method is invoked,
which will take further (url) parameters and may end in a redirect.

=cut

sub _renameTopic {
    my $session = shift;
    use Foswiki::Plugins::UiByRestPlugin::TopicRename;
    return Foswiki::Plugins::UiByRestPlugin::TopicRename::do($session);
}

=begin TML

---++ _moveTopic( $session )
This is a wrapper substitute for the rename bin script.

It checks the prerequisites and sets the following status codes:
400 : url parameter(s) are missing
400 : newtopic is not valid (non) wikiword
401 : access denied for unauthorized user
403 : the user is not allowed to RENAME the topic
404 : the source topic does not exist
409 : the target topic already exists

Return:
In case of an error, the movetopic template is returned.
In case of no error, the Manage:rename() method is invoked,
which will take further (url) parameters and may end in a redirect.

=cut

sub _moveTopic {
    my $session = shift;
    use Foswiki::Plugins::UiByRestPlugin::TopicMove;
    return Foswiki::Plugins::UiByRestPlugin::TopicMove::do($session);
}

=begin TML

---++ _renameTopicForm( $session )
Return the template which is defined for renaming a topic ( movetopic.YOURSKIN.tmpl )
=cut

sub _moveTopicForm {
    my $session = shift;
    use Foswiki::Plugins::UiByRestPlugin::TopicMove;
    return Foswiki::Plugins::UiByRestPlugin::TopicMove::template($session);
}

=begin TML

---++ _moveAttachment( $session )
This is a wrapper substitute for the rename bin script.

It checks the prerequisites and sets the following status codes:
400 : url parameter(s) are missing
400 : newtopic is not valid (non) wikiword
401 : access denied for unauthorized user
403 : the user is not allowed to CHANGE on attachment topic
404 : attachment does not exist
409 : the target topic already exists

Return:
In case of an error, the moveattachment template is returned.
In case of no error, the Manage:rename() method is invoked,
which will take further (url) parameters and may end in a redirect.

=cut

sub _moveAttachment {
    my $session = shift;
    use Foswiki::Plugins::UiByRestPlugin::AttachmentMove;
    return Foswiki::Plugins::UiByRestPlugin::AttachmentMove::do($session);
}

sub _replaceAttachment {
    my $session = shift;
    use Foswiki::Plugins::UiByRestPlugin::AttachmentReplace;
    return Foswiki::Plugins::UiByRestPlugin::AttachmentReplace::do($session);

}

sub _replaceAttachment {
    my $session = shift;
    use Foswiki::Plugins::UiByRestPlugin::AttachmentReplace;
    return Foswiki::Plugins::UiByRestPlugin::AttachmentReplace::do($session);
}

sub _replaceAttachmentForm {
    my $session = shift;
    use Foswiki::Plugins::UiByRestPlugin::AttachmentReplace;
    return Foswiki::Plugins::UiByRestPlugin::AttachmentReplace::template(
        $session);
}

sub _addAttachmentForm {
    my $session = shift;
    use Foswiki::Plugins::UiByRestPlugin::AttachmentAdd;
    return Foswiki::Plugins::UiByRestPlugin::AttachmentAdd::template($session);
}

sub _addAttachment {
    my $session = shift;
    use Foswiki::Plugins::UiByRestPlugin::AttachmentAdd;
    return Foswiki::Plugins::UiByRestPlugin::AttachmentAdd::do($session);
}

sub _versionsAttachment {
    my $session = shift;
    use Foswiki::Plugins::UiByRestPlugin::AttachmentReplace;
    return Foswiki::Plugins::UiByRestPlugin::AttachmentReplace::do($session);
}

sub _versionsAttachmentForm {
    my $session = shift;
    use Foswiki::Plugins::UiByRestPlugin::AttachmentVersions;
    return Foswiki::Plugins::UiByRestPlugin::AttachmentVersions::template(
        $session);
}

sub _tableAttachmenstForm {
    my $session = shift;
    use Foswiki::Plugins::UiByRestPlugin::AttachmentTable;
    return Foswiki::Plugins::UiByRestPlugin::AttachmentTable::template(
        $session);
}

=begin TML

---++ _renameWeb( $session )
%X% *Untested yet* %X%

This is a wrapper substitute for the rename bin script.

It checks the prerequisites and sets the following status codes:
400 : url parameter(s) are missing
400 : newparentweb or newsubweb is not a valid webname
401 : access denied for unauthorized user
403 : the user is not allowed to CHANGE the topic
404 : the old web does not exist
409 : the newweb already exists

Return:
In case of an error, the renametopic template is returned.
In case of no error, the Manage:rename() method is invoked,
which will take further (url) parameters and may end in a redirect.

=cut

sub _renameWeb {
    my $session = shift;
    use Foswiki::Plugins::UiByRestPlugin::WebRename;
    return Foswiki::Plugins::UiByRestPlugin::WebRename::do($session);
}
