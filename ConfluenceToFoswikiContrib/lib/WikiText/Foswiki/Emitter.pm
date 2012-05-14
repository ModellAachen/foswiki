package WikiText::Foswiki::Emitter;
use strict;
use warnings;

use WikiText::Receiver;
our @ISA = qw( WikiText::Receiver );
use CGI::Util;

my $type_tags = {
    b        => 'strong',
    i        => 'em',
    wikilink => 'a',
};

sub init {
    my $self = shift;
    $self->{output} = '';
}

sub content {
    my $self = shift;
    return $self->{output};
}

sub insert {
    my $self = shift;
    my $ast  = shift;
    $self->{output} .= $ast->{output} || '';
}

sub uri_escape {
    $_ = shift;
    s/ /\%20/g;
    return $_;
}

sub begin_node {
    my $self   = shift;
    my $node   = shift;
    my $type   = $node->{type};
    my $tag    = $type_tags->{$type} || $type;
    my $output = "";

    if ( $type eq "ul" || $type eq "ol" ) {
        $WikiText::Receiver::Foswiki::listlevel++;
    }
    elsif ( $type eq "li" && $node->{subtype} eq "unordered" ) {
        $output .= " " x ( 3 * $WikiText::Receiver::Foswiki::listlevel ) . "* ";
    }
    elsif ( $type eq "li" && $node->{subtype} eq "ordered" ) {
        $output = " " x ( 3 * $WikiText::Receiver::Foswiki::listlevel ) . "1 ";
    }
    elsif ( $type =~ /^h([1-6])$/ ) {
        $output .= "---" . "+" x $1 . " ";
    }
    elsif ( $type eq "hr" ) {
        $output .= "----\n";
    }
    elsif ( $type eq "br" ) {
        $output .= "<br />";
    }
    elsif ( $type eq "b" ) {
        $output .= "*";
    }
    elsif ( $type eq "i" ) {
        $output .= "_";
    }
    elsif ( $type eq "tt" ) {
        $output .= "=";
    }
    elsif ( $type eq "del" ) {
        $output .= "<strike>";
    }
    elsif ( $type eq "u" ) {
        $output .= "<u>";
    }
    elsif ( $type eq "sup" ) {
        $output .= "<sup>";
    }
    elsif ( $type eq "sub" ) {
        $output .= "<sub>";
    }
    elsif ( $type eq "blockquote" ) {
        $output .= "<blockquote>";
    }
    elsif ( $type eq "td" ) {
        if ( defined $node->{subtype} and $node->{subtype} eq "head" ) {
            $output .= "|*";
        }
        else {
            $output .= "|";
        }
    }
    elsif ( $type eq "pre" ) {
        $output .= "<verbatim>\n";
    }
    elsif ( $type eq "a" ) {
        $output .= " ";
        if ( $node->{subtype} eq "dblink" ) {
            $output .= "[dblink $node->{attributes}{dblink}]";
        }
        elsif ( $node->{subtype} eq "userlink" ) {
            $output .= "[userlink $node->{attributes}{userlink}]";
        }
        elsif ( $node->{subtype} eq "bloglink" ) {
            $output .= "[bloglink $node->{attributes}{bloglink}]";
        }
        elsif ( $node->{subtype} eq "wikilink" ) {
            $output .= process_wikilink($node);
        }
        elsif ( $node->{subtype} eq "url" ) {
            if ( $node->{attributes}{linktext} ) {
                $output .=
"[[$node->{attributes}{href}][$node->{attributes}{linktext}]]";
            }
            else {
                $output .= "[[$node->{attributes}{href}]]";
            }
        }
    }
    elsif ( $type eq "mail" ) {
        $output .= " $node->{attributes}{address} ";
    }
    elsif ( $type eq "anchor" ) {
        $output .= "\n#" . to_foswikiname( $node->{attributes}{anchor} ) . " ";
    }
    elsif ( $type eq "color" ) {
        $output .= '<font color="#' . $node->{attributes}{color} . '">';

        #print "COLOR= $node->{attributes}{color}";
    }
    elsif ( $type eq "toc" ) {
        $output .= '%TOC%' . "\n";
    }

    $self->{output} .= $output;
}

sub process_wikilink {
    my $node = shift;
    my ( $web, $foswikipage, $anchor, $output );

    if ( $node->{attributes}{space} ) {
        $web = to_foswikiname( $node->{attributes}{space} );
    }
    if ( $node->{attributes}{page} ) {
        $foswikipage = to_foswikiname( $node->{attributes}{page} );
    }
    if ( $node->{attributes}{anchor} ) {
        $anchor = to_foswikiname( $node->{attributes}{anchor} );
    }

    if ( $node->{attributes}{attachment} ) {
        if ( !$foswikipage ) {    # attachment in current page
            $output = "%ATTACHURL%/$node->{attributes}{attachment}";
        }
        elsif ( !$web ) {         # attachment in current web
            $output =
              "%PUBURLPATH%/%WEB%/$foswikipage/$node->{attributes}{attachment}";
        }
        else {
            $output =
              "%PUBURLPATH%/$web/$foswikipage/$node->{attributes}{attachment}";
        }
    }
    elsif ( $node->{attributes}{anchor} ) {
        $output = "$web." if $web;
        $output .= "$foswikipage" if $foswikipage;
        $output .= "#$anchor";
    }
    elsif ( $web && !$foswikipage ) {    # bare web
        $output = "$web.WebHome";
    }
    elsif ($web) {
        $output = "$web.$foswikipage";
    }
    else {
        $output = "$foswikipage";
    }

    if ( $node->{attributes}{linktext} ) {    # wrap with linktext if necessary
        $output = "[[$output][$node->{attributes}{linktext}]]";
    }
    else {
        $output = "[[$output]]";
    }

    return $output;
}

sub to_foswikiname {
    my $page = shift;

    $page =~ s/[^a-zA-Z0-9_]/_/g;
    $page =~ s/(\b[a-z]|_[a-z])/uc($1)/eg;
    return $page;
}

sub begin_wikilink {
    my $self = shift;
    my $node = shift;
    my $tag  = $node->{type};

    my $link =
        $self->{callbacks}{wikilink}
      ? $self->{callbacks}{wikilink}->($node)
      : CGI::Util::escape( $node->{attributes}{target} );
    return qq{<a href="$link">};
}

sub end_node {
    my $self   = shift;
    my $node   = shift;
    my $type   = $node->{type};
    my $output = "";
    my $tag    = $type_tags->{$type} || $type;
    $tag =~ s/-.*//;

    if ( $type eq "ul" || $type eq "ol" ) {
        $WikiText::Receiver::Foswiki::listlevel--;
    }
    elsif ( $type =~ /^(li|h[1-6])$/ ) {
        $output .= "\n";
    }
    elsif ( $type eq "p" ) {
        $output .= "\n\n";
    }
    elsif ( $type eq "b" ) {
        $output .= "*";
    }
    elsif ( $type eq "i" ) {
        $output .= "_";
    }
    elsif ( $type eq "tt" ) {
        $output .= "=";
    }
    elsif ( $type eq "del" ) {
        $output .= "</strike>";
    }
    elsif ( $type eq "u" ) {
        $output .= "</u>";
    }
    elsif ( $type eq "sup" ) {
        $output .= "</sup>";
    }
    elsif ( $type eq "sub" ) {
        $output .= "</sub>";
    }
    elsif ( $type eq "blockquote" ) {
        $output .= "</blockquote>\n";
    }
    elsif ( $type eq "td" ) {
        if ( defined $node->{subtype} and $node->{subtype} eq "head" ) {
            $output .= "*";
        }
    }
    elsif ( $type eq "tr" ) {
        $output .= "|\n";
    }
    elsif ( $type eq "pre" ) {
        $output .= "</verbatim>\n";
    }
    elsif ( $type eq "color" ) {
        $output .= "</font>";
    }

    $self->{output} .= $output;
}

sub text_node {
    my $self = shift;
    my $text = shift;
    $self->{output} .= "$text";
}

1;

=head1 NAME

WikiText::HTML::Emitter - A WikiText Receiver That Generates HTML

=head1 SYNOPSIS

    use WikiText::HTML::Emitter;
    
=head1 DESCRIPTION

This receiver module, when hooked up to a parser, produces HTML.

=head1 AUTHOR

Ingy döt Net <ingy@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2008. Ingy döt Net.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
