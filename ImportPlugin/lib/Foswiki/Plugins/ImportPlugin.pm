# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::ImportPlugin;

use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version
use Error qw(:try);
use Foswiki::Time ();
use Foswiki::Plugins::WysiwygPlugin::HTML2TML;
use Foswiki::Plugins::ImportPlugin::SharepointHTML2TML;

#for importHtml
use Archive::Zip;
use Archive::Zip::MemberRead;

our $VERSION           = '$Rev$';
our $RELEASE           = '0.1.0';
our $SHORTDESCRIPTION  = 'Upload and import data to foswiki';
our $NO_PREFS_IN_TOPIC = 1;

our %webFull;
our $html2tml      = new Foswiki::Plugins::WysiwygPlugin::HTML2TML();
our $sharehtml2tml = new Foswiki::Plugins::ImportPlugin::SharepointHTML2TML();

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

*REQUIRED*

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using =Foswiki::Func::writeWarning= and return 0. In this case
%<nop>FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

__Note:__ Please align macro names with the Plugin name, e.g. if
your Plugin is called !FooBarPlugin, name macros FOOBAR and/or
FOOBARSOMETHING. This avoids namespace issues.

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Example code of how to get a preference value, register a macro
    # handler and register a RESTHandler (remove code you do not need)

    # Set your per-installation plugin configuration in LocalSite.cfg,
    # like this:
    # $Foswiki::cfg{Plugins}{ImportPlugin}{ExampleSetting} = 1;
    # See %SYSTEMWEB%.DevelopingPlugins#ConfigSpec for information
    # on integrating your plugin configuration with =configure=.

    # Always provide a default in case the setting is not defined in
    # LocalSite.cfg.
    # my $setting = $Foswiki::cfg{Plugins}{ImportPlugin}{ExampleSetting} || 0;

    # Register the _EXAMPLETAG function to handle %EXAMPLETAG{...}%
    # This will be called whenever %EXAMPLETAG% or %EXAMPLETAG{...}% is
    # seen in the topic text.
    Foswiki::Func::registerTagHandler( 'SHOWIMPORTFILE', \&SHOWIMPORTFILE );

    # Allow a sub to be called from the REST interface
    # using the provided alias
    Foswiki::Func::registerRESTHandler( 'importCsv',  \&importCsvFile );
    Foswiki::Func::registerRESTHandler( 'importHtml', \&importHtml );

    # Plugin correctly initialized
    return 1;
}

#attempts to show a representative portion of the import file.
#atm, csv only so shows 5 lines?
sub SHOWIMPORTFILE {
    my ( $session, $params, $topic, $web, $topicObject ) = @_;

    my $filename = $params->{_DEFAULT} || '';
    ( $web, $topic, $filename ) =
      Foswiki::Func::_checkWTA( $web, $topic, $filename );
    if ( defined($filename) ) {
        if ( $filename =~ /\.(tgz|zip|tag.gz|exe)$/ ) {    #binary?
            return "binary file..";
        }
        try {
            my $data = Foswiki::Func::readAttachment( $web, $topic, $filename );

            #just get the first few lines..
            my @lines = split( /\n/, $data );
            return
                "<verbatim>"
              . join( "\n", @lines[ 0 .. 5 ] )
              . "</verbatim>";
        }
        catch Foswiki::AccessControlException with {
            my $e = shift;
            print $e->stringify();
        };
    }
    return 'FILENAME error';

}

=begin TML

---++ importHtml($session) -> $text

=cut

sub catch_zap {
    my $signame = shift;
    die "Somebody sent me a SIG$signame\n";
}
$SIG{INT} = \&catch_zap;

#foreach my $k (keys(%SIG)) {
#    $SIG{$k} =         sub  {
#        my $signame = shift;
#        die "Somebody sent me a SIG$k\n";
#        }
#}

sub importHtml {
    my ( $session, $subject, $verb, $response ) = @_;

    my @error;

    my $query = $session->{request};
    my $outputweb = $query->{param}->{outputweb}[0] || 'SharepointWiki';

    #open the attachment
    my $type = lc(
        Foswiki::Sandbox::untaintUnchecked(
            $query->{param}->{fromtype}[0] || 'SharepointWiki'
        )
    );
    my $fromweb   = $query->{param}->{fromweb}[0]   || 'Sandbox';
    my $fromtopic = $query->{param}->{fromtopic}[0] || 'ImportPlugin019';
    my $fromattachment = $query->{param}->{fromattachment}[0]
      || 'GamingKnowledgeBaseWiki.zip';

    ( $fromweb, $fromtopic ) =
      Foswiki::Func::normalizeWebTopicName( $fromweb, $fromtopic );
    ( $fromweb, $fromtopic, $fromattachment ) =
      Foswiki::Func::_checkWTA( $fromweb, $fromtopic, $fromattachment );

    my $zipfilename = join( '/',
        ( $Foswiki::cfg{PubDir}, $fromweb, $fromtopic, $fromattachment ) );
    print STDERR "import from $zipfilename\n";

    #$zipfilename = '/home/sven/Downloads/Eloquent JavaScript.zip';

    my $zip          = Archive::Zip->new($zipfilename);
    my @members      = $zip->members();
    my $count        = 0;
    my $actual_count = 0;
    foreach my $member (@members) {
        my $file = $member->fileName();
        $actual_count++;

#DEBUG stop (do the firs 40 topics, with some revisions)
#last if (scalar(keys(%webFull)) > 20);
#last if ($count > 0);
#next unless ($file eq '1024___1.CONFIGURATION CHECKLIST.aspx');
#next unless ($file eq '512___Card Printer and Embosser.aspx');
#next unless ($file =~ /Technical/);
#next unless ($file eq '290816___Technical.aspx');      #this one has a span tag or combination that break html2tml
#next unless ($file eq '301056___Technical.aspx');

       #next unless ($member->fileName eq "Eloquent JavaScript/chapter6.html" );
        my ( $encoded_data, $status ) = $member->contents();

        #print STDERR $data;
        #die;
        #$member->extractToFileNamed( '/tmp/teteet' );

        #utf16le from windows causes us tissues
        use Encode::Guess;
        my $enc = guess_encoding(
            $encoded_data,

            #Encode->encodings(":all"));
            qw/utf16le utf8 ascii/
        );

        #qw/euc-jp shiftjis 7bit-jis/);
        my $data;
        if ( ref($enc) eq '' ) {
            print STDERR "++++++++++++++++++++++++ Can't guess: $enc"
              ;    # trap error this way
                   #last;
            use Encode;
            my $unicode = decode( 'UTF-8', $encoded_data );    #?
            $data = encode( 'unicode', $unicode );
        }
        else {

            #die join(', ', Encode->encodings(":all"));
            print STDERR "++++++++++++++++++++++++ Guessed Encoding as "
              . $enc->name . "\n";
            use Encode;
            my $unicode = decode( $enc->name, $encoded_data );    #'UTF-16LE'?
            $data = encode( 'unicode', $unicode );
        }

        next unless ( $file =~ /^(\d\d\d+)___(.*)\.(html|htm|aspx)$/ );
        my $rev       = $1;
        my $topicname = $2;
        my $ext       = $3;

#$member->rewindData();
#my ( $outRef, $status ) = $member->readChunk();
#die $$outRef if $status != Archive::Zip::AZ_OK && $status != Archive::Zip::AZ_STREAM_END;
#my $data = $$outRef;

        my %hash;
        $hash{web} = $outputweb;

        $topicname = simplfyTopicName($topicname);
        $hash{name} = $topicname;
        print STDERR scalar( keys(%webFull) ) . ' ('
          . $actual_count . ')'
          . ++$count . 'of'
          . scalar(@members)
          . "import $file "
          . $hash{name}
          . " ($status) ("
          . (Archive::Zip::AZ_OK)
          . ") - isTest="
          . $member->isTextFile()
          . " length: "
          . length($data) . "\n";

        my $tidinfo;
        if ( $data =~ m/^(Last modified at.*userdisp.aspx\?ID=\d*">.*?)<\/A>/i )
        {
            $tidinfo = $1;
        }
        else {
            if ( $data =~ m/(at.*?userdisp.aspx\?ID=\d*">.*?)<\/A>/i ) {
                $tidinfo = $1;
            }
            else {
                print STDERR 'OMG. ' . $file . "\n\n";
                push( @error, $file );
                next;
            }
        }

        print STDERR "--------$tidinfo\n";

        #(Created  at |Last modified at )
        $tidinfo =~ /(\d+)\/(\d\d)\/(\d\d\d\d) (\d+):(\d\d) ([AP]M)/;

        #$tidinfo =~ /Created(..........)/;
        $hash{'TOPICINFO.date'} = "$3/$2/$1 HOUR:$5";
        my $hour = ( $6 eq 'AM' ? $4 : $4 + 12 );
        if ( $4 eq '12' ) {
            if ( $6 eq 'AM' ) {
                $hour = 0;
            }
            else {
                $hour = 12;
            }
        }
        $hash{'TOPICINFO.date'} =~ s/HOUR/$hour/;

        #make TOPICINFO.date usable
        #$hash{'TOPICINFO.date'} =~ s/\.\d\d\d$//;
        print STDERR ".... date: " . $hash{'TOPICINFO.date'} . "\n";
        $hash{'TOPICINFO.date'} =
          Foswiki::Time::parseTime( $hash{'TOPICINFO.date'} );

        $tidinfo =~ /.*userdisp.aspx\?ID=\d*">(.*)$/;
        $hash{'TOPICINFO.author'} = $1;

#make a useable author
#$hash{'TOPICINFO.author'} =~ s/(.*)@.*/$1/; #remove domain - TODO: need to see what LdapContrib will do with for a cuid
        $hash{'TOPICINFO.author'} =~ s/\.//g;

        my $inverseFilter = $Foswiki::cfg{NameFilter};
        $inverseFilter =~ s/\[(.*)\^(.*)\]/[$2]/;

        $hash{'TOPICINFO.author'} =~ s/$inverseFilter//g;
        $hash{'TOPICINFO.author'} =~ s/[\.\/\s]//g;
        print STDERR ".... author: " . $hash{'TOPICINFO.author'} . "\n";

        print STDERR "trying to match\n";

        #narrow down the html we're going to import
        if ( $data =~ m/.*(<TABLE.*?Wiki Content.*?sip=".*?<\/TABLE>)/sim ) {

            #if ($data =~ m/(Wiki Content.*sip=")/ims) {
            $data = $1 . '</table></table>';
            print STDERR "......................match.......\n";

           #further tidying, want to add this info into Meta fields later though
            $data =~ s/(.*)(<!-- FieldName="Wiki Content")/$2/ms;
            my $preamble = $1;
            $data =~
s/(<\/td>\s*<\/tr>\s*<\/table>.*?"\/_layouts\/images\/blank.gif.*)$//msi;
            my $postamble = $1;
        }
        elsif ( $data =~
            m/.*(<TABLE.*Wiki Content.*(Created at|Modified at).*<\/TABLE>)/sim
          )
        {
            $data = $1 . '</table></table>';
            print STDERR "......................match.......\n";

           #further tidying, want to add this info into Meta fields later though
            $data =~ s/(.*)(<!-- FieldName="Wiki Content")/$2/ms;
            my $preamble = $1;
            $data =~
s/(<\/td>\s*<\/tr>\s*<\/table>.*?"\/_layouts\/images\/blank.gif.*)$//msi;
            my $postamble = $1;
        }
        else {
            print STDERR ".............. FAILED to match\n";
            push( @error, $file );
            next;
        }

#$data =~ s|<div( class=ExternalClass90EB474F1F684091AC987A1DC6C2015E)?>(<font face="Arial Black" size=2></font>)?(..?)</div>||g;
#my $squelsh = $3;
#$data =~ s|$squelsh||e;

#require HTML::Entities;
#    HTML::Entities::encode_entities( $data);#, HTML::Entities::decode_entities('&Acirc;') );
#die $data;
        print STDERR "tidy\n";
        use HTML::Tidy;
        my $tidy = HTML::Tidy->new();
        $hash{text} = $tidy->clean($data);

        print STDERR "html2tml\n";

        #$hash{text} =~ s/.*<body>//mis;
        #$hash{text} =~ s/<\/body>.*//mis;

#look for the common bits and remove?
#if ($hash{text} =~ /(<p>|<div|<a href|<h[1234567]>|<br \/>|&nbsp;)/i) {
#$hash{text} = $sharehtml2tml->convert( $hash{text}, { very_clean => 1 } );
#$hash{text} = $sharehtml2tml->{stackTop}->stringify();#something is going very wrong in the _generateRoot
#$html2tml->ignore_tags(qw/a img h2 b u p br div font span strong/);
#$html2tml->ignore_tags(qw/span/);
        $html2tml->ignore_tags(qw/font span/)
          ;    #span tag causes html2tml to infinite loop
        $hash{text} = $html2tml->convert( $hash{text}, { very_clean => 1 } );

        #}

#re-write sharepoint wiki url's
#/sites/maxgaming/cougarkb/Cougar Knowledge Base Wiki/Site Controller Install or Swapout.aspx
        $hash{text} =~
s|/sites/maxgaming/cougarkb/Cougar Knowledge Base Wiki/(.*?).aspx|simplfyTopicName($1)|ge;

#re-write remaining references to '/sites/maxgaming/cougarkb' with %COUGARURI% and set that in the WebPrefs for testing
#TODO: attach files that are found..
        $hash{text} =~
s|([['"])/sites/maxgaming/cougarkb/([^/]*?)/(.*)|$1.'%COUGARURI%'.simplfyTopicName($2).'/'.expandSharepointLink($3)|ge;

        #[/sites/maxgaming/cougarkb/Wiki Image Library/Kiosk Site Inventory.xls]

        #use the breadcrumbs someone added
        if ( $hash{text} =~
            s/^(.*\[\[.*\]\[.*\]\].*?)?(\[\[(.*)\]\[.*\]\])(.*?)\n// )
        {
            $hash{'TOPICPARENT.name'}    = $3;
            $hash{'preferences.parents'} = $1 . $2 . $4;
        }

        ###########################################################################
        #start to unravel some of the horrid markup
        #remove create new topic links
        $hash{text} =~ s/<a href="(.*?)CreateWebPage(.*?)<\/a>\s//g;

#bullet points within the link markup
#TODO: this would mean alot of testing and mucking.
#$hash{text} =~ s/^\[\[(.*?)\]\[(\d*)\.\s*(.*?)\]\](.*)$/   $2 [[$1][$3]]$4/gms;

        #$hash{text} =~ s/^\*\s/   * /gms;
        #end tweaking sharepoint output
        ###########################################################################

        $webFull{ $hash{name} } = ()
          if ( not defined( $webFull{ $hash{name} } ) );
        $webFull{ $hash{name} }{ $hash{'TOPICINFO.date'} } = \%hash;
        print STDERR "=-=-=-"
          . $hash{name}
          . "  ....   "
          . $hash{'TOPICINFO.date'} . "  :  "
          . $hash{'TOPICINFO.author'} . "\n";

    }
    print STDERR 'making web';
    my $data =
"\n#######################################################################\n"
      . "ok: \n"
      . writeWeb(
        $outputweb,
        {
            COUGARURI  => '%PUBURL%/images/',
            WEBBGCOLOR => '#AA2299',
            WEBSUMMARY => 'Cougar Wiki'
        }
      );

    $data =
"\n#######################################################################\n"
      . "ERRORS: -----------------------------------------------------------------\n"
      . join( "\n", @error ) . "\n\n"
      . $data
      if ( $#error > -1 );

    return $data;
}

sub expandSharepointLink {
    my $file = shift;

    $file =~ s/\/([^\/]*?)\.(png|gif|jpg)/\/_w\/$1_$2.jpg/;

    return $file;
}

sub simplfyTopicName {
    my $topic = shift;

    $topic =~ s/\d+\. //;    #remove a leading number?
    $topic =~ s/%20/ /g;     #remove escaped spaces

    my $inverseFilter = $Foswiki::cfg{NameFilter};
    $inverseFilter =~ s/\[(.*)\^(.*)\]/[$2]/;

    #make a useable Topic name
    $topic =~ s/$inverseFilter//g;
    $topic =~ s/[\.\/]//g;                     #just remove dots and slashes
    $topic =~ s/([A-Z_]*)/ucfirst(lc($1))/ge
      ;    #if its all caps and spaces, lowercase it so we're not shouting
     #convert all underscores to spaces then remove them after capitalising all letters after a space..
    $topic =~ s/[\s_]+(\w)/uc($1)/ge;
    $topic =~ s/^(\w)/uc($1)/e;
    $topic =~ s/[\?_\s()]//g;

    return $topic;
}

=begin TML

---++ importCsvFile($session) -> $text

=cut

my %regex_map = (
    html_invalid => '(.*?)',
    html         => '([^,]*)',
    text_invalid => '(.*?)',
    text         => '([^,]*)',
    datetime     => '([^,]*)',

    #    int => '([-.0123456789]]*|NULL)'
    int => '(\d*|NULL)'
);

sub importCsvFile {
    my ( $session, $subject, $verb, $response ) = @_;

    my $query           = $session->{request};
    my $outputelements  = $query->{param}->{outputelements}[0];
    my $separator       = $query->{param}->{separator}[0];
    my $invalidelements = $query->{param}->{invalidelements}[0];
    my $outputweb       = $query->{param}->{outputweb}[0];
    my $importplugin    = $query->{param}->{importplugin}[0];

    #use the importtypes to make a regex
    my $inputelements_param = lc(
        Foswiki::Sandbox::untaintUnchecked(
            $query->{param}->{inputelments}[0]
        )
    );
    my @inputelements = split( /\r?\n/, $inputelements_param );
    my $invalidelements_param = lc(
        Foswiki::Sandbox::untaintUnchecked(
            $query->{param}->{invalidelements}[0]
        )
    );
    my %invalidelements;
    map { $invalidelements{$_} = 1; } split( /\r?\n/, $invalidelements_param );
    my $outputelements_param = Foswiki::Sandbox::untaintUnchecked(
        $query->{param}->{outputelements}[0] );
    my @outputelements = split( /\r?\n/, $outputelements_param );

    my $elementtypes_param =
      Foswiki::Sandbox::untaintUnchecked( $query->{param}->{elementtypes}[0] );
    my @elementtypes = split( /\r?\n/, $elementtypes_param );

    my @regex;
    for ( my $i = 0 ; $i < $#inputelements ; $i++ ) {
        if ( defined( $invalidelements{ lc( $inputelements[$i] ) } ) ) {
            $elementtypes[$i] .= '_invalid';
        }

        if ( defined( $regex_map{ lc( $elementtypes[$i] ) } ) ) {
            push( @regex, $regex_map{ $elementtypes[$i] } );
        }
        elsif ( $elementtypes[$i] =~ /^char\((\d+)\)$/i ) {
            push( @regex, '([^,]{' . $1 . '})' );
        }
        else {

            #presume that the user has handcrafted a regex.
            push( @regex, $elementtypes[$i] );
        }
    }
    my $regex_str = join( ',', @regex );

    #    return "Import ".join(', ', @inputelements)."<br />\n".
    #        "as ".join(', ', @elementtypes)."<br />\n".
    #        "to ".join(', ', @outputelements)."<br />\n".
    #        "with pain ".join(', ', keys(%invalidelements))."<br />\n".
    #        "<br />$regex<br/\n\n>".$data;

    #open the attachment
    my $type = lc(
        Foswiki::Sandbox::untaintUnchecked( $query->{param}->{fromtype}[0] ) );
    my $fromweb        = $query->{param}->{fromweb}[0];
    my $fromtopic      = $query->{param}->{fromtopic}[0];
    my $fromattachment = $query->{param}->{fromattachment}[0];

    ( $fromweb, $fromtopic ) =
      Foswiki::Func::normalizeWebTopicName( $fromweb, $fromtopic );
    ( $fromweb, $fromtopic, $fromattachment ) =
      Foswiki::Func::_checkWTA( $fromweb, $fromtopic, $fromattachment );

    my $data = '';

#    use Foswiki::AccessControlException;
#    try {
#        $data = Foswiki::Func::readAttachment($fromweb, $fromtopic, $fromattachment);
#        use Encode 'is_utf8';
#        print STDERR "--------------------is_utf8: ".(is_utf8($data) ? 1 : 0)."\n";
#        die "--------------------is_utf8: ".(is_utf8($data) ? 1 : 0)."\n";;
#    } catch Foswiki::AccessControlException with {
#        my $e = shift;
#       return 'boomy '.$e;
#    };
    my $topicObject =
      Foswiki::Meta->new( $Foswiki::Plugins::SESSION, $fromweb, $fromtopic );
    unless ( $topicObject->haveAccess('VIEW') ) {
        throw Foswiki::AccessControlException( 'VIEW',
            $Foswiki::Plugins::SESSION->{user},
            $fromweb, $fromtopic, $Foswiki::Meta::reason );
    }

    try {

#TODO: yup, can't do this either. Foswiki protects me from doing useful code.
#my $fh = $topicObject->openAttachment( $fromattachment, '<:raw:encoding(UTF16-LE):crlf:utf8', version => undef );
#TODO: argh, huge nasty presumption, no point being clean, the entire thing is now afreaking hack.
        my $file = join( '/',
            ( $Foswiki::cfg{PubDir}, $fromweb, $fromtopic, $fromattachment ) );

        #open(my $fh, '<:raw:encoding(UTF16-LE):crlf:utf8', $file );
        open( my $fh, '<', $file );
        local $/;
        $data = <$fh>;
    }
    catch Error::Simple with {
        my $e = shift;
        return 'boomy ' . $e;
    };

    #I'm going to simplify, cos i've run out of time.
    #presume that the first element is easy to identify and split on that.
    my $firstelem = $regex[0] . ',';
    $firstelem = qr/$firstelem/;

    #$data =~ s/\r\n/\n/;
    #$data = "\n".$data;

#EE04D302-00F3-1F8D-A3CDC239FC957A6B,
#my @testdata = split(/([0123456789ABCDEF]{8}-[0123456789ABCDEF]{4}-[0123456789ABCDEF]{4}-[0123456789ABCDEF]{16})/, $data);
#my @testdata = split(/([^,]{35}),/m, $data);
#my @testdata = split(/$/m, $data);
#my @testdata = split(/([A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{16}),/, $data);
    my @testdata = split( $firstelem, $data );
    if ( $#testdata > 0 ) {
        $data =
            'count: '
          . $#testdata
          . '<br /><br />' . "\n\n"
          . 'regex: '
          . $regex_str
          . '<br /><br />' . "\n\n"
          .

          #        $testdata[1].'<br /><br />'."\n\n".
          #        $testdata[3].'<br /><br />'."\n\n".
          #        $testdata[5].'<br /><br />'."\n\n".
          #        $testdata[7].'<br /><br />'."\n\n".
          #        $testdata[9].'<br /><br />'."\n\n".
          #        $testdata[11].'<br /><br />'."\n\n".
          '<br /><br />' . "--------<br /><br />\n";

        my $dud = 0;
        for ( my $i = 1 ; $i < $#testdata ; $i += 2 ) {

            #        for (my $i=1;$i<20;$i+=2) {
            my $line = $testdata[$i] . ',' . $testdata[ $i + 1 ];
            my @match = $line =~ /^$regex_str$/s;
            if ( $#match > 0 ) {
                my $topicversion =
                  addToTopics( $outputweb, \@outputelements, \@match );
                $data =
                  $data . ' ++++ ' . $topicversion . '<br /><br />' . "\n\n";
            }
            else {
                $data =
                  $data . ' ---- ' . $testdata[$i] . '<br /><br />' . "\n\n";
                $dud++;

                #remove up to the invalid field.
                my $comma = '';
                foreach my $reg (@regex) {
                    last if ( $reg =~ /\?/ );
                    if ( $line =~ s/$comma$reg//s ) {
                        $comma = ',';
                        $data =
                            $data
                          . ' MATCHED '
                          . $reg
                          . '<br /><br />' . "\n\n"
                          . "\n\n??"
                          . $1
                          . '<br /><br />' . "\n\n";
                    }
                    else {
                        $data =
                            $data
                          . ' FAILED to match '
                          . $reg
                          . '<br /><br />'
                          . "\n\n??"
                          . $line
                          . '<br /><br />' . "\n\n";
                    }
                }
                $data =
                    $data
                  . ' bump in the night >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> <br /><br />'
                  . "\n\n";

                #remove up to the invalid field.
                foreach my $reg ( reverse @regex ) {
                    last if ( $reg =~ /\?/ );
                    if ( $line =~ s/$comma$reg$//s ) {
                        $comma = ',';
                        $data =
                            $data
                          . ' MATCHED '
                          . $reg
                          . '<br /><br />' . "\n\n"
                          . "\n\n??"
                          . $1
                          . '<br /><br />' . "\n\n";
                    }
                    else {
                        $data =
                            $data
                          . ' FAILED to match '
                          . $reg
                          . '<br /><br />'
                          . "\n\n??"
                          . $line
                          . '<br /><br />' . "\n\n";
                    }
                }

            }
        }
        $data =
          $data . "DUD: $dud out of " . ( $#testdata / 2 ) . "<br /><br />\n\n";

        $data = $data . writeWeb($outputweb);

    }
    else {

        #$data = 'no match';
        $data =~ /(.......................................)/;
        $data = length($data) . ' (failed)  :  ' . $1;
    }

    return
        "Import $type file "
      . join( '/', ( $fromweb, $fromtopic, $fromattachment ) )
      . " \n<br /><br />$data";
}

sub writeWeb {
    my $orig_outputweb = shift;
    my $options        = shift;

    #need to create a new
    my $web_suffix = 1;
    my $outputweb  = $orig_outputweb;
    while ( Foswiki::Func::webExists($outputweb) ) {
        $outputweb = $orig_outputweb . $web_suffix++;
    }
    try {
        Foswiki::Func::createWeb( $outputweb, '_default', $options );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;

        # see documentation on Foswiki::AccessControlException
    }
    catch Error::Simple with {
        my $e = shift;

        # see documentation on Error::Simple
    }
    otherwise {

        #...
    };
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $outputweb, 'WebPreferences' );
    foreach my $key ( keys(%$options) ) {

        #TODO: because the createWeb doesn't do what the docco says
        setField( $meta, 'preferences.' . $key, $options->{$key} );
    }
    Foswiki::Func::saveTopic( $meta->web, $meta->topic, $meta, $meta->text );

    my $data =
"into $outputweb - <a href='http://quad7/~sven/core/bin/view/$outputweb/WebIndex'>WebIndex</a><br />\n";

    #and now use the %webFull hash to make topics without losing our revisions
    foreach my $t ( keys(%webFull) ) {
        print STDERR $t;
        $data =
            $data
          . ' ++++ <a href="http://quad7/~sven/core/bin/view/'
          . $outputweb . '/'
          . $t . '">'
          . $t
          . '</a> @@ ';

        foreach my $rev ( sort keys( %{ $webFull{$t} } ) ) {
            my $hash = $webFull{$t}{$rev};
            $data = $data . $hash->{'TOPICINFO.date'} . ' ';
            $hash->{web} = $outputweb;

            my ( $meta, $text );
            if ( Foswiki::Func::topicExists( $outputweb, $t ) ) {
                ( $meta, $text ) = Foswiki::Func::readTopic( $outputweb, $t );
            }
            else {

#if the topic doesn't exist, we can either leave $meta undefined
#or if we need to set more than just the topic text, we create a new Meta object and use it.
                $meta =
                  new Foswiki::Meta( $Foswiki::Plugins::SESSION, $outputweb,
                    $t );
                $text = '';
            }
            foreach my $k ( keys(%$hash) ) {

                #just like query search getField.
                setField( $meta, $k, $hash->{$k} );
            }
            try {
                Foswiki::Func::saveTopic(
                    $meta->web,
                    $meta->topic,
                    $meta,
                    $meta->text,
                    {
                        forcenewrevision => 1,
                        forcedate        => $hash->{'TOPICINFO.date'},
                        author           => $hash->{'TOPICINFO.author'}
                    }
                );

                #$data = $data.' ok <br />'."\n";
            }
            otherwise {
                my $e = shift;
                print STDERR "Error saving ("
                  . $meta->topic
                  . "), trying again without forcedate."
                  . ( defined($e) ? $e->stringify() : '' );
                Foswiki::Func::saveTopic(
                    $meta->web,
                    $meta->topic,
                    $meta,
                    $meta->text,
                    {
                        forcenewrevision => 1,
                        author           => $hash->{'TOPICINFO.author'}
                    }
                );
            };

        }
        $data = $data . " <br />\n";
    }
    return $data;
}

#($meta, $k, $hash->{$k}});
#this is/should be the inverse of QuerySearch's getField
sub setField {
    my $meta  = shift;
    my $name  = shift;
    my $value = shift;

    return if ( ( not defined($value) ) or $value eq 'NULL' or $value eq '' );

    if ( $name eq 'name' ) {
        $meta->topic($value);
    }
    elsif ( $name eq 'web' ) {
        $meta->web($value);
    }
    elsif ( $name eq 'text' ) {
        $meta->text($value);
    }
    elsif ( $name =~ /^TOPICINFO\.(.*)$/ ) {

        #        $meta->putKeyed( 'TOPICINFO',
        #            { name => $1, value =>$value } );
    }
    elsif ( $name =~ /^TOPICPARENT\.(.*)$/ ) {
        $meta->putKeyed( 'TOPICPARENT', { name => $value } );
    }
    elsif ( $name =~ /^preferences\.(.*)$/ ) {
        $meta->putKeyed( 'PREFERENCE', { name => $1, value => $value } );
    }
    elsif ( $name =~ /^field\.(.*)$/ ) {
        $meta->putKeyed( 'FIELD',
            { name => $1, title => $1, value => $value } );
    }
    elsif ( $name =~ /^attachments\.(.*)$/ ) {
        die $name . ' of surprise ' . $value if ( $value ne '' );
    }
    else {

        #meh.
        die $name . ' of coniptions ' . $value if ( $value ne '' );
    }
}

#CanvasWiki..
sub addToTopics {
    my $web    = shift;
    my $fields = shift;
    my $info   = shift;

    my %hash;
    @hash{@$fields} = @$info;
    $hash{web} = $web;

    return 'WARNING: ignoring attachment '
      . $hash{'attachments.name'}
      if (
        defined( $hash{'attachments.name'} )
        and not( $hash{'attachments.name'} eq ''
            or $hash{'attachments.name'} eq 'NULL' )
      );

    my $inverseFilter = $Foswiki::cfg{NameFilter};
    $inverseFilter =~ s/\[(.*)\^(.*)\]/[$2]/;

    #make a useable Topic name
    $hash{name} =~ s/$inverseFilter//g;
    $hash{name} =~ s/[\.\/]//g;

#convert all underscores to spaces then remove them after capitalising all letters after a space..
    $hash{name} =~ s/[\s_]+(\w)/uc($1)/ge;
    $hash{name} =~ s/^(\w)/uc($1)/e;
    $hash{name} =~ s/\?//g;
    $hash{name} =~ s/_//g;

    #make a useable author
    $hash{'TOPICINFO.author'} =~ s/$inverseFilter//g;
    $hash{'TOPICINFO.author'} =~ s/[\.\/\s]//g;

    #make TOPICINFO.date usable
    $hash{'TOPICINFO.date'} =~ s/\.\d\d\d$//;
    $hash{'TOPICINFO.date'} =
      Foswiki::Time::parseTime( $hash{'TOPICINFO.date'} );

    #convert html2tml
    #$hash{'preferences.HTML'} = $hash{text};
    #oh crap, these topics are not just html.
    $hash{text} =~ s/\r\n/\n/gms;
    $hash{text} =~ s/\[\[(.*?)\|(.*?)\]\]/[[$1][$2]]/gms;
    $hash{text} =~ s/^\*\*\*/         * /gms;
    $hash{text} =~ s/^\*\*/      * /gms;
    $hash{text} =~ s/^\*/   * /gms;
    $hash{text} =~ s/^# /   1 /gms;
    $hash{text} =~ s/^## /      1 /gms;
    $hash{text} =~ s/'''(.*?)'''/*$1*/gms;
    $hash{text} =~ s/\[sup\]/<sup>/gms;
    $hash{text} =~ s/\[\/sup\]/<\/sup>/gms;

    #$hash{text} =~ s///gms;

    if ( $hash{text} =~ /(<p>|<div|<a href|<h[1234567]>|<br \/>|&nbsp;)/i ) {
        $hash{text} = $html2tml->convert( $hash{text}, { very_clean => 1 } );
    }

    $webFull{ $hash{name} } = () if ( not defined( $webFull{ $hash{name} } ) );
    $webFull{ $hash{name} }{ $hash{'TOPICINFO.date'} } = \%hash;

    return
        $web . '.'
      . $hash{name} . '@@'
      . $hash{'TOPICINFO.date'} . ' by '
      . $webFull{ $hash{name} }{ $hash{'TOPICINFO.date'} }
      ->{'TOPICINFO.author'};

}

=begin TML

---++ earlyInitPlugin()

This handler is called before any other handler, and before it has been
determined if the plugin is enabled or not. Use it with great care!

If it returns a non-null error string, the plugin will be disabled.

=cut

sub earlyInitPlugin {
    my $session = $Foswiki::Plugins::SESSION;
    my $query   = $session->{request};

    my $web   = $query->{param}->{web}[0];
    my $topic = $query->{param}->{topic}[0];
    ( $web, $topic ) = Foswiki::Func::_checkWTA( $web, $topic );

    my $importFrom = $query->{param}->{importFrom}[0] || '';
    $importFrom =~ /(CanvasWiki|SharepointWiki)/;
    $importFrom = $1;

    my $importplugin = $query->{param}->{importplugin}[0] || '';
    if ( $importplugin eq 'step1' ) {

        #over-ride the attachment max size
        if ( Foswiki::Func::isAnAdmin() ) {
            Foswiki::Func::setPreferencesValue( 'ATTACHFILESIZELIMIT', 0 );
        }

        #if the topic doesn't exist, create it.
        if (   ( not Foswiki::Func::topicExists( $web, $topic ) )
            or ( $topic =~ /AUTOINC(\d+)/ )
            or ( $topic =~ /X{10}/ ) )
        {

            #create with the right view template?
            use Error qw( :try );
            use Foswiki::UI::Save;
            my $formtemplateparam = $query->{param}->{formtemplate}[0]
              || 'ImportPluginTopicForm';
            my ( $formtemplateweb, $formtemplatetopic ) =
              Foswiki::Func::normalizeWebTopicName( 'System',
                $formtemplateparam );
            my ( $meta, $formtext ) =
              Foswiki::Func::readTopic( $formtemplateweb, $formtemplatetopic );

            my $templatetopicparam = $query->{param}->{templatetopic}[0]
              || 'ImportPluginTopicTemplate';
            my ( $templateweb, $templatetopic ) =
              Foswiki::Func::normalizeWebTopicName( 'System',
                $templatetopicparam );
            my ( $templatemeta, $text ) =
              Foswiki::Func::readTopic( $templateweb, $templatetopic );

            $meta->text($text);
            $meta->putKeyed(
                'FIELD',
                {
                    name  => 'importFrom',
                    title => 'importFrom',
                    value => $importFrom
                }
            );

    #   * Set VIEW_TEMPLATE=System.ImportPlugin%QUERY{"importFrom"}%ViewTemplate
            $meta->putKeyed(
                'PREFERENCE',
                {
                    name  => 'VIEW_TEMPLATE',
                    value => 'System.ImportPlugin'
                      . $importFrom
                      . 'ViewTemplate'
                }
            );

            #obey AUTOINC and XXXXX
            $topic = Foswiki::UI::Save::expandAUTOINC( $session, $web, $topic );
            $query->{param}->{topic}[0] = $topic;

            #change the 'requested topic so we upload to the new one.
            $Foswiki::Plugins::SESSION->{webName}   = $web;
            $Foswiki::Plugins::SESSION->{topicName} = $topic;

            try {
                Foswiki::Func::saveTopic( $web, $topic, $meta, $text );
            }
            catch Foswiki::AccessControlException with {
                my $e = shift;

                # see documentation on Foswiki::AccessControlException
            }
            catch Error::Simple with {
                my $e = shift;

                # see documentation on Error::Simple
            }
            otherwise {

                #                ...
            };
        }
    }

    return undef;
}

=begin TML

---++ initializeUserHandler( $loginName, $url, $pathInfo )
   * =$loginName= - login name recovered from $ENV{REMOTE_USER}
   * =$url= - request url
   * =$pathInfo= - pathinfo from the CGI query
Allows a plugin to set the username. Normally Foswiki gets the username
from the login manager. This handler gives you a chance to override the
login manager.

Return the *login* name.

This handler is called very early, immediately after =earlyInitPlugin=.

*Since:* Foswiki::Plugins::VERSION = '2.0'

=cut

#sub initializeUserHandler {
#    my ( $loginName, $url, $pathInfo ) = @_;
#}

=begin TML

---++ finishPlugin()

Called when Foswiki is shutting down, this handler can be used by the plugin
to release resources - for example, shut down open database connections,
release allocated memory etc.

Note that it's important to break any cycles in memory allocated by plugins,
or that memory will be lost when Foswiki is run in a persistent context
e.g. mod_perl.

=cut

#sub finishPlugin {
#}

=begin TML

---++ registrationHandler($web, $wikiName, $loginName, $data )
   * =$web= - the name of the web in the current CGI query
   * =$wikiName= - users wiki name
   * =$loginName= - users login name
   * =$data= - a hashref containing all the formfields POSTed to the registration script

Called when a new user registers with this Foswiki.

Note that the handler is not called when the user submits the registration
form if {Register}{NeedVerification} is enabled. It is then called when
the user submits the activation code.

*Since:* Foswiki::Plugins::VERSION = '2.0'

=cut

#sub registrationHandler {
#    my ( $web, $wikiName, $loginName, $data ) = @_;
#}

=begin TML

---++ commonTagsHandler($text, $topic, $web, $included, $meta )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$included= - Boolean flag indicating whether the handler is
     invoked on an included topic
   * =$meta= - meta-data object for the topic MAY BE =undef=
This handler is called by the code that expands %<nop>MACROS% syntax in
the topic body and in form fields. It may be called many times while
a topic is being rendered.

Only plugins that have to parse the entire topic content should implement
this function. For expanding macros with trivial syntax it is *far* more
efficient to use =Foswiki::Func::registerTagHandler= (see =initPlugin=).

Internal Foswiki macros, (and any macros declared using
=Foswiki::Func::registerTagHandler=) are expanded _before_, and then again
_after_, this function is called to ensure all %<nop>MACROS% are expanded.

*NOTE:* when this handler is called, &lt;verbatim> blocks have been
removed from the text (though all other blocks such as &lt;pre> and
&lt;noautolink> are still present).

*NOTE:* meta-data is _not_ embedded in the text passed to this
handler. Use the =$meta= object.

*NOTE:* Read the developer supplement at
Foswiki:Development.AddToZoneFromPluginHandlers if you are calling
=addToZone()= from this handler

*Since:* $Foswiki::Plugins::VERSION 2.0

=cut

#sub commonTagsHandler {
#    my ( $text, $topic, $web, $included, $meta ) = @_;
#
#    # If you don't want to be called from nested includes...
#    #   if( $included ) {
#    #         # bail out, handler called from an %INCLUDE{}%
#    #         return;
#    #   }
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ beforeCommonTagsHandler($text, $topic, $web, $meta )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - meta-data object for the topic MAY BE =undef=
This handler is called before Foswiki does any expansion of its own
internal variables. It is designed for use by cache plugins. Note that
when this handler is called, &lt;verbatim> blocks are still present
in the text.

*NOTE*: This handler is called once for each call to
=commonTagsHandler= i.e. it may be called many times during the
rendering of a topic.

*NOTE:* meta-data is _not_ embedded in the text passed to this
handler.

*NOTE:* This handler is not separately called on included topics.

*NOTE:* Read the developer supplement at
Foswiki:Development.AddToZoneFromPluginHandlers if you are calling
=addToZone()= from this handler

=cut

#sub beforeCommonTagsHandler {
#    my ( $text, $topic, $web, $meta ) = @_;
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ afterCommonTagsHandler($text, $topic, $web, $meta )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - meta-data object for the topic MAY BE =undef=
This handler is called after Foswiki has completed expansion of %MACROS%.
It is designed for use by cache plugins. Note that when this handler
is called, &lt;verbatim> blocks are present in the text.

*NOTE*: This handler is called once for each call to
=commonTagsHandler= i.e. it may be called many times during the
rendering of a topic.

*NOTE:* meta-data is _not_ embedded in the text passed to this
handler.

*NOTE:* Read the developer supplement at
Foswiki:Development.AddToZoneFromPluginHandlers if you are calling
=addToZone()= from this handler

=cut

#sub afterCommonTagsHandler {
#    my ( $text, $topic, $web, $meta ) = @_;
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ preRenderingHandler( $text, \%map )
   * =$text= - text, with the head, verbatim and pre blocks replaced
     with placeholders
   * =\%removed= - reference to a hash that maps the placeholders to
     the removed blocks.

Handler called immediately before Foswiki syntax structures (such as lists) are
processed, but after all variables have been expanded. Use this handler to
process special syntax only recognised by your plugin.

Placeholders are text strings constructed using the tag name and a
sequence number e.g. 'pre1', "verbatim6", "head1" etc. Placeholders are
inserted into the text inside &lt;!--!marker!--&gt; characters so the
text will contain &lt;!--!pre1!--&gt; for placeholder pre1.

Each removed block is represented by the block text and the parameters
passed to the tag (usually empty) e.g. for
<verbatim>
<pre class='slobadob'>
XYZ
</pre>
</verbatim>
the map will contain:
<pre>
$removed->{'pre1'}{text}:   XYZ
$removed->{'pre1'}{params}: class="slobadob"
</pre>
Iterating over blocks for a single tag is easy. For example, to prepend a
line number to every line of every pre block you might use this code:
<verbatim>
foreach my $placeholder ( keys %$map ) {
    if( $placeholder =~ /^pre/i ) {
        my $n = 1;
        $map->{$placeholder}{text} =~ s/^/$n++/gem;
    }
}
</verbatim>

__NOTE__: This handler is called once for each rendered block of text i.e.
it may be called several times during the rendering of a topic.

*NOTE:* meta-data is _not_ embedded in the text passed to this
handler.

*NOTE:* Read the developer supplement at
Foswiki:Development.AddToZoneFromPluginHandlers if you are calling
=addToZone()= from this handler

Since Foswiki::Plugins::VERSION = '2.0'

=cut

#sub preRenderingHandler {
#    my( $text, $pMap ) = @_;
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ postRenderingHandler( $text )
   * =$text= - the text that has just been rendered. May be modified in place.

*NOTE*: This handler is called once for each rendered block of text i.e. 
it may be called several times during the rendering of a topic.

*NOTE:* meta-data is _not_ embedded in the text passed to this
handler.

*NOTE:* Read the developer supplement at
Foswiki:Development.AddToZoneFromPluginHandlers if you are calling
=addToZone()= from this handler

Since Foswiki::Plugins::VERSION = '2.0'

=cut

#sub postRenderingHandler {
#    my $text = shift;
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ beforeEditHandler($text, $topic, $web )
   * =$text= - text that will be edited
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called by the edit script just before presenting the edit text
in the edit box. It is called once when the =edit= script is run.

*NOTE*: meta-data may be embedded in the text passed to this handler 
(using %META: tags)

*Since:* Foswiki::Plugins::VERSION = '2.0'

=cut

#sub beforeEditHandler {
#    my ( $text, $topic, $web ) = @_;
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ afterEditHandler($text, $topic, $web, $meta )
   * =$text= - text that is being previewed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - meta-data for the topic.
This handler is called by the preview script just before presenting the text.
It is called once when the =preview= script is run.

*NOTE:* this handler is _not_ called unless the text is previewed.

*NOTE:* meta-data is _not_ embedded in the text passed to this
handler. Use the =$meta= object.

*Since:* $Foswiki::Plugins::VERSION 2.0

=cut

#sub afterEditHandler {
#    my ( $text, $topic, $web ) = @_;
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ beforeSaveHandler($text, $topic, $web, $meta )
   * =$text= - text _with embedded meta-data tags_
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - the metadata of the topic being saved, represented by a Foswiki::Meta object.

This handler is called each time a topic is saved.

*NOTE:* meta-data is embedded in =$text= (using %META: tags). If you modify
the =$meta= object, then it will override any changes to the meta-data
embedded in the text. Modify *either* the META in the text *or* the =$meta=
object, never both. You are recommended to modify the =$meta= object rather
than the text, as this approach is proof against changes in the embedded
text format.

*Since:* Foswiki::Plugins::VERSION = 2.0

=cut

#sub beforeSaveHandler {
#    my ( $text, $topic, $web ) = @_;
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ afterSaveHandler($text, $topic, $web, $error, $meta )
   * =$text= - the text of the topic _excluding meta-data tags_
     (see beforeSaveHandler)
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$error= - any error string returned by the save.
   * =$meta= - the metadata of the saved topic, represented by a Foswiki::Meta object 

This handler is called each time a topic is saved.

*NOTE:* meta-data is embedded in $text (using %META: tags)

*Since:* Foswiki::Plugins::VERSION 2.0

=cut

#sub afterSaveHandler {
#    my ( $text, $topic, $web, $error, $meta ) = @_;
#
#    # You can work on $text in place by using the special perl
#    # variable $_[0]. These allow you to operate on $text
#    # as if it was passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ afterRenameHandler( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment )

   * =$oldWeb= - name of old web
   * =$oldTopic= - name of old topic (empty string if web rename)
   * =$oldAttachment= - name of old attachment (empty string if web or topic rename)
   * =$newWeb= - name of new web
   * =$newTopic= - name of new topic (empty string if web rename)
   * =$newAttachment= - name of new attachment (empty string if web or topic rename)

This handler is called just after the rename/move/delete action of a web, topic or attachment.

*Since:* Foswiki::Plugins::VERSION = '2.0'

=cut

#sub afterRenameHandler {
#    my ( $oldWeb, $oldTopic, $oldAttachment,
#         $newWeb, $newTopic, $newAttachment ) = @_;
#}

=begin TML

---++ beforeUploadHandler(\%attrHash, $meta )
   * =\%attrHash= - reference to hash of attachment attribute values
   * =$meta= - the Foswiki::Meta object where the upload will happen

This handler is called once when an attachment is uploaded. When this
handler is called, the attachment has *not* been recorded in the database.

The attributes hash will include at least the following attributes:
   * =attachment= => the attachment name - must not be modified
   * =user= - the user id - must not be modified
   * =comment= - the comment - may be modified
   * =stream= - an input stream that will deliver the data for the
     attachment. The stream can be assumed to be seekable, and the file
     pointer will be positioned at the start. It is *not* necessary to
     reset the file pointer to the start of the stream after you are
     done, nor is it necessary to close the stream.

The handler may wish to replace the original data served by the stream
with new data. In this case, the handler can set the ={stream}= to a
new stream.

For example:
<verbatim>
sub beforeUploadHandler {
    my ( $attrs, $meta ) = @_;
    my $fh = $attrs->{stream};
    local $/;
    # read the whole stream
    my $text = <$fh>;
    # Modify the content
    $text =~ s/investment bank/den of thieves/gi;
    $fh = new File::Temp();
    print $fh $text;
    $attrs->{stream} = $fh;

}
</verbatim>

*Since:* Foswiki::Plugins::VERSION = 2.1

=cut

#sub beforeUploadHandler {
#    my( $attrHashRef, $topic, $web ) = @_;
#}

=begin TML

---++ afterUploadHandler(\%attrHash, $meta )
   * =\%attrHash= - reference to hash of attachment attribute values
   * =$meta= - a Foswiki::Meta  object where the upload has happened

This handler is called just after the after the attachment
meta-data in the topic has been saved. The attributes hash
will include at least the following attributes, all of which are read-only:
   * =attachment= => the attachment name
   * =comment= - the comment
   * =user= - the user id

*Since:* Foswiki::Plugins::VERSION = 2.1

=cut

#sub afterUploadHandler {
#    my( $attrHashRef, $meta ) = @_;
#}

=begin TML

---++ mergeHandler( $diff, $old, $new, \%info ) -> $text
Try to resolve a difference encountered during merge. The =differences= 
array is an array of hash references, where each hash contains the 
following fields:
   * =$diff= => one of the characters '+', '-', 'c' or ' '.
      * '+' - =new= contains text inserted in the new version
      * '-' - =old= contains text deleted from the old version
      * 'c' - =old= contains text from the old version, and =new= text
        from the version being saved
      * ' ' - =new= contains text common to both versions, or the change
        only involved whitespace
   * =$old= => text from version currently saved
   * =$new= => text from version being saved
   * =\%info= is a reference to the form field description { name, title,
     type, size, value, tooltip, attributes, referenced }. It must _not_
     be wrtten to. This parameter will be undef when merging the body
     text of the topic.

Plugins should try to resolve differences and return the merged text. 
For example, a radio button field where we have 
={ diff=>'c', old=>'Leafy', new=>'Barky' }= might be resolved as 
='Treelike'=. If the plugin cannot resolve a difference it should return 
undef.

The merge handler will be called several times during a save; once for 
each difference that needs resolution.

If any merges are left unresolved after all plugins have been given a 
chance to intercede, the following algorithm is used to decide how to 
merge the data:
   1 =new= is taken for all =radio=, =checkbox= and =select= fields to 
     resolve 'c' conflicts
   1 '+' and '-' text is always included in the the body text and text
     fields
   1 =&lt;del>conflict&lt;/del> &lt;ins>markers&lt;/ins>= are used to 
     mark 'c' merges in text fields

The merge handler is called whenever a topic is saved, and a merge is 
required to resolve concurrent edits on a topic.

*Since:* Foswiki::Plugins::VERSION = 2.0

=cut

#sub mergeHandler {
#    my ( $diff, $old, $new, $info ) = @_;
#}

=begin TML

---++ modifyHeaderHandler( \%headers, $query )
   * =\%headers= - reference to a hash of existing header values
   * =$query= - reference to CGI query object
Lets the plugin modify the HTTP headers that will be emitted when a
page is written to the browser. \%headers= will contain the headers
proposed by the core, plus any modifications made by other plugins that also
implement this method that come earlier in the plugins list.
<verbatim>
$headers->{expires} = '+1h';
</verbatim>

Note that this is the HTTP header which is _not_ the same as the HTML
&lt;HEAD&gt; tag. The contents of the &lt;HEAD&gt; tag may be manipulated
using the =Foswiki::Func::addToHEAD= method.

*Since:* Foswiki::Plugins::VERSION 2.0

=cut

#sub modifyHeaderHandler {
#    my ( $headers, $query ) = @_;
#}

=begin TML

---++ renderFormFieldForEditHandler($name, $type, $size, $value, $attributes, $possibleValues) -> $html

This handler is called before built-in types are considered. It generates 
the HTML text rendering this form field, or false, if the rendering 
should be done by the built-in type handlers.
   * =$name= - name of form field
   * =$type= - type of form field (checkbox, radio etc)
   * =$size= - size of form field
   * =$value= - value held in the form field
   * =$attributes= - attributes of form field 
   * =$possibleValues= - the values defined as options for form field, if
     any. May be a scalar (one legal value) or a ref to an array
     (several legal values)

Return HTML text that renders this field. If false, form rendering
continues by considering the built-in types.

*Since:* Foswiki::Plugins::VERSION 2.0

Note that you can also extend the range of available
types by providing a subclass of =Foswiki::Form::FieldDefinition= to implement
the new type (see =Foswiki::Extensions.JSCalendarContrib= and
=Foswiki::Extensions.RatingContrib= for examples). This is the preferred way to
extend the form field types.

=cut

#sub renderFormFieldForEditHandler {
#    my ( $name, $type, $size, $value, $attributes, $possibleValues) = @_;
#}

=begin TML

---++ renderWikiWordHandler($linkText, $hasExplicitLinkLabel, $web, $topic) -> $linkText
   * =$linkText= - the text for the link i.e. for =[<nop>[Link][blah blah]]=
     it's =blah blah=, for =BlahBlah= it's =BlahBlah=, and for [[Blah Blah]] it's =Blah Blah=.
   * =$hasExplicitLinkLabel= - true if the link is of the form =[<nop>[Link][blah blah]]= (false if it's ==<nop>[Blah]] or =BlahBlah=)
   * =$web=, =$topic= - specify the topic being rendered

Called during rendering, this handler allows the plugin a chance to change
the rendering of labels used for links.

Return the new link text.

*Since:* Foswiki::Plugins::VERSION 2.0

=cut

#sub renderWikiWordHandler {
#    my( $linkText, $hasExplicitLinkLabel, $web, $topic ) = @_;
#    return $linkText;
#}

=begin TML

---++ completePageHandler($html, $httpHeaders)

This handler is called on the ingredients of every page that is
output by the standard CGI scripts. It is designed primarily for use by
cache and security plugins.
   * =$html= - the body of the page (normally &lt;html>..$lt;/html>)
   * =$httpHeaders= - the HTTP headers. Note that the headers do not contain
     a =Content-length=. That will be computed and added immediately before
     the page is actually written. This is a string, which must end in \n\n.

*Since:* Foswiki::Plugins::VERSION 2.0

=cut

#sub completePageHandler {
#    my( $html, $httpHeaders ) = @_;
#    # modify $_[0] or $_[1] if you must change the HTML or headers
#    # You can work on $html and $httpHeaders in place by using the
#    # special perl variables $_[0] and $_[1]. These allow you to operate
#    # on parameters as if they were passed by reference; for example:
#    # $_[0] =~ s/SpecialString/my alternative/ge;
#}

=begin TML

---++ Deprecated handlers

---+++ redirectCgiQueryHandler($query, $url )
   * =$query= - the CGI query
   * =$url= - the URL to redirect to

This handler can be used to replace Foswiki's internal redirect function.

If this handler is defined in more than one plugin, only the handler
in the earliest plugin in the INSTALLEDPLUGINS list will be called. All
the others will be ignored.

*Deprecated in:* Foswiki::Plugins::VERSION 2.1

This handler was deprecated because it cannot be guaranteed to work, and
caused a significant impediment to code improvements in the core.

---+++ beforeAttachmentSaveHandler(\%attrHash, $topic, $web )

   * =\%attrHash= - reference to hash of attachment attribute values
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called once when an attachment is uploaded. When this
handler is called, the attachment has *not* been recorded in the database.

The attributes hash will include at least the following attributes:
   * =attachment= => the attachment name
   * =comment= - the comment
   * =user= - the user id
   * =tmpFilename= - name of a temporary file containing the attachment data

*Deprecated in:* Foswiki::Plugins::VERSION 2.1

The efficiency of this handler (and therefore it's impact on performance)
is very bad. Please use =beforeUploadHandler()= instead.

=begin TML

---+++ afterAttachmentSaveHandler(\%attrHash, $topic, $web )

   * =\%attrHash= - reference to hash of attachment attribute values
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$error= - any error string generated during the save process (always
     undef in 2.1)

This handler is called just after the save action. The attributes hash
will include at least the following attributes:
   * =attachment= => the attachment name
   * =comment= - the comment
   * =user= - the user id

*Deprecated in:* Foswiki::Plugins::VERSION 2.1

This handler has a number of problems including security and performance
issues. Please use =afterUploadHandler()= instead.

=cut

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
