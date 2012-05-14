#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
#
# Authors (in alphabetical order)
#   Andrea Bacchetta
#   Richard Bennett
#   Anthon Pang
#   Andrea Sterbini
#   Martin Watt
#   Thomas Eschner
#   Rafael Alvarez (RAF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 7 See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# =========================
#
# ========================
#
package TWiki::Plugins::XpTrackerPlugin;

use HTTP::Date;
use TWiki::Plugins::XpTrackerPlugin::Status;
use TWiki::Plugins::XpTrackerPlugin::Cache;
use TWiki::Plugins::XpTrackerPlugin::HtmlUtil;

use TWiki::Plugins::XpTrackerPlugin::Story;

# =========================
use vars qw(
  $web $query $topic $user $installWeb $VERSION $RELEASE $debug
  $exampleCfgVar $dataDir $orderBy
);

use vars qw ( @timeRec
);

use strict;

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$debug = 0;

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # Get plugin debug flag
    $debug   = &TWiki::Func::getPreferencesFlag("XPTRACKERPLUGIN_DEBUG");
    $orderBy = &TWiki::Func::getPreferencesValue("XPTRACKERPLUGIN_ORDERBY");

    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::XpTrackerPlugin::initPlugin is OK")
      if $debug;
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::XpTrackerPlugin::initPlugin order by $orderBy")
      if $debug;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between XpTrackerPlugin and Plugins.pm");
        return 0;
    }

    $query = &TWiki::Func::getCgiQuery();
    if ( !$query ) {
        return 0;
    }

    &initCache($web);

    # Read the color schema from the Plugin Topic
    &TWiki::Plugins::XpTrackerPlugin::Status::initModule();

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::XpTrackerPlugin::initPlugin( $web.$topic ) is OK")
      if $debug;

    return 1;
}

# =========================
sub afterSaveHandler {
    ### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    TWiki::Plugins::XpTrackerPlugin::Cache::buildCache( $_[2] );
    &TWiki::Func::writeDebug(
"- TWiki::Plugins::XpTrackerPlugin::afterSaveHandler( $_[2].$_[1] ) is OK"
    );
}

# =========================
#sub accepts {
#    return ($_[0] =~ /%XP[A-Z]+.*?%/);
#}

sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    # search for create new page link
    if ( $query->param('xpsave') ) {
        xpSavePage($web);

        # return; # in case browser does not redirect
    }
    my $web = $_[2];

    # %XPSHOWALLPROJECTS% - Show all projects
    $_[0] =~ s/%XPSHOWALLPROJECTS%/&xpShowAllProjects($web)/geo;

    # %XPSHOWALLTEAMS% - Show all teams
    $_[0] =~ s/%XPSHOWALLTEAMS%/&xpShowAllTeams($web)/geo;

    # %XPSHOWALLITERATIONS% - Show all iterations (DONE)
    $_[0] =~ s/%XPSHOWALLITERATIONS%/&xpShowAllIterations($web)/geo;

    # %XPSHOWPROJECTTEAMS% - Show all teams on this project (DONE)
    $_[0] =~ s/%XPSHOWPROJECTTEAMS\{(.*?)\}%/&xpShowProjectTeams($1, $web)/geo;

    # %XPSHOWPROJECTITERATIONS% - Show all project iterations (DONE)
    $_[0] =~
s/%XPSHOWPROJECTITERATIONS\{(.*?)\}%/&xpShowProjectIterations($1, $web)/geo;

    # %XPSHOWPROJECTSTORIES% - Show all project stories (DONE)
    $_[0] =~
      s/%XPSHOWPROJECTSTORIES\{(.*?)\}%/&xpShowProjectStories($1, $web)/geo;

# %XPSHOWPROJECTCOMPLETIONBYSTORIES% - Show completion status of project by stories (DONE)
    $_[0] =~
s/%XPSHOWPROJECTCOMPLETIONBYSTORIES\{(.*?)\}%/&xpShowProjectCompletionByStories($1, $web)/geo;

# %XPSHOWPROJECTCOMPLETIONBYTASKS% - Show completion status of project by tasks (DONE)
    $_[0] =~
s/%XPSHOWPROJECTCOMPLETIONBYTASKS\{(.*?)\}%/&xpShowProjectCompletionByTasks($1, $web)/geo;

    # %XPSHOWTEAMITERATIONS% - Show all team iterations (DONE)
    $_[0] =~
      s/%XPSHOWTEAMITERATIONS\{(.*?)\}%/&xpShowTeamIterations($1, $web)/geo;

    # %XPSHOWITERATION% - Show iteration status (DONE)
    $_[0] =~ s/%XPSHOWITERATION\{(.*?)\}%/&xpShowIteration($1,$web)/geo;

    # %XPSHOWITERATIONTERSE% - Show iteration status (DONE)
    $_[0] =~
      s/%XPSHOWITERATIONTERSE\{(.*?)\}%/&xpShowIterationTerse($1,$web)/geo;

    # %XPVELOCITIES% - Show velocities by iteration (DONE)
    $_[0] =~ s/%XPVELOCITIES\{(.*?)\}%/&xpShowVelocities($1,$web)/geo;

    # %XPDUMPITERATION% - Dumps an iteration for printing
    $_[0] =~ s/%XPDUMPITERATION\{(.*?)\}%/&xpDumpIteration($1,$web)/geo;

    # ThomasEschner: %XPSHOWDEVELOPERTASKS% - Show open tasks by developer
    $_[0] =~
      s/%XPSHOWDEVELOPERTASKS\{([^,]*?)\}%/&xpShowDeveloperTasks($1,$web)/geo;

# RafaelAlvarez: %XPSHOWDEVELOPERTASKS% - Show open tasks by developer, in the specified web
    $_[0] =~
      s/%XPSHOWDEVELOPERTASKS\{(.+?),(.+?)\}%/&xpShowDeveloperTasks($1,$2)/geo;

# RafaelAlvarez: %XPSHOWDEVELOPERTASKSBYITERATION% - Show open tasks by developer and iteration
    $_[0] =~
s/%XPSHOWDEVELOPERTASKSBYITERATION\{([^,]+?),([^,]+?)\}%/xpShowDeveloperTasksByIteration($1,$2,$web)/geo;

# RafaelAlvarez: %XPSHOWDEVELOPERTASKSBYITERATION% - Show open tasks by developer and iteration, in the specified web
    $_[0] =~
s/%XPSHOWDEVELOPERTASKSBYITERATION\{([^,]+?),([^,]+?),(.+?)\}%/xpShowDeveloperTasksByIteration($1,$2,$3)/geo;

# ThomasEschner: %XPSHOWLOAD% - Show workload by developer and project/iteration (DONE)
    $_[0] =~ s/%XPSHOWLOAD\{(.*?)\}%/&xpShowLoad($1,$web)/geo;

    # %XPSHOWCOLOURS% - Service procedure to show current colours
    $_[0] =~ s/%XPSHOWCOLOURS%/&xpShowColours($web)/geo;

    # %XPGETSTORYSTATUS% - Show the status of a given story
    $_[0] =~ s/%XPGETSTORYSTATUS\{(.*?)\}%/&xpGetStoryStatus($1)/geo;

    # ========================== END XP TAGS ==========================

    return $_[0];
}

sub xpGetStoryStatus {
    my $storyName = $_[0];
    my @elements = split( /\./, $storyName );
    my $story =
      new TWiki::Plugins::XpTrackerPlugin::Story( $elements[0], $elements[1] );

    return $story->{storyStatS};
}

###########################
# xpGetValue
#
# Return value from passed in text with passed in title

sub xpGetValue {
    my $title = $_[0];

    # my $text = $_[1]; # DONT MAKE COPY for performance reasons
    my $oldStyle = $_[2];
    my $result   = "";

    my $pattern1 =
      "<!--" . $oldStyle . "--> *(.*?) *<!--\\/" . $oldStyle . "-->";
    my $pattern2 = "\\|[ \\t]*" . $title . "[ \\t]*\\|[ \\t]*(.*?)[ \\t]*\\|";

    if ( $_[1] =~ /$pattern1/s ) {
        $result = $1;
    }
    elsif ( $_[1] =~ /$pattern2/s ) {
        $result = $1;
    }
    return $result;
}

###########################
# xpGetValueAndRemove
#
# Return value from passed in text with passed in title. Remove line from text

sub xpGetValueAndRemove {
    my $title = $_[0];

    # my $text = $_[1]; # DONT MAKE COPY for performance reasons
    my $oldStyle = $_[2];
    my $result   = "";

    my $pattern1 =
      "<!--" . $oldStyle . "--> *(.*?) *<!--\\/" . $oldStyle . "-->";
    my $pattern2 = "\\|[ \\t]*" . $title . "[ \\t]*\\|[ \\t]*(.*?)[ \\t]*\\|";

    if ( $_[1] =~ s/$pattern1//s ) {
        $result = $1;
    }
    elsif ( $_[1] =~ s/$pattern2//s ) {
        $result = $1;
    }
    return $result;
}

############################### BEGIN OF RENDERING SUBS #########################

###########################
# xpDumpIteration
#
# Dumps stories and tasks in an iteration.

sub xpDumpIteration {
    my ( $iteration, $web ) = @_;

    my @allStories = &xpGetIterStories( $iteration, $web );

    # Iterate over each and build master list

    my $bigList = "";

    foreach my $story (@allStories) {
        my $storyText =
          &TWiki::Plugins::XpTrackerPlugin::Common::readStoryText( $web,
            $story );

        # TODO: This is a hack!
        # Patch the embedded "DumpStoryList" name to the real story name
        if ( &xpGetValue( "\\*Iteration\\*", $storyText, "storyiter" ) eq
            $iteration )
        {

            # TODO: This is a hack!
            # Patch the embedded %TOPIC% before the main TWiki code does
            $storyText =~ s/%TOPIC%/$story/go;
            $bigList .=
                "<h2>Story: " 
              . $story
              . "</h2>\n"
              . $storyText
              . "<br><br><hr> \n";
        }
    }

    return $bigList;
}

###########################
# xpShowIteration
#
# Shows the specified iteration broken down by stories and tasks

sub xpShowIteration {
    eval("use TWiki::Plugins::XpTrackerPlugin::ShowIteration;");
    return TWiki::Plugins::XpTrackerPlugin::ShowIteration::xpShowIteration(@_);
}

###########################
# xpShowIterationTerse
#
# Shows the specified iteration broken down by stories and tasks
# Copied from XpShowIteration. Need to refactor!

sub xpShowIterationTerse {
    eval("use TWiki::Plugins::XpTrackerPlugin::ShowIterationTerse;");
    return
      TWiki::Plugins::XpTrackerPlugin::ShowIterationTerse::xpShowIterationTerse(
        @_);
}

###########################
# xpShowAllIterations
#
# Shows all the iterations

sub xpShowAllIterations {
    eval("use TWiki::Plugins::XpTrackerPlugin::ShowAllIterations;");
    return
      TWiki::Plugins::XpTrackerPlugin::ShowAllIterations::xpShowAllIterations(
        @_);
}

###########################
# xpShowProjectIterations
#
# Shows all the iterations for this project
sub xpShowProjectIterations {
    eval("use TWiki::Plugins::XpTrackerPlugin::ShowProjectIterations;");
    return
      TWiki::Plugins::XpTrackerPlugin::ShowProjectIterations::xpShowProjectIterations(
        @_);
}

###########################
# xpShowProjectStories
#
# Shows all the stories for this project

sub xpShowProjectStories {
    eval("use TWiki::Plugins::XpTrackerPlugin::ShowProjectStories;");
    return
      TWiki::Plugins::XpTrackerPlugin::ShowProjectStories::xpShowProjectStories(
        @_);
}

###########################
# xpShowTeamIterations
#
# Shows all the iterations for this team

sub xpShowTeamIterations {
    eval("use TWiki::Plugins::XpTrackerPlugin::ShowTeamIterations;");
    return
      TWiki::Plugins::XpTrackerPlugin::ShowTeamIterations::xpShowTeamIteration(
        @_);
}

###########################
# xpShowAllTeams
#
# Shows all the teams

sub xpShowAllTeams {

    my ($web) = @_;

    my @projects = &xpGetAllProjects($web);

    my $list = TWiki::Plugins::XpTrackerPlugin::HtmlUtil::emmitTwikiHeader( 3,
        "List of all projects and teams:" );
    $list .= "| *Project* | *Project Teams* |\n";

    foreach my $project (@projects) {

        my @projTeams = &xpGetProjectTeams( $project, $web );

        $list .=
            "| " 
          . $project . " | "
          . TWiki::Plugins::XpTrackerPlugin::HtmlUtil::emmitArrayInBullets(
            @projTeams)
          . " |\n";
    }

    # append form to allow creation of new projects
    $list .= &xpCreateHtmlForm(
        "NewnameProj",
        &TWiki::Func::getPreferencesValue("XPTRACKERPLUGIN_PROJECTTEMPLATE"),
        "Create new project"
    );

    return $list;
}

###########################
# xpShowProjectTeams
#
# Shows all the teams on this project

sub xpShowProjectTeams {
    eval("use TWiki::Plugins::XpTrackerPlugin::ShowProjectTeams;");
    return
      TWiki::Plugins::XpTrackerPlugin::ShowProjectTeams::xpShowProjectTeams(@_);
}

###########################
# xpShowProjectCompletionByStories
#
# Shows the project completion by release and iteration using stories.

sub xpShowProjectCompletionByStories {
    eval(
        "use TWiki::Plugins::XpTrackerPlugin::ShowProjectCompletitionByStories;"
    );
    return
      TWiki::Plugins::XpTrackerPlugin::ShowProjectCompletitionByStories::xpShowProjectCompletitionByStories(
        @_);
}

###########################
# xpShowProjectCompletionByTasks
#
# Shows the project completion using tasks.

sub xpShowProjectCompletionByTasks {
    eval(
        "use TWiki::Plugins::XpTrackerPlugin::ShowProjectCompletitionByTasks;");
    return
      TWiki::Plugins::XpTrackerPlugin::ShowProjectCompletitionByTasks::xpShowProjectCompletionByTasks(
        @_);
}

###########################
# ThomasEschner: xpShowLoad
#
# Shows workload by developer and project/iteration.

sub xpShowLoad {
    eval("use TWiki::Plugins::XpTrackerPlugin::ShowLoad;");
    return TWiki::Plugins::XpTrackerPlugin::ShowLoad::xpShowLoad(@_);
}

###########################
# ThomasEschner: xpShowDeveloperTasks
# RafaelAlvarez: Modified to be able to consult the open task from any web.
# Shows open tasks by developer.
sub xpShowDeveloperTasks {
    eval("use TWiki::Plugins::XpTrackerPlugin::Show;");
    return TWiki::Plugins::XpTrackerPlugin::Show::developerTasks(@_);
}

###########################
# RafaelAlvarez: xpShowDeveloperTasksByProject
# Shows open tasks in a project by developer in the specified web.
sub xpShowDeveloperTasksByProject {
    eval("use TWiki::Plugins::XpTrackerPlugin::Show;");
    return TWiki::Plugins::XpTrackerPlugin::Show::developerTasksByProject(@_);
}

###########################
# RafaelAlvarez: xpShowDeveloperTasksByIteration
# Shows open tasks in an iteration by developer in the specified web.
sub xpShowDeveloperTasksByIteration {
    eval("use TWiki::Plugins::XpTrackerPlugin::Show;");
    return TWiki::Plugins::XpTrackerPlugin::Show::developerTasksByIteration( @_,
        1, 1 );
}

###########################
# xpShowVelocities
#
# Shows velocities of resources in an iteration.

sub xpShowVelocities {
    eval("use TWiki::Plugins::XpTrackerPlugin::ShowVelocities");
    return TWiki::Plugins::XpTrackerPlugin::ShowVelocities::xpShowVelocities(
        @_);
}

###########################
# xpShowAllProjects
#
# Shows all the projects on this web

sub xpShowAllProjects {

    my ($web) = @_;

    my @projects = &xpGetAllProjects($web);

    my $list = "<h3>All projects</h3>\n\n";
    $list .= "| *Project* |\n";

    # write out all iterations to table
    foreach my $project (@projects) {
        $list .= "| $project |\n";
    }

    # append form to allow creation of new projects
    $list .= &xpCreateHtmlForm(
        "NewnameProj",
        &TWiki::Func::getPreferencesValue("XPTRACKERPLUGIN_PROJECTTEMPLATE"),
        "Create new project"
    );

    return $list;
}

###########################
# xpShowColours
#
# Service method to show current background colours
sub xpShowColours {
    return TWiki::Plugins::XpTrackerPlugin::Status::showColours(@_);
}

############################### END OF RENDERING SUBS #########################

###########################
# xpGetAllStories
#
# Returns a list of all stories in this web.

sub xpGetAllStories {

    my $web = $_[0];

    # Read in all stories in this web
    #opendir(WEB,$dataDir."/".$web);
    opendir( WEB, TWiki::Func::getDataDir() . "/" . $web );
    my @allStories = grep { s/(.*?Story).txt$/$1/go } readdir(WEB);
    closedir(WEB);

    return @allStories;
}

###########################
# xpGetProjectStories
#
# Returns a list of all stories in the given project

sub xpGetProjectStories {

    my ( $project, $web ) = @_;

    my @matchingStories = ();

    my @teams = &xpGetProjectTeams( $project, $web );
    foreach my $team (@teams) {

        my @teamIters = &xpGetTeamIterations( $team, $web );

        # write out all iterations to table
        foreach my $iter (@teamIters) {

            my @allStories = &xpGetIterStories( $iter, $web );
            push @matchingStories, @allStories;
        }
    }
    return @matchingStories;
}

###########################
# xpRipWords
#
# Parses a bunch of words from TWiki code

sub xpRipWords {
    my $string = $_[0];
    my @out    = ();
    foreach my $word ( split( /[ \|]/, $string ) ) {
        if ( $word ne "" ) {
            push @out, $word;
        }
    }
    return @out;
}

###########################
# xpZero2Null
#
# Returns a numeric, or null if zero

sub xpZero2Null {
    if ( $_[0] == 0 ) {
        return "";
    }
    else {
        return $_[0];
    }
}

###########################
# xpGetNextTask
#
# Return the next task in a story
# Watch out<<<<<<<<<<<<<

sub xpGetNextTask {

    # use reference to text to avoid large copy
    #my $storyText = $_[0];

    my ( $taskName, $taskEst, $taskWho, $taskSpent, $taskEtc, $taskStatus,
        $taskReviewer )
      = "";

    # first look for new-style task (horizontally laid out)
    if ( $_[0] =~ s/(\|[ \t]*Task[ \t]*\|.*\n)// )
    {    # get to eol, so no newline in search
        my @fields = split /[ \t]*\|[ \t]*/,
          $1;    # split by "|", allowing surrounding whitespace and tab too

        $taskName     = $fields[8];
        $taskEst      = $fields[2];
        $taskWho      = $fields[7];
        $taskSpent    = $fields[3];
        $taskEtc      = $fields[4];
        $taskReviewer = $fields[6];

    }
    else {
        $taskName =
          &xpGetValueAndRemove( "\\*Task name\\*", $_[0], "taskname" );
        if ( !$taskName ) {
            return 0;
        }

        $taskEst =
          &xpGetValueAndRemove( "\\*Original estimate\\*", $_[0], "est" );
        $taskWho = &xpGetValueAndRemove( "\\*Assigned to\\*", $_[0], "who" );
        $taskSpent = &xpGetValueAndRemove( "\\*Time spent\\*", $_[0], "spent" );
        $taskEtc =
          &xpGetValueAndRemove( "\\*Est\\. time to go\\*", $_[0], "etc" );
    }

    return ( 1, $taskName, $taskEst, $taskWho, $taskSpent, $taskEtc, 0,
        $taskReviewer );    #$taskStatus);
}

###########################
sub sort_unique(@) {
    my @array = @_;
    my %hash;

    #make the names the keys of a hash, so the keys will be unique
    foreach my $el (@array) {
        $hash{$el}++;
    }

    #now sort the keys
    return ( sort keys(%hash) );
}

sub xpSavePage() {
    my ($web) = @_;

    # check the user has entered a non-null string
    my $title = $query->param('topic');

    if ( $title eq "" ) {
        TWiki::Func::redirectCgiQuery( $query,
            &TWiki::Func::getViewUrl( $web, "XpNewPageError" ) );
        return;
    }
    TWiki::Func::writeDebug(
"- TWiki::Plugins::XpTrackerPlugin::xpSavePage check the user has entered a non-null string (  $title  ) "
    ) if $debug;

    # check topic does not already exist
    if ( TWiki::Func::topicExists( $web, $title ) ) {
        TWiki::Func::redirectCgiQuery( $query,
            &TWiki::Func::getViewUrl( $web, "XpNewPageError" ) );
        return;
    }
    TWiki::Func::writeDebug(
"- TWiki::Plugins::XpTrackerPlugin::xpSavePage check topic does not already exist"
    ) if $debug;

    # check the user has entered a WIKI name
    if ( !TWiki::isValidWikiWord($title) ) {
        TWiki::Func::redirectCgiQuery( $query,
            &TWiki::Func::getViewUrl( $web, "XpNewPageError" ) );
        return;
    }
    TWiki::Func::writeDebug(
"- TWiki::Plugins::XpTrackerPlugin::xpSavePage check the user has entered a WIKI name"
    ) if $debug;

    # if creating a story, check name ends in *Story
    my $template = $query->param('templatetopic');
    if ( $template eq "StoryTemplate" ) {
        if ( !( $title =~ /^[\w]*Story$/ ) ) {
            TWiki::Func::redirectCgiQuery( $query,
                &TWiki::Func::getViewUrl( $web, "XpNewPageError" ) );
            return;
        }
    }
    TWiki::Func::writeDebug(
"- TWiki::Plugins::XpTrackerPlugin::xpSavePage if creating a story, check name ends in *Story"
    ) if $debug;

    # load template for page type requested
    my $text = &TWiki::Func::readTopicText( $web, $template );

    # write parent name into page
    my $parent = $query->param('parent');
    $text =~ s/XPPARENTPAGE/$parent/geo;

    # save new page and open in browser
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::XpTrackerPlugin::xpSavePage Saving topic")
      if $debug;

    #If we get this far, we can be sure that $title is safe
    $title = TWiki::Sandbox::untaintUnchecked($title);
    my $error = &TWiki::Func::saveTopicText( $web, $title, $text );

    if ($error) {
        TWiki::Func::writeDebug(
            "- TWiki::Plugins::XpTrackerPlugin::xpSavePage ERROR $error")
          if $debug;
        my $url =
          &TWiki::Func::getOopsUrl( $web, $topic, "oopssaveerr", $error );
        TWiki::Func::redirectCgiQuery( $query, $url );
        return;
    }

#TWiki::Func::redirectCgiQuery( $query, &TWiki::Func::getViewUrl( $web, $topic ) );

    TWiki::Func::writeDebug(
        "- TWiki::Plugins::XpTrackerPlugin::xpSavePage Redirecting to: "
          . &TWiki::Func::getViewUrl( $web, $topic ) )
      if $debug;
    $query->param( 'xpsave', '0' );
    TWiki::Func::redirectCgiQuery( $query,
        &TWiki::Func::getViewUrl( $web, $topic ) );

    TWiki::Func::writeDebug(
        "- TWiki::Plugins::XpTrackerPlugin::xpSavePage Redirected to: "
          . &TWiki::Func::getViewUrl( $web, $topic ) )
      if $debug;

    #TWiki::Func::setTopicEditLock( $web,$theTopic, 1 );

}

# ====================================
# Wrapper subs to improve readability
# ====================================

###########################
# xpCreateHtmlForm
#
# Make form to create new subtype
sub xpCreateHtmlForm {
    return TWiki::Plugins::XpTrackerPlugin::HtmlUtil::createHtmlForm(@_);
}

###########################
# xpGetProjectTeams
#
# Get all the teams on this project
sub xpGetProjectTeams {
    return &TWiki::Plugins::XpTrackerPlugin::Cache::getProjectTeams(@_);
}

###########################
# xpGetIterStories
#
# Returns a list of all stories in this web in this iteration
sub xpGetIterStories {
    return &TWiki::Plugins::XpTrackerPlugin::Cache::getIterStories(@_);
}

###########################
# xpGetTeamIterations
#
# Get all the iterations for this team
sub xpGetTeamIterations {
    return &TWiki::Plugins::XpTrackerPlugin::Cache::getTeamIterations(@_);
}

###########################
# xpGetAllProjects
#
# Get all the projects for the web
sub xpGetAllProjects {
    return &TWiki::Plugins::XpTrackerPlugin::Cache::getAllProjects(@_);
}

###########################
# initCache
#
# Initializes the cache for the specified web
sub initCache {
    TWiki::Plugins::XpTrackerPlugin::Cache::initCache(@_);
}

###########################
# getColor
#
# Return the color for a given status
sub getColor {
    return TWiki::Plugins::XpTrackerPlugin::Status::getColor(@_);
}

###########################
# getStatusS
#
# Return the string associated to a given status
sub getStatusS {
    return TWiki::Plugins::XpTrackerPlugin::Status::getStatusS(@_);
}

# =========================

1;
