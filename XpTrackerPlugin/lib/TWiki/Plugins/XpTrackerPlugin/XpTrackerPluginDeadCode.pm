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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# =========================
# DEAD CODE FROM XpTrackerPlugin
# =========================
package TWiki::Plugins::XpTrackerPlugin::XpTrackerPluginDeadCode;

###########################
# xpTaskStatus
# WARNING: (RAF) THIS METHOD IS NOT BEING USED ANYWHERE... IS DEAD CODE
# Substituted by a call to TWiki::Plugins::XpTrackerPlugin::Status::getStatus(est,spent,"N");
# Leaved here for historical reasons
# Calculates the status of a task.
#sub xpTaskStatus {
#    my @who = xpRipWords($_[0]);
#    my @etc = xpRipWords($_[1]);
#    my @spent = xpRipWords($_[2]);
#
#    # status - 0=not started, 1=inprogress, 2=complete
#
#    # anyone assigned?
#    if (@who == 0) {
#    return 0; # nobody assigned, not started
#    }
#    foreach my $who (@who) {
#    if ($who eq "?") {
#        return 0; # not assigned correctly, not started
#    }
#    }
#
#    # someone is assigned, see if ANY time remaining
#    my $isRemaining = 0;
#    foreach my $etc (@etc) {
#        if ($etc eq "?") {
#            return 0; # no "todo", so still not started
#        }
#        if ($etc > 0) {
#            $isRemaining = 1;
#        }
#    }
#    if (!$isRemaining) {
#        return 2; # If no time remaining, must be complete
#    }
#
#    # If ANY spent > 0, then in progress, else not started
#    foreach my $spent (@spent) {
#        if ($spent > 0) {
#            return 1; # in progress
#        }
#    }
#    return 0;
#
#}

###########################
# xpGetIterDevelopers
# WARNING: (RAF) THIS METHOD IS NOT BEING USED ANYWHERE... IS DEAD CODE
# To know the developers for an iteration, a scan of the tasks must be made
# Returns a list of all developers in this iteration in this web.
#sub xpGetIterDevelopers {
#
#    my ($iteration,$web) = @_;
#
#    my @iterStories = &xpGetIterStories($iteration, $web);
#
#    my @dev = ();
#    foreach my $story (@iterStories) {
#    my $storyText = &TWiki::Func::readTopic($web, $story);
#
#    # search for text matching a developer
#    my $ret = "";
#    while ($ret = &xpGetValueAndRemove("\\*Assigned to\\*", $storyText, "who")) {
#        push @dev, $ret;
#    }
#    }
#    @dev = sort_unique(@dev);
#
#    return @dev;
#}

###########################
# xpGetTableValue
# WARNING: (RAF) THIS METHOD IS NOT BEING USED ANYWHERE... IS DEAD CODE
#
# Return value from passed in text with passed in title
# This searches a horizontal table to find the matching field
#sub xpGetTableValue {
#    my $title = $_[0];
##    # my $text = $_[1]; # DONT MAKE COPY for performance reasons
#    my $result = "";
#
#    my $pattern2 = "\\|[ \\t]*".$title."[ \\t]*\\|[ \\t]*(.*?)[ \\t]*\\|";
#
#    if ($_[1] =~ /$pattern2/s) {
#      $result = $1;
#    }
#    return $result;
#}

1;
