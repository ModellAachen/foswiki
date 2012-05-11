# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2009-2011 Michael Daum, http://michaeldaumconsulting.com
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. 
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::JQGridPlugin::SearchConnector;

use strict;
use warnings;

use Foswiki::Plugins::JQGridPlugin::FoswikiConnector ();
use Error qw(:try);

our @ISA = qw( Foswiki::Plugins::JQGridPlugin::FoswikiConnector );

use constant DEBUG => 0; # toggle me

sub writeDebug {
  print STDERR "- SearchConnector - $_[0]\n" if DEBUG;
}

=begin TML

---+ package Foswiki::Plugins::JQGridPlugin::DBCacheConnector

implements the grid connector interface using the standard SEARCH interface

=cut

sub new {
  my ($class, $session) = @_;

  my $this = $class->SUPER::new($session);

  # maps column names to accessors to the actual property being displayed
  $this->{propertyMap} = {
    'Topic' => 'name',
    'Modified' => 'info.date',
    'Changed' => 'info.date',
    'By' => 'info.author',
    'Author' => 'info.author'
  };
  # maps column names to accessors appropriate for sorting
  $this->{sortPropertyMap} = {
    'Topic' => 'topic',
    'Modified' => 'modified',
    'Changed' => 'modified',
    'By' => 'editby',
    'Author' => 'editby'
  };

  return $this;
}

=begin TML

---++ ClassMethod restHandleSearch( $request, $response )

search backend 

=cut

sub restHandleSearch {
  my ($this, $request, $response) = @_;

  my $query = $request->param('query') || '1';
  $query = Foswiki::Plugins::JQGridPlugin::Connector::urlDecode($query);

  my $columns = Foswiki::Plugins::JQGridPlugin::Connector::urlDecode($request->param('columns') || '');
  foreach my $columnName (split(/\s*,\s*/, $columns)) {
    my $values = $request->param($columnName);
    next unless $values;

    my $propertyName = $this->column2Property($columnName);
    my @filterquery;

    # add search filters
    foreach my $value (split(/\s+/, $values)) {
      if ($value =~ /^-(.*)$/) {
        push(@filterquery, "NOT (lc($propertyName)=~lc('$1'))");
      } else {
        push(@filterquery, "lc($propertyName)=~lc('$value')");
      }
    }
    if (scalar(@filterquery)) {
      $query = join(' AND ', @filterquery) . " AND ($query)";
    }
  }

  my $sort = $request->param('sidx') || '';
  my $sord = $request->param('sord') || 'asc';
  my $reverse = ($sord eq 'desc'?'on':'off');

  my $web = $request->param('web') || $this->{session}->{webName};

  my $rows = $request->param('rows') || 10;
  my $page = $request->param('page') || 1;

  # create xml
  my $result = $this->search(
    web=>$web,
    query=>$query,
    sort=>$sort, 
    reverse=>$reverse, 
    columns=>$columns,
    rows=>$rows,
    page=>$page,
  );
  throw Error::Simple("can't search in web $web using $query")
    unless defined $result;

  $this->{session}->writeCompletePage($result, 'view', 'text/xml');
}

sub column2SortProperty {
  my ($this, $column) = @_;

  return $this->{sortPropertyMap}{$column} || "formfield($column)";
}

=begin TML

---++ ClassMethod search( $web, %params ) -> $xml

search $web and generate an xml result suitable for jquery.grid

=cut

sub search {
  my ($this, %params) = @_;

  my $context = Foswiki::Func::getContext();

  # TODO: get this sorted out
  my $order = $this->column2SortProperty($params{sort});

  my $tml = <<"HERE";
<literal><noautolink>%SEARCH{
  "$params{query}"
  type="query"
  nonoise="on"
  web="$params{web}"
  reverse="$params{reverse}"
  pagesize="$params{rows}"
  showpage="$params{page}"
  order="$order"
  separator="\$n"
  pagerformat=" "
      pagerformat2="<page>\$currentpage</page>
      <total>\$numberofpages</total>
      <records>\$percntCALC{\$EVAL(\$numberofpages * \$pagesize)}\$percnt</records>\$n"
  footer="\$n</rows>"
  header="<?xml version='1.0' encoding='$Foswiki::cfg{Site}{CharSet}'?><rows>
  <page>\$currentpage</page><total>\$numberofpages</total><records>\$percntCALC{\$EVAL(\$numberofpages * \$pagesize)}\$percnt</records>\$n"
  format="<row id='\$web.\$topic'>
HERE

  my @selectedFields = split(/\s*,\s*/, $params{columns});
  foreach my $columnName (@selectedFields) {
    my $cell = '';
    my $propertyName = $this->column2Property($columnName);
    if ($propertyName eq 'name') {
      $cell .= '$topic';
    } elsif ($propertyName =~ /^[a-zA-Z_]+$/) { # SMELL: should check if this is a defined formfield consulting the DataForm definition 
      $cell .= '$formfield(' . $propertyName . ')';
    } else {
      $cell .= '$percntQUERY{\"\'$web.$topic\'/' . $propertyName . '\"}$percnt';
    }
    $tml .= '<cell name=\"'.$columnName.'\"><![CDATA[<nop>' . $cell . ']]></cell>' . "\n";    # SMELL extra space behind cell needed to work around bug in Render::getRenderedVerision
  }
  $tml .= '</row>"}%</noautolink></literal>';

  $tml = Foswiki::Func::expandCommonVariables($tml);
  $tml = Foswiki::Func::renderText($tml);

  return $tml;
}

1;
