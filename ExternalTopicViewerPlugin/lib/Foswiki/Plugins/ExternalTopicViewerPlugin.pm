# Plugin for TWiki Collaboration Platform, http://TWiki.org/
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

=pod

---+ package TWiki::Plugins::ExternalTopicViewerPlugin

To interact with TWiki use ONLY the official API functions
in the TWiki::Func module. Do not reference any functions or
variables elsewhere in TWiki, as these are subject to change
without prior warning, and your plugin may suddenly stop
working.

For increased performance, all handlers except initPlugin are
disabled below. *To enable a handler* remove the leading DISABLE_ from
the function name. For efficiency and clarity, you should comment out or
delete the whole of handlers you don't use before you release your
plugin.

__NOTE:__ When developing a plugin it is important to remember that
TWiki is tolerant of plugins that do not compile. In this case,
the failure will be silent but the plugin will not be available.
See %TWIKIWEB%.TWikiPlugins#FAILEDPLUGINS for error messages.

__NOTE:__ Defining deprecated handlers will cause the handlers to be 
listed in %TWIKIWEB%.TWikiPlugins#FAILEDPLUGINS. See
%TWIKIWEB%.TWikiPlugins#Handlig_deprecated_functions
for information on regarding deprecated handlers that are defined for
compatibility with older TWiki versions.

__NOTE:__ When writing handlers, keep in mind that these may be invoked
on included topics. For example, if a plugin generates links to the current
topic, these need to be generated before the afterCommonTagsHandler is run,
as at that point in the rendering loop we have lost the information that we
the text had been included from another topic.

=cut

package TWiki::Plugins::ExternalTopicViewerPlugin;

# Always use strict to enforce variable scoping
use strict;

require TWiki::Func;       # The plugins API
require TWiki::Plugins;    # For the API version

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package.
use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

# This should always be $Rev: 15942 (11 Aug 2008) $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 15942 (11 Aug 2008) $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'TWiki-4.2';

# Short description of this plugin
# One line description, is shown in the %TWIKIWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION =
'External Topics Viewer Plugin for generating overview tables and viewing file content of external TML formatted text files';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use preferences
# stored in the plugin topic. This default is required for compatibility with
# older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, use $TWiki::cfg entries set in LocalSite.cfg, or
# if you want the users to be able to change settings, then use standard TWiki
# preferences that can be defined in your Main.TWikiPreferences and overridden
# at the web and topic level.
$NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
$pluginName = 'ExternalTopicViewerPlugin';

# Always use strict to enforce variable scoping
use strict;

require TWiki::Func;       # The plugins API
require TWiki::Plugins;    # For the API version

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package.
use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'TWiki-4.2';

# Short description of this plugin
# One line description, is shown in the %TWIKIWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION =
'External Topic Viewer Plugin for generating overview tables and viewing file content of external TML formatted text files';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use preferences
# stored in the plugin topic. This default is required for compatibility with
# older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, use $TWiki::cfg entries set in LocalSite.cfg, or
# if you want the users to be able to change settings, then use standard TWiki
# preferences that can be defined in your Main.TWikiPreferences and overridden
# at the web and topic level.
$NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
$pluginName = 'ExternalTopicViewerPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

REQUIRED

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using TWiki::Func::writeWarning and return 0. In this case
%FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

You may also call =TWiki::Func::registerTagHandler= here to register
a function to handle variables that have standard TWiki syntax - for example,
=%MYTAG{"my param" myarg="My Arg"}%. You can also override internal
TWiki variable handling functions this way, though this practice is unsupported
and highly dangerous!

__Note:__ Please align variables names with the Plugin name, e.g. if 
your Plugin is called FooBarPlugin, name variables FOOBAR and/or 
FOOBARSOMETHING. This avoids namespace issues.


=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    my $setting = $TWiki::cfg{Plugins}{ReportPlugin}{ExampleSetting} || 0;
    $debug = $TWiki::cfg{Plugins}{ReportPlugin}{Debug} || 0;

    TWiki::Func::registerTagHandler( 'EXTERNALTOPICS', \&_EXTERNALTOPICS );

    # Plugin correctly initialized
    return 1;
}

# The function used to handle the %QQREPORT{...}% variable
# You would have one of these for each variable you want to process.
sub _EXTERNALTOPICS {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    my $text = '';

    # Prevent manual file deletion
    my $allow_deletion = 0;

    # Obtain tag parameters
    #  Check if fullpath is specified
    my $full_path = $params->{fullpath}
      or return error_msg(
'%MAKETEXT{"Please specify tag parameter =fullpath= (using forward-slashes) i.e. =c:/external_topic_files/=!"}%',
        "Wrong or missing =fullpath=\"...\"="
      );

    $full_path =~ s/\\/\//g;
    $full_path .= '/' unless ( $full_path =~ /\\|\/$/ );
    lc($full_path);

    #  Obtain optional tag parameter filenamesep(parator), if specified
    my $file_name_sep = $params->{filenamesep} || '_o_';

    #  Check if filenameheader is specified
    my $file_name_header = $params->{filenameheader}
      or return error_msg(
"Please specify tag parameter =filenameheader=\"\(properly ordered coma-separated file name element list\)\"= e.g. =filenameheader=\"Date,Time,Description,Type\"= %BR% *Note!* that this list must reflect your file name elements, as this freely configurable list is used to build the overview table. %BR% Example file list: %BR% 2008-09-05_o_11-17-16_o_ConfigBackup_o_Backup.txt %BR% 2008-09-06_o_11-30-26_o_DatabaseLogBackup_o_Backup.txt ",
        "Missing =filenameheader=\"...\"="
      );

#  Check if file deletion is required (TWiki::cfg AllowFileDeletionPath parameter = full_pathes_to_folders)
    my $allow_file_deletion_pathes =
      $TWiki::cfg{Plugins}{ExternalTopicViewerPlugin}{AllowFileDeletionPath};
    $allow_file_deletion_pathes =~ s/\\/\//g;

#$allow_file_deletion_pathes .= '/' unless ($allow_file_deletion_pathes =~ /\\|\/$/);
#    TWiki::Func::writeWarning( $allow_file_deletion_pathes );

    my @header_all = split /\s*,\s*/, $file_name_header;

    #  Obtain columns to be hidden from the overview table
    my $hidecols = $params->{hidecols};
    my @hidden_header_names = split /\s*,\s*/, $hidecols;

    my @header                 = ();
    my @array_elements_to_hide = ();
    if ( defined $hidecols ) {

 # Delete headers (specified in hidecols) from header line and get array indexes
 # of array elements (table column data fields) that we do not want to be shown
 # on the overview table
        my @header_all_backup = @header_all;
        foreach my $hidden_col (@hidden_header_names) {
            chomp($hidden_col);

            push( @array_elements_to_hide,
                get_index( \@header_all, $hidden_col ) );

            @header = grep !/$hidden_col/i, @header_all_backup;
            @header_all_backup = @header;
        }
    }
    else {
        @header = @header_all;
    }

    #  Check if standard or verbatim text processing is wanted
    my $content_mode = $params->{contentmode};

    #  Check columns to be hidden on the overview table
    my $file_search_pattern = $params->{filesearchpattern} || '\.txt$';
    chomp($file_search_pattern);

# Check if $full_path matches with at least one path specified in TWiki::cfg AllowFileDeletionPath
#  Get path entries
    my @allow_file_deletion_path_entries = split /\s*,\s*/,
      $allow_file_deletion_pathes;

    my %file_deletion_path_entries = ();
    foreach (@allow_file_deletion_path_entries) {
        chomp;
        my $item = $_;
        $item =~ s/\\/\//g;
        $item .= '/' unless ( $item =~ /\/$/ );
        lc($item);

        #        TWiki::Func::writeWarning( "item: $item" );
        #        TWiki::Func::writeWarning( "full_path: $full_path" );
        $file_deletion_path_entries{$item} = 1;
    }

    #    TWiki::Func::writeWarning( "$full_path\n$del_bits" );

    $allow_deletion = 1 if ( $file_deletion_path_entries{$full_path} );

    #    TWiki::Func::writeWarning( "Allow deletion: $allow_deletion" );

# Obtain HTTP parameters:
# If extfilename is passed, present file contents instead of the overview table
# If submit_deletereports is passed, delete all files passed in as HTTP param etv_fileselect from the $full_path folder
    my $cgi                  = TWiki::Func::getCgiQuery();
    my $ext_file_name        = $cgi->param("extfilename");
    my $submit_deletereports = $cgi->param("submit_deletereports");
    my @etv_fileselect       = $cgi->param("etv_fileselect");

    #    TWiki::Func::writeWarning( "@etv_fileselect" );

    # Delete selected files from $full_path
    if (   (@etv_fileselect)
        && ( defined $submit_deletereports )
        && ($allow_deletion) )
    {
        foreach (@etv_fileselect) {
            my $file_name = $full_path . $_;
            $file_name = untaint($file_name);

            #            TWiki::Func::writeWarning( "$file_name" );
            unlink("$file_name");
        }
    }

    if ( defined $ext_file_name ) {
        open( INFILE, "$full_path$ext_file_name" )
          or return error_msg( "Could not open dir $full_path", "$!" );
        $text .= '<verbatim>' . "\n" if ( $content_mode =~ /verbatim/i );
        while (<INFILE>) {
            chomp;
            $text .= "$_\n";
        }
        close(INFILE);
        $text .= '</verbatim>' . "\n" if ( $content_mode =~ /verbatim/i );

        return $text;
    }

    opendir( DIR, $full_path )
      or return error_msg( "Could not open dir $full_path", "$!" );

    my @file_listing = grep /$file_search_pattern/, readdir(DIR);
    closedir(DIR);

    my %listing = ();
    foreach (@file_listing) {

        #next if (/archived_reports/);
        my @file_elements_all = split /$file_name_sep/, $_;

        my @file_elements = @file_elements_all;
        foreach my $hide_element (@array_elements_to_hide) {
            splice( @file_elements, $hide_element, 1, 'ignore' );
        }

        $listing{$_} = [@file_elements];
    }

    # Build the form
    if ($allow_deletion) {
        $text .=
'<form action="%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/%WEB%/%TOPIC%" method="POST" name="deleteExternalTopics">'
          . "\n";
        $text .=
            ' <input type="hidden" name="submit_deletereports" value="on" />'
          . "\n";
    }

    # Build the table
    $text .=
'%TABLE{ sort="on" tableborder="0" cellpadding="4" cellspacing="3" cellborder="0" headerbg="#D5CCB1" headercolor="#666666" databg="#FAF0D4, #F3DFA8" headerrows="1" }%'
      . "\n";

    # Build header row
    if   ($allow_deletion) { $text .= '| *Select* |'; }
    else                   { $text .= '|'; }
    foreach (@header) {
        $text .= " *$_* |";
    }
    $text .= " *Open file* |";
    $text .= "\n";

    # Build content rows
    my $listing_counter = 0;
    foreach ( sort keys %listing ) {
        if ($allow_deletion) {
            $text .=
                '| <input type="checkbox" name="etv_fileselect" value="' 
              . $_
              . '"></input> |';
        }
        else {
            $text .= '|';
        }
        foreach my $table_field ( @{ $listing{$_} } ) {
            $text .= " $table_field |" unless ( $table_field =~ /ignore/i );
        }
        $text .=
" [[%SCRIPTURLPATH{\"view\"}%/%WEB%/$theTopic?extfilename=$_][%MAKETEXT{Open}%]] |";
        $text .= "\n";
        $listing_counter++;
    }

    # Close the form
    if ($allow_deletion) {
        my $empty_table_fields = $#header;

        #        TWiki::Func::writeWarning( "$empty_table_fields" );
        $text .=
'<input type="submit" class="twikiSubmit" value="%MAKETEXT{"Delete Selected Files"}%" />'
          . "\n";

        #$text .= '|' x ($empty_table_fields + 3);
        $text .= '</form>' . "\n";
    }

    #    TWiki::Func::writeWarning( "$text" );

    return $text;

}

sub error_msg {
    my ( $msg, $short_msg ) = @_;

    my $text =
"| &nbsp;&nbsp;&nbsp;%ICON{\"warning\"}% *%MAKETEXT{\"$pluginName returned an error:* | $short_msg |\"}%"
      . "\n";
    $text .= "|  *Message* | " . $msg . " |";

    return $text;
}

sub convert_date {
    my ($date_single) = shift;
    my @items;

    my $year = substr( $date_single, 0,  4 );
    my $mon  = substr( $date_single, 4,  2 );
    my $mday = substr( $date_single, 6,  2 );
    my $hour = substr( $date_single, 8,  2 );
    my $min  = substr( $date_single, 10, 2 );
    my $sec  = substr( $date_single, 12, 2 );

    $items[0] = "$year\.$mon\.$mday $hour\:$min\:$sec";
    $items[1] = substr( $year, 2, 2 );
    $items[2] = $mon;
    $items[3] = $mday;
    $items[4] = $hour;
    $items[5] = $min;
    $items[6] = $sec;

    return \@items;
}

sub untaint {
    my $val = shift;

    # Unsecure untaint pattern, working though
    if ( $val =~ /(.+)$/ ) {
        $val = $1;    # val now untainted
    }
    else {
        TWiki::Func::writeWarning("BAD DATA IN $val");
    }
    return ($val);
}

sub get_index {
    my ( $array, $value ) = @_;
    my $x = 0;

    foreach ( @{$array} ) {
        $_ eq $value ? return $x : $x++;
    }
}

1;
