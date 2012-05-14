package Review;
use strict;

use DBI;

#FIXME - put the class data (db name, table names, etc) in TWiki.cfg

# class data

my $reviewTable    = "reviews";
my $tempTable      = "temp";
my $tempOutTable   = "tempout";
my $tempCountTable = "tempcount";
my $tempBestTable  = "tempbest";
my $dataBase       = "dbi:mysql:Peer";
my $dbUsername     = "sjrmysql";
my $dbPassword     = "sjrmysql";

## the static (class) functions (independent of review object)

sub rvOpen {
    my $res;
    eval { $res = DBI->connect( $dataBase, $dbUsername, $dbPassword ); };

    # check whether the connect failed!
    return $res;
}

sub rvClose {
    my $dbh = shift;
    $dbh->disconnect() if $dbh;
    return 1;
}

## object constructor example with inheritance
#sub new {
#	my $proto = shift;
#	my $class = ref($proto) || $proto;
#	my $self  = {};
#	$self->{Reviewer}   = "";
#	$self->{Topic}      = "";
#	$self->{TopicRev}   = "";
#	$self->{DateTime}   = "";
#	$self->{Notify}     = 0;
#	$self->{Quality}    = 0;
#	$self->{Relevance}  = 0;
#	$self->{Comment}    = "";
#	bless ($self, $class);
#	return $self;
#}

#=====================================
sub rvAdd {
    my $dbh    = shift;
    my @params = @_;
    my $error  = "";
    my @row    = ();

    #prepare and execute SQL statement
    my $sqlstatement = "INSERT $reviewTable VALUES(";
    $sqlstatement .= "'$params[0]',";
    $sqlstatement .= "'$params[1]',";
    $sqlstatement .= "$params[2],";
    $sqlstatement .= "$params[3],";
    $sqlstatement .= "$params[4],";
    $sqlstatement .= "$params[5],";
    $sqlstatement .= "$params[6],";
    $sqlstatement .= "$params[7],";
    $sqlstatement .= "'$params[8]',";
    $sqlstatement .= "NOW());";

    &TWiki::Func::writeDebug("Review db add: sql is $sqlstatement");

    my $sth = $dbh->prepare($sqlstatement);
    $sth->execute || die "Could not execute SQL statement ... maybe invalid?";

    return $error;
}

#=====================================
sub rvStats {
    my $dbh          = shift;
    my $type         = shift;
    my $limit        = shift;
    my $sth          = "";
    my @row          = ();
    my $sqlstatement = "";
    my @topicList    = ();
    my @rvResult     = ();

    #&TWiki::Func::writeDebug( "Review stats: start" );

    #####do count
    if ( $type eq 'count' ) {
        $sqlstatement = qq{
		SELECT COUNT(*)
		FROM $reviewTable
		};

        $sth = $dbh->prepare($sqlstatement);
        $sth->execute
          || die "Could not execute SQL statement ... maybe invalid?";

        @row = $sth->fetchrow_array;
        return $row[0];
    }
    #####do rvBestTen
    elsif ( $type eq 'bestten' ) {
        $sqlstatement = qq{
		CREATE TEMPORARY TABLE $tempBestTable
		(Topic VARCHAR(255),
		Quality INT,
		Metric INT)
		};

        $sth = $dbh->prepare($sqlstatement);
        $sth->execute
          || die "Could not execute SQL statement ... maybe invalid?";

        my $item = "";

        $sqlstatement = qq{
		INSERT INTO $tempBestTable 
		SELECT Topic, SUM(Quality)/COUNT(*), SUM(Quality * Relevance)/COUNT(*) 
		FROM $reviewTable 
		GROUP BY Topic
		};

        $sth = $dbh->prepare($sqlstatement);
        $sth->execute
          || die "Could not execute SQL statement ... maybe invalid?";

        $sqlstatement = qq{
		SELECT Topic, Quality
		FROM $tempBestTable
		ORDER BY Metric DESC 
		LIMIT $limit
		};

        $sth = $dbh->prepare($sqlstatement);
        $sth->execute
          || die "Could not execute SQL statement ... maybe invalid?";

        while ( @row = $sth->fetchrow_array ) {
            push( @rvResult, $row[1] );
            push( @rvResult, $row[0] );
        }

        $sqlstatement = qq{
		DROP TABLE $tempBestTable
		};

        $sth = $dbh->prepare($sqlstatement);
        $sth->execute
          || die "Could not execute SQL statement ... maybe invalid?";

        return @rvResult;
    }
    #####do rvMostTen
    elsif ( $type eq 'mostten' ) {
        $sqlstatement = qq{
		CREATE TEMPORARY TABLE $tempCountTable 
		(Topic VARCHAR(255),
		Count INT)
		};

        $sth = $dbh->prepare($sqlstatement);
        $sth->execute
          || die "Could not execute SQL statement ... maybe invalid?";

        my $item = "";

        $sqlstatement = qq{
		INSERT INTO $tempCountTable 
		SELECT Topic, COUNT(*) 
		FROM $reviewTable 
		GROUP BY Topic
		};

        $sth = $dbh->prepare($sqlstatement);
        $sth->execute
          || die "Could not execute SQL statement ... maybe invalid?";

        $sqlstatement = qq{
		SELECT Topic, Count
		FROM $tempCountTable
		ORDER BY Count DESC 
		LIMIT $limit
		};

        $sth = $dbh->prepare($sqlstatement);
        $sth->execute
          || die "Could not execute SQL statement ... maybe invalid?";

        while ( @row = $sth->fetchrow_array ) {
            push( @rvResult, $row[1] );
            push( @rvResult, $row[0] );
        }

        $sqlstatement = qq{
		DROP TABLE $tempCountTable
		};

        $sth = $dbh->prepare($sqlstatement);
        $sth->execute
          || die "Could not execute SQL statement ... maybe invalid?";

        return @rvResult;
    }
    #####do rvUserTen
    elsif ( $type eq 'userten' ) {
        $sqlstatement = qq{
		CREATE TEMPORARY TABLE $tempCountTable 
		(Topic VARCHAR(255),
		Count INT)
		};

        $sth = $dbh->prepare($sqlstatement);
        $sth->execute
          || die "Could not execute SQL statement ... maybe invalid?";

        my $item = "";

        #load tempcount table
        $sqlstatement = qq{
		INSERT INTO $tempCountTable 
		SELECT Reviewer, COUNT(*) 
		FROM $reviewTable 
		GROUP BY Reviewer 
		};

        $sth = $dbh->prepare($sqlstatement);
        $sth->execute
          || die "Could not execute SQL statement ... maybe invalid?";

        $sqlstatement = qq{
		SELECT Topic, Count
		FROM $tempCountTable
		ORDER BY Count DESC 
		LIMIT $limit
		};

        $sth = $dbh->prepare($sqlstatement);
        $sth->execute
          || die "Could not execute SQL statement ... maybe invalid?";

        while ( @row = $sth->fetchrow_array ) {
            push( @rvResult, $row[1] );
            push( @rvResult, $row[0] );
        }

        $sqlstatement = qq{
		DROP TABLE $tempCountTable
		};

        $sth = $dbh->prepare($sqlstatement);
        $sth->execute
          || die "Could not execute SQL statement ... maybe invalid?";

        return @rvResult;
    }

    #$rvCount, @rvBestTen, @rvMostTen, @rvUserTen
}

#=====================================
sub rvRating {
    my $dbh          = shift;
    my $sth          = "";
    my @row          = ();
    my @list         = ();
    my $sqlstatement = "";

    my $itemType = getItemType(@_);    #ie "Reviewer" or "Topic"

    my ( $where, $error ) = makeWhere(@_);    #FIXME - add error handling

    &makeTempOut( $dbh, $itemType, $where );

    #&TWiki::Func::writeDebug( "Review rating: start" );
    #&TWiki::Func::writeDebug( "Review rating: sql is $sqlstatement" );

    #get sorted output
    $sqlstatement = qq{
	SELECT ROUND(AVG(Quality))
	FROM $tempOutTable
	};

    $sth = $dbh->prepare($sqlstatement);
    $sth->execute || die "Could not execute SQL statement ... maybe invalid?";

    @row = $sth->fetchrow_array;

    $sqlstatement = qq{
	DROP TABLE $tempOutTable
	};
    $sth = $dbh->prepare($sqlstatement);
    $sth->execute || die "Could not execute SQL statement ... maybe invalid?";

    return ("$row[0]");
}

#=====================================
sub rvList {
    my $dbh          = shift;
    my $sth          = "";
    my @row          = ();
    my @list         = ();
    my $sqlstatement = "";

    my $itemType = getItemType(@_);    #ie "Reviewer" or "Topic"

    my ( $where, $error ) = makeWhere(@_);    #FIXME - add error handling

    my $order = makeOrder(@_);

    &makeTempOut( $dbh, $itemType, $where );

    #get sorted output
    $sqlstatement = qq{
	SELECT *
	FROM $tempOutTable
	ORDER BY $order $itemType
	};

    $sth = $dbh->prepare($sqlstatement);
    $sth->execute || die "Could not execute SQL statement ... maybe invalid?";

    while ( @row = $sth->fetchrow_array ) {

        #&TWiki::Func::writeDebug( "Review inner loop: row is @row\n" );

        #initialize review object
        my $review = {};
        $review->{Reviewer}     = ( $row[0] );
        $review->{Topic}        = ( $row[1] );
        $review->{TopicRev}     = ( $row[2] );
        $review->{Notify}       = ( $row[3] );
        $review->{Quality}      = ( $row[4] );
        $review->{Relevance}    = ( $row[5] );
        $review->{Timeliness}   = ( $row[6] );
        $review->{Completeness} = ( $row[7] );
        $review->{Comment}      = ( $row[8] );
        $review->{DateTime}     = ( $row[9] );
        bless($review)
          ; #FIXME - add 2nd param to specify class - or inheritance not supported
        push( @list, $review );
    }

    #&TWiki::Func::writeDebug( "Review topicview: list is @list\n" );

    $sqlstatement = qq{
	DROP TABLE $tempOutTable
	};

    return (@list);
}

## private functions (only callable from this object)

#=====================================
sub makeTempOut {
    my $dbh          = shift;
    my $itemType     = shift;
    my $where        = shift;
    my $sth          = "";
    my @row          = ();
    my @list         = ();
    my $sqlstatement = "";
    my @itemList     = ();
    my $item         = "";

    #&TWiki::Func::writeDebug( "Review: makeTempOut: itemType is $itemType\n" );
    #&TWiki::Func::writeDebug( "Review: makeTempOut: where is $where\n" );

    #lock table
    $sqlstatement = qq{
	LOCK TABLES $reviewTable READ
	};

    $sth = $dbh->prepare($sqlstatement);
    $sth->execute || die "Could not execute SQL statement ... maybe invalid?";

    #get item list: reviewers of topic or topics reviewed by user
    $sqlstatement = qq{
	SELECT DISTINCT $itemType 
	FROM $reviewTable
	WHERE $where
	};

    $sth = $dbh->prepare($sqlstatement);
    $sth->execute || die "Could not execute SQL statement ... maybe invalid?";

    #output database results
    while ( @row = $sth->fetchrow_array ) {
        push( @itemList, $row[0] );
    }

    #&TWiki::Func::writeDebug( "Review: $itemType is @itemList\n" );

    #create output table
    $sqlstatement = qq{
	CREATE TEMPORARY TABLE $tempOutTable 
	(Reviewer VARCHAR(255) NOT NULL,
	Topic VARCHAR(255) NOT NULL,
	TopicRev INT,
	Notify INT NOT NULL,
	Quality INT NOT NULL,
	Relevance INT,
	Completeness INT,
	Timeliness INT,
	Comment VARCHAR(255),
	DateTime DATETIME)
	};

    $sth = $dbh->prepare($sqlstatement);
    $sth->execute || die "Could not execute SQL statement ... maybe invalid?";

    #create temp table
    $sqlstatement = qq{
	CREATE TEMPORARY TABLE $tempTable 
	(Reviewer VARCHAR(255) NOT NULL,
	Topic VARCHAR(255) NOT NULL,
	TopicRev INT,
	Notify INT NOT NULL,
	Quality INT NOT NULL,
	Relevance INT,
	Completeness INT,
	Timeliness INT,
	Comment VARCHAR(255),
	DateTime DATETIME)
	};

    $sth = $dbh->prepare($sqlstatement);
    $sth->execute || die "Could not execute SQL statement ... maybe invalid?";

    foreach $item (@itemList) {
        $sqlstatement = qq{
		DELETE FROM $tempTable
		};

        $sth = $dbh->prepare($sqlstatement);
        $sth->execute
          || die "Could not execute SQL statement ... maybe invalid?";

        #load temp table with single reviewer info
        $sqlstatement = qq{
		INSERT INTO $tempTable
		SELECT *
		FROM $reviewTable
		WHERE $where
		&& $itemType='$item'
		};

        $sth = $dbh->prepare($sqlstatement);
        $sth->execute
          || die "Could not execute SQL statement ... maybe invalid?";

        #extract most recent line from temp table into output table
        $sqlstatement = qq{
		INSERT INTO $tempOutTable
		SELECT *
		FROM $tempTable
		ORDER BY DateTime DESC
		LIMIT 1
		};

        $sth = $dbh->prepare($sqlstatement);
        $sth->execute
          || die "Could not execute SQL statement ... maybe invalid?";
    }

    $sqlstatement = qq{
	UNLOCK TABLES
	};

    $sth = $dbh->prepare($sqlstatement);
    $sth->execute || die "Could not execute SQL statement ... maybe invalid?";

    $sqlstatement = qq{
	DROP TABLE $tempTable
	};

    $sth = $dbh->prepare($sqlstatement);
    $sth->execute || die "Could not execute SQL statement ... maybe invalid?";

    return "";

}

sub getItemType {
    my $opFormat = shift;
    my $itemType = "";

    if ( $opFormat eq "topicview" || $opFormat eq "topictherm" ) {
        $itemType = "Reviewer";
    }
    elsif ( $opFormat eq "userview" || $opFormat eq "usertherm" ) {
        $itemType = "Topic";
    }

    return ($itemType);
}

sub makeOrder {
    my $opFormat = shift;
    my $order    = "";

    if ( $opFormat eq "topicview" ) {
        $order = "TopicRev DESC ,";
    }

    return ($order);
}

sub makeWhere {

    #prepare SQL WHERE clause
    my $opFormat    = shift;
    my %selectPairs = @_;

    #makewhere - generic map of attributes to selection
    my $where  = "";
    my $key    = "";
    my $value  = "";
    my $error  = "";
    my $format = "";
    my @smkeys = keys(%selectPairs);
    foreach $key (@smkeys) {
        if ($where) { $where .= " && "; }

        #check keys (search/select by content not supported)
        if ( $key eq "Reviewer" ) {
            $format = "text";
        }
        elsif ( $key eq "Topic" ) {
            $format = "url";
        }
        elsif ( $key eq "TopicRev" ) {
            $format = "int";
        }
        elsif ( $key eq "Notify" ) {
            $format = "int";
        }
        else {
            $error = "Error: incorrect key name";
        }

        #check values & build text
        $value = $selectPairs{$key};
        if ( $format eq "text" ) {
            if ( $value =~ /^[a-zA-Z0-9]+$/ ) {
                $where .= "$key='$value'";
            }
            else {
                $error = "Error: incorrect value type (text)";
            }
        }
        elsif ( $format eq "url" ) {
            if ( $value =~ /^[^\s]+$/ ) {
                $where .= "$key='$value'";
            }
            else {
                $error = "Error: incorrect value type (url)";
            }
        }
        elsif ( $format eq "int" ) {
            if ( $value =~ /^\d+$/ ) {
                $where .= "$key=$value";
            }
            else {
                $error = "Error: incorrect value type (int)";
            }
        }

        #&TWiki::Func::writeDebug( "Review: makeWhere: key is $key\n" );
        #&TWiki::Func::writeDebug( "Review: makeWhere: format is $format\n" );
        #&TWiki::Func::writeDebug( "Review: makeWhere: value is $value\n" );
    }

    #&TWiki::Func::writeDebug( "Review: makeWhere: where is $where\n" );
    #&TWiki::Func::writeDebug( "Review: makeWhere: error is $error\n" );

    return ( $where, $error );
}

# FIXME - write it
sub rvStore {
    my $self = shift;
    return 1;
}

# FIXME - write it
sub rvDelete {
    my $self = shift;
    return 1;
}

# FIXME - delete this?
sub getSelectMode {
    my $self = shift;
    return %{ $self->{SelectMode} };
}

# FIXME - write it
sub sortMode {
    my $self = shift;
    if (@_) { @{ $self->{SortMode} } = @_ }
    return @{ $self->{SortMode} };
}

######## HERE ARE THE REVIEW OBJECT METHODS ########

sub reviewer {
    my $self = shift;
    if (@_) { $self->{Reviewer} = shift }
    return $self->{Reviewer};
}

sub topic {
    my $self = shift;
    if (@_) { $self->{Topic} = shift }
    return $self->{Topic};
}

sub topicRev {
    my $self = shift;
    if (@_) { $self->{TopicRev} = shift }
    return $self->{TopicRev};
}

sub dateTime {
    my $self = shift;
    if (@_) { $self->{DateTime} = shift }
    return $self->{DateTime};
}

sub epSecs {
    my $self   = shift;
    my $dbh    = shift;
    my @row    = ();
    my $epSecs = 0;
    if (@_) {
        $epSecs = shift;

        #prepare and execute SQL statement
        my $sqlstatement = "SELECT FROM_UNIXTIME( $epSecs )";
        my $sth          = $dbh->prepare($sqlstatement);
        $sth->execute
          || die "Could not execute SQL statement ... maybe invalid?";

        #load database results
        @row = $sth->fetchrow_array;
        $self->{DateTime} = $row[0];
    }
    else {
        my $dTime = $self->{DateTime};

        #prepare and execute SQL statement
        my $sqlstatement = "SELECT UNIX_TIMESTAMP( '$dTime' )";
        my $sth          = $dbh->prepare($sqlstatement);
        $sth->execute
          || die "Could not execute SQL statement ... maybe invalid?";

        #load database results
        @row    = $sth->fetchrow_array;
        $epSecs = $row[0];
    }
    return $epSecs;
}

sub notify {
    my $self = shift;
    if (@_) { $self->{Notify} = shift }
    return $self->{Notify};
}

sub quality {
    my $self = shift;
    if (@_) { $self->{Quality} = shift }
    return $self->{Quality};
}

sub relevance {
    my $self = shift;
    if (@_) { $self->{Relevance} = shift }
    return $self->{Relevance};
}

sub comment {
    my $self = shift;
    if (@_) { $self->{Comment} = shift }
    return $self->{Comment};
}

1;    # so the require or use succeeds
