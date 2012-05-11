package Foswiki::Plugins::JQTablePlugin::TableSorter;
use strict;
use Foswiki::Plugins::JQueryPlugin::Plugin ();
our @ISA = 'Foswiki::Plugins::JQueryPlugin::Plugin';

sub new {
    my $class   = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;
    my $this    = bless(
        $class->SUPER::new(
            $session,
            name       => 'TableSorter',
            version    => '2.0.3',
            author     => 'Christian Bach',
            homepage   => 'http://tablesorter.com/docs/',
            puburl     => '%PUBURLPATH%/%SYSTEMWEB%/JQTablePlugin',
            css        => ['jquery.tablesorter.css'],
            javascript => [ 'jquery.tablesorter.js', 'tables.js' ],
            summary    => <<SUMMARY), $class );
<nop>TableSorter is a jQuery plugin for turning a standard HTML table with THEAD and
TBODY tags into a sortable table without page refreshes. tablesorter can
successfully parse and sort many types of data including linked data in a cell.
SUMMARY
    return $this;
}
1;
