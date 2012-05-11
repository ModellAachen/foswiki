package BatchUploadPluginSuite;
use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub include_tests {
    qw( BatchUploadPluginIntegrationTests BatchUploadPluginUnitTests );
}

1;
