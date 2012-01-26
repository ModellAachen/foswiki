# ---+ Extensions
# ---++ ImmediateNotifyPlugin
# ---+++ EMail Notifications
# **BOOLEAN**
# Enable SMTP for mailing messages. Note:  This plugin uses Foswiki core email support for sending
# notifications.  See the "Mail and Proxies" tab for the configuration.
$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{SMTP}{Enabled} = $FALSE;

# **REGEX**
# Define the regular expression that an email address entered in WebNotify
# must match to be identified as a legal email by the notifier. You can use
# this expression to - for example - filter email addresses on your company
# domain.<br />
# If this is not defined, then the default setting of
# <code>[A-Za-z0-9.+-_]+\@[A-Za-z0-9.-]+</code> is used.
$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{SMTP}{EmailFilterIn} = '';

# ---+++ Jabber / XMPP
# **BOOLEAN**
# Enable XMPP (XMPP) for notifications.
$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{XMPP}{Enabled} = $FALSE;

# **STRING 30**
# Hostname of the XMPP / XMPP server
$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{XMPP}{Server} = '';

# **STRING 30**
# Username for the XMPP account used by the ImmediateNotifyPlugin.  If configured here, the
# topic based setting will be ignored.
$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{XMPP}{Username} = '';

# **PASSWORD 30**
# Password for the XMPP account used by the ImmediateNotifyPlugin.  If configured here, the
# topic based setting will be ignored.
$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{XMPP}{Password} = '';

# ---+++ Twitter
# **BOOLEAN**
# Enable Twitter for notifications.
$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{Twitter}{Enabled} = $FALSE;

# **STRING 30**
# Specify the username for the twitter account
$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{Twitter}{Username} = '';

# **PASSWORD 30**
# Specify the password for the twitter account
$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{Twitter}{Password} = '';

# ---+++ Bit.ly URL Shortening
# **BOOLEAN**
# Enable URL Shortening with Bit.ly.
$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{Bitly}{Enabled} = $FALSE;

# **STRING**
# Optionally, specify a bit.ly username
$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{Bitly}{Username} = '';

# **STRING**
# Optionally, specify a bit.ly API key
$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{Bitlly}{APIKey} = '';
