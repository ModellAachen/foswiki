package TWiki::Contrib::CommandSet::TWiki;

use TWiki::Contrib::CommandSet::TWiki::Conf;

=pod

---++ TWiki::Contrib::CommandSet::TWiki

This CommandSet does not have any commands. It exist only to discover all the information about the TWiki installation where TWikiShell recides, and make it available through the TWikiShellConfigObject.


=cut

sub onImport {
    my ($shell) = @_;
    configure(@_);
}

1;
