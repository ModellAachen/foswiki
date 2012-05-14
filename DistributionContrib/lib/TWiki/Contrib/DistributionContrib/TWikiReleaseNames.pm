package TWiki::Contrib::DistributionContrib::TWikiReleaseNames;
use strict;
use diagnostics;

=pod 

---++ sub wikiVersionToDistributionName($wikiVersion)

 * turns '01 Feb 2003' => "TWiki20030201"

=cut

sub wikiVersionToDistributionName {
    my ($wikiVersion) = @_;
    my %months = (
        Jan => "01",
        Feb => "02",
        Mar => "03",
        Apr => "04",
        May => "05",
        Jun => "06",
        Jul => "07",
        Aug => "08",
        Sep => "09",
        Oct => "10",
        Nov => "11",
        Dec => "12"
    );

    $wikiVersion =~ s/ \$.*//;    # hack off the unique revision number

    # SMELL - this is probably THE most unique way to identify.

    if ( $wikiVersion =~ m/([0-9][0-9]) (.*) ([0-9].*)/ )
    {                             #CodeSmell lazy regex
        my ( $day, $month, $year ) = ( $1, $2, $3 );
        my $monthNumber = $months{$month};
        my $ans         = "TWiki" . $year . $monthNumber . $day;

        #	print $ans;
        return $ans;
    }
    return "ERROR - couldn't parse $wikiVersion";

}

=pod 

---++ sub releaseTopicToDistributionName($releaseTopic)

 * TWikiBetaRelease2004x07x30 => TWiki20040730beta 
 * TWikiRelease20030201 => TWiki20030201

=cut 

sub releaseTopicToDistributionName {
    my ($releaseTopic) = @_;
    my $date;
    my $type;
    if ( $releaseTopic =~ m/TWikiBetaRelease(.*)/ ) {
        $date = $1;
        $date =~ s/x//g;
        $type = "beta";
    }
    elsif ( $releaseTopic =~ m/TWikiRelease(.*)/ ) {
        $date = $1;
        $type = "";
    }
    return "TWiki" . $date . $type;
}

1;
