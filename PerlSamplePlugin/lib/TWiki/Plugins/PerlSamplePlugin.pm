#
# Copyright (C) 2000-2001 Franco Bagnoli, bagnoli@dma.unifi.it
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
# http://www.gnu.ai.mit.edu/copyleft/gpl.html
#
# =========================
#
# This is a plugin to show perl code examples
#
# =========================
#
# Each plugin is a package that contains the subs:
#
#	initPluginy      ( $topic, $web, $user, $installWeb )
#	commonTagsHandler( $text, $topic, $web )
#	outsidePREHandler( $text, $web )
#	insidePREHandler ( $text, $web )
#	beforeSaveHandler( $text, $topic, $web )
#	afterEditHandler ( $text, $topic, $web )
#
# =========================
package TWiki::Plugins::PerlSamplePlugin;

use Safe;

# =========================
use vars qw( $web $topic $user $installWeb $VERSION
  $compartment );
$VERSION = '1.000';

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    if ( !defined Safe::VERSION ) {
        &TWiki::Func::writeWarning(
            'PerlSamplePlugin: Safe perl module not installed.');
        return 0;
    }

    $compartment = new Safe;
    $compartment->permit(qw(sort));

    return 1;
}

# =========================
sub commonTagsHandler {

    #    my ( $text, $topic, $web ) = @_;

    $_[0] =~ s/%PERLSAMPLE{(.*?)}%/&handlePerlSample($1,$compartment)/gseo;
}

# =========================
#sub outsidePREHandler
#{
#    my ( $text, $web ) = @_;
#}
# =========================
#sub insidePREHandler
#{
#    my ( $text, $web ) = @_;
#}
# =========================

#FB perl
sub maxeol {
    my $max = 0;
    my $n   = 0;
    foreach $string (@_) {
        $n = $string =~ tr/\n//;
        $max = $n if $max < $n;
    }
    return $max + 1;
}

# =========================
sub handlePerlSample {
    my ( $arg, $compartment ) = @_;
    open SAVEOUT, ">&STDOUT";
    open STDOUT,  ">perl_stdout.tmp";

    $arg =~ s/\n*$//so;
    $arg =~ s/^\s*\n*//so;
    $myarg = $arg;
    $myarg =~ s/print/print substr("  ".(__LINE__),-2), ': ',/go;

    #print "---\n$myarg\n---\n";
    my $ret = "";
    $ret .= $compartment->reval($myarg);
    $ret =~ s/\n*$//so;
    $ret .= "&nbsp;";
    close STDOUT;
    open STDOUT,  ">&SAVEOUT";
    open SAVEOUT, "perl_stdout.tmp";
    my $stdout = join "", <SAVEOUT>;
    $stdout =~ s/\n*$//so;
    $stdout .= "&nbsp;";
    close SAVEOUT;
    my $stderr = $@;
    $stderr .= "&nbsp;";
    my $n = maxeol( $arg, $ret );
    my ( $i, $li );
    $li = join "\n", ( 1 .. $n );
    my $text = <<EOF;
<!-- STOP RENDERING -->
<table border=0>
	<tr>
		<th> </th>
		<th bgcolor = #aaaaaa>code</th>
		<th bgcolor = #aaffaa>return</th>
	</tr>
	<tr valign="top" bgcolor = #eeeeff>
		<td bgcolor="#aaaaaa"><font color="#0000ff"><pre>$li</pre></font></td>
		<td bgcolor="#eeeeee"><font color="#ff0000"><pre>$arg</pre></font></td>
		<td bgcolor = #eeffee><pre>$ret</pre></td>
	</tr>
		<th> </th>
		<th bgcolor = #ffaaff>stdout</th>
		<th bgcolor = #ffaaaa>stderr</th>
	</tr>
	<tr valign="top" bgcolor = #eeeeff>
		<td></td>
		<td bgcolor = #ffeeff><pre>$stdout</pre></td>
		<td bgcolor = #ffeeee><pre>$stderr</pre></td>
	</tr>
</table>
<!-- START RENDERING -->
EOF
    return $text;
}

#/FB

1;

