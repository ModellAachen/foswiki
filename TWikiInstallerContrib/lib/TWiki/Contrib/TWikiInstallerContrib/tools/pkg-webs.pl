#! /usr/bin/perl -w

use Cwd;

@ARGV
  ? PackageLocalWebs(@ARGV)
  : PackageSystemWebs();

exit 0;

################################################################################
################################################################################

sub PackageSystemWebs {
    chdir '/Users/wbniv/Sites/foswiki';
    {
        my @webs = qw( Main System _default Sandbox );
        foreach my $WikiName (@webs) {
            print STDERR $WikiName, "\t";
            print
`cd /Users/wbniv/Sites/foswiki; tar cjf /Users/wbniv/foswiki/install/downloads/webs/system/$WikiName.wiki.tar.bz2 data/$WikiName/ pub/$WikiName/`;
            chomp( my $nTopics =
                  `ls -R /Users/wbniv/Sites/foswiki/data/$WikiName | wc -l` );
            $nTopics =
              int( $nTopics / 2 );    # hack to deal with .txt and .txt,v files
            print STDERR "~$nTopics topic(s)\n";
        }
    }
    chdir '../install';
}

#PackageLocalWebs( qw( AnimalParty Barbie GameDev HowToThinkLikeAComputerScientistUsingPython Isowiki It Owikiforge Personal Platform ProjectManagement SexGame FoswikiDotOrg Tivo WikiDev WillNorris _JobsBoardTemplate _businessplan _skin ) );

################################################################################

sub PackageLocalWebs {
    my @webs = @_;
    foreach my $WikiName (@webs) {
        print STDERR $WikiName, "\t";

#	print `cd /Users/wbniv/Sites/foswiki; tar cjf ../install/webs/local/$WikiName.wiki.tar.bz2 data/$WikiName/ pub/$WikiName/`;
        print
`cd /Users/wbniv/Sites/foswiki; tar cjf /Users/wbniv/foswiki/install/webs/$WikiName.wiki.tar.bz2 data/$WikiName/ pub/$WikiName/`;
        chomp( my $nTopics =
              `ls -R /Users/wbniv/Sites/foswiki/data/$WikiName | wc -l` );
        $nTopics =
          int( $nTopics / 2 );    # hack to deal with .txt and .txt,v files
        print STDERR ~"$nTopics topic(s)\n";
    }
}

sub PackageWeb {

}
