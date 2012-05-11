package BatchUploadPluginUnitTests;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;

use Foswiki::Func;
use Foswiki::Plugins::BatchUploadPlugin;

sub new {
    my $this = shift()->SUPER::new( 'Unit', @_ );

    # try and guess where our test attachments are
    $this->{attachmentDir} =
"$Foswiki::cfg{WorkingDir}/../../BatchUploadPlugin/test/unit/BatchUploadPlugin/attachment_examples/";
    if ( !-e $this->{attachmentDir} ) {
        die
"Can't find attachment_examples directory (tried $this->{attachmentDir})";
    }

    $this->{simple_archive} = $this->{attachmentDir} . '/simple-archive.zip';
    if ( !-e $this->{simple_archive} ) {
        die "Can't find archive.zip (tried $this->{simple_archive})";
    }

    return $this;
}

sub test_openZipSanityCheck {
    my $this = shift;

    open( my $fh, '<', $this->{simple_archive} );

    my $zip =
      Foswiki::Plugins::BatchUploadPlugin::openZipSanityCheck( $fh,
        $this->{test_web}, $this->{test_topic}, 'archive.zip' );

    $this->assert_not_null($zip);
}

sub test_isZip {
    my $this = shift;

    $this->assert( Foswiki::Plugins::BatchUploadPlugin::isZip('foo.zip') );
    $this->assert( !Foswiki::Plugins::BatchUploadPlugin::isZip('foo.docx') );
}

1;
