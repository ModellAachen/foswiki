# ---+ Extensions
# ---++ AntiWikiSpamPlugin
# **URL**
# URL where plugin should retrive the list of regular expressions that match spam postings.
# The default site provides the MoinMoin antispam list: http://arch.thinkmo.de/cgi-bin/spam-merge
$Foswiki::cfg{Plugins}{AntiWikiSpamPlugin}{ANTISPAMREGEXLISTURL} = 'http://arch.thinkmo.de/cgi-bin/spam-merge';

# **STRING 40**
# Local topic name containing list of regular expressions that match spam postings.
$Foswiki::cfg{Plugins}{AntiWikiSpamPlugin}{LOCALANTISPAMREGEXLISTTOPIC} = '$Foswiki::cfg{SystemWebName}.AntiWikiSpamLocalList';

# **NUMBER**
# Age in minutes of the regular expression list, after which a new list will be retrieved.
$Foswiki::cfg{Plugins}{AntiWikiSpamPlugin}{GETLISTTIMEOUT} = 60;

# **STRING 40**
# Group name whose members are allowed to post regardless of spam status.    
$Foswiki::cfg{Plugins}{AntiWikiSpamPlugin}{BypassGroup} = 'AntiWikiSpamBypassGroup';

# **NUMBER**
# Number of potential spam regex matches that will result in blociking save and attach operations.
# Default is 1, blocking on a single match.  Set to -1 to "simulate" operation by logging, but not blocking any actions.
# If un-set, then the default is 1.
$Foswiki::cfg{Plugins}{AntiWikiSpamPlugin}{HitThreshold} = 1;

# **STRING 40**
# Name of a topic containing a white-list that limit registrations.
$Foswiki::cfg{Plugins}{AntiWikiSpamPlugin}{RegistrationWhiteList} = '$Foswiki::cfg{SystemWebName}.AntiWikiSpamRegistrationWhiteList';

# **STRING 40**
# Name of a topic containing a black-list that limit registrations.
$Foswiki::cfg{Plugins}{AntiWikiSpamPlugin}{RegistrationBlackList} = '$Foswiki::cfg{SystemWebName}.AntiWikiSpamRegistrationBlackList';

1;
