#
#      TWiki LDAP Plugin
#
#      Written by Gerard Hickey <hickey@kernelrom.com>
#      Modified by Gerald Skerbitz <gsker@tcfreenet.org> to use extractNameValuePair() and provide for
#                  multiple attributes and multiple records.
#     Modified by PatrickNomblot - 26 Jun 2003 to add JPeg Photo
#     Modified by Gerald Skerbitz 24 Oct 2003 to fix bug with shortvs long fields
#     Modified by PatrickNomblot - 9 Dec 2003 to change JPeg Photo to not have IMG hradcoded
#     Modified by GeraldSkerbitz - 13 Jan 2004 to add utf coding
#     Modified by GeraldSkerbitz and PatrickNomblot - 14 Jan 2004 to add CGI and fix default Filter
#     Modified by GeraldSkerbitz 02 Feb 2004 changed basedn to base everywhere.
#     Modified by GeraldSkerbitz 04 Feb 2004 Code contributed by PatrickNomblot to
#                  accomodate multiple values per attribute
#     Modified by GeraldSkerbitz 05 Apr 2004 Added Order to sort output
#     Modified by JoanTouzet 03 Oct 2005 Reindented without tabs; fixes for Dakar, use strict

# =========================
package TWiki::Plugins::LdapPlugin;

use strict;
no strict 'refs';
use Data::Dumper;
use Net::LDAP;
use Net::LDAP::Entry;
use Unicode::String qw(utf8 latin1 utf16);

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
  $LDAP_Base $LDAP_Host $LDAP_Header $LDAP_Format
  $LDAP_Filter $LDAP_jpegPhoto $LDAP_Notfounderror
  $LDAP_Port $LDAP_Order $LDAP_MvFormat
  $LDAP_jpegDefaultPhoto
);

$VERSION = '$Rev$';
$RELEASE = '1.011';    # 03 Oct 2005

# =========================
sub initPlugin {
    ( my $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning(
            "Version mismatch between EmptyPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin preferences, the variable defined by:
    #    * Set EXAMPLE = ...
    $LDAP_Base   = &TWiki::Func::getPreferencesValue("LDAPPLUGIN_BASE");
    $LDAP_Host   = &TWiki::Func::getPreferencesValue("LDAPPLUGIN_HOST");
    $LDAP_Header = &TWiki::Func::getPreferencesValue("LDAPPLUGIN_HEADER");
    $LDAP_Format = &TWiki::Func::getPreferencesValue("LDAPPLUGIN_FORMAT");
    $LDAP_Order  = &TWiki::Func::getPreferencesValue("LDAPPLUGIN_ORDER");
    $LDAP_Port = &TWiki::Func::getPreferencesValue("LDAPPLUGIN_PORT") || "389";
    $LDAP_MvFormat = &TWiki::Func::getPreferencesValue("LDAPPLUGIN_MVFORMAT")
      || "<br>";
    $LDAP_Notfounderror =
      &TWiki::Func::getPreferencesValue("LDAPPLUGIN_NOTFOUNDERROR");

    #jpegPhoto defines the Photo attribute name, if any
    $LDAP_jpegPhoto = &TWiki::Func::getPreferencesValue("LDAPPLUGIN_JPEGPHOTO")
      || 'jpegPhoto';

    #jpegDefaultPhoto defines a default photo if someone doesn't have one
    $LDAP_jpegDefaultPhoto =
      &TWiki::Func::getPreferencesValue("LDAPPLUGIN_JPEGDEFAULTPHOTO") || '';

    # LDAP_Filter is the default Filter
    # The word TOPIC in the filter is replaced with the topic.

    $LDAP_Filter =
      &TWiki::Func::getPreferencesValue("LDAPPLUGIN_DEFAULTFILTER");
    my $topicreplace = &TWiki::Func::wikiToUserName($topic);
    $LDAP_Filter =~ s/TOPIC/$topicreplace/;

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("LDAPPLUGIN_DEBUG") || 0;

    if ($debug) {
        &TWiki::Func::writeDebug(
            "- TWiki::Plugins::LdapPlugin::initPlugin( $web.$topic ) is OK");

        my @values = (
            'LDAP_Base',          'LDAP_Host',
            'LDAP_Header',        'LDAP_Format',
            'LDAP_Filter',        'LDAP_jpegPhoto',
            'LDAP_Notfounderror', 'LDAP_Port'
        );
        foreach my $value (@values) {
            &TWiki::Func::writeDebug(
                "- TWiki::Plugins::LdapPlugin::initPlugin $value --> $$value\n"
            );
        }
    }
    return 1;
}

# =========================
sub ldap_lookup () {
    my $attr = shift;
    my ( $ldap, $i, $x, $y, $row, $mesg );
    my ( @fields, @keyfields );
    my ( %rows,   %sortfield );

    &TWiki::Func::writeDebug("- LdapPlugin::ldap_lookup( $attr )") if $debug;

    my $mvformat = &TWiki::Func::extractNameValuePair( $attr, "mvformat" )
      || $LDAP_MvFormat;

    # host from setting or from parameter
    my $host = &TWiki::Func::extractNameValuePair( $attr, "host" )
      || $LDAP_Host;

    # add the defined port
    $host .= ":$LDAP_Port";

    # Use $host to make connection.  Bail out with error if no connect.
    if ( !( $ldap = Net::LDAP->new($host) ) ) {

        # Connection failed!
        return ("<b> LDAP Connect Failure </b>");
    }

    # filter from parameter or CgiQuery
    my $cgi       = &TWiki::Func::getCgiQuery();
    my $cgiFilter = "";
    if ( $cgi->param('ldapfilter') ) {
        $cgiFilter = $cgi->param('ldapfilter');
        $cgiFilter =~ s/^ +//;
        $cgiFilter =~ s/^AND\(/&(/;
        $cgiFilter =~ s/%(\d\d)/pack("H2",$1)/eg;
    }

    my $filter =
         $cgiFilter
      || &TWiki::Func::extractNameValuePair( $attr, "filter" )
      || $LDAP_Filter;

    if ( !$filter ) {
        return ("No Filter Specified for Search");
    }

    # format from setting or parameter.  Field list extracted from format.
    my $format = &TWiki::Func::extractNameValuePair( $attr, "format" )
      || $LDAP_Format;
    if ( !$format ) {
        return "No Fields Requested";
    }
    else {

        # get attributes list from Format
        if ( $format eq "FIELDLIST" ) {
            @fields = ();
        }
        else {
            @fields = ( $format =~ /\$([^\W]+)/g );
        }
    }

    my $order = &TWiki::Func::extractNameValuePair( $attr, "order" )
      || $LDAP_Order;
    @keyfields = ( $order =~ /([^\W]+)/g );

    # header from setting or parameter
    my $header = &TWiki::Func::extractNameValuePair( $attr, "header" )
      || $LDAP_Header;

    # base from setting or parameter
    my $base = &TWiki::Func::extractNameValuePair( $attr, "base" )
      || $LDAP_Base;

    # Special attribute : PHOTO --> need to store the content in a file
    # if you never want to process jpeg, comment out the next line
    # and it won't ever happen.
    my $jpegPhoto = &TWiki::Func::extractNameValuePair( $attr, "jpegPhoto" )
      || $LDAP_jpegPhoto;
    my $jpegDefaultPhoto =
         &TWiki::Func::extractNameValuePair( $attr, "jpegDefaultPhoto" )
      || $LDAP_jpegDefaultPhoto;

    # Error message if LDAP request gives no answer
    my $NotFoundError =
         &TWiki::Func::extractNameValuePair( $attr, "notfounderror" )
      || $LDAP_Notfounderror
      || "LDAP Query Returned Zero Records [Filter: =$filter= ]";

    &TWiki::Func::writeDebug(
"- LdapPlugin::ldap_lookup(): HOST=\"$host\" BASE=\"$base\" FILTER=\"$filter\""
    ) if $debug;
    &TWiki::Func::writeDebug("- LdapPlugin::ldap_lookup(): attrs=\"@fields\"")
      if $debug;

    # do the actual LDAP lookup
    $mesg = $ldap->search(
        'host'   => $host,
        'base'   => $base,
        'filter' => $filter,
        'attrs'  => [@fields]
    );

    # If query succeeds, then print header here (if defined)
    my $max   = $mesg->count;
    my $value = "";
    if ($max) {
        $value = "$header \n" if ($header);
    }
    else {

        # return message saying no rows were found ....
        return "$NotFoundError";
    }

# If $format = FIELDLIST then just return the list of fields for the entry found.
    if ( $format eq "FIELDLIST" ) {

        # Loop over all entries to add all seen attributes on this query
        # From Net::LDAP::Examples
        my %attrHash;
        my $href       = $mesg->as_struct;
        my @arrayOfDNs = keys %$href;
        foreach (@arrayOfDNs) {
            my $valref       = $$href{$_};
            my @arrayOfAttrs = sort keys %$valref;
            my $attrName;
            foreach $attrName (@arrayOfAttrs) {
                $attrHash{$attrName} = '1';
            }
        }
        foreach my $key ( keys %attrHash ) {
            $value .= "$key, ";
        }
        return $value;
    }

    %rows = ();

    # Then print rows of query response
    for ( $i = 0 ; $i < $max ; $i++ ) {
        %sortfield = ();
        $row       = $format;
        my $entry = $mesg->entry($i);
        foreach $x ( sort { length($b) <=> length($a) } @fields ) {
            if ( defined( $entry->get_value($x) ) ) {
                $y = join( "$mvformat", $entry->get_value($x) );

                if ( defined($jpegPhoto) && ( $x eq "$jpegPhoto" ) ) {
                    my $dir = TWiki::Func::getPubDir() . "/LdapPhotos";
                    if ( !-e "$dir" ) {
                        umask(002);
                        mkdir( $dir, 0775 );
                        &TWiki::Func::writeDebug(
                            "- LdapPlugin::ldap_lookup() create $dir/\n")
                          if $debug;
                    }
                    my $jpegPhotoFile = $entry->get_value('alias');
                    if ( "$jpegPhotoFile" eq "" ) { $jpegPhotoFile = $topic; }
                    $jpegPhotoFile = $jpegPhotoFile . ".jpg";
                    open( FILE, ">$dir/$jpegPhotoFile" );
                    binmode(FILE);
                    print FILE $y;
                    close(FILE);
                    $y = TWiki::Func::getPubUrlPath()
                      . "/LdapPhotos/$jpegPhotoFile";
                    &TWiki::Func::writeDebug(
"- LdapPlugin::ldap_lookup() create $dir/$jpegPhotoFile\n"
                    ) if $debug;
                }
                $y =~ s/\n/ /g; # remove newlines from data (messes with format)
                $row =~ s/\$$x/$y/ge;    # replace $field with $y (the value)
            }
            else {
                $row =~ s/\$$jpegPhoto/$jpegDefaultPhoto/ge;
                $row =~ s/\$$x/" "/ge;
            }

            # Capture field value for sort
            if ( scalar grep ( /$x/, @keyfields ) ) {
                $sortfield{$x} = $y;
                &TWiki::Func::writeDebug(
                    "- LdapPlugin::ldap_lookup() Field=\"$x\" Sort=\"$y\"")
                  if $debug;
            }
        }
        $row = utf8($row)->latin1;
        $rows{ join( "-", @sortfield{@keyfields} ) } .= "$row\n";
    }

    # build $value with %rows{sortfield}
    foreach my $key ( sort keys %rows ) {
        $value .= "$rows{$key}";
    }

    &TWiki::Func::writeDebug("- LdapPlugin::ldap_lookup() returning: $value")
      if $debug;
    return ($value);
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

###  &TWiki::Func::writeDebug( "- LdapPlugin::commonTagsHandler( text ,$_[1],$_[2] )") if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%
    $_[0] =~ s/(?<!\<nop\>)%LDAP{(.*?)}%/&ldap_lookup($1)/geo;

}

1;
