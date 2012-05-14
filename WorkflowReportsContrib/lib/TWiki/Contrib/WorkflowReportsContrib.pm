# Contrib for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
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

package TWiki::Contrib::WorkflowReportsContrib;

use strict;
use TWiki;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION );
$VERSION = '$Rev: 0$';
$RELEASE = 'Dakar';
$SHORTDESCRIPTION =
'Supports report generation for workflow topics (see [[Foswiki:Extensions/WorkflowPlugin][WorkflowPlugin]])';

my $debugMode    = 0;
my $queryContext = 0;

# Do a dynamic 'use locale' for this module
BEGIN {
    if ( $TWiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

#The command handler
sub workflowReports {
    my $twiki   = shift;
    my $webList = undef;

    $queryContext = !$twiki->inContext('command_line');

    # start html output if not running from command_line
    if ($queryContext) {
        my $query = $twiki->{cgiQuery};
        $webList   = $query->param('webs');
        $debugMode = $query->param('debug');

        $twiki->writePageHeader();
        print CGI::start_html( -title => 'TWiki: Create Workflow Reports' );

        _report( $twiki, $webList );

        # insert a link to return referring url
        my $url = $ENV{HTTP_REFERER} || $query->url() . $query->path_info();
        _print_message( $twiki,
            '   * Go back to '
              . CGI::a( { href => $url, rel => 'nofollow' }, $url ) );
        print CGI::end_html();
    }
    else {
        _report( $twiki, $webList );
    }
}

sub _report {
    my ( $twiki, $weblist ) = @_;

    _print_message( $twiki, 'TWiki: Create Workflow Reports' );
    _print_message( $twiki, 'Do not interrupt this script!' );
    _print_message( $twiki, 'Please wait until data collection has finished.' );

    my @webs = ();
    if ($weblist) {    # did we get a web list?
        push( @webs, split( /,\s*/, $weblist ) );
    }
    else {             # otherwise do all user webs:
        @webs = $twiki->{store}->getListOfWebs('user');
    }

    foreach my $web (@webs) {
        no locale;
        if ( $web =~ /^([\/-\@\w.]+)$/ ) {
            $web = $1;    # $web now untainted
            _try_on( $twiki, $web );
        }
        else {
            print STDERR "**** ERROR Bad data in '$web' \n";
        }
    }

    _print_message( $twiki, 'End creating workflow reports' );
}

sub _try_on {
    my ( $twiki, $web ) = @_;
    my $store = $twiki->{store};

    return unless $store->webExists($web);

    my $reportTopic = $twiki->{prefs}->getPreferencesValue('WEBWORKFLOWREPORT')
      || 'WorkflowReport';

    if ($debugMode) {    #override when debugging
        $reportTopic = 'DebugWorkflowReport';
    }

    return unless $store->topicExists( $web, $reportTopic );

    # Save existing meta data from report topric
    my ( $topicMetadata, $topicText ) =
      $store->readTopic( undef, $web, $reportTopic, undef );

    my @report_rows = _report_on( $twiki, $web );

    return unless @report_rows;

    $topicText = join( "\n", @report_rows );
    $topicText .= "\n";

    $store->saveTopic( $twiki->{user}, $web, $reportTopic, $topicText,
        $topicMetadata, { minor => 1, dontlog => 1 } );
}

sub _report_on {
    my ( $twiki, $web ) = @_;

    return ()
      if $web ne $twiki->{webName}
          && $twiki->{prefs}->getWebPreferencesValue( 'NOSEARCHALL', $web );

    # List of all web topics
    my @topicnames = $twiki->{store}->getTopicNames($web);
    (@topicnames) = sort(@topicnames);

    # get workflow report topic name
    my $reportFormat =
      $twiki->{prefs}->getPreferencesValue('WEBWORKFLOWREPORTFORMAT')
      || '|$topic|$status|$lasttime|$history|';

    # Report content (table of topics under workflow control)
    my @reportRows = _get_report_header($reportFormat);
    foreach my $topic (@topicnames) {
        my $reportRow = _get_report_item( $twiki, $web, $topic, $reportFormat );
        if ($reportRow) {
            push @reportRows, $reportRow;
        }
    }

    return @reportRows;
}

sub _get_report_header {
    my $header = shift;    # load report format

    # replace coresponding format placeholder with header text
    $header =~ s/\$topic\b/*%MAKETEXT{"Topic"}%*/g;
    $header =~ s/\$status\b/*%MAKETEXT{"Status"}%*/g;
    $header =~ s/\$author\b/*%MAKETEXT{"Last editor"}%*/g;
    $header =~ s/\$revision\b/*%MAKETEXT{"Revision"}%*/g;
    $header =~ s/\$parent\b/*%MAKETEXT{"Topic parent:"}%*/g;
    $header =~ s/\$date\b/*%MAKETEXT{"Last modified time"}%*/g;
    $header =~ s/\$lasttime\b/*%MAKETEXT{"Date"}%*/g;
    $header =~ s/\$history\b/*%MAKETEXT{"History:"}%*/g;

    return $header;
}

sub _get_report_item {
    my ( $twiki, $web, $topic, $item ) = @_;    # loads item with report format

    if ( $twiki->{store}->topicExists( $web, $topic ) ) {

        # Get topic meta data
        my ( $meta, $text ) =
          $twiki->{store}->readTopic( undef, $web, $topic, undef );

        # Get workflow attributes (status, lasttime)
        my $type      = 'WORKFLOW';
        my $keyValue  = undef;
        my $attribute = $meta->get( $type, $keyValue );
        return undef if ( !defined($attribute) );

        my $status   = $attribute->{name};
        my $lasttime = $attribute->{ 'LASTTIME_' . $status };

        # Get workflow history attribute (history)
        $type     = 'WORKFLOWHISTORY';
        $keyValue = undef;

        $attribute = $meta->get( $type, $keyValue );
        my $history = ' - ';
        $history = $attribute->{value} if $attribute;

        # Get topicinfo attributes (lasteditor, last edit time, revision)
        $type      = 'TOPICINFO';
        $keyValue  = undef;
        $attribute = $meta->get( $type, $keyValue );

        my $author   = ' - ';
        my $wikiname = $attribute->{author};
        $author = '%MAINWEB%.' . $wikiname if $wikiname;

        my $intDate = $attribute->{date};    # Last topic revision date
        my $date = TWiki::Time::formatTime( $intDate, '$day $mon $year' );
        $date .= ' - ';
        $date .= TWiki::Time::formatTime( $intDate, '$hour:$min:$sec' );

        my $revision = $attribute->{version};    # Last topic revision number

        # Get topicparent attribute (parent)
        my $parent = ' - ';
        $type      = 'TOPICPARENT';
        $keyValue  = undef;
        $attribute = $meta->get( $type, $keyValue );
        $parent    = $attribute->{name} if $attribute;

        # replace coresponding format placeholder with value retrieved
        $item =~ s/\$topic\b/[[$topic]]/g;
        $item =~ s/\$status\b/$status/g;
        $item =~ s/\$author\b/$author/g;
        $item =~ s/\$revision\b/$revision/g;
        $item =~ s/\$parent\b/$parent/g;
        $item =~ s/\$date\b/$date/g;
        $item =~ s/\$lasttime\b/$lasttime/g;
        $item =~ s/\$history\b/<verbatim>$history<\/verbatim>/g;

    }
    else {
        print STDERR "**** ERROR workflow reporter cannot find topic $topic\n";
        $item = undef;
    }

    return $item;
}

# print message helper
sub _print_message {
    my ( $twiki, $message ) = @_;

    if ($queryContext) {
        if ( $message =~ s/^\!// ) {
            $message =
              CGI::h4( CGI::span( { class => 'twikiAlert' }, $message ) );
        }
        elsif ( $message =~ /^[A-Z]/ ) {

            # SMELL: does not support internationalised script messages
            $message =~ s/^([A-Z].*)/CGI::h3($1)/ge;
        }
        else {
            $message =~
              s/(\*\*\*.*)/CGI::span( { class=>'twikiAlert' }, $1 )/ge;
            $message =~ s/^\s\s/&nbsp;&nbsp;/go;
            $message =~ s/^\s/&nbsp;/go;
            $message .= CGI::br();
        }
        $message =~
          s/==([A-Z]*)==/'=='.CGI::span( { class=>'twikiAlert' }, $1 ).'=='/ge;
    }
    else {
        $message =~ s/&nbsp;/ /go;
    }
    print $message, "\n";
}

1;
__END__

=begin TML
---+ Workflow Reports Contrib Package
%SHORTDESCRIPTION%

%TOC%

---++ Summary
This package is an add-on to the Workflow Plugin.
See [[Foswiki:Extensions/WorkflowPlugin][WorkflowPlugin]]
for an overwiew of Workflows in TWiki.

---+++ <code>TWiki/Contrib/WorkflowReportsContrib</code> code library
The main part of the package is the  =WorkflowReportsContrib.pm= module.
It provides the services for the script (and other applications of course) to
update a <nop>WebWorkflowReport. This allows (for example) TWiki users to add
a "Update Report" button to topics.

The main interface is the =workflow<nop>Reports= method described below.

---+++ <code>bin/workflowreports</code> script
The =workflowreports= script is an application of the workflowreports contrib package.
It is designed to be run from 'cron' (or an equivalent offline job scheduler)
to update the workflow report topics regularly.

---++ Acknowledgments
This contrib package is inspired by the following contributions
   * [[Foswiki:Extensions/WorkflowPlugin][WorkflowPlugin]]
   * WebStatistics module
   * [[Foswiki:Extensions/MakeCtrlTopicsListAddOn][MakeCtrlTopicsListAddOn]]
   * [[Foswiki:Extensions/MailerContrib][MailerContrib]]

I would like to express my gratitude to:
[[TWiki:Main/PeterThoeny][PeterThoeny]], [[TWiki:Main/ThomasWeigert][ThomasWeigert]],
[[TWiki:Main/DetlefMarxsen][DetlefMarxsen]], [[TWiki:Main/CrawfordCurrie][CrawfordCurrie]]

---++ Static Method workflow<nop>Reports
The workflow reports query and command handler.

This method supports invocation through a cgi query and via the =TWiki::UI::run= method.

It updates one workflow report topic for each 'user' web except webs that
do have the NOSEARCHALL preference set to 'on' OR for web(s) specified
in the query parameter 'webs'. It does not _create_ the topic, it only updates
the content of an existing workflow report topic.

During execution some messages are output as a sign of activity. Output may be
sent from cron to an e-mail recipient. No topic content is disclosed.
But web and topic names may be disclosed in case of failures.

---++ Process description
Workflow report topics are updated for each web separately.

The report topic name can be defined through the web preference setting
WEBWORKFLOWREPORT. In case the setting is missing 'Workflow<nop>Report' is used as a
default topic name.

The report topic must exist before executing this script. Create this topic
manually. If the report topic does not exist the web is skipped even if topics
under workflow control exist. This can be used to suspend reporting on a web temporarily.

For debug purposes a topic named 'Debug<nop>WorkflowReport' is used. Create this topic
manually before debugging. Use the query parameter 'debug' to enter debug mode.

Any previous content will be replaced by the report information. Meta information
is preserved. TWiki<nop>AdminGroup is the report topic author if the script is run from cron.

The topic changes are saved as minor changes without logging.

---++ Report description
The command handler scans all the web topics and collects topic and
workflow information from topics under workflow control.

The following topic and workflow information is available:
   * $topic (topic link)
   * from meta data WORKFLOW
      * $status (current workflow status)
      * $lasttime (date - time of status assignment)
   * from meta data WORKFLOWHISTORY
      * $history (workflow history as verbatim history information)
   * from meta data TOPICINFO
      * $revision (current revision)
      * $date (last modified date - time)
      * $author (last editor)
   * from meta data TOPICPARENT
      * $parent (parent topic)

The report format can be defined through the web preference setting
WEBWORKFLOWREPORTFORMAT. In case the setting is missing a default format
is used (a table row defined as: |$topic|$status|$lasttime|$history|)

The table header is using the following MAKETEXT items
   * $topic : "Topic"
   * $status : "Status"
   * $lasttime : "Date"
   * $history : "History:"
   * $revision : "Revision"
   * $date : "Last modified time"
   * $author : "Last editor"
   * $parent : "Topic parent:"

For each topic under workflow control (whenever meta data 'WORKFLOW' is available)
a table row is added. The row gets populated with the information matching
the defined format. Missing information is represented as a dash '-'.

The table is sorted alphabetically by topic name. Locale is used if enabled.

---++++ Sample Report:
|*%MAKETEXT{"Topic"}%*|*%MAKETEXT{"Status"}%*|*%MAKETEXT{"Date"}%*|*%MAKETEXT{"History:"}%*|*%MAKETEXT{"Revision"}%*|*%MAKETEXT{"Last modified time"}%*|*%MAKETEXT{"Last editor"}%*|*%MAKETEXT{"Topic parent:"}%*|
|[[Issue1]]|ASSIGNED|08 Oct 2006 - 01:32|<verbatim>ASSIGNED -- 07 Oct 2006 - 23:46
CLOSED -- 08 Oct 2006 - 00:29</verbatim>|1.1|08 Oct 2006 - 01:32:50|%MAINWEB%.PaulHoesli|WebHome|
|[[Issue2]]|CONFIRMED|08 Oct 2006 - 01:24|<verbatim>REJECTED
CONFIRMED </verbatim>|1.1|08 Oct 2006 - 01:24:06|%MAINWEB%.PaulHoesli|WebHome|

---++ Missing Features
   * Add application programming interface
   * Add workflow name to report data items
   * Optionally create separate reports for different workflows (e.g. '%<nop>WorkflowName%Report')
   * Select workflow(s) to report on (query param 'workflows')
Vote on or add your own missing features in TWiki:Codev/WorkflowReportsContribDev.

---++ Bugs
   * Subwebs return undefined report rows

---++ Settings

Settings are stored as preferences variables. To reference a setting
write ==%<nop>&lt;plugin&gt;_&lt;setting&gt;%==, e.g. ==%<nop>WORKFLOWREPORTSCONTRIB_STUB%==

   * One line description:
      * Set SHORTDESCRIPTION = Supports report generation for workflow topics (see [[Foswiki:Extensions/WorkflowPlugin][WorkflowPlugin]])

   * Name of the perl package
      * Set STUB = %$STUB%

   * Topic name and format of the workflow report:
      * Set WEBWORKFLOWREPORT = <nop>WebWorkflowReport
      * Set WEBWORKFLOWREPORTFORMAT = |$topic|$status|$lasttime|$history|$revision|$author|$date|$parent|

---++ Usage samples
---+++ Setting up a cron job
You may set up a =cron= (or equivalent) job to run =workflowreports= regularly.

<code>Usage: /usr/bin/perl -I &lt;bin&gt; &lt;bin&gt;workflowreports</code>
   * &lt;bin&gt; is the *absolute* path to the TWiki bin directory (usually =/home/&lt;user&gt;/public_html/&lt;twiki&gt;/bin=), so that the script can find the rest of TWiki.
   * add <code>>/dev/null 2>&1</code> at the end if activity messages are to be supressed

For example, =/usr/bin/perl -I /home/myuser/public_html/twiki/bin /home/myuser/public_html/twiki/bin/workflowreports >/dev/null 2>&1=

---+++ Include the report into your topic
Insert the following line in your topic:

%<nop>INCLUDE{%<nop>WEBWORKFLOWREPORT%}%;

---+++ Update the report from you topic manually using a link
Insert the following line in your topic:

<verbatim><a href="%SCRIPTURLPATH{workflowreports}%">Update workflow report</a></verbatim>

---+++ Update reports from you topic manually using a button
Insert the following lines in your topic:

<verbatim><form name="updateReport" action="%SCRIPTURLPATH{workflowreports}%/%WEB%/">
   <input type="hidden" name="webs" value="Main, Sandbox" />
   <input type="submit" class="twikiSubmit"  value="Update Reports" />
</form></verbatim>

---+++ License
This software is published under the terms of the GNU General Public License.

The software is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details, published at http://www.gnu.org/copyleft/gpl.html

=cut


