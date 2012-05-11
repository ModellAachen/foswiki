##################################################
package Utils::IdAppender;
##################################################

our @ISA = qw(Log::Log4perl::Appender);

=head1 NAME

Utils::Config - Configuration module

=head1 DESCRIPTION

This module extends functionality of default Logfile appender.
The default module is tweaked to add log id.
=cut

use warnings;
use strict;
use Log::Log4perl::Config::Watch;
use Fcntl;
use constant _INTERNAL_DEBUG => 0;

##################################################
sub new {
##################################################
    my ( $class, @options ) = @_;

    my $self = {
        name                    => "unknown name",
        umask                   => undef,
        owner                   => undef,
        group                   => undef,
        autoflush               => 1,
        syswrite                => 0,
        mode                    => "append",
        binmode                 => undef,
        utf8                    => undef,
        recreate                => 0,
        recreate_check_interval => 30,
        recreate_check_signal   => undef,
        recreate_pid_write      => undef,
        create_at_logtime       => 0,
        header_text             => undef,
        @options,
    };

    if ( $self->{create_at_logtime} ) {
        $self->{recreate} = 1;
    }

    if ( defined $self->{umask} and $self->{umask} =~ /^0/ ) {

        # umask value is a string, meant to be an oct value
        $self->{umask} = oct( $self->{umask} );
    }

    die "Mandatory parameter 'filename' missing"
      unless exists $self->{filename};

    bless $self, $class;
    $self->{last_message_count} = 0;
    if ( $self->{recreate_pid_write} ) {
        print "Creating pid file", " $self->{recreate_pid_write}\n"
          if _INTERNAL_DEBUG;
        open FILE, ">$self->{recreate_pid_write}"
          or die "Cannot open $self->{recreate_pid_write}";
        print FILE "$$\n";
        close FILE;
    }

    # This will die() if it fails
    $self->file_open() unless $self->{create_at_logtime};

    return $self;
}

##################################################
sub filename {
##################################################
    my ($self) = @_;

    return $self->{filename};
}

##################################################
sub file_open {
##################################################
    my ($self) = @_;

    my $arrows  = ">";
    my $sysmode = ( O_CREAT | O_WRONLY );

    my $old_umask = umask();

    if ( $self->{mode} eq "append" ) {
        $arrows = ">>";
        $sysmode |= O_APPEND;
    }
    elsif ( $self->{mode} eq "pipe" ) {
        $arrows = "|";
    }
    else {
        $sysmode |= O_TRUNC;
    }

    my $fh = do { local *FH; *FH; };

    umask( $self->{umask} ) if defined $self->{umask};

    my $didnt_exist = !-f $self->{filename};

    if ( $self->{syswrite} ) {
        sysopen $fh, "$self->{filename}", $sysmode
          or die "Can't sysopen $self->{filename} ($!)";
    }
    else {
        open $fh, "$arrows$self->{filename}"
          or die "Can't open $self->{filename} ($!)";
    }

    if ( $didnt_exist
        and ( defined $self->{owner} or defined $self->{group} ) )
    {

        eval { $self->perms_fix() };

        if ($@) {

            # Cleanup and re-throw
            unlink $self->{filename};
            die $@;
        }
    }

    if ( $self->{recreate} ) {
        $self->{watcher} = Log::Log4perl::Config::Watch->new(
            file => $self->{filename},
            (
                defined $self->{recreate_check_interval}
                ? ( check_interval => $self->{recreate_check_interval} )
                : ()
            ),
            (
                defined $self->{recreate_check_signal}
                ? ( signal => $self->{recreate_check_signal} )
                : ()
            ),
        );
    }

    umask($old_umask) if defined $self->{umask};

    $self->{fh} = $fh;

    if ( $self->{autoflush} and !$self->{syswrite} ) {
        my $oldfh = select $self->{fh};
        $| = 1;
        select $oldfh;
    }

    if ( defined $self->{binmode} ) {
        binmode $self->{fh}, $self->{binmode};
    }

    if ( defined $self->{utf8} ) {
        binmode $self->{fh}, ":utf8";
    }

    if ( defined $self->{header_text} ) {
        if ( $self->{header_text} !~ /\n\Z/ ) {
            $self->{header_text} .= "\n";
        }
        my $fh = $self->{fh};
        print $fh $self->{header_text};
    }
}

##################################################
sub file_close {
##################################################
    my ($self) = @_;

    undef $self->{fh};
}

##################################################
sub perms_fix {
##################################################
    my ($self) = @_;

    my ( $uid_org, $gid_org ) = ( stat $self->{filename} )[ 4, 5 ];

    my ( $uid, $gid ) = ( $uid_org, $gid_org );

    if ( !defined $uid ) {
        die "stat of $self->{filename} failed ($!)";
    }

    my $needs_fixing = 0;

    if ( defined $self->{owner} ) {
        $uid = $self->{owner};
        if ( $self->{owner} !~ /^\d+$/ ) {
            $uid = ( getpwnam( $self->{owner} ) )[2];
            die "Unknown user: $self->{owner}" unless defined $uid;
        }
    }

    if ( defined $self->{group} ) {
        $gid = $self->{group};
        if ( $self->{group} !~ /^\d+$/ ) {
            $gid = getgrnam( $self->{group} );

            die "Unknown group: $self->{group}" unless defined $gid;
        }
    }
    if ( $uid != $uid_org or $gid != $gid_org ) {
        chown( $uid, $gid, $self->{filename} )
          or die "chown('$uid', '$gid') on '$self->{filename}' failed: $!";
    }
}

##################################################
sub file_switch {
##################################################
    my ( $self, $new_filename ) = @_;

    print "Switching file from $self->{filename} to $new_filename\n"
      if _INTERNAL_DEBUG;

    $self->file_close();
    $self->{filename} = $new_filename;
    $self->file_open();
}

##################################################
sub log {
##################################################
    my ( $self, %params ) = @_;

    if ( $self->{recreate} ) {
        if ( $self->{recreate_check_signal} ) {
            if ( $self->{watcher}->{signal_caught} ) {
                $self->{watcher}->{signal_caught} = 0;
                $self->file_switch( $self->{filename} );
            }
        }
        else {
            if (  !$self->{watcher}
                or $self->{watcher}->file_has_moved() )
            {
                $self->file_switch( $self->{filename} );
            }
        }
    }

    my $fh = $self->{fh};
    $self->{last_message_count}++;
    if ( $self->{syswrite} ) {
        syswrite $fh, "[$self->{last_message_count}]" . $params{message}
          or die "Cannot syswrite to '$self->{filename}': $!";
    }
    else {
        print $fh "[$self->{last_message_count}]" . $params{message}
          or die "Cannot write to '$self->{filename}': $!";
    }
}

##################################################
sub DESTROY {
##################################################
    my ($self) = @_;

    if ( $self->{fh} ) {
        my $fh = $self->{fh};
        close $fh;
    }
}

1;

__END__

