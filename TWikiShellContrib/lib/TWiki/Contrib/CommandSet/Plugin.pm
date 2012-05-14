package TWiki::Contrib::CommandSet::Plugin;

=pod
---++ TWiki::Contrib::CommandSet::Plugin

TWikiExtension Management CommandSet

| *Command* | *Description* |
| plugin create | Creates the suggested directory structure for a TWikiExtension |
| plugin develop  | Prepares the file of a TWikiExtension for development |
| plugin putback | Put back TWikiExtension files into their checkout area |

=cut

sub smry { return "Plugin Management"; }
sub help { return "" }
sub run  { print help(); }

sub onImport {
    my ($shell) = @_;
    $shell->importCommand( $shell->{config}, "Plugin::Develop" );
    $shell->importCommand( $shell->{config}, "Plugin::PutBack" );
    $shell->importCommand( $shell->{config}, "Plugin::Create" );

}

1;

