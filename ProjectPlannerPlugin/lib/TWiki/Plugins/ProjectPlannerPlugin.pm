###########################################################################################
#
# ProjectPlannerPlugin.pm
#
# kiran.bondalapati@NOSPAMamd.com
#
# A Twiki plugin to generate planning tools for projects.
# Heavily borrows on ideas from the XpTracker Plugin
#
# Architecture:
# The web contains multiple Projects and multiple Developers (Devs)
# Each Project can have multiple Developers and each Developer can be
# in multiple Projects.
#
# Each Project is split into multiple Plans. A Plan consists of a list
# of Tasks. A Developer is associated with each Task.
#
###########################################################################################
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
###########################################################################################
#
# Following from EmptyPlugin.pm:
#
###########################################################################################
# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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
#
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see %SYSTEMWEB%.Plugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional.
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

# =========================
package TWiki::Plugins::ProjectPlannerPlugin;

use strict;

#use HTTP::Date;
use Time::Local;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $exampleCfgVar $query
);

use vars qw (
  $cacheFileName
  %cachedProjPlans
  %cachedPlanProj
  %cachedPlanSummary
  %cachedPlanTasks
  %cachedTaskPlan
  %cachedDevTasks
  %cachedIdPlans
);

# These are computed by parsing the PlanTemplate file for the table of
# tasks. However there is no guarantees from screwup for strange PlanTemplate.txt

use vars qw (
  $col_taskname
  $col_summary
  $col_module
  $col_dev
  $col_priority
  $col_status
  $col_estdays
  $col_spentdays
  $col_effort
  $col_dateadded
  $col_results
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'ProjectPlannerPlugin';    # Name of this Plugin

use vars qw ( $TIMESCALE @monthArr @weekdayArr %monthToNum);

$TIMESCALE = "day";
@monthArr  = (
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
);
@weekdayArr = (
    "Sunday",   "Monday", "Tuesday", "Wednesday",
    "Thursday", "Friday", "Saturday"
);
{
    my $count = 0;
    %monthToNum = map { $_ => $count++ } @monthArr;
}

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    $query = &TWiki::Func::getCgiQuery();
    if ( !$query ) {
        return 0;
    }

 # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $exampleCfgVar =
      &TWiki::Func::getPreferencesValue("PROJECTPLANNERPLUGIN_EXAMPLE")
      || "default";

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "-  TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;

    &ppReadPlanTemplate($web);
    &ppReadCache($web);

    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- $pluginName") if $debug;
    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;

# ========================== START PROJECT PLANNER TAGS ==========================

    # search for create new page link
    if ( $query->param('ppsave') ) {
        ppSavePage($web);

        # return; # in case browser does not redirect
    }

    ######## The tags that use Projects as parameters

    #%PPALLPROJECTS% - Show all projects
    $_[0] =~ s/%PPALLPROJECTS%/&ppAllProjects($web)/geo;

    # %PPPROJECTPLANS% - Show project plans for a project with a new Plan form
    $_[0] =~ s/%PPPROJECTPLANS\{(.*?)\}%/&ppProjectPlansNewForm($1, $web)/geo;

# %PPALLPROJECTSPLANS% - Show project plans for a project without a new Plan form
    $_[0] =~ s/%PPALLPROJECTSPLANS\{(.*?)\}%/&ppAllProjectPlans($1, $web)/geo;

    # %PPALLPROJECTSINFO% - Show all project tasks
    $_[0] =~ s/%PPALLPROJECTSINFO\{(.*?)\}%/&ppAllProjectsInfo($1, $web)/geo;

    # These two use Projects as inputs and show summary by developer

    # %PPDEVSUMMARY% - Show developer summary for listed projects
    $_[0] =~ s/%PPDEVSUMMARY\{(.*?)\}%/&ppAllDevSummary($1, $web, 0)/geo;

    # %PPDEVDETAILS% - Show developer detailed summary for listed
    #                  projects. Shows all tasks of developer
    $_[0] =~ s/%PPDEVDETAILS\{(.*?)\}%/&ppAllDevSummary($1, $web, 1)/geo;

    # Show summaries by PlanId

    # %PPPLANIDSUMMARY% - Show task list by ID for listed projects
    $_[0] =~ s/%PPPLANIDSUMMARY\{(.*?)\}%/&ppAllPlanIdSummary($1, $web)/geo;

    ####### The tags that use Plans as parameters

    # %PPALLPLANS% - Show all testplans
    $_[0] =~ s/%PPALLPLANS%/&ppAllPlans($web)/geo;

    # %PPALLPLANSTASKSUMMARY% - Show summary for listed plans and task subsets
    $_[0] =~
      s/%PPALLPLANSTASKSUMMARY\{(.*?)\}%/&ppAllPlansTasksSummary($1, $web)/geo;

    # %PPPROJECTTASKS% - Show all project tasks
    $_[0] =~ s/%PPALLPROJECTSTASKS\{(.*?)\}%/&ppAllProjectTasks($1, $web)/geo;

# ========================== END PROJECT PLANNER TAGS ==========================

    return $_[0];
}

#################################################################################
# gaugeLite
#
# display gauge using html table. Pass in int value for percentange done
#################################################################################

sub gaugeLite {
    my $done = $_[0];
    my $todo = 100 - $done;
    my $line = "<table height=100% width=100%><tr>";
    if ( $done > 0 ) {
        $line .= "<td width=$done% bgcolor=\"#00cc00\">&nbsp;</td>";
    }
    if ( $todo > 0 ) {
        $line .= "<td width=$todo% bgcolor=\"#cc0000\">&nbsp;</td>";
    }
    $line .= "</tr></table>";
    return $line;
}
#################################################################################
# gaugeTriple
#
# display gauge using html table. Pass in three int value for percentange
# done and in progress
#################################################################################

sub gaugeTriple {
    my $done       = $_[0];
    my $inprogress = $_[1];
    my $todo       = 100 - $done - $inprogress;
    my $line       = "<table height=100% width=100%><tr>";
    if ( $done > 0 ) {
        $line .= "<td width=$done% bgcolor=\"#00cc00\">&nbsp;</td>";
    }
    if ( $inprogress > 0 ) {
        $line .= "<td width=$inprogress% bgcolor=\"#ff9900\">&nbsp;</td>";
    }
    if ( $todo > 0 ) {
        $line .= "<td width=$todo% bgcolor=\"#cc0000\">&nbsp;</td>";
    }
    $line .= "</tr></table>";
    return $line;
}
#################################################################################
# gaugeFour
#
# display gauge using html table. Pass in four int values for percentange
# done and in progress
#################################################################################

sub gaugeFour {
    my $done       = $_[0];
    my $waiting    = $_[1];
    my $inprogress = $_[2];
    my $todo       = 100 - $done - $inprogress - $waiting;
    my $line       = "<table height=100% width=100%><tr>";
    if ( $done > 0 ) {
        $line .= "<td width=$done% bgcolor=\"#00cc00\">&nbsp;</td>";
    }
    if ( $waiting > 0 ) {
        $line .= "<td width=$waiting% bgcolor=\"#003399\">&nbsp;</td>";
    }
    if ( $inprogress > 0 ) {
        $line .= "<td width=$inprogress% bgcolor=\"#ff9900\">&nbsp;</td>";
    }
    if ( $todo > 0 ) {
        $line .= "<td width=$todo% bgcolor=\"#cc0000\">&nbsp;</td>";
    }
    $line .= "</tr></table>";
    return $line;
}
#################################################################################
# ppReadPlanTemplate
#
# Take $web and read PlanTemplate to figure out mapping to column
# numbers for each Task line by searching for strings
#
# maybe it should rewritten to create a hashmap from field names to
# numbers instead of global variables?
#################################################################################

sub ppReadPlanTemplate {
    my $web = $_[0];

    $col_taskname = $col_summary = $col_module = $col_dev = $col_priority =
      $col_status = $col_estdays = $col_spentdays = $col_effort =
      $col_dateadded = $col_results = 0;

    my $tmplText = &TWiki::Func::readTopic( $web, "PlanTemplate" );
    foreach my $line ( split( /\n/, $tmplText ) ) {
        if ( $line =~ /.*\|\s*\*Key\*\s*\|.*/ ) {
            $line =~ s/^\s*(.*?)\s*$/$1/;
            my @fields = split( /\|/, $line );
            my $cnt = 0;
            foreach my $field (@fields) {
                if ( $field =~ /\*Task Name\*/ ) {
                    $col_taskname = $cnt;
                }
                elsif ( $field =~ /\*Summary\*/ ) {
                    $col_summary = $cnt;
                }
                elsif ( $field =~ /\*Module\*/ ) {
                    $col_module = $cnt;
                }
                elsif (( $field =~ /\*Developer\*/ )
                    || ( $field =~ /\*Owner\*/ ) )
                {
                    $col_dev = $cnt;
                }
                elsif ( $field =~ /\*Priority\*/ ) {
                    $col_priority = $cnt;
                }
                elsif ( $field =~ /\*Status\*/ ) {
                    $col_status = $cnt;
                }
                elsif ( $field =~ /\*Est\. Days\*/ ) {
                    $col_estdays = $cnt;
                }
                elsif ( $field =~ /\*Spent Days\*/ ) {
                    $col_spentdays = $cnt;
                }
                elsif ( $field =~ /\*Est. Effort\*/ ) {
                    $col_effort = $cnt;
                }
                elsif ( $field =~ /\*Date Added\*/ ) {
                    $col_dateadded = $cnt;
                }
                elsif ( $field =~ /\*Results_Comments\*/ ) {
                    $col_results = $cnt;
                }
                $cnt++;
            }
            last;
        }
    }
}

#################################################################################
# ppFindAllProjPlans
#
# Returns a list of all (proj,plan) pairs in this web by scanning all
# text files for the Project Template: $projectname tag
#################################################################################

sub ppFindAllProjPlans {

    my $web = $_[0];
    my %allProjPlans;

    # Read in all projects in this web
    #opendir(WEB,$dataDir."/".$web);
    opendir( WEB, TWiki::Func::getDataDir() . "/" . $web );
    my @allFiles = grep { s/(.*?).txt$/$1/go } readdir(WEB);
    closedir(WEB);
    foreach my $eachF (@allFiles) {
        if ( $eachF =~ /.*PlanTemplate.*/ ) {
            next;
        }
        if ( $eachF =~ /.*ProjectTemplate.*/ ) {
            next;
        }
        my $planText = &TWiki::Func::readTopic( $web, $eachF );
        if (
            $planText =~ /.*\|.*PP Project Template.*\|.*PROJECTPLANNER.*\|.*/ )
        {
            $allProjPlans{$eachF} .= "";
        }
        if ( $planText =~ /.*\|.*PP Plan Project.*\|.*\|.*/ ) {
            $planText =~ /.*\|.*PP Plan Project.*\|\s*(\w+)\s*\|.*/;
            my $eachPr = $1;
            $allProjPlans{$eachPr} .= "$eachF;";
        }
    }

    return %allProjPlans;
}
#################################################################################
# ppBuildCache
#
# Take $web and set up the cached info
#
#################################################################################

sub ppBuildCache {
    my $web = shift;
    my ( $eachPr, $eachPl, $line, $task, $dev, @planTask, $planText, $planId );
    my $projCache = "";
    my $planCache = "";
    my ( @plans, @allPlans, @plantask );
    my $inLoop = 0;

    # Get all the Projects and their plans
    my %tempProjPlans = &ppFindAllProjPlans($web);

    foreach $eachPr ( keys %tempProjPlans ) {
        if ( $tempProjPlans{$eachPr} eq "" ) {
            $projCache .= "PROJ : $eachPr :  \n";
        }
        else {
            @plans = split( /;/, $tempProjPlans{$eachPr} );
            @allPlans = ( @allPlans, @plans );
            foreach $eachPl (@plans) {

                # assume unique project per plan
                $projCache .= "PROJ : $eachPr : $eachPl \n";
            }
        }
    }

    foreach $eachPl (@allPlans) {
        if ( &TWiki::Func::topicExists( $web, $eachPl ) ) {
            $planText = &TWiki::Func::readTopic( $web, $eachPl );

            # To go from Plan -> Task (multiple values)
            $inLoop = 0;
            $planId = "";
            foreach $line ( split( /\n/, $planText ) ) {
                if ( $line =~ /.*\|.*PP Plan Id.*\|\s*(.*?)\s*\|.*/ ) {
                    $planId = $1;
                }
                elsif ( $line =~ /.*\|\s*PPTASK\s*\|.*/ ) {
                    $inLoop   = 1;
                    @plantask = split( /\|/, $line );
                    $task     = $plantask[$col_taskname];

                    # assume each task is only in one plan
                    $dev = $plantask[$col_dev];
                    $planCache .= "PLAN : $eachPl : $planId : $task : $dev\n";
                }
                elsif ($inLoop) {

                    # If we saw PPTASK and stopped seeing it, skip
                    # rest of page
                    last;
                }
            }
        }
    }

    my $cacheText = $projCache . $planCache;
    &TWiki::Func::saveFile( $cacheFileName, $cacheText );
}

#################################################################################
# ppReadCache
#
# Read disk cache file created by ppBuildCache
#
#################################################################################
sub ppReadCache {
    my $web = shift;

    $cacheFileName = TWiki::Func::getDataDir() . "/$web/.ppcache";

    # if there is no disk cache file, build one
    if ( !( -e "$cacheFileName" ) ) {

        # &TWiki::Func::writeDebug( "NO CACHE, BUILDING DISK CACHE" );
        &ppBuildCache($web);
    }
    else {

        # if cache exists but is not most recent file, rebuild it
        # Do this by checking directory timestamp
        my @cacheStat  = stat("$cacheFileName");
        my @latestStat = stat( TWiki::Func::getDataDir() . "/$web" );

        # field 9 is the last modified timestamp
        if ( $cacheStat[9] < $latestStat[9] ) {

         # &TWiki::Func::writeDebug( "OLD CACHE $cacheStat[9] $latestStat[9]" );
            &ppBuildCache($web);
        }
    }

    # read disk cache
    my $cacheText = &TWiki::Func::readFile($cacheFileName);
    %cachedProjPlans  = ();
    %cachedIdPlans    = ();
    $cachedIdPlans{0} = "";

    my $plan;
    my $proj;
    my $task;
    my $devs;
    my $planIds;

    while ( $cacheText =~ s/PROJ : (.*?) : (.*?)\n// ) {
        $proj = $1;
        $plan = $2;
        $proj =~ s/^\s*(.*?)\s*$/$1/;
        $plan =~ s/^\s*(.*?)\s*$/$1/;
        $cachedProjPlans{$proj} .= "$plan;";
        $cachedPlanProj{$plan} = "$proj";
    }

    # drop the last ";" from each item
    foreach my $item ( keys %cachedProjPlans ) {
        chop( $cachedProjPlans{$item} );
    }

    while ( $cacheText =~ s/PLAN : (.*?) : (.*?) : (.*?) : (.*?)\n// ) {
        $plan    = $1;
        $planIds = $2;
        $task    = $3;
        $devs    = $4;

        $plan    =~ s/^\s*(.*?)\s*$/$1/;
        $planIds =~ s/^\s*(.*?)\s*$/$1/;
        $task    =~ s/^\s*(.*?)\s*$/$1/;
        $devs    =~ s/^\s*(.*?)\s*$/$1/;

        $cachedPlanTasks{$plan} .= "$task;";
        $cachedTaskPlan{$task} = "$plan";
        foreach my $dev ( split( /,/, $devs ) ) {
            $dev =~ s/^\s*(.*?)\s*$/$1/;
            $cachedDevTasks{$dev} .= "$task;";
        }

        if ( $planIds eq "" ) {
            if ( !( $cachedIdPlans{0} =~ /$plan/ ) ) {
                $cachedIdPlans{0} .= "$plan;";
            }
        }
        else {
            my @ids = split( /,/, $planIds );
            foreach my $id (@ids) {
                if ( !( $cachedIdPlans{$id} =~ /$plan/ ) ) {
                    $cachedIdPlans{$id} .= "$plan;";
                }
            }
        }
    }

    # drop the last ";" from each item
    foreach my $item ( keys %cachedPlanTasks ) {
        chop( $cachedPlanTasks{$item} );
    }

    # drop the last ";" from each item
    foreach my $item ( keys %cachedDevTasks ) {
        chop( $cachedDevTasks{$item} );
    }

}

#################################################################################
# ppSavePage
#
# save the page into Wiki Storage
#################################################################################

sub ppSavePage() {
    my ($web) = @_;

    my $title    = $query->param('topic');
    my $template = $query->param('templatetopic');
    my $summary  = $query->param('summary');
    my $id       = $query->param('id');

    # check the user has entered a non-null string
    if ( $title eq "" ) {
        TWiki::Func::redirectCgiQuery( $query,
            &TWiki::Func::getViewUrl( $web, "NewPageError" ) );
        return;
    }

    # check topic does not already exist
    if ( TWiki::Func::topicExists( $web, $title ) ) {
        TWiki::Func::redirectCgiQuery( $query,
            &TWiki::Func::getViewUrl( $web, "NewPageError" ) );
        return;
    }

    # check the user has entered a WIKI name
    if ( !TWiki::isWikiName($title) ) {
        TWiki::Func::redirectCgiQuery( $query,
            &TWiki::Func::getViewUrl( $web, "NewPageError" ) );
        return;
    }

    # we do not use this anymore. Instead we grep for Project Template
    # | PROJECTPLANNER to find all projects
    # if creating a Project, check name ends in *Project

#     if($template eq "ProjectTemplate") {
#         if(!($title =~ /^[\w]*PPProject$/)) {
#             TWiki::Func::redirectCgiQuery( $query, &TWiki::Func::getViewUrl( "", "NewPageError" ) );
#             return;
#         }
#     }

    # load template for page type requested
    my ($text) = &TWiki::Func::readTopicText( $web, $template );

    # write parent name into page
    my $parent = $query->param('topicparent');
    $text =~ s/PPPARENTPAGE/$parent/geo;
    $text =~ s/PPSUMMARY/$summary/geo;
    $text =~ s/PPID/$id/geo;

    # save new page and open in browser
    my $error = &TWiki::Func::saveTopicText( $web, $title, $text );
    TWiki::Func::redirectCgiQuery( $query,
        &TWiki::Func::getViewUrl( $web, $title ) );

    &TWiki::Func::setTopicEditLock( $web, $title, "on" );
    if ($error) {
        my $url =
          &TWiki::Func::getOopsUrl( $web, $title, "oopssaveerr", $error );
        TWiki::Func::redirectCgiQuery( $query, $url );
    }

}

#################################################################################
# ppCreateHtmlForm
#
# Make form to create new subtype
#################################################################################

sub ppCreateHtmlForm {

    my ( $type, $template, $prompt ) = @_;
    my $list = "";

    # append form for new page creation
    $list .= "<p>\n";
    $list .= "<form name=\"new\">\n";
    $list .= "$type Name: <input type=\"text\" name=\"topic\" size=\"20\" />\n";
    $list .= "ID(s): <input type=\"text\" name=\"id\" size=\"40\" /><br>\n";
    $list .=
      "$type Summary: <input type=\"text\" name=\"summary\" size=\"40\" />\n";
    $list .=
        "<input type=\"hidden\" name=\"templatetopic\" value=\""
      . $template
      . "\" />\n";
    $list .=
      "<input type=\"hidden\" name=\"topicparent\" value=\"%TOPIC%\" />\n";
    $list .=
      "<input type=\"submit\" name =\"ppsave\" value=\"" . $prompt . "\" />\n";
    $list .= "</form>\n";
    $list .= "\n";

    return $list;
}

#################################################################################
# ppFindMatchingProjects
#
# Get all the projects which match a comma separated list of regexp projects
#################################################################################

sub ppFindMatchingProjects {

    my @projList = ();

    # handle default null case quickly
    if ( $_[0] eq "" ) {
        @projList = keys %cachedProjPlans;
        return @projList;
    }

    my @inputList = split( /,/, $_[0] );
    my $projStr = "";

    foreach my $inpRE (@inputList) {
        $inpRE =~ s/^\s*(.*?)\s*$/$1/;
        if ( $inpRE =~ /\*/ ) {
            $inpRE =~ s/\*/\.\*/g;
            foreach my $matchP ( keys %cachedProjPlans ) {
                $matchP =~ s/^\s*(.*?)\s*$/$1/;
                if ( ( $matchP =~ /$inpRE/ ) && !( $projStr =~ /$matchP/ ) ) {
                    @projList = ( @projList, "$matchP" );
                    $projStr .= "$matchP;";
                }
            }
        }
        else {
            my @commaList = split( /,/, $inpRE );
            @projList = ( @projList, @commaList );
        }
    }

    return @projList;
}

#################################################################################
# ppFindMatchingPlans
#
# Get all the plans which match a comma separated list of regexp projects
#################################################################################

sub ppFindMatchingPlans {

    my @planList = ();

    # handle default null case quickly
    if ( $_[0] eq "" ) {
        @planList = keys %cachedPlanProj;
        return @planList;
    }

    my @inputList = split( /,/, $_[0] );
    my $planStr = "";

    foreach my $inpRE (@inputList) {
        if ( $inpRE =~ /\*/ ) {
            $inpRE =~ s/\*/\.\*/g;
            foreach my $matchP ( keys %cachedPlanProj ) {
                if ( ( $matchP =~ /$inpRE/ ) && !( $planStr =~ /$matchP/ ) ) {
                    @planList = ( @planList, "$matchP" );
                    $planStr .= "$matchP;";
                }
            }
        }
        else {
            my @commaList = split( /,/, $inpRE );
            @planList = ( @planList, @commaList );
        }
    }

    return @planList;
}

#################################################################################
# ppFindMatchingTasks (plan, regexp)
#
# Get all the tasks which match the regexp in a given plan
#################################################################################

sub ppFindMatchingTasks {
    my ( $plan, $taskexp ) = @_;
    my $taskStr;

    # handle default null case quickly
    if ( $plan eq "" ) {
        return "";
    }

    if ( $taskexp eq "" ) {
        return ( split( /;/, $cachedPlanTasks{$plan} ) );
    }

    my @inputList = split( /,/, $taskexp );
    my @taskArr = ();

    foreach my $inpRE (@inputList) {
        if ( $inpRE =~ /\*/ ) {
            $inpRE =~ s/\*/\.\*/g;
            foreach my $matchP ( split( /;/, $cachedPlanTasks{$plan} ) ) {
                if ( ( $matchP =~ /^$inpRE$/ ) && !( $taskStr =~ /$matchP/ ) ) {
                    push @taskArr, $matchP;
                }
            }
        }
        else {
            push @taskArr, $inpRE;
        }
    }

    return @taskArr;
}

#################################################################################
# ppAllProjects
#
# Shows all the projects on this web
#################################################################################

sub ppAllProjects {

    my ($web) = @_;

    my @projects = keys %cachedProjPlans;

    my $list = "<h3>All projects</h3>\n\n";
    $list .= "| *Project* | *Summary* |\n";

    foreach my $project (@projects) {
        my $summary = "";
        if ( &TWiki::Func::topicExists( $web, $project ) ) {
            my $projText = &TWiki::Func::readTopic( $web, $project );
            if ( $projText =~ /.*\|.*PP Project Summary.*\|.*\|.*/ ) {
                $projText =~ /.*\|.*PP Project Summary.*\|(.*?)\|.*/;
                $summary = "$1";
                $summary =~ s/^\s*(.*?)\s*$/$1/;
            }
        }
        $list .= "| $project | $summary | \n";
    }

    if ( &TWiki::Func::topicExists( $web, "ProjectTemplate" ) ) {

        # append form to allow creation of new projects
        $list .= &ppCreateHtmlForm( "Project", "ProjectTemplate",
            "Create new project" );
    }
    else {
        $list .=
"Error: Could not find ProjectTemplate topic. Did you forget to copy it to this web?\n";
    }
    return $list;
}

#################################################################################
# ppProjectPlansNewForm
#
# Show all plans for a project with appropriate status info.
# Has a form to create a new plan at the bottom.
#
#################################################################################

sub ppProjectPlansNewForm {

    my ( $project, $web ) = @_;
    my $projDoneTasks  = 0;
    my $projTotalTasks = 0;
    my $projEstDays    = 0;
    my $projSpentDays  = 0;
    my %projModuleTotal;
    my %projModuleDone;
    my %projModuleInP;
    my %projModuleWait;
    my %projModuleNS;
    my %prioTotal;
    my %prioDone;
    my %prioInP;
    my %prioWait;
    my %prioNS;

    my ( $summary, $ids, $planText );

    my $list = "<h3>All plans for project $project</h3>\n\n";
    $list .=
"| *Plan* | *Summary* | *Status By Tasks* | *Done Tasks* | *Total Tasks* | *Status By Days* | *Spent Days* | *Estimated Days* | \n";
    foreach my $eachPl ( split( /;/, $cachedProjPlans{$project} ) ) {
        if ( &TWiki::Func::topicExists( $web, $eachPl ) ) {
            $planText = &TWiki::Func::readTopic( $web, $eachPl );
            $summary = "";
            if ( $planText =~ /.*\|.*PP Plan Summary.*\|.*\|.*/ ) {
                $planText =~ /.*\|.*PP Plan Summary.*\|(.*?)\|.*/;
                $summary = "$1";
                $summary =~ s/^\s*(.*?)\s*$/$1/;
            }
            $ids = "";
            if ( $planText =~ /.*\|.*PP Plan Id.*\|.*\|.*/ ) {
                $planText =~ /.*\|.*PP Plan Id.*\|\s*(.*?)\s*\|.*/;
                $ids = "$1";
                if ( $ids ne "" ) {
                    $ids = convertPlanIdsToUrl($ids);
                }
            }

            # To go from Plan -> Task (multiple values)
            my $line;
            my $totalTasks      = 0;
            my $doneTasks       = 0;
            my $inProgressTasks = 0;
            my $waitingTasks    = 0;
            my $totalDays       = 0;
            my $doneDays        = 0;
            my $inProgressDays  = 0;
            my $waitingDays;

            foreach $line ( split( /\n/, $planText ) ) {
                if ( $line =~ /.*\|\s*PPTASK\s*\|.*/ ) {
                    $totalTasks++;
                    my @plantask = split( /\|/, $line );
                    $totalDays += int $plantask[$col_estdays];
                    $projModuleTotal{ $plantask[$col_module] } +=
                      int $plantask[$col_estdays];
                    $prioTotal{ $plantask[$col_priority] } +=
                      int $plantask[$col_estdays];
                    if (   ( $plantask[$col_status] =~ /.*[d|D]one.*/ )
                        || ( $plantask[$col_status] =~ /.*[c|C]ancelled.*/ ) )
                    {
                        $doneTasks++;

                        #assume spent days not accurate sp Spent=Est
                        $doneDays += int $plantask[$col_estdays];
                        $projModuleDone{ $plantask[$col_module] } +=
                          int $plantask[$col_estdays];
                        $prioDone{ $plantask[$col_priority] } +=
                          int $plantask[$col_estdays];
                    }
                    elsif (
                        $plantask[$col_status] =~ /.*[i|I]n [p|P]rogress.*/ )
                    {
                        $inProgressTasks++;
                        $inProgressDays += $plantask[$col_spentdays];
                        $projModuleInP{ $plantask[$col_module] } +=
                          int $plantask[$col_spentdays];
                        $prioInP{ $plantask[$col_priority] } +=
                          int $plantask[$col_spentdays];
                    }
                    elsif ( $plantask[$col_status] =~ /.*[w|W]aiting.*/ ) {
                        $waitingTasks++;
                        $waitingDays += $plantask[$col_spentdays];
                        $projModuleWait{ $plantask[$col_module] } +=
                          int $plantask[$col_spentdays];
                        $prioWait{ $plantask[$col_priority] } +=
                          int $plantask[$col_spentdays];
                    }
                    else {
                        $projModuleNS{ $plantask[$col_module] } +=
                          int $plantask[$col_estdays];
                        $prioNS{ $plantask[$col_priority] } +=
                          int $plantask[$col_estdays];
                    }
                }
            }
            my $taskDonePer       = 0;
            my $taskInProgressPer = 0;
            my $taskWaitingPer    = 0;
            if ( $totalTasks > 0 ) {
                $taskDonePer = int( 100.0 * $doneTasks / $totalTasks );
                $taskInProgressPer =
                  int( 100.0 * $inProgressTasks / $totalTasks );
                $taskWaitingPer = int( 100.0 * $waitingTasks / $totalTasks );
            }

            my $daysDonePer       = 0;
            my $daysInProgressPer = 0;
            my $daysWaitingPer    = 0;
            if ( $totalDays > 0 ) {
                $daysDonePer = int( 100.0 * $doneDays / $totalDays );
                $daysInProgressPer =
                  int( 100.0 * $inProgressDays / $totalDays );
                $daysWaitingPer = int( 100.0 * $waitingDays / $totalDays );
            }
            $list .= "| $eachPl $ids |$summary |";
            $list .=
              gaugeFour( $taskDonePer, $taskWaitingPer, $taskInProgressPer );
            $list .= "|   $doneTasks|   $totalTasks|";
            $list .=
              gaugeFour( $daysDonePer, $daysWaitingPer, $daysInProgressPer );
            my $totalSpentDays =
              int( $doneDays + $inProgressDays + $waitingDays );
            $list .= "|    $totalSpentDays|   $totalDays| \n";

            #collect stats for full project
            $projDoneTasks  += $doneTasks;
            $projTotalTasks += $totalTasks;
            $projEstDays    += $totalDays;
            $projSpentDays  += $totalSpentDays;
        }
        else {
            $list .= "|$eachPl | | | | | | | | \n";
        }
    }
    $list .=
      "| | | |<b>Done:   $projDoneTasks</b>|<b>Total:   $projTotalTasks</b>|";
    my $projSpentPer;
    if ( $projEstDays > 0 ) {
        $projSpentPer = int( 100.0 * $projSpentDays / $projEstDays );
    }
    $list .= gaugeLite($projSpentPer);
    $list .=
"|     <b>Total Spent: $projSpentDays</b>|     <b>Total Estimated: $projEstDays</b>| \n";

    # Build list of modules with data
    my %mods;
    foreach my $m ( keys %projModuleDone ) { $mods{$m} = 1; }
    foreach my $m ( keys %projModuleInP )  { $mods{$m} = 1; }
    foreach my $m ( keys %projModuleWait ) { $mods{$m} = 1; }
    foreach my $m ( keys %projModuleNS )   { $mods{$m} = 1; }

    $list .= "| | | | | *Module* | | | |\n";

    foreach my $m ( keys %mods ) {
        my $done = 0;
        $done += $projModuleDone{$m};
        my $wait = 0;
        $wait += $projModuleWait{$m};
        my $inP = 0;
        $inP += $projModuleInP{$m};
        my $total = 0;
        $total = int $projModuleTotal{$m};
        my $spent = $done + $wait + $inP;

        if ( $total > 0 ) {
            my $doneper = int( $done * 100 / $total );
            my $waitper = int( $wait * 100 / $total );
            my $inPper  = int( $inP * 100 / $total );
            $list .= "| | | | | <b>$m</b> |";
            $list .= gaugeFour( $doneper, $waitper, $inPper );
            $list .= "|     <b>$spent</b>|     <b>$total</b>| \n";
        }
    }

    # Build list of priorities with data
    my %prios;
    foreach my $p ( keys %prioDone ) { $prios{$p} = 1; }
    foreach my $p ( keys %prioInP )  { $prios{$p} = 1; }
    foreach my $p ( keys %prioWait ) { $prios{$p} = 1; }
    foreach my $p ( keys %prioNS )   { $prios{$p} = 1; }
    $list .= "| | | | | *Priority* | | | |\n";
    foreach my $p ( keys %prios ) {
        my $done = 0;
        $done += $prioDone{$p};
        my $wait = 0;
        $wait += $prioWait{$p};
        my $inP = 0;
        $inP += $prioInP{$p};
        my $total = 0;
        $total = int $prioTotal{$p};
        my $spent = $done + $wait + $inP;

        if ( $total > 0 ) {
            my $doneper = int( $done * 100 / $total );
            my $waitper = int( $wait * 100 / $total );
            my $inPper  = int( $inP * 100 / $total );
            $list .= "| | | | | <b>$p</b> |";
            $list .= gaugeFour( $doneper, $waitper, $inPper );
            $list .= "|     <b>$spent</b>|     <b>$total</b>| \n";
        }
    }

    if ( &TWiki::Func::topicExists( $web, "PlanTemplate" ) ) {

        # append form to allow creation of new plans
        $list .= &ppCreateHtmlForm( "Plan", "PlanTemplate", "Create new plan" );
    }
    else {
        $list .=
"Error: Could not find PlanTemplate topic. Did you forget to copy it to this web?\n";
    }

    return $list;
}

#################################################################################
# ppAllProjectsPlans
#
# Show all plans for a list of comma separated projects with appropriate status info
#################################################################################

sub ppAllProjectPlans {

    my ( $projList, $web ) = @_;
    my @projects;

    @projects = ppFindMatchingProjects($projList);

    my ( $summary, $ids, $planText, @plantask );
    my $allEstDays    = 0;
    my $allSpentDays  = 0;
    my $allDoneTasks  = 0;
    my $allTotalTasks = 0;

    my $list = "<h3>All plans for projects @projects</h3>\n\n";
    $list .=
"| *Project* | *Plan* | *Summary* | *Status By Tasks* | *Done Tasks* | *Total Tasks* | *Status By Days* | *Spent Days* | *Estimated Days* | \n";
    foreach my $eachPr (@projects) {
        my $proj           = $eachPr;
        my $projDoneTasks  = 0;
        my $projTotalTasks = 0;
        my $projEstDays    = 0;
        my $projSpentDays  = 0;
        if ( $cachedProjPlans{$eachPr} eq "" ) {
            $list .=
"| $eachPr | | | | | | <b>Total Spent:  $projSpentDays </b>|<b>Total Est:  $projEstDays </b>| \n";
            next;
        }
        foreach my $eachPl ( split( /;/, $cachedProjPlans{$eachPr} ) ) {
            if ( &TWiki::Func::topicExists( $web, $eachPl ) ) {
                $planText = &TWiki::Func::readTopic( $web, $eachPl );
                $summary = "";
                if ( $planText =~ /.*\|.*PP Plan Summary.*\|.*\|.*/ ) {
                    $planText =~ /.*\|.*PP Plan Summary.*\|(.*?)\|.*/;
                    $summary = "$1";
                    $summary =~ s/^\s*(.*?)\s*$/$1/;
                }
                $ids = "";
                if ( $planText =~ /.*\|.*PP Plan Id.*\|.*\|.*/ ) {
                    $planText =~ /.*\|.*PP Plan Id.*\|\s*(.*?)\s*\|.*/;
                    $ids = "$1";
                    if ( $ids ne "" ) {
                        $ids = convertPlanIdsToUrl($ids);
                    }
                }

                # To go from Plan -> Task (multiple values)
                my $line;
                my $totalTasks      = 0;
                my $doneTasks       = 0;
                my $inProgressTasks = 0;
                my $waitingTasks    = 0;
                my $totalDays       = 0;
                my $doneDays        = 0;
                my $inProgressDays  = 0;
                my $waitingDays     = 0;
                my $inLoop          = 0;
                foreach $line ( split( /\n/, $planText ) ) {

                    if ( $line =~ /.*\|\s*PPTASK\s*\|.*/ ) {
                        $inLoop = 1;
                        $totalTasks++;
                        @plantask = split( /\|/, $line );
                        $totalDays += int $plantask[$col_estdays];
                        if (   ( $plantask[$col_status] =~ /.*[d|D]one.*/ )
                            || ( $plantask[$col_status] =~ /.*[c|C]ancelled.*/ )
                          )
                        {
                            $doneTasks++;

                            #assume spent days not accurate sp Spent=Est
                            $doneDays += int $plantask[$col_estdays];
                        }
                        elsif ( $plantask[$col_status] =~
                            /.*[i|I]n [p|P]rogress.*/ )
                        {
                            $inProgressTasks++;
                            $inProgressDays += $plantask[$col_spentdays];
                        }
                        elsif ( $plantask[$col_status] =~ /.*[w|W]aiting.*/ ) {
                            $waitingTasks++;
                            $waitingDays += $plantask[$col_spentdays];
                        }
                    }
                    elsif ($inLoop) {
                        last;
                    }
                }
                my $taskDonePer       = 100;
                my $taskInProgressPer = 0;
                my $taskWaitingPer    = 0;
                if ( $totalTasks > 0 ) {
                    $taskDonePer = int( 100.0 * $doneTasks / $totalTasks );
                    $taskInProgressPer =
                      int( 100.0 * $inProgressTasks / $totalTasks );
                    $taskWaitingPer =
                      int( 100.0 * $waitingTasks / $totalTasks );
                }

                my $daysDonePer       = 100;
                my $daysInProgressPer = 0;
                my $daysWaitingPer    = 0;
                if ( $totalDays > 0 ) {
                    $daysDonePer = int( 100.0 * $doneDays / $totalDays );
                    $daysInProgressPer =
                      int( 100.0 * $inProgressDays / $totalDays );
                    $daysWaitingPer = int( 100.0 * $waitingDays / $totalDays );
                }
                $list .= "| $proj | $eachPl $ids |$summary |";
                $list .= gaugeFour( $taskDonePer, $taskWaitingPer,
                    $taskInProgressPer );
                $list .= "|   $doneTasks|   $totalTasks|";
                $list .= gaugeFour( $daysDonePer, $daysWaitingPer,
                    $daysInProgressPer );
                my $totalSpentDays =
                  int( $doneDays + $inProgressDays + $waitingDays );
                $list .= "|   $totalSpentDays|   $totalDays| \n";

                #collect stats for full project
                $projDoneTasks  += $doneTasks;
                $projTotalTasks += $totalTasks;
                $projEstDays    += $totalDays;
                $projSpentDays  += $totalSpentDays;
            }
            else {
                $list .= "|$proj | $eachPl | | | | | | |\n";
            }
            $proj = "";    # print Project only for first Plan line
        }
        $list .=
"| | | | |<b>Done:   $projDoneTasks</b>|<b>Total:   $projTotalTasks</b>|";
        if ( $projEstDays > 0 ) {
            my $projSpentPer = int( 100.0 * $projSpentDays / $projEstDays );
            $list .= gaugeLite($projSpentPer);
        }
        else {
            $list .= " ";
        }
        $list .=
"|<b>Total Spent:  $projSpentDays </b>|<b>Total Est: $projEstDays </b>| \n";

#$list .= "| | | | | |<b>Total Est:  $projEstDays </b>|<b>Total Spent:  $projSpentDays </b>| \n";
        $allEstDays    += $projEstDays;
        $allSpentDays  += $projSpentDays;
        $allDoneTasks  += $projDoneTasks;
        $allTotalTasks += $projTotalTasks;
    }
    $list .=
      "| | | | |<b>Done:  $allDoneTasks</b>|<b>Total:  $allTotalTasks</b>|";
    if ( $allEstDays > 0 ) {
        my $allSpentPer = int( 100.0 * $allSpentDays / $allEstDays );
        $list .= gaugeLite($allSpentPer);
    }
    else {
        $list .= " ";
    }
    $list .=
"|<b>Total Spent:  $allSpentDays </b>|<b>Total Estimated: $allEstDays </b>| \n";
    return $list;
}

#################################################################################
# ppAllPlans
#
# Show all plans for all projects
#################################################################################

sub ppAllPlans {

    my ( $project, $web ) = @_;

    my $list = "<h3>All plans</h3>\n\n";
    $list .= "| *Project* | *Plans* | \n";
    foreach my $eachPr ( keys %cachedProjPlans ) {
        my $proj = $eachPr;    # print project only for first plan
        foreach my $eachPl ( split( /;/, $cachedProjPlans{$eachPr} ) ) {
            $list .= "| $proj | $eachPl | \n";
            $proj = "";        # print project only for first plan
        }
    }

    return $list;
}

#################################################################################
# ppAllPlansTasksSummary
#
# Show the summary status for a list of plans and tasks subset
#################################################################################

sub ppAllPlansTasksSummary {

    my ( $planList, $web ) = @_;
    my @allPlans;
    my %allPlansTasks = ();
    my $list          = "";

    foreach my $planandtask ( split( /,/, $planList ) ) {
        my $planExp;
        my $taskListExp;
        ( $planExp, $taskListExp ) = split( /:/, $planandtask );
        my @planList = ppFindMatchingPlans($planExp);
        foreach my $plan (@planList) {
            my @matches = ppFindMatchingTasks( $plan, $taskListExp );
            my @new;
            if ( ( $#{ $allPlansTasks{$plan} } ) >= 0 ) {
                push @new, ( @{ $allPlansTasks{$plan} }, @matches );
            }
            else {
                @new = @matches;
            }
            $allPlansTasks{$plan} = [@new];
            &TWiki::Func::writeDebug(
                "$plan: matches:@matches new:@{$allPlansTasks{$plan}}\n")
              if $debug;
        }
    }

    my ( $summary, $ids, $planText, @plantask );

    $list .= "<h3>Summary for plans and tasks for ";
    foreach my $printP ( split /,/, $planList ) {
        $list .= "$printP, ";
    }
    chop($list);
    chop($list);
    $list .= "</h3>\n\n";
    $list .=
"| *Plan* | *Summary* | *Project* | *Status By Tasks* | *Done Tasks* | *Total Tasks* | *Status By Days* | *Spent Days* | *Total Est Days* |\n";
    my $summaryEstDays   = 0;
    my $summarySpentDays = 0;
    my $summaryTasks     = 0;
    my $summaryDoneTasks = 0;
    my %moduleTotal;
    my %moduleDone;
    my %moduleInP;
    my %moduleWait;
    my %moduleNS;
    my %prioTotal;
    my %prioDone;
    my %prioInP;
    my %prioWait;
    my %prioNS;

    foreach my $eachPl ( keys %allPlansTasks ) {
        my $proj = $cachedPlanProj{$eachPl};
        my @matchTasks;
        if ( ( $#{ $allPlansTasks{$eachPl} } ) < 0 ) {
            $list .= "|$eachPl | No Info | $proj | | | | | | | \n";
            next;
        }
        push @matchTasks, @{ $allPlansTasks{$eachPl} };
        if ( &TWiki::Func::topicExists( $web, $eachPl ) ) {
            $planText = &TWiki::Func::readTopic( $web, $eachPl );
            $summary = "";
            if ( $planText =~ /.*\|.*PP Plan Summary.*\|.*\|.*/ ) {
                $planText =~ /.*\|.*PP Plan Summary.*\|(.*?)\|.*/;
                $summary = "$1";
                $summary =~ s/^\s*(.*?)\s*$/$1/;
            }
            $ids = "";
            if ( $planText =~ /.*\|.*PP Plan Id.*\|.*\|.*/ ) {
                $planText =~ /.*\|.*PP Plan Id.*\|\s*(.*?)\s*\|.*/;
                $ids = "$1";
                if ( $ids ne "" ) {
                    $ids = convertPlanIdsToUrl($ids);
                }
            }

            # To go from Plan -> Task (multiple values)
            my $line;
            my $totalTasks      = 0;
            my $doneTasks       = 0;
            my $inProgressTasks = 0;
            my $waitingTasks    = 0;
            my $totalDays       = 0;
            my $doneDays        = 0;
            my $inProgressDays  = 0;
            my $waitingDays     = 0;
            foreach $line ( split( /\n/, $planText ) ) {

                if ( $line =~ /.*\|\s*PPTASK\s*\|.*/ ) {
                    @plantask = split( /\|/, $line );

                    # only if this task is in the list of tasks we are matching
                    my $taskname = $plantask[$col_taskname];
                    $taskname =~ s/^\s*(.*?)\s*$/$1/;
                    my $matched = 0;
                    foreach my $mt (@matchTasks) {
                        if ( $taskname eq $mt ) {
                            $matched = 1;
                            last;
                        }
                    }
                    if ($matched) {
                        &TWiki::Func::writeDebug("T: $eachPl:  $taskname ")
                          if ($debug);
                        $totalTasks++;
                        $totalDays += int $plantask[$col_estdays];
                        $moduleTotal{ $plantask[$col_module] } +=
                          int $plantask[$col_estdays];
                        $prioTotal{ $plantask[$col_priority] } +=
                          int $plantask[$col_estdays];

                        if (   ( $plantask[$col_status] =~ /.*[d|D]one.*/ )
                            || ( $plantask[$col_status] =~ /.*[c|C]ancelled.*/ )
                          )
                        {
                            $doneTasks++;

                            #assume spent days not accurate sp Spent=Est
                            $doneDays += int $plantask[$col_estdays];
                            $moduleDone{ $plantask[$col_module] } +=
                              int $plantask[$col_estdays];
                            $prioDone{ $plantask[$col_priority] } +=
                              int $plantask[$col_estdays];
                        }
                        elsif ( $plantask[$col_status] =~
                            /.*[i|I]n [p|P]rogress.*/ )
                        {
                            $inProgressTasks++;
                            $inProgressDays += $plantask[$col_spentdays];
                            $moduleInP{ $plantask[$col_module] } +=
                              int $plantask[$col_spentdays];
                            $prioInP{ $plantask[$col_priority] } +=
                              int $plantask[$col_spentdays];
                        }
                        elsif ( $plantask[$col_status] =~ /.*[w|W]aiting.*/ ) {
                            $waitingTasks++;
                            $waitingDays += $plantask[$col_spentdays];
                            $moduleWait{ $plantask[$col_module] } +=
                              int $plantask[$col_spentdays];
                            $prioWait{ $plantask[$col_priority] } +=
                              int $plantask[$col_spentdays];
                        }
                        else {
                            $moduleNS{ $plantask[$col_module] } +=
                              int $plantask[$col_estdays];
                            $prioNS{ $plantask[$col_priority] } +=
                              int $plantask[$col_estdays];
                        }
                    }
                }
            }
            my $taskDonePer       = 100;
            my $taskInProgressPer = 0;
            my $taskWaitingPer    = 0;
            if ( $totalTasks > 0 ) {
                $taskDonePer = int( 100.0 * $doneTasks / $totalTasks );
                $taskInProgressPer =
                  int( 100.0 * $inProgressTasks / $totalTasks );
                $taskWaitingPer = int( 100.0 * $waitingTasks / $totalTasks );
            }

            my $daysDonePer       = 100;
            my $daysInProgressPer = 0;
            my $daysWaitingPer    = 0;
            if ( $totalDays > 0 ) {
                $daysDonePer = int( 100.0 * $doneDays / $totalDays );
                $daysInProgressPer =
                  int( 100.0 * $inProgressDays / $totalDays );
                $daysWaitingPer = int( 100.0 * $waitingDays / $totalDays );
            }
            $list .= "| $eachPl $ids | $summary | $proj |";
            $list .=
              gaugeFour( $taskDonePer, $taskWaitingPer, $taskInProgressPer );
            $list .= "|   $doneTasks|   $totalTasks|";
            $list .=
              gaugeFour( $daysDonePer, $daysWaitingPer, $daysInProgressPer );
            my $totalSpentDays = $doneDays + $inProgressDays + $waitingDays;
            $list .= "|   $totalSpentDays|   $totalDays| \n";

            #collect stats for all plans
            $summaryTasks     += $totalTasks;
            $summaryDoneTasks += $doneTasks;
            $summaryEstDays   += $totalDays;
            $summarySpentDays += $totalSpentDays;
        }
        else {
            $list .= "|$eachPl | No Info | $proj | | | | | | | \n";
        }
    }
    my $summaryDonePer = 0;
    if ( $summaryTasks > 0 ) {
        $summaryDonePer = int( 100.0 * $summaryDoneTasks / $summaryTasks );
    }
    $list .= "| | | |";
    $list .= gaugeLite($summaryDonePer);
    $list .= "|<b>Done:   $summaryDoneTasks</b>|<b>Total:   $summaryTasks</b>|";
    if ( $summaryEstDays > 0 ) {
        my $summarySpentPer =
          int( 100.0 * $summarySpentDays / $summaryEstDays );
        $list .= gaugeLite($summarySpentPer);
    }
    else {
        $list .= " ";
    }
    $list .=
"|<b>Total Spent:  $summarySpentDays </b>|<b>Total Estimated:  $summaryEstDays </b>| \n";

    # Build list of modules with data
    my %mods;
    foreach my $m ( keys %moduleDone ) { $mods{$m} = 1; }
    foreach my $m ( keys %moduleInP )  { $mods{$m} = 1; }
    foreach my $m ( keys %moduleWait ) { $mods{$m} = 1; }
    foreach my $m ( keys %moduleNS )   { $mods{$m} = 1; }
    $list .= "| | | | | | *Module* | | | |\n";
    foreach my $m ( keys %mods ) {
        my $done = 0;
        $done += $moduleDone{$m};
        my $wait = 0;
        $wait += $moduleWait{$m};
        my $inP = 0;
        $inP += $moduleInP{$m};
        my $total = 0;
        $total = int $moduleTotal{$m};
        my $spent = $done + $wait + $inP;

        if ( $total > 0 ) {
            my $doneper = int( $done * 100 / $total );
            my $waitper = int( $wait * 100 / $total );
            my $inPper  = int( $inP * 100 / $total );
            $list .= "| | | | | | <b>$m</b> |";
            $list .= gaugeFour( $doneper, $waitper, $inPper );
            $list .= "|     <b>$spent</b>|     <b>$total</b>| \n";
        }
    }

    # Build list of priorities with data
    my %prios;
    foreach my $p ( keys %prioDone ) { $prios{$p} = 1; }
    foreach my $p ( keys %prioInP )  { $prios{$p} = 1; }
    foreach my $p ( keys %prioWait ) { $prios{$p} = 1; }
    foreach my $p ( keys %prioNS )   { $prios{$p} = 1; }
    $list .= "| | | | | | *Priority* | | | |\n";
    foreach my $p ( keys %prios ) {
        my $done = 0;
        $done += $prioDone{$p};
        my $wait = 0;
        $wait += $prioWait{$p};
        my $inP = 0;
        $inP += $prioInP{$p};
        my $total = 0;
        $total = int $prioTotal{$p};
        my $spent = $done + $wait + $inP;

        if ( $total > 0 ) {
            my $doneper = int( $done * 100 / $total );
            my $waitper = int( $wait * 100 / $total );
            my $inPper  = int( $inP * 100 / $total );
            $list .= "| | | | | | <b>$p</b> |";
            $list .= gaugeFour( $doneper, $waitper, $inPper );
            $list .= "|     <b>$spent</b>|     <b>$total</b>| \n";
        }
    }
    return $list;
}

#################################################################################
# ppGetProjectTasks
#
# Show all tasks for all plans for a project
#################################################################################

sub ppGetProjectTasks {

    my ( $project, $web ) = @_;
    my $list;
    my $line;
    my $inLoop;
    my $planText;
    my @plantask;

    if ( $cachedProjPlans{$project} eq "" ) {
        $list = "| $project | | | | | | | | | | |\n";
        return $list;
    }
    my $proj = $project;    # print project only for first plan
    foreach my $eachPl ( split( /;/, $cachedProjPlans{$project} ) ) {
        if ( &TWiki::Func::topicExists( $web, $eachPl ) ) {
            $planText = &TWiki::Func::readTopic( $web, $eachPl );
            $planText =~ /.*\|.*PP Plan Id.*\|\s*(.*?)\s*\|.*/;
            my $ids = "$1";
            if ( $ids ne "" ) {
                $ids = convertPlanIdsToUrl($ids);
            }

            $list .= "| $proj | $eachPl $ids | | | | | | | | | |\n";
            $proj = "";

            # To go from Plan -> Task (multiple values)
            $inLoop = 0;
            foreach $line ( split( /\n/, $planText ) ) {
                if ( $line =~ /.*\|\s*PPTASK\s*\|.*/ ) {
                    $inLoop = 1;
                    @plantask = split( /\|/, $line );
                    if (   ( $plantask[$col_status] =~ /[dD]one/ )
                        && ( $plantask[$col_module] =~ /dirtest/ ) )
                    {
                        $list .=
"| | | $plantask[$col_taskname] | $plantask[$col_summary] | $plantask[$col_dev] | $plantask[$col_module] | $plantask[$col_status] | $plantask[$col_priority] | $plantask[$col_estdays] | $plantask[$col_spentdays] | ";
                        $list .=
                          convertResultsToUrl( $plantask[$col_results], 0,
                            $plantask[$col_module] );
                        $list .= " |\n";
                    }
                    else {
                        $list .=
"| | | $plantask[$col_taskname] | $plantask[$col_summary] | $plantask[$col_dev] | $plantask[$col_module] | $plantask[$col_status] | $plantask[$col_priority] | $plantask[$col_estdays] | $plantask[$col_spentdays] | $plantask[$col_results] |\n";
                    }
                }
                elsif ($inLoop) {

      # we already saw PPTASK so if we stopped seeing it we reached end of table
                    last;
                }
            }
        }
        else {
            $list .= "| $proj | $eachPl | | | | | | | | | |\n";
            $proj = "";
        }
    }

    return $list;
}

#################################################################################
# ppAllProjectTasks
#
# Show all tasks for all plans for all projects in a comma separated list
#################################################################################

sub ppAllProjectTasks {

    my ( $projList, $web ) = @_;
    my @projects;

    @projects = ppFindMatchingProjects($projList);

    my $list = "<h3>All plans and tasks for all projects @projects</h3>\n\n";
    $list .=
"| *Project* | *Plan* | *Task* | *Summary* | *Developer* | *Module* | *Status* | *Priority* | *Est Days* | *Spent Days* | *Results_Comments* |\n";

    foreach my $eachPr (@projects) {
        $list .= &ppGetProjectTasks( $eachPr, $web );
    }

    return $list;
}

#################################################################################
# ppGetProjectInfo
#
# Show all tasks and the info for task if it exists for all plans for a project
#################################################################################

sub ppGetProjectInfo {

    my ( $project, $web ) = @_;
    my ( $list, $line, $planText, @plantask, $taskText );
    my $inLoop = 0;

    foreach my $eachPl ( split( /;/, $cachedProjPlans{$project} ) ) {
        if ( &TWiki::Func::topicExists( $web, $eachPl ) ) {
            $planText = &TWiki::Func::readTopic( $web, $eachPl );
            $inLoop = 0;
            $planText =~ /.*\|.*PP Plan Id.*\|\s*(.*?)\s*\|.*/;
            my $ids = "$1";
            if ( $ids ne "" ) {
                $ids = "($ids)";
            }
            $list .= "<b>PLAN</b> <nop>$eachPl $ids<br><br>";

            # To go from Plan -> Task (multiple values)
            foreach $line ( split( /\n/, $planText ) ) {
                if ( $line =~ /.*\|\s*PPTASK\s*\|.*/ ) {
                    $inLoop = 1;
                    @plantask = split( /\|/, $line );
                    my $taskname = $plantask[$col_taskname];
                    $taskname =~ s/^\s*(.*?)\s*$/$1/;
                    $list .=
"<b>TASK</b>: <nop>$taskname <b>Developer</b>:$plantask[$col_dev] <b>Status</b>:$plantask[$col_status] <b>Priority</b>:$plantask[$col_priority] <b>Est Days</b>:$plantask[$col_estdays] <b>Spent Days</b>:$plantask[$col_spentdays] <b>Results_Comments</b>: $plantask[$col_results] <br><b>Summary</b>:$plantask[$col_summary]<br>";
                    $plantask[$col_taskname] =~ s/^\s*(.*?)\s*$/$1/;
                    if (
                        &TWiki::Func::topicExists(
                            $web, $plantask[$col_taskname]
                        )
                      )
                    {
                        $list .= "<b>Description</b>:<br>";
                        $list .=
                          &TWiki::Func::readTopic( $web,
                            $plantask[$col_taskname] );
                    }
                    $list .= "<br><br>";
                }
                elsif ($inLoop) {

                    # we already looked through all PPTASK lines so exit now
                    last;
                }
            }
        }
        else {
            $list .= "<b>PLAN <nop>$eachPl *No Tasks* </b><br><br>";
        }
    }

    return $list;
}

#################################################################################
# ppAllProjectsInfo
#
# Show all info for all plans for all projects in a comma separated list
#################################################################################

sub ppAllProjectsInfo {

    my ( $projList, $web ) = @_;
    my @projects;

    @projects = ppFindMatchingProjects($projList);

    my $list = "<h3>Description of projects @projects</h3>\n\n";

    foreach my $eachPr (@projects) {
        $list .= "<p><b>PROJECT: $eachPr</b><br><br>";
        $list .= &ppGetProjectInfo( $eachPr, $web );
    }

    return $list;
}

#################################################################################
# ppAllDevSummary
#
# Show summary information by developer for list of projects
#################################################################################

sub ppAllDevSummary {

    my ( $projList, $web, $detailedSummary ) = @_;
    my ( $eachD, @tasks, $eachT, $eachPl, $eachPr, $matchPr, $found,
        $allProjs );
    my @projects;

    @projects = ppFindMatchingProjects($projList);
    $allProjs = ( $projList eq "" );

    my $list =
      "\n<h3>Summary of developer tasks and status for @projects</h3>\n";
    $list .=
      "(<b>Rem. Days</b> accounts for the <b>Est. Effort</b> in each task)\n\n";
    if ($detailedSummary) {
        $list .=
"| *Developer* | *Task* | *Plan* | *Module* | *Status* | *Priority* | *Spent Days* | *Est Days* | *Est. Effort* | *Rem. Days* | *Status By Days* |\n";
    }
    else {
        $list .=
"| *Developer* | *Spent Days* | *Est Days* | *Rem. Days* | *Completion Date* | *Status By Days* |\n";
    }

    foreach $eachD ( sort ( keys %cachedDevTasks ) ) {
        @tasks = split( /;/, $cachedDevTasks{$eachD} );
        my $firstTask       = 1;
        my $foundTask       = 0;
        my $totalTasks      = 0;
        my $doneTasks       = 0;
        my $inProgressTasks = 0;
        my $waitingTasks    = 0;
        my $totalDays       = 0;
        my $doneDays        = 0;
        my $inProgressDays  = 0;
        my $waitingDays     = 0;
        my $totalCal        = 0;
        foreach $eachT (@tasks) {
            $eachPl = $cachedTaskPlan{$eachT};
            $eachPl =~ s/^\s*(.*?)\s*$/$1/;

            # see if this task is in the list of projects passed as params
            if ( !$allProjs ) {
                $matchPr = $cachedPlanProj{$eachPl};
                $found   = 0;
                foreach $eachPr (@projects) {
                    if ( $eachPr eq $matchPr ) {
                        $found = 1;
                        last;
                    }
                }
                if ( !$found ) {
                    next;
                }
            }
            if ( &TWiki::Func::topicExists( $web, $eachPl ) ) {
                my $planText = &TWiki::Func::readTopic( $web, $eachPl );

                # To go from Plan -> Task (multiple values)
                my $line;
                my $inLoop = 0;
                foreach $line ( split( /\n/, $planText ) ) {
                    if ( $line =~ /.*\|\s*PPTASK\s*\|.*/ ) {
                        $inLoop = 1;
                        my @plantask = split( /\|/, $line );
                        my $taskname = $plantask[$col_taskname];
                        $taskname =~ s/^\s*(.*?)\s*$/$1/;
                        if ( $taskname eq $eachT ) {

                            # the entry might have comma separated
                            # list of owners which we don't like, but handle it
                            my @developers = split( /,/, $plantask[$col_dev] );
                            my $foundmatch = 0;
                            foreach my $matchdev (@developers) {
                                if ( $matchdev =~ /$eachD/ ) {
                                    $foundmatch = 1;
                                    last;
                                }
                            }
                            if ( !$foundmatch ) {
                                next;
                            }

                # add header and trailer only if developer has at least one task
                # if we are doing detailed info

                            if ($firstTask) {
                                $firstTask = 0;
                                $foundTask = 1;
                                if ($detailedSummary) {
                                    $list .= "|$eachD | | | | | | | | | | |\n";
                                }
                            }
                            if ($detailedSummary) {
                                $list .=
"| | $eachT | $eachPl | $plantask[$col_module] | $plantask[$col_status] | $plantask[$col_priority] | $plantask[$col_spentdays] | $plantask[$col_estdays] | $plantask[$col_effort] | ";
                            }
                            $totalTasks++;
                            $totalDays += int $plantask[$col_estdays];
                            if (
                                ( $plantask[$col_status] =~ /.*[d|D]one.*/ )
                                || ( $plantask[$col_status] =~
                                    /.*[c|C]ancelled.*/ )
                              )
                            {
                                $doneTasks++;

                                #assume spent days not accurate sp Spent=Est
                                $doneDays += int $plantask[$col_estdays];
                                if ($detailedSummary) {
                                    $list .= "   0|";
                                    $list .= gaugeLite( int(100) );
                                    $list .= "|\n";
                                }
                            }
                            else {
                                my $spentPer = 0;
                                my $ip       = 0;
                                my $wait     = 0;
                                if ( $plantask[$col_status] =~
                                    /.*[i|I]n [p|P]rogress.*/ )
                                {
                                    $inProgressTasks++;
                                    $inProgressDays +=
                                      $plantask[$col_spentdays];
                                    $ip = 1;
                                }
                                elsif ( $plantask[$col_status] =~
                                    /.*[w|W]aiting.*/ )
                                {
                                    $waitingTasks++;
                                    $waitingDays += $plantask[$col_spentdays];
                                    $wait = 1;
                                }
                                if (   ( $plantask[$col_effort] > 0 )
                                    && ( $plantask[$col_estdays] > 0 ) )
                                {
                                    my $reqDays = int(
                                        (
                                            $plantask[$col_estdays] -
                                              $plantask[$col_spentdays]
                                        ) * ( 100.0 / $plantask[$col_effort] )
                                    );
                                    $totalCal += $reqDays;
                                    $spentPer =
                                      int( 100.0 *
                                          $plantask[$col_spentdays] /
                                          $plantask[$col_estdays] );
                                    if ($detailedSummary) {
                                        $list .= " $reqDays |";
                                        if ($ip) {
                                            $list .=
                                              gaugeTriple( 0, $spentPer );
                                        }
                                        elsif ($wait) {
                                            $list .=
                                              gaugeFour( 0, $spentPer, 0 );
                                        }
                                        else {
                                            $list .= gaugeLite(0);
                                        }
                                        $list .= "|\n";
                                    }
                                }
                                else {
                                    if ($detailedSummary) {
                                        $list .= " | |\n";
                                    }
                                }
                            }
                        }
                    }
                    elsif ($inLoop) {
                        last;
                    }
                }
            }
            else {
                if ($detailedSummary) {
                    $list .= "| | $eachT | | | | | | | | | |";
                }
            }
        }
        if ($foundTask) {
            my $totalSpentDays = $doneDays + $inProgressDays + $waitingDays;
            my $workDaysLeft   = int( $totalCal * 7.0 / 5.0 );
            my $today =
              _date2serial(
                _serial2date( time(), '$year/$month/$day PDT', 0 ) );
            my $targetDate =
              _serial2date( _timeadd( $today, $workDaysLeft, $TIMESCALE ),
                '$year/$month/$day', 0 );
            if ($detailedSummary) {
                $list .=
"| | | | | | | <b>Spent Days: $totalSpentDays</b> | <b>Total Est Days: $totalDays</b> |<b>Days Left: $totalCal</b>|<b>Completion Date: $targetDate</b>|";
            }
            else {
                $list .=
"| $eachD |     <b>$totalSpentDays</b>|    <b>$totalDays</b>|     <b>$totalCal</b>|    <b>$targetDate</b>|";
            }
            my $daysDonePer       = 100;
            my $daysInProgressPer = 0;
            my $daysWaitingPer    = 0;
            if ( $totalDays > 0 ) {
                $daysDonePer = int( 100.0 * $doneDays / $totalDays );
                $daysInProgressPer =
                  int( 100.0 * $inProgressDays / $totalDays );
                $daysWaitingPer = int( 100.0 * $waitingDays / $totalDays );
            }
            $list .=
              gaugeFour( $daysDonePer, $daysWaitingPer, $daysInProgressPer );
            $list .= "|\n";
        }
    }

    return $list;
}

#################################################################################
# ppAllPlanIdSummary
#
# Show summary information by plan Id for list of projects
# empty list means all projects
#################################################################################

sub ppAllPlanIdSummary {

    my ( $projList, $web ) = @_;
    my ( $allProjs, $eachId, @plans, $eachPl, $eachPr, $matchPr, $found );
    my ($printPlan);
    my @projects;

    @projects = ppFindMatchingProjects($projList);
    $allProjs = ( $projList eq "" );

    # Do a two level display. First display high level summary of
    # plans and then expand the loop including tasks
    my $list = "\n<h3>Summary of plans by Plan Id for @projects</h3>\n\n";
    $list .= "| *Plan Id* | *Project* | *Plan* | *Summary* | *Results* | \n";
    my $printId;
    foreach $eachId ( sort keys %cachedIdPlans ) {
        if ( $eachId == 0 ) {
            $printId = "unknown";
        }
        else {
            $printId = convertPlanIdsToUrl($eachId);
        }
        @plans = split( /;/, $cachedIdPlans{$eachId} );
        foreach $eachPl (@plans) {
            $printPlan = $eachPl;

            # see if this plan is in the list of projects passed as params
            if ( !$allProjs ) {
                $matchPr = $cachedPlanProj{$eachPl};
                $found   = 0;
                foreach $eachPr (@projects) {
                    if ( $eachPr eq $matchPr ) {
                        $found = 1;
                        last;
                    }
                }
                if ( !$found ) {
                    next;
                }
            }
            my $results;
            if ( &TWiki::Func::topicExists( $web, $eachPl ) ) {
                my $planText = &TWiki::Func::readTopic( $web, $eachPl );
                my $summary = "";
                if ( $planText =~ /.*\|.*PP Plan Summary.*\|.*\|.*/ ) {
                    $planText =~ /.*\|.*PP Plan Summary.*\|(.*?)\|.*/;
                    $summary = "$1";
                    $summary =~ s/^\s*(.*?)\s*$/$1/;
                }

                # To go from Plan -> Task (multiple values)
                my $line;
                my $inLoop = 0;
                foreach $line ( split( /\n/, $planText ) ) {
                    if ( $line =~ /.*\|\s*PPTASK\s*\|.*/ ) {
                        $inLoop = 1;
                        my @plantask = split( /\|/, $line );
                        if ( $plantask[$col_status] =~ /[dD]one/ ) {
                            $results .=
                              convertResultsToUrl( $plantask[$col_results], 1,
                                $plantask[$col_module] );
                            $results .= " ";
                        }
                    }
                    elsif ($inLoop) {
                        last;
                    }
                }
                $list .=
"| $printId | $cachedPlanProj{$eachPl} | $eachPl | $summary |";
                $list .= $results;
                $list .= " |\n";
            }
            else {
                $list .=
                  "| $printId | $cachedPlanProj{$eachPl} | $eachPl | | |\n";
            }
            $printId = "";
        }
    }

    $list .= "\n\n";

    # Now add detailed summary including tasks below
    $list .= "\n<h3>Summary of tasks by Plan Id for @projects</h3>\n\n";
    $list .=
"| *Plan Id* | *Plan* | *Task* | *Module* | *Developer* | *Status* | *Results* |\n";

    foreach $eachId ( sort keys %cachedIdPlans ) {
        if ( $eachId == 0 ) {
            $list .= "| unknown | | | | | | |\n";
        }
        else {
            $list .= "| ";
            $list .= convertPlanIdsToUrl($eachId);
            $list .= " | | | | | | |\n";
        }
        @plans = split( /;/, $cachedIdPlans{$eachId} );
        foreach $eachPl (@plans) {
            $printPlan = $eachPl;

            # see if this task is in the list of projects passed as params
            if ( !$allProjs ) {
                $matchPr = $cachedPlanProj{$eachPl};
                $found   = 0;
                foreach $eachPr (@projects) {
                    if ( $eachPr eq $matchPr ) {
                        $found = 1;
                        last;
                    }
                }
                if ( !$found ) {
                    next;
                }
            }
            if ( &TWiki::Func::topicExists( $web, $eachPl ) ) {
                my $planText = &TWiki::Func::readTopic( $web, $eachPl );

                # To go from Plan -> Task (multiple values)
                my $line;
                my $inLoop = 0;
                foreach $line ( split( /\n/, $planText ) ) {
                    if ( $line =~ /.*\|\s*PPTASK\s*\|.*/ ) {
                        $inLoop = 1;
                        my @plantask = split( /\|/, $line );
                        if ( $plantask[$col_status] =~ /[dD]one/ ) {
                            $list .=
"| | $printPlan | $plantask[$col_taskname] | $plantask[$col_module] | $plantask[$col_dev] | $plantask[$col_status] | ";
                            $list .=
                              convertResultsToUrl( $plantask[$col_results], 0,
                                $plantask[$col_module] );
                            $list .= " |\n";
                        }
                        else {
                            $list .=
"| | $printPlan | $plantask[$col_taskname] | $plantask[$col_module] | $plantask[$col_dev] | $plantask[$col_status] | $plantask[$col_results] |\n";
                        }
                        $printPlan = "";
                    }
                    elsif ($inLoop) {
                        last;
                    }
                }
            }
            else {
                $list .= "| | $printPlan | | | | | |\n";
            }
        }
    }

    return $list;
}

#################################################################################
# converts a date string to a time value based on format
#
#################################################################################
sub _date2serial {
    my ($theText) = @_;

    my $sec  = 0;
    my $min  = 0;
    my $hour = 0;
    my $day  = 1;
    my $mon  = 0;
    my $year = 0;

    if ( $theText =~
m|([0-9]{1,2})[-\s/]+([A-Z][a-z][a-z])[-\s/]+([0-9]{4})[-\s/]+([0-9]{1,2}):([0-9]{1,2})|
      )
    {

# "31 Dec 2003 - 23:59", "31-Dec-2003 - 23:59", "31 Dec 2003 - 23:59 - any suffix"
        $day  = $1;
        $mon  = $monthToNum{$2} || 0;
        $year = $3 - 1900;
        $hour = $4;
        $min  = $5;
    }
    elsif (
        $theText =~ m|([0-9]{1,2})[-\s/]+([A-Z][a-z][a-z])[-\s/]+([0-9]{2,4})| )
    {

        # "31 Dec 2003", "31 Dec 03", "31-Dec-2003", "31/Dec/2003"
        $day  = $1;
        $mon  = $monthToNum{$2} || 0;
        $year = $3;
        $year += 100 if ( $year < 80 );    # "05"   --> "105" (leave "99" as is)
        $year -= 1900 if ( $year >= 1900 );    # "2005" --> "105"
    }
    elsif ( $theText =~
m|([0-9]{4})[-/\.]([0-9]{1,2})[-/\.]([0-9]{1,2})[-/\.\,\s]+([0-9]{1,2})[-\:/\.]([0-9]{1,2})[-\:/\.]([0-9]{1,2})|
      )
    {

        # "2003/12/31 23:59:59", "2003-12-31-23-59-59", "2003.12.31.23.59.59"
        $year = $1 - 1900;
        $mon  = $2 - 1;
        $day  = $3;
        $hour = $4;
        $min  = $5;
        $sec  = $6;
    }
    elsif ( $theText =~
m|([0-9]{4})[-/\.]([0-9]{1,2})[-/\.]([0-9]{1,2})[-/\.\,\s]+([0-9]{1,2})[-\:/\.]([0-9]{1,2})|
      )
    {

        # "2003/12/31 23:59", "2003-12-31-23-59", "2003.12.31.23.59"
        $year = $1 - 1900;
        $mon  = $2 - 1;
        $day  = $3;
        $hour = $4;
        $min  = $5;
    }
    elsif ( $theText =~ m|([0-9]{4})[-/]([0-9]{1,2})[-/]([0-9]{1,2})| ) {

        # "2003/12/31", "2003-12-31"
        $year = $1 - 1900;
        $mon  = $2 - 1;
        $day  = $3;
    }
    else {

        # unsupported format
        &TWiki::Func::writeDebug("Time unsupported format\n") if $debug;
        return 0;
    }

    my $retval;
    if ( $theText =~ /gmt/i ) {
        $retval = timegm( $sec, $min, $hour, $day, $mon, $year );
    }
    else {
        $retval = timelocal( $sec, $min, $hour, $day, $mon, $year );
    }

    return $retval;
}

#################################################################################
# converts a time value to a date string based on formatting information
#
#################################################################################
sub _serial2date {
    my ( $theTime, $theStr, $isGmt ) = @_;

    my ( $sec, $min, $hour, $day, $mon, $year, $wday, $yday ) =
      localtime($theTime);
    ( $sec, $min, $hour, $day, $mon, $year, $wday, $yday ) = gmtime($theTime)
      if ($isGmt);

    $theStr =~ s/\$sec[o]?[n]?[d]?[s]?/sprintf("%.2u",$sec)/geoi;
    $theStr =~ s/\$min[u]?[t]?[e]?[s]?/sprintf("%.2u",$min)/geoi;
    $theStr =~ s/\$hou[r]?[s]?/sprintf("%.2u",$hour)/geoi;
    $theStr =~ s/\$day/sprintf("%.2u",$day)/geoi;
    $theStr =~ s/\$mon(?!t)/$monthArr[$mon]/goi;
    $theStr =~ s/\$mo[n]?[t]?[h]?/sprintf("%.2u",$mon+1)/geoi;
    $theStr =~ s/\$yearday/$yday+1/geoi;
    $theStr =~ s/\$yea[r]?/sprintf("%.4u",$year+1900)/geoi;
    $theStr =~ s/\$ye/sprintf("%.2u",$year%100)/geoi;
    $theStr =~ s/\$wday/substr($weekdayArr[$wday],0,3)/geoi;
    $theStr =~ s/\$wd/$wday+1/geoi;
    $theStr =~ s/\$weekday/$weekdayArr[$wday]/goi;

    return $theStr;
}

#################################################################################
# adds the specified number of days $value to the $time
#
#################################################################################
sub _timeadd {
    my ( $time, $value, $scale ) = @_;

    &TWiki::Func::writeDebug("Timeadd: input $time $value $scale\n")
      if ($debug);

    $time  =~ s/.*?([0-9]+).*/$1/o      || 0;
    $value =~ s/.*?(\-?[0-9\.]+).*/$1/o || 0;
    $value *= 60                if ( $scale =~ /^min/i );
    $value *= 3600              if ( $scale =~ /^hou/i );
    $value *= 3600 * 24         if ( $scale =~ /^day/i );
    $value *= 3600 * 24 * 7     if ( $scale =~ /^week/i );
    $value *= 3600 * 24 * 30.42 if ( $scale =~ /^mon/i );    # FIXME: exact calc
    $value *= 3600 * 24 * 365   if ( $scale =~ /^year/i );   # FIXME: exact calc
    my $result = int( $time + $value );

    &TWiki::Func::writeDebug("Timeadd: output $result\n") if ($debug);

    return $result;
}
#################################################################################
# convertPlanIdsToUrl
#
# compose the Url to point to for a PlanId
#################################################################################

sub convertPlanIdsToUrl() {
    return @_;    # default
}

#################################################################################
# convertResultsToUrl
#
# compose the Url to point to for Results
#################################################################################

sub convertResultsToUrl() {
    return @_;    # default
}

#================================= EOF =====================================
1;
