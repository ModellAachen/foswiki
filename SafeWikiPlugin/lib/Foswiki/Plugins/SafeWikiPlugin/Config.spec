#---+ Extensions
#---++ SafeWikiPlugin
# **SELECT FAIL,ASSERT,WARN**
# If set to FAIL, then threats will be defused. If set to WARN, then Foswiki
# will continue to operate normally and any threats are logged to the error
# log without being disarmed (this is useful when tuning the filters for
# a specific site). ASSERT is like FAIL except that if FOSWIKI_ASSERTS are
# enabled, it will fail with an ASSERT on the first filter action.
$Foswiki::cfg{Plugins}{SafeWikiPlugin}{Action} = 'FAIL';

# **BOOLEAN**
# If this option is enabled, then the plugin will check HTML for
# correctness. While nowhere near as rigorous as a full XHTML validation,
# this check will at least highlight malformed HTML that might be exploited
# by a hacker.
$Foswiki::cfg{Plugins}{SafeWikiPlugin}{CheckPurity} = 0;

#---+++ Signatures
# **PERL**
# A perl list consisting of MD5 based signatures of inline script code that may
# appear anywhere in a topic, including as event handlers, script tags, or added
# with the %ADDTO macros.   The default covers inline scripts used in Foswiki 1.1.4
$Foswiki::cfg{Plugins}{SafeWikiPlugin}{SignaturesList} = [
          '2Jpk3RVVNT3hBHyjYhbbCQ',
          '4oSmQfCDgWT55P3UGgv+OA',
          '4PkSB+IE2tVosMVmZw4QlA',
          '7Ks6aCAX/IRM6+TeajS7TQ',
          '7qpsUfhWZacx7H0iVvhoLg',
          'AnhTto6hzF0vJ3OXrtyEhQ',
          'AsAR/5iiim0S99gZTxptBQ',
          'Be+iJp0ZnMxx52E0P6YAhQ',
          'cvV6Chg3lK+IdfwJjZrNjw',
          'd5ClsIZPk1lhgKvpZWfGpg',
          'dMET8vfHCRka2ui+FA1kVA',
          'EanI43tB93UorXxc/lF1rQ',
          'EnNdNZTttZJmWPNOKC5PXw',
          'eqMbgt6hy9EWX4AoZDsPvw',
          'FHV/t3zQBC7L6FjefOiswA',
          'ftLypjekDf5EqaqMbFgFxw',
          'iIkg+VVDLj+0AxkTEDG4kA',
          'JqTv3srxhdRqiFUpmUL2Zw',
          '/RYNq/yniRZAV1gp1+3fBQ',
          'SmxhyJWfKRDLMhDEew0tZg',
          'soagFnGW4IyP2ptdZlx9Fg',
          'wA6gF/AdfUdn3t0HILlUlg',
          'xGF5lh4U0hW2a5wr6j+Gog',
          'z3Rea3lLhcnPpgByI2Zjtg',
          'zaUbpMvbZdvs7eck11IwwA',
          'zfA8ivIe7u/Ag5UNFpIcRw',
          '+zrQyf8aaXWnB+M/GXBvvw',
	  '+WUoeOHoF2+XW//F+NdrgA', # System.SiteChanges
 # Signatures for Foswiki 1.1.3 javascript
          'of8+OSdMT8GH7pDjlxj1WQ',
          'xlIE+D9nDhn7D0vUBPrSPg',
          'EtiWFyrKBBWi7Z/1QS5j+w',
          'q7owQkia4PUohVYy7suRzw',
          'uAd9ZustXM3quTHwg10pTw',
 # Signatues for Foswiki 1.1.2 javascript
          'YSnsdlI4pRfs/da7u6codQ',

        ];

# **STRING 60**
# Optional topic containing a list of signatures merged with the above list.
# The plugin only uses the first column of the table found in this topic.
# See System.SafeWikiSignatures for an example.  <b>If topic based signatures
# are used it is critical that this topic cannot be modified by unauthorized users.
$Foswiki::cfg{Plugins}{SafeWikiPlugin}{SignaturesTopic} = '';

#---+++ Event Handlers
# **PERL**
# Array of perl regular expressions, one of which must match the value
# of an on* handler, or it will be filtered. The default permits a simple
# function call; for example:
# <tt>javascript: fn(param1, "param2")</tt>
# You can use other Foswiki::cfg variables in the the strings here.
$Foswiki::cfg{Plugins}{SafeWikiPlugin}{SafeHandler} = [
          '^(\s*javascript:)?(\s*return)?\s*\w+\s*\(((\w+|\'[^\']*\'|"[^"]*")(\s*,\s*(\w+|\'[^\']*\'|"[^"]*"))*|\s*)?\)[\s;]*(return\s+(\w+|\'[^\']*\'|"[^"]*")[\s;]*)?$',
          '^StrikeOne\.submit\(this\);?(document\.loginform\.foswiki_origin\.value\+=window\.location\.hash)?$',
        ];

# **PERL**
# Array of perl regular expressions. If any of these match the value
# of an on* handler, it will be filtered. The default exludes use of
# 'eval' calls.
# You can use other Foswiki::cfg variables in the the strings here.
$Foswiki::cfg{Plugins}{SafeWikiPlugin}{UnsafeHandler} = ['\beval\s*\('];

# **STRING 30**
# String used to replace dodgy handlers.
$Foswiki::cfg{Plugins}{SafeWikiPlugin}{DisarmHandler} = 'alert("Handler filtered by SafeWikiPlugin")';

#---+++ URIs
# **PERL**
# HTML tags and attributes that will be URI-filtered by the SafeWikiPlugin.
# These attributes are filtered if the tag is included in {Plugins}{SafeWikiPlugin}{FilterTags}
# and the attributes value matches any expression in
# {Plugins}{SafeWikiPlugin}{UnsafeURI} or fails to match at least one expression
# in {Plugins}{SafeWikiPlugin}{SafeURI} (if any are defined). The following quick reference lists
# all the URI attributes on all HTML4 & HTML5 tags, should you want to include any of them.
# <pre>
# A          => [ 'href' ],
# APPLET     => [ 'archive', 'code', 'codebase' ],
# AREA       => [ 'href' ],
# AUDIO      => [ 'src' ],
# BASE       => [ 'href' ],
# BLOCKQUOTE => [ 'cite' ],
# BODY       => [ 'background' ],
# BUTTON     => [ 'formaction' ],
# DEL        => [ 'cite' ],
# EMBED      => [ 'pluginspace', 'pluginurl', 'href', 'target', 'src' ],
# FORM       => [ 'action' ],
# FRAME      => [ 'src', 'longdesc' ],
# IFRAME     => [ 'src', 'longdesc' ],
# IMG        => [ 'src', 'longdesc', 'usemap' ],
# INPUT      => [ 'src', 'usemap' ],
# INS        => [ 'cite' ],
# LINK       => [ 'href' ],
# OBJECT     => [ 'archive', 'codebase', 'data', 'usemap' ],
# Q          => [ 'cite' ],
# SCRIPT     => [ 'src' ],
# SOURCE     => [ 'src' ],
# VIDEO      => [ 'src', 'poster' ]
# </pre>
$Foswiki::cfg{Plugins}{SafeWikiPlugin}{Tags} = {
    APPLET     => [ 'archive', 'code', 'codebase' ],
    EMBED      => [ 'pluginspace', 'pluginurl', 'src' ],
    OBJECT     => [ 'archive', 'codebase' ],
    SCRIPT     => [ 'src' ]
};

# **PERL**
# Array of perl regular expressions, one of which must be matched for
# a URI used in a Foswiki page to be passed unfiltered. You can
# use other Foswiki::cfg variables in the the strings here.
# Note that you will have to extend this list if you have used
# <code>{PermittedRedirectHostUrls}</code> in your configuration.
$Foswiki::cfg{Plugins}{SafeWikiPlugin}{SafeURI} = ['^(|http://(localhost|127\.0\.0\.1)(:\d*)?|$Foswiki::cfg{DefaultUrlHost})/*$Foswiki::cfg{PubUrlPath}/+$Foswiki::cfg{SystemWebName}/+'];

# **PERL**
# Array of perl regular expressions. If any of these match
# a URI used in a Foswiki page it will be filtered.
$Foswiki::cfg{Plugins}{SafeWikiPlugin}{UnsafeURI} = [];

# **STRING 30**
# String used to replace dodgy URIs. Can be a URI if you want.
$Foswiki::cfg{Plugins}{SafeWikiPlugin}{DisarmURI} = 'URI filtered by SafeWikiPlugin';

#---+++ SCRIPT tags
# **PERL**
# Array of perl regular expressions, one of which must match the contents
# of an inline script tag or it will be filtered. The default permits a simple
# Allows the TinyMCEPlugin to provide its inline init code.
$Foswiki::cfg{Plugins}{SafeWikiPlugin}{SafeInline} = [
          '^\s?FoswikiTiny\.init.*'
        ];

