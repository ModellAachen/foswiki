# ---+ Extensions
# ---++ GenPDFWebkitPlugin
# **PATH M**
# wkhtmltopdf executable including complete path
# downloadable from http://code.google.com/p/wkhtmltopdf;
# note that this plugin comes with a wkhtmltopdf binary for linux in the tools directory.
$Foswiki::cfg{GenPDFWebkitPlugin}{WebkitCmd} = "$Foswiki::cfg{DataDir}/../tools/wkhtmltopdf -q --enable-plugins --outline --print-media-type %INFILE|F% %OUTFILE|F%";
1;
