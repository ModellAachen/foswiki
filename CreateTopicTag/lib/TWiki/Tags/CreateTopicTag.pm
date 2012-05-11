# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
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
# For licensing info read LICENSE file in the TWiki root.
#
# '$Rev$'

=pod

---+ package CreateTopicTag

=cut

# Always use strict to enforce variable scoping
use strict;

use vars qw($tagname);
use TWiki::Tags::CreateTopicTag::Support;

$tagname = 'CREATETOPIC';

sub CREATETOPIC {
    my ( $session, $params, $topic, $web ) = @_;

    my $jsstart       = TWiki::Tags::CreateTopicTag::Support::getJSPrefix();
    my $jsend         = TWiki::Tags::CreateTopicTag::Support::getJSSuffix();
    my $templatetopic = $params->{templatetopic};
    my $showparents   = $params->{showparents} || 'off';
    my $action        = $params->{action};
    my $initialtext   = $params->{initialtext};
    my $form          = $params->{form};

    my $formtext = TWiki::Tags::CreateTopicTag::Support::getFormStart();
    $formtext .= TWiki::Tags::CreateTopicTag::Support::getStep1();
    $formtext .= TWiki::Tags::CreateTopicTag::Support::getStep2()
      if $showparents eq 'on';
    $formtext .= TWiki::Tags::CreateTopicTag::Support::getStep3();
    $formtext .= TWiki::Tags::CreateTopicTag::Support::getFormEnd();

    $formtext .=
      "\n<input type='hidden' name='templatetopic' value='$templatetopic'>"
      if $templatetopic;
    $formtext .= "\n<input type='hidden' name='action' value='$action'>"
      if $action;
    $formtext .= "\n<input type='hidden' name='text' value='$initialtext'>"
      if $initialtext;
    $formtext .= "\n<input type='hidden' name='form' value='$form'>" if $form;

    return join( "\n", $jsstart, $formtext, "</form>", $jsend );
}

1;
