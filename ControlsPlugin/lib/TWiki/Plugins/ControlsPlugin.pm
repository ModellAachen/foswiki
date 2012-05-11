# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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
#
## Bug: If we allow the [[][]] notation to distinguish between value and
## display, we should take care of this for URL parameters also.
## Bug: If selection is "", then a hierarchical control is generated but
## may be in a context where it does not make sense. Figure out how to
## force an empty menu in that case (or some other default solution).
## Idea: If selector="", list all options, rather than none. Use none only
## if unknown selection is given.

# =========================
package TWiki::Plugins::ControlsPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug
  $maxlevel @menuStack
);

$VERSION    = '$Rev: 9598$';
$RELEASE    = 'Dakar';
$pluginName = 'ControlsPlugin';    # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning(
            "This version of $pluginName works only with TWiki 4 and greater.");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    TWiki::Func::registerTagHandler( 'CONTROL', \&handleControls,
        'context-free' );

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;

    return 1;
}

# =========================

=pod
---++ sub handleControls ( $session, $params, $web, $topic ) ==> $value
| $session | twiki session |
| $params | twiki parameter string  |
| $web | web and  |
| $topic | topic to display the name for |

=cut

sub handleControls {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    my $name  = $params->{"_DEFAULT"}  || $params->{name} || "";
    my $web   = $params->{web}         || $theWeb;
    my $topic = $params->{topic}       || $theTopic;
    my $size  = $params->{size}        || 1;
    my $type  = $params->{type}        || "select";
    my $url   = $params->{urlparam}    || "off";
    my $sep   = $params->{separator}   || " ";
    my $form  = $params->{form}        || '';
    my $sel   = $params->{selection};
    my $msg1  = $params->{initmessage} || 'Select previous level first';
    my $msg2  = $params->{nextmessage}
      || '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
    $maxlevel  = 0;
    @menuStack = ();

    my $menu = getListOfFieldValues(
        $session, $web, $topic, $name, $type, $size,
        $sep,     $url, $msg1,  $msg2, $sel
    );

    if ( $maxlevel > 0 ) {

        # hierarchical menu present
        TWiki::Func::addToHEAD( 'control',
"<SCRIPT language=JavaScript src=\"%PUBURLPATH%/$installWeb/$pluginName/cascade_select.js\" type=text/javascript></SCRIPT>"
        );

        my $tag = "new DepSelectOne(document.$form.elements[\'${name}0\']";
        for ( my $idx = 1 ; $idx <= $maxlevel ; $idx++ ) {
            $tag .= ", \'$name$idx\'";
        }
        $tag .= ')';
        TWiki::Func::addToHEAD(
            "$name$form", "<SCRIPT type=\"text/javascript\">
//<![CDATA[
   addLoadEvent(initControl$name$form);
   function initControl$name$form () {
      $tag;
   }
//]]>
</SCRIPT>"
        );
    }

    return $menu;
}

# ============================
# Get list of possible field values
# If topic contains Web this overrides webName

=pod

---++ sub getListOfFieldValues ( $session, $webName, $topic, $name, $type, $size, $url, $msg1, $msg2, $sel )

Not yet documented.

=cut

sub getListOfFieldValues {
    my (
        $session, $webName, $topic, $name, $type, $size,
        $sep,     $url,     $msg1,  $msg2, $selection
    ) = @_;

    # Bug: Due to the onLoad that configures the hierarchical menu,
    # the fancy features do not work unless this is in a form. Outside a
    # form this operates in fallback mode.
    #
    # Needs error checking if items are not "select" in hierarchical menu
    # i.e., if not select, we need to pull out a right option even if it has
    # a [[][]] name
    #
    # Requires that the menu hierarchy is complete (i.e., all branches
    # have the same depth).

    $maxlevel = 0;
    $menuStack[0] = '';

    if ( $topic =~ /^(.*)\.(.*)$/ ) {
        $webName = $1;
        $topic   = $2;
    }
    my @posValues = ();

    if ( &TWiki::Func::topicExists( $webName, $topic ) ) {
        my ( $meta, $text ) = &TWiki::Func::readTopic( $webName, $topic );

        # Processing of SEARCHES for Lists
        $text =~
          s/%SEARCH{(.*?)}%/&TWiki::_SEARCH($session, $1, $webName, $topic)/geo;
        @posValues = &TWiki::Form::_getPossibleFieldValues($text);
    }
    else {

        # Need to deal with error case.
    }

    my $value  = "";
    my $script = '';
    $type = $type || "select";
    $size = $size || 1;

    if ( $type eq "select" ) {
        my $idx = 0;
        my $val = '';
        $val =
          ( $url eq "on" )
          ? "<option value=\"%URLPARAM{\"$name\"}%\">%URLPARAM{\"$name\"}%</option>"
          : "";
        foreach my $item (@posValues) {

            #next if ($item =~ m/^\s*$/o);
            my $web = $webName;
            $item =~ s/%WEB%/$web/o;
            my $subtopic = $item;
            if ( $item =~ /\[\[(.+)\]\[(.+)\]\]/ ) {

                # hierarchical expansion
                $item     = $2;
                $subtopic = $1;
                if ( $subtopic =~ /^(.*)\.(.*)$/ ) {

                    # alternate web
                    $web      = $1;
                    $subtopic = $2;
                }
            }
            elsif ( $item =~ /^(.*)\.(.*)$/ ) {

                # alternate web
                $web      = $1;
                $subtopic = $2;
                $item     = $2;
            }
            if ($selection) {

          # only consider $selection, unless it is empty (in that case, use all)
                next unless ( $item eq $selection );
            }
            if ( $subtopic && TWiki::Func::topicExists( $web, $subtopic ) ) {

                # hierarchical control
                getHierarchicalMenu(
                    $session, $web, $subtopic, $name, $type, $size,
                    $sep,     $url, 1,         $item, $msg1, $msg2
                );
            }
## If we want to be able to set [[value][title]] use the following, but
## it will not work if we have subtopics
##	$val .= "   <option value=\"$subtopic\">$item</option>";
            $val .= "   <option value=\"$item\">$item</option>";
            $idx++;
        }
        my $menudepth = $#menuStack;    # could use $maxlevel
        if ( defined $selection && ( $menudepth > 0 ) ) {
            for ( my $idy = 1 ; $idy <= $menudepth ; $idy++ ) {
                $menuStack[ $idy - 1 ] = $menuStack[$idy];
            }
            pop @menuStack;
            $maxlevel--;
            $val = $menuStack[0];
            unless ($maxlevel) {
                $val =~ s/<option value="choose">$msg2<\/option>//o;
                $val =
"<option value=\"%URLPARAM{\"$name\"}%\">%URLPARAM{\"$name\"}%</option>$val"
                  if ( $url eq "on" );
            }
        }
        if ( defined $selection && !$maxlevel ) {
            $maxlevel = 0;
            $value    = '';
        }
        elsif ($maxlevel) {
            $menuStack[0] = $val;
            $value = generateHierarchicalMenu( $name, $sep, $msg1 );
        }
        else {
            $value = "<select name=\"$name\" size=\"$size\">";
            $value .= "$val</select>";
        }
    }
    elsif ( $type =~ "^checkbox" ) {
        my $val   = "<table  cellspacing=\"0\" cellpadding=\"0\"><tr>";
        my $lines = 0;
        foreach my $item (@posValues) {
            my $expandedItem =
              $session->handleCommonTags( $item, $webName, $topic );
            $val .=
"\n<td><input class=\"twikiCheckBox\" type=\"checkbox\" name=\"$name$item\" />$expandedItem &nbsp;&nbsp;</td>";
            if ( $size > 0 && ( $lines % $size == $size - 1 ) ) {
                $val .= "\n</tr><tr>";
            }
            $lines++;
        }
        $val =~ s/\n<\/tr><tr>$//;
        $value = "$val\n</tr></table>\n";
    }
    elsif ( $type eq "radio" ) {
        my $val   = "<table  cellspacing=\"0\" cellpadding=\"0\"><tr>";
        my $lines = 0;
        foreach my $item (@posValues) {
            my $expandedItem =
              $session->handleCommonTags( $item, $webName, $topic );
            $val .=
"\n<td><input class=\"twikiRadioButton\" type=\"radio\" name=\"$name\" value=\"$item\" />$expandedItem &nbsp;&nbsp;</td>";
            if ( $size > 0 && ( $lines % $size == $size - 1 ) ) {
                $val .= "\n</tr><tr>";
            }
            $lines++;
        }
        $val =~ s/\n<\/tr><tr>$//;
        $value = "$val\n</tr></table>\n";
    }
    return $value;
}

=pod

---++ sub getHierarchicalMenu ( $session, $webName, $topic, $name, $type, $size, $url, $level, $upper, $msg1, $msg2  )

Not yet documented.

=cut

sub getHierarchicalMenu {
    my (
        $session, $webName, $topic, $name,  $type, $size,
        $sep,     $url,     $level, $upper, $msg1, $msg2
    ) = @_;

    # Due to the onLoad that configures the hierarchical menu,
    # the fancy features do not work unless this is in a form. Outside a
    # form this operates in fallback mode.
    #
    # Requires that the menu hierarchy is complete (i.e., all branches
    # have the same depth).

    $level = 0 unless $level;
    $maxlevel = $level if ( $level > $maxlevel );
    my $hierarchicalmenu = '';
    $menuStack[$level] = '' unless $menuStack[$level];

    if ( $topic =~ /^(.*)\.(.*)$/ ) {
        $webName = $1;
        $topic   = $2;
    }
    my @posValues = ();

    if ( &TWiki::Func::topicExists( $webName, $topic ) ) {
        my ( $meta, $text ) = &TWiki::Func::readTopic( $webName, $topic );

        # Processing of SEARCHES for Lists
        $text =~
          s/%SEARCH{(.*?)}%/&TWiki::_SEARCH($session, $1, $webName, $topic)/geo;
        @posValues = &TWiki::Form::_getPossibleFieldValues($text);
    }
    else {

        # Need to deal with error case.
    }

    unless (@posValues) {

        # Was not hierarchical after all...
        pop @menuStack;
        $maxlevel--;
        return;
    }

    my $value  = "";
    my $script = '';
    $type = $type || "select";
    $size = $size || 1;

    # type must be select
    my $web = $webName;
    my $idx = 0;
    my $val = '';
    $val .= "<option value=\"choose\">$msg2</option>";
## Cannot select from the URL parameter
#      $val .= ($url eq "on")?"<option value=\"%URLPARAM{\"$name$level\"}%\">%URLPARAM{\"$name$level\"}%</option>":"";
    foreach my $item (@posValues) {

        #next if ($item =~ m/^\s*$/o);
        if ( $item =~ /\[\[(.+)\]\[(.+)\]\]/ ) {

            # hierarchical expansion
            $item     = $2;
            $subtopic = $1;
            if ( $subtopic =~ /^(.*)\.(.*)$/ ) {

                # alternate web
                $web      = $1;
                $subtopic = $2;
            }
        }
        elsif ( $item =~ /^(.*)\.(.*)$/ ) {

            # alternate web
            $web      = $1;
            $subtopic = $2;
            $item     = $2;
        }
        else {
            $subtopic = $item;
        }
        if ( $subtopic && TWiki::Func::topicExists( $web, $subtopic ) ) {

            # hierarchical control
            getHierarchicalMenu(
                $session, $web, $subtopic,  $name, $type, $size,
                $sep,     $url, $level + 1, $item, $msg1, $msg2
            );
        }
        $val .= "   <option value=\"$subtopic\">$item</option>";
        $idx++;
    }

    $menuStack[$level] .= $val;
}

sub generateHierarchicalMenu {
    my ( $name, $sep, $msg1 ) = @_;
    my $menu .= "<select name=\"${name}0\">";
    $menu .=
"<option value=\"choose\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</option>";
    $menu .= $menuStack[0];
    $menu .= "</select>";
    for ( my $idx = 1 ; $idx <= $maxlevel ; $idx++ ) {
        $menu .= $sep;
        $menu .= "<select name=\"$name$idx\">";
        $menu .= "<option value=\"choose\">$msg1</option>";
        $menu .= $menuStack[$idx];
        $menu .= "</select>";
    }
    return $menu;

}
1;
