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

package Foswiki::Plugins::JQGridPlugin::DBCacheConnector;

use strict;
use warnings;

use Foswiki::Plugins::JQGridPlugin::FoswikiConnector ();
use Foswiki::Plugins::DBCachePlugin ();
use Foswiki::Form ();
use POSIX ();
use Error qw(:try);

our @ISA = qw( Foswiki::Plugins::JQGridPlugin::FoswikiConnector );

use constant DEBUG => 0; # toggle me

sub writeDebug {
  print STDERR "- DBCacheConnector - $_[0]\n" if DEBUG;
}

=begin TML

---+ package Foswiki::Plugins::JQGridPlugin::DBCacheConnector

implements the grid connector interface using a DBCachePlugin based backend

=cut

sub new {
  my ($class, $session) = @_;

  my $this = $class->SUPER::new($session);

  # maps column names to accessors to the actual property being displayed
  $this->{propertyMap} = {
    'topic' => 'Topic', 
    'Topic' => 'topic',
    'TopicTitle' => 'topictitle',
    'info.date' => 'Modified', 
    'Modified' => 'info.date',
    'info.date' => 'Changed', 
    'Changed' => 'info.date',
    'info.author' => 'By', 
    'By' => 'info.author',
    'info.author' => 'Author', 
    'Author' => 'info.author'
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
        push(@filterquery, "! (lc($propertyName)=~lc('$1'))");
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

  #print STDERR "result=$result\n";

  $this->{session}->writeCompletePage($result, 'view', 'text/xml');
}

=begin TML

---++ ClassMethod search( $web, %params ) -> $xml

search $web and generate an xml result suitable for jquery.grid

=cut

sub search {
  my ($this, %params) = @_;
  
  my $db = Foswiki::Plugins::DBCachePlugin::getDB($params{web});
  throw Error::Simple("can't load dbcache") unless defined $db;
  

  my @result = ();
  my @selectedColumns = split(/\s*,\s*/, $params{columns});

  my $sort = $this->column2Property($params{sort});
  my ($topicNames, $hits, $msg) = $db->dbQuery($params{query}, undef, $sort, $params{reverse});
  return '' unless $topicNames;

  my $count = scalar(@$topicNames);
  my $totalPages = POSIX::ceil($count / $params{rows});

  my $page = $params{page};
  $page = $totalPages if $page > $totalPages;
  $page = 1 if $page < 1;

  my $start = $params{rows} * ($page - 1);
  $start = 0 if $start < 0;

  my $limit = $start + $params{rows};

  my $index = 0;
  foreach my $topic (@$topicNames) {
    $index++;
    next if $index <= $start;
    my $topicObj = $hits->{$topic};
    my $form = $topicObj->fastget("form");
    my $fieldDef;
    $form = $topicObj->fastget($form) if $form;
    $form = $form->fastget("name") if $form;
    $form = new Foswiki::Form($this->{session}, $params{web}, $form) if $form;

    my $line = "<row id='$params{web}.$topic'>\n";
    foreach my $columnName (@selectedColumns) {
      my $propertyName = $this->column2Property($columnName);
      my $cell = $db->expandPath($topicObj, $propertyName); # SMELL: use the core's QUERY

      # try to render it for display
      $fieldDef = $form->getField($propertyName) if $form;
      if ($fieldDef) {

        # patch in a random field name so that they are different on each row
        # required for older JQueryPlugins
        my $oldFieldName = $fieldDef->{name};
        $fieldDef->{name} .= int( rand(10000) ) + 1;

        $cell = $fieldDef->renderForDisplay('$value', $cell, undef, $params{web}, $topic);
        $cell = Foswiki::Func::expandCommonVariables($cell, $topic, $params{web});

        # restore original name in form definition to prevent sideeffects
        $fieldDef->{name} = $oldFieldName;
      }
      
      $line .= '<cell name="'.$columnName.'"><![CDATA[' . $cell . ']]></cell>' . "\n"; 
    }

    $line .= "</row>\n";
    push @result, $line;
    last if $index >= $limit;
  }

  my $header = <<"HERE";
<?xml version='1.0' encoding='$Foswiki::cfg{Site}{CharSet}'?>
<rows>
  <page>$page</page>
  <total>$totalPages</total>
  <records>$count</records>
HERE

  my $footer = "\n</rows>";

  return $header.join("\n", @result).$footer;

}

1;
