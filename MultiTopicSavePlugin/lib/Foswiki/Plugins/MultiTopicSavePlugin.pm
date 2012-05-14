# See bottom of file for default license and copyright information

=begin TML

---+ package MultiTopicSavePlugin

This plugin enables saving content incl form data to multiple topics using
only a single submit.

It is typically used where you list content of a number of topics in a formatted
search which present the content as an HTML form with fields for each topic.

A submit button makes a rest call that causes this plugin to save the changed
date to all the topics listed.

=cut

# change the package name!!!
package Foswiki::Plugins::MultiTopicSavePlugin;

# Always use strict to enforce variable scoping
use strict;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

# $VERSION  should always be in the format$Rev: 5771 $ so that Foswiki can
# determine the checked-in status of the extension.
our $VERSION = '$Rev: 5771 $';

# $RELEASE is used in the "Find More Extensions" automation in configure.
our $RELEASE = '1.7';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION =
  'Save form data to multiple topics in one single submission';

# No preferences set in the plugin topic.
our $NO_PREFS_IN_TOPIC = 1;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using =Foswiki::Func::writeWarning= and return 0. In this case
%<nop>FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

__Note:__ Please align macro names with the Plugin name, e.g. if
your Plugin is called !FooBarPlugin, name macros FOOBAR and/or
FOOBARSOMETHING. This avoids namespace issues.

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Example code of how to get a preference value, register a macro
    # handler and register a RESTHandler (remove code you do not need)

    # Set your per-installation plugin configuration in LocalSite.cfg,
    # like this:
    # $Foswiki::cfg{Plugins}{EmptyPlugin}{ExampleSetting} = 1;
    # See %SYSTEMWEB%.DevelopingPlugins#ConfigSpec for information
    # on integrating your plugin configuration with =configure=.

    # Always provide a default in case the setting is not defined in
    # LocalSite.cfg. See %SYSTEMWEB%.Plugins for help in adding your plugin
    # configuration to the =configure= interface.
    # my $setting = $Foswiki::cfg{Plugins}{EmptyPlugin}{ExampleSetting} || 0;

    # Register the _EXAMPLETAG function to handle %EXAMPLETAG{...}%
    # This will be called whenever %EXAMPLETAG% or %EXAMPLETAG{...}% is
    # seen in the topic text.
    Foswiki::Func::registerTagHandler( 'MULTITOPICSAVESUBMIT',
        \&_MULTITOPICSAVESUBMIT );

    Foswiki::Func::registerTagHandler( 'MULTITOPICSAVEINPUT',
        \&_MULTITOPICSAVEINPUT );
    Foswiki::Func::registerTagHandler( 'MULTITOPICSAVEMESSAGE',
        \&_MULTITOPICSAVEMESSAGE );

    Foswiki::Func::registerTagHandler( 'MULTITOPICSAVESTARTFORM',
        \&_MULTITOPICSAVESTARTFORM );

    Foswiki::Func::registerTagHandler( 'MULTITOPICSAVEENDFORM',
        \&_MULTITOPICSAVEENDFORM );

    # Allow a sub to be called from the REST interface
    # using the provided alias
    Foswiki::Func::registerRESTHandler(
        'multitopicsave',
        \&restMultiTopicSave,
        authenticate => 1,
        http_allow   => 'POST',
        validate     => 1
    );

    # Plugin correctly initialized
    return 1;
}

=begin TML

---++ _topicLock($web, $topic, $mode) -> ($success, $message)

This is the which will lock or unlock a topic

The parameter is:
   * =$session= - The Foswiki object associated to this session.
   * =$mode= - "locked" or "released", default "released"
   
The sub returns
   * =$success= - 0 = failed, 1 = success
   * =$message= - a message how it went.
   
Note: Message from this sub is not yet used in the plugin. Nice to have

=cut

sub _topicLock {
    my ( $web, $topic, $mode ) = @_;

    $mode ||= "released";

    my $currentWikiName = Foswiki::Func::getWikiName();

    my $message = '';

    unless ( Foswiki::Func::topicExists( $web, $topic ) ) {
        $message .= "Topic $web.$topic does not exist\n\n";
        return ( 0, $message );
    }

    # Is it locked?
    my ( $oopsUrl, $loginName, $unlockTime ) =
      Foswiki::Func::checkTopicEditLock( $web, $topic, undef );

    my $lockedWikiName = Foswiki::Func::getWikiName($loginName);

    # We cannot lock or unlock if locked by someone else
    if ( $unlockTime && ( $lockedWikiName ne $currentWikiName ) ) {
        $message .= "Topic $web.$topic was not $mode. "
          . "It is being edited by !$lockedWikiName";

        return ( 0, $message );
    }

    # We cannot lock or unlock unless we have access rights
    unless (
        Foswiki::Func::checkAccessPermission(
            'CHANGE', $currentWikiName, undef, $topic, $web
        )
      )
    {

        $message .= "Topic $web.$topic was not $mode "
          . "due to lack of access rights\n\n";

        return ( 0, $message );
    }

    # Success, we can lock or release
    Foswiki::Func::setTopicEditLock( $web, $topic, ( $mode eq 'locked' ) );

    $message .= "Topic $web.$topic was $mode.";

    return ( 1, $message );
}

=begin TML

---++ _fetchFormFieldValue($field, $web, $topic) -> $value

Fetch the raw unrendered content of a formfield

The parameter is:
   * =$field= - Field name to fetch.
   * =$web= - Web name of topic
   * =$topic= - Topic name  
   
The sub returns
   * String - The raw content in the field
   * Returns '' if topic does not exist or no access rights
   
=cut

sub _fetchFormFieldValue {
    my ( $field, $web, $topic ) = @_;

    my $currentWikiName = Foswiki::Func::getWikiName();

    unless (
        Foswiki::Func::checkAccessPermission(
            'VIEW', $currentWikiName, undef, $topic, $web
        )
      )
    {
        return '';
    }

    my ( $meta, undef ) = Foswiki::Func::readTopic( $web, $topic );
    my $value = $meta->get( 'FIELD', $field );

    my $returnvalue = defined $value ? $value->{'value'} : '';

    return $returnvalue;
}

=begin TML

---++ _encodeValue($value) -> $value

This function returns the input string encoded for view in TML tables
We encode the most common destroyers of TML tables:
newlines and vertical bars

=cut

sub _encodeValue {
    my ($value) = @_;
    $value =~ s/\r?\n/<br \/>/gs;
    my $bar = '&#124;';
    $value =~ s/\|/$bar/g;
    return $value;
}

=begin TML

---++ _encodeHTMLEntities($value) -> $value

This function encodes special characters to html entities
so values can be used in input fields in edit mode

=cut

sub _encodeHTMLEntities {
    my ($value) = @_;
    $value =~ s/'/&#39;/g;
    $value =~ s/</&lt;/g;
    $value =~ s/>/&gt;/g;
    return $value;
}

# The function used to handle the %MULTITOPICSAVESUBMIT{...}% macro
sub _MULTITOPICSAVESUBMIT {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

  # $session  - a reference to the Foswiki session object (if you don't know
  #             what this is, just ignore it)
  # $params=  - a reference to a Foswiki::Attrs object containing
  #             parameters.
  #             This can be used as a simple hash that maps parameter names
  #             to values, with _DEFAULT being the name for the default
  #             (unnamed) parameter.
  #             returnweb = the web we want to return to after submit (optional)
  #             returntopic = the topic we want to return to after submit
  #                           can be web.topic format
  # $theTopic - name of the topic in the query
  # $theWeb   - name of the web in the query
  # Return: the result of processing the macro. This will replace the
  # macro call in the final text.

    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # $params->{sideorder} will be 'onions'

    # We cannot use the rest parameter endPoint because we need to return
    # to the submit with the URLPARAM MULTITOPICSAVEMESSAGE set.

    my $web = defined $params->{returnweb} ? $params->{returnweb} : $theWeb;
    my $topic =
      defined $params->{returntopic} ? $params->{returntopic} : $theTopic;

    # If returnweb was undefined and returntopic is web.topic form the result
    # is as expected web.topic.
    ( $web, $topic ) = Foswiki::Func::normalizeWebTopicName( $web, $topic );

    my $result =
        "<input type='hidden' name='redirectweb' value='$web' />"
      . "<input type='hidden' name='redirecttopic' value='$topic' />"
      . "<input type='hidden' name='topic' value='$web.$topic' />"
      . "<input type='submit' class='foswikiButton' value='";
    $result .= $params->{_DEFAULT} || "Submit All Changes";
    $result .= "' />";

    return $result;

}

# The function used to handle the %MULTITOPICSAVEINPUT{...}% macro
sub _MULTITOPICSAVEINPUT {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    # $session  - a reference to the Foswiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a Foswiki::Attrs object containing
    #             parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             (unnamed) parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the macro. This will replace the
    # macro call in the final text.

    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # INPUT will be 'onions'

    my $result          = '';
    my $type            = lc( $params->{type} ) || 'text';
    my $size            = $params->{size};                   # No default here
    my $multiple        = $params->{multiple} || 0;
    my $field           = $params->{_DEFAULT};
    my $targetWeb       = $params->{web} || $theWeb;
    my $targetTopic     = $params->{topic} || $theTopic;
    my $currentWikiName = Foswiki::Func::getWikiName();

    ( $targetWeb, $targetTopic ) =
      Foswiki::Func::normalizeWebTopicName( $targetWeb, $targetTopic );

    my $topicFQN = "$targetWeb.$targetTopic";    # Topic fully qualified name

    # Delay means we escape with $percnt and $quot
    # We cannot replace inside _RAW because that also replace quotes in values
    my $delay = $params->{delay};
    if ( $delay && ( $delay =~ /\d+/ ) && $delay-- > 0 ) {
        $result = "\$percntMULTITOPICSAVEINPUT{";
        $result .= "\$quot$field\$quot ";

        foreach my $key ( keys %$params ) {
            next if ( $key eq '_RAW' || $key eq '_DEFAULT' );

            if ( $key eq 'delay' ) {
                $result .= "delay=\$quot$delay\$quot ";
                next;
            }

            $result .= "$key=\$quot" . $params->{$key} . "\$quot ";
        }
        $result .= "}\$percnt";
        return $result;
    }

    # if value is not defined we set it to the string $value
    my $value = defined $params->{value} ? $params->{value} : '$value';

    # Substitute the string '$value' by $value. This enables the user to
    # Prefix and suffix the existing value
    $value =~
      s/\$value/_fetchFormFieldValue( $field, $targetWeb, $targetTopic )/ge;

    # If edit mode is defined and set to off - just return the value
    my $editmode =
      defined $params->{editmode}
      ? Foswiki::Func::isTrue( $params->{editmode} )
      : 1;

    my $lockmode =
      defined $params->{lockmode}
      ? Foswiki::Func::isTrue( $params->{lockmode} )
      : 0;

    # encodeview is designed to be used in TML tables and encode the most
    # destroyers of TML tables, newlines and vertical bars
    my $encodeview =
      defined $params->{encodeview}
      ? Foswiki::Func::isTrue( $params->{encodeview} )
      : 1;

    if ( $currentWikiName eq $Foswiki::cfg{DefaultUserWikiName} ) {
        $value = _encodeValue($value) if $encodeview;
        return $value;
    }

    if ($editmode) {

        # if lockmode is enabled we lock topic when in edit mode and
        # return the value if the lock failed since we cannot edit
        # Otherwise input fields need special characters html encoded
        if ($lockmode) {
            unless ( ( _topicLock( $targetWeb, $targetTopic, 'locked' ) )[0] ) {
                $value = _encodeValue($value) if $encodeview;
                return $value;
            }
        }
        $value = _encodeHTMLEntities($value);
    }
    else {

        # if lockmode is enabled we release topic lease when in non-edit mode
        _topicLock( $targetWeb, $targetTopic, 'released' )
          if $lockmode;
        $value = _encodeValue($value) if $encodeview;
        return $value;
    }

    # We assume leading and trailing spaces around option values are unwanted
    my @options = ();
    if ( defined $params->{options} ) {
        @options = map { s/^\s*(.*?)\s*$/$1/; $_; }
          split( /\s*,\s*/, $params->{options} );
    }

    # Render the field for editing depending on field type
    if ( $type eq 'text' ) {
        $result = "<input class='foswikiInputField' type='text' ";
        $size = 10 if ( !$size || $size < 1 );
        $result .= "size='$size' ";
        $result .= "name='multitopicsavefield{$topicFQN}{$field}' ";
        $result .= "value='" . $value . "' />";
    }
    elsif ( $type eq 'textarea' ) {
        $result = "<textarea class='foswikiTextarea' ";
        my ( $cols, $rows ) = ( 40, 5 );
        if ( defined $size ) {
            if ( $size =~ m/(\d+)[xX](\d+)/ ) {
                ( $cols, $rows ) = ( $1, $2 );
            }
            $result .= "cols='$cols' rows='$rows' ";
        }
        $result .= "name='multitopicsavefield{$topicFQN}{$field}'>";
        $result .= "$value";
        $result .= "</textarea>";
    }
    elsif ( $type eq 'radio' || $type eq 'checkbox' ) {
        my @values =
          map { s/^\s*(.*?)\s*$/$1/; $_; } split( /\s*,\s*/, $value );
        my $initcounter = defined $size ? $size : 1;
        my $counter = $initcounter;
        $result =
"<table style='border:none;border-style:none;border-width:0;padding-top:0;'>";
        foreach my $option (@options) {
            $result .= "<tr>" if ( $counter == $initcounter );
            $result .=
"<td style='border:none;border-style:none;border-width:0;padding-top:0;'><input type='$type' ";
            $result .= "name='multitopicsavefield{$topicFQN}{$field}' ";
            $result .= "value='" . $option . "' ";
            if ( $type eq 'radio' && $option eq $value ) {
                $result .= "checked='checked' ";
            }
            if ( $type eq 'checkbox' && grep ( /^$option$/, @values ) ) {
                $result .= "checked='checked' ";
            }
            $result .= "/> $option </td>";
            unless ( --$counter ) {
                $result .= "</tr> ";
                $counter = $initcounter;
            }
        }
        $result .= "</tr>" if ( $counter != $initcounter );
        $result .= "</table>";

        # We need a dummy hidden field to be able to send
        # none of the checkboxes selected from the browser
        $result .=
"<input type='hidden' name='multitopicsavefield{$topicFQN}{$field}' value='' />"
          if ( $type eq 'checkbox' );
    }
    elsif ( $type eq 'select' ) {
        my @values =
          map { s/^\s*(.*?)\s*$/$1/; $_; } split( /\s*,\s*/, $value );

        $result =
            "<select "
          . "name='multitopicsavefield{$topicFQN}{$field}' "
          . "class='foswikiSelect' ";

        $result .= "multiple='multiple' "
          if Foswiki::Func::isTrue($multiple);

        $result .= "size='$size'"
          if defined $size;

        $result .= ">";

        foreach my $option (@options) {
            $result .= "<option class='foswikiOption' ";

            if ( grep ( /^$option$/, @values ) ) {
                $result .= "selected='selected' ";
            }

            $result .= ">" . $option . "</option>";
        }

        $result .= "</select>";

        # We need a dummy hidden field to be able to send
        # none of the checkboxes selected from the browser
        $result .=
"<input type='hidden' name='multitopicsavefield{$topicFQN}{$field}' value='' />";
    }
    elsif ( $type eq 'hidden' ) {
        $result = "<input type='hidden' ";
        $result .= "name='multitopicsavefield{$topicFQN}{$field}' ";
        $result .= "value='" . $value . "' />";
    }

    # else if the type is unknown we return nothing

    return $result;
}

# The function used to handle the %MULTITOPICSAVEMESSAGE% macro
sub _MULTITOPICSAVEMESSAGE {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    # $session  - a reference to the Foswiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a Foswiki::Attrs object containing
    #             parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             (unnamed) parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the macro. This will replace the
    # macro call in the final text.

    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # $params->{sideorder} will be 'onions'

    return "%URLPARAM{\"MULTITOPICSAVEMESSAGE\"}%";
}

# The function used to handle the %MULTITOPICSAVESTARTFORM% macro
sub _MULTITOPICSAVESTARTFORM {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    my $result = "<form action='%SCRIPTURL{\"rest\"}%/"
      . "MultiTopicSavePlugin/multitopicsave' method='post'>";
    return $result;

}

# The function used to handle the %MULTITOPICSAVEENDFORM% macro
sub _MULTITOPICSAVEENDFORM {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    return "</form>";
}

=begin TML

---++ restMultiTopicSave($session) -> $text

This is the sub which is called called by the =rest= script with multitopicsave.

The parameter is:
   * =$session= - The Foswiki object associated to this session.

Additional parameters can be recovered via the query object in the $session, for example:

my $query = $session->{request};
my $web = $query->{param}->{web}[0];

For more information, check %SYSTEMWEB%.CommandAndCGIScripts#rest

For information about handling error returns from REST handlers, see
Foswiki::Support.Faq1

*Since:* Foswiki::Plugins::VERSION 2.0

=cut

sub restMultiTopicSave {
    my ($session) = @_;

    my $query = Foswiki::Func::getCgiQuery();

    my $redirecttopic = $query->param('redirecttopic') || '';
    my $redirectweb   = $query->param('redirectweb')   || '';
    my $sessionweb    = $session->{webName};
    my $sessiontopic  = $session->{topicName};
    my %parameters    = ();
    my $currentWikiName = Foswiki::Func::getWikiName();

    ( $redirectweb, $redirecttopic ) =
      Foswiki::Func::normalizeWebTopicName( $redirectweb, $redirecttopic );

    my $url =
      Foswiki::Func::getScriptUrl( $redirectweb, $redirecttopic, 'view' );
    my $message = '';

    if ( $currentWikiName eq $Foswiki::cfg{DefaultUserWikiName} ) {
        $message =
          "Only authenticated users are allowed to save multiple topics\n\n";
        $query->param( -name => 'MULTITOPICSAVEMESSAGE', -value => "$message" );
        Foswiki::Func::redirectCgiQuery( undef, $url, 1 );
        return undef;
    }

    # First we put all the multitopicsavefield parameters in a hash
    # parameters{topicname}{field}=value where value can be an array of
    # values from select fields
    foreach my $key ( $query->param() ) {
        if ( $key =~ /^multitopicsavefield{(.*?)}{(.*?)}$/ ) {

            my $topic       = $1;
            my $fieldName   = $2;
            my @fieldValues = $query->param($key);

            # Remove empty values, they are most likely dummy values used
            # to indicate that no value in a multiple checkbox or select
            # is selected
            @fieldValues = grep( /.+/, @fieldValues );
            $parameters{$topic}{$fieldName} = join( ", ", @fieldValues );
        }
    }

    # Now we traverse each topic and save all the parameters for
    # each topic if they have changed.

    my $topicsavecounter = 0;

    foreach my $topickey ( keys %parameters ) {

        my $saveThisTopic = 0;    # if 1 access is checked and granted

        my ( $web, $topic ) =
          Foswiki::Func::normalizeWebTopicName( '', $topickey );

        my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

        foreach my $fieldName ( keys %{ $parameters{$topickey} } ) {
            my $value = $parameters{$topickey}{$fieldName};
            my $fieldhashref = $meta->get( 'FIELD', $fieldName );

            my $oldValue =
                $fieldhashref
              ? $meta->get( 'FIELD', $fieldName )->{'value'}
              : '';

            # Note: We can actually find and store fields that are not in the
            # form definition topic. Let us call this a feature. Could be
            # useful for finding old formfields in topics after form is altered
            if ( $oldValue ne $value ) {

                # OK we want to save to the topic. If we already decided we can
                # save we do not need to check again
                unless (
                    $saveThisTopic
                    || Foswiki::Func::checkAccessPermission(
                        'CHANGE', $currentWikiName, undef, $topic, $web
                    )
                  )
                {
                    $message .= "Topic $web.$topic was not saved due to lack "
                      . "of access rights\n\n";
                    last;
                }
                unless ($saveThisTopic) {
                    my ( $oopsUrl, $loginName, $unlockTime ) =
                      Foswiki::Func::checkTopicEditLock( $web, $topic, undef );
                    my $lockedWikiName = Foswiki::Func::getWikiName($loginName);
                    if ( $unlockTime
                        && ( $lockedWikiName ne $currentWikiName ) )
                    {
                        $message .=
                            "Topic $web.$topic was not saved because it is"
                          . "currently being edited by !$lockedWikiName\n\n";
                        last;
                    }
                }

                $meta->putKeyed( 'FIELD',
                    { name => $fieldName, value => $value } );
                $saveThisTopic = 1;
            }
        }

        if ($saveThisTopic) {
            Foswiki::Func::saveTopic( $web, $topic, $meta, $text );

            #We need to avoid leaving many topics in locked state.
            Foswiki::Func::setTopicEditLock( $web, $topic, 0 );

            $topicsavecounter++;
        }
    }

    $message .= "Number of topics changed: $topicsavecounter";

    $query->param( -name => 'MULTITOPICSAVEMESSAGE', -value => "$message" );
    Foswiki::Func::redirectCgiQuery( undef, $url, 1 );
    return undef;
}

1;

__END__
# This copyright information applies to the MultiTopicSavePlugin:
#
# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2010 Kenneth Lavrsen and Foswiki Contributors.
# 
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# This license applies to MultiTopicSave and to any derivatives.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the root of this distribution.
