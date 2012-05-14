# Copyright (C) 2009-2011 Foswiki Contributors
#
# For licensing info read LICENSE file in the Foswiki root.
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

package Foswiki::Contrib::Stringifier::Plugins::DOC_abiword;
use Foswiki::Contrib::Stringifier::Base ();
our @ISA = qw( Foswiki::Contrib::Stringifier::Base );
use File::Temp qw/tmpnam/;

my $abiword = $Foswiki::cfg{StringifierContrib}{abiwordCmd} || 'abiword';

#only load abiword if the user has selected it in configure - Sven & Andrew have had no success with it
if (defined($Foswiki::cfg{StringifierContrib}{WordIndexer}) && 
    ($Foswiki::cfg{StringifierContrib}{WordIndexer} eq 'abiword')) {
# Only if abiword exists, I register myself.
    if (__PACKAGE__->_programExists($abiword)){
        __PACKAGE__->register_handler("application/word", ".doc");
    }
}

sub stringForFile {
    my ($self, $file) = @_;
    my $tmp_file = tmpnam() . ".txt";
    
    my $cmd = $abiword . ' --to=%TMPFILE|F% %FILENAME|F%';
    my ($output, $exit) = Foswiki::Sandbox->sysCommand($cmd, TMPFILE => $tmp_file, FILENAME => $file);

    return '' unless ($exit == 0);

    open($in, $tmp_file) or return "";
    local $/ = undef;    # set to read to EOF
    my $text = <$in>;
    close($in);

    unlink($tmp_file);

    $text = $self->decode($text, $Foswiki::cfg{StringifierContrib}{CharSet}{abiword} || 'utf-8');
    $text = $self->encode($text);

    $text =~ s/^\s+//g;
    $text =~ s/\s+$//g;

    return $text;
}

1;
