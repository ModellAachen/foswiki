package TWiki::Contrib::TWikiShellContrib::Help;

use Exporter;

@ISA    = (Exporter);
@EXPORT = qw(assembleHelp);

=pod
---++ TWiki::Contrib::TWikiShellContrib::Help

=cut

=pod

---+++ assembleHelp(\%doco,@order) -> $helpText

Assembles a help text from the provided hash.

   * \%doco: A hash containing the help sections and their corresponding texts.
   * @order: A list with the name of the sections, ordered in the way they should be displayed.
   
Example:

Given the following hash (from =TWiki::Contrib::CommandSet::Plugin::Develop=):
<verbatim>
my $doco = {
   "SYNOPSIS" =>" plugin develop <Plugin/Contrib> - Copies the files for the Plugin/Contrib into the twiki root for development",
   "DESCRIPTION" =>
" This command will copy all the related files for a Plugin/Contrib
 from the \${TWIKIROOT}/twikiplugins directory to the proper place 
 under the \${TWIKIROOT} directory, while creating a manifest file 
 with all the files copied.
 This is an alternative to the =mklinks -copy=  command, with the
 added value that it creates a manifest file that can be used by 
 the Package CommandSet or the BuildContrib based =build.pl= 
 script to create a release version.

",
   "EXAMPLE" =>
" twikishell plugin develop TWikiShellContrib

    Will copy all the files from twikiplugins/TWihiShellContrib to
    their proper place and create the TWikiShellContrib.MF file 
    under \${TWIKIROOT}.   
"};
</verbatim>

the call =assembleHelp($doco,"SYNOPSIS","DESCRIPTION","EXAMPLE")= will produce:
<verbatim>
SYNOPSIS
     plugin develop <Plugin/Contrib> - Copies the files for the Plugin/Contrib 
into the twiki root for development

DESCRIPTION
     This command will copy all the related files for a Plugin/Contrib
     from the ${TWIKIROOT}/twikiplugins directory to the proper place
     under the ${TWIKIROOT} directory, while creating a manifest file
     with all the files copied.
     This is an alternative to the =mklinks -copy=  command, with the
     added value that it creates a manifest file that can be used by
     the Package CommandSet or the BuildContrib based =build.pl=
     script to create a release version.

EXAMPLE
     twikishell plugin develop TWikiShellContrib

        Will copy all the files from twikiplugins/TWihiShellContrib to
        their proper place and create the TWikiShellContrib.MF file
        under ${TWIKIROOT}.
</verbatim>

The programmer is responsible of the formating of the text.

=cut

use strict;

sub assembleHelp {
    my $doco  = shift;
    my @order = @_;
    my $help  = '';
    foreach my $section (@order) {
        $help .= _section( $section, $doco->{$section} );
    }
    return $help;

}

sub _section {
    my ( $section, $text ) = @_;
    return '' unless $text;
    $section = uc $section;
    $text = join( "\n", map { "    " . $_; } split( "\n", $text ) );
    return "
$section
$text
";

}

1;
