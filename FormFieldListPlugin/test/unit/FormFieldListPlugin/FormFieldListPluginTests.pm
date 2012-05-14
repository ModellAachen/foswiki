package FormFieldListPluginTests;

use strict;
use warnings;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Foswiki::Meta;
use Foswiki::Func;
use Error qw( :try );
use Foswiki::UI::Save;
use Foswiki::OopsException;
use Devel::Symdump;
use Data::Dumper;

my %testForms = (
    topic1 => {
        name   => 'FormFieldListTestTopic1',
        user   => 'ScumBag',
        date   => time() - 4004,
        form   => 'ProjectForm',
        field1 => {
            name      => 'Author',
            value     => 'MaryJones',
            attribute => 'M',
        },
        field2 => {
            name      => 'Status',
            value     => 'being revised',
            attribute => 'M,H',
        },
        field3 => {
            name => 'Remarks',
            value =>
'The proposal does not reveal the current complexity well enough.',
            attribute => '',
        },
    },
    topic2 => {
        name   => 'FormFieldListTestTopic2',
        user   => 'ProjectContributor',
        date   => time() - 3003,
        form   => 'ProjectForm',
        field1 => {
            name      => 'Author',
            value     => 'ChevyChase',
            attribute => 'M',
        },
        field2 => {
            name      => 'Status',
            value     => 'completed',
            attribute => 'M,H',
        },
        field3 => {
            name      => 'Remarks',
            value     => 'Well done!',
            attribute => '',
        },
    },
    topic3 => {
        name   => 'FormFieldListTestTopic3',
        user   => 'WikiGuest',
        date   => time() - 2002,
        form   => 'ProjectForm',
        field1 => {
            name      => 'Author',
            value     => 'CoolAide',
            attribute => 'M',
        },
        field2 => {
            name      => 'Status',
            value     => 'new',
            attribute => 'M,H',
        },
        field3 => {
            name      => 'Remarks',
            value     => 'TBD...',
            attribute => '',
        },
    },
    topic4 => {
        name   => 'FormFieldListTestTopic4',
        user   => 'AdminUser',
        date   => time() - 1001,
        form   => 'ProjectForm',
        field1 => {
            name      => 'Author',
            value     => 'JohnDoe',
            attribute => 'M',
        },
        field2 => {
            name      => 'Status',
            value     => 'outdated',
            attribute => 'M,H',
        },
        field3 => {
            name      => 'Remarks',
            value     => '',
            attribute => '',
        },
    },
    topic5 => { name => 'FormFieldListTestTopic5', },
);

my $allFields = "Author, Status, Remarks";

my $allTopics =
"$testForms{topic1}{name}, $testForms{topic2}{name}, $testForms{topic3}{name}, $testForms{topic4}{name}, $testForms{topic5}{name}";

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub set_up {
    my ($this) = @_;

    $this->SUPER::set_up();
    $Foswiki::cfg{Plugins}{FormFieldListPlugin}{Enabled} = 1;
    $this->{session}->finish();
    $this->{session} = Foswiki::new('Foswiki');
    $this->_createForms();
}

# This formats the text up to immediately before <nop>s are removed, so we
# can see the nops.
sub _do_test {
    my ( $this, $topic, $expected, $source ) = @_;

    my $actual =
      Foswiki::Func::expandCommonVariables( $source, $topic,
        $this->{test_web} );
    $this->assert_equals( $expected, $actual );
}

=pod

=cut

sub test_compatibility_version_1 {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"Author, Status\" topic=\"$testTopic\" separator=\". \" default=\"(Field \$title not set)\" alttext=\"_\$title_ field not found\"}%";

    my $expected = 'MaryJones. being revised';
    $this->_do_test( $testTopic, $expected, $source );
}

=pod

No form fields passed.
We use sort and format parameters here to make the outcome predictable.

=cut

sub test_simple_no_fields {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source = "%FORMFIELDLIST{sort=\"\$name\" format=\"\$title=\$value\"}%";

    my $expected = 'Author=MaryJones
Remarks=The proposal does not reveal the current complexity well enough.
Status=being revised';
    $this->_do_test( $testTopic, $expected, $source );
}

=pod

No form fields passed.
We use sort and format parameters here to make the outcome predictable.

=cut

sub test_simple_no_fields_all_topics {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{topic=\"$allTopics\" sort=\"\$topicName\" format=\"\$topicName: \$title=\$value\"}%";

    my $expected = 'FormFieldListTestTopic1: Status=being revised
FormFieldListTestTopic1: Remarks=The proposal does not reveal the current complexity well enough.
FormFieldListTestTopic1: Author=MaryJones
FormFieldListTestTopic2: Status=completed
FormFieldListTestTopic2: Remarks=Well done!
FormFieldListTestTopic2: Author=ChevyChase
FormFieldListTestTopic3: Status=new
FormFieldListTestTopic3: Remarks=TBD...
FormFieldListTestTopic3: Author=CoolAide
FormFieldListTestTopic4: Status=outdated
FormFieldListTestTopic4: Remarks=
FormFieldListTestTopic4: Author=JohnDoe';
    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Most simple test: one form field of current topic.

=cut

sub test_simple_one_field {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source = "%FORMFIELDLIST{\"Author\"}%";

    my $expected = 'MaryJones';
    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Most simple test: one form field of current topic, using param field.

=cut

sub test_simple_one_field_param_field {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source = "%FORMFIELDLIST{field=\"Author\"}%";

    my $expected = 'MaryJones';
    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Simple test with 3 fields of current topic. 

=cut

sub test_simple_more_fields {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source = "%FORMFIELDLIST{\"Author, Status, Remarks\"}%";

    my $expected = 'MaryJones
being revised
The proposal does not reveal the current complexity well enough.';
    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Simple test with all fields of all topics.

=cut

sub test_simple_one_field_specified_topics {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};
    my $topic1    = $testForms{topic1}{name};
    my $topic2    = $testForms{topic2}{name};
    my $source    = "%FORMFIELDLIST{\"Author\" topic=\"$topic1, $topic2\"}%";

    my $expected = 'MaryJones
ChevyChase';
    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param web. TODO: test other webs

=cut

sub test_param_web {
    my $this = shift;

    my $source =
"%FORMFIELDLIST{\"Author\" web=\"$this->{test_web}\" topic=\"$allTopics\"}%";

    my $expected = 'MaryJones
ChevyChase
CoolAide
JohnDoe';

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param excludeweb. TODO: test other webs

=cut

sub test_param_excludeweb {
    my $this = shift;

    my $source =
"%FORMFIELDLIST{\"Author\" excludeweb=\"$this->{test_web}\" topic=\"$allTopics\"}%";

    my $expected = '';

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Simple test with all fields of all topics.

=cut

sub test_simple_all_fields_all_topics {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source = "%FORMFIELDLIST{\"$allFields\" topic=\"$allTopics\"}%";

    my $expected = 'MaryJones
being revised
The proposal does not reveal the current complexity well enough.
ChevyChase
completed
Well done!
CoolAide
new
TBD...
JohnDoe
outdated
';
    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param topic with 1 topic.

=cut

sub test_param_topic_one_topic {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};
    my $topic1    = $testForms{topic1}{name};
    my $source    = "%FORMFIELDLIST{\"Author\" topic=\"$topic1\"}%";

    my $expected = 'MaryJones';
    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param topic with 1 topic.

=cut

sub test_param_topic_one_topic_webdottopic_notation {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};
    my $topic1    = $testForms{topic1}{name};
    my $web       = $this->{test_web};

    my $source =
        '%FORMFIELDLIST{"Author" topic="'
      . "TemporaryFormFieldListPluginTestsTestWebFormFieldListPluginTests.$topic1"
      . '"}%';

    my $expected = 'MaryJones';
    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param topic with 2 topic.

=cut

sub test_param_topic_multiple_topics {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};
    my $topic1    = $testForms{topic1}{name};
    my $topic2    = $testForms{topic2}{name};
    my $source    = "%FORMFIELDLIST{\"Author\" topic=\"$topic1, $topic2\"}%";

    my $expected = 'MaryJones
ChevyChase';
    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param excludetopic.

=cut

sub test_param_excludetopic {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $excludetopic1 = $testForms{topic2}{name};
    my $excludetopic2 = $testForms{topic3}{name};

    my $source =
"%FORMFIELDLIST{\"Author\" topic=\"$allTopics\" excludetopic=\"$excludetopic1, $excludetopic2\"}%";

    my $expected = 'MaryJones
JohnDoe';
    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param excludefield.

=cut

sub test_param_excludefield {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"$allFields\" topic=\"$allTopics\" excludefield=\"Author\" format=\"\$title=\$value\"}%";

    my $expected = 'Status=being revised
Remarks=The proposal does not reveal the current complexity well enough.
Status=completed
Remarks=Well done!
Status=new
Remarks=TBD...
Status=outdated
Remarks=';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param includefieldpattern.

=cut

sub test_param_includefieldpattern {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{topic=\"$allTopics\" includefieldpattern=\"^(?i)[RS]\" format=\"\$title=\$value\"}%";

    my $expected = 'Status=being revised
Remarks=The proposal does not reveal the current complexity well enough.
Status=completed
Remarks=Well done!
Status=new
Remarks=TBD...
Status=outdated
Remarks=';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param excludefieldpattern.

=cut

sub test_param_excludefieldpattern {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{topic=\"$allTopics\" excludefieldpattern=\"^(?i)[RS]\" format=\"\$title=\$value\"}%";

    my $expected = 'Author=MaryJones
Author=ChevyChase
Author=CoolAide
Author=JohnDoe';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param includevalue.

=cut

sub test_param_includevalue {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"$allFields\" topic=\"$allTopics\" includevalue=\"Well done!\" format=\"\$title=\$value\"}%";

    my $expected = 'Remarks=Well done!';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param excludevalue.

=cut

sub test_param_excludevalue {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"Author\" topic=\"$allTopics\" excludevalue=\"ChevyChase, CoolAide\" format=\"Author=\$value\"}%";

    my $expected = 'Author=MaryJones
Author=JohnDoe';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param includevaluepattern.

=cut

sub test_param_includevaluepattern {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"$allFields\" topic=\"$allTopics\" includevaluepattern=\"(?i)co\" format=\"\$title=\$value\"}%";

    my $expected =
      'Remarks=The proposal does not reveal the current complexity well enough.
Status=completed
Author=CoolAide';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param excludevaluepattern.

=cut

sub test_param_excludevaluepattern {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"$allFields\" topic=\"$allTopics\" excludevaluepattern=\"^(?i)[A-S]\" format=\"\$title=\$value\"}%";

    my $expected =
      'Remarks=The proposal does not reveal the current complexity well enough.
Remarks=Well done!
Remarks=TBD...
Remarks=';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param excludeemptyvalue_off.

=cut

sub test_param_excludeemptyvalue_on {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"$allFields\" topic=\"$allTopics\" excludeemptyvalue=\"on\" format=\"\$topicName: \$title=\$value\"}%";

    my $expected = 'FormFieldListTestTopic1: Author=MaryJones
FormFieldListTestTopic1: Status=being revised
FormFieldListTestTopic1: Remarks=The proposal does not reveal the current complexity well enough.
FormFieldListTestTopic2: Author=ChevyChase
FormFieldListTestTopic2: Status=completed
FormFieldListTestTopic2: Remarks=Well done!
FormFieldListTestTopic3: Author=CoolAide
FormFieldListTestTopic3: Status=new
FormFieldListTestTopic3: Remarks=TBD...
FormFieldListTestTopic4: Author=JohnDoe
FormFieldListTestTopic4: Status=outdated';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param includemissingfields.

=cut

sub test_param_includemissingfields {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"$allFields\" topic=\"$allTopics\" includemissingfields=\"on\" format=\"\$title=\$value\"}%";

    my $expected = 'Author=MaryJones
Status=being revised
Remarks=The proposal does not reveal the current complexity well enough.
Author=ChevyChase
Status=completed
Remarks=Well done!
Author=CoolAide
Status=new
Remarks=TBD...
Author=JohnDoe
Status=outdated
Remarks=
Author=';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param user.

=cut

sub test_param_user {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};
    my $source =
"%FORMFIELDLIST{topic=\"$allTopics\" user=\"ScumBag, ProjectContributor\" format=\"topic=\$topicName, last changed by \$topicUser\"}%";

    my $expected = 'topic=FormFieldListTestTopic1, last changed by ScumBag
topic=FormFieldListTestTopic1, last changed by ScumBag
topic=FormFieldListTestTopic1, last changed by ScumBag
topic=FormFieldListTestTopic2, last changed by ProjectContributor
topic=FormFieldListTestTopic2, last changed by ProjectContributor
topic=FormFieldListTestTopic2, last changed by ProjectContributor';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param excludeuser.

=cut

sub test_param_excludeuser {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{topic=\"$allTopics\" excludeuser=\"ScumBag, ProjectContributor\" format=\"topic=\$topicName, last changed by \$topicUser\"}%";

    my $expected = 'topic=FormFieldListTestTopic3, last changed by WikiGuest
topic=FormFieldListTestTopic3, last changed by WikiGuest
topic=FormFieldListTestTopic3, last changed by WikiGuest
topic=FormFieldListTestTopic4, last changed by AdminUser
topic=FormFieldListTestTopic4, last changed by AdminUser
topic=FormFieldListTestTopic4, last changed by AdminUser';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param fromdate.

=cut

sub test_param_fromdate {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{topic=\"$allTopics\" fromdate=\"2000/01/01\" format=\"topic=\$topicName; field=\$name; value=\$value\"}%";

    my $expected =
      'topic=FormFieldListTestTopic1; field=Status; value=being revised
topic=FormFieldListTestTopic1; field=Remarks; value=The proposal does not reveal the current complexity well enough.
topic=FormFieldListTestTopic1; field=Author; value=MaryJones
topic=FormFieldListTestTopic2; field=Status; value=completed
topic=FormFieldListTestTopic2; field=Remarks; value=Well done!
topic=FormFieldListTestTopic2; field=Author; value=ChevyChase
topic=FormFieldListTestTopic3; field=Status; value=new
topic=FormFieldListTestTopic3; field=Remarks; value=TBD...
topic=FormFieldListTestTopic3; field=Author; value=CoolAide
topic=FormFieldListTestTopic4; field=Status; value=outdated
topic=FormFieldListTestTopic4; field=Remarks; value=
topic=FormFieldListTestTopic4; field=Author; value=JohnDoe';

    my $actual =
      Foswiki::Func::expandCommonVariables( $source, $testTopic,
        $this->{test_web} );

    #$this->assert_not_null( $actual );
    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param todate.
NOTE: cannot be tested well!

=cut

sub test_param_todate {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{topic=\"$allTopics\" todate=\"2020/01/01\" format=\"topic=\$topicName; field=\$name; value=\$value\"}%";

    my $expected =
      'topic=FormFieldListTestTopic1; field=Status; value=being revised
topic=FormFieldListTestTopic1; field=Remarks; value=The proposal does not reveal the current complexity well enough.
topic=FormFieldListTestTopic1; field=Author; value=MaryJones
topic=FormFieldListTestTopic2; field=Status; value=completed
topic=FormFieldListTestTopic2; field=Remarks; value=Well done!
topic=FormFieldListTestTopic2; field=Author; value=ChevyChase
topic=FormFieldListTestTopic3; field=Status; value=new
topic=FormFieldListTestTopic3; field=Remarks; value=TBD...
topic=FormFieldListTestTopic3; field=Author; value=CoolAide
topic=FormFieldListTestTopic4; field=Status; value=outdated
topic=FormFieldListTestTopic4; field=Remarks; value=
topic=FormFieldListTestTopic4; field=Author; value=JohnDoe';

    my $actual =
      Foswiki::Func::expandCommonVariables( $source, $testTopic,
        $this->{test_web} );

    #$this->assert_not_null( $actual );
    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param separator

=cut

sub test_param_separator_one_topic {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
      "%FORMFIELDLIST{\"Author, Status, Remarks\" separator=\", \"}%";

    my $expected =
'MaryJones, being revised, The proposal does not reveal the current complexity well enough.';
    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param topicheader

=cut

sub test_param_topic_header {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{topic=\"*\" \"$allFields\" format=\"   * \$topicName: \$value\" topicheader=\"---\"}%";

    my $expected = '---
   * FormFieldListTestTopic1: MaryJones
   * FormFieldListTestTopic1: being revised
   * FormFieldListTestTopic1: The proposal does not reveal the current complexity well enough.
---
   * FormFieldListTestTopic2: ChevyChase
   * FormFieldListTestTopic2: completed
   * FormFieldListTestTopic2: Well done!
---
   * FormFieldListTestTopic3: CoolAide
   * FormFieldListTestTopic3: new
   * FormFieldListTestTopic3: TBD...
---
   * FormFieldListTestTopic4: JohnDoe
   * FormFieldListTestTopic4: outdated
   * FormFieldListTestTopic4: ';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param default.

=cut

sub test_param_default {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
      "%FORMFIELDLIST{\"Remarks\" topic=\"*\" default=\"--nothing--\"}%";

    my $expected =
      'The proposal does not reveal the current complexity well enough.
Well done!
TBD...
--nothing--';
    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param alttext, current topic.
Must be used with includemissingfields="on".
=cut

sub test_param_alttext_current_topic {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"DoesNotExist\" alttext=\"--field not found--\" includemissingfields=\"on\"}%";

    my $expected = '--field not found--';
    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param alttext, all topics.
Must be used with includemissingfields="on".

=cut

sub test_param_alttext_all_topics {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"DoesNotExist\" topic=\"*\" alttext=\"--field not found--\" includemissingfields=\"on\"}%";

    my $expected = '--field not found--
--field not found--
--field not found--
--field not found--
--field not found--
--field not found--
--field not found--';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param alt.

=cut

sub test_param_alt {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"DoesNotExist\" topic=\"$allTopics\" alt=\"No fields found\"}%";

    my $expected = 'No fields found';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param format

=cut

sub test_param_format {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"Author\" topic=\"$testTopic\" format=\"   * \$value\"}%";

    my $expected = '   * MaryJones';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test format param $name.

=cut

sub test_param_format_name {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
      "%FORMFIELDLIST{\"Author\" topic=\"$testTopic\" format=\"name=\$name\"}%";

    my $expected = 'name=Author';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test format param $title.

=cut

sub test_param_format_title {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"Author\" topic=\"$testTopic\" format=\"title=\$title\"}%";

    my $expected = 'title=Author';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test format param $title in $alttext.
Must be used with includemissingfields="on"

=cut

sub test_param_format_title_in_alttext {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"DoesNotExist\" alttext=\"_\$title_ field not found\" includemissingfields=\"on\"}%";

    my $expected = '_DoesNotExist_ field not found';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test format param $title in $default.

=cut

sub test_param_format_title_in_default {
    my $this = shift;

    my $testTopic = $testForms{topic4}{name};

    my $source =
      "%FORMFIELDLIST{\"Remarks\" default=\"(Field \$title not set)\"}%";

    my $expected = '(Field Remarks not set)';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test format param $value.

=cut

sub test_param_format_value {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"Author\" topic=\"$testTopic\" format=\"value=\$value\"}%";

    my $expected = 'value=MaryJones';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test format param $topicUser.

=cut

sub test_param_format_topicUser {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"Author\" topic=\"$testTopic\" format=\"user=\$topicUser\"}%";

    my $expected = 'user=ScumBag';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test format param $topicDate.

=cut

sub test_param_format_topicDate {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"Author\" topic=\"$testTopic\" format=\"date=\$topicDate\"}%";

    require Foswiki::Time;
    my $time = Foswiki::Time::formatTime( time(), '$epoch', 'servertime' );
    my $date = _formatDate($time);

    my $expected = "date=$date";

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test sort param $fieldDate.

=cut

sub test_param_format_sort_fieldDate_default {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"Author\" topic=\"$allTopics\" sort=\"\$fieldDate\" format=\"topic=\$topicName\"}%";

    my $expected = 'topic=FormFieldListTestTopic4
topic=FormFieldListTestTopic3
topic=FormFieldListTestTopic2
topic=FormFieldListTestTopic1';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test format param $fieldDate

STEP 1: Change field value of topic 2, save topic
STEP 2: Change text of topic 3, save.

TEST 1: When sorting on $topicDate, topic 3 should be first.
TEST 2: When sorting on $fieldDate, topic 2 should be first.
TEST 3: When looking for a different field name, the order should be in topic changed order - FOR THAT FIELD! (last on top: 4, 3, 2, 1)

=cut

sub test_param_format_sort_fieldDate_save_field_only {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    # first make sure that the cache is created
    my $tmp_source =
"%FORMFIELDLIST{\"$allFields\" topic=\"$allTopics\" sort=\"\$fieldDate\"}%";
    my $tmp_expected = '
outdated
JohnDoe
TBD...
new
CoolAide
Well done!
completed
ChevyChase
The proposal does not reveal the current complexity well enough.
being revised
MaryJones';
    $this->_do_test( $testTopic, $tmp_expected, $tmp_source );

    # --- STEP 1: change field value of topic 2, but not the text

    my $topic = $testForms{topic2}{name};

    my ( $meta, $text ) = Foswiki::Func::readTopic( $this->{test_web}, $topic );

    my @fields = $meta->find('FIELD');

    foreach my $field (@fields) {
        my $name = $field->{name};
        if ( $name eq 'Author' ) {
            $meta->put( 'FIELD',
                { name => $name, title => $name, value => 'Johnny' } );
        }
    }
    _makeDelay(1.1);
    $meta->save();

    # --- STEP 2: change text of topic 3
    {
        my $topic = $testForms{topic3}{name};

        my ( $meta, $text ) =
          Foswiki::Func::readTopic( $this->{test_web}, $topic );

        $text = 'DA';
        _makeDelay(1.1);
        Foswiki::Func::saveTopic( $this->{test_web}, $topic, $meta, $text );
    }

    # --- PERFORM TESTS

    my $currentDefaultDateFormat = $Foswiki::cfg{DefaultDateFormat};
    $Foswiki::cfg{DefaultDateFormat} = '$epoch';

    my $source;
    my $expected;

    # -----------------------------
    # SUBTEST 1: sort on $topicDate
    $source =
"%FORMFIELDLIST{\"Author\" topic=\"$allTopics\" sort=\"\$topicDate\" format=\"\$topicName\"}%";

    $expected = 'FormFieldListTestTopic3
FormFieldListTestTopic2
FormFieldListTestTopic4
FormFieldListTestTopic1';

    $this->_do_test( $testTopic, $expected, $source );

    # -----------------------------
    # SUBTEST 2: sort on $fieldDate
    $source =
"%FORMFIELDLIST{\"Author\" topic=\"$allTopics\" sort=\"\$fieldDate\" format=\"\$topicName\"}%";

    $expected = 'FormFieldListTestTopic2
FormFieldListTestTopic4
FormFieldListTestTopic3
FormFieldListTestTopic1';

    $this->_do_test( $testTopic, $expected, $source );

    # -----------------------------
    # SUBTEST 3: sort on $fieldDate, but search on different field
    $source =
"%FORMFIELDLIST{\"Status\" topic=\"$allTopics\" sort=\"\$fieldDate\" format=\"\$topicName\"}%";

    $expected = 'FormFieldListTestTopic4
FormFieldListTestTopic3
FormFieldListTestTopic2
FormFieldListTestTopic1';

    $this->_do_test( $testTopic, $expected, $source );

    # restore topic
    @fields = $meta->find('FIELD');
    foreach my $field (@fields) {
        my $name = $field->{name};
        if ( $name eq 'Author' ) {
            $field->{value} = 'ChevyChase';
        }
    }
    $meta->putAll( 'FIELD', @fields );

    Foswiki::Func::saveTopic( $this->{test_web}, $topic, $meta, $text );

    $Foswiki::cfg{DefaultDateFormat} = $currentDefaultDateFormat;

}

=pod

Test format param $topicName.

=cut

sub test_param_format_topicName {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"Author\" topic=\"$testTopic\" format=\"topic=\$topicName\"}%";

    my $expected = 'topic=FormFieldListTestTopic1';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test format param $webName.

=cut

sub test_param_format_webName {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"Author\" topic=\"$testTopic\" format=\"web=\$webName\"}%";

    my $expected = 'web=' . $this->{test_web};

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test format param $fieldCount in footer.

=cut

sub test_param_format_fieldCount_footer {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"$allFields\" topic=\"$allTopics\" footer=\"Number of fields: \$fieldCount\"}%";

    my $expected = 'MaryJones
being revised
The proposal does not reveal the current complexity well enough.
ChevyChase
completed
Well done!
CoolAide
new
TBD...
JohnDoe
outdated

Number of fields: 12';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test format param $fieldCount in header.

=cut

sub test_param_format_fieldCount_header {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"$allFields\" topic=\"$testTopic\" header=\"Number of fields: \$fieldCount\"}%";

    my $expected = 'Number of fields: 3
MaryJones
being revised
The proposal does not reveal the current complexity well enough.';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param limit

=cut

sub test_param_limit {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
      "%FORMFIELDLIST{\"$allFields\" topic=\"$allTopics\" limit=\"5\"}%";

    my $expected = 'MaryJones
being revised
The proposal does not reveal the current complexity well enough.
ChevyChase
completed';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param limit with sort

=cut

sub test_param_limit_with_sort {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"$allFields\" topic=\"$allTopics\" limit=\"10\" sort=\"\$date\" format=\"\$value\"}%";

    my $expected = 'being revised
The proposal does not reveal the current complexity well enough.
MaryJones
outdated

JohnDoe
new
TBD...
CoolAide
completed';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param sort on $name.

=cut

sub test_param_sort_name {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source = "%FORMFIELDLIST{sort=\"\$name\" format=\"\$name=\$value\"}%";

    my $expected = 'Author=MaryJones
Remarks=The proposal does not reveal the current complexity well enough.
Status=being revised';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param sort on $name, sortorder descending.

=cut

sub test_param_sort_name_sortorder_descending {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{sort=\"\$name\" sortorder=\"descending\" format=\"\$name=\$value\"}%";

    my $expected = 'Status=being revised
Remarks=The proposal does not reveal the current complexity well enough.
Author=MaryJones';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param sort on $value.

=cut

sub test_param_sort_value {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{topic=\"$allTopics\" sort=\"\$value\" format=\"value=\$value\"}%";

    my $expected = 'value=
value=being revised
value=ChevyChase
value=completed
value=CoolAide
value=JohnDoe
value=MaryJones
value=new
value=outdated
value=TBD...
value=The proposal does not reveal the current complexity well enough.
value=Well done!';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param sort on $value, sortorder descending.

=cut

sub test_param_sort_value_sortorder_descending {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{topic=\"$allTopics\" sort=\"\$value\" sortorder=\"descending\" format=\"value=\$value\"}%";

    my $expected = 'value=Well done!
value=The proposal does not reveal the current complexity well enough.
value=TBD...
value=outdated
value=new
value=MaryJones
value=JohnDoe
value=CoolAide
value=completed
value=ChevyChase
value=being revised
value=';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param sort on $topicName.

=cut

sub test_param_sort_topicName {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{field=\"$allFields\" topic=\"$allTopics\" sort=\"\$topicName\" format=\"topic=\$topicName, field=\$name, value=\$value\"}%";

    my $expected = 'topic=FormFieldListTestTopic1, field=Author, value=MaryJones
topic=FormFieldListTestTopic1, field=Status, value=being revised
topic=FormFieldListTestTopic1, field=Remarks, value=The proposal does not reveal the current complexity well enough.
topic=FormFieldListTestTopic2, field=Author, value=ChevyChase
topic=FormFieldListTestTopic2, field=Status, value=completed
topic=FormFieldListTestTopic2, field=Remarks, value=Well done!
topic=FormFieldListTestTopic3, field=Author, value=CoolAide
topic=FormFieldListTestTopic3, field=Status, value=new
topic=FormFieldListTestTopic3, field=Remarks, value=TBD...
topic=FormFieldListTestTopic4, field=Author, value=JohnDoe
topic=FormFieldListTestTopic4, field=Status, value=outdated
topic=FormFieldListTestTopic4, field=Remarks, value=';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param sort on $topicDate.

=cut

sub test_param_sort_topicDate {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{field=\"Author\" topic=\"$allTopics\" sort=\"\$topicDate\" format=\"topic=\$topicName, field=\$name, value=\$value\"}%";

    my $expected = 'topic=FormFieldListTestTopic4, field=Author, value=JohnDoe
topic=FormFieldListTestTopic3, field=Author, value=CoolAide
topic=FormFieldListTestTopic2, field=Author, value=ChevyChase
topic=FormFieldListTestTopic1, field=Author, value=MaryJones';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param sort on $topicUser.

=cut

sub test_param_sort_topicUser {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{topic=\"$allTopics\" sort=\"\$topicUser\" format=\"user=\$topicUser\"}%";

    my $expected = 'user=AdminUser
user=AdminUser
user=AdminUser
user=ProjectContributor
user=ProjectContributor
user=ProjectContributor
user=ScumBag
user=ScumBag
user=ScumBag
user=WikiGuest
user=WikiGuest
user=WikiGuest';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param header.

=cut

sub test_param_header {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"Author\" topic=\"$testTopic\" format=\"value=\$value\" header=\"Results:\"}%";

    my $expected = 'Results:
value=MaryJones';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param header with no results.

=cut

sub test_param_header_no_results {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"DoesNotExist\" topic=\"$testTopic\" header=\"Results:\"}%";

    my $expected = '';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param footer.

=cut

sub test_param_footer {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"Author\" topic=\"$testTopic\" format=\"value=\$value\" footer=\"That was all\"}%";

    my $expected = 'value=MaryJones
That was all';

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test param footer with no results.

=cut

sub test_param_footer_no_results {
    my $this = shift;

    my $testTopic = $testForms{topic1}{name};

    my $source =
"%FORMFIELDLIST{\"DoesNotExist\" topic=\"$testTopic\" footer=\"Results:\"}%";

    my $expected = '';

    $this->_do_test( $testTopic, $expected, $source );
}

sub test_param_sort_fieldDefinition {
    my $this      = shift;
    my $testTopic = 'sortFieldDefinition';
    my $source    = <<"HERE";
---+ Sorted
%FORMFIELDLIST{sort="\$fieldDefinition" format="   * \$name: \$value"}%
---+ Unsorted
%FORMFIELDLIST{format="   * \$name: \$value"}%
HERE
    my $expected = <<"HERE";
---+ Sorted
   * Zfield: 1
   * Bfield: 1
   * Cfield: 1
---+ Unsorted
   * Zfield: 1
   * Cfield: 1
   * Bfield: 1
HERE

    $this->_set_up_topic( $testTopic, <<'HERE');
TestForm doesn't exist

For now we just test that the order of appearance of the META:FIELD macros
are preserved by FORMFIELDLIST{sort="$fieldDefinition"}. One day we will
be able to properly query the form's idea of field ordering instead of
relying on how it happens to be serialised in the topic... The $fieldDefinition
sort feature will be broken on any store implementation that doesn't behave
this way :-/

Item8392

%META:FORM{name="TestForm"}%
%META:FIELD{name="Zfield" attributes="" title="Zfield" value="1"}%
%META:FIELD{name="Bfield" attributes="" title="Bfield" value="1"}%
%META:FIELD{name="Cfield" attributes="" title="Cfeild" value="1"}%
HERE
    $this->_do_test( $testTopic, $expected, $source );

    return;
}

=pod

=cut

sub _set_up_topic {
    my $this = shift;

    # Create topic
    my $topic = shift;
    my $text  = shift;
    my $user  = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topic, $text );

    $topicObject->save();
}

=pod

Adds a form to a specified topic. Form attributes are passed in a hash.

=cut

sub _addForm {
    my ( $this, $topic, %formData ) = @_;

    $this->assert( Foswiki::Func::topicExists( $this->{test_web}, $topic ) );

    my ( $oldmeta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, $topic );

    my $web = $this->{test_web};
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $web, $topic, $text );

    my $user = $formData{user} || $this->{session}->{user};

    my $users = $this->{session}->{users};
    my $cUID  = $users->getCanonicalUserID($user);
    if ( !$cUID ) {

        # Not a login name or a wiki name. Is it a valid cUID?
        my $ln = $users->getLoginName($user);
        $cUID = $user if defined $ln && $ln ne 'unknown';
    }
    my %options = ();
    my $fieldKey;
    if ( $formData{'field1'} ) {
        $fieldKey = 'field1';
        $topicObject->putKeyed(
            'FIELD',
            {
                name  => $formData{$fieldKey}{name},
                title => $formData{$fieldKey}{name},
                value => $formData{$fieldKey}{value},
            }
        );
    }
    if ( $formData{'field2'} ) {
        $fieldKey = 'field2';
        $topicObject->putKeyed(
            'FIELD',
            {
                name  => $formData{$fieldKey}{name},
                title => $formData{$fieldKey}{name},
                value => $formData{$fieldKey}{value},
            }
        );
    }
    if ( $formData{'field3'} ) {
        $fieldKey = 'field3';
        $topicObject->putKeyed(
            'FIELD',
            {
                name  => $formData{$fieldKey}{name},
                title => $formData{$fieldKey}{name},
                value => $formData{$fieldKey}{value},
            }
        );
    }

    #$options{forcedate}    = $formData{'date'};
    $options{author}  = $cUID;
    $options{format}  = '1.1';
    $options{version} = '1.1913';

    # Added for Item8392; seems the topic isn't saved with correct date
    # otherwise
    $options{forcedate} = $formData{date} if $formData{date};

    $topicObject->save(%options);
}

=pod

=cut

sub _createFormForTopic {
    my ( $this, $topicKey ) = @_;

    my $topic = $testForms{$topicKey}{name};
    my $text  = $testForms{$topicKey}{text} || 'hi';
    my $user  = $testForms{$topicKey}{user} || $this->{test_user_wikiname};

    $this->_set_up_topic( $topic, $text, $user );

    my %formData = %{ $testForms{$topicKey} };
    $this->_addForm( $topic, %formData );

    my ( $meta, $atext ) = $this->_simulate_view( $this->{test_web}, $topic );

    my @formfields = $meta->find('FIELD');
    _printFormFields( $topic, @formfields ); # leave as comment unless debugging
}

=pod

=cut

sub _createForms {

    my $this = shift;

    $this->_createFormForTopic('topic1');
    _makeDelay(1.1);
    $this->_createFormForTopic('topic2');
    _makeDelay(1.1);
    $this->_createFormForTopic('topic3');
    _makeDelay(1.1);
    $this->_createFormForTopic('topic4');
    _makeDelay(1.1);
    $this->_createFormForTopic('topic5');
}

=pod

Needed for debugging (see above).

=cut

sub _printFormFields {
    my ( $inTopic, @inFields ) = @_;

    _debug("FORM FIELDS for topic $inTopic --- ");
    foreach my $field (@inFields) {
        _debug( Dumper($field) );
    }
}

=pod

=cut

sub _simulate_view {
    my ( $this, $web, $topic ) = @_;

    my $oldWebName   = $this->{session}->{webName};
    my $oldTopicName = $this->{session}->{topicName};

    $this->{session}->{webName}   = $web;
    $this->{session}->{topicName} = $topic;

    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

    $this->{session}->{webName}   = $oldWebName;
    $this->{session}->{topicName} = $oldTopicName;

    return ( $meta, $text );
}

=pod

=cut

sub _makeDelay {
    my ($inDelaySeconds) = @_;

    #sleep($inDelaySeconds);
}

=pod

Formats $epoch seconds to the date-time format specified in configure.

=cut

sub _formatDate {
    my ($epoch) = @_;

    return Foswiki::Func::formatTime(
        $epoch,
        $Foswiki::cfg{DefaultDateFormat},
        $Foswiki::cfg{DisplayTimeValues}
    );
}

sub _debug {
    my ($inText) = @_;

    Foswiki::Func::writeDebug($inText);
}

=pod

my @allTopics = split(/\s*,\s*/, $allTopics);
map { $this->_debugMeta($_); } @allTopics;

=cut

sub _debugMeta {
    my ( $this, $inTopic ) = @_;

    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, $inTopic );
    my @topicInfo = $meta->find('TOPICINFO');
    _debug( "meta=" . Dumper(@topicInfo) );
}

1;
