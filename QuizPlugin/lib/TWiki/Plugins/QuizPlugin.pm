# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2007 Motorola Ltd. 2001
# Copyright (C) 2007 Crawford Currie http://c-dot.co.uk

use strict;

package TWiki::Plugins::QuizPlugin;    # change the package name!!!

use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE
  $quizNumber
);

$VERSION = '$Rev$';
$RELEASE = '1.000';

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    TWiki::Func::registerTagHandler( 'QUIZ', \&handleQuiz );
    $quizNumber = 1;
    return 1;
}

sub handleQuiz {
    my ( $session, $attrs, $topic, $web ) = @_;
    my $name      = $attrs->{_DEFAULT};
    my $correct   = $attrs->{correct};
    my $jumptopic = $attrs->{jump};
    my $units     = $attrs->{units} || '';

    if ( !defined($correct) ) {
        return CGI::span( { class => 'twikiAlert' },
            "Invalid quiz - need correct answer(s)" );
    }

    my $result = <<HEADER;
<form name=quiz$quizNumber>
<div class='twikiAlert'> Q$quizNumber: $name</div>
HEADER

    if ( $attrs->{type} eq 'string' ) {
        my $length = length($correct);
        $result .= stringScript( $quizNumber, $correct, $jumptopic );
        $result .= <<FIELD;
<input type='text' name='field' size='$length' maxlength='$length'> $units <br />
FIELD
    }

    elsif ( $attrs->{type} eq 'select' ) {
        my $answers = $attrs->{choices};
        $result .= someOfScript( $quizNumber, $answers, $correct, $jumptopic );
        my @corrects = split( /;/, $correct );
        my $type;
        if ( scalar(@corrects) > 1 ) {
            $type = "checkbox";
        }
        else {
            $type = 'radio';
        }
        my @anslist = split( /;/, $answers );
        foreach my $answer (@anslist) {
            $result .= <<ANSWER
<input type='$type' name='field' value='$answer'> $answer <br />
ANSWER
        }
    }
    else {
        return "<font color=red>Invalid quiz $attrs - need select "
          . "or string</font><br>";
    }

    $result .= <<SUBMIT;
<input type=button value="Submit Answer" onClick="Submit${quizNumber}()">
SUBMIT
    $result .= <<SHOW;
<input type=button value="Cheat" onClick="Cheat${quizNumber}()">
SHOW
    $quizNumber++;
    return $result . "</form>";
}

my $scriptHeader = "<script language=\"JavaScript\"> <!--HIDE\n";
my $scriptFooter = "//STOP HIDING-->\n</script>\n";

sub cheatScript {
    my ( $quizNumber, $set ) = @_;
    return "var first$quizNumber=1; function Cheat${quizNumber}() {
	if (first$quizNumber==1) {
		alert(\"You should try at least once before clicking on 'Show Solutions'!\");
	} else { $set }}";
}

sub submitScript {
    my ( $quizNumber, $check, $jumpTopic ) = @_;
    my $result = <<JS;
function Submit${quizNumber}() {
 first$quizNumber=0;
 if ( $check ) {
  if (confirm("Correct!!! Click on OK to continue"))
JS
    if ($jumpTopic) {
        $result .= "   window.location.replace('$jumpTopic');\n";
    }
    else {
        $result .= "   ;\n";
    }
    return $result . <<MOREJS;
 } else {
  alert("Wrong! Try again...\\n");
 }
};
MOREJS
}

# Generate script for someOf
sub someOfScript {
    my ( $quizNumber, $legalAnswers, $correctAnswers, $jumpTopic ) = @_;

    my @possibles = split( /;/, $legalAnswers );
    my %nameMap;
    my @corrects = split( /;/, $correctAnswers );

    my $n = 0;
    foreach my $poss (@possibles) {
        $nameMap{$poss} = "window.document.quiz${quizNumber}.field[$n].checked";
        $n++;
    }

    my $set   = "";
    my $check = "";
    foreach my $poss (@possibles) {
        if ( $check ne "" ) {
            $check .= "&&";
        }
        $set .= $nameMap{$poss};
        if ( $correctAnswers !~ /\b$poss\b/ ) {
            $set   .= "=false;";
            $check .= "!";
        }
        else {
            $set .= "=true;";
        }
        $check .= $nameMap{$poss};
    }

    return
        $scriptHeader
      . cheatScript( $quizNumber, $set ) . "\n"
      . submitScript( $quizNumber, $check, $jumpTopic )
      . $scriptFooter;
}

# Generate script for string
sub stringScript {
    my ( $quizNumber, $correctAnswer, $jumpTopic ) = @_;

    return $scriptHeader
      . cheatScript( $quizNumber,
            "window.document.quiz"
          . $quizNumber
          . ".field.value=\"$correctAnswer\";" )
      . "\n"
      . submitScript(
        $quizNumber,
        "window.document.quiz$quizNumber" . ".field.value==\"$correctAnswer\"",
        $jumpTopic
      ) . $scriptFooter;
}

1;

