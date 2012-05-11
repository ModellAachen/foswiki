#!/usr/bin/perl -w

use File::Find::Rule;

#my @subdirs = File::Find::Rule->directory->in( '/eis/apps/twiki/test/data/' );
my @subdirs = File::Find::Rule->directory->in('.');

foreach $dir (@subdirs) {
    next if ( $dir =~ m/^_|^\.|^Trash$/ );

# open dir, loop through files, open files with .txt$, search for syntax, output if found
    opendir( DIR, $dir ) or die "can't opendir: $!";
    while ( defined( $filename = readdir(DIR) ) ) {
        if ( $filename =~ /.*\.txt$/ ) {

            #print $filename . "\n" if $filename =~ /Syntax/;
            open INFILE, "<", "$dir/$filename" or print "$! $filename\n";
            my $file;
            while (<INFILE>) {
                $file .= $_;
            }
            close INFILE;
            $file =~
s/^\%begin( numbered)?(?:\:(\d+))? ([^%]*?)%\n(.*?)^\%end%$/\%CODE{\"$3\" num=\"$2\"}\%\n$4\%ENDCODE\%/mgos;

#$file =~ s/^%begin( numbered)?(?:\:(\d+))? ([^%]*?)%\n(.*?)^%end%$/%CODE{\"$3\" num=\"$2\"}%code%ENDCODE%/mgos
            open OUTFILE, ">", "$dir/$filename" or print "$! $filename\n";
            print OUTFILE $file;
            close OUTFILE;
        }
    }
}
