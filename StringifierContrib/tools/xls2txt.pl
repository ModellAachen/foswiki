#!/usr/bin/perl -w
# Wrapper for Spreadsheet::ParseExcel as it terminates with an Out of meomory error
# on password-protected xls files. making it an external tool won't cure this. however
# it will not take down all of the foswiki process. See http://foswiki.org/Tasks/ItemXXX

use strict;
use Spreadsheet::ParseExcel ();
use Encode ();
use utf8;

my $file = $ARGV[0];

unless ($file) {
  print STDERR "usage: xls2txt <file>\n";
  exit 1;
}

unless (-e $file) {
  print STDERR "file not found: $file\n";
  exit 1;
}

my $format = Spreadsheet::ParseExcel::FmtDefault->new();
my $book = Spreadsheet::ParseExcel::Workbook->Parse($file, $format);

return '' unless $book;

my $text = '';

foreach my $sheet (@{ $book->{Worksheet} }) {
  last if !defined $sheet->{MaxRow};
  foreach my $row ($sheet->{MinRow} .. $sheet->{MaxRow}) {
    foreach my $col ($sheet->{MinCol} .. $sheet->{MaxCol}) {
      my $cell = $sheet->{Cells}[$row][$col];
      if ($cell) {
        my $cell_text;
        if ($cell->{Type} eq "Numeric") {
          $cell_text = $cell->{Val};
        } else {
          $cell_text = $cell->Value;
        }
        next if ($cell_text eq "");

        $text .= $cell_text;
      }
      $text .= " ";
    }
    $text .= "\n";
  }
  $text .= "\n";
}
print Encode::encode_utf8($text);
