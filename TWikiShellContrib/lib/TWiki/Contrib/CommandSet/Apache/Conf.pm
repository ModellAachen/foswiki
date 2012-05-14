package TWiki::Contrib::CommandSet::Apache::Conf;

use TWiki::Contrib::TWikiShellContrib::Common;

use Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(configure);

sub configure {
    my ( $shell, $config ) = @_;
    my $apacheDefault = "/etc/apache/httpd.conf";

    $config->{APACHE}{httpd} = askUser(
        $config->{APACHE}{httpd},
        '',
        "Apache configuration file",
        sub { return ( -e shift ) }
    );
}

1;
