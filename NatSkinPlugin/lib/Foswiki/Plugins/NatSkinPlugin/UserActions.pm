###############################################################################
# NatSkinPlugin.pm - Plugin handler for the NatSkin.
# 
# Copyright (C) 2003-2011 MichaelDaum http://michaeldaumconsulting.com
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
###############################################################################

package Foswiki::Plugins::NatSkinPlugin::UserActions;
use strict;
use Foswiki::Func ();
use Foswiki::Meta ();
use Foswiki::Plugins ();
use Foswiki::Plugins::NatSkinPlugin::ThemeEngine ();
use Foswiki::Plugins::NatSkinPlugin::Utils ();

###############################################################################
sub render {
  my ($session, $params, $topic, $web) = @_;

  my $baseTopic = $session->{topicName};
  my $baseWeb = $session->{webName};
  my $sepString = $params->{sep} || $params->{separator} || '<span class="natSep"> | </span>';

  my $header = $params->{header} || '';
  my $footer = $params->{footer} || '';
  
  my $text = $params->{_DEFAULT} || $params->{format};
  $text = '$edit$sep$attach$sep$new$sep$raw$sep$delete$sep$history$sepprint$sep$more'
    unless defined $text;

  my $guestText = $params->{guest};
  $guestText = '$login$sep$register' 
    unless defined $guestText;

  $text = $guestText unless Foswiki::Func::getContext()->{authenticated};

  my $themeEngine = Foswiki::Plugins::NatSkinPlugin::ThemeEngine::getThemeEngine();
  if ($themeEngine->{skinState}{"history"}) {
    my $historyText = $params->{history};
    $text = $historyText if defined $historyText;
  }

  return '' unless $text;

  # params used by all actions
  my $actionParams = ();

  $actionParams->{topic} = $topic;
  $actionParams->{web} = $web;
  $actionParams->{baseTopic} = $baseTopic;
  $actionParams->{baseWeb} = $baseWeb;
  $actionParams->{menu} = $params->{menu};
  $actionParams->{menu_header} = $params->{menu_header};
  $actionParams->{menu_footer} = $params->{menu_footer};
  $actionParams->{hiderestricted} = Foswiki::Func::isTrue($params->{hiderestricted}, 0);

  # get restrictions
  my $restrictedActions = $params->{restrictedactions};
  $restrictedActions = 'edit, attach, move, delete, diff, more, raw'
    unless defined $restrictedActions;
  %{$actionParams->{isRestrictedAction}} = map { $_ => 1 } split(/\s*,\s*/, $restrictedActions);

  # a guest can't subscribe to changes
  if (Foswiki::Func::isGuest()) {
    $actionParams->{isRestrictedAction}{'subscribe'} = 1;
  }

  # list all actions that need edit rights
  if ($actionParams->{isRestrictedAction}{'edit'}) {
    $actionParams->{isRestrictedAction}{'attach'} = 1;
    $actionParams->{isRestrictedAction}{'delete'} = 1;
    $actionParams->{isRestrictedAction}{'editform'} = 1;
    $actionParams->{isRestrictedAction}{'editsettings'} = 1;
    $actionParams->{isRestrictedAction}{'editraw'} = 1;
    $actionParams->{isRestrictedAction}{'editformsettings'} = 1;
    $actionParams->{isRestrictedAction}{'edittext'} = 1;
    $actionParams->{isRestrictedAction}{'harvest'} = 1;
    $actionParams->{isRestrictedAction}{'webdavdir'} = 1;
    $actionParams->{isRestrictedAction}{'move'} = 1;
    $actionParams->{isRestrictedAction}{'restore'} = 1;
  }

  # if you've got access to this topic then all actions are allowed
  my $wikiName = Foswiki::Func::getWikiName();
  my $gotAccess = Foswiki::Func::checkAccessPermission('CHANGE', $wikiName, undef, $baseTopic, $baseWeb);
  $actionParams->{isRestrictedAction} = () if $gotAccess;

  # disable registration
  unless (Foswiki::Func::getContext()->{registration_enabled}) {
    $actionParams->{isRestrictedAction}{'register'} = 1;
  }

  my $request = Foswiki::Func::getCgiQuery();
  $actionParams->{isRaw} = ($request) ? $request->param('raw') : '';

  my $isCompare = ($themeEngine->{skinState}{'action'} eq 'compare')?1:0;
  my $isRdiff = ($themeEngine->{skinState}{'action'} eq 'rdiff')?1:0;
  $actionParams->{action} = 'view';
  $actionParams->{action} = 'compare' if $isCompare;
  $actionParams->{action} = 'rdiff' if $isRdiff;

  $actionParams->{renderMode} = ($request) ? $request->param('render') : '';
  $actionParams->{renderMode} = $isCompare ? 'interweave' : 'sequential' 
    unless $actionParams->{renderMode};

  # menu can contain actions. so it goes first
  $text =~ s/\$menu/renderMenu($actionParams)/ge;

  # special actions
  $text =~ s/\$(?:editform\b|action\(editform(?:,\s*(.*?))?\))/renderEditForm($actionParams, $1)/ge;
  $text =~ s/\$(?:account\b|action\(account(?:,\s*(.*?))?\))/renderAccount($actionParams, $1)/ge;
  $text =~ s/\$(?:diff\b|action\(diff(?:,\s*(.*?))?\))/renderDiff($actionParams, $1)/ge;
  $text =~ s/\$(?:edit\b|action\(edit(?:,\s*(.*?))?\))/renderEdit($actionParams, $1)/ge;
  $text =~ s/\$(?:first\b|action\(first(?:,\s*(.*?))?\))/renderFirst($actionParams, $1)/ge;
  $text =~ s/\$(?:last\b|action\(last(?:,\s*(.*?))?\))/renderLast($actionParams, $1)/ge;
  $text =~ s/\$(?:login\b|action\(login(?:,\s*(.*?))?\))/renderLogin($actionParams, $1)/ge;
  $text =~ s/\$(?:next\b|action\(next(?:,\s*(.*?))?\))/renderNext($actionParams, $1)/ge;
  $text =~ s/\$(?:prev\b|action\(prev(?:,\s*(.*?))?\))/renderPrev($actionParams, $1)/ge;
  $text =~ s/\$(?:raw\b|action\(raw(?:,\s*(.*?))?\))/renderRaw($actionParams, $1)/ge;
  $text =~ s/(\$sep)?\$(?:logout\b|action\(logout(?:,\s*(.*?))?\))/renderLogout($actionParams, $1, $2)/ge;

  # normal actions / backwards compatibility
  $text =~ s/\$(attach|copytopic|delete|editsettings|edittext|help|history|more|move|new|pdf|print|register|restore|users)\b/renderAction($1, $actionParams)/ge;

  # generic actions
  $text =~ s/\$action\((.*?)(?:,\s*(.*?))?\)/renderAction($1, $actionParams, undef, undef, $2)/ge;

  # action urls
  $text =~ s/\$diffurl\b/getDiffUrl($actionParams)/ge;
  $text =~ s/\$editurl\b/getEditUrl($actionParams)/ge;
  $text =~ s/\$restoreurl\b/getRestoreUrl($actionParams)/ge;
  $text =~ s/\$firsturl\b/getFirstUrl($actionParams)/ge;
  $text =~ s/\$prevurl\b/getPrevUrl($actionParams)/ge;
  $text =~ s/\$nexturl\b/getNextUrl($actionParams)/ge;
  $text =~ s/\$lasturl\b/getLastUrl($actionParams)/ge;
  $text =~ s/\$helpurl\b/getHelpUrl($actionParams)/ge;
  $text =~ s/\$loginurl\b/getLoginUrl($actionParams)/ge;
  $text =~ s/\$logouturl/getLogoutUrl($actionParams)/ge;
  $text =~ s/\$registerurl/getRegisterUrl($actionParams)/ge;
  $text =~ s/\$pdfurl\b/getPdfUrl($actionParams)/ge;

  $text =~ s/\$sep\b/$sepString/g;
  $text =~ s/\$rev\b/getRev($actionParams)/ge;

  return '' unless $text;

  return Foswiki::Func::decodeFormatTokens($header . $text . $footer);
}

###############################################################################
sub renderAction {
  my ($action, $params, $template, $restrictedTemplate, $context) = @_;

  #print STDERR "called renderAction($action,".($context?"'".$context."'":'').")\n";

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  $template = uc($action)."_ACTION" unless defined $template;
  $restrictedTemplate = uc($action)."_ACTION_RESTRICTED" unless defined $restrictedTemplate;

  if ($params->{isRestrictedAction}{$action}) {
    return '' if $params->{hiderestricted};
    return Foswiki::Func::expandTemplate($restrictedTemplate);
  }

  return Foswiki::Func::expandTemplate($template);
}


###############################################################################
sub renderEdit {
  my ($params, $context) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';
  my $themeEngine = Foswiki::Plugins::NatSkinPlugin::ThemeEngine::getThemeEngine();

  if ($params->{isRestrictedAction}{'edit'}) {
    return '' if $params->{hiderestricted};
    return ($themeEngine->{skinState}{"history"})?
      Foswiki::Func::expandTemplate('RESTORE_ACTION_RESTRICTED'):
      Foswiki::Func::expandTemplate('EDIT_ACTION_RESTRICTED');
  } else {
    return ($themeEngine->{skinState}{"history"})?
      Foswiki::Func::expandTemplate('RESTORE_ACTION'):
      Foswiki::Func::expandTemplate('EDIT_ACTION');
  }

  return $result;
}

###############################################################################
sub getEditUrl {
  my $params = shift;

  my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath("edit", undef, undef, 't' => time(),);
  my $whiteBoard = Foswiki::Func::getPreferencesValue('WHITEBOARD');
  my $editAction = Foswiki::Func::getPreferencesValue('EDITACTION') || '';

  if (!Foswiki::Plugins::NatSkinPlugin::Utils::isTrue($whiteBoard, 1) || $editAction eq 'form') {
    $url .= '&action=form';
  } elsif ($editAction eq 'text') {
    $url .= '&action=text';
  }

  return $url;
}

###############################################################################
sub getRestoreUrl {
  my $params = shift;

  my $themeEngine = Foswiki::Plugins::NatSkinPlugin::ThemeEngine::getThemeEngine();

  my $rev;
  if ($themeEngine->{skinState}{"history"}) {
    $rev = getRev($params);
  } else {
    $rev = getCurRev($params) - 1;
    $rev = 1 if $rev < 1;
  }

  return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
    "edit", undef, undef,
    't' => time(),
    'rev' => $rev
  );
}

###############################################################################
sub renderRaw {
  my ($params, $context) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';

  if ($params->{isRestrictedAction}{'raw'}) {
    return '' if $params->{hiderestricted};
    return ($params->{isRaw})?
      Foswiki::Func::expandTemplate('VIEW_ACTION_RESTRICTED'):
      Foswiki::Func::expandTemplate('RAW_ACTION_RESTRICTED');
  } else {
    return ($params->{isRaw})?
      Foswiki::Func::expandTemplate('VIEW_ACTION'):
      Foswiki::Func::expandTemplate('RAW_ACTION');
  }

  return $result;
}

###############################################################################
sub renderMenu {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'menu'}) {
    return '' if $params->{hiderestricted};
    $result = Foswiki::Func::expandTemplate('MENU_RESTRICTED');
  } else {
    my $menu = $params->{menu};
    my $header = $params->{menu_header};
    my $footer = $params->{menu_footer};
    $menu = Foswiki::Func::expandTemplate('MENU_FORMAT') unless defined $menu;
    $header = Foswiki::Func::expandTemplate('MENU_HEADER') unless defined $header;
    $footer = Foswiki::Func::expandTemplate('MENU_FOOTER') unless defined $footer;
    $result = $header.$menu.$footer;
  }

  return $result;
}

###############################################################################
sub getPdfUrl {

  my $url;
  my $context = Foswiki::Func::getContext();
  if ($context->{GenPDFPrincePluginEnabled} || $context->{GenPDFWebkitPluginEnabled}) {
    $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
      'view',
      undef, undef,
      'contenttype' => 'application/pdf',
      'cover' => 'print',
    );
  } else {

    # SMELL: can't check for GenPDFAddOn reliably; we'd like to
    # default to normal printing if no other print helper is installed
    $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('genpdf', undef, undef, 'cover' => 'print',);
  }
  my $extraParams = Foswiki::Plugins::NatSkinPlugin::Utils::makeParams();
  $url .= ';' . $extraParams if $extraParams;

  return $url;
}

###############################################################################
sub renderEditForm {
  my ($params, $context) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $session = $Foswiki::Plugins::SESSION;
  my ($topicObj) = Foswiki::Func::readTopic($params->{baseWeb}, $params->{baseTopic});
  if ($topicObj && $topicObj->getFormName) {
    if ($params->{isRestrictedAction}{'editform'}) {
      return '' if $params->{hiderestricted};
      return Foswiki::Func::expandTemplate("EDITFORM_ACTION_RESTRICTED");
    }
    return Foswiki::Func::expandTemplate("EDITFORM_ACTION");
  }

  return '';
}

###############################################################################
sub renderAccount {
  my ($params, $context) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';
  my $usersWeb = $Foswiki::cfg{UsersWebName};
  my $wikiName = Foswiki::Func::getWikiName();

  if (Foswiki::Func::topicExists($usersWeb, $wikiName)) {
    $result = Foswiki::Func::expandTemplate('ACCOUNT_ACTION');
  } else {
    $result = Foswiki::Func::expandTemplate('ACCOUNT_ACTION_RESTRICTED');
  }

  return $result;
}

###############################################################################
sub getHelpUrl {
  my $params = shift;

  my $helpTopic = $params->{help} || "UsersGuide";
  my $helpWeb = $Foswiki::cfg{SystemWebName};

  ($helpWeb, $helpTopic) = Foswiki::Func::normalizeWebTopicName($helpWeb, $helpTopic);

  return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', $helpWeb, $helpTopic);
}

###############################################################################
sub renderFirst {
  my ($params, $context) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';

  if ($params->{isRestrictedAction}{'first'} || getCurRev($params) == getNrRev($params)+1) {
    $result = Foswiki::Func::expandTemplate('FIRST_ACTION_RESTRICTION');
  } else {
    $result = Foswiki::Func::expandTemplate('FIRST_ACTION');
  }

  return $result;
}

###############################################################################
sub getFirstUrl {
  my $params = shift;

  if ($params->{action} eq 'view') {
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', undef, undef, 'rev'=>1);
  } else {
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath($params->{action}, undef, undef,
      'rev1'=>(1+getNrRev($params)),
      'rev2'=>1,
      'render'=>$params->{renderMode},
    );
  }
}

###############################################################################
sub renderLogin {
  my ($params, $context) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';

  my $loginUrl = getLoginUrl();
  if ($loginUrl) {
    if ($params->{isRestrictedAction}{'login'}) {
      return '' if $params->{hiderestricted};
      return Foswiki::Func::expandTemplate('LOG_IN_ACTION_RESTRICTED');
    }
    return Foswiki::Func::expandTemplate('LOG_IN_ACTION');
  }

  return $result;
}

###############################################################################
sub getLoginUrl {
  my $session = $Foswiki::Plugins::SESSION;
  return '' unless $session;

  my $loginManager = $session->{loginManager} || # TMwiki-4.2
    $session->{users}->{loginManager} || # TMwiki-4.???
    $session->{client} || # TMwiki-4.0
    $session->{users}->{loginManager}; # Foswiki

  return $loginManager->loginUrl();
}


###############################################################################
sub renderLogout {
  my ($params, $sep, $context) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});


  my $result = '';
  $sep ||= '';

  my $logoutUrl = getLogoutUrl();
  if ($logoutUrl) {
    if ($params->{isRestrictedAction}{'logout'}) {
      return '' if $params->{hiderestricted};
      return $sep.Foswiki::Func::expandTemplate('LOG_OUT_ACTION_RESTRICTED');
    }
    return $sep.Foswiki::Func::expandTemplate('LOG_OUT_ACTION');
  }

  return $result;
}

###############################################################################
sub getLogoutUrl {

  # SMELL: I'd like to do this
  # my $loginManager = $session->{users}->{loginManager};
  # return $loginManager->logoutUrl();
  #
  # but for now the "best" we can do is this:
  my $loginManager = $Foswiki::cfg{LoginManager};
  if ($loginManager =~ /ApacheLogin/) {
    return '';
  } 
  
  return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', undef, undef, logout=>1);
}


###############################################################################
sub getRegisterUrl {

  # SMELL: I'd like to do this
  # my $loginManager = $session->{users}->{loginManager};
  # return $loginManager->registerUrl();
  #
  # but for now the "best" we can do is this:
  return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', $Foswiki::cfg{SystemWebName}, 'UserRegistration');
}


###############################################################################
sub renderLast {
  my ($params, $context) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  return ($params->{isRestrictedAction}{'last'} || getCurRev($params) == getMaxRev($params))?
    Foswiki::Func::expandTemplate('LAST_ACTION_RESTRICTED'):
    Foswiki::Func::expandTemplate('LAST_ACTION');
}

###############################################################################
sub getLastUrl {
  my $params = shift;

  if ($params->{action} eq 'view') {
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', undef, undef, 
      'rev' => getMaxRev($params));
  } else {
    my $rev2 = getMaxRev($params) - getNrRev($params);
    $rev2 = 1 if $rev2 < 1;

    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
      $params->{action}, undef, undef,
      'rev1' => getMaxRev($params),
      'rev2' => $rev2,
      'render' => $params->{renderMode},
    );
  }
}

###############################################################################
sub renderNext {
  my ($params, $context) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  return ($params->{isRestrictedAction}{'next'} || getNextRev($params) > getMaxRev($params))?
    Foswiki::Func::expandTemplate('NEXT_ACTION_RESTRICTED'):
    Foswiki::Func::expandTemplate('NEXT_ACTION');
}

###############################################################################
sub getNextUrl {
  my $params = shift;

  if ($params->{action} eq 'view') {
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', undef, undef, 
      'rev'=>getRev($params) + getNrRev($params)
    );
  } else {
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
      $params->{action}, undef, undef,
      'rev1' => getNextRev($params),
      'rev2' => getCurRev($params),
      'render' => $params->{renderMode},
    );
  }
}

###############################################################################
sub renderPrev {
  my ($params, $context) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  return ($params->{isRestrictedAction}{'prev'} || getPrevRev($params) <= 1)?
    Foswiki::Func::expandTemplate('PREV_ACTION_RESTRICTED'):
    Foswiki::Func::expandTemplate('PREV_ACTION');
}

###############################################################################
sub getPrevUrl {
  my $params = shift;

  if ($params->{action} eq 'view') {
    my $rev = getRev($params) - getNrRev($params);
    $rev = 1 if $rev < 1;
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', undef, undef, 
      'rev'=>$rev
    );
  } else {

    my $rev2 = getPrevRev($params) - getNrRev($params);
    $rev2 = 1 if $rev2 < 1;

    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
      $params->{action}, undef, undef,
      'rev1' => getPrevRev($params),
      'rev2' => $rev2,
      'render' => $params->{renderMode},
    );
  }
}

###############################################################################
sub renderDiff {
  my ($params, $context) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  if ($params->{isRestrictedAction}{'diff'}) {
      return '' if $params->{hiderestricted};
      return Foswiki::Func::expandTemplate('DIFF_ACTION_RESTRICTED');
  }

  return Foswiki::Func::expandTemplate('DIFF_ACTION');
}

###############################################################################
sub getDiffUrl {
  my $params = shift;

  my $rev2 = getCurRev($params) - getNrRev($params);
  $rev2 = 1 if $rev2 < 1;

  my $action = $params->{action};
  if ($action !~ /^(compare|rdiff)$/) {
    my $context = Foswiki::Func::getContext();
    $action = $context->{CompareRevisionsAddonPluginEnabled} ? "compare" : "rdiff";
  }
  return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
    $action, undef, undef,
    'rev1' => getCurRev($params),
    'rev2' => $rev2,
    'render' => $params->{renderMode},
  );

}

###############################################################################
sub getMaxRev {
  my $params = shift;

  unless (defined $params->{maxRev}) {
    $params->{maxRev} = Foswiki::Plugins::NatSkinPlugin::Utils::getMaxRevision();
  }

  return $params->{maxRev};
}

###############################################################################
sub getCurRev {
  my $params = shift;

  unless (defined $params->{curRev}) {
    $params->{curRev} =
         Foswiki::Plugins::NatSkinPlugin::Utils::getCurRevision()
      || getMaxRev($params)
      || 1;
  }

  return $params->{curRev};
}

###############################################################################
sub getRev {
  my $params = shift;

  unless (defined $params->{rev}) {
    my $request = Foswiki::Func::getCgiQuery();
    if ($request) {
      my $rev = $request->param('rev');
      my $rev1 = $request->param('rev1');
      my $rev2 = $request->param('rev2');

      if (defined($rev)) {
        $params->{rev} = $rev;
      } elsif (!defined($rev1) && !defined($rev2)) {
        $params->{rev} = getCurRev($params) unless defined $rev1;
      } else {
        $rev1 ||= 1;
        $rev2 ||= 1;
        $params->{rev} = $rev1 > $rev2 ? $rev1 : $rev2;
      }
    }
  }

  return $params->{rev};
}

###############################################################################
sub getNrRev {
  my $params = shift;

  unless (defined $params->{nrRev}) {
    my $request = Foswiki::Func::getCgiQuery();
    if ($request) {
      my $rev1 = $request->param('rev1') || 1;
      my $rev2 = $request->param('rev2') || 1;
      $params->{nrRev} = abs($rev1 - $rev2);
    }
    #$params->{nrRev} = $Foswiki::cfg{NumberOfRevisions} unless $params->{nrRev};
    $params->{nrRev} = 1 unless $params->{nrRev};
  }

  return $params->{nrRev};
}

###############################################################################
sub getPrevRev {
  my $params = shift;

  unless (defined $params->{prevRev}) {
    $params->{prevRev} = getCurRev($params) - getNrRev($params);
    $params->{prevRev} = 1 if $params->{prevRev} < 1;
  }

  return $params->{prevRev};
}

###############################################################################
sub getNextRev {
  my $params = shift;

  unless (defined $params->{nextRev}) {
    $params->{nextRev} = getCurRev($params) + getNrRev($params);
  }

  return $params->{nextRev};
}

1;
