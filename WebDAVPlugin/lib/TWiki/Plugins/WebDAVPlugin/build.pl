#!/usr/bin/perl -w
#
# Build class for WebDAVPlugin

# Standard preamble
BEGIN {
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} || '' ) ) {
        unshift @INC, $pc;
    }
}

use TWiki::Contrib::Build;

package WebDAVPluginBuild;

@WebDAVPluginBuild::ISA = ("TWiki::Contrib::Build");

sub new {
    my $class = shift;
    return bless( $class->SUPER::new("WebDAVPlugin"), $class );
}

# override to build C program in test dir

=pod

sub target_test {
    my $this = shift;

    open(F,">/tmp/tmp.c") || die $!;
    print F "#include <tdb.h>\n";
    close F;

    `gcc /tmp/tmp.c -ltdb`;
    if( $? ) {
        print STDERR "Installing TDB\n";
        $this->pushd($this->{basedir}."/lib/tdb");
        if (! -f 'Makefile') {
            # must be in /usr for apache
            $this->sys_action("./configure --prefix=/usr/");
        }
        $this->sys_action("make install");
        $this->popd();
    } else {
        die "BOLLOCKS";
    }

    $this->pushd($this->{basedir}."/lib/twiki_dav");
    if (! -f 'Makefile') {
        # Assume dynamic loading
        $this->sys_action("./configure --with-apxs");
    }
    $this->popd();
    $this->pushd($this->{basedir}."/lib/twiki_dav");
    $this->sys_action("make install");
    $this->popd();

    $this->pushd("$this->{basedir}/test/unit/WebDAVPlugin");
    $this->sys_action("gcc access_check.c -g -I $this->{basedir}/lib/twiki_dav -g -o accesscheck -ltdb");
    $this->popd();

    $this->SUPER::target_test;
}

=cut

$build = new WebDAVPluginBuild();

$build->build( $build->{target} );
