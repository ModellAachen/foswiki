#
# Provides access to TWiki.
#

use strict;
use warnings;

require LWP;    #need to use LWP::UserAgent for upload

use vars qw($VERSION);
$VERSION = '0.12';

package Slion::TWiki::Client;

#Sub classing LWP::UserAgent to set our credentials
{

    package Slion::TWiki::Client::UserAgent;
    @Slion::TWiki::Client::UserAgent::ISA = qw(LWP::UserAgent);

    sub new {
        my $self = LWP::UserAgent::new(@_);
        $self->agent("Slion::TWiki::Client");
        $self;
    }

    sub get_basic_credentials {
        my $self = shift;
        return ( $self->{User}, $self->{Password} );
    }

}

=pod
Create a new Slion::TWiki::Client object. 
=cut        

sub new {

    #A bit of magic to get the class name in case of inheritance
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};

    #Initialize data member
    $self->{ScriptUrl} = undef;
    $self->{Web}       = undef;
    $self->{Topic}     = undef;
    $self->{User}      = undef;
    $self->{Password}  = undef;
    $self->{Verbose}   = 0;
    $self->{UserAgent} = undef;

    #$self->{PEERS}  = [];
    bless( $self, $class );    #Tells self that we are of class $class
    return $self;
}

=pod
Set/Get TWiki script url. 
=cut    

sub ScriptUrl {
    my $self = shift;
    if (@_) { $self->{ScriptUrl} = shift }
    return $self->{ScriptUrl};
}

=pod
Set/Get TWiki target Web. 
=cut        

sub Web {
    my $self = shift;
    if (@_) { $self->{Web} = shift }
    return $self->{Web};
}

=pod
Set/Get TWiki target topic. 
=cut        

sub Topic {
    my $self = shift;
    if (@_) { $self->{Topic} = shift }
    return $self->{Topic};
}

=pod
Set/Get TWiki user login. 
=cut        

sub User {
    my $self = shift;
    if (@_) { $self->{User} = shift; }
    return $self->{User};
}

=pod
Set/Get TWiki user password. 
=cut        

sub Password {
    my $self = shift;
    if (@_) { $self->{Password} = shift; }
    return $self->{Password};
}

=pod
Set/Get Verbose status. 
=cut    

sub Verbose {
    my $self = shift;
    if (@_) { $self->{Verbose} = shift }
    return $self->{Verbose};
}

=pod
Save a TWiki topic. 
If the topic existed it is modified otherwise a new topic is created. 
@param [IN] A hash reference containing the script URL parameters as per TWiki documentation.
@param [IN/OUT] A scalar reference containing a HTTP::Response object on return.
@return Returns 1 if success 0 if failure.
=cut

sub Save {
    my $self = shift;
    print "Saving..." if ( $self->Verbose );
    $self->Script( "save", @_ );
    my ( $paramref, $responseRef ) = @_;
    my $web   = $self->Web;
    my $topic = $self->Topic;

    #Do error check
    #Strip out the trailing Xs before checking for errors
    my $topicNoXs = $topic;
    if ( $topic =~ /(.*?)XXXXXXXXXX/ ) {
        $topicNoXs = $1;
    }

    if (   $$responseRef->is_redirect
        && $$responseRef->headers->header('Location') =~
        /view([\.\w]*)\/$web\/$topicNoXs/ )
    {

        #Success
        print "Done!\n" if ( $self->Verbose );    # To be removed
        return 1;
    }
    else {

        #Failure
        my $statusLine     = $$responseRef->status_line;
        my $stringResponse = $$responseRef->as_string;
        my $uriResponse    = $$responseRef->request->uri;
        print "Status line: $statusLine\n" if ( $self->Verbose );
        print "$stringResponse\n"          if ( $self->Verbose );
        print "Failed!\n"                  if ( $self->Verbose );
        return 0;
    }
}

=pod
View a TWiki topic. 
@param [IN] A hash reference containing the script URL parameters as per TWiki documentation.
@param [IN/OUT] A scalar reference containing a HTTP::Response object on return.
@return Returns 1 if success 0 if failure
=cut

sub View {
    my $self = shift;
    $self->Script( "view", @_ );
    my ( $paramref, $responseRef ) = @_;
    my $web   = $self->Web;
    my $topic = $self->Topic;

#TODO: Find a valid test to identify the case where the topic does not exists
# It seems like there is simply no way to tell whether or not a topic exist by looking at the view results (TWiki 4.1.2)
    if ( $$responseRef->is_success ) {

        #Success
        return 1;
    }
    else {

        #Failed
        #print "Failed!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
        return 0;
    }
}

=pod
Login to a TWiki web site using TWiki login mechanism (e.g TemplateLoginManager). 
@param [IN] A hash reference containing the script URL parameters as per TWiki documentation.
@param [IN/OUT] A scalar reference containing a HTTP::Response object on return.
@return Returns 1 if success 0 if failure
=cut

sub Login {
    my $self = shift;
    my ( $paramref, $responseRef ) = @_;
    my $baseUrl = $self->ScriptUrl;

    #Create our user agent and set credentials
    $self->CheckUserAgent();

    #Issue the request
    $self->Script( 'login', @_ );

    my $web   = $self->Web;
    my $topic = $self->Topic;

    #To validate our response we check:
    #   1: that we are dealing with a redirect (should really be 302)
    #   2: that the Location header contains the Web and Topic specified
    if (   $$responseRef->is_redirect
        && $$responseRef->header('Location') =~ /.*$web\/$topic.*/ )
    {

        #Success
        return 1;
    }
    else {

        #Failed
        #print "Failed!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
        $self->PrintResponse($responseRef);
        return 0;
    }
}

=pod
Execute a TWiki script from the script url. 
@param [IN] A scalar containing the name of the script to execute. (view/upload/save...)
@param [IN] A hash reference containing the script URL parameters as per TWiki documentation.
@param [IN/OUT] A scalar reference containing a HTTP::Response object on return.
@return nothing
=cut		

sub Script {
    my ( $self, $script, $paramref, $responseRef ) = @_;

    my $baseUrl = $self->ScriptUrl;
    my $web     = $self->Web;
    my $topic   = $self->Topic;

    #Some consistency check to enforce usage
    die "ScriptUrl not defined!" unless defined $baseUrl;
    die "Web not defined!"       unless defined $web;
    die "Topic not defined!"     unless defined $topic;

    #Create our user agent and set credentials
    $self->CheckUserAgent();

    #Issue the request
    $$responseRef =
      $self->{UserAgent}->post( "$baseUrl/$script/$web/$topic", $paramref );

    #No error check here
}

=pod
Attach a document to a TWiki topic. 
@param [IN] A hash reference containing the script URL parameters as per TWiki documentation.
@param [IN/OUT] A scalar reference containing a HTTP::Response object on return.
@return Returns 1 if success 0 if failure.
=cut		

sub Upload {

    #TODO: deal with zero size upload, search for zero_size_upload
    my $self = shift;
    my ( $paramref, $responseRef ) = @_;    #

    my $filepath    = "D:\\Dev\\Tools\\TWiki\\uploadthis.txt";
    my $filecomment = "A comment";

    my $web   = $self->Web;
    my $topic = $self->Topic;

    print "Uploading...\n" if ( $self->Verbose );

    #$self->Script("upload",@_);

    my $baseUrl = $self->ScriptUrl . '/upload';

    #Create our user agent and set credentials
    $self->CheckUserAgent();

    #Issue the request
    $$responseRef =
      $self->{UserAgent}->post( "$baseUrl/$web/$topic", $paramref,
        'Content_Type' => 'form-data' );

    my $stringResponse = $$responseRef->as_string;
    my $uriResponse    = $$responseRef->request->uri;

    #my $statusLine=$response->status_line;
    #print "Status line: $statusLine\n";

    if (   $$responseRef->is_redirect
        && $$responseRef->headers->header('Location') =~
        /view([\.\w]*)\/$web\/$topic/ )
    {

        #Success
        print "Done!\n" if ( $self->Verbose );
        return 1;
    }
    else {

        #Failure
        print "Can't upload. $uriResponse ; $stringResponse"
          if ( $self->Verbose );
        return 0;
    }

}

=pod
Read variables from a topic and put them into a hash
@param A hash reference
@return Returns 1 if success 0 if failure
=cut			

sub ReadVariables {
    my $self = shift;
    my ( $hashRef, $varKey ) = @_;
    my $response;

    $varKey = 'set' unless defined $varKey;

    #Get the raw text of the TWiki topic
    my %sriptParam = ( 'raw' => 'text' );
    my $res = $self->View( \%sriptParam, \$response );

    #Get the HTTP body of the response
    my $body = $response->content;

    #Split the body in lines
    my @body = split( /\n/, $body );

    my $line;

    #Search for TWiki variable for each line in the TWiki document
    foreach $line (@body) {

        #if ($line=~/^\s+\*\s+set\s+([\w]+)\s+=\s+([\w,:\-\.\s\\]*?)\s*$/i)
        if ( $line =~ /^\s+\*\s+$varKey\s+([\w]+)\s+=\s+(.*?)\s*$/i ) {
            my $var   = $1;
            my $value = $2;

            #Populate the hash with with variables from that document
            $hashRef->{"$var"} = $value;

            #print "$var = $value\n";
        }
    }

    return $res;
}

=pod
Read variables from a topic and put them into an array
@param [in/out] An array reference containing the variables upon return
@return Returns 1 if success 0 if failure
=cut			

sub ReadVariablesInOrder {
    my $self = shift;
    my ( $arrayRef, $varKey ) = @_;
    my $response;

    $varKey = 'set' unless defined $varKey;

    #Get the raw text of the TWiki topic
    my %sriptParam = ( 'raw' => 'text' );
    my $res = $self->View( \%sriptParam, \$response );

    #Get the HTTP body of the response
    my $body = $response->content;

    #Split the body in lines
    my @body = split( /\n/, $body );

    my $line;

    #Search for TWiki variable for each line in the TWiki document
    foreach $line (@body) {

#if ($line=~/^\s+\*\s+set\s+([\w]+)\s+=\s+([\w,:\-\@_:\.\s\\]*?)\s*$/i) #TODO: this regexp should be put in global for external use
        if ( $line =~ /^\s+\*\s+$varKey\s+([\w]+)\s+=\s+(.*?)\s*$/i ) {
            my $var   = $1;
            my $value = $2;

            #Populate the array with variables from that document
            push( @$arrayRef, $line );

            #print "$var = $value\n";
        }
    }

    return $res;
}

=pod
Do a search and parse the result to see if our topic exists
@return Returns 1 if the topic exists 0 if it doesn't
=cut				

sub Exists {
    my $self  = shift;
    my $web   = $self->Web;
    my $topic = $self->Topic;

    my %sriptParam = (
        'web'     => $web,
        'topic'   => $topic,
        'search'  => '*',
        'nonoise' => 'on',

#'scope' => 'topic', #TODO: log twiki bug for the search always giving result when using scope=topic and search=MyTopicName
        'format'   => '<searchres>$topic</searchres>',
        'nosearch' => 'on'
    );

    my $baseUrl = $self->ScriptUrl;

    #Create our user agent and set credentials
    $self->CheckUserAgent();

    #Issue the request
    my $response = $self->{UserAgent}->post( "$baseUrl/search", \%sriptParam );
    my $content = $response->content();

    #print $content;
    if ( $content =~ /<searchres>$topic<\/searchres>/g ) {
        return 1;
    }
    else {
        return 0;
    }
}

=pod
Download the given URL and returns whether or not it was a success.

@param The URL to test for.
@return true if success false otherwise
=cut		

sub UrlExists {
    my $self = shift;
    my $url  = shift;

    $self->CheckUserAgent();
    my $response = $self->{UserAgent}->get($url);
    return $response->is_success;
}

=pod
Append some text to a topic
@param The text to append to the topic
@return Returns 1 if success 0 if failure
=cut			

sub Append {
    my $self = shift;
    my ($text) = @_;
    my $response;

    #Get the raw text of the TWiki topic
    my %sriptParam = ( 'raw' => 'text' );
    my $res = $self->View( \%sriptParam, \$response );
    return $res unless ( $res == 1 );    #Stop here if error

    #Get the HTTP body of the response
    my $body = $response->content;

    #Check if the topic already exists
    #TODO: should improve that test really
    #Split the body in lines
    my @body = split( /\n/, $body );
    if ( defined $body[0]
        && $body[0] eq
        '---++ %MAKETEXT{"NOTE: This Wiki topic does not exist yet"}%' )

#if ($self->Exists) # We are having all sorts of problem with the exists function so we give up on that for now
    {

        #The topic does not exist yet so we are going to create it
        $body = $text;
    }
    else {

        #The topic already exist so we append the content
        $body .= $text;
    }

    %sriptParam = ( 'text' => "$body" );

    $res = $self->Save( \%sriptParam, \$response );
    return $res;
}

=pod
Make sure the user agent object was created.
=cut

sub CheckUserAgent {
    my $self = shift;
    unless ( defined $self->{UserAgent} ) {
        $self->{UserAgent} =
          Slion::TWiki::Client::UserAgent->new( $self->User, $self->Password );
        $self->{UserAgent}->{User}     = $self->User;
        $self->{UserAgent}->{Password} = $self->Password;

        #We need to create a cookie jar so that cookies are preserved
        #It's essential if you need to use TWiki template login
        $self->{UserAgent}->cookie_jar( {} );    #use temporary cookie jar
    }
}

=pod
Print the HTTP response if we are Verbose.
@param A reference to an HTTP::Response object
=cut

sub PrintResponse {
    my ( $self, $responseRef ) = @_;
    my $statusLine     = $$responseRef->status_line;
    my $stringResponse = $$responseRef->as_string;
    my $uriResponse    = $$responseRef->request->uri;
    print "Status line: $statusLine\n" if ( $self->Verbose );
    print "$stringResponse\n"          if ( $self->Verbose );
    print "Failed!\n"                  if ( $self->Verbose );
}

1;    #PERL stuff so that the package can be include using 'use' or 'require'
