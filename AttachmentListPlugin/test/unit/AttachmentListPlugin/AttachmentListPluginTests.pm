
package AttachmentListPluginTests;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;

use Foswiki;
use Foswiki::Meta;
use Error qw( :try );
use Foswiki::UI::Save;
use Foswiki::OopsException;
use Foswiki::Plugins::AttachmentListPlugin;
use Devel::Symdump;
use Data::Dumper;
use File::Path qw(mkpath);

my %testAttachments = (
    topic1 => {
        name        => 'AttachmentListTestTopic1',
        attachment1 => {
            name    => 'A_important_salary_raise.txt',
            size    => 1000 * 1.024,
            user    => 'JohnDoe',
            date    => 1100000000,
            hidden  => 'h',
            comment => 'do not read',
        },
        attachment2 => {
            name    => 'B_contract_negotiations.txt',
            size    => 2000 * 1.024,
            user    => 'MaryDoe',
            date    => 1200000000,
            hidden  => '',
            comment => 'do not read either',
        },
    },
    topic2 => {
        name        => 'AttachmentListTestTopic2',
        attachment1 => {
            name    => 'C_image.jpg',
            size    => 10000 * 1.024,
            user    => 'AdamBlithe',
            date    => 1300000000,
            hidden  => '',
            comment => 'me',
        },
        attachment2 => {
            name    => 'D_photo.PNG',
            size    => 20000 * 1.024,
            user    => 'KathyJones',
            date    => 1400000000,
            hidden  => 'h',
            comment => 'you',
        },
    },
    topic3 => {
        name        => 'AttachmentListTestTopic3',
        attachment1 => {
            name    => 'E_todo.xsl',
            size    => 10 * 1.024,
            user    => 'JohnDoe',
            date    => 1500000000,
            hidden  => '',
            comment => 'johnny',
        },
        attachment2 => {
            name    => 'F_report.doc',
            size    => 0,
            user    => 'AdminUser',
            date    => 1600000000,
            hidden  => '',
            comment => 'aAbB',
        },
    },
    topic4 => {
        name        => 'AttachmentListTestTopic4',
        attachment1 => {
            name    => 'G_readme.txt',
            size    => 10,
            date    => 1700000000,
            hidden  => '',
            comment => '',
        },
        attachment2 => {
            name    => 'H_AUTHORS',
            size    => 2,
            user    => 'AdminUser',
            date    => 1800000000,
            hidden  => '',
            comment => '',
        },
    },
    topic5 => {
        name        => 'AttachmentListTestTopic5',
        text        => "\n   * Set ALLOWTOPICVIEW = AdminUser",
        attachment1 => {
            name    => 'I_no_permission.txt',
            size    => 10,
            date    => 1200000000,
            hidden  => '',
            comment => '',
        },
        attachment2 => {
            name    => 'J_DIRECTORS',
            size    => 20,
            user    => 'AdminUser',
            date    => 1800000000,
            hidden  => '',
            comment => '',
        },
    }
);

sub new {
    my $self = shift()->SUPER::new( 'AttachmentListPluginTests', @_ );
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $this->_createAttachments();
    $this->{plugin_name} = 'AttachmentListPlugin';

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

Most simple test: attachments of current topic

=cut

sub test_simple {
    my $this = shift;

    my $pubUrl = Foswiki::Func::getUrlHost() . Foswiki::Func::getPubUrlPath();
    my $testTopic   = $testAttachments{topic1}{name};
    my $att1        = $testAttachments{topic1}{attachment1}{name};
    my $att1comment = $testAttachments{topic1}{attachment1}{comment};
    my $att2        = $testAttachments{topic1}{attachment2}{name};
    my $att2comment = $testAttachments{topic1}{attachment2}{comment};

    my $source = '%ATTACHMENTLIST{}%';

    my $expected =
      "   * [[$pubUrl/$this->{test_web}/$testTopic/$att1][$att1]] $att1comment";
    $expected .= "\n";
    $expected .=
      "   * [[$pubUrl/$this->{test_web}/$testTopic/$att2][$att2]] $att2comment";

    $this->_do_test( $testTopic, $expected, $source );
}

=pod

Test retrieval of attachments of specified topics 1 and 2.

=cut

sub test_param_topic {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};
    my $testTopic2 = $testAttachments{topic2}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic1,$testTopic2\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\"}%";

    my $expected =
'A_important_salary_raise.txt,B_contract_negotiations.txt,C_image.jpg,D_photo.PNG';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test retrieval of attachments autoattached, and not in metadata.

=cut

sub test_Item9015 {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};
    my $testTopic2 = $testAttachments{topic2}{name};
    $Foswiki::cfg{RCS}{AutoAttachPubFiles} = 1;

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic1,$testTopic2\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\"}%";

    my $expected =
'A_important_salary_raise.txt,AutoAttachedFile.blah,B_contract_negotiations.txt,C_image.jpg,D_photo.PNG';

    my $content = "datadata\n";
    my $path =
      $Foswiki::cfg{PubDir} . '/' . $this->{test_web} . '/' . $testTopic1;
    my $file = 'AutoAttachedFile.blah';

    mkpath($path);
    open( my $fh, '>', "$path/$file" )
      or die "Unable to open $path/$file for writing: $!\n";
    print $fh "$content \n";
    close($fh);

    $this->_do_test( $testTopic1, $expected, $source );

    unlink "$path/$file";
}

=pod

TODO:

Test retrieval of attachments of specified topic 1, passed 2 times.
Duplicates should be removed.

=cut

sub test_param_topic_duplicates {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic1,$testTopic1\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\"}%";

    my $expected = 'A_important_salary_raise.txt,B_contract_negotiations.txt';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Exclude topics 1 and 2, should find topics 3 and 4.

=cut

sub test_param_excludetopic_topic_notation {
    my $this = shift;

    my $excludeTopic1 = $testAttachments{topic1}{name};
    my $excludeTopic2 = $testAttachments{topic2}{name};

    my $source =
"%ATTACHMENTLIST{excludetopic=\"$excludeTopic1,$excludeTopic2\" topic=\"*\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\"}%";

    my $expected = 'E_todo.xsl,F_report.doc,G_readme.txt,H_AUTHORS';

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Exclude topics 1 and 2, should find topics 3 and 4 - variant with web.topic notation.

=cut

sub test_param_excludetopic_webtopic_notation {
    my $this = shift;

    my $web           = $this->{test_web};
    my $excludeTopic1 = "$web.$testAttachments{topic1}{name}";
    my $excludeTopic2 = "$web.$testAttachments{topic2}{name}";

    my $source =
"%ATTACHMENTLIST{excludetopic=\"$excludeTopic1,$excludeTopic2\" topic=\"*\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\"}%";

    my $expected = 'E_todo.xsl,F_report.doc,G_readme.txt,H_AUTHORS';

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param web. TODO: test other webs

=cut

sub test_param_web {
    my $this = shift;

    my $source =
"%ATTACHMENTLIST{topic=\"*\" web=\"$this->{test_web}\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\"}%";

    my $expected =
'A_important_salary_raise.txt,B_contract_negotiations.txt,C_image.jpg,D_photo.PNG,E_todo.xsl,F_report.doc,G_readme.txt,H_AUTHORS';

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param excludeweb. TODO: test other webs

=cut

sub test_param_excludeweb {
    my $this = shift;

    my $source =
"%ATTACHMENTLIST{topic=\"*\" excludeweb=\"$this->{test_web}\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\"}%";

    my $expected = '';

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param limit with a valid number.

=cut

sub test_param_limit_int {
    my $this = shift;

    my $source =
"%ATTACHMENTLIST{topic=\"*\" web=\"$this->{test_web}\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\" limit=\"2\"}%";

    my $expected = "A_important_salary_raise.txt,B_contract_negotiations.txt";

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param limit with '0'

=cut

sub test_param_limit_0 {
    my $this = shift;

    my $source =
"%ATTACHMENTLIST{topic=\"*\" web=\"$this->{test_web}\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\" limit=\"0\"}%";

    my $expected = '';

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param format: $fileName.

=cut

sub test_param_format_fileName {
    my $this = shift;

    my $format    = "\$fileName";
    my $testTopic = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic\" web=\"$this->{test_web}\" format=\"$format\" limit=\"1\"}%";

    my $expected = $testAttachments{topic1}{attachment1}{name};

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param format: $fileSize.

=cut

sub test_param_format_fileSize {
    my $this = shift;

    my $format    = "\$fileSize";
    my $testTopic = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic\" web=\"$this->{test_web}\" format=\"$format\" limit=\"1\"}%";

    my $expected = '1.0K';    #$testAttachments{topic1}{attachment1}{size};

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param format: $fileExtension.

=cut

sub test_param_format_fileExtension {
    my $this = shift;

    my $format    = "\$fileExtension";
    my $testTopic = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic\" web=\"$this->{test_web}\" format=\"$format\" limit=\"1\"}%";

    my $expected = 'txt';

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param format: $fileIcon.

=cut

sub test_param_format_fileIcon {
    my $this       = shift;
    my $pubUrlPath = Foswiki::Func::getPubUrlPath();

    my $format    = "\$fileIcon";
    my $testTopic = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic\" web=\"$this->{test_web}\" format=\"$format\" limit=\"1\"}%";

    my $expected =
"<span class=\"foswikiIcon\"><img src=\"%PUBURL%/%SYSTEMWEB%/DocumentGraphics/txt.png\" width=\"16\" height=\"16\" alt=\"txt\" /></span>";

    $expected = Foswiki::Func::expandCommonVariables($expected);
    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param format: $fileComment.

=cut

sub test_param_format_fileComment {
    my $this = shift;

    my $format    = "\$fileComment";
    my $testTopic = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic\" web=\"$this->{test_web}\" format=\"$format\" limit=\"1\"}%";

    my $expected = $testAttachments{topic1}{attachment1}{comment};

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param format: $fileUser.

=cut

sub test_param_format_fileUser {
    my $this = shift;

    my $format    = "\$fileUser";
    my $testTopic = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic\" web=\"$this->{test_web}\" format=\"$format\" limit=\"1\"}%";

    my $expected = $testAttachments{topic1}{attachment1}{user};

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param format: $fileDate.

=cut

sub test_param_format_fileDate {
    my $this = shift;

    my $format    = "\$fileDate";
    my $testTopic = $testAttachments{topic1}{name};
    my $rawDate   = $testAttachments{topic1}{attachment1}{date};

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic\" web=\"$this->{test_web}\" format=\"$format\" limit=\"1\"}%";

    my $expected = Foswiki::Func::formatTime(
        $rawDate,
        $Foswiki::cfg{DefaultDateFormat},
        $Foswiki::cfg{DisplayTimeValues}
    );

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param format: $fileUrl.

=cut

sub test_param_format_fileUrl {
    my $this = shift;

    my $pubUrl = Foswiki::Func::getUrlHost() . Foswiki::Func::getPubUrlPath();

    my $format         = "\$fileUrl";
    my $testTopic      = $testAttachments{topic1}{name};
    my $attachmentName = $testAttachments{topic1}{attachment1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic\" web=\"$this->{test_web}\" format=\"$format\" limit=\"1\"}%";

    my $expected =
        $pubUrl . '/'
      . $this->{test_web} . '/'
      . $testTopic . '/'
      . $attachmentName;

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param format: $fileTopic.

=cut

sub test_param_format_fileTopic {
    my $this = shift;

    my $format    = "\$fileTopic";
    my $testTopic = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic\" web=\"$this->{test_web}\" format=\"$format\" limit=\"1\"}%";

    my $expected = $testTopic;

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param format: $fileWeb.

=cut

sub test_param_format_fileWeb {
    my $this = shift;

    my $format    = "\$fileWeb";
    my $testTopic = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic\" web=\"$this->{test_web}\" format=\"$format\" limit=\"1\"}%";

    my $expected = $this->{test_web};

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param format: $viewfileUrl.

=cut

sub test_param_format_viewfileUrl {
    my $this = shift;

    my $viewFileUrl =
      Foswiki::Func::expandCommonVariables( '%SCRIPTURL{"viewfile"}%',
        $this->{test_topic}, $this->{test_web} );

    my $format         = "\$viewfileUrl";
    my $testTopic      = $testAttachments{topic1}{name};
    my $attachmentName = $testAttachments{topic1}{attachment1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic\" web=\"$this->{test_web}\" format=\"$format\" limit=\"1\"}%";

    my $expected =
        $viewFileUrl . '/'
      . $this->{test_web} . '/'
      . $testTopic
      . '?rev=&filename='
      . $attachmentName;

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param format: $fileActionUrl.

=cut

sub test_param_format_fileActionUrl {
    my $this = shift;

    my $actionUrl =
      Foswiki::Func::expandCommonVariables( '%SCRIPTURL{"attach"}%',
        $this->{test_topic}, $this->{test_web} );

    my $format         = "\$fileActionUrl";
    my $testTopic      = $testAttachments{topic1}{name};
    my $attachmentName = $testAttachments{topic1}{attachment1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic\" web=\"$this->{test_web}\" format=\"$format\" limit=\"1\"}%";

    my $expected =
        $actionUrl . '/'
      . $this->{test_web} . '/'
      . $testTopic
      . '?filename='
      . $attachmentName
      . '&revInfo=1';

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param format: $imgTag.

=cut

sub test_param_format_imgTag {
    my $this   = shift;
    my $pubUrl = Foswiki::Func::getUrlHost() . Foswiki::Func::getPubUrlPath();

    my $format         = "\$imgTag";
    my $testTopic      = $testAttachments{topic1}{name};
    my $attachmentName = $testAttachments{topic1}{attachment1}{name};

    my $fileUrl =
        $pubUrl . '/'
      . $this->{test_web} . '/'
      . $testTopic . '/'
      . $attachmentName;
    my $fileComment = $testAttachments{topic1}{attachment1}{comment};

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic\" web=\"$this->{test_web}\" format=\"$format\" limit=\"1\"}%";

    my $expected =
      "<img src='$fileUrl' alt='$fileComment' title='$fileComment' />";

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param format: $imgWidth and $imgHeight of a GIF image.

=cut

sub test_param_format_GIF_imgWidth_and_imgHeight {
    my $this = shift;

    my $format = "\$imgWidth x \$imgHeight";

    my $source =
"%ATTACHMENTLIST{topic=\"FileAttachment\" web=\"%SYSTEMWEB%\" format=\"$format\" file=\"Smile.gif\"}%";

    my $expected = '15 x 15';

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test param format: $imgWidth and $imgHeight of a JPEG image.

=cut

sub test_param_format_JPEG_imgWidth_and_imgHeight {
    my $this = shift;

    my $format = "\$imgWidth x \$imgHeight";

    my $source =
"%ATTACHMENTLIST{topic=\"TestCaseAmISane\" web=\"TestCases\" format=\"$format\" file=\"volcano.jpg\" separator=\",\"}%";

    my $expected = '113 x 85';

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

TODO: Test param format: $imgWidth and $imgHeight of a PNG image.
Currently no png images are listed in META:FILEATTACHMENT topic data.

sub test_param_format_PNG_imgWidth_and_imgHeight {
    my $this = shift;

    my $format    = "\$imgWidth x \$imgHeight";

    my $source =
"%ATTACHMENTLIST{topic=\"ProjectLogos\" web=\"%SYSTEMWEB%\" format=\"$format\" file=\"T-logo-140x40.png\" separator=\",\"}%";

    my $expected = '140 x 40';

    $this->_do_test( $this->{test_topic}, $expected, $source );
}
=cut

=pod

Test param format: $hidden.

=cut

sub test_param_format_hidden {
    my $this = shift;

    my $format    = "\$hidden";
    my $testTopic = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic\" web=\"$this->{test_web}\" format=\"$format\" limit=\"1\"}%";

    my $expected = 'hidden';

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test separator.

=cut

sub test_param_separator {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};
    my $testTopic2 = $testAttachments{topic2}{name};
    my $separator  = '12321';
    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic1,$testTopic2\" format=\"\$fileName\" separator=\"$separator\" sort=\"\$fileName\"}%";

    my $expected =
        'A_important_salary_raise.txt'
      . $separator
      . 'B_contract_negotiations.txt'
      . $separator
      . 'C_image.jpg'
      . $separator
      . 'D_photo.PNG';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param header.

=cut

sub test_param_header_specified {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};
    my $header     = 'Things I Love:';

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic1\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\" header=\"$header\"}%";

    my $expected =
"Things I Love:\nA_important_salary_raise.txt,B_contract_negotiations.txt";

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param header with no string specified.

=cut

sub test_param_header_empty {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};
    my $header     = '';

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic1\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\" header=\"$header\"}%";

    my $expected = "A_important_salary_raise.txt,B_contract_negotiations.txt";

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param footer.

=cut

sub test_param_footer_specified {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};
    my $footer     = 'Number of files: $fileCount';

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic1\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\" footer=\"$footer\"}%";

    my $expected =
"A_important_salary_raise.txt,B_contract_negotiations.txt\nNumber of files: 2";

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param footer with no string specified.

=cut

sub test_param_footer_empty {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};
    my $footer     = '';

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic1\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\" footer=\"$footer\"}%";

    my $expected = "A_important_salary_raise.txt,B_contract_negotiations.txt";

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param alt.

=cut

sub test_param_alt {
    my $this       = shift;
    my $testTopic1 = $testAttachments{topic1}{name};

    my $alt = 'I could not find any file you specified.';

    my $source = "%ATTACHMENTLIST{topic=\"DOES_NOT_EXIST\" alt=\"$alt\"}%";

    my $expected = $alt;

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param hide.

=cut

sub test_param_hide_on {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic1\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\" hide=\"on\"}%";

    my $expected = 'B_contract_negotiations.txt';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param hide with other value than 'on'.

=cut

sub test_param_hide_off {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic1\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\" hide=\"off\"}%";

    my $expected = 'A_important_salary_raise.txt,B_contract_negotiations.txt';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param extension.

=cut

sub test_param_extension {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};
    my $extension  = 'txt,JPG';

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\" extension=\"$extension\"}%";

    my $expected =
'A_important_salary_raise.txt,B_contract_negotiations.txt,C_image.jpg,G_readme.txt';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param excludeextension.

=cut

sub test_param_excludeextension {
    my $this = shift;

    my $testTopic1       = $testAttachments{topic1}{name};
    my $excludeextension = 'txt,JPG';

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\" excludeextension=\"$excludeextension\"}%";

    my $expected = 'D_photo.PNG,E_todo.xsl,F_report.doc,H_AUTHORS';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param extension NONE.

=cut

sub test_param_extension_none {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};
    my $extension  = 'txt, NONE';

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\" extension=\"$extension\"}%";

    my $expected =
'A_important_salary_raise.txt,B_contract_negotiations.txt,G_readme.txt,H_AUTHORS';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param excludeextension.

=cut

sub test_param_extension_with_excludeextension {
    my $this = shift;

    my $testTopic1       = $testAttachments{topic1}{name};
    my $extension        = 'doc';
    my $excludeextension = 'txt,JPG';

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\" extension=\"$extension\" excludeextension=\"$excludeextension\"}%";

    my $expected = 'F_report.doc';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param user.

=cut

sub test_param_user {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};
    my $user       = 'JohnDoe, KathyJones';

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileUser\" separator=\",\" sort=\"\$fileName\" user=\"$user\"}%";

    my $expected = 'JohnDoe,KathyJones,JohnDoe';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param user - not specified.

=cut

sub test_param_user_not_specified {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};
    my $user       = 'UnknownUser';

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileUser\" separator=\",\" sort=\"\$fileName\" user=\"$user\"}%";

    my $expected = 'UnknownUser';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param excludeuser.

=cut

sub test_param_excludeuser {
    my $this = shift;

    my $testTopic1  = $testAttachments{topic1}{name};
    my $excludeuser = 'JohnDoe, KathyJones';

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileUser\" separator=\",\" sort=\"\$fileName\" excludeuser=\"$excludeuser\"}%";

    my $expected = 'MaryDoe,AdamBlithe,AdminUser,UnknownUser,AdminUser';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param user with param excludeuser.

=cut

sub test_param_user_with_excludeuser {
    my $this = shift;

    my $testTopic1  = $testAttachments{topic1}{name};
    my $user        = 'JohnDoe, KathyJones';
    my $excludeuser = 'KathyJones';

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileUser\" separator=\",\" sort=\"\$fileName\" user=\"$user\" excludeuser=\"$excludeuser\"}%";

    my $expected = 'JohnDoe,JohnDoe';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param file.

=cut

sub test_param_file {
    my $this = shift;

    my $testTopic1     = $testAttachments{topic1}{name};
    my $attachmentName = $testAttachments{topic4}{attachment2}{name};

    my $file = 'H_AUTHORS';

    my $source =
"%ATTACHMENTLIST{topic=\"*\" file=\"$file\" format=\"\$fileName\" separator=\",\"}%";

    my $expected = $attachmentName;

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test retrieval of excluded attachments of specified topics 1 and 2.

=cut

sub test_param_excludefile {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};
    my $testTopic2 = $testAttachments{topic2}{name};
    my $excluded   = 'A_important_salary_raise.txt,D_photo.PNG';
    my $source =
"%ATTACHMENTLIST{topic=\"$testTopic1,$testTopic2\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\" excludefile=\"$excluded\"}%";

    my $expected = "B_contract_negotiations.txt,C_image.jpg";

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param file together with param excludefile. Should return nothing.

=cut

sub test_param_file_and_excludefile {
    my $this = shift;

    my $testTopic1     = $testAttachments{topic1}{name};
    my $attachmentName = $testAttachments{topic4}{attachment2}{name};

    my $file        = 'H_AUTHORS';
    my $excludefile = 'H_AUTHORS';

    my $source =
"%ATTACHMENTLIST{topic=\"*\" file=\"$file\" excludefile=\"$excludefile\" format=\"\$fileName\" separator=\",\"}%";

    my $expected = '';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param includefilepattern.

=cut

sub test_param_includefilepattern {
    my $this = shift;

    my $testTopic1     = $testAttachments{topic1}{name};
    my $attachmentName = $testAttachments{topic4}{attachment2}{name};

    my $includefilepattern = '(?i)^[AB]';

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileName\" separator=\",\" includefilepattern=\"$includefilepattern\"}%";

    my $expected = 'A_important_salary_raise.txt,B_contract_negotiations.txt';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param excludefilepattern.

=cut

sub test_param_excludefilepattern {
    my $this = shift;

    my $testTopic1     = $testAttachments{topic1}{name};
    my $attachmentName = $testAttachments{topic4}{attachment2}{name};

    my $excludefilepattern = '(?i)^[AB]';

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileName\" separator=\",\" excludefilepattern=\"$excludefilepattern\" sort=\"\$fileName\"}%";

    my $expected =
      'C_image.jpg,D_photo.PNG,E_todo.xsl,F_report.doc,G_readme.txt,H_AUTHORS';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param includefilepattern with param excludefilepattern.

=cut

sub test_param_includefilepattern_with_excludefilepattern {
    my $this = shift;

    my $testTopic1     = $testAttachments{topic1}{name};
    my $attachmentName = $testAttachments{topic4}{attachment2}{name};

    my $includefilepattern = '(?i)^[A-Z]';
    my $excludefilepattern = '(?i)^[B]';

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileName\" separator=\",\" includefilepattern=\"$includefilepattern\" excludefilepattern=\"$excludefilepattern\" sort=\"\$fileName\"}%";
    my $expected =
'A_important_salary_raise.txt,C_image.jpg,D_photo.PNG,E_todo.xsl,F_report.doc,G_readme.txt,H_AUTHORS';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test param includefilepattern with param excludefilepattern, where both patterns overlap each other.

=cut

sub test_param_includefilepattern_with_excludefilepattern_overlapping {
    my $this = shift;

    my $testTopic1     = $testAttachments{topic1}{name};
    my $attachmentName = $testAttachments{topic4}{attachment2}{name};

    my $includefilepattern = '(?i)^[A-D]';
    my $excludefilepattern = '(?i)^[A-D]';

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileName\" separator=\",\" includefilepattern=\"$includefilepattern\" excludefilepattern=\"$excludefilepattern\" sort=\"\$fileName\"}%";

    my $expected = '';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test sorting with sort param fileName.

=cut

sub test_param_sort_fileName {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\"}%";

    my $expected =
"A_important_salary_raise.txt,B_contract_negotiations.txt,C_image.jpg,D_photo.PNG,E_todo.xsl,F_report.doc,G_readme.txt,H_AUTHORS";

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test sorting with sort param fileName, and param sortorder descending.

=cut

sub test_param_sort_fileName_sortorder_descending {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};
    my $sortOrder  = 'descending';

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\" sortorder=\"$sortOrder\"}%";

    my $expected =
"H_AUTHORS,G_readme.txt,F_report.doc,E_todo.xsl,D_photo.PNG,C_image.jpg,B_contract_negotiations.txt,A_important_salary_raise.txt";

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test sorting with sort param fileName, and param sortorder reverse.

=cut

sub test_param_sort_fileName_sortorder_reverse {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};
    my $sortOrder  = 'reverse';

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\" sortorder=\"$sortOrder\"}%";

    my $expected =
"H_AUTHORS,G_readme.txt,F_report.doc,E_todo.xsl,D_photo.PNG,C_image.jpg,B_contract_negotiations.txt,A_important_salary_raise.txt";

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test sorting with sort param fileSize.

=cut

sub test_param_sort_fileSize {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileSize\" separator=\",\" sort=\"\$fileSize\"}%";

    my $expected = '0,2b,10b,10.24b,1.0K,2.0K,10.0K,20.0K';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test sorting with sort param fileSize, with sortorder descending.

=cut

sub test_param_sort_fileSize_descending {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileSize\" separator=\",\" sort=\"\$fileSize\" sortorder=\"descending\"}%";

    my $expected = '20.0K,10.0K,2.0K,1.0K,10.24b,10b,2b,0';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test sorting with sort param fileSize, with sortorder reverse.

=cut

sub test_param_sort_fileSize_reverse {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileSize\" separator=\",\" sort=\"\$fileSize\" sortorder=\"reverse\"}%";

    my $expected = '20.0K,10.0K,2.0K,1.0K,10.24b,10b,2b,0';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test sorting with sort param fileUser.

=cut

sub test_param_sort_fileUser {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileUser\" separator=\",\" sort=\"\$fileUser\"}%";

    my $expected =
'AdamBlithe,AdminUser,AdminUser,JohnDoe,JohnDoe,KathyJones,MaryDoe,UnknownUser';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test sorting with sort param fileUser, sortorder descending.

=cut

sub test_param_sort_fileUser_descending {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileUser\" separator=\",\" sort=\"\$fileUser\" sortorder=\"descending\"}%";

    my $expected =
'UnknownUser,MaryDoe,KathyJones,JohnDoe,JohnDoe,AdminUser,AdminUser,AdamBlithe';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test sorting with sort param fileUser, sortorder reverse.

=cut

sub test_param_sort_fileUser_reverse {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileUser\" separator=\",\" sort=\"\$fileUser\" sortorder=\"reverse\"}%";

    my $expected =
'UnknownUser,MaryDoe,KathyJones,JohnDoe,JohnDoe,AdminUser,AdminUser,AdamBlithe';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test sorting with sort param fileDate. Dates are sorted descending by default.

=cut

sub test_param_sort_fileDate {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileDate\" separator=\",\" sort=\"\$fileDate\"}%";

    my $expected =
'15 Jan 2027,14 Nov 2023,13 Sep 2020,14 Jul 2017,13 May 2014,13 Mar 2011,10 Jan 2008,09 Nov 2004';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test sorting with sort param fileDate, sortorder descending. Dates are sorted descending by default.

=cut

sub test_param_sort_fileDate_descending {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileDate\" separator=\",\" sort=\"\$fileDate\" sortorder=\"descending\"}%";

    my $expected =
'15 Jan 2027,14 Nov 2023,13 Sep 2020,14 Jul 2017,13 May 2014,13 Mar 2011,10 Jan 2008,09 Nov 2004';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test sorting with sort param fileDate, sortorder ascending.

=cut

sub test_param_sort_fileDate_ascending {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileDate\" separator=\",\" sort=\"\$fileDate\" sortorder=\"ascending\"}%";

    my $expected =
'09 Nov 2004,10 Jan 2008,13 Mar 2011,13 May 2014,14 Jul 2017,13 Sep 2020,14 Nov 2023,15 Jan 2027';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test sorting with sort param fileDate, sortorder reverse.

=cut

sub test_param_sort_fileDate_reverse {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileDate\" separator=\",\" sort=\"\$fileDate\" sortorder=\"reverse\"}%";

    my $expected =
'09 Nov 2004,10 Jan 2008,13 Mar 2011,13 May 2014,14 Jul 2017,13 Sep 2020,14 Nov 2023,15 Jan 2027';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test sorting with sort param fileExtension.

=cut

sub test_param_sort_fileExtension {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileExtension\" separator=\",\" sort=\"\$fileExtension\"}%";

    my $expected = 'doc,jpg,,png,txt,txt,txt,xsl';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test sorting with sort param fileExtension, sortorder descending.

=cut

sub test_param_sort_fileExtension_descending {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileExtension\" separator=\",\" sort=\"\$fileExtension\" sortorder=\"descending\"}%";

    my $expected = 'xsl,txt,txt,txt,png,,jpg,doc';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test sorting with sort param fileExtension, sortorder reverse.

=cut

sub test_param_sort_fileExtension_reverse {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileExtension\" separator=\",\" sort=\"\$fileExtension\" sortorder=\"reverse\"}%";

    my $expected = 'xsl,txt,txt,txt,png,,jpg,doc';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test sorting with sort param fileTopic.

=cut

sub test_param_sort_fileTopic {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileTopic\" separator=\",\" sort=\"\$fileTopic\"}%";

    my $expected =
'AttachmentListTestTopic1,AttachmentListTestTopic1,AttachmentListTestTopic2,AttachmentListTestTopic2,AttachmentListTestTopic3,AttachmentListTestTopic3,AttachmentListTestTopic4,AttachmentListTestTopic4';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test sorting with sort param fileTopic, sortorder descending.

=cut

sub test_param_sort_fileTopic_descending {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileTopic\" separator=\",\" sort=\"\$fileTopic\" sortorder=\"descending\"}%";

    my $expected =
'AttachmentListTestTopic4,AttachmentListTestTopic4,AttachmentListTestTopic3,AttachmentListTestTopic3,AttachmentListTestTopic2,AttachmentListTestTopic2,AttachmentListTestTopic1,AttachmentListTestTopic1';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test sorting with sort param fileTopic, sortorder reverse.

=cut

sub test_param_sort_fileTopic_reverse {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileTopic\" separator=\",\" sort=\"\$fileTopic\" sortorder=\"reverse\"}%";

    my $expected =
'AttachmentListTestTopic4,AttachmentListTestTopic4,AttachmentListTestTopic3,AttachmentListTestTopic3,AttachmentListTestTopic2,AttachmentListTestTopic2,AttachmentListTestTopic1,AttachmentListTestTopic1';

    $this->_do_test( $testTopic1, $expected, $source );
}

sub test_param_sort_fileComment {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$hidden:\$fileComment\" separator=\"|\" sort=\"\$fileComment\"}%";

    my $expected =
      'hidden:do not read|hidden:you|:|:|:aAbB|:do not read either|:johnny|:me';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test date range filter with param fromdate.

=cut

sub test_param_fromdate {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileDate\" separator=\",\" sort=\"\$fileTopic\" fromdate=\"2020/09/13\"}%";

    my $expected = '13 Sep 2020,14 Nov 2023,15 Jan 2027';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test date range filter with param todate.

=cut

sub test_param_todate {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileDate\" separator=\",\" sort=\"\$fileTopic\" todate=\"2020/09/13\"}%";

    my $expected =
      '09 Nov 2004,10 Jan 2008,13 Mar 2011,13 May 2014,14 Jul 2017,13 Sep 2020';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test date range filter with param fromdate and param todate.

=cut

sub test_param_fromdate_and_todate {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileDate\" separator=\",\" sort=\"\$fileTopic\" fromdate=\"2020/09/13\" todate=\"2020/09/13\"}%";

    my $expected = '13 Sep 2020';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test date range filter with param fromdate and param todate, with both dates excluding each other.

=cut

sub test_param_fromdate_and_todate_excluding {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileDate\" separator=\",\" sort=\"\$fileTopic\" fromdate=\"2020/09/13\" todate=\"2019/09/13\"}%";

    my $expected = '';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test formatting variables.

$n or $n()  	 New line. Use $n() if followed by alphanumeric character, e.g. write Foo$n()Bar instead of Foo$nBar
$nop or $nop() 	Is a "no operation".
$quot 	Double quote (")
$percnt 	Percent sign (%)
$dollar 	Dollar sign ($)
$br 	<br /> tag 

=cut

sub test_formatting_variables {
    my $this = shift;

    my $testTopic1 = $testAttachments{topic1}{name};
    my $format =
'$fileName$n()$nop%TOPIC% or %TOPIC%$n$quot$fileComment$quot$n()$percnt$dollar$br';

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"$format\" file=\"A_important_salary_raise.txt\" sort=\"\$fileTopic\"}%";

    my $expected = 'A_important_salary_raise.txt
AttachmentListTestTopic1 or AttachmentListTestTopic1
"do not read"
%$<br />';

    $this->_do_test( $testTopic1, $expected, $source );
}

=pod

Test formatting variable fileCount.

=cut

sub test_formatting_fileCount {
    my $this = shift;

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileName\" separator=\",\" sort=\"\$fileName\" limit=\"1\" header=\"Number of files: \$fileCount\" footer=\"Number of files: \$fileCount\"}%";

    my $expected = 'Number of files: 1
A_important_salary_raise.txt
Number of files: 1';

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

Test formatting variable fileExtensions.

=cut

sub test_formatting_fileExtensions {
    my $this = shift;

    my $source =
"%ATTACHMENTLIST{topic=\"*\" format=\"\$fileExtension\" separator=\",\" sort=\"\$fileName\" footer=\"Extensions: \$fileExtensions\"}%";

    my $expected = 'txt,txt,jpg,png,xsl,doc,txt,
Extensions: doc,jpg,png,txt,xsl';

    $this->_do_test( $this->{test_topic}, $expected, $source );
}

=pod

=cut

sub _set_up_topic {
    my $this = shift;

    # Create topic
    my $topic = shift;
    my $text  = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topic, $text );

    $topicObject->save();
}

=pod

Adds an attachment to a specified topic. Attachment attributes are passed in a hash.

=cut

sub _addAttachment {
    my ( $this, $topic, %attData ) = @_;

    $this->assert( Foswiki::Func::topicExists( $this->{test_web}, $topic ) );

    my ( $meta, $text ) = Foswiki::Func::readTopic( $this->{test_web}, $topic );

    $meta->putKeyed(
        'FILEATTACHMENT',
        {
            name    => $attData{name},
            version => '',
            path    => $attData{name},
            size    => $attData{size},
            date    => $attData{date},
            user    => $attData{user},
            comment => $attData{comment},
            attr    => $attData{hidden},
        }
    );

    $meta->save();
}

=pod

=cut

sub _createAttachmentsForTopic {
    my ( $this, $topicKey ) = @_;

    my $topic = $testAttachments{$topicKey}{name};
    my $text = $testAttachments{$topicKey}{text} || 'hi';
    $this->_set_up_topic( $topic, $text );
    {

        # attachment1
        my %attachmentData = %{ $testAttachments{$topicKey}{attachment1} };
        $this->_addAttachment( $topic, %attachmentData );
    }
    {

        # attachment2
        my %attachmentData = %{ $testAttachments{$topicKey}{attachment2} };
        $this->_addAttachment( $topic, %attachmentData );
    }
    my ( $meta, $atext ) = $this->_simulate_view( $this->{test_web}, $topic );

    #my @attachments = $meta->find('FILEATTACHMENT');
    #_printAttachments(@attachments);    # leave as comment unless debugging
}

=pod

=cut

sub _createAttachments {

    my $this = shift;
    $this->_createAttachmentsForTopic('topic1');
    $this->_createAttachmentsForTopic('topic2');
    $this->_createAttachmentsForTopic('topic3');
    $this->_createAttachmentsForTopic('topic4');

    #$this->_createAttachmentsForTopic('topic5');
    # uncomment to test access permission
}

=pod

Needed for debugging (see above).

=cut

sub _printAttachments {
    my (@attachments) = @_;

    print "\n\n-------ATTACHMENTS--------\n";
    foreach my $attachment (@attachments) {
        print "Attachment found: " . Dumper($attachment) . "\n";
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

1;
