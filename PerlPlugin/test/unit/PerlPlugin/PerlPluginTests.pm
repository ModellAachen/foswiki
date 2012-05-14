package PerlPluginTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;

use Foswiki;
use Foswiki::Func;

sub loadExtraConfig {
    shift->SUPER::loadExtraConfig();
    $Foswiki::cfg{Plugins}{PerlPlugin}{Enabled} = 1;
}

sub test_simpleWorkingExprs {
    my $this = shift;
    my $t    = Foswiki::Func::expandCommonVariables("%PERL{\"'A String'\"}%");
    $this->assert_equals( 'A String', $t );
    $t = Foswiki::Func::expandCommonVariables("%PERL{\"101 - 59\"}%");
    $this->assert_equals( 42, $t );
    $t = Foswiki::Func::expandCommonVariables(
        "%PERL{\"sub x{95};x()\"}%...%PERL{\"x()+164\"}%");
    $this->assert_equals( "95...259", $t );
}

# Disabled due to a bug in the heredoc parser
sub test_hereDoc {
    my $this = shift;
    my $t    = <<'DRAGONS';
HERE%PERL{<<HERE}%DRAGONS
my %x = ( a=>'%TOPIC%' );
$x{a} =~ s/%/x/g;
$x{'a'} =~ s/xTOPICx/ BE /g;
"$x{a}";
HERE
!
DRAGONS
    $t = Foswiki::Func::expandCommonVariables($t);
    $this->assert_equals( "HERE BE DRAGONS!\n", $t );
}

sub test_syntaxError {
    my $this = shift;
    my $t    = Foswiki::Func::expandCommonVariables('%PERL{"-~-1+~+"}%');
    $this->assert_matches( qr/class='foswikiAlert'>%PERL error: syntax error/,
        $t );
}

sub test_strict {
    my $this = shift;
    my $t    = Foswiki::Func::expandCommonVariables('%PERL{"x"}%');
    $this->assert_matches(
        qr/class='foswikiAlert'>%PERL error: Bareword "x" not allowed/, $t );
}

sub test_die {
    my $this = shift;
    my $t =
      Foswiki::Func::expandCommonVariables('%PERL{"die \'pig dog rabbit\'"}%');
    $this->assert_matches( qr/class='foswikiAlert'>%PERL error: pig dog rabbit/,
        $t );
}

sub test_warn {
    my $this = shift;
    my $t    = Foswiki::Func::expandCommonVariables(
        '%PERL{"warn(\'pig\', \'dog\'); 2"}%');
    $this->assert_matches( qr/2\s*<.*?class='foswikiAlert'>pigdog at line 1/s,
        $t );
}

sub test_STDOUT {
    my $this = shift;
    my $t    = Foswiki::Func::expandCommonVariables(
        '%PERL{"print STDOUT \'pig dog rabbit\';\'\'"}%');
    $this->assert_matches( qr/pig dog rabbit/s, $t );
}

sub test_STDERR {
    my $this = shift;
    my $t    = Foswiki::Func::expandCommonVariables(
        '%PERL{"print STDERR \'were wolf\';666"}%');
    $this->assert_matches( qr/666\s*<.*?class='foswikiAlert'>were wolf<\/pre>/s,
        $t );
}

sub test_arithmeticError {
    my $this = shift;
    my $t    = Foswiki::Func::expandCommonVariables(
        '%PERL{"my ($x, $y) = (1, 0); my $z = $x / $y; $z;"}%');
    $this->assert_matches(
        qr/class='foswikiAlert'>%PERL error: Illegal division by zero/, $t );
}

1;
