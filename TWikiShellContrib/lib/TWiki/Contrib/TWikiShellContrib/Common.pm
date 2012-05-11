package TWiki::Contrib::TWikiShellContrib::Common;

use Exporter;
@ISA = qw(Exporter);
@EXPORT =
  qw(extractPackageFromSub askUser checkIfDir sys_action findRelativeTo makeExtensionPath);

=pod

---++ TWiki::Contrib::TWikiShellContrib::Common

Useful fuctions to be used in CommandSets. All the functions in this package are exported.

=cut

=pod

---+++ extractPackageFromSub($sub)-> $package

Receives the fully qualified name of a sub (ie: TWiki::writeDebug) and returns only the package (ie: TWiki).

=cut

sub extractPackageFromSub {
    my $sub = shift;
    if ( $sub =~ /(.*)\:\:[^\:]+/ ) {
        return $1;
    }
    else {
        return "";
    }
}

=pod

---+++ askUser($value,$default,$prompt,\&checkOk,$allwaysAsk)->$userInput

Ask the user for an input, providing a default value to be used if no input is received.
The parameters are:
   * $value: Value to be checked. If undef or empty, it'll be set to $default;
   * $default: A default to be suggested to the user.
   * $prompt: the message to be displayed to the user.
   * \&checkOk: A function used to check if the user input is valid or not.
   * $allwaysAsk: By default, askUser verifies if the provided $value (or $default) pass the \&checkOk test. If it pass, the user is not asked. By passing 1 in $allwaysAsk, this check is not performed and the user is always asked for an input.

The result is a $userInput that satisfies the \&checkOk check.

=cut

sub askUser {
    my ( $value, $default, $prompt, $checkOk, $allwaysAsk ) = @_;

    $allwaysAsk = $allwaysAsk || 0;

    if ( !$checkOk ) {
        $checkOk = sub { return 0 };
    }

    $value = $value || $default;

    if ( $allwaysAsk || !&$checkOk($value) ) {
        do {
            print " $prompt [$default]: ---> ";
            chomp( $value = <STDIN> );
        } until ( &$checkOk($value) || $value eq '' );

    }

    return ( $value || $default );
}

=pod 

---+++ checkIfDir($dir)

Convenience function that checks if the given parameter is a directory. Designed to be used with askUser

=cut

sub checkIfDir {
    return ( -d shift );
}

=pod 

---+++ sys_action($cmd)
Perform a "system" command.

=cut

sub sys_action {
    my ($cmd) = @_;
    print "Command: $cmd\n";
    system($cmd);
    die 'Failed to ' . $cmd . ': ' . $? if ($?);
}

=pod 

---+++ findRelativeTo($startdir, $name) -> $path

Look for $name starting in  $startdir, and moving up in the path until $name if found.

Returns the path to $name or undef if not found.

=cut

sub findRelativeTo {
    my ( $startdir, $name ) = @_;

    my @path = split( /\/+/, $startdir );

    while ( scalar(@path) > 0 ) {
        my $found = join( '/', @path ) . '/' . $name;
        return $found if -e $found;
        pop(@path);
    }
    return undef;
}

=pod

---+++ makeExtensionPath($extensionName) -> $path

Returns the path relative to =$TWIKIROOT= for a given extension name.

Examples:

=makeExtensionPath("TWikiShellContrib")= returns =lib/TWiki/Contrib/TWikiShellContrib=

=makeExtensionPath("CommentPlugin")= returns =lib/TWiki/Plugin/CommentPlugin=
=cut

sub makeExtensionPath {
    my $extensionName = shift;
    my $path          = 'lib/TWiki';
    if ( $extensionName =~ /[a-zA-Z]+Contrib$/ ) {
        $path .= '/Contrib';
    }
    else {
        $path .= '/Plugins';
    }

    return $path . '/' . $extensionName;
}

1;
