#! perl -w
use strict;
use diagnostics;

package TWiki::Contrib::DistributionContrib::FileFetcher;
use TWiki::Contrib::DistributionContrib::Config qw(%config);
my %config = %TWiki::Contrib::DistributionContrib::Config::config;

use LWP::Simple;

=pod
Fetches a copy of a given file and distribution. 
Saves according to TWiki::Contrib::DistributionContrib::Config;

---++ sub fetchDistributionFile() 

In:
| $file | name of filename, e.g. bin/view |
| $distribution | name of distribution, e.g. TWiki20020201 |
| $localFileSuffix | for the downloaded file, any suffix to be added to the filename |

Out:
| $location | where the local copy of the file has been placed |

NB. the localFileSuffix is a way to allow multiple downloaded files to coexist at the same time.
As the FileFetcher does not provide a way to delete the files (and TWiki does not automatically
refresh its attachment table on the arrival of new attachments), I recommend you use unique names
scarcely. e.g. keep using the same localFileSuffix "1", "2"

=cut

sub fetchDistributionFile {
    my ( $file, $distribution, $localFileSuffix ) = @_;
    $localFileSuffix = "" unless ($localFileSuffix);

    $file =~ s!^twiki/!!;
    my $fileUrl = $config{'serverUrl'} . "/" . $distribution . "/" . $file;
    my $webTopicBodge = $config{'saveTopic'};
    $webTopicBodge =~ s!\.!/!;
    my $attachmentPath =
        TWiki::Func::getPubDir() . "/"
      . $webTopicBodge . "/"
      . $config{'saveTopicAttachmentName'}
      . $localFileSuffix;
    my $ans = $attachmentPath;
    my $status = getstore( $fileUrl, $attachmentPath );

    if ( is_error($status) ) {
        my $error =
"Couldn't get $distribution:$file as $fileUrl to $attachmentPath ($status)";
        TWiki::Func::writeWarning( $error . "\n" );
        $ans = "Couldn't download - $error";
    }
    return $ans;
}

1;
