#
# GenPDFLatex.pm (converts a Foswiki topic to Latex or PDF using HTML::Latex)
#    (based on GenPDF.pm package)
#
# This package Copyright (c) 2005 W Scott Hoge
# (shoge -at- bwh -dot- harvard -dot- edu)
# and distributed under the GPL (see below)
#
# an extension to the Foswiki wiki (see http://foswiki.org)
# Copyright (C) 2008-2009 Foswiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

## This package was used to capture STDOUT during development
##
#  package Redirect;
#
#  sub TIEHANDLE  {
#      return bless [], $_[0];
#  }
#
#  sub PRINT {
#      my $fh = shift;
#      push @$fh, @_;
#  }
#
#  1;

package Foswiki::Contrib::GenPDFLatex;

use strict;

use vars qw( $debug );

use File::Copy;

# VERSION and RELEASE moved to GenPDFLatexAddOn.pm

=pod

=head1 Foswiki::Contrib::GenPDFLatex

Foswiki::Contrib::GenPDFLatex - Generates raw latex or pdflatex file from a 
    Foswiki topic

=head1 DESCRIPTION

See the GenPDFLatexAddOn Foswiki topic for the full description.

=head1 METHODS

Methods with a leading underscore should be considered local methods
and not called from outside the package.

=cut

######################################################################
#### these paths need to be properly configured (either here or in
#### LocalSite.cfg)

# path to location of local texmf tree, where custom style files are storedx
$ENV{'HOME'} = $Foswiki::cfg{Plugins}{GenPDFLatex}{home}
  || '/home/nobody';

# full path to pdflatex and bibtex
my $pdflatex = $Foswiki::cfg{Plugins}{GenPDFLatex}{pdflatex}
  || '/usr/share/texmf/bin/pdflatex';
my $bibtex = $Foswiki::cfg{Plugins}{BibtexPlugin}{bibtex}
  || '/usr/share/texmf/bin/bibtex';

# directory where the html2latex parser will store copies of
# referenced images, if needed
my $htmlstore = $Foswiki::cfg{Plugins}{GenPDFLatex}{h2l_store}
  || '/tmp/';

######################################################################

use CGI::Carp qw( fatalsToBrowser );
use CGI;
use Foswiki::Func;
use Foswiki::UI::View;

use HTML::LatexLMP;
use File::Basename;
use File::Temp;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

sub writeDebug {
    &Foswiki::Func::writeDebug( "genpdflatex - " . $_[0] ) if $debug;
}

$debug = 0;

sub GenPDFLatex() {

    $Foswiki::Plugins::SESSION = shift;

    my $query = $Foswiki::Plugins::SESSION->{cgiQuery};

    # initialize the topic location
    ##
    my $topic         = $Foswiki::Plugins::SESSION->{topicName};
    my $webName       = $Foswiki::Plugins::SESSION->{webName};
    my $scriptUrlPath = $Foswiki::Plugins::SESSION->{scriptUrlPath};
    my $userName;

    my $thePathInfo   = $query->path_info();
    my $theRemoteUser = $query->remote_user();
    my $theTopic      = $query->param('topic');
    my $theUrl        = $query->url;

    my $action = $query->param('output') || "";

    if ( $action eq 'latex' ) {

        my $tex = _genlatex( $webName, $topic, $userName, $query );

        my $resp = $Foswiki::Plugins::SESSION->{response};
        if ( length($tex) > 0 ) {
            $resp->header(
                -TYPE       => "text/html",
                -attachment => "$topic.tex"
            );
            $resp->print($tex);
        }
        else {
            $resp->header( -TYPE => "text/html" );

            $resp->print("GenPDFLatex error:  No latex file generated.");
        }

    }
    elsif ( $action eq 'srczip' ) {

        my $tex = _genlatex( $webName, $topic, $userName, $query );

        my @filelist = _get_file_list( $webName, $topic );

        if ($debug) {

            my $resp = $Foswiki::Plugins::SESSION->{response};
            $resp->header( -TYPE => "text/html" );

            $resp->print(
"<p>Generating ZIP file of latex source + attached bib and fig files\n<p>"
                  . "<ul>"
                  . map { "<li> $_" } @filelist 
                  . "</ul>" );
        }

        my $zip = Archive::Zip->new();
        my ( $tmpzip, $WDIR ) = ( '', '' );
        if ( defined($zip) ) {

            $WDIR   = File::Temp::tempdir();
            $tmpzip = $WDIR . "tmp.zip";

            my $member = $zip->addString( $tex, $topic . '.tex' );

            #        $member->desiredCompressionMethod( COMPRESSION_DEFLATED );

            # use hard-disk path rather than relative url paths for images
            my $url = Foswiki::Func::getPubDir();

            foreach my $c (@filelist) {
                my $member =
                  $zip->addFile( join( '/', $url, $webName, $topic, $c ), $c );
            }
            die 'write error'
              unless $zip->writeToFileNamed($tmpzip) == AZ_OK;
        }

        if ( -f $tmpzip ) {
            my $resp = $Foswiki::Plugins::SESSION->{response};

            $resp->header(
                -TYPE       => "application/zip",
                -attachment => $topic . "_src.zip"
            );

            open( F, $tmpzip );
            while (<F>) {
                $resp->print($_);
            }
            close(F);

            unlink($tmpzip) unless ($debug);

            rmdir($WDIR)
              || print STDERR "genpdflatex: Can't remove $WDIR: $!\n";
            $WDIR = undef;

        }
        else {
            my $resp = $Foswiki::Plugins::SESSION->{response};
            $resp->header( -TYPE => "text/html" );
            $resp->print("GenPDFLatex error:  No ZIP file generated.");
        }
        undef($zip);

    }
    elsif ( $action eq 'pdf' ) {

        my $tex = _genlatex( $webName, $topic, $userName, $query );

        # create a temporary working directory
        my $WDIR = File::Temp::tempdir();

        my $latexfile = $WDIR . '/lmp_content.tex';

        open( F, ">$latexfile" );
        print F $tex;
        close(F);

        my ( $base, $path, $extension ) = fileparse( $latexfile, '\.tex' );
        my $texrel  = "$base$extension";    #relative name of the tex file
        my $logfile = "$path$base.log";
        my $pdffile = "$path$base.pdf";

        # change to working directory for latex processing
        use Cwd;
        my $SDIR = getcwd();
        $SDIR = $1 if ( ($SDIR) and ( $SDIR =~ m/^(.*)$/ ) );

        open( F, ">/tmp/gpl.txt" );

        my @filelist = _get_file_list( $webName, $topic );
        print F join( " ", @filelist );
        print F "\n";
        foreach my $f (@filelist) {
            my $ret = copy(
                join( '/', Foswiki::Func::getPubDir(), $webName, $topic, $f ),
                $path . '/' . $f );
            if ( $ret == 0 ) {
                print F "Copy of $f failed. $!\n";
            }
            else {
                print F "Copied $f\n";
            }
        }

        chdir($path);
        my $flag = 0;
        my $ret  = "";

        do {
            my ( $result, $code ) = Foswiki::Sandbox->sysCommand(
                "$pdflatex -interaction=nonstopmode $texrel");
            $ret = $result;

            print F $ret;

            if ( $tex =~ m/\\bibliography\{/ ) {

                ( $result, $code ) =
                  Foswiki::Sandbox->sysCommand("$bibtex $base");
                $ret .= $result;
            }
            $flag++;    # unless ($ret =~ m/Warning.*?Rerun/i);

            print F "Flag: " . $flag . "\n";
        } while ( $flag < 2 );
        close(F);

        my @errors = grep /^!/, $ret;

        my $log = "";
        open( F, "$logfile" );
        while (<F>) {
            $log .= $_ . "\n";
            push( @errors, grep /Error\:/, $_ );
        }
        close(F);

        my $resp = $Foswiki::Plugins::SESSION->{response};
        if (@errors) {
            $resp->header( -TYPE => "text/html" );
            $resp->print("<html><body>");
            $resp->print( "pdflatex reported "
                  . scalar(@errors)
                  . " errors while creating PDF:" );
            $resp->print("<ul>\n");
            $resp->print( map { "<li>$_ " } @errors );
            $resp->print("</ul>\n");

            $resp->print("</html></body>");

        }
        elsif ( -f $pdffile ) {

            $resp->header(
                -TYPE       => "application/pdf",
                -attachment => "$topic.pdf"
            );

            open( F, "$pdffile" );
            while (<F>) {
                $resp->print($_);
            }
            close(F);
        }
        else {

            $resp->header( -TYPE => "text/html" );
            $resp->print("<html><body>\n");
            $resp->print("<h1>PDFLATEX processing error:</h1>\n");

            if ($debug) {
                $resp->print("Attached files: <ul>");
                $resp->print( map { "<li> $_" } @filelist );
                $resp->print("</ul>");
            }
            $resp->print( "<pre>" . $log );
            $resp->print("</pre></body></html>\n");
        }

        do {

            # clean up the working directory
            opendir( D, $WDIR )
              || print STDERR "genpdflatex: Can't open $WDIR: $!\n";
            foreach my $t ( grep( /$base/, readdir(D) ) ) {
                $t =~ m/^(.*?)$/;
                $t = $1;    # untaint it
                unlink("$t")
                  || print STDERR "genpdflatex: Can't remove $t: $!\n";
            }
            close(D);

            # remove the attached files
            foreach my $f (@filelist) {
                unlink("$f")
                  || print STDERR "genpdflatex: Can't remove $f: $!\n";
            }

            chdir($SDIR) if ( $SDIR ne "" );
            rmdir($WDIR)
              || print STDERR "genpdflatex: Can't remove $WDIR: $!\n";
            $WDIR = undef;
        } unless ($debug);

    }
    else {

        my $optpg =
          &Foswiki::Func::getPreferencesValue("GENPDFLATEX_OPTIONSPAGE") || "";

        $optpg =~ s/\s+$//;    # this should not be needed, but apparently is :(
        my $text = "";
        if ( $optpg ne "" ) {

            # if an options page is defined

            my ( $optWeb, $optTopic ) = ( $1, $2 )
              if $optpg =~ /(.*)[\.\/](.*)/;

            # print STDERR "$optWeb . $optTopic \n";
            if ( $optTopic eq "" ) {
                $optTopic = $optWeb;
                $optWeb   = $webName;
            }
            $optWeb = $webName if ( $optWeb eq "" );

            my $session = $Foswiki::Plugins::SESSION;
            my $exists = $session->{store}->topicExists( $optWeb, $optTopic );

            if ($exists) {
                my $skin = "plain";    # $query->param( "skin" );
                my $tmpl;
                if ( $Foswiki::Plugins::VERSION >= 1.2 ) {
                    $tmpl = $session->templates->readTemplate( 'view', $skin );
                }
                elsif ( $Foswiki::Plugins::VERSION >= 1.1 ) {
                    $tmpl =
                      $session->{templates}->readTemplate( 'view', $skin );
                }
                else {
                    $tmpl = &Foswiki::Store::readTemplate( "view", $skin );
                }

                $text =
                  Foswiki::Func::readTopicText( $optWeb, $optTopic, undef );

                $tmpl =~ s/%TEXT%/$text/;
                $tmpl =~ s/%META:\w+{.*?}%//gs;

                $tmpl .= "<p>(edit the $optpg topic to modify this form.)";

                $text = Foswiki::Func::expandCommonVariables( $tmpl, $optTopic,
                    $optWeb );
                $text = Foswiki::Func::renderText($text);

                $text =~ s/%.*?%//g;    # clean up any spurious Foswiki tags
            }
        }

        # if (0) {
        #     ### I was hoping to render the form inside the default template,
        #     ### but it didn't look as nice as I'd hoped...
        #
        #     my ($optWeb,$optTopic) = ($1,$2) if $optpg =~ /(.*)[\.\/](.*)/ ;
        #     print STDERR "$optWeb . $optTopic \n";
        #     if ($optTopic eq "") {
        #         $optTopic = $optWeb;
        #         $optWeb = $webName;
        #     }
        #     $optWeb = $webName if ($optWeb eq "");
        #
        #     my $stdout = tie *STDOUT, 'Redirect';
        #
        #     # Foswiki::Func::redirectCgiQuery( $query, $optpg );
        #     Foswiki::UI::View::view( $optWeb, $optTopic, $userName, $query );
        #
        #     my $text = join('',@{ $stdout });
        #
        #     $stdout = undef;
        #     untie(*STDOUT);
        # }

        if ( length($text) == 0 ) {

            # if optpg is undefined, or points to a non-existent topic, then
            # use the default form defined below.
            while (<DATA>) {
                $text .= $_;
            }
        }

        $text =~ s/\$scriptUrlPath/$scriptUrlPath/g;
        $text =~ s/\$topic/$topic/g;
        $text =~ s/\$web/$webName/g;

        $text =~
s!<title>.*?</title>!<title>Foswiki genpdflatex: $webName/$topic</title>!;

        foreach my $c ( $query->param() ) {
            my $o = $query->param($c);
            $text =~ s/\$$c/$o/g;

            $text .= "<br>$c = " . $query->param($c) if ($debug);
        }

        # elliminate style lines and packages if the options are not declared.
        $text =~ s/\n.*?\$style.*?\n/\n/g;
        $text =~ s/\$packages//g;

        &Foswiki::Func::writeHeader();
        $Foswiki::Plugins::SESSION->{response}->print($text);

    }

}

sub _get_file_list {
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $_[0], $_[1] );    # $webName, $topic
    my @filelist;

    my %h = %{$meta};
    foreach my $c ( @{ $h{'FILEATTACHMENT'} } ) {
        my %h2 = %{$c};
        next if ( $h2{'attr'} eq 'h' );
        push @filelist, $h2{'name'};
    }
    return (@filelist);
}

sub _list_possible_classes {

    # this is a debug subroutine to check if the latex environment is
    # operational on the server.
    print $ENV{'HOME'};
    print $ENV{'PATH'};
    my ( $base, $path ) = fileparse($pdflatex);
    $ENV{'PATH'} .= ':' . $base;    # use correct dir sep for your OS.

    my @paths = split( /:/, `$base/kpsepath tex` );

    my %classes = ();

    print "<ul>";
    foreach (@paths) {
        print "<li>" . $_;
        ( my $p = $_ ) =~ s!(texmf.*?)/.*$!$1!;
        $p =~ s/\!//g;
        print "   $p";
        if ( ( -d $p ) and ( -f $p . "/ls-R" ) ) {
            open( F, "$p/ls-R" ) or next;
            while (<F>) {
                chomp;
                $classes{$_} = 1 if (s/\.cls$//);
            }
            close(F);
        }
    }
    print "</ul>";

    if ( keys %classes ) {
        print "<ul>";
        print map { "<li> $_" } sort keys %classes;
        print "</ul>";
    }
}

sub _genlatex {
    my ( $webName, $topic, $userName, $query ) = @_;

    # wiki rendering set-up
    my $rev         = $query->param("rev");
    my $viewRaw     = $query->param("raw") || "";
    my $unlock      = $query->param("unlock") || "";
    my $skin        = "plain";                        # $query->param( "skin" );
    my $contentType = $query->param("contenttype");

    my $tmpl;
    if ( $Foswiki::Plugins::VERSION >= 1.1 ) {

        # Dakar interface or better
        my $session = $Foswiki::Plugins::SESSION;
        my $store   = $session->{store};

        return unless ( $store->topicExists( $webName, $topic ) );

        if ( $Foswiki::Plugins::VERSION >= 1.2 ) {
            $tmpl = $session->templates->readTemplate( 'view', $skin );
        }
        else {
            $tmpl = $session->{templates}->readTemplate( 'view', $skin );
        }
    }
    else {
        return unless Foswiki::UI::webExists( $webName, $topic );

        $tmpl = &Foswiki::Store::readTemplate( "view", $skin );
    }

    Foswiki::Func::getContext()->{'genpdflatex'} = 1;

    ### from Foswiki::Contrib::GenPDF::_getRenderedView

    my $text = Foswiki::Func::readTopicText( $webName, $topic, $rev );
    $text = Foswiki::Func::expandCommonVariables( $text, $topic, $webName );

    # $text =~ s/\\/\n/g;

    ### for compatibility w/ SectionalEditPlugin (can't override skin
    ### directives in Foswiki::Func::getSkin)
    $text =~ s!<.*?section.*?>!!g;

    # protect latex new-lines at end of physical lines
    $text =~ s!(\\\\)$!$1    !g;
    $text =~ s!(\\\\)\n!$1    \n!g;

    $text = Foswiki::Func::renderText($text);

    $text =~ s/%META:\w+{.*?}%//gs;    # clean out the meta-data

    my $preamble = Foswiki::Func::getContext->{'LMPcontext'}->{'preamble'}
      || "";
    print STDERR $preamble . "\n" if ($debug);

    # remove the wiki <nop> tag (It gets ignored in the HTML
    # parser anyway, this just cuts down on the number of error
    # messages.)
    $text =~ s!<nop>!!g;

    # use hard-disk path rather than relative url paths for images
    my $pdir  = Foswiki::Func::getPubDir();
    my $purlh = Foswiki::Func::getUrlHost();
    my $purlp = Foswiki::Func::getPubUrlPath();

    $text =~ s!<img(.*?) src="($purlh)?$purlp!<img$1 src="$pdir\/!sgi;

    # $url =~ s/$ptmp//;
    # $text =~ s!<img(.*?) src="\/!<img$1 src="$url\/!sgi;

    # add <p> tags to all paragraph breaks
    # while ($text =~ s!\n\n!\n<p />\n!gs) {}

    ## strip out all <p> tags from within <latex></latex>
    my $t2 = $text;

    # while ($text =~ m!<latex>(.*?)</latex>!gs) {
    #     my $t = $1;
    #     (my $u = $t) =~ s!\n?<p\s?\/?>!!gs;
    #     # print STDERR $t."\n".$u."\nxxxxxx\n";
    #     $t2 =~ s/\Q$t\E/$u/s;
    # }
    {    # catch all nested <latex> tags!
        my $c   = 0;
        my $txt = '';
        while ( $text =~ m!\G(.*?<(/?)latex>)!gs ) {
            if ( $2 eq '/' ) {
                $c = $c - 1;
                $txt .= $1;
                if ( $c == 0 ) {
                    ( my $n = $txt ) =~ s!\n?<p\s?\/?>|\n\n!!gs;
                    $t2 =~ s/\Q$txt\E/$n/;
                    $txt = '';
                }
            }
            else {
                $txt .= $1 if ( $c > 0 );
                $c = $c + 1;
            }
        }
    }

    $text = "<html><body>" . $t2 . "</body></html>";
    if ($debug) {
        open( F, ">$htmlstore/LMP.html" );
        print F $text;
        close(F);
    }

    # html parser set-up
    my %options  = ();
    my @packages = ();
    my @heads    = ();
    my @banned   = ();

    push( @heads, 'draftcls' )
      if $query->param('draftcls');
    push( @heads, $query->param('ncol') )
      if $query->param('ncol');
    push( @packages, split( /\,/, $query->param('packages') ) )
      if $query->param('packages');
    $options{document_class} = $query->param('class')
      if $query->param('class');
    $options{font_size} = $query->param('fontsize')
      if $query->param('fontsize');
    $options{image} = $query->param('imgscale')
      if $query->param('imgscale');

    $options{paragraph} = 0;

    my $parser = new HTML::LatexLMP();

    $parser->set_option( \%options );
    $parser->add_package(@packages);
    $parser->add_head(@heads);
    $parser->ban_tag(@banned);
    $parser->set_option( { store => $htmlstore } );

    # $parser->set_log('/tmp/LMP.log');
    # open(F,">/tmp/LMP.html"); print F $text; close(F);
    my $tex = $parser->parse_string( $text . "<p>", 1 );

    $tex =~ s/(\\begin\{document\})/\n$preamble\n$1/ if ( $preamble ne "" );

    # some packages, e.g. endfloat, need environments to end on their own line
    $tex =~ s/([^\n])\\end\{/$1\n\\end\{/g;

    # \par commands, too!
    $tex =~ s/\\par\b/\n\\par/g;

    # if color happens to appear outside of a latex environment,
    # ensure that the color package is included.
    # SMELL: there must be a better way to do this.
    if (    ( $tex =~ m/\\textcolor/ )
        and !( $tex =~ m/\\usepackage(\[[^\]]*\])?\{x?color\}/ )
        and !( $tex =~ m/\\includepackage(\[[^\]]*\])?\{x?color\}/ ) )
    {
        $tex =~ s!(\\begin\{document\})!\\usepackage{color}\n$1!;
    }

    return ($tex);
}

1;

__DATA__
<html><body>
    <form action="$scriptUrlPath/genpdflatex/$web/$topic" method="POST">
    <table border=1>
    <tr>
    <td> Web Name: 
    <td> $web
    <tr>
    <td> Topic Name: 
    <td> $topic
    <tr> 
    <td> Latex document style:
    <td>
    <select name="class">
    <option value="$style">$style</option>
    <option value="article">Generic Article</option>
    <option value="book">Book</option>
    <option value="IEEEtran">IEEE Trans</option>
    <option value="ismrm">MRM / JMRI (ISMRM)</option>
    <option value="cmr">Concepts in MR</option>
    <option value="letter">Letter</option>
    </select>
    <tr> 
    <td> Number of columns per page:
    <td>
    <input type="radio" name="ncol" value="onecolumn" checked="on" /> 1 column
     <input type="radio" name="ncol" value="twocolumn" /> 2 column
    <tr>
    <td> Font size:
    <td>
    <select name="fontsize">
    <option value="10"> 10pt </option>
    <option selected="true" value="11"> 11pt </option>
    <option value="12"> 12pt </option>
    </select>
    <tr>
    <td>Draft? (typically, double-spaced <br> with end-floats)
    <td>
    <input type="checkbox" name="draftcls" checked="on" />
    <tr>
    <td>Additional packages to include:
    <td><input name="packages" type="text" size="40" value="$packages" ></input>
    <tr>
    <td>Output file type:
    <td>
    <table>
    <tr><td><input type="radio" name="output" checked="on" value="latex" /> latex .tex file
    <tr><td><input type="radio" name="output" value="pdf" /> pdflatex PDF file
    <tr><td><input type="radio" name="output" value="srczip" /> ZIP file (.tex + attachments)
    </table>
    <tr>
    <td>
    <td>
    <input type="submit" value="Produce PDF/Latex" />
    </table>
    </form>
</body></html> 
