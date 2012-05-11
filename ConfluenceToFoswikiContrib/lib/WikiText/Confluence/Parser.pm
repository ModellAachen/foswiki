package WikiText::Confluence::Parser;
use strict;
use warnings;
use WikiText::Parser;
our @ISA = qw( WikiText::Parser );

# Reusable regexp generators used by the grammar
my $ALPHANUM = '\p{Letter}\p{Number}\pM';

# These are all stolen from URI.pm
my $reserved   = q{;/?:@&=+$,[]#};
my $mark       = q{-_.!~*'()};
my $unreserved = "A-Za-z0-9\Q$mark\E";
my $uric       = quotemeta($reserved) . $unreserved . "%";
my %im_types   = (
    yahoo  => 'yahoo',
    ymsgr  => 'yahoo',
    callto => 'callto',
    skype  => 'callto',
    callme => 'callto',
    aim    => 'aim',
    msn    => 'msn',
    asap   => 'asap',
);
my $im_re = join '|', keys %im_types;

my %colormap = (
    black   => '000000',
    navy    => '000080',
    green   => '008000',
    teal    => '008080',
    silver  => 'C0C0C0',
    blue    => '0000FF',
    lime    => '00FF00',
    aqua    => '00FFFF',
    maroon  => '800000',
    purple  => '800080',
    olive   => '808000',
    gray    => '808080',
    red     => 'FF0000',
    fuchsia => 'FF00FF',
    yellow  => 'FFFF00',
    white   => 'FFFFFF'
);

sub create_grammar {

  # phrases and blocks and their order taken from textile-j's Confluence parser.

    my $all_phrases = [
        qw(color a mail dblink userlink bloglink wikilink anchor strong emphasis citation deleted underlined superscript subscript monospace br)
    ];
    my $all_blocks = [

#		qw(heading hr list table quote preformat panel note info warning tip code toc p empty)
        qw(heading hr ul ol table quote pre banchor bcolor p empty toc default)
    ];

    return {
        _all_blocks  => $all_blocks,
        _all_phrases => $all_phrases,

        top => { blocks => $all_blocks, },

        empty => {
            match  => qr/^\s*\n/,
            filter => sub {
                my $node = shift;
                $node->{type} = '';
              }
        },

        heading => {
            match  => qr/^h([1-6])\.\s*(.*?)\s*?\n+/,
            filter => sub {
                my $node = shift;
                $node->{type} = 'h' . $node->{1};
                $_ = $node->{text} = $node->{2};

            },
        },

        p => {
            match => qr/^(			# Capture whole thing
					(?m:
					^(?!		# All consecutive lines *not* starting with
					(?:
					[\#\-\*]+[\ ] |	# para breaker - list
					h[1-6]\. |	# para breaker - heading
					\| |		# para breaker - table
					\{[^\}]+\}.*\n	# para breaker - braced something (?)
					)
					)
					.*\S.*\n
					)+
					)
					(\s*\n)*	# and all blank lines after
					/x,
            phrases => $all_phrases,
            filter  => sub { chomp },
        },

        quote => {
            type  => 'blockquote',
            match => [
                (
                    qr/^bq\.\s*(
					.*\S.*\n	# rest of first line
					(?m:		# rest similar to p above
					^(?!
					(?:
					[\#\-\*]+[\ ] |
					h[1-6]\. |
					\| |
					\{[^\}]+\}.*\n
					)
					)
					.*\S.*\n
					)*
					)
					(\s*\n)*
					/x,
                    qr/^\{quote\}\s*(
					.*\S.*\n		# rest of first line
					(?:.*\n)*?)		# all lines after {quote}
					(?m:^\{quote\}\s*\n)	# ending {quote}
					(?:(?:\s*\n)*)/x    # trailing empty lines
                )
            ],
            phrases => $all_phrases,
        },

        pre => {
            match => [
                (
                    qr/^\{noformat\}\s*(
					.*\S.*\n		# rest of first line
					(?:.*\n)*?)		# all lines after {noformat}
					(?m:^\{noformat\}\s*\n)	# ending {noformat}
					(?:(?:\s*\n)*)/x,    # trailing empty lines
                    qr/^\{code\}\s*(
					.*\S.*\n		# rest of first line
					(?:.*\n)*?)		# all lines after {code}
					(?m:^\{code\}\s*\n)	# ending {code}
					(?:(?:\s*\n)*)/x,    # trailing empty lines
                )
            ],
        },

        bcolor => {       # block version - hack till para is fixed
            type   => 'color',
            match  => qr/^\{color\:(\w+)\}((?s).*?)\{color\}/,
            filter => sub {
                my $node = shift;

                $node->{attributes}{color} =
                  exists( $colormap{ $node->{1} } )
                  ? $colormap{ $node->{1} }
                  : $node->{1};
                $node->{text} = $_ = $node->{2};
            },
            phrases => $all_phrases,
        },
        color => {    # doesn't support para spanning
            match  => qr/\{color\:(\w+)\}((?s).*?)\{color\}/,
            filter => sub {
                my $node = shift;

                $node->{attributes}{color} =
                  exists( $colormap{ $node->{1} } )
                  ? $colormap{ $node->{1} }
                  : $node->{1};
                $node->{text} = $_ = $node->{2};
            },
            phrases => $all_phrases,
        },

        table => {
            match => qr/^\s*(
				\|.*\|\s*\n		# first table line
				(?:\s*\|.*\|\s*\n)*	# rest of table lines
				)(?:\s*\n)?/x,    # eat trailing blank lines
            blocks => [ 'trhead', 'tr' ],
        },

        trhead => {
            type   => 'tr',
            match  => qr/^\s*(\|\|.*.\|\|\s*\n)/,
            blocks => ['tdhead'],
            filter => sub {
                my $node = shift;
                $node->{subtype} = 'head';
            },
        },

        tdhead => {
            type    => 'td',
            match   => qr/(?:\|\|)?\s*(.*?)\s*\|\|\s*\n?/,
            phrases => $all_phrases,
            filter  => sub {
                my $node = shift;
                $node->{subtype} = 'head';
            },
        },

        tr => {
            match  => qr/^\s*(\|.*.\|\s*\n)/,
            blocks => ['td'],
        },

        td => {
            match   => qr/(?:\|)?\s*(.*?)\s*\|\s*\n?/,
            phrases => $all_phrases,
        },

        ul => {
            match  => re_list('[\*\-\+]'),
            blocks => [qw(ul ol ulli)],
            filter => sub { s/^[\*\-\+\#] *//mg; },
        },

        ol => {
            match  => re_list('\#'),
            blocks => [qw(ul ol olli)],
            filter => sub { s/^[\*\#] *//mg; },
        },

        ulli => {
            type    => 'li',
            match   => qr/(.*)\n/,     # Capture the whole line
            phrases => $all_phrases,
            filter  => sub {
                my $node = shift;
                $node->{subtype} = 'unordered';
            },
        },

        olli => {
            type    => 'li',
            match   => qr/(.*)\n/,     # Capture the whole line
            phrases => $all_phrases,
            filter  => sub {
                my $node = shift;
                $node->{subtype} = 'ordered';
            },
        },

        hr => { match => qr/^----(?:\s*\n)?(?:(?:^\s*\n)*)/, },

        br => { match => qr/\\\\/, },

        strong => {
            type    => 'b',
            match   => re_huggy(q{\*}),
            phrases => $all_phrases,
        },

        monospace => {
            type  => 'tt',
            match => re_huggy( '\{\{', '\}\}' ),
        },

        emphasis => {
            type    => 'i',
            match   => re_huggy(q{\_}),
            phrases => $all_phrases,
        },

        citation => {
            type    => 'i',
            match   => re_huggy('\?\?'),
            phrases => $all_phrases,
        },

        underlined => {
            type    => 'u',
            match   => re_huggy(q{\+}),
            phrases => $all_phrases,
        },

        superscript => {
            type    => 'sup',
            match   => re_huggy(q{\^}),
            phrases => $all_phrases,
        },

        subscript => {
            type    => 'sub',
            match   => re_huggy(q{\~}),
            phrases => $all_phrases,
        },

        deleted => {
            type    => 'del',
            match   => re_huggy(q{\-}),
            phrases => $all_phrases,
        },

        dblink => {
            type  => 'a',
            match => qr/
				\[				# opening [
				(?:([^\|\]]+)\|)?			# 0 or 1 instance of link text
				(\$[^\|\]]+)			# link
				(?:\|([^\]]+))?			# 0 or 1 instance of link tip
				\]/x,
            filter => sub {
                my $node = shift;
                $node->{subtype}              = "dblink";
                $node->{attributes}{linktext} = $node->{1};
                $node->{attributes}{target}   = $node->{2};
                $node->{attributes}{dblink}   = $node->{2};
                undef $_;
            },
        },

        userlink => {
            type  => 'a',
            match => qr/
				\[				# opening [
				(?:([^\|\]]+)\|)?			# 0 or 1 instance of link text
				\~([^\|\]]+)			# link
				(?:\|([^\]]+))?			# 0 or 1 instance of link tip
				\]/x,
            filter => sub {
                my $node = shift;
                $node->{subtype}              = "userlink";
                $node->{attributes}{linktext} = $node->{1};
                $node->{attributes}{target}   = $node->{2};
                $node->{attributes}{userlink} = $node->{2};
                undef $_;
            },
        },

        bloglink => {
            type  => 'a',
            match => qr{
				\[					# opening [
				(?:([^\|\]]+)\|)?			# 0 or 1 instance of link text
				((?:[^:\|\]]+:)?/\d+/\d+/\d+(?:[^\|\]]+)?)	# link
				(?:\|([^\]]+))?				# 0 or 1 instance of link tip
				\]}x,
            filter => sub {
                my $node = shift;
                $node->{subtype}              = "bloglink";
                $node->{attributes}{linktext} = $node->{1};
                $node->{attributes}{target}   = $node->{2};
                $node->{2} =~ qr{
					\s*(?:([^:]+):)?	# 0 or 1 instance of space spec
					(/\d+/\d+/\d+.*)?	# 0 or 1 instance of page
					}x;
                $node->{attributes}{space}    = $1;
                $node->{attributes}{bloglink} = $2;
                undef $_;
            },
        },

        wikilink => {
            type  => 'a',
            match => qr/
				\[				# opening [
				(?:([^\|\]]+?)\s*\|)?		# 0 or 1 instance of link text
				\s*([^\|\]]+?)\s*		# link
				(?:\|([^\]]+?)\s*)?			# 0 or 1 instance of link tip
				\]/x,
            filter => sub {
                my $node = shift;
                $node->{subtype}              = "wikilink";
                $node->{attributes}{linktext} = $node->{1};
                $node->{attributes}{target}   = $node->{2};
                $node->{2} =~ qr/
					\s*(?:([^:]+):)?	# 0 or 1 instance of space spec
					([^\^\#]+)?		# 0 or 1 instance of page
					(?:([\#\^])(.*))?	# 0 or 1 anchor or attachment
					/x;
                $node->{attributes}{space} = $1;
                $node->{attributes}{page}  = $2;

                if ( defined $3 and $3 eq '#' ) {
                    $node->{attributes}{anchor} = $4;
                }
                if ( defined $3 and $3 eq '^' ) {
                    $node->{attributes}{attachment} = $4;
                }
                $node->{attributes}{linktip} = $node->{3};
                undef $_;
            },
        },

        a => {
            match => qr{
				\[				# opening [
				(?:([^\|\]]+?)\s*\|)?		# 0 or 1 instance of link text
		                \s*(
				(?:http|https|ftp|irc|file):
				(?://)?
				[$uric]+
				[A-Za-z0-9/#]
				)
				\s*\]
				}x,
            filter => sub {
                my $node = shift;
                $node->{subtype}              = "url";
                $node->{attributes}{linktext} = $node->{1};
                $node->{attributes}{href}     = $node->{2};
                undef $_;
            },
        },

        mail => {
            match => qr/
				\[
				\s*mailto:
				([\w+%\-\.]+@(?:[\w\-]+\.)+[\w\-]+)	# mail addr
				\s*\]
				/x,
            filter => sub {
                my $node = shift;
                $node->{attributes}{address} = $node->{1};
                undef $_;
            },
        },

        anchor => {
            match  => qr/\{anchor\:\s*([^\}]+?)\s*\}/,
            filter => sub {
                my $node = shift;
                $node->{attributes}{anchor} = $node->{1};
                undef $_;
            },
        },

        banchor => {    # block form of anchor
                        # p breaks on open-brace
                        # no enclosing block for phrase "anchor"
            type   => 'anchor',
            match  => qr/^\{anchor\:\s*([^\}]+?)\s*\}/,
            filter => sub {
                my $node = shift;
                $node->{attributes}{anchor} = $node->{1};
                undef $_;
            },
        },

        subl => {
            type => 'li',

            match => qr/^(				# Block must start at beginning
								# Capture everything in $1
					(.*)\n			# Capture the whole first line
					[\*\#]+\ .*\n		# Line starting with one or more bullet
					(?:[\*\#]+\ .*\n)*	# Lines starting with '*' or '#'
					)(?:\s*\n)?/x,    # Eat trailing lines
            blocks => [qw(ul ol li2)],
        },

        li2 => {
            type    => '',
            match   => qr/(.*)\n/,     # Capture the whole line
            phrases => $all_phrases,
        },

        t => { match => qr/\{toc(.*)\}/, },

        toc => {
            type  => 'toc',
            match => qr/\{toc(.*)\}/,    # match table of contents tag
        },

        default => {
            type  => 'pre',
            match => qr/(.*)/,

        },
    };
}

sub re_huggy {
    my $brace1 = shift;
    my $brace2 = shift || $brace1;

    qr/
        (?:^|(?<=[^{$ALPHANUM}$brace1]))$brace1(?=\S)(?!$brace2)
        (.*?)
        $brace2(?=[^{$ALPHANUM}$brace2]|\z)
    /x;
}

sub re_list {
    my $bullet = shift;
    return qr/^(            # Block must start at beginning
                            # Capture everything in $1
        ^$bullet+\ .*\n     # Line starting with one or more bullet
        (?:[\*\-\+\#]+\ .*\n)*  # Lines starting with '*' or '#'
    )(?:\s*\n)?/x,    # Eat trailing lines
}

1;
