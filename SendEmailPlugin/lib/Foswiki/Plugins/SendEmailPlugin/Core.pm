# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (c) 2007-2010 by Arthur Clemens, Michael Daum
#
# and Foswiki Contributors. All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.

package Foswiki::Plugins::SendEmailPlugin::Core;

# Always use strict to enforce variable scoping
use strict;
use Foswiki;
use Foswiki::Func;
use Foswiki::Plugins;
use CGI qw( :all );

use vars qw( $debug $emailRE );

my $ERROR_STATUS_TAG             = 'SendEmailErrorStatus';
my $ERROR_MESSAGE_TAG            = 'SendEmailErrorMessage';
my $NOTIFICATION_CSS_CLASS       = 'sendEmailPluginNotification';
my $NOTIFICATION_ERROR_CSS_CLASS = 'sendEmailPluginError';
my $NOTIFICATION_ANCHOR_NAME     = 'SendEmailNotification';
my %ERROR_STATUS                 = (
    'noerror' => 1,
    'error'   => 2,
);
my %ERROR_STATUS_MESSAGE = (
    1 => 'success',
    2 => 'error',
);
my $EMAIL_SENT_SUCCESS_MESSAGE;
my $EMAIL_SENT_ERROR_MESSAGE;
my $ERROR_INVALID_ADDRESS;
my $ERROR_EMPTY_TO_EMAIL;
my $ERROR_EMPTY_FROM_EMAIL;
my $ERROR_NO_PERMISSION_FROM;
my $ERROR_NO_PERMISSION_TO;
my $ERROR_NO_PERMISSION_CC;

=pod

writes a debug message if the $debug flag is set

=cut

sub _debug {
    Foswiki::Func::writeDebug("SendEmailPlugin -- $_[0]")
      if $debug;
}

=pod

some init steps

=cut

sub init {
    my $session = shift;
    $Foswiki::Plugins::SESSION ||= $session;
    my $pluginName = $Foswiki::Plugins::SendEmailPlugin::pluginName;
    $debug = $Foswiki::cfg{Plugins}{$pluginName}{Debug} || 0;
    $emailRE = Foswiki::Func::getRegularExpression('emailAddrRegex');
    initMessageStrings();
}

sub initMessageStrings {
    my $session = shift;

    my $language = Foswiki::Func::getPreferencesValue("LANGUAGE") || 'en';
    my $pluginName = $Foswiki::Plugins::SendEmailPlugin::pluginName;

    $EMAIL_SENT_SUCCESS_MESSAGE =
      $Foswiki::cfg{Plugins}{$pluginName}{Messages}{SentSuccess}{en};
    $EMAIL_SENT_ERROR_MESSAGE =
      $Foswiki::cfg{Plugins}{$pluginName}{Messages}{SentError}{$language};
    $ERROR_INVALID_ADDRESS =
      $Foswiki::cfg{Plugins}{$pluginName}{Messages}{InvalidAddress}{$language};
    $ERROR_EMPTY_TO_EMAIL =
      $Foswiki::cfg{Plugins}{$pluginName}{Messages}{EmptyTo}{$language};
    $ERROR_EMPTY_FROM_EMAIL =
      $Foswiki::cfg{Plugins}{$pluginName}{Messages}{EmptyFrom}{$language};
    $ERROR_NO_PERMISSION_FROM =
      $Foswiki::cfg{Plugins}{$pluginName}{Messages}{NoPermissionFrom}
      {$language};
    $ERROR_NO_PERMISSION_TO =
      $Foswiki::cfg{Plugins}{$pluginName}{Messages}{NoPermissionTo}{$language};
    $ERROR_NO_PERMISSION_CC =
      $Foswiki::cfg{Plugins}{$pluginName}{Messages}{NoPermissionCc}{$language};
}

=pod

Invoked by bin/sendemail

=cut

sub sendEmail {
    my $session = shift;

    _debug("sendEmail");

    init($session);

    my $query        = Foswiki::Func::getCgiQuery();
    my $errorMessage = '';
    my $redirectUrl  = $query->param('redirectto');

    return _finishSendEmail( $session, $ERROR_STATUS{'error'}, undef,
        $redirectUrl )
      unless $query;

    # get TO
    my $to = $query->param('to') || $query->param('To');

    return _finishSendEmail( $session, $ERROR_STATUS{'error'},
        $ERROR_EMPTY_TO_EMAIL, $redirectUrl )
      unless $to;

    my @toEmails = ();
    foreach my $thisTo ( split( /\s*,\s*/, $to ) ) {
        my $addrs;

        if ( $thisTo =~ /$emailRE/ ) {

            # regular address
            $addrs = $thisTo;
        }
        else {

            # get TO user info
            my $wikiName = Foswiki::Func::getWikiName($thisTo);
            my @addrs    = Foswiki::Func::wikinameToEmails($wikiName);
            $addrs = $addrs[0] if @addrs;

            unless ($addrs) {

                # no regular address and no address found in user info

                $errorMessage = $ERROR_INVALID_ADDRESS;
                $errorMessage =~ s/\$EMAIL/$thisTo/go;
                return _finishSendEmail( $session, $ERROR_STATUS{'error'},
                    $errorMessage, $redirectUrl );
            }
        }

        # validate TO
        if (  !_matchesSetting( 'Allow', 'MailTo', $thisTo )
            || _matchesSetting( 'Deny', 'MailTo', $thisTo ) )
        {
            $errorMessage = $ERROR_NO_PERMISSION_TO;
            $errorMessage =~ s/\$EMAIL/$thisTo/go;
            Foswiki::Func::writeWarning($errorMessage);
            return _finishSendEmail( $session, $ERROR_STATUS{'error'},
                $errorMessage, $redirectUrl );
        }

        push @toEmails, $addrs;
    }
    $to = join( ', ', @toEmails );
    _debug("to=$to");

    # get FROM
    my $from = $query->param('from') || $query->param('From');

    unless ($from) {

        # get from user settings
        my $emails = Foswiki::Func::wikiToEmail();
        my @emails = split( /\s*,*\s/, $emails );
        $from = shift @emails if @emails;
    }

    unless ($from) {

        # fallback to webmaster
        $from = $Foswiki::cfg{WebMasterEmail}
          || Foswiki::Func::getPreferencesValue('WIKIWEBMASTER');
    }

    # validate FROM
    return _finishSendEmail( $session, $ERROR_STATUS{'error'},
        $ERROR_EMPTY_FROM_EMAIL, $redirectUrl )
      unless $from;

    if (  !_matchesSetting( 'Allow', 'MailFrom', $from )
        || _matchesSetting( 'Deny', 'MailFrom', $from ) )
    {
        $errorMessage = $ERROR_NO_PERMISSION_FROM;
        $errorMessage =~ s/\$EMAIL/$from/go;
        Foswiki::Func::writeWarning($errorMessage);
        return _finishSendEmail( $session, $ERROR_STATUS{'error'},
            $errorMessage, $redirectUrl );
    }

    unless ( $from =~ m/$emailRE/ ) {
        $errorMessage = $ERROR_INVALID_ADDRESS;
        $errorMessage =~ s/\$EMAIL/$from/go;
        return _finishSendEmail( $session, $ERROR_STATUS{'error'},
            $errorMessage, $redirectUrl );
    }
    _debug("from=$from");

    # get CC
    my $cc = $query->param('cc') || $query->param('CC') || '';

    if ($cc) {
        my @ccEmails = ();
        foreach my $thisCC ( split( /\s*,\s*/, $cc ) ) {
            my $addrs;

            if ( $thisCC =~ /$emailRE/ ) {

                # normal email address
                $addrs = $thisCC;

            }
            else {

                # get from user info
                my $wikiName = Foswiki::Func::getWikiName($thisCC);
                my @addrs    = Foswiki::Func::wikinameToEmails($wikiName);
                $addrs = $addrs[0] if @addrs;

                unless ($addrs) {

                    # no regular address and no address found in user info

                    $errorMessage = $ERROR_INVALID_ADDRESS;
                    $errorMessage =~ s/\$EMAIL/$thisCC/go;
                    return _finishSendEmail( $session, $ERROR_STATUS{'error'},
                        $errorMessage, $redirectUrl );
                }
            }

            # validate CC
            if (  !_matchesSetting( 'Allow', 'MailCc', $thisCC )
                || _matchesSetting( 'Deny', 'MailCc', $thisCC ) )
            {
                $errorMessage = $ERROR_NO_PERMISSION_CC;
                $errorMessage =~ s/\$EMAIL/$thisCC/go;
                Foswiki::Func::writeWarning($errorMessage);
                return _finishSendEmail( $session, $ERROR_STATUS{'error'},
                    $errorMessage, $redirectUrl );
            }

            push @ccEmails, $addrs;
        }
        $cc = join( ', ', @ccEmails );
        _debug("cc=$cc");
    }

    # get SUBJECT
    my $subject = $query->param('subject') || $query->param('Subject') || '';
    _debug("subject=$subject") if $subject;

    # get BODY
    my $body = $query->param('body') || $query->param('Body') || '';
    _debug("body=$body") if $body;

    # get template
    my $templateName = $query->param('mailtemplate')
      || 'SendEmailPluginTemplate';

    # remove 'Template' at end - stupid TWiki solution from the old days
    $templateName =~ s/^(.*?)Template$/$1/;

    my $template = Foswiki::Func::readTemplate($templateName);
    _debug("templateName=$templateName");
    unless ($template) {
        $template = <<'HERE';
From: %FROM%
To: %TO%
CC: %CC%
Subject: %SUBJECT%

%BODY%
HERE
    }
    _debug("template=$template");

    # format email
    my $mail = $template;
    $mail =~ s/%FROM%/$from/go;
    $mail =~ s/%TO%/$to/go;
    $mail =~ s/%CC%/$cc/go;
    $mail =~ s/%SUBJECT%/$subject/go;
    $mail =~ s/%BODY%/$body/go;

    _debug("mail=\n$mail");

    # send email
    $errorMessage = Foswiki::Func::sendEmail( $mail, 1 );

    # finally
    my $errorStatus =
      $errorMessage ? $ERROR_STATUS{'error'} : $ERROR_STATUS{'noerror'};

    return _finishSendEmail( $session, $errorStatus, $errorMessage,
        $redirectUrl );

    return 0;
}

=pod

Renders the SENDEMAIL feedback macro.

=cut

sub handleSendEmailTag {
    my ( $session, $params, $topic, $web ) = @_;

    init();
    _addHeader();

    my $query = Foswiki::Func::getCgiQuery();
    return '' if !$query;

    my $errorStatus = $query->param($ERROR_STATUS_TAG);
    my $errorMessage = $query->param($ERROR_MESSAGE_TAG) || '';

    my $feedbackSuccess = $params->{'feedbackSuccess'};
    my $feedbackError   = $params->{'feedbackError'};
    my $format          = $params->{'format'};

    return '' if !defined $errorStatus;

    _debug(
        "handleSendEmailTag errorStatus=" . _errorStatusMessage($errorStatus) );

    unless ( defined $feedbackSuccess ) {
        $feedbackSuccess = $EMAIL_SENT_SUCCESS_MESSAGE
          || '';
    }
    $feedbackSuccess =~ s/^\s*(.*?)\s*$/$1/go;    # remove surrounding spaces

    unless ( defined $feedbackError ) {
        $feedbackError = $EMAIL_SENT_ERROR_MESSAGE || '';
    }

    my $userMessage =
      ( $errorStatus == $ERROR_STATUS{'error'} )
      ? $feedbackError
      : $feedbackSuccess;

    $userMessage =~ s/^[[:space:]]+//s;           # trim at start
    $userMessage =~ s/[[:space:]]+$//s;           # trim at end

    my $notificationMessage =
      _createNotificationMessage( $userMessage, $errorStatus, $errorMessage,
        defined $format );

    if ($format) {
        $format =~ s/\$message/$notificationMessage/;
        $notificationMessage = $format;
    }
    return _wrapHtmlNotificationContainer($notificationMessage);
}

=pod

Checks if a given value matches a preferences pattern. The pref pattern
actually is a list of patterns. The function returns true if 
at least one of the patterns in the list matches.

=cut

sub _matchesSetting {
    my ( $mode, $key, $value ) = @_;

    my $pluginName = $Foswiki::Plugins::SendEmailPlugin::pluginName;
    my $pattern = $Foswiki::cfg{Plugins}{$pluginName}{Permissions}{$mode}{$key};

    _debug("called _matchesSetting($mode, $key, $value)");
    _debug("matching pattern=$pattern");
    _debug( "mode=" . ( $mode =~ /Allow/i ? 1 : 0 ) );

    if ( $mode =~ /Deny/i && !$pattern ) {

        # no pattern, so noone is denied
        return 0;
    }

    $pattern =~ s/^\s//o;
    $pattern =~ s/\s$//o;
    $pattern = '(' . join( ')|(', split( /\s*,\s*/, $pattern ) ) . ')';

    _debug("final matching pattern=$pattern");

    my $result = ( $value =~ /$pattern/ ) ? 1 : 0;

    _debug("result=$result");

    return $result;
}

=pod

=cut

sub _finishSendEmail {
    my ( $session, $errorStatus, $errorMessage, $redirectUrl ) = @_;

    my $query = Foswiki::Func::getCgiQuery();

    _debug(
        "_finishSendEmail errorStatus=" . _errorStatusMessage($errorStatus) )
      if $errorStatus;
    _debug("_finishSendEmail redirectUrl=$redirectUrl")
      if $redirectUrl;

    $query->param( -name => $ERROR_STATUS_TAG, -value => $errorStatus )
      if $query;

    $errorMessage ||= '';
    _debug("_finishSendEmail errorMessage=$errorMessage;")
      if $errorMessage;

    $query->param( -name => $ERROR_MESSAGE_TAG, -value => $errorMessage )
      if $query;

    my $web     = $session->{webName};
    my $topic   = $session->{topicName};
    my $origUrl = Foswiki::Func::getScriptUrl( $web, $topic, 'view' );

    $query->param( -name => 'origurl', -value => $origUrl );

    my $section = $query->param(
        ( $errorStatus == $ERROR_STATUS{'error'} )
        ? 'errorsection'
        : 'successsection'
    );

    $query->param( -name => 'section', -value => $section )
      if $section;

    $redirectUrl ||= $origUrl;
    $redirectUrl = "$redirectUrl#$NOTIFICATION_ANCHOR_NAME";

    Foswiki::Func::redirectCgiQuery( undef, $redirectUrl, 1 );
    return 0;
}

=pod

=cut

sub _addHeader {

    my $header = <<'EOF';
<style type="text/css" media="all">
@import url("%PUBURL%/%SYSTEMWEB%/SendEmailPlugin/sendemailplugin.css");
</style>
EOF
    Foswiki::Func::addToHEAD( 'SENDEMAILPLUGIN', $header );
}

=pod

=cut

sub _createNotificationMessage {
    my ( $text, $errorStatus, $errorMessage, $customFormat ) = @_;

    if ($customFormat) {
        return "$text $errorMessage";
    }

    my $cssClass = $NOTIFICATION_CSS_CLASS;
    $cssClass .= ' ' . $NOTIFICATION_ERROR_CSS_CLASS
      if ( $errorStatus == $ERROR_STATUS{'error'} );

    return CGI::div( { class => $cssClass }, "$text $errorMessage" );
}

=pod

=cut

sub _wrapHtmlNotificationContainer {
    my ($notificationMessage) = @_;

    return CGI::a( { name => $NOTIFICATION_ANCHOR_NAME }, '<!--#-->' ) . "\n"
      . $notificationMessage;
}

sub _errorStatusMessage {
    my ($errorStatus) = @_;

    return $ERROR_STATUS_MESSAGE{$errorStatus};
}

1;
