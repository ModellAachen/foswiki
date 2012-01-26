# ---+ Extensions
# ---++ SolrPlugin

# **STRING**
# Comma seperated list of webs to skip
$Foswiki::cfg{SolrPlugin}{SkipWebs} = 'Trash, TWiki, TestCases';

# **STRING**
# List of topics to skip.
# Topics can be in the form of Web.MyTopic, or if you want a topic to be excluded from all webs just enter MyTopic.
# For example: Main.WikiUsers, WebStatistics
$Foswiki::cfg{SolrPlugin}{SkipTopics} = 'WebRss, WebSearch, WebStatistics, WebTopicList, WebLeftBar, WebPreferences, WebSearchAdvanced, WebIndex, WebAtom, WebChanges, WebCreateNewTopic, WebNotify';

# **STRING**
# Comma seperated list of extenstions to read, Their metadata is added to the index in any case.
$Foswiki::cfg{SolrPlugin}{IndexExtensions} = 'txt, html, doc, docx, xls, xlsx, ppt, pptx, pdf, odt';

# **STRING**
# List of attachments to skip                                                                                         
# For example: Web.SomeTopic.AnAttachment.txt, Web.OtherTopic.OtherAttachment.pdf 
# Note that neither metadata nor the content of the attachment is added to the index
$Foswiki::cfg{SolrPlugin}{SkipAttachments} = '';

# **BOOLEAN**
# Update the index when a topic is created or save.
# If this flag is disabled, you will have to install a cronjob to update the index regularly.
$Foswiki::cfg{SolrPlugin}{EnableOnSaveUpdates} = 0;

# **BOOLEAN**
# Update the index whenever a file is attached to an existing topic. 
# If this flag is disabled, you will have to install a cronjob to update the index regularly.
$Foswiki::cfg{SolrPlugin}{EnableOnUploadUpdates} = 0;

# **BOOLEAN**
# Update the index whenever a topic is renamed.
# If this flag is disabled, you will have to install a cronjob to update the index regularly.
$Foswiki::cfg{SolrPlugin}{EnableOnRenameUpdates} = 1;

# **PERL H**
# This setting is required to enable executing the solrsearch script from the bin directory
$Foswiki::cfg{SwitchBoard}{solrsearch} = ['Foswiki::Plugins::SolrPlugin', 'searchCgi', { 'solrsearch' => 1 }];

# **PERL H**
$Foswiki::cfg{SwitchBoard}{solrindex} = ['Foswiki::Plugins::SolrPlugin', 'indexCgi', { 'solrindex' => 1 }];

# **STRING**
# Url where to find the solr server
$Foswiki::cfg{SolrPlugin}{Url} = 'http://localhost:8983/solr';

# **STRING** 
# Url of the server to send updates to. Note, you will only need this setting
# in a solr setup with master-slave replication where all updates are sent to
# a single master which in turn replicates them to the clients. This setting
# will override any {Url} setting above.
$Foswiki::cfg{SolrPlugin}{UpdateUrl} = '';

# **STRING** 
# Url of a slave server to get search results from.  Note, you will only
# need this server in a solr setup with master-slave replication.  This
# setting will override any {Url} setting above.
$Foswiki::cfg{SolrPlugin}{SearchUrl} = '';

# **BOOLEAN**
# Enable this flag to automatically start a solr instance coming with this plugin
$Foswiki::cfg{SolrPlugin}{AutoStartDaemon} = 0;

# **COMMAND**
# Command used to start the solr instance. Note that <code>solrstart</code> is a shell script wrapping
# around the actual startup routine
$Foswiki::cfg{SolrPlugin}{SolrStartCmd} = '$Foswiki::cfg{ToolsDir}/solrstart %SOLRHOME|F%';

# **PATH**
# Path to the directory containing the <code>start.jar</code> file. That's where the jetty engine is 
# located and where solr puts its data further down the directory structure
$Foswiki::cfg{SolrPlugin}{SolrHome} = '';

# **STRING**
# Default collection where to put foswiki content to (including topic text as well as all attachments)
$Foswiki::cfg{SolrPlugin}{DefaultCollection} = 'wiki';

# **PERL**
# List of supported languages. These are the locale IDs as supported for by the schema.xml configuration
# file for solr. For each language ID there's a text field named text_&lt;ID&gt; that will be filled
# with content in the appropriate language. A wiki page can be flagged to be in a specific language by
# setting the CONTENT_LANGUAGE preference variable. Default is the site's language as configured in {Site}{Locale}.
# Entries in the list below are key =&gt; value pairs mapping a cleartext language label to the used locale ID
# used in the schema.
$Foswiki::cfg{SolrPlugin}{SupportedLanguages} = {
  'en' => 'en', 'english' => 'en',
  'cjk' => 'cjk', 'chinese' => 'cjk', 'japanese' => 'cjk', 'korean' => 'cjk', 
  'da' => 'da', 'danish' => 'da', 
  'de' => 'de', 'german' => 'de', 
  'es' => 'es', 'spanish' => 'es', 
  'fi' => 'fi', 'finish' => 'fi', 
  'fr' => 'fr', 'french' => 'fr', 
  'it' => 'it', 'italian' => 'it', 
  'nl' => 'nl', 'dutch' => 'nl', 
  'pt' => 'pt', 'portuguese' => 'pt', 
  'ru' => 'ru', 'russian' => 'ru', 
  'se' => 'se', 'swedish' => 'se', 
  'tr' => 'tr', 'turkish' => 'tr'
};

1;
