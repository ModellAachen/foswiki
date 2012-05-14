
package TopicDataHelperPluginTests;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );
use strict;
use Error qw( :try );

use Foswiki;
use Foswiki::Meta;
use Foswiki::Func;
use Foswiki::Plugins::TopicDataHelperPlugin;
use Foswiki::UI::Save;
use Foswiki::OopsException;
use Devel::Symdump;
use Data::Dumper;

my %testForms = (
    topic1 => {
        name   => 'FormFieldListTestTopic1',
        user   => 'ScumBag',
        date   => '1100000000',
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
        date   => 1200000000,
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
        date   => 1300000000,
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
        date   => 1400000000,
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

my $defaultUsersWeb = 'TemporaryTopicDataHelperPluginTestsUsersWeb';

sub new {
    my $self = shift()->SUPER::new( 'TopicDataHelperPluginTests', @_ );
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $this->_createForms();
    $this->{plugin_name} = 'TopicDataHelperPlugin';

    $Foswiki::cfg{Plugins}{ $this->{plugin_name} }{Enabled} = 1;
    $Foswiki::cfg{Plugins}{ $this->{plugin_name} }{Module} =
      "Foswiki::Plugins::$this->{plugin_name}";
    $this->{session}->finish();
    $this->{session} = new Foswiki();                # default user
    $Foswiki::Plugins::SESSION = $this->{session};
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

sub test_createTopicData_default {
    my $this = shift;

    my $webs = $this->{test_web};
    my $topics =
"FormFieldListTestTopic2,FormFieldListTestTopic1,,FormFieldListTestTopic3,FormFieldListTestTopic5,FormFieldListTestTopic4,";

    my $excludeTopics = undef;
    my $excludeWebs   = undef;

    # find all topics except for excluded topics
    my $topicData =
      Foswiki::Plugins::TopicDataHelperPlugin::createTopicData( $webs,
        $excludeWebs, $topics, $excludeTopics );

    my $resultTopics           = $topicData->{ $this->{test_web} };
    my @resultTopicsList       = sort keys %{$resultTopics};
    my $resultTopicsListString = join( ",", @resultTopicsList );
    $this->assert_equals(
'FormFieldListTestTopic1,FormFieldListTestTopic2,FormFieldListTestTopic3,FormFieldListTestTopic4,FormFieldListTestTopic5',
        $resultTopicsListString
    );
}

=pod

=cut

sub test_createTopicData_default_no_web {
    my $this = shift;

    my $webs   = undef;
    my $topics = "WebHome,WebPreferences";

    my $excludeTopics = undef;
    my $excludeWebs   = undef;

    # find all topics except for excluded topics
    my $topicData =
      Foswiki::Plugins::TopicDataHelperPlugin::createTopicData( $webs,
        $excludeWebs, $topics, $excludeTopics );

    my $resultTopics           = $topicData->{$defaultUsersWeb};
    my @resultTopicsList       = sort keys %{$resultTopics};
    my $resultTopicsListString = join( ",", @resultTopicsList );
    $this->assert_equals( 'WebHome,WebPreferences', $resultTopicsListString );
}

=pod

=cut

sub test_createTopicData_all_topics {
    my $this = shift;

    my $webs   = $this->{test_web};
    my $topics = '*';

    my $excludeTopics = undef;
    my $excludeWebs   = undef;

    # find all topics except for excluded topics
    my $topicData =
      Foswiki::Plugins::TopicDataHelperPlugin::createTopicData( $webs,
        $excludeWebs, $topics, $excludeTopics );

    my $resultTopics           = $topicData->{ $this->{test_web} };
    my @resultTopicsList       = sort keys %{$resultTopics};
    my $resultTopicsListString = join( ",", @resultTopicsList );
    $this->assert_equals(
'FormFieldListTestTopic1,FormFieldListTestTopic2,FormFieldListTestTopic3,FormFieldListTestTopic4,FormFieldListTestTopic5,TestTopicTopicDataHelperPluginTests,WebPreferences',
        $resultTopicsListString
    );
}

=pod

=cut

sub test_createTopicData_exclude_web {
    my $this = shift;

    my $webs = $this->{test_web};
    my $topics =
"FormFieldListTestTopic2,FormFieldListTestTopic1,,FormFieldListTestTopic3,FormFieldListTestTopic5,FormFieldListTestTopic4,";
    my $excludeTopics = undef;
    my $excludeWebs   = ",Main,$this->{test_web},";

    # find all topics except for excluded topics
    my $topicData =
      Foswiki::Plugins::TopicDataHelperPlugin::createTopicData( $webs,
        $excludeWebs, $topics, $excludeTopics );

    my $resultTopics           = $topicData->{ $this->{test_web} };
    my @resultTopicsList       = sort keys %{$resultTopics};
    my $resultTopicsListString = join( ",", @resultTopicsList );
    $this->assert_equals( '', $resultTopicsListString );
}

=pod

=cut

sub test_createTopicData_exclude_topics {
    my $this = shift;

    my $webs = $this->{test_web};
    my $topics =
"FormFieldListTestTopic2,FormFieldListTestTopic1,,FormFieldListTestTopic3,FormFieldListTestTopic5,FormFieldListTestTopic4,";
    my $excludeTopics = 'FormFieldListTestTopic5,   FormFieldListTestTopic1';
    my $excludeWebs   = undef;

    # find all topics except for excluded topics
    my $topicData =
      Foswiki::Plugins::TopicDataHelperPlugin::createTopicData( $webs,
        $excludeWebs, $topics, $excludeTopics );

    my $resultTopics           = $topicData->{ $this->{test_web} };
    my @resultTopicsList       = sort keys %{$resultTopics};
    my $resultTopicsListString = join( ",", @resultTopicsList );
    $this->assert_equals(
'FormFieldListTestTopic2,FormFieldListTestTopic3,FormFieldListTestTopic4',
        $resultTopicsListString
    );
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
}

=pod

=cut

sub _createForms {

    my $this = shift;

    $this->_createFormForTopic('topic1');
    $this->_createFormForTopic('topic2');
    $this->_createFormForTopic('topic3');
    $this->_createFormForTopic('topic4');
    $this->_createFormForTopic('topic5');
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

    sleep($inDelaySeconds);
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

package TopicDataHelperPluginTests::TestTopicData;

use strict;
use overload ( '""' => \&as_string );

my %sortKeys = (
    '$name'      => [ 'name',      'string' ],
    '$value'     => [ 'value',     'string' ],
    '$fieldDate' => [ 'fieldDate', 'integer' ],
    '$topicName' => [ 'topic',     'string' ],
    '$topicDate' => [ 'date',      'integer' ],
    '$topicUser' => [ 'user',      'string' ],
);

our $EMPTY_VALUE_PLACEHOLDER = '';

=pod

=cut

sub new {
    my ( $class, $web, $topic, $field, $name ) = @_;
    my $this = {};

    $this->{'field'} = $field;

    # only copy sort keys to FormFieldData attributes
    $this->{'name'}  = $name             || '';
    $this->{'title'} = $name             || $field->{'title'} || '';
    $this->{'value'} = $field->{'value'} || $EMPTY_VALUE_PLACEHOLDER;
    $this->{'date'}      = undef;
    $this->{'fieldDate'} = '';
    $this->{'topic'}     = $topic;
    $this->{'user'}      = undef;

    $this->{'web'}      = $web;
    $this->{'notfound'} = 0;

    bless $this, $class;
}

sub getSortKey {
    my ($inRawKey) = @_;
    return $sortKeys{$inRawKey}[0];
}

sub getCompareMode {
    my ($inRawKey) = @_;
    return $sortKeys{$inRawKey}[1];
}

sub setTopicDate {
    my ( $this, $inDate ) = @_;
    $this->{date} = $inDate;
    if ( !$this->{'fieldDate'} ) {
        $this->{'fieldDate'} = $inDate;
    }
}

sub setFieldDate {
    my ( $this, $inDate ) = @_;
    $this->{'fieldDate'} = $inDate;
}

=pod

Stringify function for data storage.

Most important data as string, each value separated by a tab:
- stringify version number
- web
- topic
- name
- value
- topicDate

=cut

sub stringify {
    my $this = shift;

    return
"1.0\t$this->{web}\t$this->{topic}\t$this->{name}\t$this->{value}\t$this->{date}";
}

=pod

Stringify function for debugging only.

=cut

sub as_string {
    my $this = shift;

    return
        "FormFieldListPlugin: web="
      . $this->{'web'}
      . "; topic="
      . $this->{'topic'}
      . "; name="
      . $this->{'name'}
      . "; value="
      . $this->{'value'};
}

1;
