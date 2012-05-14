package TWiki::Plugins::GoogleAjaxSearchPlugin;

use strict;

use vars
  qw( $VERSION $RELEASE $pluginName $debug $initialised $googleSiteKey $searchSite $searchWeb $siteLabel );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'GoogleAjaxSearchPlugin';

BEGIN {
    $initialised = 0;
}

sub commonTagsHandler {
    return unless ( $_[0] =~ s/%GOOGLEAJAXSEARCH%//ge );

    if ( !$initialised ) {
        return unless _lazyInit();
    }
}

sub _lazyInit {
    unless ($initialised) {
        _addToHead();
        $initialised = 1;
    }
}

#there is no need to document this.
sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG");

    $googleSiteKey =
         TWiki::Func::getPreferencesValue('GOOGLEKEY')
      || TWiki::Func::getPluginPreferencesValue('GOOGLEKEY')
      || '';
    $searchSite =
         TWiki::Func::getPreferencesValue('GOOGLESEARCHSITE')
      || TWiki::Func::getPluginPreferencesValue("GOOGLESEARCHSITE")
      || '';
    $searchWeb =
         TWiki::Func::getPreferencesValue('GOOGLESEARCHWEB')
      || TWiki::Func::getPluginPreferencesValue("GOOGLESEARCHWEB")
      || '';
    $siteLabel =
         TWiki::Func::getPreferencesValue('GOOGLESEARCHLABEL')
      || TWiki::Func::getPluginPreferencesValue("GOOGLESEARCHLABEL")
      || '';

    return 1;
}

sub _addToHead {
    my $header =
'<script src="http://www.google.com/uds/api?file=uds.js&amp;v=1.0&amp;key='
      . $googleSiteKey
      . '" type="text/javascript"></script>';
    $header .= '
<style type="text/css" media="all">
	@import url("http://www.google.com/uds/css/gsearch.css");
	@import url("%PUBURL%/%SYSTEMWEB%/GoogleAjaxSearchPlugin/googleAjaxSearch.css");
</style>
<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/GoogleAjaxSearchPlugin/googleAjaxSearch.js"></script>
<script type="text/javascript">
	//<![CDATA[
	GoogleAjaxSearch.prototype.getSearchSite = function () {
		return "' . $searchSite . '" + this.getSearchWeb();
	}
	/**
	An input field with id \'googleAjaxSearchWeb\' may override GOOGLESEARCHWEB.
	*/
	GoogleAjaxSearch.prototype.getSearchWeb = function () {
		var webElem = document.getElementById("googleAjaxSearchWeb");
		if (webElem) {
			var webName = webElem.value;
			if (webName) return webName;
		}
		// else default
		return "' . $searchWeb . '";
	}
	GoogleAjaxSearch.prototype.getUrlParam = function () {
		return "%URLPARAM{"googleAjaxQuery" default=""}%";
	}
	GoogleAjaxSearch.prototype.getSiteLabel = function () {
		var webElem = document.getElementById("googleAjaxSearchlabel");
		if (webElem) {
			var label = webElem.value;
			if (label) return label;
		}
		// else default
		return "' . $siteLabel . '";
	}
//]]>
</script>
';
    TWiki::Func::addToHEAD( 'GOOGLEAJAXSEARCHPLUGIN', $header );
}

1;
