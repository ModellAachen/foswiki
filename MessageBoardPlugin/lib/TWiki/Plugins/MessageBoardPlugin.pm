# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004 Luis Campos de Carvalho, monsieur_champs@yahoo.com.br
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

# =========================
package TWiki::Plugins::MessageBoardPlugin;
use strict;
use warnings;
use DBI;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug %db %i18nMessage %color
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'MessageBoardPlugin';

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    # Get plugin color settings
    %color =
      map { $_->[0] => &TWiki::Func::getPreferencesValue( $_->[1] ) } (
        [ TABLE_HEAD   => "\U$pluginName\E_TABLE_HEAD_COLOR" ],
        [ REVERSE_LINE => "\U$pluginName\E_REVERSE_LINE_COLOR" ],
      );

    # Get plugin messages (so you can internationalize and customize
    # them at will )
    %i18nMessage =
      map { $_->[0] => &TWiki::Func::getPreferencesValue( $_->[1] ) } (
        [ DB_CONNECT_ERROR => "\U$pluginName\E_MSG_DB_CONNECT_ERROR" ],
        [ DB_CLOSE_ERROR   => "\U$pluginName\E_MSG_DB_CLOSE_ERROR" ],
        [ DB_PREPARE_ERROR => "\U$pluginName\E_MSG_DB_PREPARE_ERROR" ],
        [ DB_FETCH_ERROR   => "\U$pluginName\E_MSG_DB_FETCH_ERROR" ],
        [ DB_EXECUTE_ERROR => "\U$pluginName\E_MSG_DB_EXECUTE_ERROR" ],
        [ DB_NO_DATA_ERROR => "\U$pluginName\E_MSG_DB_NO_DATA_ERROR" ],
        [ DB_UPDATE_ERROR  => "\U$pluginName\E_MSG_DB_UPDATE_ERROR" ],
        [ DB_INSERT_ERROR  => "\U$pluginName\E_MSG_DB_INSERT_ERROR" ],
      );

    # Get plugin database meta-data
    %db =
      map { $_->[0] => &TWiki::Func::getPreferencesValue( $_->[1] ) } (
        [ driver   => "\U$pluginName\E_DB_DRIVER" ],
        [ host     => "\U$pluginName\E_DB_SERVER" ],
        [ port     => "\U$pluginName\E_DB_SERVER_PORT" ],
        [ database => "\U$pluginName\E_DB_DATABASE" ],
        [ table    => "\U$pluginName\E_DB_TABLE" ],
        [ user     => "\U$pluginName\E_DB_USER" ],
        [ passwd   => "\U$pluginName\E_DB_PASSWORD" ],
      );

    $db{dbh} = eval {
        DBI->connect( 'dbi:'
              . $db{driver}
              . ':database='
              . $db{database}
              . ';hostname='
              . $db{host}
              . ';port='
              . $db{port},
            $db{user}, $db{passwd}, { RaiseError => 1, PrintError => 0 } );
    };
    $db{connection_error} = $@ if $@;

# Plugin correctly initialized
# TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler {
    ### my ( $text, $topic, $web ) = @_;
    # do not uncomment, use $_[0], $_[1]... instead

# TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )") if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    $_[0] =~ s/(%MESSAGE_BOARD(?:{[^}]+})?%)/&board($1)/ge;
}

# =========================
sub display {
    my $msgOrder = shift;

    my $sth = eval {
        $db{dbh}->prepare(
            q{ SELECT id
                               , author
                               , DATE_FORMAT( due, '%T<br />%d/%m/%Y' ) as due
                               , DATE_FORMAT( posted, '%T<br />%d/%m/%Y' ) as posted
                               , msg
			  FROM message
			  WHERE dropped = 'N'
			  AND due >= NOW()
			  ORDER BY id
			} . uc $msgOrder
        );
    };
    return $i18nMessage{DB_PREPARE_ERROR} . ": $@." if $@;
    eval { $sth->execute; };
    return $i18nMessage{DB_EXECUTE_ERROR} . ": $@." if $@;
    my $result = eval { $sth->fetchall_arrayref( {} ); };
    return $i18nMessage{DB_FETCH_ERROR} . ": $@." if $@;

    my $trash_icon = &TWiki::Func::expandCommonVariables(
        &TWiki::Func::getPreferencesValue(
            "\U$pluginName\E_TRASH_CAN_ICON_LINK"),
        $topic, $web
    );
    my $pencil_icon =
      &TWiki::Func::expandCommonVariables(
        &TWiki::Func::getPreferencesValue("\U$pluginName\E_PENCIL_ICON_LINK"),
        $topic, $web );

    # Build Message Board Table and return it.
    return qq{<table align="center" border="1" cellpadding="5" cellspacing="0">
  <tr valign="middle" align="center" bgcolor="$color{TABLE_HEAD}">
    <td> <b> Due&nbsp;Date </b> </td>
    <td> <b> Posted&nbsp;Date </b> </td>
    <td> <b> Author </b> </td>
    <td> <b> Drop &amp;<br />Change </b> </td>
    <td> <b> Message </b> </td>
  </tr> }
      . (
        $result
        ? join "\n",
        map( '<tr valign="top" align="center"><td>'
              . $_->{due}
              . '</td><td>'
              . $_->{posted}
              . '</td><td> '
              . $_->{author}
              . ' </td><td><a href="'
              . &TWiki::Func::getViewUrl( $web, $topic )
              . '?message_id='
              . $_->{id}
              . ';action=edit">'
              . $pencil_icon
              . '</a><a href="'
              . &TWiki::Func::getViewUrl( $web, $topic )
              . '?message_id='
              . $_->{id}
              . ';action=remove">'
              . $trash_icon
              . '</a></td><td align="left">'
              . $_->{msg}
              . '</td></tr>',
            @$result )
        : $i18nMessage{DB_NO_DATA_ERROR}
      ) . '</table>';
}

sub inputBox {

    # Don't uncomment, use @_ instead
    #   my $action_url = shift; # $_[0]
    #   my $msgid      = shift; # $_[1]
    #   my $action     = shift; # $_[2]
    return qq{<form action="$_[0]" method="post">\n}
      . (
        $_[1]
        ? qq{  <input type="hidden" name="message_id" value="$_[1]" />\n}
        : ''
      )
      . qq{  <input type="hidden" name="action" value="$_[2]" />
  <input type="hidden" name="commit" value="1" />
  <table align="center" border="1" cellpadding="5" cellspacing="0">
    <tr valign="middle" align="center" bgcolor="$color{TABLE_HEAD}">
      <td colspan="2"> <b>}
      . ( $_[2] eq 'edit' ? "Edit Message #$_[1]" : 'Compose New Message' )
      . qq{ </b> </td>
    </tr>
    <tr valign="middle" align="left" >
      <td> Author: </td>
      <td>
}
      . (
        $_[2] eq 'edit'
        ? q{        <input type="text" name="author" size="40" }
          . (
            $_[3] ? qq{value="$_[3]->{author}"} : &TWiki::Func::getWikiName() )
          . qq{ />}
        : &TWiki::Func::getWikiName()
      )
      . q{
      </td>
    </tr>
    <tr valign="middle" align="left">
      <td>Due Date: </td>
      <td>}
      . &gen_date_selector(
        'due',
        (
            $_[3]
            ? @{ $_[3] }{ 'day', 'month', 'year', 'hour', 'minute' }
            : (localtime)[3],
            (localtime)[4] + 1,
            (localtime)[5] + 1900,
            23,
            59
        )
      )
      . qq{
      </td>
    </tr>
    <tr valign="middle" align="left">
      <td>Message: </td>
      <td>
        <textarea rows="5" name="msg" cols="50">}
      . ( $_[3] ? $_[3]->{msg} : '' ) . qq{</textarea>
      </td>
    </tr>
    <tr valign="middle" align="left">
      <td>
        <input type="checkbox" name="dropped" value="Y" }
      . ( $_[3] && $_[3]->{dropped} eq 'Y' ? 'CHECKED' : '' )
      . q{>&nbsp;Dropped.
      </td>
      <td align="right">
        }
      . (
        $_[2] eq 'edit'
        ? qq{<a href="$_[0]">Cancel Edition</a> &nbsp;&nbsp;&nbsp; }
        : ''
      )
      . qq{<input type="submit" name="change" value="}
      . ( $_[2] eq 'edit' ? 'Change' : 'Post' )
      . q{ Message">
      </td>
    </tr>
  </table>
</form>
};
}

# =========================
sub board {

    # Deal with database errors
    if ( !$db{dbh} && $db{connection_error} ) {
        return $i18nMessage{DB_CONNECT_ERROR} . ": " . $db{connection_error};
    }

    # Recover tag, extract parameters
    # my $tag = shift;
    my ( $displayOnly, $messageOrder ) = (
        &TWiki::Func::extractNameValuePair( $_[0], 'displayOnly' ),
        &TWiki::Func::extractNameValuePair( $_[0], 'messageOrder' ) || 'ASC'
    );

    my $q = &TWiki::Func::getCgiQuery();

    my $msgid  = $q->param('message_id');
    my $action = $q->param('action');

    if ( $action eq 'remove' ) {
        ##################################################
        # Remove action
        ##################################################
        eval {
            $db{dbh}->do(
                q{ UPDATE message
		       SET dropped = 'Y'
		       WHERE id = ? },
                { RaiseError => 1 },
                $msgid
            );
        };
        return $i18nMessage{DB_EXECUTE_ERROR} . ': ' . $db{dbh}->errstr if $@;

    }
    elsif ( $action eq 'edit' ) {
        ##################################################
        # Edit Action
        ##################################################
        if ( $q->param('commit') ) {
            ##################################################
            # Commit previous started edition
            ##################################################
            eval {
                $db{dbh}->do(    # DBI::do( $sql, \%attr, @bind )
                    q{UPDATE message
			   SET author  = ?
			     , due     = ?
			     , msg     = ?
			     , dropped = ?
			   WHERE id = ?},
                    { RaiseError => 1 },
                    $q->param('author'),
                    sprintf(
                        '%04d-%02d-%02d %02d:%02d:00',
                        map( $q->param($_),
                            qw( due_year due_month due_day
                              due_hour due_minute ) )
                    ),
                    $q->param('msg'),
                    $q->param('dropped') ? 'Y' : 'N',
                    $msgid
                );
            };
            return $i18nMessage{DB_UPDATE_ERROR} . ': ' . $@ if $@;
        }
        else {
            ##################################################
            # Start new edition
            ##################################################
            my $data;

            # recover data from existing record...
            eval {
                my $sth = $db{dbh}->prepare(    # DBI::prepare( $sql )
                    q{SELECT author
				           , EXTRACT(DAY FROM due) AS day
				           , EXTRACT(MONTH FROM due) AS month
				           , EXTRACT(YEAR FROM due) AS year
				           , EXTRACT(HOUR FROM due) AS hour
				           , EXTRACT(MINUTE FROM due) AS minute
				           , msg
				           , dropped
				      FROM message
				      WHERE id = ?}
                );
                my $result = $sth->execute($msgid);    # DBI::execute( @bind )
                $data = $sth->fetchrow_hashref();
            };
            return $i18nMessage{DB_FETCH_ERROR} . ': ' . $@ if $@;

            # Build HTML
            return &inputBox( &TWiki::Func::getViewUrl( $web, $topic ),
                $msgid, 'edit', $data );
        }
    }
    elsif ( $action eq 'new' ) {
        ##################################################
        # Post New Message
        ##################################################
        if ( $q->param('commit') ) {
            ##################################################
            # Commit previous started edition
            ##################################################
            eval {
                $db{dbh}->do(    # DBI::do( $sql, \%attr, @bind )
                    q{INSERT INTO message( author, due, posted, msg, dropped )
		       VALUES( ?, ?, NOW(), ?, ? ) },
                    { RaiseError => 1 },
                    &TWiki::Func::getWikiName(),
                    sprintf(
                        '%04d-%02d-%02d %02d:%02d:00',
                        map( $q->param($_),
                            qw( due_year due_month due_day
                              due_hour due_minute ) )
                    ),
                    $q->param('msg'),
                    $q->param('dropped') ? 'Y' : 'N',
                );
            };
            return $i18nMessage{DB_INSERT_ERROR} . ': ' . $@ if $@;
        }
    }

    ##################################################
    # Execute display action
    ##################################################
    return
        '<table align="center" border="0" cellpadding="0" cellspacing="2">'
      . '<tr align="center">' . '<td>'
      . &display($messageOrder)
      . '</td></tr>'
      . (
        $displayOnly ? '' : '<tr align="center"><td>'
          . &inputBox( &TWiki::Func::getViewUrl( $web, $topic ),
            undef, 'new', undef )
          . '</td></tr>'
      ) . '</table>';
}

sub gen_date_selector {

    # my $name = shift;
    # # Those are for the 'selected' HTML tag:
    # my $ref_day = shift;    # numeric current day (1..31)
    # my $ref_month = shift;  # numeric current month (1..12)
    # my $ref_year = shift;   # numeric current year (0..MAX_BIGINT)
    # my $ref_hour = shift;   # numeric current hour (0..23)
    # my $ref_minute = shift; # numeric current minute (0..59)
    join '', (
        qq{<select name="$_[0]_day">\n },
        (

            # generate day 'option' tags
            map {
                my $d = sprintf '%02d', $_;
                qq'<option value="$d"'
                  . ( $d == $_[1] ? ' selected' : '' )
                  . ">$d</option>\n";
              } 1 .. 31
        ),
        qq{ </select> / <select name="$_[0]_month">\n},
        (

            # generate month 'option' tags
            map {
                my $m = sprintf '%02d', $_;
                qq'<option value="$m"'
                  . ( $m == $_[2] ? ' selected' : '' )
                  . ">$m</option>\n";
              } 1 .. 12
        ),
        qq{ </select> / <select name="$_[0]_year">\n},
        (

            # generate year 'option' tags
            map {
                my $y = sprintf '%04d', $_;
                qq'<option value="$y"'
                  . ( $y == $_[3] ? ' selected' : '' )
                  . ">$y</option>\n";
              } ( (localtime)[5] + 1900 ) .. ( (localtime)[5] + 1902 )
        ),
        qq{</select>&nbsp;<select name="$_[0]_hour">},
        (

            # generate hour 'option' tags
            map {
                my $h = sprintf '%02d', $_;
                qq'<option value="$h"'
                  . ( $h == $_[4] ? ' selected' : '' )
                  . ">$h</option>\n";
              } 0 .. 23
        ),
        qq{</select>:<select name="$_[0]_minute">},
        (

            # generate minute 'option' tags
            map {
                my $m = sprintf '%02d', $_;
                qq'<option value="$m"'
                  . ( $m == $_[5] ? ' selected' : '' )
                  . ">$m</option>\n";
              } 0 .. 59
        ),
        qq{</select>:00},
    );
}
1;
