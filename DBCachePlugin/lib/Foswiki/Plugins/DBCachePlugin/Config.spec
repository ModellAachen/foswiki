# ---+ Extensions
# ---++ DBCachePlugin
# This is the configuration used by the <b>DBCachePlugin</b>.

# **BOOLEAN**
# Set this to true to enable caching storable images in a shared memory segment. This
# will significantly improve performance as the dbcache file isn't loaded from disk on
# every request.
$Foswiki::cfg{DBCachePlugin}{MemoryCache} = 1;

# **BOOLEAN EXPERT**
# Foswiki engines since version 1.1 implement a handler called afterUploadHandler
# that this plugin uses to watch for new attachments being uploaded. On prior engines,
# the deprecated afterAttachmentSaveHandler has to be used which infact is flawed.
# However, when you backported the newer afterUploadHandler to a legacy foswiki you can
# enable the UseUploadHandler flag to use the afterUploadHandler in favor to the depreated
# counterpart. Leave this to false on newer engines or when you are unsure what this is all about.
$Foswiki::cfg{DBCachePlugin}{UseUploadHandler} = 0;

# ---+ Security and Authentication
# ---++ Access Control
# **BOOLEAN EXPERT**
# When enabling this option, reading TopicTitles is protected by view rights on that topic.
# Note, however, that this might cause a performance degradation as every wiki link will
# require a permission check.
$Foswiki::cfg{SecureTopicTitles} = 0;
