#
# Copyright (C) 2004 Crawford Currie, http://c-dot.co.uk
#
# Foswiki plugin-in module for Form Query Plugin
#
package Foswiki::Plugins::FormQueryPlugin;

use strict;

use Foswiki        ();
use Foswiki::Func  ();
use Foswiki::Attrs ();
use Error qw( :try );
use Assert;

our $VERSION = '$Rev$';
our $RELEASE = '17 Nov 2009';
our $SHORTDESCRIPTION =
'Provides query capabilities across a database defined using forms and embedded tables in Foswiki topics.';

our $quid        = 0;     # Unique query id
our $initialised = 0;     # flag whether _lazyInit has been called
our %db          = ();    # hash of loaded DBs, keyed on web name
our $moan        = 0;     # Preference value

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    Foswiki::Func::registerTagHandler( 'FQPDEBUG', \&_FQPDEBUG,
        'context-free' );
    Foswiki::Func::registerTagHandler(
        'DOANDSHOWQUERY',
        \&_DOQUERY,       # Deprecated
        'context-free'
    );
    Foswiki::Func::registerTagHandler( 'DOQUERY', \&_DOQUERY, 'context-free' );
    Foswiki::Func::registerTagHandler( 'FORMQUERY', \&_FORMQUERY,
        'context-free' );
    Foswiki::Func::registerTagHandler( 'SUMFIELD', \&_SUMFIELD,
        'context-free' );
    Foswiki::Func::registerTagHandler( 'MATCHCOUNT', \&_MATCHCOUNT,
        'context-free' );
    Foswiki::Func::registerTagHandler( 'TABLEFORMAT', \&_TABLEFORMAT,
        'context-free' );
    Foswiki::Func::registerTagHandler( 'SHOWQUERY', \&_SHOWQUERY,
        'context-free' );
    Foswiki::Func::registerTagHandler( 'QUERYTOCALC', \&_QUERYTOCALC,
        'context-free' );
    Foswiki::Func::registerTagHandler( 'SHOWCALC', \&_SHOWCALC,
        'context-free' );

    return 1;
}

sub _moan {
    my ( $tag, $attrs, $mess ) = @_;
    my $whinge = $moan || 'on';
    $whinge = $attrs->{moan} if defined $attrs->{moan};
    if ( Foswiki::Func::isTrue($whinge) ) {
        return CGI::span( { class => 'twikiAlert' },
            '%<nop> ' . $tag . '{' . $attrs->stringify() . "}% :$mess" );
    }
    return '';
}

sub _original {
    my ( $macro, $params, $mess ) = @_;
    $mess = defined $mess ? ": $mess" : '';
    return _moan( $macro, $params, "Plugin initialisation failed$mess" );
}

sub _FQPDEBUG {
    my $im = _lazyInit();
    return _original( 'FQPDEBUG', $_[1], $im ) if $im;

    my ( $session, $attrs, $topic, $web ) = @_;

    my $limit = $attrs->{limit};
    $limit = undef if ( $limit && $limit eq 'all' );

    my $result;
    try {
        my $name = $attrs->{query};
        if ($name) {
            $result =
              Foswiki::Plugins::FormQueryPlugin::WebDB::getQueryInfo( $name,
                $limit );
        }
        else {

            my $webName = $attrs->{web} || $web;

            if ( _lazyCreateDB($webName) ) {
                $result =
                  $db{$webName}
                  ->getTopicInfo( $attrs->{topic}, $attrs->{limit} );
            }
            else {
                $result = _original( 'FQPDEBUG', $_[1] );
            }
        }
    }
    catch Error::Simple with {
        $result = _moan( 'FQPDEBUG', $attrs, shift->{-text} );

        #die $result if DEBUG;
    };
    return $result;
}

sub _DOQUERY {

    my $im = _lazyInit();
    return _original( 'DOQUERY', $_[1], $im ) if $im;

    my ( $session, $attrs, $topic, $web ) = @_;

    my $webName;
    my $result = '';
    try {
        my $casesensitive = $attrs->{casesensitive} || "0";
        $casesensitive = 0 if ( $casesensitive =~ /^off$/oi );
        my $string = $attrs->{search};
        $string = $attrs->{"_DEFAULT"} unless $string;

        $webName = $attrs->{web} || $web;
        my @webs = split( /,\s*/, $webName );

        foreach $webName (@webs) {
            if ( _lazyCreateDB($webName) ) {

                # This should be done more efficiently, don't copy...
                $db{$webName}->formQueryOnDB( '__query__' . $quid,
                    $string, $attrs->{extract}, $casesensitive, 1 );

                $result .= Foswiki::Plugins::FormQueryPlugin::WebDB::showQuery(
                    '__query__' . $quid,
                    $attrs->{format}, $attrs, $topic, $web );
                $quid++;
            }
            else {
                $result .= _original( 'DOANDSHOWQUERY', $_[1] );
            }
        }
    }
    catch Error::Simple with {
        $result = _moan( 'DOQUERY', $attrs, shift->{-text} );
    };
    return $result;

}

sub _FORMQUERY {
    my $im = _lazyInit();
    return _original( 'FORMQUERY', $_[1], $im ) if $im;

    my ( $session, $attrs, $topic, $web ) = @_;
    my $query = $attrs->{query};
    my $casesensitive = $attrs->{casesensitive} || "0";
    $casesensitive = 0 if ( $casesensitive =~ /^off$/oi );
    my $string = $attrs->{search};
    $string = $attrs->{"_DEFAULT"} || "" unless $string;

    my $result = '';
    try {
        if ($query) {
            $result =
              Foswiki::Plugins::FormQueryPlugin::WebDB::formQueryOnQuery(
                $attrs->{name}, $string, $query, $attrs->{extract},
                $casesensitive );
        }
        else {
            my $webName = $attrs->{web} || $web;
            my @webs = split /,\s*/, $webName;

            my $result;
            foreach $webName (@webs) {
                if ( _lazyCreateDB($webName) ) {

                    # This should be done more efficiently,
                    # don't copy every time...
                    $result .=
                      $db{$webName}->formQueryOnDB( $attrs->{name}, $string,
                        $attrs->{extract}, $casesensitive, 1 );
                }
                else {
                    $result .= _original( 'FORMQUERY', $_[1] );
                }
            }
        }
    }
    catch Error::Simple with {
        $result = _moan( 'FORMQUERY', $attrs, shift->{-text} );
    };
    return $result;
}

sub _TABLEFORMAT {
    my $im = _lazyInit();
    return _original( 'TABLEFORMAT', $_[1], $im ) if $im;

    my ( $session, $attrs, $topic, $web ) = @_;

    my $result;
    try {
        $result =
          Foswiki::Plugins::FormQueryPlugin::WebDB::tableFormat( $attrs->{name},
            $attrs->{format}, $attrs );
    }
    catch Error::Simple with {
        $result = _moan( 'TABLEFORMAT', $attrs, shift->{-text} );
    };
    return $result;
}

sub _SHOWQUERY {
    my $im = _lazyInit();
    return _original( 'SHOWQUERY', $_[1], $im ) if $im;

    my ( $session, $attrs, $topic, $web ) = @_;

    my $result;
    try {
        $result =
          Foswiki::Plugins::FormQueryPlugin::WebDB::showQuery( $attrs->{query},
            $attrs->{format}, $attrs, $topic, $web );
    }
    catch Error::Simple with {
        $result = _moan( 'SHOWQUERY', $attrs, shift->{-text} );
    };
    return $result;
}

sub _QUERYTOCALC {
    my $im = _lazyInit();
    return _original( 'QUERYTOCALC', $_[1], $im ) if $im;

    my ( $session, $attrs, $topic, $web ) = @_;

    my $result;
    try {
        $result =
          Foswiki::Plugins::FormQueryPlugin::WebDB::toTable( $attrs->{query},
            $attrs->{format}, $attrs, $topic, $web );
    }
    catch Error::Simple with {
        $result = _moan( 'QUERYTOCALC', $attrs, shift->{-text} );
    };
    return $result;
}

sub _SHOWCALC {
    my $im = _lazyInit();
    return _original( 'SHOWCALC', $_[1], $im ) if $im;

    my ( $session, $attrs, $topic, $web ) = @_;

    my $calcline = $attrs->{"_DEFAULT"};

    # Not required but for safety, as we are not in the table...
    $Foswiki::Plugins::SpreadSheetPlugin::cPos = -1;

    my $result;
    try {
        $result = Foswiki::Plugins::SpreadSheetPlugin::Calc::doCalc($calcline);
    }
    catch Error::Simple with {
        $result = _moan( 'SHOWCALC', $attrs, shift->{-text} );
    };
    return $result;
}

sub _SUMFIELD {
    my $im = _lazyInit();
    return _original( 'SUMFIELD', $_[1], $im ) if $im;

    my ( $session, $attrs, $topic, $web ) = @_;

    my $result;
    try {
        $result =
          Foswiki::Plugins::FormQueryPlugin::WebDB::sumQuery( $attrs->{query},
            $attrs->{field} );
    }
    catch Error::Simple with {
        $result = _moan( 'SUMFIELD', $attrs, shift->{-text} );
    };
    return $result;
}

sub _MATCHCOUNT {
    my $im = _lazyInit();
    return _original( 'MATCHCOUNT', $_[1], $im ) if $im;

    my ( $session, $attrs, $topic, $web ) = @_;

    my $result;
    try {
        $result = Foswiki::Plugins::FormQueryPlugin::WebDB::matchCount(
            $attrs->{query} );
    }
    catch Error::Simple with {
        $result = _moan( 'MATCHCOUNT', $attrs, shift->{-text} );
    };
    return $result;
}

sub _lazyInit {

    # Problem: %SEARCH% with scope=text changes the current directory, thus
    # the subsequent loads do not work.

    return undef if ($initialised);

    # FQP_ENABLE must be set globally or in this web!
    return "FORMQUERYPLUGIN_ENABLE not set"
      unless Foswiki::Func::getPreferencesFlag('FORMQUERYPLUGIN_ENABLE');

    # Check for diagostic output
    $moan = Foswiki::Func::getPreferencesValue("FORMQUERYPLUGIN_MOAN");

    require Foswiki::Plugins::FormQueryPlugin::WebDB;
    return $@ if $@;

    $initialised = 1;

    return undef;

}

sub _lazyCreateDB {
    my ($webName) = @_;

    return 1 if $db{$webName};

    $db{$webName} = new Foswiki::Plugins::FormQueryPlugin::WebDB($webName);

    return 0 unless ref( $db{$webName} );

    return 1;
}

1;
