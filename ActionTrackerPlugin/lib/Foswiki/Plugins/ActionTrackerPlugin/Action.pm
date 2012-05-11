# See bottom of file for copyright and license information

=begin TML

---+ package Foswiki::Plugins::ActionTrackerPlugin::Action

Object that represents a single action

Fields:
   * web:           Web the action was found in
   * topic:         Topic the action was found in
   * ACTION_NUMBER: The number of the action in the topic (deprecated)
   * text:          The text of the action
   * who:           The person responsible for the action
   * due:           When the action is due
   * notify:        List of people to notify when the action changes
   * uid:           Unique identifier for the action
   * creator:       Who created the action
   * created:       When the action was created
   * closer:        Who closed the action
   * closed:        When the action was closed

=cut

package Foswiki::Plugins::ActionTrackerPlugin::Action;

use strict;
use integer;

use CGI ();
use JSON;
use Text::Soundex ();
use Time::ParseDate ();

use Foswiki::Func ();
use Foswiki::Attrs ();

use Foswiki::Plugins::ActionTrackerPlugin::AttrDef ();
use Foswiki::Plugins::ActionTrackerPlugin::Format ();

our $now = time();

# Options for parsedate
# Note that it is intentional that we use GMT no matter what the server
# is setup for or which time zone we are in
# We want all dates the user enters to remain unconverted. The date you
# enter must always be the date you see. By using GMT when both parsing
# and formatting we ensure that no conversion happens.
my %pdopt = ( NO_RELATIVE => 1, DATE_REQUIRED => 1, WHOLE => 1, GMT => 1, UK => 1 );

# Types of standard attributes. The 'noload' type tells us
# not to load the hash from %ACTION attributes, and the 'nomatch' type
# tells us not to consider it during match operations.
# Types are defined as a base type and a comma-separated list of
# format attributes. Two meta-type components 'noload' and 'nomatch'
# are defined. If an attribute is defined 'noload' no attempt will
# be made to load a value for it when the action is created. If it
# is defined 'nomatch' then the attribute will be ignored in match
# expressions.
my $dw        = 16;
my $nw        = 35;
my %basetypes = (
    changedsince => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'noload'
    ),
    closed => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'date', size => $dw, match => 1
    ),
    closer => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'names', size => $nw, match => 1
    ),
    created => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'date', size => $dw, match => 1
    ),
    creator => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'names', size => $nw, match => 1
    ),
    dollar => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'noload'
    ),
    due => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'date', size => $dw, match => 1
    ),
    edit => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'noload'
    ),
    format => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'noload'
    ),
    header => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'noload'
    ),
    late => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'noload'
    ),
    n => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'noload'
    ),
    nop => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'noload'
    ),
    notify => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'names', size => $nw, match => 1
    ),
    percnt => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'noload'
    ),
    quot => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'noload'
    ),
    sort => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'noload'
    ),
    state => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'select', size => 1, match => 1, defineable => 1, values => [ 'open', 'closed' ]
    ),
    text => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'noload', match => 1, merge => 1
    ),
    topic => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'noload', match => 1
    ),
    uid => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'text', size => $nw, match => 1
    ),
    web => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'noload', match => 1
    ),
    who => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'names', size => $nw, match => 1
    ),
    within => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'noload', match => 1
    ),
    ACTION_NUMBER => new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
        type => 'noload'
    ),
);

my %types = %basetypes;

# PUBLIC Constructor
sub new {
    my ( $class, $web, $topic, $number, $attrs, $descr ) = @_;
    my $this = {};

    my $attr = new Foswiki::Attrs( $attrs, 1 );

    # We always have a state, and if it's not defined in the
    # attribute set, and the closed attribute isn't defined,
    # then it takes the value of the first option in the
    # enum for the state attribute. If the closed attribute is
    # defined it takes the last enum.
    $this->{state} = $attr->{state};
    if ( !defined( $this->{state} ) ) {
        if ( $attr->{closed} ) {
            $this->{state} = 'closed';
        }
        else {
            $this->{state} = $types{state}->firstSelect();
        }
    }

    # conditionally load field values, interpreting them
    # according to their type.
    foreach my $key ( keys %$attr ) {
        my $type = getBaseType($key) || 'noload';
        my $val = $attr->{$key};
        if ( $type eq 'names' && defined($val) ) {
            my @names = split( /[,\s]+/, $val );
            foreach my $n (@names) {
                $n = _canonicalName($n);
            }
            $this->{$key} = join( ', ', @names );
        }
        elsif ( $type eq 'date' ) {
            if ( defined($val) ) {
                if ( $key eq 'due' && $val !~ /\W/ ) {

                    # special case of an empty date
                    $this->{$key} = '';
                }
                else {
                    $this->{$key} = Time::ParseDate::parsedate( $val, %pdopt );
                }
            }
        }
        elsif ( $type !~ 'noload' ) {

            # treat as plain string; text, select
            $this->{$key} = $attr->{$key};
        }
    }

    # do these last so they override and attribute values
    $this->{web}           = $web;
    $this->{topic}         = $topic;
    $this->{ACTION_NUMBER} = $number;

    $descr =~ s/^\s+//o;
    $descr =~ s/\s+$//o;
    $descr =~ s/\r+//o;

    # Translate newlines in the description to XHTML tags
    $descr =~ s/\n\n/<p \/>/gos;
    $descr =~ s/\n/<br \/>/gos;
    $descr =~ s/%(ACTION\w*)\{/%<nop>$1\{/gso;

    $this->{text} = $descr;

    return bless( $this, $class );
}

# PUBLIC STATIC extend the range of types accepted by actions.
# Return undef if everything went OK, or error message if not.
# The range of types is extended statically; once extended, there's
# no way to unextend them.
# Format of a type def is described in ActionTrackerPlugin.txt
sub extendTypes {
    my $defs = shift;
    $defs =~ s/^\s*\|//o;
    $defs =~ s/\|\s*$//o;

    foreach my $def ( split( /\s*\|\s*/, $defs ) ) {
        if ( $def =~ m/^\s*(\w+)\s*,\s*(\w+)\s*(,\s*(\d+)\s*)?(,\s*(.*))?$/o ) {
            my $name   = $1;
            my $type   = $2;
            my $size   = $4;
            my $params = $6;
            my @values;
            my $exists = $types{$name};

            if ( defined($exists) && !$exists->isRedefinable() ) {
                return 'Attempt to redefine attribute \'' . $name
                  . '\' in EXTRAS';
            }
            elsif ( $type eq 'select' ) {
                @values = split( /\s*,\s*/, $params );
                foreach my $option (@values) {
                    $option =~ s/^"(.*)"$/$1/o;
                }
            }
            $types{$name} =
              new Foswiki::Plugins::ActionTrackerPlugin::AttrDef(
		  type => $type, size => $size,
		  match => 1, defineable => 1, values => \@values );
        }
        else {
            return 'Bad EXTRAS definition \'' . $def . '\' in EXTRAS';
        }
    }
    return undef;
}

# STATIC remove type extensions
sub unextendTypes {
    %types = %basetypes;
}

# PUBLIC get the base type of an attribute name i.e.
# with the formatting attributes stripped off.
sub getBaseType {
    my $vbl  = shift;
    my $type = $types{$vbl};
    if ( defined($type) ) {
        return $type->{type};
    }
    return undef;
}

# PUBLIC provided as part of the contract with Format.
sub getType {
    my ( $this, $name ) = @_;

    return $types{$name};
}

# Allocate a new UID for this action.
sub getNewUID {
    my $this = shift;

    my $workArea    = Foswiki::Func::getWorkArea('ActionTrackerPlugin');
    my $uidRegister = $workArea . '/UIDRegister';

    # Compatibility code. Upgrade existing atUidReg to plugin work area.
    if ( !-e $uidRegister && -e Foswiki::Func::getDataDir() . '/atUidReg' ) {
        my $oldReg = Foswiki::Func::getDataDir() . '/atUidReg';
        open( FH, "<$oldReg" ) or die "Reading $oldReg: $!";
        my $uid = <FH>;
        close(FH);
        open( FH, ">$uidRegister" ) or die "Writing $uidRegister: $!";
        print FH "$uid\n";
        close(FH);
        unlink $oldReg;
    }

    my $lockFile = $uidRegister . '.lock';

    # Could do this using flock but it's not guaranteed to be
    # implemented on all systems. This technique is simpler
    # and mostly works.
    # COVERAGE OFF lock file wait
    while ( -f $lockFile ) {

        # if it's more than 10 mins old something is wrong, so just ignore
        # it.
        my @s = stat($lockFile);
        if ( time() - $s[9] > 10 * 60 ) {
            Foswiki::Func::writeWarning(
                "Action Tracker Plugin: Warning: broke $lockFile");
            last;
        }
        sleep(1);
    }

    # COVERAGE ON

    open( FH, ">$lockFile" ) or die "Locking $lockFile: $!";
    print FH "locked\n";
    close(FH);

    my $lastUID = 0;
    if ( -f $uidRegister ) {
        open( FH, "<$uidRegister" ) or die "Reading $uidRegister: $!";
        $lastUID = <FH>;
        close(FH);
    }

    my $uid = $lastUID + 1;
    open( FH, ">$uidRegister" ) or die "Writing $uidRegister: $!";
    print FH "$uid\n";
    close(FH);
    unlink($lockFile) or die "Unlocking $lockFile: $!";

    $this->{uid} = sprintf( '%06d', $uid );
}

# PUBLIC when a topic containing an action is about to be saved,
# populate these fields for the action.
# Note: This will put a wrong date on closed actions if they were
# closed a long while ago, but that's life.
sub populateMissingFields {
    my $this = shift;
    my $me   = _canonicalName('me');

    if ( !defined( $this->{uid} ) || $this->{uid} eq "" ) {
        $this->getNewUID();
    }

    if ( !defined( $this->{who} ) ) {
        $this->{who} = $me;
    }

    if ( !$this->{due} ) {
        $this->{due} = 0;    # '' means 'to be decided'
    }

    if ( !defined( $this->{creator} ) ) {
        $this->{creator} = $me;
    }

    if ( !defined( $this->{created} ) ) {
        $this->{created} = $now;
    }

    if ( $this->{state} eq 'closed' ) {
        if ( !defined( $this->{closer} ) ) {
            $this->{closer} = $me;
        }
        if ( !defined( $this->{closed} ) ) {
            $this->{closed} = $now;
        }
    }
}

# PUBLIC format as an action
sub stringify {
    my $this  = shift;
    my $attrs = '';
    my $descr = '';
    foreach my $key ( sort keys %$this ) {
        my $type = $types{$key};
        if ( $key eq 'text' ) {
            $descr = $this->{text};
            $descr =~ s/^\s*(.*)\s*$/$1/os;
        }
        elsif ( defined($type) ) {
            if ( $type->{type} eq 'date' ) {
                $attrs .=
                  ' ' . $key . '="' . formatTime( $this->{$key}, 'attr' ) . '"';
            }
            elsif ( $type->{type} !~ /noload/ ) {

                # select or text; treat as plain text
                $attrs .= ' ' . $key . '="' . $this->{$key} . '"';
            }
        }
    }
    return '%ACTION{' . $attrs . ' }% ' . $descr . " %ENDACTION%";
}

# Assemble a form for an update of the given field value
sub _form {
    my ($this, $fld, $value, $input) = @_;
    return
	CGI::start_form(
	    -action => '%SCRIPTURLPATH{rest}%/ActionTrackerPlugin/update',
	    -method => 'POST')
	. CGI::hidden(-name => 'topic', -value => "$this->{web}.$this->{topic}")
	. CGI::hidden(-name => 'uid', -value => $this->{uid})
	. CGI::hidden(-name => 'field', -value => $fld)
	. CGI::hidden(-name => 'value', -value => $value)
	. $input
	. CGI::end_form();
}

# PRIVATE STATIC make a canonical name (including the web) for a user
# unless it's an email address.
sub _canonicalName {
    my $who = shift;

    return undef unless ( defined($who) );

    if ( $who !~ /([A-Za-z0-9\.\+\-\_]+\@[A-Za-z0-9\.\-]+)/ ) {
        if ( $who eq 'me' ) {
            $who = Foswiki::Func::getWikiName();
        }
	if ($who) {
	    my ($w, $t) = Foswiki::Func::normalizeWebTopicName(undef, $who);
	    $who = "$w.$t";
	}
    }
    return $who;
}

# PUBLIC For testing only, force current time to a known value
sub forceTime {
    my $tim = shift;
    $now = Time::ParseDate::parsedate($tim, %pdopt);
}

# PRIVATE get the anchor of this action
sub getAnchor {
    my $this = shift;

    my $anchor = $this->{uid};
    if ( !$anchor ) {

        # required for old actions without uids
        $anchor = 'AcTion' . $this->{ACTION_NUMBER};
    }

    return $anchor;
}

# PRIVATE STATIC format a time string
# Note that it is intentional that we use gmtime no matter what the server
# is setup for or which time zone we are in
# We want all dates the user enters to remain unconverted. The date you
# enter must always be the date you see. By using GMT when both parsing
# and formatting we ensure that no conversion happens.
sub formatTime {
    my ( $time, $format ) = @_;
    my $stime;

    # Default to time=0, which means 'to be decided'
    $time ||= 0;

    if ( !$time ) {
        $stime = '';
    }
    elsif ( $format eq 'attr' ) {
        $stime =
          Foswiki::Func::formatTime( $time, '$year-$mo-$day', 'gmtime' );
    }
    else {
        $stime = Foswiki::Func::formatTime(
            $time,
            $Foswiki::cfg{DefaultDateFormat},
            'gmtime'
        );
    }
    return $stime;
}

# PUBLIC return number of seconds to go before due date, negative if action
# is late
sub secsToGo {
    my $this = shift;

    # The ponderous test supports empty due dates, which are always treated
    # as being late
    if ( $this->{due} ) {
        return $this->{due} - $now;
    }

    # No due date, use default
    require Foswiki::Plugins::ActionTrackerPlugin::Options;
    return $Foswiki::Plugins::ActionTrackerPlugin::Options::options{DEFAULTDUE};
}

# PUBLIC return number of days to go before due date, negative if action
# is late, 0 if it's due today
sub daysToGo {
    my $this  = shift;
    my $delta = $this->secsToGo();

    # if less that 24h late, make it a day late
    if ( $delta < 0 && $delta > -( 60 * 60 * 24 ) ) {
        return -1;
    }
    else {
        return $delta / ( 60 * 60 * 24 );
    }
}

# PUBLIC true if due time is before now and not closed
sub isLate {
    my $this = shift;
    return 1 if !$this->{due};
    if ( $this->{state} eq 'closed' ) {
        return 0;
    }
    return $this->secsToGo() < 0 ? 1 : 0;
}

# PRIVATE match the passed names against the given names type field.
# The match passes if any of the names passed matches any of the
# names in the field.
sub _matchType_names {
    my ( $this, $vbl, $val ) = @_;

    return (!$this->{$vbl}) if (!$val);

    return 0 unless ( defined( $this->{$vbl} ) );

    foreach my $name ( split( /\s*,\s*/, $val ) ) {
        my $who = _canonicalName($name);

        $who =~ s/.*\.//;
        my $r;
        eval {
            $r = ( $this->{$vbl} =~ m/\b$who\b/ || $this->{$vbl} =~ m/$who$/ );
        };
        return 1 if ($r);
    }
    return 0;
}

sub _matchType_date {
    my ( $this, $vbl, $val ) = @_;
    my $cond;
    if ( $val =~ s/^([><]=?)\s*// ) {
        $cond = $1;
    }
    else {
        $cond = '==';
    }
    return 0 unless defined( $this->{$vbl} );
    my $tim = Time::ParseDate::parsedate(
        $val, DATE_REQUIRED => 1, WHOLE => 1, GMT => 1, UK => 1,
	PREFER_PAST => 1, FUZZY => 1 );
    return eval "$this->{$vbl} $cond $tim";
}

# PRIVATE match if there are at least $val days to go before
# action falls due
sub _matchField_within {
    my ( $this, $val ) = @_;
    my $signed    = ( $val =~ /^[+-]/ ) ? 1 : 0;
    my $toGoSecs  = $this->secsToGo();             # negative if past
    my $rangeSecs = $val * 60 * 60 * 24;

    if ($signed) {
        if ( $val < 0 ) {
            return $toGoSecs <= 0 && $toGoSecs >= $rangeSecs;
        }
        else {
            return $toGoSecs >= 0 && $toGoSecs <= $rangeSecs;
        }
    }
    else {

        # e.g. within="7", all actions that fall due within within 7 days
        # either side of now
        return abs($toGoSecs) <= abs($rangeSecs);
    }
}

# PRIVATE match boolean attribute "closed"
sub _matchField_closed {
    my ( $this, $val ) = @_;
    if ( $val eq '1' ) {
        return ( $this->{state} eq 'closed' );
    }
    else {

        # val is not a simple boolean, it's a date spec. Pass on to
        # date matcher.
        return $this->_matchType_date( 'closed', $val );
    }
}

# PRIVATE match attribute "due"
sub _matchField_due {
    my ( $this, $val ) = @_;
    return 1 if ( !$this->{due} );    # empty due always matches
    return $this->_matchType_date( 'due', $val );
}

# PRIVATE match boolean attribute "open"
sub _matchField_open {
    my $this = shift;
    return ( $this->{state} ne 'closed' );
}

# PRIVATE match boolean attribute "late"
sub _matchField_late {
    my $this = shift;
    return ( $this->secsToGo() < 0 && $this->{state} ne 'closed' ) ? 1 : 0;
}

# PRIVATE trap for state so we can put state="late" into attributes
sub _matchField_state {
    my ( $this, $val ) = @_;
    if ( $val eq 'late' ) {
        return ( $this->secsToGo() < 0 && $this->{state} ne 'closed' ) ? 1 : 0;
    }
    else {
        return ( eval "\$this->{state} =~ /^$val\$/" );
    }
}

# PUBLIC true if the action matches the search attributes
# The match is made either by calling a match function for the attribute
# or by comparing the value of the field with the value of the
# corresponding attribute, which is considered to be an RE.
# To match, an action must match all conditions.
sub matches {
    my ( $this, $a ) = @_;
    foreach my $attrName ( keys %$a ) {
        next if $attrName =~ /^_/;
        my $attrVal  = $a->{$attrName};
        my $attrType = getBaseType($attrName);
        my $class    = ref($this);
        if ( defined( &{ $class . "::_matchField_$attrName" } ) ) {
            # function match
            my $fn = "_matchField_$attrName";
            if ( !$this->$fn($attrVal) ) {
                return 0;
            }
        }
        elsif (defined($attrType)
            && defined( &{ $class . "::_matchType_$attrType" } ) )
        {
            my $fn = "_matchType_$attrType";
            if ( !$this->$fn( $attrName, $attrVal ) ) {
                return 0;
            }
        }
        elsif (defined($attrVal)
            && defined( $this->{$attrName} ) )
        {
            # re match
            my $r;
            eval { $r = ( $this->{$attrName} !~ m/$attrVal/ ); };
            return 0 if ($r);
        }
        else {
            return 0;
        }
    }
    return 1;
}

# PRIVATE format the given time type
sub _formatType_date {
    my ( $this, $fld, $args, $asHTML ) = @_;
    return formatTime( $this->{$fld}, 'string' );
}

# PRIVATE format the given select box type
# Contributed by Kent Dozier
sub _formatType_select {
    my ( $this, $fld, $args, $asHTML ) = @_;

    # If HTML isn't wanted, just throw back the value
    unless ( $asHTML ) {
	return (defined $this->{$fld}) ? $this->{$fld} : '';
    }

    # Turn the select into a fully populated drop down box
    my $type = $this->getType( $fld );
    my $size = $type->{size};
    my $fields = '';
    my $any_selected = 0;
    foreach my $option ( @{$type->{values}} ) {
	my $attrs = { value => $option };
	if ( defined( $this->{$fld} ) &&
	     $this->{$fld} eq $option ) {
	    $attrs->{selected} = "selected";
	    $any_selected = 1;
	}
	$fields .= CGI::option( $attrs, $option );
    }

    # If nothing was selected, add an empty selection at the top
    # That way, it can display a blank box, but can be changed.
    if (!$any_selected) {
	$fields = CGI::option({ value=>"NuLL", selected=>"selected" }, "") . $fields;
    }

    return $this->_form(
	$fld, undef,
	CGI::Select(
	    { name => $fld,
	      size => $size,
	      class => 'atp_update userval value_' .
		(defined $this->{$fld} ? $this->{$fld} : 'fw_field_not_defined'),
	    },
	    $fields ));
}

sub _formatField_formfield {
    my ( $this, $args, $asHTML ) = @_;

    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{web}, $this->{topic} );

    if ( !$meta->can('renderFormFieldForDisplay') ) {

        # 4.1 compatibility
        return Foswiki::Render::renderFormFieldArg( $meta, $args );
    }
    else {
        my $name      = $args;
        my $breakArgs = '';
        my @params    = split( /\,\s*/, $args, 2 );
        if ( @params > 1 ) {
            $name      = $params[0] || '';
            $breakArgs = $params[1] || 1;
        }
        return $meta->renderFormFieldForDisplay( $name, '$value',
            { break => $breakArgs, protectdollar => 1 } );
    }
}

# PRIVATE format the given field (takes precedence over standard
# date formatting)
sub _formatField_due {
    my ( $this, $args, $asHTML ) = @_;
    my $text = formatTime( $this->{due}, 'string' );

    if ( !$this->{due} ) {
        if ($asHTML) {
            $text ||= '&nbsp;';
            $text = CGI::span( { class => 'atpError' }, $text );
        }
    }
    elsif ( $this->isLate() ) {
        if ($asHTML) {
            $text = CGI::span( { class => 'atpWarn' }, $text );
        }
        else {
            $text .= ' (LATE)';
        }
    }
    else {
        if ($asHTML) {
            if ( $this->{state} eq 'closed' ) {
                $text = CGI::span( { class => 'atpClosed' }, $text );
            }
            else {
                $text = CGI::span( { class => 'atpOpen' }, $text );
            }
        }
    }

    return $text;
}

sub _formatField_state {
    my ( $this, $args, $asHTML ) = @_;

    return $this->{state} unless $this->{uid};

    # SMELL: assumes a prior call has loaded the options
    require Foswiki::Plugins::ActionTrackerPlugin::Options;
    return $this->{state}
      unless
        $Foswiki::Plugins::ActionTrackerPlugin::Options::options{ENABLESTATESHORTCUT};

    return $this->_formatType_select('state', $args, $asHTML);
}

# Special 'close' button field for transition between any state and 'closed'
sub _formatField_statebutton {
    my ( $this, $args, $asHTML ) = @_;
    return '' unless $asHTML;
    return '' unless $this->{uid};

    my ( $tgtState, $buttonName ) = ( 'closed', 'Close' );
    if ( $args =~ /^(.*),(.*)$/ ) {
        ( $buttonName, $tgtState ) = ( $1, $2 );
    }
    return '' if ( $this->{state} eq $tgtState );

    return $this->_form(
	'state', 'closed',
        CGI::input({
            type  => 'button',
            value => $buttonName,
            class => "atp_update"
        }));
}

# PRIVATE format text field
sub _formatField_text {
    my ( $this, $args, $asHTML, $type ) = @_;
    return $this->{text};
}

# PRIVATE format link field
sub _formatField_link {
    my ( $this, $args, $asHTML, $type ) = @_;
    my $text = '';

    if ( $asHTML && defined($type) && $type eq 'href' ) {

        # Generate a jump-to in wiki syntax
        $text =~ s/<br ?\/?>/\n/sgo;

        # Would be nice to do the goto as a button image....
        my $jump = ' '
          . CGI::a(
            {
                href =>
                  Foswiki::Func::getViewUrl( $this->{web}, $this->{topic} )
                  . '#'
                  . $this->getAnchor()
            },
            CGI::img(
                {
                    src => '%PUBURL%/%SYSTEMWEB%/DocumentGraphics/target.gif',
                    alt => '(go to action)'
                }
            )
          );
        $text .= $jump;
    } else {
	$text = Foswiki::Func::getViewUrl( $this->{web}, $this->{topic} )
                  . '#'
                  . $this->getAnchor();
    }
    return $text;
}

# PRIVATE format edit field
sub _formatField_edit {
    my ( $this, $args, $asHTML, $type ) = @_;

    if ( !$asHTML ) {

        # Can't edit from plain text
        return '';
    }

    my $skin = join( ',', ( 'action', Foswiki::Func::getSkin() ) );

    my $url = Foswiki::Func::getScriptUrl(
        $this->{web}, $this->{topic}, 'edit',
        skin       => $skin,
        atp_action => $this->getAnchor(),
        nowysiwyg  => 1,                    # SMELL: could do better!
        t          => time()
    );
    $url =~ s/%2c/,/g;
    my $attrs = { href => $url, title => 'Edit', class => "atp_edit ui-icon ui-icon-pencil" };

    return CGI::a( $attrs, 'edit' );
}

# PUBLIC see if this other action matches according to fuzzy
# rules. Return a number indicating the quality of the match, which
# is the sum of:
# action number identical - 3
# who identical - 2
# notify identical - 2
# due identical - 1
# state identical - 1
# text identical - length of matching text
# text sounds match - number of matching sounds
# This is deprecated but is retained for support of non-UID actions.
sub fuzzyMatches {
    my ( $this, $old ) = @_;
    my $sum = 0;

    # COVERAGE OFF fuzzy match with uid
    if ( defined( $this->{uid} ) ) {
        if ( defined( $old->{uid} ) && $this->{uid} eq $old->{uid} ) {
            return 100;
        }
        return 0;
    }

    # identical text
    if ( $this->{text} =~ m/^\Q$old->{text}\E/ ) {
        $sum += length( $this->{text} );
    }
    else {
        $sum += _partialMatch( $old->{text}, $this->{text} ) * 4;
    }
    if ( $this->{ACTION_NUMBER} == $old->{ACTION_NUMBER} ) {
        $sum += 3;    # 50;
    }
    if (   defined( $this->{notify} )
        && defined( $old->{notify} )
        && $this->{notify} eq $old->{notify} )
    {
        $sum += 2;
    }
    if (   defined( $this->{who} )
        && defined( $old->{who} )
        && $this->{who} eq $old->{who} )
    {
        $sum += 2;
    }
    if (   defined( $this->{due} )
        && defined( $old->{due} )
        && $this->{due} == $old->{due} )
    {
        $sum += 1;
    }
    if ( $this->{state} eq $old->{state} ) {
        $sum += 1;
    }

    # COVERAGE ON
    return $sum;
}

# PRIVATE Crude algorithm for matching text. The words in the old text
# are matched by equality or sound and the proportion of words
# in the old text still seen in the new text is returned.
sub _partialMatch {
    my ( $old, $new ) = @_;
    my @aold = split( /\s+/, $old );
    my @anew = split( /\s+/, $new );
    my $matches = 0;
    foreach my $s (@aold) {
        for ( my $t = 0 ; $t <= $#anew ; $t++ ) {
            if ( $anew[$t] =~ m/^\Q$s\E$/i ) {
                $anew[$t] = '';
                $matches++;
                last;
            }
            else {
                my $so = Text::Soundex::soundex($s)          || '';
                my $sn = Text::Soundex::soundex( $anew[$t] ) || '';
                if ( $so eq $sn ) {
                    $anew[$t] = '';
                    $matches += 0.75;
                }
            }
        }
    }
    return $matches / ( $#aold + 1 );
}

# PUBLIC find and format differences between this action and another
# action, adding the changes to a hash keyed on the names of
# people interested in notification.
sub findChanges {
    my ( $this, $old, $format, $notifications ) = @_;

    # COVERAGE OFF safety net
    if ( !defined( $this->{notify} ) || $this->{notify} !~ m/\w/o ) {
        return 0;
    }

    # COVERAGE ON

    my $changes = $format->formatChangesAsString( $old, $this );
    if ( $changes eq '' ) {
        return 0;
    }

    my $plain_text = $format->formatStringTable( [$this] );
    $plain_text .= "\n$changes\n";
    my $html_text =
      $format->formatHTMLTable( [$this], 'href', 'atpChanges' );
    $html_text .= $format->formatChangesAsHTML( $old, $this );

    # Add text to people interested in notification
    # in the hash
    my @notables = split( /[,\s]+/, $this->{notify} );
    foreach my $notable (@notables) {
        $notable = _canonicalName($notable);
        $notifications->{$notable}{html} .= $html_text;
        $notifications->{$notable}{text} .= $plain_text;
    }

    return 1;
}

# PUBLIC STATIC create a new action filling in attributes
# from a CGI query as used in the action edit.
sub createFromQuery {
    my ( $web, $topic, $an, $query ) = @_;
    my $desc = $query->param('text') || 'No description';
    $desc =~ s/\r?\n\r?\n/ <p \/>/sgo;
    $desc =~ s/\r?\n/ <br \/>/sgo;

    # for each of the legal attribute types, see if the query
    # contains a value for that attribute. If it does, fill it
    # in.
    my $attrs = '';
    foreach my $attrname ( keys %types ) {
        my $type = $types{$attrname};
        if ( $type->{type} !~ m/noload/o ) {
            my $val = $query->param($attrname);
            if ( defined($val) ) {
                $attrs .= ' ' . $attrname . '="' . $val . '"';
            }
        }
    }
    return new Foswiki::Plugins::ActionTrackerPlugin::Action( $web, $topic, $an,
        $attrs, $desc );
}

# Copy noload attributes from a copy of the action
sub updateFromCopy {
    my ( $this, $copy, $mustMerge, $curRev, $origRev, $ancestoraction ) = @_;
    foreach my $attrname ( keys %types ) {
        if ( defined $copy->{$attrname}
	    && (!defined($this->{attrname}) || $copy->{attrname} ne $this->{$attrname})) {
	    if ($mustMerge && $ancestoraction && $types{$attrname}->{merge}) {
		# must attempt to merge
		require Foswiki::Merge;
		if ($ancestoraction) {
		    $this->{$attrname} =
			Foswiki::Merge::merge3(
			    $origRev, $ancestoraction->{$attrname},
			    $curRev, $this->{$attrname},
			    'new', $copy->{$attrname},
			    '.*?\n', $Foswiki::Plugins::SESSION );
		} else {
		    $this->{$attrname} =
			Foswiki::Merge::merge2(
			    $curRev, $this->{$attrname},
			    'new', $copy->{$attrname},
			    '.*?\n', $Foswiki::Plugins::SESSION );
		}
	    } else {
		# Take the value from the action editor
		$this->{$attrname} = $copy->{$attrname};
	    }
	}
    }
}

sub formatForEdit {
    my ( $this, $format ) = @_;

    # Generate visible fields
    my %expanded;
    my $table = $format->formatEditableFields( $this, \%expanded );

    # Generate unexpanded fields using hidden inputs
    foreach my $attrname ( keys %types ) {
        if ( !$expanded{$attrname} ) {
            my $type = $types{$attrname};
            if ( $type->{type} !~ m/noload/ ) {
                $table .= $format->formatHidden( $this, $attrname );
            }
        }
    }
    return $table;
}

1;
__END__

Copyright (C) 2002-2003 Motorola UK Ltd - All rights reserved
Copyright (C) 2004-2011 Crawford Currie http://c-dot.co.uk

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at 
http://www.gnu.org/copyleft/gpl.html

