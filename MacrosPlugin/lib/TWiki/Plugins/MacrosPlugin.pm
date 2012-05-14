package TWiki::Plugins::MacrosPlugin;

use vars qw( $VERSION $RELEASE $pluginName );

use TWiki::Attrs;

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

my $pluginName = 'MacrosPlugin';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.000 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    return 1;
}

sub commonTagsHandler {
    ### my ( $text, $topic, $web ) = @_;

    # First expand all macros and macro parameters
    $_[0] =~ s/%CALLMACRO{(.*?)}%/&_callMacro($1,$_[2],$_[1])/ge;

    return unless ( $_[0] =~ m/%SET\s+/mo );

    # Now process in order to ensure correct SET ordering
    my %sets;    # scope of this topic only
    my $res;

    foreach my $block ( split( /\n%SET\s+/, "\n$_[0]" ) ) {
        foreach my $set ( keys %sets ) {
            $block =~ s/\%$set\%/$sets{$set}/g;
        }

        if ( $block =~ s/^(\w+)[ \t]*=[ \t]*([^\r\n]*)\r*\n//o ) {
            my $setname = $1;
            my $setval  = $2;
            $setval =
              TWiki::Func::expandCommonVariables( $setval, $topic, $web );
            $sets{$setname} = $setval;
            $block =~ s/\%$setname\%/$setval/g;
        }
        $res .= $block;
    }
    $res =~ s/^\n//o;
    $_[0] = $res;
}

# Expand a macro. The macro is identified by the 'topic' parameter
# and is loaded from the named topic. The remaining parameters have
# their values replaced into the macro and the expanded macro body
# is returned.
sub _callMacro {
    my ( $params, $web, $topic ) = @_;
    my $attrs = new TWiki::Attrs( $params, 1 );
    my $mtop = $attrs->{topic} || $attrs->{_DEFAULT};
    my $mweb = $web;

    return unless $mtop;

    ( $mweb, $mtop ) = TWiki::Func::normalizeWebTopicName( $web, $mtop );

    if ( !TWiki::Func::topicExists( $mweb, $mtop ) ) {
        return
" <font color=red> No such macro $mtop in CALLMACRO\{$params\} </font> ";
    }
    my ( $meta, $text ) = TWiki::Func::readTopic( $mweb, $mtop );

    foreach my $vbl ( keys %$attrs ) {
        my $val = $attrs->get($vbl);
        $text =~ s/%$vbl%/$val/g;
    }

    $text =~ s/[\r\n]+//go if ( $text =~ s/%STRIP%//go );

    # Recursive expansion
    $text =~ s/%CALLMACRO{(.+?)}%/&_callMacro($1,$web,$topic)/geo;

    return $text;
}

1;
