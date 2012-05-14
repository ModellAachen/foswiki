# See bottom of file for license and copyright information
package Foswiki::Plugins::BookmakerPlugin;

use strict;
use warnings;
use Assert;

use Foswiki::Func ();
use JSON;

our $VERSION = '$Rev: 9771 $';
our $RELEASE = '1.0.3';
our $SHORTDESCRIPTION =
'Provides a UI and an API for other extensions that support the definition and maintenance of a specific topic ordering';
our $NO_PREFS_IN_TOPIC = 1;
our $openBook;
our $bookName;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    require Foswiki::Plugins::JQueryPlugin;

    Foswiki::Func::registerTagHandler( 'BOOKMAKER_IN_OPEN_BOOK',
        \&_IN_OPEN_BOOK );
    Foswiki::Func::registerTagHandler( 'BOOKLIST', \&_BOOKLIST );
    Foswiki::Func::registerTagHandler( 'BOOKMAKER_BOOK',
        sub { $bookName || '' } );

    $bookName = Foswiki::Func::getSessionValue('BOOKMAKER_OPEN_BOOK');
    my $q = Foswiki::Func::getCgiQuery();

    if ( $q && $q->param("open_bookmaker") ) {
        my ( $tweb, $ttopic ) =
          Foswiki::Func::normalizeWebTopicName( $web,
            Foswiki::Func::getCgiQuery()->param('open_bookmaker') );
        $ttopic = "WebOrder" if $ttopic eq "WebHome";
        $tweb = Foswiki::Sandbox::untaint( $tweb,
            \&Foswiki::Sandbox::validateWebName );
        $ttopic = Foswiki::Sandbox::untaint( $ttopic,
            \&Foswiki::Sandbox::validateTopicName );
        $bookName = "$tweb.$ttopic";
        Foswiki::Func::setSessionValue( 'BOOKMAKER_OPEN_BOOK', $bookName );
    }
    return 1 unless $bookName;

    if ( $q && $q->param("close_bookmaker") ) {
        Foswiki::Func::clearSessionValue('BOOKMAKER_OPEN_BOOK');
        return 1;
    }

    # Require the JQuery plugin.
    Foswiki::Plugins::JQueryPlugin::registerPlugin( 'Bookmaker',
        'Foswiki::Plugins::BookmakerPlugin::JQuery' );

    # This ought to JQREQUIRE it, no? Yes. But it's not getting included.
    Foswiki::Plugins::JQueryPlugin::createPlugin('Bookmaker');

    Foswiki::Func::registerRESTHandler( 'add',    \&_rest_add );
    Foswiki::Func::registerRESTHandler( 'remove', \&_rest_remove );
    Foswiki::Func::registerRESTHandler( 'list',   \&_rest_list );
    Foswiki::Func::registerRESTHandler( 'move',   \&_rest_move );

    return 1;
}

sub _openBook {
    my $title = shift || $bookName;
    return $openBook if defined $openBook;
    return '' unless $title;
    require Foswiki::Plugins::BookmakerPlugin::Book;
    return $openBook = Foswiki::Plugins::BookmakerPlugin::Book->new($title);
}

# Plugin handlers

sub postRenderingHandler {

    #my ($text, $map) = @_;

    # There has to be a book
    return unless $bookName;

    # Only view gets the bookmaker
    return unless Foswiki::Func::getContext()->{view};

    # only the body section gets a bookmaker
    return unless $_[0] =~ m#<body #i;

    my $tmpl    = Foswiki::Func::readTemplate("bookmaker");
    my $session = $Foswiki::Plugins::SESSION;
    $tmpl =
      Foswiki::Func::expandCommonVariables( $tmpl, $session->{topicName},
        $session->{webName} );
    $tmpl =
      Foswiki::Func::renderText( $tmpl, $session->{topicName},
        $session->{webName} );
    $_[0] =~ s#(<body.*?>)#$1$tmpl#;
}

# Tag handlers

sub _IN_OPEN_BOOK {
    my ( $session, $params, $topic, $web, $topicObject ) = @_;
    return 0 unless _openBook();
    return ( $openBook->find("$web.$topic") >= 0 ) ? 1 : 0;
}

sub _BOOKLIST {
    my ( $session, $params, $topic, $web, $topicObject ) = @_;
    my $title = $params->{_DEFAULT} || $bookName;
    return '' unless $title;
    require Foswiki::Plugins::BookmakerPlugin::Book;
    my $book = Foswiki::Plugins::BookmakerPlugin::Book->new($title);
    return '' unless $book;
    my $it = $book->each();
    my @list;

    while ( $it->hasNext() ) {
        my $e = $it->next();
        push( @list, "$e->{web}.$e->{topic}" );
    }
    return join( ',', @list );
}

# REST handlers

sub _REST {
    my ( $response, $status, $text ) = @_;

    $response->header(
        -status => $status || 200,
        -type => 'text/javascript',
        -charset => 'UTF-8'
    );
    $response->print($text);
    print STDERR $text if ( $status >= 400 );
    return undef;
}

sub _rest_add {
    my ( $session, $plugin, $verb, $response ) = @_;
    my $web   = $session->{webName};
    my $topic = $session->{topicName};
    return _REST( $response, 500, "No open book" ) unless _openBook();
    my $title = "$web.$topic";
    $openBook->add($title);
    $openBook->save();
    return _REST( $response, 200, <<JS);
\$('#bookmaker_add_button').removeClass("bookmaker_active").hide();
\$('#bookmaker_remove_button').addClass("bookmaker_active").show();
JS
}

sub _rest_remove {
    my ( $session, $plugin, $verb, $response ) = @_;
    my $web   = $session->{webName};
    my $topic = $session->{topicName};
    return _REST( $response, 500, "No open book" ) unless _openBook();
    $openBook->remove( $openBook->find("$web.$topic") );
    $openBook->save();
    return _REST( $response, 200, <<JS);
\$('#bookmaker_add_button').addClass("bookmaker_active").show();
\$('#bookmaker_remove_button').removeClass("bookmaker_active").hide();
JS
}

# Generate a jsTree format tree for the open book
sub _jstree {
    my $tree = { children => [] };    # level -1
    my $level = 0;      # level of nodes that are added to the current stack top
    my @stack = ($tree);

    my $it = $openBook->each();
    while ( $it->hasNext() ) {
        my $e = $it->next();
        while ( $e->{level} > $level ) {
            my $child;
            my $kids = $stack[$#stack]->{children};
            if ( scalar(@$kids) ) {
                $child = $kids->[$#$kids];
            }
            else {

                # Insert a pseudo-node
                $child = { data => '', children => [] };
            }
            push( @stack, $child );
            $level++;
        }
        while ( $level > $e->{level} ) {
            pop(@stack);
            $level--;
        }
        my $node = {
            data => {
                title => "$e->{web}.$e->{topic}",
                attr  => { href => "%SCRIPTURL{view}%/$e->{web}/$e->{topic}" }
            },
            attr     => { topic => "$e->{web}.$e->{topic}" },
            children => []
        };
        push( @{ $stack[$#stack]->{children} }, $node );
    }
    return $stack[0]->{children};
}

sub _rest_list {
    my ( $session, $plugin, $verb, $response ) = @_;
    return _REST( $response, 500, "No open book" ) unless _openBook();

    my $nodes = JSON::to_json( _jstree($openBook) );
    return _REST(
        $response,
        200,
        Foswiki::Func::expandCommonVariables(
            <<JS, $openBook->{topic}, $openBook->{web} ) );
\$('#bookmaker_expand').fadeOut();
\$('.bookmaker_active').fadeOut();
\$('#bookmaker_more').slideDown();
\$("#book_tree").jstree(\$.extend({
  json_data: { data: $nodes },
  move_url: "%SCRIPTURL{rest}%/BookmakerPlugin/move"
}, Bookmaker.jstree_options));
JS
}

sub _rest_move {
    my ( $session, $plugin, $verb, $response ) = @_;

    eval {
        require Foswiki::Contrib::JSTreeContrib;
        Foswiki::Contrib::JSTreeContrib::init();
        die "No open book" unless _openBook();
        my $q     = Foswiki::Func::getCgiQuery();
        my $what  = $q->param('what');
        my $level = 0;

        my $new_parent = $q->param('new_parent');
        my $ppos       = 0;
        if ($new_parent) {
            $ppos = $openBook->find($new_parent);
            die "Bad parent $new_parent" unless $ppos >= 0;
            my $parent = $openBook->at($ppos);
            $level = $parent->{level} + 1;
        }
        my $where = $openBook->find($what);
        die "No such entry $what at $where" unless $where >= 0;

        my $new_pos = $q->param('new_pos');
        my $entry   = $openBook->remove($where);
        $entry->{level} = $level;
        $openBook->insert( $ppos + $new_pos, $entry );
        $openBook->save();
    };
    return _REST( $response, 500, $@ ) if ($@);
    return _REST( $response, 200, '' );

# if DEBUG - but it will only work the first time!
#    my $nodes = JSON::to_json(_jstree($openBook));
#     return _REST($response, 200, Foswiki::Func::expandCommonVariables(<<JS, $openBook->{topic}, $openBook->{web}));
#\$("#book_tree").jstree(\$.extend({
#  json_data: { data: $nodes },
#  move_url: "%SCRIPTURL{rest}%/BookmakerPlugin/move"
#}, Bookmaker.jstree_options));
#JS
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
