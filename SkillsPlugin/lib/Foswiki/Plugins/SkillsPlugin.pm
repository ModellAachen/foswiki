# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2007 - 2009 Andrew Jones, andrewjones86@googlemail.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.

package Foswiki::Plugins::SkillsPlugin;

use strict;

use Assert;
use JSON ();

use Foswiki::Plugins::SkillsPlugin::Skills     ();
use Foswiki::Plugins::SkillsPlugin::UserSkills ();
use Foswiki::Plugins::SkillsPlugin::SkillNode  ();

# Plugin Variables
our $VERSION           = '$Rev$';
our $RELEASE           = '3 Nov 2009';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION =
  'Allows users to list their skills, which can then be searched';
our $recursionBlock;

# ========================= INIT
sub initPlugin {

    # Set a context that defined how many levels of
    Foswiki::Func::getContext()->{skillsplugin_subcategories} = 1;

    Foswiki::Func::registerTagHandler( 'SKILLS', \&_handleTag );

    Foswiki::Func::registerTagHandler( 'SKILLRATINGS', \&_SKILLRATINGS );

    # Register REST handlers
    Foswiki::Func::registerRESTHandler( 'createNode', \&_rest_createNode );
    Foswiki::Func::registerRESTHandler( 'renameNode', \&_rest_renameNode );
    Foswiki::Func::registerRESTHandler( 'moveNode',   \&_rest_moveNode );
    Foswiki::Func::registerRESTHandler( 'deleteNode', \&_rest_deleteNode );
    Foswiki::Func::registerRESTHandler( 'getChildNodes',
        \&_rest_getChildNodes );
    Foswiki::Func::registerRESTHandler( 'getSkillDetails',
        \&_rest_getSkillDetails );
    Foswiki::Func::registerRESTHandler( 'getSkillTree', \&_rest_getSkillTree );
    Foswiki::Func::registerRESTHandler( 'search',       \&_rest_search );

    Foswiki::Func::registerRESTHandler( 'addEditSkill', \&_rest_addEditSkill );
    Foswiki::Func::registerRESTHandler( 'saveUserChanges',
        \&_rest_saveUserChanges );

    return 1;
}

sub _getLevels {
    my $names = Foswiki::Func::getPreferencesValue('SKILLSPLUGIN_RATINGS')
      || "None,Ancient Knowledge,Working Knowledge,Expert,Guru";
    my @levels = split( /,\s*/, $names );
    return \@levels;
}

# Generate the divs that contain the tooltips
sub _genTooltips {
    my $skills = new Foswiki::Plugins::SkillsPlugin::Skills();
    my $out    = '';
    $skills->visit(
        undef,
        sub {
            my ( $node, $out ) = @_;
            my $id   = $node->getID();
            my $desc = Foswiki::Func::renderText( $node->{text} );
            if ( $desc && length($desc) > 0 ) {
                $$out .= "<div class='skillsplugin_tooltip' id='tip$id'>"
                  . "$desc</div>";
            }
        },
        \$out
    );
    return $out;
}

# ========================= TAGS
sub _handleTag {

    my $out = '';

    my $action =
         $_[1]->{action}
      || $_[1]->{_DEFAULT}
      || return 'No action specified';

    my $start = "<noautolink>\n";
    my $end   = "\n</noautolink>";

    for ($action) {
        /user/
          and $out =
            $start
          . Foswiki::Plugins::SkillsPlugin::_tagUserSkills( $_[1] )
          . $end,
          last;

#    /group/ and $out = $start . Foswiki::Plugins::SkillsPlugin::Tag::_tagGroupSkills($_[1]) . $end, last; # shows skills for a particular group
        /browse/
          and $out =
            $start
          . Foswiki::Plugins::SkillsPlugin::_tagBrowseSkills( $_[1] )
          . $end, last;
        /editall/
          and $out =
            $start
          . Foswiki::Plugins::SkillsPlugin::_tagEditAllSkills( $_[1] )
          . $end,
          last;
        /edit/
          and $out =
            $start
          . Foswiki::Plugins::SkillsPlugin::_tagEditSkills( $_[1] )
          . $end,
          last;
        /showskill/
          and $out =
            $start
          . Foswiki::Plugins::SkillsPlugin::_tagShowSkills( $_[1] )
          . $end,
          last;
        /showcat/
          and $out =
            $start
          . Foswiki::Plugins::SkillsPlugin::_tagShowCategories( $_[1] )
          . $end, last;    # show all categories in a format
        /^search$/
          and $out =
            $start
          . Foswiki::Plugins::SkillsPlugin::_tagSearchForm( $_[1] )
          . $end, last;    # creates a search form
        /searchresults/
          and $out = $start . '<div id="search-skill-results"></div>' . $end,
          last;            # container for the results

        # action not valid
        $out =
          "<span class='foswikiAlert'>Error: Unknown action ('$action')</span>",
          last;
    }

    #$allowedit = 0;

    return $out;
}

sub _SKILLRATINGS {
    my ( $session, $params ) = @_;

    my $format =
        defined $params->{_DEFAULT} ? $params->{_DEFAULT}
      : defined $params->{format}   ? $params->{format}
      :                               '$name: $value';
    my $marker = defined $params->{marker} ? $params->{marker} : 'selected';
    my $separator =
      defined $params->{separator} ? $params->{separator} : '$n()';
    my $selection = defined $params->{selection} ? $params->{selection} : -1;
    my $levels = _getLevels();
    $selection = $#$levels if $selection eq '$';
    my $from = defined $params->{from} ? ( $params->{from} || 0 ) : 0;
    my $to = defined $params->{to} ? ( $params->{to} || $#$levels ) : $#$levels;

    my @values = ();
    foreach my $value ( $from .. $#$levels ) {
        my $name = $levels->[$value];
        my $mark = ( $value == $selection ) ? $marker : '';
        my $item = $format;
        $item =~ s/\$name/$name/g;
        $item =~ s/\$value/$value/g;
        $item =~ s/\$marker/$mark/g;
        push( @values, $item );
    }
    my $out = join( $separator, @values );
    return Foswiki::Func::decodeFormatTokens($out);
}

# allows the user to print all categories in format of their choice
sub _tagShowCategories {
    my $params = shift;

    my ( $format, $separator ) = ( $params->{format}, $params->{separator} );

    $separator = ', ' unless defined $separator;
    $separator = Foswiki::Func::decodeFormatTokens($separator);

    $format = '$category' unless defined $format;

    my @entries;

    my $skills = new Foswiki::Plugins::SkillsPlugin::Skills();
    $skills->visit(
        sub {
            my $node = shift;
            return unless $node->{parent} && $node->hasChildren();
            my $entry = $format;
            $entry =~ s/\$category/$node->getPath()/ge;
            $entry = Foswiki::Func::decodeFormatTokens($entry);
            push( @entries, $entry );
        }
    );

    return join( $separator, @entries );
}

sub _tagShowSkills {
    my $params = shift;

    my ( $cat, $format, $separator, $prefix, $suffix, $catSeparator ) = (
        $params->{category}, $params->{format}, $params->{separator},
        $params->{prefix},   $params->{suffix}
    );

    my $hasSeparator = $separator ne '' if $separator;
    my $hasFormat    = $format    ne '' if $format;

    $separator = ', ' unless ( $hasSeparator || $hasFormat );
    $separator ||= '';
    $separator =~ s/\$n/\n/go;

    $format = '$skill' unless $hasFormat;
    $format .= "\n" unless $separator;
    $format =~ s/\$n/\n/go;

    $prefix =~ s/\$n/\n/go if $prefix;
    $suffix =~ s/\$n/\n/go if $suffix;
    $catSeparator = "\n" unless defined $catSeparator;

    # iterator of all categories
    my $skills = new Foswiki::Plugins::SkillsPlugin::Skills();
    my $categories;
    if ($cat) {    # category specified
        my @path = split( '/', $cat );
        $skills = $skills->getByPath(@path);
    }

    my $out = '';
    $skills->visit(
        sub {
            my ( $node, $out ) = @_;
            return unless $node->{name};
            if ( !$node->hasChildren() ) {
                my $line = $format;
                $line =~ s/\$category/$node->{parent}->getPath()/goe;
                $line =~ s/\$skill/$node->{name}/go;
                $$out .= $line . $separator;
            }
        },
        sub {
            my ( $node, $out ) = @_;
            return unless $node->{name};
            if ( $node->hasChildren() ) {
                my $suffixLine = $suffix || '';
                $suffixLine =~ s/\$category/$node->{parent}->getPath()/goe;
                $suffixLine =~ s/\$n/\n/go;
                $$out .= $suffixLine;
            }
        },
        \$out
    );
    return $out;
}

# creates a form allowing users to edit their skills
sub _tagEditSkills {
    my $params = shift;
    my $user   = Foswiki::Func::getWikiName();
    my $style  = $params->{style} || '';

    my $out = Foswiki::Func::readTemplate( 'skillsedit' . $style );

    _addHeads('addEditSkills');

    return $out . _genTooltips();
}

# creates a form allowing users to edit their skills
sub _tagEditAllSkills {
    my $params = shift;
    my $user   = Foswiki::Func::getWikiName();

    my $out = Foswiki::Func::readTemplate('skillseditall');

    _addHeads('editAllSkills');

    return $out . _genTooltips();
}

sub _addCommentTip {
    my ( $user, $skill ) = @_;
    if ( !$skill->{text} ) {
        return ( '', '' );
    }
    my $id = 'comment:' . $user->{name} . ':' . $skill->getID();
    my $tipDiv =
      "<div style='display:none' id='tip$id'>" . $skill->{text} . "</div>";
    my $tipIcon = "<span id='$id' class='skillsTipped'>%ICON{note}%</span>";
    return ( $tipIcon, $tipDiv );
}

sub _tagUserSkills {

    my $params = shift;

    my $username = $params->{user}   || Foswiki::Func::getWikiName();
    my $twisty   = $params->{twisty} || 'closed';

    Foswiki::Func::readTemplate('skillsuserview');

    my $out = Foswiki::Func::expandTemplate("skills:userview:start");

    my $tmplCatStart =
      Foswiki::Func::expandTemplate("skills:userview:repeated:categorystart");
    my $tmplCatEnd =
      Foswiki::Func::expandTemplate("skills:userview:repeated:categoryend");

    my $tmplSkillStart =
      Foswiki::Func::expandTemplate("skills:userview:repeated:skillstart");
    my $tmplSkillEnd =
      Foswiki::Func::expandTemplate("skills:userview:repeated:skillend");

    my $userSkills = new Foswiki::Plugins::SkillsPlugin::UserSkills();
    my $user       = $userSkills->getUser($username);
    return '' unless $user;

    my $commentTips = '';

    $user->visit(
        sub {
            my ( $node, $out ) = @_;
            my $nodeOut = '';

            return if $node == $user;

            if ( $node->hasChildren() ) {

                # Open Category
                $nodeOut = $tmplCatStart;
            }
            else {

                # Open and Close Skill
                $nodeOut = $tmplSkillStart;

                $nodeOut .= _compileUserSkill( $user, $node, 'skills:userview',
                    \$commentTips );

                $nodeOut .= $tmplSkillEnd;
            }
            $nodeOut =~ s/%ID%/$node->getID()/ge;
            $nodeOut =~ s/%NAME%/$node->{name}/ge;
            $$out .= $nodeOut;
        },
        sub {
            my ( $node, $out ) = @_;

            return if $node == $user;

            if ( $node->hasChildren() ) {

                # Close Category
                my $nodeOut = $tmplCatEnd;
                $nodeOut =~ s/%ID%/$node->getID()/ge;
                $nodeOut =~ s/%NAME%/$node->{name}/ge;
                $$out .= $nodeOut;
            }
        },
        \$out
    );

    $out .= Foswiki::Func::expandTemplate("skills:userview:end");

    $out =~ s/%USER%/$user->{name}/g;

    _addHeads( 'viewUserSkills', $twisty );

    return $out . _genTooltips() . $commentTips;
}

sub _tagSearchForm {
    my $out = Foswiki::Func::readTemplate('skillssearchform');

    _addHeads('searchSkills');

    return $out . _genTooltips();
}

sub _tagBrowseSkills {

    my $params = shift;

    my $twisty = $params->{twisty} || 'closed';

    Foswiki::Func::readTemplate('skillsbrowseview');

    # loop over all skills from skills.txt
    # if a user has this skill, output them

    my $body = '';

    my $commentTips = '';

    my $skills     = new Foswiki::Plugins::SkillsPlugin::Skills();
    my $userSkills = new Foswiki::Plugins::SkillsPlugin::UserSkills($skills);
    my $template   = Foswiki::Func::expandTemplate("skills:browseview:start");

    $skills->visit(
        sub {
            my $node = shift;
            if ( $node->hasChildren() ) {

                # Has children; category
                _openCategory( $node, @_ );
            }
            else {

                # No children: skill
                _openSkill( $node, $userSkills, @_ );
            }
        },
        sub {
            my $node = shift;
            if ( $node->hasChildren() ) {

                # Has children; category
                _closeCategory( $node, @_ );
            }
            else {

                # No children: skill
                _closeSkill( $node, @_ );
            }
        },
        \$template,
        \$commentTips
    );
    $template .= Foswiki::Func::expandTemplate("skills:browseview:end");

    _addHeads( 'browseSkills', $twisty );

    return $template . _genTooltips() . $commentTips;
}

sub _openCategory {
    my ( $node, $out, $commentTips ) = @_;

    return unless defined( $node->{name} );

    my $catOut =
      Foswiki::Func::expandTemplate("skills:browseview:repeated:categorystart");
    $catOut =~ s/%ID%/$node->getID()/ge;
    $catOut =~ s/%NAME%/$node->{name}/g;

    $$out .= $catOut;
}

sub _closeCategory {
    my ( $node, $out, $commentTips ) = @_;

    return unless defined( $node->{name} );

    my $catOut =
      Foswiki::Func::expandTemplate("skills:browseview:repeated:categoryend");
    $catOut =~ s/%ID%/$node->getID()/ge;
    $catOut =~ s/%NAME%/$node->{name}/ge;
    $$out .= $catOut;
}

sub _openSkill {
    my ( $node, $userSkills, $out, $commentTips ) = @_;

    # iterate over users and find out if they have
    # this skill.
    my @path = $node->getPathArray();

    my $levels = _getLevels();

    my $skillOut =
      Foswiki::Func::expandTemplate("skills:browseview:repeated:skillstart");

    $skillOut .=
      _compileAllUserSkills( \@path, 'skills:browseview', $userSkills,
        $commentTips );

    $skillOut =~ s/%ID%/$node->getID()/ge;
    $skillOut =~ s/%NAME%/$node->{name}/ge;

    $$out .= $skillOut;
}

sub _closeSkill {
    my ( $node, $out ) = @_;

    my $skillOut =
      Foswiki::Func::expandTemplate("skills:browseview:repeated:skillend");
    $skillOut =~ s/%ID%/$node->getID()/ge;
    $skillOut =~ s/%NAME%/$node->{name}/ge;

    $$out .= $skillOut;
}

# Gather skills for all users
sub _compileAllUserSkills {
    my ( $path, $templates, $userSkills, $commentTips, $matches ) = @_;

    my $out = '';
    my $it  = Foswiki::Func::eachUser();
    while ( $it->hasNext() ) {
        my $user = $userSkills->getUser( $it->next() );
        next unless $user;
        my $skill = $user->getByPath(@$path);
        next unless $skill;                 # User does not have this skill
        next unless $skill->{rating} > 0;
        $out .= _compileUserSkill( $user, $skill, $templates, $commentTips,
            $matches );
    }
    return $out;
}

# Gather skills for a single user
sub _compileUserSkill {
    my ( $user, $skill, $templates, $commentTips, $matches ) = @_;

    my $levels = _getLevels();

    my $out =
      Foswiki::Func::expandTemplate( $templates . ':repeated:userstart' );

    my $tmplPreRating =
      Foswiki::Func::expandTemplate( $templates . ':repeated:prerating' );

    my $i = 1;
    while ( $i < $skill->{rating} ) {
        $out .= $tmplPreRating;
        $i++;
    }

    if ( $skill->{rating} > 0 ) {
        $out .=
          Foswiki::Func::expandTemplate( $templates . ':repeated:rating' );
        $i++;
    }

    my $tmplPostRating =
      Foswiki::Func::expandTemplate( $templates . ':repeated:postrating' );
    while ( $i <= $#$levels ) {
        $out .= $tmplPostRating;
        $i++;
    }
    $out .= Foswiki::Func::expandTemplate( $templates . ':repeated:userend' );

    # comment
    my ( $tipIcon, $tipDiv ) = _addCommentTip( $user, $skill );
    $$commentTips .= $tipDiv;
    $out =~ s/%COMMENTTIP%/$tipIcon/g;
    $out =~ s/%USER%/$user->{name}/g;

    $$matches++ if defined $matches;

    return $out;
}

sub _getPathFromCGI {
    my @path;
    my $request = Foswiki::Func::getCgiQuery();
    if ( defined $request->param('path') ) {
        my $paths = $request->param('path');
        $paths =~ s#//+#/#;
        $paths =~ s#/+$##;
        $paths =~ s#/+$##;
        @path = split( '/', $paths );
    }
    else {
        for ( my $i = 1 ; $i < 10 ; $i++ ) {
            if ( defined( $request->param("path$i") ) ) {
                push( @path, split( '/', $request->param("path$i") ) );
            }
        }
    }
    return @path;
}

# Add a skill or category to the skills database
# params: path name description topic
sub _rest_createNode {
    my ( $session, $plugin, $verb, $response ) = @_;

    my $request = Foswiki::Func::getCgiQuery();

    my @path        = _getPathFromCGI();
    my $leafname    = $request->param('name');
    my $description = $request->param('description');

    my $skills = new Foswiki::Plugins::SkillsPlugin::Skills();
    my $leaf   = new Foswiki::Plugins::SkillsPlugin::SkillNode($leafname);
    $leaf->{text} = $description if defined $description;
    $skills->addByPath( $leaf, @path );
    $skills->save();

    return returnRESTResult( $response, 200, $leaf->getPath() . " added" );
}

# Rename a skill or category in the skills database
# params: path newname topic
sub _rest_renameNode {
    my ( $session, $plugin, $verb, $response ) = @_;

    my $request = Foswiki::Func::getCgiQuery();

    my @path    = _getPathFromCGI();
    my $newname = $request->param('newname');

    # rename in skills.txt
    my $skills = new Foswiki::Plugins::SkillsPlugin::Skills();
    my $node   = $skills->getByPath(@path);
    return returnRESTResult( $response, 500,
        join( '/', @path ) . " is not in the skills database" )
      unless $node;

    # SMELL: should check the rename doesn't create a duplicate
    $node->{name} = $newname;
    $skills->save();

    # rename in users
    my $users = new Foswiki::Plugins::SkillsPlugin::UserSkills($skills);
    my $it    = Foswiki::Func::eachUser();
    while ( $it->hasNext() ) {
        my $user = $users->getUser( $it->next() );
        my $node = $user->getByPath(@path);
        $node->{name} = $newname if $node;
        $users->save($user);
    }

    return returnRESTResult( $response, 200, "Renamed to " . $node->getPath() );
}

# Delete a skill or category from the skills database
# params: path
sub _rest_deleteNode {
    my ( $session, $plugin, $verb, $response ) = @_;

    my $request = Foswiki::Func::getCgiQuery();
    my @path    = _getPathFromCGI();

    # delete in skills.txt
    my $skills = new Foswiki::Plugins::SkillsPlugin::Skills();
    my $node   = $skills->getByPath(@path);
    return returnRESTResult( $response, 500,
        join( '/', @path ) . " is not in the skills database" )
      unless $node;
    $node->remove();
    $skills->save();

    # rename in users
    my $users = new Foswiki::Plugins::SkillsPlugin::UserSkills($skills);
    my $it    = Foswiki::Func::eachUser();
    while ( $it->hasNext() ) {
        my $user = $users->getUser( $it->next() );
        my $node = $user->getByPath(@path);
        if ($node) {
            $node->remove();
            $users->save($user);
        }
    }

    return returnRESTResult( $response, 200, "Deleted" );
}

# Move a node to a new parent
# params: path newparent
sub _rest_moveNode {
    my ( $session, $plugin, $verb, $response ) = @_;

    my $request   = Foswiki::Func::getCgiQuery();
    my @path      = _getPathFromCGI();
    my @newparent = split( '/', $request->param('newparent') );

    my $skills = new Foswiki::Plugins::SkillsPlugin::Skills();
    my $node   = $skills->getByPath(@path);
    return returnRESTResult( $response, 500,
        join( '/', @path ) . " is not in the skills database" )
      unless $node;
    $node->remove();

    # Add it back in at the new path
    $skills->addByPath( $node, @newparent );
    $skills->save();

    # move in users
    my $users = new Foswiki::Plugins::SkillsPlugin::UserSkills($skills);
    my $it    = Foswiki::Func::eachUser();
    while ( $it->hasNext() ) {
        my $user = $users->getUser( $it->next() );
        my $node = $user->getByPath(@path);
        if ($node) {
            $node->remove();
            $user->addByPath( $node, @newparent );
            $users->save($user);
        }
    }
    return returnRESTResult( $response, 200, "Moved" );
}

# Returns names of all possible subcategories/skills for the given path
sub _rest_getChildNodes {
    my ( $session, $plugin, $verb, $response ) = @_;

    my $request  = Foswiki::Func::getCgiQuery();
    my @path     = _getPathFromCGI();
    my $leafonly = $request->param('leafonly');

    my $skills = new Foswiki::Plugins::SkillsPlugin::Skills();
    my $node   = $skills->getByPath(@path);
    return returnRESTResult( $response, 500,
        join( '/', @path ) . " is not in the skills database" )
      unless $node;
    my @kids = map { $_->{name} }
      grep { !( $leafonly && $_->hasChildren ) } @{ $node->{childNodes} };
    return returnRESTResult( $response, 200, JSON::to_json( \@kids ) );
}

# Returns complete skill tree rooted at a given path,
# including the ratings and comments for the current user's skills
sub _rest_getSkillTree {
    my ( $session, $plugin, $verb, $response ) = @_;

    my $request = Foswiki::Func::getCgiQuery();
    my @path    = _getPathFromCGI();

    my $skills = new Foswiki::Plugins::SkillsPlugin::Skills();
    my $node   = $skills->getByPath(@path);
    return returnRESTResult( $response, 500,
        join( '/', @path ) . " is not in the skills database" )
      unless $node;

    my $userData;
    my $users = new Foswiki::Plugins::SkillsPlugin::UserSkills($skills);
    my $user  = $users->getUser( Foswiki::Func::getWikiName() );
    if ($user) {

        # User has skills
        $userData = $user->getByPath(@path);
    }
    return returnRESTResult( $response, 200, $node->toJSON($userData) );
}

# Gets all the details for a particular skill for the user logged in
# i.e. rating and comments
# TODO: constrain the skills to the legal set
sub _rest_getSkillDetails {
    my ( $session, $plugin, $verb, $response ) = @_;

    my @path = _getPathFromCGI();

    my $users    = new Foswiki::Plugins::SkillsPlugin::UserSkills();
    my $username = Foswiki::Func::getWikiName();
    my $user     = $users->getUser($username);
    my $result   = {
        user    => $username,
        path    => join( '/', @path ),
        rating  => '',
        comment => '',
    };
    return returnRESTResult( $response, 200, JSON::to_json($result) )
      unless $user;
    my $skill = $user->getByPath(@path);

    return returnRESTResult( $response, 200, JSON::to_json($result) )
      unless $skill;

    $result->{rating}  = $skill->{rating};
    $result->{comment} = $skill->{text};

    return returnRESTResult( $response, 200, JSON::to_json($result) );
}

# allows a user to add a new skill or edit an existing one
sub _rest_addEditSkill {
    my ( $session, $plugin, $verb, $response ) = @_;

    return if $recursionBlock;
    local $recursionBlock = 1;

    my @path    = _getPathFromCGI();
    my $request = Foswiki::Func::getCgiQuery();
    my $rating  = $request->param('addedit-skill-rating');
    my $comment = $request->param('comment');

    my $username = Foswiki::Func::getWikiName();
    my $users    = new Foswiki::Plugins::SkillsPlugin::UserSkills();
    my $user     = $users->getUser($username);
    my $known    = $user->getByPath(@path);
    my $action   = "add";
    if ( !$known ) {
        $known = new Foswiki::Plugins::SkillsPlugin::UserSkill( pop(@path) );
        $user->addByPath( $known, @path );
    }
    else {
        $action = "edit";
    }
    $known->{rating} = $rating;
    $known->{text}   = $comment;
    $users->save($user);

    return returnRESTResult( $response, 200,
        "Skill '" . $known->getPath() . "' ${action}ed" );
}

# Save changes made in the flat category form
sub _rest_saveUserChanges {
    my ( $session, $plugin, $verb, $response ) = @_;

    return if $recursionBlock;
    local $recursionBlock = 1;

    my $request  = Foswiki::Func::getCgiQuery();
    my $username = Foswiki::Func::getWikiName();

    my $skills = new Foswiki::Plugins::SkillsPlugin::Skills();

    my $users = new Foswiki::Plugins::SkillsPlugin::UserSkills($skills);
    my $user  = $users->getUser($username);

    my $added  = 0;
    my $edited = 0;

    $skills->visit(
        sub {
            my $node = shift;
            return if $node->hasChildren();
            my $key     = $node->getID();
            my $rating  = $request->param("$key-rating");
            my $comment = $request->param("$key-comment");
            if ( defined $rating || defined $comment ) {
                my @path  = $node->getPathArray();
                my $known = $user->getByPath(@path);
                if ( !$known ) {
                    $known = new Foswiki::Plugins::SkillsPlugin::UserSkill(
                        pop(@path) );
                    $user->addByPath( $known, @path );
                    $known->{rating} = $rating;
                    $known->{text}   = $comment;
                    $added++;
                    print STDERR $known->getPath() . " added\n";
                }
                else {
                    my $changes = 0;
                    if (
                        defined $rating
                        && ( !defined $known->{rating}
                            || ( $rating || 0 ) != ( $known->{rating} || 0 ) )
                      )
                    {
                        print STDERR "Rating "
                          . (
                            defined $known->{rating}
                            ? $known->{rating}
                            : 'undef'
                          )
                          . " -> "
                          . "$rating\n";
                        $known->{rating} = $rating;
                        $changes++;
                    }
                    if (
                        defined $comment
                        && ( !defined $known->{text}
                            || $comment ne $known->{text} )
                      )
                    {
                        $known->{text} = $comment;
                        print STDERR "Comment "
                          . (
                            defined $known->{text} ? $known->{text} : 'undef' )
                          . " -> "
                          . "$comment\n";
                        $changes++;
                    }
                    if ($changes) {
                        print STDERR "Edit " . $known->getPath() . "\n";
                        $edited++;
                    }
                }
            }
        }
    );
    my $message = "No changes needed to be saved";

    if ( $added || $edited ) {
        $users->save($user);
        $message = '';
        $message .= "$added skill" . ( $added == 1 ? '' : 's' ) . " added. "
          if $added;
        $message .= "$edited skill" . ( $edited == 1 ? '' : 's' ) . " edited."
          if $edited;
    }
    return returnRESTResult( $response, 200, $message );
}

sub _rest_search {
    my ( $session, $plugin, $verb, $response ) = @_;

    my $request    = Foswiki::Func::getCgiQuery();
    my @path       = _getPathFromCGI();
    my $ratingFrom = $request->param('ratingFrom');
    my $ratingTo   = $request->param('ratingTo');

    Foswiki::Func::readTemplate('skillssearchresults');
    my $out = Foswiki::Func::expandTemplate("skills:searchresults:start");

    my $commentTips = '';
    my $matches     = 0;

    my $userSkills = new Foswiki::Plugins::SkillsPlugin::UserSkills();

    $out .= _compileAllUserSkills( \@path, 'skills:searchresults', $userSkills,
        \$commentTips, \$matches );

    $out .= Foswiki::Func::expandTemplate("skills:searchresults:end");

    my $cat = join( '/', @path );
    $out =~ s/%SEARCHPATH%/$cat/g;
    $out =~ s/%SEARCHMATCHES%/$matches/g;

    $out = Foswiki::Func::expandCommonVariables($out);

    return returnRESTResult( $response, 200, $out . $commentTips );
}

# ========================= FUNCTIONS

sub _addHeads {
    my $form = shift;
    my $twisty = shift || 'closed';

    my $loggedIn = ( Foswiki::Func::isGuest() ) ? 0 : 1;

# yui
# adds the YUI Javascript files from header
# these are from the YahooUserInterfaceContrib, if installed
# or directly from the internet (See http://developer.yahoo.com/yui/articles/hosting/)
# TODO: Could be configurable?
    my $yui;
    eval 'use Foswiki::Contrib::YahooUserInterfaceContrib';
    if ( !$@ ) {
        $yui = "%PUBURL%/%SYSTEMWEB%/YahooUserInterfaceContrib";
    }
    else {
        $yui = "http://yui.yahooapis.com/2.5.2";
    }

    my $urlPath  = '%PUBURLPATH%/%SYSTEMWEB%/SkillsPlugin';
    my $restPath = '%SCRIPTURL{"rest"}%/SkillsPlugin';

    my $src = (DEBUG) ? '_src' : '';

    # add to head
    # FIXME: use the 'requires' parameter? for YUI?
    Foswiki::Func::addToHEAD( 'SKILLSPLUGIN_JS', <<THIS);
<style type="text/css" media="all">
 \@import url("$urlPath/style$src.css");
</style>
<script type="text/javascript" src="$yui/build/yahoo-dom-event/yahoo-dom-event.js"></script>
<script type="text/javascript" src="$yui/build/connection/connection-min.js">
</script>
<script type="text/javascript" src="$yui/build/element/element-beta-min.js">
</script>
<script type="text/javascript" src="$yui/build/json/json-min.js"></script>
<script type="text/javascript" src="$yui/build/animation/animation-min.js">
</script>
<script type="text/javascript" src="$yui/build/container/container-min.js">
</script>
<link rel="stylesheet" type="text/css" href="$yui/build/container/assets/skins/sam/container.css" />
<style>
.skillsSpinner {
 width: 16px;
 height: 16px;
 margin: 0px;
 padding: 0px;
 background-image: url("$urlPath/spinner.gif");
}
</style>
<script language='javascript' type='text/javascript'>
var SkillsPlugin = {
 vars: {
  restUrl: '%SCRIPTURL{"rest"}%',
  loggedIn: $loggedIn,
  twistyOpenImgSrc: '%ICONURL{toggleopen}%',
  twistyCloseImgSrc: '%ICONURL{toggleclose}%',
  lineSrc: {
   ld: '%ICONURL{dot_ld}%',
   lr: '%ICONURL{dot_lr}%',
   lrd: '%ICONURL{dot_lrd}%',
   rd: '%ICONURL{dot_rd}%',
   ud: '%ICONURL{dot_ud}%',
   udl: '%ICONURL{dot_udl}%',
   udlr: '%ICONURL{dot_udlr}%',
   udr: '%ICONURL{dot_udr}%',
   ul: '%ICONURL{dot_ul}%',
   ulr: '%ICONURL{dot_ulr}%',
   ur: '%ICONURL{dot_ur}%'
  },
  twistyState: '$twisty'
 }
}
</script>
<script src="$urlPath/main$src.js" language="javascript" type="text/javascript">
</script>
<script src="$urlPath/$form$src.js" language="javascript" type="text/javascript">
</script>
THIS
}

sub returnRESTResult {
    my ( $response, $status, $text ) = @_;

    my $request  = Foswiki::Func::getCgiQuery();
    my $redirect = $request->param('endPoint');
    if ($redirect) {
        if ( $status < 400 ) {

            # Allow the redirect to the endpoint
            return undef;
        }

        # Otherwise redirect to an error page
        my $url = Foswiki::Func::getScriptUrl(
            $Foswiki::cfg{SystemWebName}, 'SkillsPlugin', 'oops',
            template => 'oopsgeneric',
            param1   => 'Error',
            param2   => $text,
            param3   => ' ',
            param4   => 'Status: ' . $status,
        );
        $url .= ';cover=skills';
        Foswiki::Func::redirectCgiQuery( undef, $url );
        $request->delete('endPoint');
        return undef;
    }

    # Foswiki 1.0 introduces the Foswiki::Response object, which handles all
    # responses.
    if ( UNIVERSAL::isa( $response, 'Foswiki::Response' ) ) {
        $response->header(
            -status  => $status,
            -type    => 'text/plain',
            -charset => 'UTF-8',
            -expires => 'now',
        );
        $response->print($text);
    }
    else {    # Pre-Foswiki-1.0.
           # Turn off AUTOFLUSH
           # See http://perl.apache.org/docs/2.0/user/coding/coding.html
           # THIS DOES NOT WORK - TWiki still generates a response with no
           # cache headers. Has the header already been generated? Worked around
           # by adding time-based key to the requests.
        local $| = 0;
        my $query = Foswiki::Func::getCgiQuery();
        if ( defined($query) ) {
            my $len;
            { use bytes; $len = length($text); };
            print $query->header(
                -status         => $status,
                -type           => 'text/plain',
                -charset        => 'UTF-8',
                -Content_length => $len,
                -expires        => 'now',
            );
            print $text;
        }
    }
    print STDERR $text if ( $status >= 400 );
    return undef;
}

1;
