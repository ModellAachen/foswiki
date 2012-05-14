#
#Run commands read from a TWiki topic
#

use strict;
use warnings;

package Slion::TWiki::Executer;
use Slion::TWiki::Client;
our @ISA = qw( Slion::TWiki::Client );

use vars qw($VERSION);
$VERSION = '1.00';

use TWiki::Func;
use Slion::Email;

#Here we list the commands that executer understands and associate a command with a function
my %cmdFunctions = (
    'OUTPUTFORMWEB'   => \&OutputFormWeb,
    'OUTPUTFORMTOPIC' => \&OutputFormTopic,
    'OUTPUTWEB'       => \&OutputWeb,
    'OUTPUTTOPIC'     => \&DoOutputTopic,
    'OUTPUT'          => \&Output,
    'OUTPUTTWIKIVAR'  => \&OutputTWikiVar,
    'FORMFIELD'       => \&FormField,
    'FORMFIELDEXE'    => \&FormFieldExe,
    'SAVEFIELDS'      => \&SaveFields,
    'SHELLEXE'        => \&ShellExecute,
    'SHELLEXENR'      => \&ShellExecuteNoRedirection,
    'CHDIR'           => \&ChDir,
    'UPLOAD'          => \&DoUpload,
    'TIMEFORMAT'      => \&TimeFormat,
    'VAR'             => \&Var,                         #deprecated
    'USERVAR'         => \&Var,
    'URLEXISTS'       => \&DoUrlExists,
    'IF'              => \&DoIf,
    'ELSE'            => \&DoElse,

    #'ELSEIF' => \&DoElseIf, #Implement some other time
    'ENDIF'    => \&DoEndIf,
    'SENDMAIL' => \&DoSendMail
);

require Slion::TWiki::Client;

#Derives from Slion::TWiki::Client
#@TWikiExecuter::ISA = qw(Slion::TWiki::Client);

sub new {
    my ($aClass) = @_;
    my $self = $aClass->SUPER::new(@_);    #Slion::TWiki::Client
    $self->{OutputTopic}     = undef;
    $self->{OutputWeb}       = undef;
    $self->{OutputFormTopic} = undef;   #Defines the TWikiForm to use
    $self->{OutputFormWeb}   = undef;   #Defines the TWikiForm to use
    $self->{InterruptReason} = undef;   #Human readable reason for the interrupt
    my %FormFields = ();
    $self->{FormFields} =
      \%FormFields;    #Hash containing field values for the DataForms
    my %Var = ();
    $self->{Var} = \%Var;   #Hash containing user variables
                            #my %Param=();							#No need to be initialized here
         #$self->{Param}    		= \%Param;    	#Hash containing parameters
    my %StartTime = ();
    $self->{StartTime} = \%StartTime;    #Hash containing start time values
    my %CurrentTime = ();
    $self->{CurrentTime} = \%CurrentTime;   #Hash containing current time values
    $self->{TimeFormat}    = undef;    #Defines the time format currently in use
    $self->{ShellExeCount} = undef;    #Used for naming of the attached files
    $self->{OutputTopicDetermined} = undef;    # Pointer to a callback function
    $self->{Depth} = 0;    #used for block depth management, in IF block notably
    $self->{Skip}  = 0
      ; #used for IF management. Tells whether or not the next commands should be skipped.

    $self->{TaskSpecTopic} =
      undef;    #Set to the topic name of the task spec in use
    $self->{TaskSpecWeb} = undef;   #Set to the web name of the task spec in use

    $self->{SmtpHost} = undef;      #Set the SMTP host used to send mails

    bless $self, $aClass;

    $self;
}

=pod
Set/Get STMP Host. 
=cut        

sub SmtpHost {
    my $self = shift;
    if (@_) { $self->{SmtpHost} = shift }
    return $self->{SmtpHost};
}

=pod
Set/Get TWiki output Web. 
=cut        

sub OutputWeb {
    my $self = shift;
    if (@_) { $self->{OutputWeb} = shift }
    return $self->{OutputWeb};
}

=pod
Set/Get TWiki output Topic. 
=cut        

sub OutputTopic {
    my $self = shift;
    if (@_) { $self->{OutputTopic} = shift }
    return $self->{OutputTopic};
}

#Used when performing task command
sub DoOutputTopic {
    my $self = shift;
    if (@_) { $self->{OutputTopic} = shift }
    $self->MakeSureTWikiOuputExists;
    return $self->{OutputTopic};
}

=pod
Set/Get TWikiForm web to use for the output Topic. 
=cut        

sub OutputFormWeb {
    my $self = shift;
    if (@_) { $self->{OutputFormWeb} = shift }
    return $self->{OutputFormWeb};
}

=pod
Set/Get TWikiForm topic to use for the output Topic. 
=cut        

sub OutputFormTopic {
    my $self = shift;
    if (@_) { $self->{OutputFormTopic} = shift }
    return $self->{OutputFormTopic};
}

=pod
Set/Get interrupt reason web to use for the output Topic. 
=cut        

sub InterruptReason {
    my $self = shift;
    if (@_) { $self->{InterruptReason} = shift }
    return $self->{InterruptReason};
}

=pod
Set/Get Callback function for output topic creation. 
=cut        

sub OutputTopicDetermined {
    my $self = shift;
    if (@_) { $self->{OutputTopicDetermined} = shift }
    return $self->{OutputTopicDetermined};
}

=pod
Set/Get the time format. 
=cut        

sub TimeFormat {
    my $self = shift;
    if (@_) { $self->{TimeFormat} = shift }
    return $self->{TimeFormat};
}

#Utility function
sub UploadFile() {
    my $self = shift;
    my ( $filepath, $filecomment ) = @_;

    return 0
      unless ( $self->IsTWikiOutput );    #Abort if no TWiki output specified

    #Save current web/topic locally
    my $currentWeb   = $self->Web;
    my $currentTopic = $self->Topic;

    #Set output Web/Topic
    $self->Web( $self->OutputWeb );
    $self->Topic( $self->OutputTopic );

    my $response;
    my %sriptParam = (
        'filepath'    => [$filepath],
        'filecomment' => $filecomment,
        'createlink'  => "1"
    );

    my $res = $self->Upload( \%sriptParam, \$response );

    #Set back previous values into data members
    $self->Web($currentWeb);
    $self->Topic($currentTopic);

    return $res;
}

=pod
Read variables from TWiki web.topic and interpret them as commands. 
A task can include any number of commands.
@param Hash reference for the parameters 
@return Returns 1 if success, 0 if failure.
=cut        

sub DoTask() {
    my $self  = shift;
    my $param = shift;    #Supposed to be hash reference if any

    #Initialize parameters, are later used for variable substitution
    if ( defined $param ) {

        #TODO: could check that we are really dealing with hash ref
        $self->{Param} = $param;
    }
    else {

        #Initialize with empty hash
        my %Param = ();
        $self->{Param} = \%Param;    #Hash containing parameters
    }

#Reset the SHELLEXE command counter.
#That counter is used to name the output files so that their names do not conflict.
    $self->{ShellExeCount}   = 0;
    $self->{InterruptReason} = undef;

    #TODO: shall we also reset some other data member in case of reentrance
    SetTimeHash( $self->{StartTime} );

    #reset IF management variables
    $self->{Depth} = 0;
    $self->{Skip}  = 0;

    #Save input web/topic in data members
    $self->{TaskSpecWeb}   = $self->Web;
    $self->{TaskSpecTopic} = $self->Topic;

    #Read our input topic
    my @myVars = [];
    my $keyVar = 'cmd';
    my $res    = $self->ReadVariablesInOrder( \@myVars, $keyVar )
      ;    # Commands should have Cmd prefix e.g. '   * Cmd = SHELLEXE, dir'
    return $res unless ( $res == 1 );    #Abort if fail to read the variables.

    foreach my $line (@myVars) {
        if ( $line =~ /^\s+\*\s+$keyVar\s+([\w]+)\s+=\s+(.*?)\s*$/i ) {
            my $var   = $1;
            my $value = $2;
            $self->DoCmd( $var, $value );
            if ( defined $self->{InterruptReason} ) {
                print "WARNING: task interruption requested!\n";
                print $self->{InterruptReason};
                return 0;
            }

            #my $var=$1;
            #my $value=$2;
            #print "$var => $value\n";
        }
    }

    #End of task: check if the task was balanced
    if ( $self->{Depth} != 0 ) {
        $self->OutputError("WARNING: Unbalanced task! Check your IF commands.");
    }

    return 1;
}

=pod
Perform actions associated with a command. 
@param [IN]: The command string as a scalar.
@param [IN]: The command parameter(s) as a scalar.
@return Returns 1 if success, 0 if failure.
=cut 

sub DoCmd() {
    my $self = shift;
    my ( $cmd, $cmdParams ) = @_;

    #Check whether that command should be skipped
    return 1 if ( $self->SkipCmd($cmd) );

    #Reset the current time
    SetTimeHash( $self->{CurrentTime} );

    $self->VariableSubstitutions( \$cmdParams );

    $self->NewParagraph()
      ; #TODO: consider getting ride of that, it causes a lot of extra blank lines

    if ( defined $cmdFunctions{$cmd} ) {
        return $cmdFunctions{$cmd}( $self, $cmdParams )
          ;    #Just call the function with the parameters
    }
    else {
        $self->Output("WARNING: command $cmd not defined!");
        return 0;
    }
}

sub MakeSureTWikiOuputExists {
    my $self = shift;

    #Save current web/topic locally
    my $currentWeb   = $self->Web;
    my $currentTopic = $self->Topic;

    my $outputWeb   = $self->OutputWeb;
    my $outputTopic = $self->OutputTopic;

    #Set output Web/Topic
    $self->Web( $self->OutputWeb );
    $self->Topic( $self->OutputTopic );

    #Check if our output topic already exists
    my $exists = $self->Exists;

    #print "$outputWeb.$outputTopic $exists\n";
    if ( $exists == 0 ) {

        #print "Creating TWiki topic for output: $outputWeb.$outputTopic...\n";
        #Our output topic does not exists so we create it
        my $response;
        my %sriptParam = ( 'text' => "" );

        #Set save script parameters
        #Set the formtemplate
        if ( defined $self->OutputFormTopic ) {
            if ( defined $self->OutputFormWeb ) {
                $sriptParam{'formtemplate'} =
                  $self->OutputFormWeb . "." . $self->OutputFormTopic;
            }
            else {
                $sriptParam{'formtemplate'} = $self->OutputFormTopic;
            }
        }

        AppendHash( \%sriptParam, $self->{FormFields} );

        #PrintHash(\%sriptParam);
        #%sriptParam=$self->{FormFields}; #Append fields values

        my $res = $self->Save( \%sriptParam, \$response );

        if ( !$res ) {

 #TODO: we could not create our output topic
 #Shall we parse the response content and give some better error feedback?
 #Request task interruption since it's not wise to continue without output topic
            $self->{InterruptReason} =
"ERROR: Can't create output topic: $outputWeb.$outputTopic!!!\nHTTP response content:\n"
              . $response->content;
            return 0;
        }

#Now we handle the case where we have an output topic name with XXXXXXXXXX, using auto numbering
        my $topicNoXs = $self->Topic;
        if ( $self->Topic =~ /(.*?)XXXXXXXXXX/ ) {
            $topicNoXs = $1;
        }
        if ( $response->headers->header('Location') =~
            /view([\.\w]*)\/$outputWeb\/($topicNoXs\d*)/ )
        {

#We have extracted the actual name of the newly created topic now put it into our member variable
            $outputTopic = $2;
            print "Output TWiki topic is: $outputWeb.$outputTopic...\n";
            $self->OutputTopic($outputTopic);
        }
    }

    if ( defined $self->{OutputTopicDetermined} ) {
        $self->{OutputTopicDetermined}($self);
    }

    #$outputTopic
    #$outputWeb

    #Set back previous values into data members
    $self->Web($currentWeb);
    $self->Topic($currentTopic);

}

=pod
Output some text to a TWiki topic if defined or to STDOUT
Edit the output text can be edited for formatting purposes.  
=cut    

sub Output() {
    my $self = shift;
    my $text = shift;

    if ( $self->IsTWikiOutput ) {

        #$self->MakeSureTWikiOuputExists;

        #Save current web/topic locally
        my $currentWeb   = $self->Web;
        my $currentTopic = $self->Topic;

        #Set output Web/Topic
        $self->Web( $self->OutputWeb );
        $self->Topic( $self->OutputTopic );

        #Replace \n with ' <br />\n'
        #$text=~s/(\n)/$1<br \/>/g;

        #Output our text to the target web.topic
        $self->Append("\n$text <br />");

        #Set back previous values into data members
        $self->Web($currentWeb);
        $self->Topic($currentTopic);

        #Use STDOUT too
        print "$text\n";
    }
    else {

        #No output web.topic specified, just use STDOUT
        print "$text\n";
    }
}

=pod
Output some text to a TWiki topic adding % characters on each side.
=cut    

sub OutputTWikiVar() {
    my $self = shift;
    my $text = shift;

    if ( $self->IsTWikiOutput ) {

        #$self->MakeSureTWikiOuputExists;

        #Save current web/topic locally
        my $currentWeb   = $self->Web;
        my $currentTopic = $self->Topic;

        #Set output Web/Topic
        $self->Web( $self->OutputWeb );
        $self->Topic( $self->OutputTopic );

        #Output our text to the target web.topic
        $self->Append("%$text%");

        #Set back previous values into data members
        $self->Web($currentWeb);
        $self->Topic($currentTopic);

    }

}

=pod
Output some text to a TWiki topic if defined or to STDERR
Edit the output text can be edited for formatting purposes.  
=cut    

sub OutputError() {
    my $self = shift;
    my $text = shift;

    if ( $self->IsTWikiOutput ) {

        #$self->MakeSureTWikiOuputExists;

        #Save current web/topic locally
        my $currentWeb   = $self->Web;
        my $currentTopic = $self->Topic;

        #Set output Web/Topic
        $self->Web( $self->OutputWeb );
        $self->Topic( $self->OutputTopic );

        #Replace \n with ' <br />\n'
        #$text=~s/(\n)/$1<br \/>/g;

        #Output our text to the target web.topic
        $self->Append("\n%RED%$text%ENDCOLOR% <br />");

        #Set back previous values into data members
        $self->Web($currentWeb);
        $self->Topic($currentTopic);

        #Use STDOUT too
        print "$text\n";
    }
    else {

        #No output web.topic specified, just use STDOUT
        print STDERR "$text\n";
    }
}

=pod
Output some text to a TWiki topic if defined or to STDOUT
without editing the output text at all.
=cut    	

sub OutputRaw() {
    my $self = shift;
    my $text = shift;

    if ( $self->IsTWikiOutput ) {

        #$self->MakeSureTWikiOuputExists;

        #Save current web/topic locally
        my $currentWeb   = $self->Web;
        my $currentTopic = $self->Topic;

        #Set output Web/Topic
        $self->Web( $self->OutputWeb );
        $self->Topic( $self->OutputTopic );

        $self->Append($text);

        #Set back previous values into data members
        $self->Web($currentWeb);
        $self->Topic($currentTopic);

        #Use STDOUT too
        print "$text\n";
    }
    else {

        #No output web.topic specified, just use STDOUT
        print $text;
    }
}

sub IsTWikiOutput() {
    my $self = shift;
    return ( defined $self->{OutputTopic} && defined $self->{OutputWeb} );
}

#Output a new paragraph if using TWiki output
sub NewParagraph() {
    my $self = shift;
    if ( $self->IsTWikiOutput ) {

        #New paragraph
        $self->OutputRaw("\n\n");
    }
}

#Static function, not used for now
sub SanitizeFileName() {
    my $name = shift;
    $name =~ s/[\\\/:\*\?\"<>|]//g;
    return $name;
}

=pod
Parses the FORMFIELD command and set the form field value in the form fields hash.
@param The value of the FORMFIELD command.
@return 1 if success, 0 if failure
=cut	

sub FormField() {
    my $self     = shift;
    my $cmdParam = shift;

    if ( $cmdParam =~ /(.+?),\s(.+)/ ) {
        my $fieldName  = $1;
        my $fieldValue = $2;

        #my %formFields=$self->{FormFields};
        #$formFields{$fieldName}=$fieldValue;
        $self->{FormFields}->{$fieldName} = $fieldValue;

        return 1;
    }
    else {
        $self->OutputError("WARNING: Can't parse FORMFIELD: =$cmdParam= !");
        return 0;
    }

    #my @buildConfigs=split (/,\s*/,$variables{"BUILDCONFIGS"}); #HARD CONSTANT
}

=pod
Parses the USERVAR command and set the variable value in the Var hash.
@param The value of the USERVAR command.
@return 1 if success, 0 if failure
=cut	

sub Var() {
    my $self     = shift;
    my $cmdParam = shift;

    if ( $cmdParam =~ /(.+?),\s(.+)/ ) {
        my $varName  = $1;
        my $varValue = $2;
        $self->{Var}->{$varName} = $varValue;
        return 1;
    }
    else {
        $self->OutputError("WARNING: Can't parse USERVAR: =$cmdParam= !");
        return 0;
    }
}

=pod 
Parse and execute the URLEXISTS command and set the given variable accordingly.
@param The value of the URLEXISTS command. Should be of the for 'myUrlExists, http://www.google.com'.
@return 1 if success, 0 if failure
=cut 

sub DoUrlExists() {
    my $self     = shift;
    my $cmdParam = shift;

    if ( $cmdParam =~ /(.+?),\s(.+)/ ) {
        my $varName = $1;
        my $url     = $2;
        $self->{Var}->{$varName} = $self->UrlExists($url);
        return 1;
    }
    else {
        $self->OutputError("WARNING: Can't parse URLEXISTS: =$cmdParam= !");
        return 0;
    }
}

=pod
Parses the FORMFIELDEXE command and set the form field value in the form fields hash.
@param The value of the FORMFIELD command.
@return 1 if success, 0 if failure
=cut	

sub FormFieldExe() {
    my $self     = shift;
    my $cmdParam = shift;

    if ( $cmdParam =~ /(.+?),\s(.+)/ ) {
        my $fieldName  = $1;
        my $exeCommand = $2;
        my $fieldValue = `$exeCommand`;

        #my %formFields=$self->{FormFields};
        #$formFields{$fieldName}=$fieldValue;

        $self->{FormFields}->{$fieldName} = $fieldValue;

        #print ("FormFieldExe: $fieldName => $fieldValue");
        return 1;
    }
    else {
        $self->OutputError("WARNING: Can't parse FORMFIELDEXE: =$cmdParam= !");
        return 0;
    }

    #my @buildConfigs=split (/,\s*/,$variables{"BUILDCONFIGS"}); #HARD CONSTANT

}

=pod
Execute the SAVEFIELDS command. It saves the fields to the output topic.
@return 1 if success, 0 if failure
=cut	

sub SaveFields {
    my $self = shift;

    #Save current web/topic locally
    my $currentWeb   = $self->Web;
    my $currentTopic = $self->Topic;

    #Set output Web/Topic
    $self->Web( $self->OutputWeb );
    $self->Topic( $self->OutputTopic );

    my $response;

    #PrintHash($self->{FormFields});
    my $res = $self->Save( $self->{FormFields}, \$response );

    #Set back previous values into data members
    $self->Web($currentWeb);
    $self->Topic($currentTopic);

    return $res;
}

=pod
Executes a shell command while automatically redirecting standard and error output to temopary files.
Standard and error output files will be uploaded to the output TWiki topic unless they are empty.
@param The shell command to execute.
@return 1 if success, 0 if failure
=cut	

sub ShellExecute() {
    my $self     = shift;
    my $cmdParam = shift;

    my $temp;
    my $count = $self->{ShellExeCount};
    $self->{ShellExeCount}++
      ;    #increment to avoid file name conflict for next iteration

    my $stdout;
    my $errout;
    my $redirect;

    #Some specific code for MS windows
    if ( $^O eq 'MSWin32' ) {
        $temp     = $ENV{TEMP};
        $stdout   = "$temp\\stdout$count.txt";
        $errout   = "$temp\\errout$count.txt";
        $redirect = " 1>$stdout 2>$errout";
    }
    else {
        $temp     = '/tmp';
        $stdout   = "$temp/stdout$count.txt";
        $errout   = "$temp/errout$count.txt";
        $redirect = " 1>$stdout 2>$errout";
    }

    $self->Output("Executing: =$cmdParam=");

    #my $comspec=$ENV{COMSPEC}; # comspec version commented out
    #system("$comspec /C $cmdParam$redirect"); #Excute the command
    system("$cmdParam$redirect");    #Excute the command
    my $exit_value = $? >> 8;
    $self->Output("Exit code: $exit_value.");

    #my $size=-s $stdout;
    #print "DEBUG: $size";

    if ( -s $stdout )   #Avoid zero size upload, -s returns the size of the file
    {
        $self->UploadFile( $stdout, "=$cmdParam= standard output" );
    }

    if ( -s $errout )   #Avoid zero size upload, -s returns the size of the file
    {
        $self->UploadFile( $errout, "=$cmdParam= error output" );
    }

    return 1;
}

=pod
Executes a shell command without redirecting standard and error output. 
@param The shell command to execute.
@return 1 if success, 0 if failure
=cut		

sub ShellExecuteNoRedirection() {
    my $self     = shift;
    my $cmdParam = shift;

    $self->Output("Executing: =$cmdParam=");
    system("$cmdParam");    #Excute the command
    my $exit_value = $? >> 8;
    $self->Output("Exit code: $exit_value.");
    return 1;
}

sub ChDir() {
    my $self     = shift;
    my $cmdParam = shift;
    if ( chdir($cmdParam) ) {
        $self->Output("Directory changed to: =$cmdParam=");
        return 1;
    }
    else {
        $self->OutputError("ERROR: Failed to change directory to: =$cmdParam=");
        return 0;
    }
}

=pod
Perfrom the UPLOAD command	
=cut

sub DoUpload() {
    my $self     = shift;
    my $cmdParam = shift;

    if ( -s $cmdParam ) #Avoid zero size upload, -s returns the size of the file
    {
        $self->UploadFile( $cmdParam, "$cmdParam" );
        return 1;
    }
    else {
        $self->OutputError(
"ERROR: Can't upload =$cmdParam=. The file does not exists or is empty!"
        );
        return 0;
    }
}

=pod
Perfrom the SENDMAIL command	
=cut

sub DoSendMail() {
    my $self     = shift;
    my $cmdParam = shift;

    #my ($smtpHost, $from, $to, $subject, $body, $attachments)=@_;

    my %params = TWiki::Func::extractParameters($cmdParam);

    #my ($smtpHost, $from, $to, $subject, $body, $attachments)
    $self->OutputError("WARNING: SENDMAIL missing =from= parameter!")
      unless defined $params{from};
    $self->OutputError("WARNING: SENDMAIL missing =to= parameter!")
      unless defined $params{to};
    $self->OutputError("WARNING: SENDMAIL missing SMTP Host!")
      unless defined $self->{SmtpHost};

    if (   defined $params{from}
        && defined $params{to}
        && defined $self->{SmtpHost} )
    {
        if ( defined $params{attachments} ) {
            Slion::Email::SendMultipart( $self->{SmtpHost}, $params{from},
                $params{to}, $params{subject}, $params{body},
                $params{attachments} );
        }
        else {
            Slion::Email::Send(
                $self->{SmtpHost}, $params{from}, $params{to},
                $params{subject},  $params{body}
            );
        }
    }
}

=pod
IF management. Right now we don't support nested IFs.
=cut

sub DoIf() {
    my $self     = shift;
    my $cmdParam = shift;

    #Increment the depth
    $self->{Depth}++;

    if ( $self->{Depth} > 1 ) {

        #Interrupt the task, we don't support nested IFs yet
        $self->InterruptReason("ERROR: nested IFs not supported!");
        return 0;
    }

    if ( $cmdParam =~ /\s*(.+?)\s*==\s*(.+?)\s*/ ) {
        my $left  = $1;
        my $right = $2;
        $self->{Skip} = ( $left ne $right );
        return 1;
    }
    elsif ( $cmdParam =~ /\s*(.+?)\s*!=\s*(.+?)\s*/ ) {
        my $left  = $1;
        my $right = $2;
        $self->{Skip} = ( $left eq $right );
        return 1;
    }
    elsif ( $cmdParam =~ /\s*!(.+?)\s*/ ) {
        $self->{Skip} = $1;
        return 1;
    }
    else {

        #Can't parse the if condition just assume its false;
        $self->{Skip} = !$cmdParam;

#$self->OutputError("WARNING: Can't parse IF: =$cmdParam= ! Assuming condition is false.");
        return 1;
    }
}

sub DoElse() {
    my $self     = shift;
    my $cmdParam = shift;

    if ( $self->{Depth} != 1 ) {

        #Unbalanced task
        $self->InterruptReason("ERROR: orphaned ELSE!");
        return 0;
    }

    #Reverse the skip flag
    $self->{Skip} = !$self->{Skip};
    return 1;
}

=pod

#ELSEIF pattern is a bit complicated for tonight

sub DoElseIf()
    {
	my $self=shift;
    #If we skipped the block before then evaluate the ELSEIF otherwise just 
    if ($self->{Skip})
        {
    	return $self->DoIf(@_);
        }
    else
        {
        return 1;
        }
    }
=cut

sub DoEndIf() {
    my $self     = shift;
    my $cmdParam = shift;

    #Our if block is closed, make sure we are not skipping commands from now on
    #Decrement the depth
    $self->{Depth}--;
    $self->{Skip} = 0;

    if ( $self->{Depth} < 0 ) {

        #Unbalanced task
        $self->InterruptReason("ERROR: orphaned ENDIF!");
        return 0;
    }

    return 1;
}

=pod
Returns whether or not a command should be skipped.
@param The command to evaluate.
@return true if the command should be skipped false otherwise.
=cut

sub SkipCmd() {
    my $self = shift;
    my $cmd  = shift;

    if ( $self->{Skip} && !( $cmd =~ /IF|ELSE|ENDIF/ ) ) {
        return 1;
    }
    else {
        return 0;
    }
}

=pod
Substitute $variable name thing in a given string

=cut	

sub VariableSubstitutions {

    #TODO: could optimize, but we don't care ;)
    my $self    = shift;
    my $textRef = shift;

    #Supported format
    # $formfield(name)
    # $starttime(year)
    # $currenttime(format)
    # $var(myvar)
    # $param(myparam)
    # $outputweb
    # $outputtopic

    #Do the form field
    my $formFieldRef = $self->{FormFields};
    while ( my ( $key, $value ) = each(%$formFieldRef) ) {
        $$textRef =~ s/\$formfield\($key\)?/$value/g;
    }

    #Do the var
    my $varRef = $self->{Var};
    while ( my ( $key, $value ) = each(%$varRef) ) {
        $$textRef =~ s/\$var\($key\)?/$value/g;
    }

    #Do the param
    my $paramRef = $self->{Param};
    while ( my ( $key, $value ) = each(%$paramRef) ) {
        $$textRef =~ s/\$param\($key\)?/$value/g;
    }

    #Do the start time
    my $startTimeRef = $self->{StartTime};
    while ( my ( $key, $value ) = each(%$startTimeRef) ) {
        $$textRef =~ s/\$starttime\($key\)?/$value/g;
    }

    #Do $starttime(format)
    if ( defined $self->{TimeFormat} && $$textRef =~ /\$starttime\(format\)/ ) {
        my $formattedStartTime = $self->{TimeFormat};
        FormatTime( $startTimeRef, \$formattedStartTime );
        $$textRef =~ s/\$starttime\(format\)/$formattedStartTime/g;
    }

    #Do the current time
    my $currentTimeRef = $self->{CurrentTime};
    while ( my ( $key, $value ) = each(%$currentTimeRef) ) {
        $$textRef =~ s/\$currenttime\($key\)?/$value/g;
    }

    #Do $currenttime(format)
    if ( defined $self->{TimeFormat} && $$textRef =~ /\$currenttime\(format\)/ )
    {
        my $formattedCurrentTime = $self->{TimeFormat};
        FormatTime( $currentTimeRef, \$formattedCurrentTime );
        $$textRef =~ s/\$currenttime\(format\)/$formattedCurrentTime/g;
    }

    #Do $outputweb
    $$textRef =~ s/\$outputweb/$self->{OutputWeb}/g;

    #Do $outputtopic
    $$textRef =~ s/\$outputtopic/$self->{OutputTopic}/g;

    #Do $taskspecweb
    $$textRef =~ s/\$taskspecweb/$self->{TaskSpecWeb}/g;

    #Do $taskspectopic
    $$textRef =~ s/\$taskspectopic/$self->{TaskSpecTopic}/g;
}

#Utility functions
sub AppendHash {
    my $target = shift;
    my $source = shift;
    while ( my ( $key, $value ) = each(%$source) ) {
        $target->{$key} = $value;
    }
}

sub PrintHash {
    my $hash = shift;
    while ( my ( $key, $value ) = each(%$hash) ) {
        print("$key => $value\n");
    }
}

sub SetTimeHash {
    my $hash = shift;

    my ( $sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst ) =
      localtime(time);
    $year += 1900;
    $month++;

    #Do some 0 padding first
    $sec   = sprintf( "%02d", $sec );
    $min   = sprintf( "%02d", $min );
    $hour  = sprintf( "%02d", $hour );
    $mday  = sprintf( "%02d", $mday );
    $month = sprintf( "%02d", $month );

    $hash->{sec}   = $sec;
    $hash->{min}   = $min;
    $hash->{hour}  = $hour;
    $hash->{mday}  = $mday;
    $hash->{month} = $month;
    $hash->{year}  = $year;
    $hash->{wday}  = $wday;
    $hash->{yday}  = $yday;

    #my @monthAbbr = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
    #$year += 1900;
    #my $formattedTime="$mday-$mon-$year";
    #return $formattedTime;
}

sub FormatTime {
    HashVarSubst(@_);
}

=pod
Substitute variables in a string as defined be the given hash.
It looks for every '$hashkey' instance in the string and substitutes it with the actual hash value.
=cut

sub HashVarSubst {
    my $hash = shift;
    my $text = shift;

    while ( my ( $key, $value ) = each(%$hash) ) {
        $$text =~ s/\$$key/$value/g;
    }
}

1;    #PERL stuff so that the package can be include using 'use' or 'require'
