
package Foswiki::Plugins::GitPlugin::GitAction;

# Always use strict to enforce variable scoping
use strict;

sub handleGitConfirm {
    my ( $cnt, $attr ) = @_;
    my $session = $Foswiki::Plugins::SESSION;

    my $confirmButton = " <form action=\""
      . &Foswiki::Func::getScriptUrl( $session->{webName},
        $session->{topicName}, 'gitop' )
      . "\" /><input type=\"hidden\" name=\"nr\" value=\"$cnt\" /><input type=\"hidden\" name=\"opertype\" value=\"confirm\" /><input type=\"submit\" value=\"Confirm\" /></form>";

    my $warning_start =
qq#<div class="foswikiBroadcastMessage">$confirmButton<img src="/pub/System/DocumentGraphics/warning.gif" alt="ALERT!" title="ALERT!" border="0" height="16" width="16"> <strong> #;

    my $warning_content =
      qq#Merge Conflict. Please CONFIRM the content and attachment.#;

    my $warning_end = qq#</strong> </div>#;

    return $warning_start . $warning_content . $warning_end;
}

sub handleGitOption {
    my ( $cnt, $attr ) = @_;
    $attr =~ s#"##go;

    my $session = $Foswiki::Plugins::SESSION;

    my $OptionButton = " <form action=\""
      . &Foswiki::Func::getScriptUrl( $session->{webName},
        $session->{topicName}, 'gitop' )
      . "\" /><input type=\"hidden\" name=\"lo\" value=\"$attr\" /><input type=\"hidden\" name=\"opertype\" value=\"option\" /><input type=\"hidden\" name=\"nr\" value=\"$cnt\" /><input type=\"submit\" value=\"Select\" /></form>";

    my $warning;
    if ( ( $attr eq "START" ) or ( $attr eq "SELECT" ) ) {
        return '';
    }
    elsif ( $attr eq "END" ) {
        $warning = qq#<div><strong>CONFLICT end</strong></div>#;
        return $warning;
    }
    else {
        my $warning =
          qq#<div>$OptionButton<strong>CONFLICT version $attr:</strong></div>#;
        return $warning;
    }
}

sub oper {
    my $session = shift;
    $Foswiki::Plugins::SESSION = $session;
    my $query = Foswiki::Func::getCgiQuery();
    return unless ($query);

    my $cnt    = $query->param('nr');
    my $action = $query->param('opertype');

    my $webName = $session->{webName};
    my $topic   = $session->{topicName};
    my $user    = $session->{user};

    return
      unless (
        &doEnableEdit( $webName, $topic, $user, $query, 'editTableRow' ) );

    my ( $meta, $text ) = &Foswiki::Func::readTopic( $webName, $topic );

    if ( $action eq "confirm" ) {
        $text =~
          s/%GITCONFIRM(?:{(.*?)})?%/&removeConfirm($cnt--, $user, $1)/geo;
    }
    elsif ( $action eq "option" ) {
        $text =~ s/%GITOPTION{(.*?)}%/&replaceOption($cnt--, $1)/geo;

        $text = &option($text);
    }
    else {
        return "error: unkown action";
    }

#force new revision to store the topic before merge( local or remote which is latest
#my $error = &Foswiki::Func::saveTopicText( $webName, $topic, $meta, $text );
    my $error =
      &Foswiki::Func::saveTopic( $webName, $topic, $meta, $text,
        { forcenewrevision => 1 } );

    Foswiki::Func::setTopicEditLock( $webName, $topic, 0 );    # unlock Topic
    if ($error) {
        Foswiki::Func::redirectCgiQuery( $query, $error );
        return 0;
    }
    else {

        # and finally display topic
        Foswiki::Func::redirectCgiQuery( $query,
            &Foswiki::Func::getViewUrl( $webName, $topic ) );
    }

}

sub removeConfirm {
    my ( $dont, $user, $attr ) = @_;

    return "";
}

sub replaceOption {
    my ( $dont, $attr ) = @_;

    return ( ($attr) ? "%GITOPTION{$attr}%" : '%GITOPTION%' ) if $dont;

    return "%GITOPTION{\"SELECT\"}%";
}

sub option {
    my $text = shift;
    my $result;
    my @para;
    my $sig;

    while ( $text =~ m/^(.*?)(%GITOPTION{"(.*?)"}%)(.*)/s ) {
        my $op = $3;
        if ( ( $op eq "START" ) or ( $op eq "END" ) ) {
            push @para, $1;
            push @para, $2;
            $text = $4;
        }
        elsif ( $op eq "SELECT" ) {
            push @para, $1;
            push @para, $2;
            $sig  = $#para;
            $text = $4;
        }
        else {
            push @para, $1;
            push @para, $2;
            $text = $4;
        }
    }
    push @para, $text;

    my ( $i, $j, $k );

    #use to match START & END, to decide which content we are want.
    my $match = 0;

    #search START
    for ( $i = $sig - 1 ; $i >= 0 ; --$i ) {
        if ( $para[$i] =~ m/%GITOPTION{"START"}%/ ) {
            last unless $match;
            --$match;
        }
        elsif ( $para[$i] =~ m/%GITOPTION{"END"}%/ ) {
            ++$match;
        }
    }

    #search END
    $match = 0;
    for ( $j = $sig + 1 ; $j < $#para + 1 ; ++$j ) {
        if ( $para[$j] =~ m/%GITOPTION{"END"}%/ ) {
            last unless $match;
            --$match;
        }
        elsif ( $para[$j] =~ m/%GITOPTION{"START"}%/ ) {
            ++$match;
        }
    }

    #search content
    $match = 0;
    for ( $k = $sig + 1 ; $k < $j + 1 ; ++$k ) {
        if ( $para[$k] =~ m/%GITOPTION{"(.*?)"}/ ) {
            ++$match if ( $1 eq "START" );
            last     if ( $match == 0 );
            --$match if ( $1 eq "END" );
        }
    }

    for ( my $m = 0 ; $m < $i ; ++$m ) {
        $result .= $para[$m];
    }

    for ( my $m = $sig + 1 ; $m < $k ; ++$m ) {
        $result .= $para[$m];
    }

    for ( my $m = $j + 1 ; $m < $#para + 1 ; ++$m ) {
        $result .= $para[$m];
    }

    return $result;

}

sub doEnableEdit {
    my ( $theWeb, $theTopic, $user, $query ) = @_;

    if (
        !&Foswiki::Func::checkAccessPermission(
            "change", $user, "", $theTopic, $theWeb
        )
      )
    {

        # user does not have permission to change the topic
        throw Foswiki::OopsException(
            'accessdenied',
            def   => 'topic_access',
            web   => $_[2],
            topic => $_[1],
            params =>
              [ 'Edit topic', 'You are not permitted to edit this topic' ]
        );
        return 0;
    }

    ## SMELL: Update for =checkTopicEditLock=
    my ( $oopsUrl, $lockUser ) =
      &Foswiki::Func::checkTopicEditLock( $theWeb, $theTopic, 'edit' );
    if ( $lockUser
        && !( $lockUser eq Foswiki::Func::getCanonicalUserID($user) ) )
    {

        # warn user that other person is editing this topic
        &Foswiki::Func::redirectCgiQuery( $query, $oopsUrl );
        return 0;
    }
    Foswiki::Func::setTopicEditLock( $theWeb, $theTopic, 1 );

    return 1;
}

1;
