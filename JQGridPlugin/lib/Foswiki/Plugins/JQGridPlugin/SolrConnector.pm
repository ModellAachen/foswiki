# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2011 Michael Daum, http://michaeldaumconsulting.com
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

package Foswiki::Plugins::JQGridPlugin::SolrConnector;

use strict;
use warnings;

use Foswiki::Plugins::JQGridPlugin::FoswikiConnector ();
use Foswiki::Plugins::SolrPlugin ();
use Foswiki::Meta ();
use Foswiki::Form ();
use POSIX ();
use Error qw(:try);

our @ISA = qw( Foswiki::Plugins::JQGridPlugin::FoswikiConnector );

use constant DEBUG => 0; # toggle me

sub writeDebug {
  print STDERR "- SolrConnector - $_[0]\n" if DEBUG;
}

=begin TML

---+ package Foswiki::Plugins::JQGridPlugin::SolrConnector

implements the grid connector interface using a SolrPlugin based backend

=cut

sub new {
  my ($class, $session) = @_;

  my $this = $class->SUPER::new($session);

  # maps column names to accessors to the actual property being displayed
  $this->{propertyMap} = {
    'Topic' => 'topic',
    'Web' => 'web',
    'TopicTitle' => 'title',
    'By' => 'author',
    'Modified' => 'date',
    'Changed' => 'date',
    'Author' => 'author',
    'Created' => 'createdate',
    'Create Date' => 'createdate',
    'Creater' => 'createauthor',
    'Create Author' => 'createauthor',
    'TopicType' => 'field_TopicType_lst',
    'Form' => 'form',
    'Category' => 'category',
    'Tag' => 'tag',
    'State' => 'state',
    'Size' => 'size',
  };

  return $this;
}

sub column2Property {
  my ($this, $columnName) = @_;

  return $columnName if $columnName =~ /^field_/g;

  my $fieldName = $this->{propertyMap}{$columnName};

  $fieldName = "field_".$columnName."_s" unless defined $fieldName;

  return $fieldName;
}

=begin TML

---++ ClassMethod restHandleSearch( $request, $response )

search backend 

=cut

sub restHandleSearch {
  my ($this, $request, $response) = @_;

  my $query = $request->param('query') || '';
  $query = Foswiki::Plugins::JQGridPlugin::Connector::urlDecode($query);

  my $web = $request->param('web') || $this->{session}->{webName};

  my $columns = Foswiki::Plugins::JQGridPlugin::Connector::urlDecode($request->param('columns') || '');
  foreach my $columnName (split(/\s*,\s*/, $columns)) {
    my $propertyName = $this->column2Property($columnName);
    my $values = $request->param($columnName);
    next unless $values;

    my @filterquery = ();

    # add search filters
    foreach my $value (split(/\s+/, $values)) {
      if ($value =~ /^-(.*)$/) {
        push(@filterquery, " -$propertyName:*$1*");
      } else {
        push(@filterquery, " $propertyName:*$value*");
      }
    }
    $query .= join(' ', @filterquery);
  }
  $query .= " web:$web";

  my $sort = $request->param('sidx') || '';
  $sort = $this->column2Property($sort);

  my $sord = $request->param('sord') || 'asc';
  my $reverse = ($sord eq 'desc'?'on':'off');

  my $rows = $request->param('rows') || 10;
  my $page = $request->param('page') || 1;

  my $searcher = Foswiki::Plugins::SolrPlugin::getSearcher();

  my $solrResponse = $searcher->doSearch($query, {
    web=>$web,
    query=>$query,
    sort=>$sort, 
    reverse=>$reverse, 
    rows=>$rows,
    start=>($page-1),
  });
  throw Error::Simple("can't search in web $web using $query")
    unless defined $solrResponse;

  #print STDERR "response=".$solrResponse->raw_response->content()."\n";

  my $count = $searcher->totalEntries($solrResponse);
  my $totalPages = $searcher->lastPage($solrResponse)+1;

  my $footer = "\n</rows>";
  my $header = <<"HERE";
<?xml version='1.0' encoding='$Foswiki::cfg{Site}{CharSet}'?>
<rows>
  <page>$page</page>
  <total>$totalPages</total>
  <records>$count</records>
HERE

  my @result = ();
  my @selectedColumns = split(/\s*,\s*/, $columns);
  for my $doc ($solrResponse->docs) {
    my $web = $doc->value_for("web");
    my $topic = $doc->value_for("topic");
    my $topicObj = new Foswiki::Meta($this->{session}, $web, $topic );
    $topicObj->load();
    my $form = $topicObj->getFormName();
    my $fieldDef;
    $form = new Foswiki::Form($this->{session}, $web, $form) if $form;

    my $line = "<row id='$web.$topic'>\n";

    foreach my $columnName (@selectedColumns) {
      my $propertyName = $this->column2Property($columnName);
      my @values = $doc->values_for($propertyName);

      # SMELL: try some alternatives
      @values = $doc->values_for("field_".$propertyName."_s") unless @values;
      @values = $doc->values_for("field_".$propertyName."_lst") unless @values;
      @values = $doc->values_for("field_".$propertyName."_dt") unless @values;
      next unless @values;

      my $value = join(", ", @values);
      $value = $searcher->fromUtf8($value);

      # try to render it for display
      $fieldDef = $form->getField($columnName) if $form;
      if ($fieldDef) {

        # patch in a random field name so that they are different on each row
        # required for older JQueryPlugins
        my $oldFieldName = $fieldDef->{name};
        $fieldDef->{name} .= int( rand(10000) ) + 1;

        $value = $fieldDef->renderForDisplay('$value', $value, undef, $web, $topic);
        $value = Foswiki::Func::expandCommonVariables($value, $topic, $web);

        # restore original name in form definition to prevent sideeffects
        $fieldDef->{name} = $oldFieldName;
      }

      $line .= '<cell name="'.$columnName.'"><![CDATA[' . $value . ']]></cell>' . "\n"; 
    }

    $line .= "</row>\n";
    push @result, $line;
  }

  my $result = $header.join("\n", @result).$footer;

  $this->{session}->writeCompletePage($result, 'view', 'text/xml');
}

1;

