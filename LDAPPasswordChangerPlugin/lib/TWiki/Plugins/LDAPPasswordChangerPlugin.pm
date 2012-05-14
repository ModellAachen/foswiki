# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyleft (C) 2004 Luis Campos, monsieur_champs@yahoo.com.br
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
package TWiki::Plugins::LDAPPasswordChangerPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $ldap_server $base_dn $filter
);

# Forward declaration for subs;
sub initPlugin;
sub commonTagsHandler;
sub pwChanger;
sub talkToLDAP;
sub genDialog;

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'LDAPPasswordChangerPlugin';

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

    # Get LDAP Server Domain Name or IP Address
    $ldap_server =
      &TWiki::Func::getPreferencesValue("\U$pluginName\E_LDAP_SERVER");
    $base_dn =
      &TWiki::Func::getPreferencesValue("\U$pluginName\E_LDAP_BASE_DN");

# $filter = sprintf( &TWiki::Func::getPreferencesValue( "\U$pluginName\E_LDAP_FILTER" ), TWiki::Func::wikiToUserName( TWiki::Func::getWikiName( ) ) );
    $filter =
      TWiki::Func::expandCommonVariables(
        TWiki::Func::getPreferencesValue("\U$pluginName\E_LDAP_FILTER"),
        $topic, $web );

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub commonTagsHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    $_[0] =~ s/%LDAPPASSWORDCHANGER%/&pwChanger()/ge;
}

# =========================
sub pwChanger {
    my ( $cgi, $message ) = ( TWiki::Func::getCgiQuery(), undef );
    my ( $old, $new, $repeat, $change ) = map $cgi->param($_),
      qw( oldpwd newpwd1 newpwd2 change );

    if ($old) {

        # Got old password.
        if ($new) {

            # Got New Password.
            if ($repeat) {

                # Got new password repeat.
                if ( $new == $repeat ) {

                    # Same password entered twice: I can safely change.
                    $message = talkToLDAP( $old, $new );
                }
                else {

                    # User can't repeat new password: there is something wrong.
                    $message =
q"%X% %RED%'New Password' and 'Repeat New Password' fields doesn't match.%ENDCOLOR%";
                }
            }
            else {

                # Error: New Password Repeat field is empty;
                $message =
                  q{%X% %RED%Please fill in your new password twice.%ENDCOLOR%};
            }
        }
        else {

            # Error: New Password field is empty.
            $message = q{%X% %RED%Please fill in your new password.%ENDCOLOR%};
        }
    }
    else {

        # Error: Empty old password.
        $message = q{%X% %RED%Please fill in your old password.%ENDCOLOR%};
    }

    return genDialog( $change ? $message : '&nbsp;' );
}

# =========================
sub talkToLDAP {
    use Net::LDAP;
    my ( $old, $new, $ldap, $dn ) =
      ( shift, shift, new Net::LDAP($ldap_server), undef );
    return
q"%X% %RED%Can't contact LDAP Server. Please review %MAINWEB%.LDAPPasswordChangerPlugin configuration.%ENDCOLOR%"
      unless $ldap;
    my $msg;
    $msg = $ldap->bind;
    return q{%X% %RED%LDAP Error:} . $msg->error . q{%ENDCOLOR%}
      if $msg->is_error;

    TWiki::Func::writeDebug(
        "calling ldap::search( base => '$base_dn', filter => '$filter' ) ")
      if $debug;
    $msg =
      $ldap->search( base => $base_dn, filter => $filter, attrs => ['1.1'] );
    return
q"%X% %RED%LDAP doesn't return any users.<br />Please inform LDAP Administrator.%ENDCOLOR%"
      unless $dn = $msg->shift_entry();
    $msg = $ldap->bind( $dn, password => $old );
    return q{%X% %RED%LDAP Error:} . $msg->error . q{%ENDCOLOR%}
      if $msg->is_error;
    $msg = $ldap->modify( $dn, replace => { userPassword => $new } );
    return q{%X% %RED%LDAP Error:} . $msg->error . q{%ENDCOLOR%}
      if $msg->is_error;
    $ldap->unbind;
    return q{%Y% %GREEN%Password changed sucessfully%ENDCOLOR%};
}

# =========================
sub genDialog {
    my $message = shift;
    return q{
<form action="%TOPIC%" method="post">
  <table bgcolor="%WEBBGCOLOR%" align="center" border="0" cellpadding="1" cellspacing="1">
    <tr>
      <td height="25" colspan="2" valign="middle" align="center">
        <b> Change Password for }
      . TWiki::Func::userToWikiName( $user, 0 ) . q{</b>
      </td>
    </tr>
    <tr>
      <td>
        <table bgcolor="#FFFFFF" align="center" border="0" cellpadding="1" cellspacing="8">}
      . (
        $message
        ? qq{
          <tr>
            <td align="center" colspan="2"> $message </td>
          </tr> }
        : ''
      )
      . q{
          <tr>
            <td align="right"> Old Password: </td>
            <td> <input type="password" name="oldpwd"> </td>
          </tr>
          <tr>
            <td align="right"> New Password: </td>
            <td> <input type="password" name="newpwd1"> </td>
          </tr>
          <tr>
            <td align="right"> New Password Again: </td>
            <td> <input type="password" name="newpwd2"> </td>
          </tr>
        </table>
      </td>
    </tr>
    <tr>
      <td height="30" colspan="2" valign="middle" align="center">
        <input type="submit" name="change" value="                   Change Password                   ">
      </td>
    </tr>
  </table>
</form>
};

}    # end sub
1;
