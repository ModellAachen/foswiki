package TWiki::Contrib::SchedulerContrib::Scheduler;

# Implements http://twiki.org/cgi-bin/view/Codev/CronCentre
# using  http://search.cpan.org/~roland/Schedule-Cron-0.9/Cron.pm

use Schedule::Cron;
my $userCrontab = $ENV{'HOME'} . "/SchedulerContrib.cron";

sub dispatcher {
    print "ID:   ", shift, "\n";
    print "Args: ", "@_", "\n";

    print "1) Dispatching to TWiki::UI::run\n";
    TWiki::UI::run(@_);
}

sub directCall {
    print "2) Direct Call - Does not use dispatcher\n";

    # do something...
}

sub logWorkOutstanding {
    my @entries = $cron->list_entries();
}

sub abortIfAlreadyRunning {

    # find the stored pid
    # if its still there
    # abort
    # else continue running
}

abortIfAlreadyRunning();
findTWikiBinAndLib();
require "TWiki.pm";

# Create new object with default dispatcher
my $cron = new Schedule::Cron( \&dispatcher, log => \&logCron );

# Load a crontab file
if ( -f userCrontab ) {
    $cron->load_crontab($userCrontab);
}
else {
    print "No load user file $userCrontab\n";
    print "Loading defaults\n";

    # This is only hardcoded as a short term measure. We should ask the
    # extensions when they want to be called back.
    $cron->add_entry( "*/1 * * * *", \&TWiki::UI::Statistics::statistics );
    $cron->add_entry( "*/1 * * * *", \&TWiki::Contrib::Mailer::mailNotify );

    #( \@webs, undef, $verbose );
    $cron->add_entry( "*/1 * * * *", \&TWiki::Client::expireDeadSessions );

    # None of those actually get called, but, as tick tock shows,
    # the principle is correct

    $cron->add_entry( "*/2 * * * *", "Tick tock" );
    $cron->add_entry( "*/2 * * * *", \&directCall );
    $cron->add_entry( "*/2 * * * *", \&logWorkOutstanding );
}

use Data::Dumper;
print Dumper( $cron->list_entries() );

print "=======================================\n";

# Run scheduler
$cron->run();

# This would be wired into TWiki's logging mechanism...
sub logCron {
    my ( $level, $msg ) = @_;
    open( LOG, ">>" . $ENV{'HOME'} . "/SchedulerContrib.log" ) || die "$!";
    print LOG "logCron $level - $msg\n";
    close LOG;
}

### Don't look down

# This is so you can run it in either the twiki root or in the twikiplugins/...
# directory.
sub findTWikiBinAndLib {
    if ( !-d 'bin' ) {
        chdir "../../../../";
        if ( !-d 'bin' ) {
            die "No bin dir in `pwd`\n";
        }
    }
    chdir "bin" || die "Could not cd to bin from `pwd`";

    my $pwd = `pwd`;
    chomp $pwd;
    if ( $pwd eq "/bin" ) {
        die
"We've ended up in $pwd, but were looking for TWiki's bin directory, not /bin!\n";
    }

    require "setlib.cfg";
}
