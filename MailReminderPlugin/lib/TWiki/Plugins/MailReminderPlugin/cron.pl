#!/usr/bin/perl -w

#################################################################################################
# CONTRIBUTED TO TWIKI WORLD BY   Naval Bhandari and Ashish Khurange
# Date of Completion : 02/11/2004
# Version number     : 1.000
# Email id           : naval@it.iitb.ac.in  , ashishk@it.iitb.ac.in
# Web Site           : http://www.it.iitb.ac.in/~naval    ,   http://www.it.iitb.ac.in/~ashishk
#################################################################################################

use Mysql;
use DBI;

$cur_dir = $0;
$cur_dir =~ s/\/[^\/]*$//;
$config_file = $cur_dir . "/config_file";
open( CONFIG, $config_file );    # read the configuration file.

while (<CONFIG>) {
    chomp;
    s/#.*//;
    s/^\s+//;
    s/\s+$//;
    next unless length;
    my ( $var, $value ) = split( /\s*=\s*/, $_, 2 );
    $$var = $value;              # initialise configuration variables.
}
close(CONFIG);

$dbh = Mysql->connect( $host, $database, $user, $passwd ); #connect to database.

( $day, $month, $year ) = (localtime)[ 3, 4, 5 ];          # take todays date.

$year  = $year + 1900;
$month = $month + 1;

$query =
    "select name, e_date, event, email_id from caltab where r_date = \'" 
  . $year . "-"
  . $month . "-"
  . $day
  . "\'";    # form query to get the events.

$sth = $dbh->query($query);    # execute query.

while ( @row = $sth->fetchrow ) {
    ( $name, $e_date, $event, $email_id ) = @row;
    send_mail( $name, $e_date, $event, $email_id )
      ;                        # for each event row send the mail.
}

$query =
    "delete from caltab where r_date = \'" 
  . $year . "-" 
  . $month . "-" 
  . $day . "\'";

# form query to delete the events.
$sth = $dbh->query($query);    # execute query.
$sth->finish();

sub send_mail {
    $mail{From} = $email_from;
    $mail{To}   = $_[3];
    $server     = $mailserver;
    use Mail::Sendmail;
    $mail{Smtp}    = $server;
    $mail{Subject} = "Event Reminder.";
    $mail{Message} = "Dear "
      . $_[0]
      . ",\nThis is to remind you that on date : "
      . $_[1]
      . " there is event : "
      . $_[2] . "\n\n"
      . "Regards,\n-Event Reminder Team.";
    sendmail %mail;
}
