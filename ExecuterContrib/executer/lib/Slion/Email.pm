#
# Email.pm
#

=pod

TODO:
-define an object 
-implement credentials support
-implement bcc and cc support
-find a way to specifiy attachments display name for multipart.

=cut

package Slion::Email;

use strict;
use warnings;

use Net::SMTP;
use Carp;
use MIME::Base64;
use MIME::Types;
use POSIX qw( strftime );

=pod
Send a mail.
@param Host name or IP address for the MTA to send the mail through i.e. 127.0.0.1
@param Email address of the sender.
@param Email address of the recipient. Can be a string of semicolon separated addresses.
@param Subject of the message.
@param Body of the message.
=cut

sub Send {
    my ( $smtpHost, $from, $to, $subject, $body ) = @_;
    my $smtp = Net::SMTP->new( $smtpHost, Timeout => 60, Debug => 0 );
    $smtp->mail("$from");
    my @to = split( /;\s*/, $to );
    $smtp->to(@to);    #multiple recipient
    $smtp->data();
    $smtp->datasend("To: $to\n");
    $smtp->datasend("Subject: $subject\n");
    $smtp->datasend("\n");
    $smtp->datasend("$body\n");
    $smtp->dataend();
    $smtp->quit;
}

=pod
Send a mail with possible file attachment.
@param Host name or IP address for the MTA to send the mail through i.e. 127.0.0.1
@param Email address of the sender.
@param Email address of the recipient. Can be a string of semicolon separated addresses.
@param Subject of the message.
@param Body of the message.
@param 	Scalar list the attachments file name separated by a pipe '|' characters. 
		Also supports attachment display name. Just prefix the file name with the display name and separate them using '?'.
		Example: "changelog.txt? d:/temp/changelog.out| diff.txt? d:/temp/diff.txt"
=cut

sub SendMultipart {
    my ( $smtpHost, $from, $to, $subject, $body, $attachments ) = @_;

    my $boundary = InitBoundary();

    my $smtp = Net::SMTP->new( $smtpHost, Timeout => 60, Debug => 0 );
    my @to = split( /;\s*/, $to );

    #The Header function seems to have a bug with multiple recipient
    #$smtp->Header(To   => \@to, Subj => "$subject", From => "$from");

    #So we just set the header the Net::Smtp way instead
    $smtp->mail("$from");    # Sender Mail Address
    $smtp->to(@to);          # Recipient Mail Addresses
    $smtp->data();
    $smtp->datasend(
        strftime( "Date: %a, %d %b %Y %H:%M:%S %z\n", localtime() ) );
    $smtp->datasend("To: $to\n");

    #$self->datasend("Cc: $ccString\n") if ($ccString);
    $smtp->datasend("Subject: $subject\n");
    $smtp->datasend("MIME-Version: 1.0\n");
    $smtp->datasend( sprintf "Content-Type: multipart/mixed; BOUNDARY=\"%s\"\n",
        $boundary );

    Text( $smtp, $boundary, $body );

    my @attachments = split( /\s*\|\s*/, $attachments );
    my $attachment = '';
    foreach $attachment (@attachments) {

        #Check if we have a display name set for that attachment
        my @displayNameAndFileName = split( /\s*\?\s*/, $attachment );

        #print "ATTACH: $attachment\n "; #Debug
        if ( scalar(@displayNameAndFileName) == 2 ) {

            #print "DISPLAY SET @displayNameAndFileName\n"; #debug
            AttachFileWithDisplayName(
                $smtp,
                $displayNameAndFileName[0],
                $displayNameAndFileName[1], $boundary
            );
        }
        else {
            AttachFileWithDisplayName( $smtp, $attachment, $attachment,
                $boundary );
        }
    }

    End( $smtp, $boundary );
}

#Net::SMTP::Multipart implementation is broken in many ways, so instead of trying to use it we just reused the code in there and implemented the following functions
#Those functions could eventually be package as an object

sub InitBoundary {
    my ( $i, $n, @chrs );
    my $b = "";
    foreach $n ( 48 .. 57, 65 .. 90, 97 .. 122 ) { $chrs[ $i++ ] = chr($n); }
    foreach $n ( 0 .. 20 ) { $b .= $chrs[ rand($i) ]; }
    return $b;
}

sub Text {
    my $smtp     = shift;
    my $boundary = shift;
    $smtp->datasend( sprintf "\n--%s\n", $boundary );
    $smtp->datasend("Content-Type: text/plain\n\n");
    foreach my $text (@_) {
        $smtp->datasend($text);
    }
    $smtp->datasend("\n\n");
}

sub End {
    my $smtp     = shift;
    my $boundary = shift;
    $smtp->datasend( sprintf "\n--%s--\n\n", $boundary )
      ;    # send boundary end message
    foreach my $epl (@_) {
        $smtp->datasend("$epl");    # send epilogue text
    }
    $smtp->datasend("\n");          # send final carriage return
    $smtp->dataend();               # close the message
    return $smtp->quit();           # quit and return the status
}

sub AttachFileWithDisplayName {
    my $smtp        = shift;
    my $displayname = shift;
    my $file        = shift;
    my $boundary    = shift;

    my ( $bytesread, $buffer, $data, $total, $fh );
    unless ( -f $file ) {
        carp "Slion::Email: unable to find file $file";
        next;
    }
    open( $fh, "$file" ) || carp "Slion::Email: failed to open $file\n";
    binmode($fh);
    while ( ( $bytesread = sysread( $fh, $buffer, 1024 ) ) == 1024 ) {
        $total += $bytesread;

        # 500K Limit on Upload Images to prevent buffer overflow
        #if (($total/1024) > 500){
        #  printf "TooBig %s\n",$total/1024;
        #  $toobig = 1;
        #  last;
        #}
        $data .= $buffer;
    }
    if ($bytesread) {
        $data .= $buffer;
        $total += $bytesread;
    }

    #print "File Size: $total bytes\n";
    close $fh;

    if ($data) {
        my $mimeType =
          new MIME::Types;    #TODO: optimize that if implementing as an object
        my $type = $mimeType->mimeTypeOf($displayname);
        $smtp->datasend("--$boundary\n"); #TODO: have a warning on that line !?!
        $smtp->datasend("Content-Type: $type; name=\"$displayname\"\n");
        $smtp->datasend("Content-Transfer-Encoding: base64\n");
        $smtp->datasend(
            "Content-Disposition: attachment; =filename=\"$displayname\"\n\n");
        $smtp->datasend( encode_base64($data) );
        $smtp->datasend("\n");
    }
}

1;
