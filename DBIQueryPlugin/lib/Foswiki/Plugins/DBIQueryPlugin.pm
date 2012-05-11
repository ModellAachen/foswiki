# See bottom of file for license and copyright details
package Foswiki::Plugins::DBIQueryPlugin;

use strict;
use warnings;

use Assert;

use Digest::MD5 qw(md5_hex);
use DBI;
use Error qw(:try);
use CGI ();

use Foswiki::Func ();

our $VERSION          = '$Rev: 7193 $';
our $RELEASE          = '1.3';
our $SHORTDESCRIPTION = 'Make complex database queries using DBI Perl module';

our $NO_PREFS_IN_TOPIC = 1;
our $query_id          = 0;
our $protectStart      = '!&lt;ProtectStart&gt;';
our $protectEnd        = '!&lt;ProtectEnd&gt;';

our %queries;
our %subquery_map;
our $connections = undef;

use constant MAXRECURSIONLEVEL => 100;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    $connections = $Foswiki::cfg{Plugins}{DBIQueryPlugin}{dbi_connections};

    return 1;
}

sub beforeCommonTagsHandler {
    processPage(@_);
}

sub commonTagsHandler {

    if ( $_[3] ) {    # We're being included
        processPage(@_);
    }
}

sub postRenderingHandler {
    $_[0] =~ s/$protectStart(.*?)$protectEnd/unprotectValue($1)/ges;
}

sub message_prefix {
    my @call = caller(2);
    my $line = ( caller(1) )[2];
    return "- " . $call[3] . "\:$line ";
}

sub warning(@) {
    return Foswiki::Func::writeWarning( message_prefix() . join( "", @_ ) );
}

sub db_set_codepage {
    my $conname    = shift;
    my $connection = $connections->{$conname};
    if ( $connection->{codepage} ) {
        if ( $connection->{driver} =~ /^(mysql|Pg)$/ ) {
            $connection->{dbh}->do("SET NAMES $connection->{codepage}");
            $connection->{dbh}->do("SET CHARACTER SET $connection->{codepage}")
              if $connection->{driver} eq 'mysql';
        }
    }
}

sub userIsInGroup {
    my ( $user, $group ) = @_;
    return Foswiki::Func::isGroupMember( $group, $user );
}

=begin TML

db_connect($db_identifier): Useful when connection to another database
needed. =$db_identifier= parameter is database ID as specified in the
[[#PluginConfig][plugin configuration]].

=cut

sub db_connect {
    my $conname         = shift;
    my $connection      = $connections->{$conname};
    my @required_fields = qw(database driver);
    my $curUser         = Foswiki::Func::getWikiUserName();

    unless ( defined $connection->{dsn} ) {
        foreach my $field (@required_fields) {
            die
"Required field $field is not defined for database connection $conname.\n"
              unless defined $connection->{$field};
        }
    }

    my ( $dbuser, $dbpass ) =
      ( $connection->{user} || "", $connection->{password} || "" );

    if ( defined( $connection->{usermap} ) ) {
        my @maps =
          sort { ( $a =~ /Group$/ ) <=> ( $b =~ /Group$/ ) }
          keys %{ $connection->{usermap} };
        my $found = 0;
      MAP:
        foreach my $entity (@maps) {
            if ( $entity =~ /Group$/ ) {

                # $entity is a group
                $found = userIsInGroup( $curUser, $entity );
            }
            else {
                my $wikiUser =
                  Foswiki::Func::userToWikiName(
                    Foswiki::Func::wikiToUserName($entity), 0 );
                $found = ( $curUser eq $wikiUser );
            }
            if ($found) {
                $dbuser = $connection->{usermap}{$entity}{user};
                $dbpass = $connection->{usermap}{$entity}{password};
                last MAP;
            }
        }
    }

    die "User $curUser is not allowed to connect to database" unless $dbuser;

    unless ( $connection->{dbh} ) {
        my $server =
          $connection->{server} ? "server=$connection->{server};" : "";
        my $dsn;
        if ( defined $connection->{dsn} ) {
            $dsn = $connection->{dsn};
        }
        else {
            $dsn =
"dbi:$connection->{driver}\:${server}database=$connection->{database}";
            $dsn .= ";host=$connection->{host}" if $connection->{host};
        }
        my $dbh = DBI->connect(
            $dsn, $dbuser, $dbpass,
            {
                RaiseError       => 1,
                PrintError       => 1,
                FetchHashKeyName => NAME_lc => @_
            }
        );
        unless ( defined $dbh ) {
            throw Error::Simple(
                "DBI connect error for connection $conname: $DBI::errstr");
        }
        $connection->{dbh} = $dbh;
    }

    db_set_codepage($conname);

    if ( defined $connection->{init} ) {
        $connection->{dbh}->do( $connection->{init} );
    }

    return $connection->{dbh};
}

sub db_disconnect {
    foreach my $conname ( keys %$connections ) {
        if ( $connections->{$conname}{dbh} ) {
            $connections->{$conname}{dbh}->commit
              unless $connections->{$conname}{dbh}{AutoCommit};
            $connections->{$conname}{dbh}->disconnect;
            delete $connections->{$conname}{dbh};
        }
    }
}

my $true_regex = qr/^(?:y(?:es)?|on|1|)$/i;

sub on_off {
    return 1 if $_[0] && $_[0] =~ $true_regex;
}

sub nl2br {
    $_[0] =~ s/\r?\n/\%BR\%/g;
    return $_[0];
}

=begin TML

protectValue($text): Returns =$text= value modified in a way that
prevents it from further processing.

=cut

sub protectValue {
    my $val = shift;
    $val =~ s/(.)/\.$1/gs;
    $val =~ s/\\(n|r)/\\\\$1/gs;
    $val =~ s/\n/\\n/gs;
    $val =~ s/\r/\\r/gs;
    $val = CGI::escapeHTML($val);
    return "${protectStart}${val}${protectEnd}";
}

sub unprotectValue {
    my $val      = shift;
    my $cgiQuery = Foswiki::Func::getCgiQuery();
    $val = $cgiQuery->unescapeHTML($val);
    $val =~ s/(?<!\\)\\n/\n/gs;
    $val =~ s/(?<!\\)\\r/\r/gs;
    $val =~ s/\\\\(n|r)/\\$1/gs;
    $val =~ s/\.(.)/$1/gs;
    return $val;
}

sub query_params {
    my $param_str = shift;

    my %params    = Foswiki::Func::extractParameters($param_str);
    my @list2hash = qw(unquoted protected multivalued);

    foreach my $param (@list2hash) {
        if ( defined $params{$param} ) {
            $params{$param} = { map { $_ => 1 } split " ", $params{$param} };
        }
        else {
            $params{$param} = {};
        }
    }

    return %params;
}

sub newQID {
    $query_id++;
    return "DBI_CONTENT$query_id";
}

=begin TML

   $ wikiErrMsg(@msg): Use it for presenting error messages in a uniform way.

=cut

sub wikiErrMsg {
    return "<span class='foswikiAlert'>" . join( "", @_ ) . "</span>";
}

sub registerQuery {
    my ( $qid, $params ) = @_;
    if ( $params->{subquery} ) {
        $queries{$qid}{subquery} = $params->{subquery};
        $subquery_map{ $params->{subquery} } = $qid;
        return "";
    }
    return "\%$qid\%";
}

sub do_allowed {
    my ($conname) = @_;
}

sub storeDoQuery {
    my ( $param_str, $content ) = @_;
    my %params;
    my $conname;

    %params  = query_params($param_str);
    $conname = $params{_DEFAULT};

    return wikiErrMsg("$conname DBI connection is not defined.")
      unless defined $connections->{$conname};

    my $connection = $connections->{$conname};

    my $section =
"$Foswiki::Plugins::SESSION->{webName}.$$Foswiki::Plugins::SESSION->{topicName}";
    $section = "default"
      unless defined( $connection->{allow_do} )
          && defined( $connection->{allow_do}{$section} );
    my $allow =
         defined( $connection->{allow_do} )
      && defined( $connection->{allow_do}{$section} )
      && ref( $connection->{allow_do}{$section} ) eq 'ARRAY'
      ? $connection->{allow_do}{$section}
      : [];
    my $allowed = 0;

    my $curUser = Foswiki::Func::getWikiUserName();
    foreach my $entity (@$allow) {
        if ( $entity =~ /Group$/ ) {

            # $entity is a group
            $allowed = userIsInGroup( $curUser, $entity );
        }
        else {
            $entity =
              Foswiki::Func::userToWikiName(
                Foswiki::Func::wikiToUserName($entity), 0 );
            $allowed = ( $curUser eq $entity );
        }
        last if $allowed;
    }

    return wikiErrMsg("You are not allowed to modify this DB ($section).")
      unless $allowed;

    my $qid = newQID;

    unless ( defined $content ) {
        if ( defined $params{topic}
            && Foswiki::Func::topicExists( undef, $params{topic} ) )
        {
            $content =
              Foswiki::Func::readTopicText( undef, $params{topic}, undef, 1 );
            if ( defined $params{script} ) {
                return wikiErrMsg(
                    "%<nop>DBI_DO% script name must be a valid identifier")
                  unless $params{script} =~ /^\w\w*$/;
                if ( $content =~
                    /%DBI_CODE{"$params{script}"}%(.*?)%DBI_CODE%/s )
                {
                    $content = $1;
                }
                else {
                    undef $content;
                }
                if ( defined $content ) {
                    $content =~ s/^\s*%CODE{.*?}%(.*)%ENDCODE%\s*$/$1/s;
                    $content =~ s/^\s*<pre>(.*)<\/pre>\s*$/$1/s;
                }
            }
        }
        return wikiErrMsg("No code defined for this %<nop>DBI_DO% variable")
          unless defined $content;
    }

    $queries{$qid}{params}     = \%params;
    $queries{$qid}{connection} = $connection;
    $queries{$qid}{type}       = "do";
    $queries{$qid}{code}       = $content;
    my $script_name =
      $params{script} ? $params{script}
      : (
        $params{name} ? $params{name}
        : (
            $params{subquery} ? $params{subquery}
            : "dbi_do_script"
        )
      );
    $queries{$qid}{script_name} =
      $params{topic} ? "$params{topic}\:\:$script_name" : $script_name;

    return registerQuery( $qid, \%params );
}

sub storeQuery {
    my ( $param_str, $content ) = @_;
    my %params;
    my $conname;

    %params  = query_params($param_str);
    $conname = $params{_DEFAULT};

    return wikiErrMsg("$conname DBI connection is not defined.")
      unless defined $connections->{$conname};

    my $qid = newQID;

    $queries{$qid}{params}     = \%params;
    $queries{$qid}{connection} = $conname;
    $queries{$qid}{type}       = "query";
    $queries{$qid}{_nesting}   = 0;

    my $content_kwd = qr/\n\.(head(?:er)?|body|footer)\s*/s;

    my %map_kwd = ( head => header => );

    my @content = split $content_kwd, $content;

    my $statement = shift @content;

    for ( my $i = 1 ; $i < @content ; $i += 2 ) {
        $content[$i] =~ s/\n*$//s;
        $content[$i] =~ s/\n/ /gs;
        $content[$i] =~ s/(?<!\\)\\n/\n/gs;
        $content[$i] =~ s/\\\\n/\\n/gs;
        my $kwd = $map_kwd{ $content[ $i - 1 ] } || $content[ $i - 1 ];
        $queries{$qid}{$kwd} = $content[$i];
    }

    $queries{$qid}{statement} = $statement;

    return registerQuery( $qid, \%params );
}

sub storeCallQuery {
    my ($param_str) = @_;
    my %params;

    my $qid = newQID;

    %params                  = Foswiki::Func::extractParameters($param_str);
    $queries{$qid}{columns}  = \%params;
    $queries{$qid}{call}     = $params{_DEFAULT};
    $queries{$qid}{type}     = 'query';
    $queries{$qid}{_nesting} = 0;

    return "\%$qid\%";
}

sub dbiCode {
    my ( $param_str, $content ) = @_;
    my %params;

    %params = Foswiki::Func::extractParameters($param_str);

    unless ( $content =~ /^\s*%CODE{.*?}%(.*)%ENDCODE%\s*$/s ) {
        $content = "<pre>$content</pre>";
    }

    return <<EOT;
<table width=\"100\%\" border=\"0\" cellspacing="5px">
  <tr>
    <td nowrap> *Script name* </td>
    <td> =$params{_DEFAULT}= </td>
  </tr>
  <tr valign="top">
    <td nowrap> *Script code* </td>
    <td> $content </td>
  </tr>
</table>
EOT
}

=begin TML

expandColumns($text, $dbRecord): Expands variables within =$text=
as described in [[#ValueExpansion][DBIQueryPlugin Expansion]].

=cut

sub expandColumns {
    my ( $text, $columns ) = @_;

    if ( keys %$columns ) {
        my $regex = "\%(" . join( "|", keys %$columns ) . ")\%";
        $text =~ s/$regex/$columns->{$1}/ge;
    }
    $text =~ s/\%DBI_(?:SUBQUERY|EXEC){(.*?)}\%/&subQuery($1, $columns)/ge;

    return $text;
}

sub executeQueryByType {
    my ( $qid, $columns ) = @_;
    $columns ||= {};
    my $query = $queries{$qid};
    return (
        $query->{type} eq 'query' ? getQueryResult( $qid, $columns )
        : (
            $query->{type} eq 'do' ? doQuery( $qid, $columns )
            : wikiErrMsg("INTERNAL: Query type `$query->{type}' is unknown.")
        )
    );
}

=begin TML

subQuery($subquery, $dbRecord): Implements =%<nop>DBI_SUBQUERY%= and
=%<nop>DBI_CALL%=. =$subquery= is the name of subquery to be called.
=$dbRecord= has the same meaning as corresponding =sub= parameter.

=cut

sub subQuery {
    my %params  = query_params(shift);
    my $columns = shift;
    return executeQueryByType( $subquery_map{ $params{_DEFAULT} }, $columns );
}

sub getQueryResult {
    my ( $qid, $columns ) = @_;

    return wikiErrMsg("Subquery $qid is not defined.")
      unless defined $queries{$qid};

    my $query = $queries{$qid};
    my $params = $query->{params} || {};
    $columns ||= {};

    if ( $query->{_nesting} > MAXRECURSIONLEVEL ) {
        my $errmsg =
            "Deep recursion (more then "
          . MAXRECURSIONLEVEL
          . ") occured for subquery $params->{subquery}";
        warning $errmsg;
        throw Error::Simple($errmsg);
    }

    my $result = "";

    if ( defined $query->{call} ) {

        $result =
          getQueryResult( $subquery_map{ $query->{call} }, $query->{columns} );

    }
    else {
        $query->{_nesting}++;
        $columns->{".nesting."} = $query->{_nesting};

        my $dbh = $query->{dbh} = db_connect( $params->{_DEFAULT} );

        if ( defined $query->{header} ) {
            $result .= expandColumns( $query->{header}, $columns );
        }

        my $statement = Foswiki::Func::expandCommonVariables(
            expandColumns( $query->{statement}, $columns ),
            $Foswiki::Plugins::SESSION->{topicName},
            $Foswiki::Plugins::SESSION->{webName}
        );
        $query->{expanded_statement} = $statement;

        my $sth = $dbh->prepare($statement);
        $sth->execute;

        my $fetched = 0;
        while ( my $row = $sth->fetchrow_hashref ) {

            $fetched++;

            # Prepare row for output;
            foreach my $col ( keys %$row ) {
                if ( $col =~ /\s/ ) {
                    ( my $out_col = $col ) =~ s/\s/_/;
                    $row->{$out_col} = $row->{$col};
                    delete $row->{$col};
                    $col = $out_col;
                }
                $row->{$col} = '_NULL_' unless defined $row->{$col};
                $row->{$col} = nl2br( CGI::escapeHTML( $row->{$col} ) )
                  unless defined $params->{unquoted}{$col};
                $row->{$col} = protectValue( $row->{$col} )
                  if $params->{protected}{$col};
            }

            my $all_columns = { %$columns, %$row };
            my $out = expandColumns( $query->{body}, $all_columns );
            $result .= $out;
        }

        if ( $fetched > 0 || $query->{_nesting} < 2 ) {
            if ( defined $query->{footer} ) {
                $result .= expandColumns( $query->{footer}, $columns );
            }
        }
        else {

            # Avoid any output for empty recursively called subqueries.
            $result = "";
        }

        $query->{_nesting}--;
    }

    return $result;
}

sub doQuery {
    my ( $qid, $columns ) = @_;

    my $query  = $queries{$qid};
    my $params = $query->{params} || {};
    my $rc     = "";
    $columns ||= {};

    my %multivalued;
    if ( defined $params->{multivalued} ) {
        %multivalued = %{ $params->{multivalued} };
    }

    # Preparing sub() code.
    my $dbh = $query->{dbh} = db_connect( $params->{_DEFAULT} );
    my $cgiQuery = Foswiki::Func::getCgiQuery();
    my $sub_code = <<EOC;
sub {
    my (\$dbh, \$cgiQuery, \$varParams, \$dbRecord) = \@_;
    my \@params = \$cgiQuery->param;
    my \%httpParams; # = %{\$cgiQuery->Vars};
    foreach my \$param (\@params) {
	my \@val = \$cgiQuery->param(\$param);
	\$httpParams{\$param} = (\$multivalued{\$param} || (\@val > 1)) ? \\\@val : \$val[0];
    }
    my \$rc = "";

#line 1,"$query->{script_name}"
    $query->{code}

    return \$rc;
}
EOC

    my $sub = eval $sub_code;
    return wikiErrMsg($@) if $@;
    $rc = $sub->( $dbh, $cgiQuery, $params, $columns );

    return $rc;
}

sub handleQueries {
    foreach my $qid ( sort keys %queries ) {
        my $query = $queries{$qid};
        try {
            $query->{result} = executeQueryByType($qid)
              unless $query->{subquery};
        }
        catch Error::Simple with {
            my $err = shift;
            warning $err->{-text};
            my $query_text = "";
            if ( defined $query->{expanded_statement} ) {
                $query_text = "<br><pre>$query->{expanded_statement}</pre>";
            }
            if (DEBUG) {
                $query->{result} =
                  wikiErrMsg( "<pre>", $err->stacktrace, "</pre>",
                    $query_text );
            }
            else {
                $query->{result} = wikiErrMsg("$err->{-text}$query_text");
            }
        }
        otherwise {
            warning
"There is a problem with QID $qid on connection $queries{$qid}{connection}";
            my $errstr;
            if ( defined $queries{$qid}{dbh} ) {
                $errstr = $queries{$qid}{dbh}->errstr;
            }
            else {
                $errstr = $DBI::errstr;
            }
            warning "DBI Error for query $qid: $errstr";
            $query->{result} = wikiErrMsg("DBI Error: $errstr");
        };
    }
}

my $level = 0;

sub processPage {

    $level++;

    # This is the place to define customized tags and variables
    # Called by Foswiki::handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;
    my $doHandle = 0;
    $_[0] =~ s/%DBI_VERSION%/$VERSION/gs;
    if ( $_[0] =~ s/%DBI_DO{(.*?)}%(?:(.*?)%DBI_DO%)?/storeDoQuery($1, $2)/ges )
    {
        $doHandle = 1;
    }
    $_[0] =~ s/\%DBI_CODE{(.*?)}%(.*?)\%DBI_CODE%/&dbiCode($1, $2)/ges;
    if ( $_[0] =~ s/%DBI_QUERY{(.*?)}%(.*?)%DBI_QUERY%/storeQuery($1, $2)/ges )
    {
        $doHandle = 1;
    }
    if ( $_[0] =~ s/%DBI_CALL{(.*?)}%/storeCallQuery($1)/ges ) {
        $doHandle = 1;
    }
    if ($doHandle) {
        handleQueries;
        $_[0] =~ s/%(DBI_CONTENT\d+)%/$queries{$1}{result}/ges;
    }

    # Do not disconnect from databases if processing inclusions.

    $level--;

    db_disconnect if $level < 1;
}

1;
__END__

Author: Vadim Belman, voland@lflat.org

Copyright (C) 2005-2006 Vadim Belman, voland@lflat.org
Copyright (C) 2010 Foswiki Contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html
