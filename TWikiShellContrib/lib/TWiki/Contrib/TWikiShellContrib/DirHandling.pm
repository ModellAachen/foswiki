package TWiki::Contrib::TWikiShellContrib::DirHandling;

use Exporter;
use File::Path;

@ISA    = (Exporter);
@EXPORT = qw(makepath dirEntries cd);

=pod
---++ TWiki::Contrib::TWikiShellContrib::DirHandling

=cut

=pod

---+++ makepath($path)

Creates the directory structure leading to $path. Examples:

<verbatim>
makepath("/lib/TWiki/Plugin/NewPlugin/NewPlugin.pm");
</verbatim>

will try to create the following directories if they don't exist:
<verbatim>
/lib
/lib/TWiki
/lib/TWiki/Plugin
/lib/TWiki/Plugin/NewPlugin
</verbatim>

<verbatim>
makepath("/pub/SomeDir/SomeSubDir");
</verbatim>

will try to create the following directories if they don't exist:

<verbatim>
/pub
/pub/SomeDir
</verbatim>

=cut

sub makepath {
    my ($to) = @_;
    chop($to) if ( $to =~ /\n$/o );
    $to =~ m!(.+)\/([^\/]*?)$!;
    mkpath( $1, 1 );
}

=pod

---+++ cd($dir)
  Change to the given directory

=cut

sub cd {
    my ($file) = @_;
    chdir($file) || die 'Failed to cd to ' . $file;
}

=pod 

---+++ dirEntries($dir) -> @entries
   Returns the list of names for the entries in the given dir.

=cut

sub dirEntries {
    my $dir = shift;
    opendir DIR, $dir;
    my @entries = readdir DIR;
    close DIR;
    return @entries;
}

1;
