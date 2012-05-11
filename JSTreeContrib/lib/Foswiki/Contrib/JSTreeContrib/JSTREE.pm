package Foswiki::Contrib::JSTreeContrib::JSTREE;
use strict;
use warnings;
use Assert;

use Foswiki::Plugins::JQueryPlugin ();
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

use Foswiki::Plugins::JQueryPlugin::Plugin ();
use Foswiki::Contrib::JSTreeContrib        ();

sub new {
    my $class   = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;
    my $src     = (DEBUG) ? '_src' : '';

    my $this = $class->SUPER::new(
        $session,
        name          => 'JSTree',
        version       => $Foswiki::Contrib::JSTreeContrib::RELEASE,
        author        => 'Ivan Bozhanov',
        homepage      => 'http://www.jstree.com',
        puburl        => '%PUBURLPATH%/%SYSTEMWEB%/JSTreeContrib',
        documentation => "$Foswiki::cfg{SystemWebName}.JSTreeContrib",
        summary       => $Foswiki::Contrib::JSTreeContrib::SHORTDESCRIPTION,
        javascript    => ["jquery.jstree${src}.js"]
    );

    return $this;
}

1;
