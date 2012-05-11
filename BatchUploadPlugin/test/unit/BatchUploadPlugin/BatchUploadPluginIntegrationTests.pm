package BatchUploadPluginIntegrationTests;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;

use Foswiki;
use Foswiki::Func;
use Foswiki::Plugins::BatchUploadPlugin;
use Error qw( :try );

sub new {
    my $this = shift()->SUPER::new(@_);

    $this->{expected_error} = 'Do not save zip file!';

    # try and guess where our test attachments are
    $this->{attachmentDir} =
"$Foswiki::cfg{WorkingDir}/../../BatchUploadPlugin/test/unit/BatchUploadPlugin/attachment_examples";
    if ( !-e $this->{attachmentDir} ) {
        die
"Can't find attachment_examples directory (tried $this->{attachmentDir})";
    }

    $this->{simple_archive} = $this->{attachmentDir} . '/simple-archive.zip';
    if ( !-e $this->{simple_archive} ) {
        die "Can't find simple-archive.zip (tried $this->{simple_archive})";
    }
    $this->{nested_archive} = $this->{attachmentDir} . '/nested-archive.zip';
    if ( !-e $this->{nested_archive} ) {
        die "Can't find nested-archive.zip (tried $this->{nested_archive})";
    }

    return $this;
}

sub loadExtraConfig {
    my $this = shift;

    $Foswiki::cfg{Plugins}{BatchUploadPlugin}{Enabled} = 1;
    $this->SUPER::loadExtraConfig();
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    # setting the preference does not work...
    #Foswiki::Func::setPreferencesValue( 'BATCHUPLOADPLUGIN_ENABLED', 1 );
    $Foswiki::Plugins::BatchUploadPlugin::pluginEnabled = 1;
}

sub test_attach_zip_by_file {
    my $this = shift;

    try {
        my $error = Foswiki::Func::saveAttachment(
            $this->{test_web},
            $this->{test_topic},
            'archive.zip',
            {
                dontlog    => 1,
                comment    => 'a comment',
                hide       => 1,
                createlink => 0,
                file       => $this->{simple_archive}
            }
        );
    }
    catch Error::Simple with {
        $this->assert_matches( $this->{expected_error}, shift );
    };

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic} );
    my $rev;

    $rev = $meta->getLatestRev('a.txt');
    $this->assert_num_equals( 1, $rev, 'a.txt not found' );
    $rev = $meta->getLatestRev('b.txt');
    $this->assert_num_equals( 1, $rev, 'b.txt not found' );
}

sub test_attach_zip_by_stream {
    my $this = shift;

    open( my $fh, '<', $this->{simple_archive} );

    try {
        my $error = Foswiki::Func::saveAttachment(
            $this->{test_web},
            $this->{test_topic},
            'archive.zip',
            {
                dontlog    => 1,
                comment    => 'a comment',
                hide       => 1,
                createlink => 0,
                stream     => $fh,
            }
        );
    }
    catch Error::Simple with {
        $this->assert_matches( $this->{expected_error}, shift );
    };

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic} );
    my $rev;

    $rev = $meta->getLatestRev('simple-archive.zip');
    $this->assert_num_equals( 0, $rev, 'simple-archive.zip found' );
    $rev = $meta->getLatestRev('a.txt');
    $this->assert_num_equals( 1, $rev, 'a.txt not found' );
    $rev = $meta->getLatestRev('b.txt');
    $this->assert_num_equals( 1, $rev, 'b.txt not found' );
}

sub test_nested_zip {
    my $this = shift;

    open( my $fh, '<', $this->{nested_archive} );

    try {
        my $error = Foswiki::Func::saveAttachment(
            $this->{test_web},
            $this->{test_topic},
            'archive.zip',
            {
                dontlog    => 1,
                comment    => 'a comment',
                hide       => 1,
                createlink => 0,
                stream     => $fh,
            }
        );
    }
    catch Error::Simple with {
        $this->assert_matches( $this->{expected_error}, shift );
    };

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic} );
    my $rev;

    $rev = $meta->getLatestRev('nested-archive.zip');
    $this->assert_num_equals( 0, $rev, 'nested-archive.zip found' );

    # TODO: verify spec of this failure
    $rev = $meta->getLatestRev('simple-archive.zip');
    $this->expect_failure();
    $this->assert_num_equals( 0, $rev, 'simple-archive.zip found' );

    $rev = $meta->getLatestRev('a.txt');
    $this->assert_num_equals( 1, $rev, 'a.txt not found' );
    $rev = $meta->getLatestRev('b.txt');
    $this->assert_num_equals( 1, $rev, 'b.txt not found' );
    $rev = $meta->getLatestRev('c.txt');
    $this->assert_num_equals( 1, $rev, 'c.txt not found' );
}

1;
