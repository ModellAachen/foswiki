package ConfigureTemplateTests;
use base qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser;

my $DEBUG              = 0;
my $PARSER_DEBUG       = $DEBUG ? 0x1F : 0;
my $PARSER_DEBUG_LEVEL = $DEBUG ? 0x1F : 0;

sub new {
    my $self = shift()->SUPER::new( 'ConfigureTemplateTests', @_ );
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
}

# main.tmpl

=pod

=cut

sub test_main_configureTools {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#if totalWarnings?? || totalErrors??>Status:</#if>
<#if totalErrors??><span class=\'configureStatusErrors\'>${totalErrors}</span></#if>
<#if totalWarnings??><span class=\'configureStatusWarnings\'>${totalWarnings}</span></#if>

<#if firstTime?? && firstTime == 1>(we will solve this in a minute)</#if>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse(
        $template,
        {
            totalWarnings         => 1,
            totalErrors           => 1,
            configureStatusErrors => 1,
        }
    );
    $result = $parsed;
    $expected =
'Status:<span class=\'configureStatusErrors\'>1</span><span class=\'configureStatusWarnings\'>1</span>';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_main_configureMainContents {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#if contents??>${contents}</#if>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, { contents => 'abcdefg', } );
    $result   = $parsed;
    $expected = 'abcdefg';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

=pod

=cut

sub test_main_navigation {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#if navigation??>
${navigation}
</#if>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed   = $parser->parse( $template, { navigation => 'navigation', } );
    $result   = $parsed;
    $expected = 'navigation';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

# installed.tmpl

=pod

=cut

sub test_installed {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<ul>
<li><a href=\'${frontpageUrl}\'>Go to your Foswiki front page</a></li>
<li><a href=\'${configureUrl}\'>Return to configuration </a></li>
</ul>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse(
        $template,
        {
            frontpageUrl => 'http://a/bin/c',
            configureUrl => 'http://x/bin/z'
        }
    );
    $result   = $parsed;
    $expected = '<ul>
<li><a href=\'http://a/bin/c\'>Go to your Foswiki front page</a></li>
<li><a href=\'http://x/bin/z\'>Return to configuration </a></li>
</ul>';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

# pagebegin.tmpl

sub test_pagebegin {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template =
'<form method="post" action="${formAction}" enctype="multipart/form-data" name="update">
<input type="hidden" name="time" value="${time}"  />';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse(
        $template,
        {
            formAction => 'configure',
            time       => '99874321'
        }
    );
    $result = $parsed;
    $expected =
'<form method="post" action="configure" enctype="multipart/form-data" name="update">
<input type="hidden" name="time" value="99874321"  />';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

# extensions.tmpl

sub test_extensions {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#if consultedLocations??>
<div class="configureConsultedLocations">
Consulted locations: ${consultedLocations?join(", ")}
</div>
</#if>

<#-- errors -->
<#if errors??>
<#list errors as i>
<div class=\'configureError\'>${i}</div>
</#list>
</#if>

<#-- table contents -->
<#if table??>
<form action="${formAction}" method="POST">
<input type="hidden" name="action" value="ManageExtensions" />
<table class=\'configureExtensionsTable\' border=\'0\' cellspacing=\'0\'>
${table}
</table>
<div class="configureActions"><div class=\'foswikiLeft\'>Currently installed: ${installedCount} out of ${allCount}</div> <input type="submit" name="submit" class="foswikiSubmit" value="Install / uninstall selected extensions" /></div>
</form>
</#if>';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse(
        $template,
        {
            consultedLocations => [ 'http://foswiki.org', 'http://twiki.org' ],
            errors             => [ 'error 1',            'error 2' ],
            formAction         => 'save',
            table          => '<tr><th>header</th></tr>',
            installedCount => 30,
            allCount       => 255,
        }
    );
    $result   = $parsed;
    $expected = '<div class="configureConsultedLocations">
Consulted locations: http://foswiki.org, http://twiki.org
</div>
<div class=\'configureError\'>error 1</div>
<div class=\'configureError\'>error 2</div>

<form action="save" method="POST">
<input type="hidden" name="action" value="ManageExtensions" />
<table class=\'configureExtensionsTable\' border=\'0\' cellspacing=\'0\'>
<tr><th>header</th></tr>
</table>
<div class="configureActions"><div class=\'foswikiLeft\'>Currently installed: 30 out of 255</div> <input type="submit" name="submit" class="foswikiSubmit" value="Install / uninstall selected extensions" /></div>
</form>';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

# feedback.tmpl

=pod

=cut

sub test_feedback {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template =
'<#if messageType == 4><div class="foswikiNotification"> Password changed </div></#if>

<h2>Your updates...</h2>          

<#if changesList??>
<div class=\'configureChangeList\'>
<table>
<#list changesList as i>
<tr><th>${i.key}</th><td>${i.value}</td></tr>
</#list>
</table>
</div>
</#if>

<h2>Update done!</h2>
<ul>
<li><a href=\'${frontpageUrl}\'>Go to your Foswiki front page</a></li>
<li><a href=\'${configureUrl}\'>Return to configuration </a></li>
</ul>
';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse(
        $template,
        {
            messageType => 4,
            changesList =>
              [ { key => 'A', value => 'a' }, { key => 'B', value => 'b' } ],
            frontpageUrl => 'http://a/bin/c',
            configureUrl => 'http://x/bin/z'
        }
    );
    $result   = $parsed;
    $expected = '<div class="foswikiNotification"> Password changed </div>
<h2>Your updates...</h2>          

<div class=\'configureChangeList\'>
<table>
<tr><th>A</th><td>a</td></tr>
<tr><th>B</th><td>b</td></tr>
</table>
</div>
<h2>Update done!</h2>
<ul>
<li><a href=\'http://a/bin/c\'>Go to your Foswiki front page</a></li>
<li><a href=\'http://x/bin/z\'>Return to configuration </a></li>
</ul>';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

# section.tmpl

=pod

=cut

sub test_section {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template =
'<div id=\'${id}Body\' class=\'${bodyClass}\'><a name=\'${id}\'><!--//--></a>

<#-- any header -->
<#if headline??><h${depth}>${headline}</h${depth}></#if>

<#-- any warning or error message -->
<#-- suppress blocks for level 3 to not clutter the interface too much -->
<#-- work around not having nested if statements -->
<#if depth < 3 && warnings?? || errors??><div class=\'foswikiAlert\'></#if>
<#if depth < 3 && errors??><span class=\'configureStatusErrors\'>${errors}</span></#if>
<#if depth < 3 && warnings??><span class=\'configureStatusWarnings\'>${warnings}</span></#if>
<#if depth < 3 && warnings?? || errors??></div></#if>

<#-- any navigation -->
<#if navigation??>${navigation}</#if>

<#-- any description -->
<#if description??>${description}</#if>

<#-- any contents (table) -->
<#if contents??>${contents?replace("CONFIGURE_EXPERT_LINK", "<span><a class=\'configureExpert\' style=\'display:none\' href=\'#\'>Hide expert options</a><a class=\'configureNotExpert foswikiMakeVisible\' style=\'display:none\' href=\'#\'>Show expert options</a></span>")?replace("CONFIGURE_INFO_LINK", "<span><a class=\'configureInfoText foswikiMakeVisible\' href=\'#\'>Hide info texts</a><a class=\'configureNotInfoText foswikiMakeVisible\' href=\'#\'>Show info texts</a></span>")}</#if>

</div><!--/${id}Body-->';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse(
        $template,
        {
            id          => 'security',
            bodyClass   => 'main',
            headline    => 'Security',
            depth       => 2,
            warnings    => 'warnings',
            errors      => 'errors',
            navigation  => 'navigation',
            description => 'description',
            contents    => '<div class=\'configureLegend\'>
\t<table class=\'configureLegend configureSectionValues\' border=\'0\' cellpadding=\'0\'>
\t\t<tr>
\t\t\t<th colspan=\'2\'>Explanation of colours and symbols</th>
\t\t</tr>
\t\t<tr>
\t\t\t<td><div class=\'configureMessageBox\'>{DefaultUrlHost}&nbsp;<span class=\'configureMandatory\'>required</span></div></td>
\t\t\t<td><strong>Required settings</strong>Must have a value</td>
\t\t</tr>
\t\t<tr>
\t\t\t<td><div class=\'configureMessageBox foswikiAlert configureError\'><span><strong>Error</strong></div></td>
\t\t\t<td><strong>Errors</strong>Must be fixed</td>
\t\t</tr>
\t\t<tr>
\t\t\t<td><div class=\'configureMessageBox foswikiAlert configureWarn\'><span><strong>Warning</strong></div></td>
\t\t\t<td><strong>Warnings</strong>Non-fatal, but often a good indicator that something is wrong</td>
\t\t</tr>
\t\t<tr>
\t\t\t<td><div class=\'configureMessageBox foswikiAlert configureExpertExample\'>{Validation}{Method}</div></td>
\t\t\t<td><strong>Expert settings</strong>For expert use only. You should not fiddle with them unless you have read all the documentation first.</td>
\t\t</tr>
\t</table>
</div>

<h3>If your Foswiki site is already working</h3>
<p>You will now need to consider how you are going to manage
authentication and access control.<br />
See the reference manual sections on <a rel="nofollow" href="/~arthur/unittestfoswiki/core/bin/view/System/UserAuthentication">
authentication</a> and
<a rel="nofollow" href="/~arthur/unittestfoswiki/core/bin/view/System/AccessControl">
access control</a>, and the \'Security\' section.</p>

<p>Continue to <a rel="nofollow" href="/~arthur/unittestfoswiki/core/bin/view/System/WebHome">
browse to the Foswiki WebHome</a>.</p>

<h3>How to become an administrator</h3>
<p>You need to first <a rel="nofollow" href="/~arthur/unittestfoswiki/core/bin/view/System/UserRegistration">
register</a> as a normal user and then goto <a rel="nofollow" href="/~arthur/unittestfoswiki/core/bin/view/Main/AdminGroup">
AdminGroup</a> and add that user to the GROUP setting (follow the text in yellow).</p>

<h3>If you are on a non-standard platform or environment</h3>
There are a lot of <a href="http://foswiki.org/Support/SupplementalDocuments">supplemental documents</a> on Foswiki.org</p>

<h3>If you get stuck</h3>
<p>There is a lot of support available at the
<a href="http://foswiki.org/Support/WebHome">Support forum</a>.</p>

<p class="foswikiClear"></p>',
        }
    );
    $result = $parsed;
    $expected =
'<div id=\'securityBody\' class=\'main\'><a name=\'security\'><!--//--></a>

<h2>Security</h2>
<div class=\'foswikiAlert\'><span class=\'configureStatusErrors\'>errors</span><span class=\'configureStatusWarnings\'>warnings</span></div>
navigation
description
<div class=\'configureLegend\'>
\t<table class=\'configureLegend configureSectionValues\' border=\'0\' cellpadding=\'0\'>
\t\t<tr>
\t\t\t<th colspan=\'2\'>Explanation of colours and symbols</th>
\t\t</tr>
\t\t<tr>
\t\t\t<td><div class=\'configureMessageBox\'>{DefaultUrlHost}&nbsp;<span class=\'configureMandatory\'>required</span></div></td>
\t\t\t<td><strong>Required settings</strong>Must have a value</td>
\t\t</tr>
\t\t<tr>
\t\t\t<td><div class=\'configureMessageBox foswikiAlert configureError\'><span><strong>Error</strong></div></td>
\t\t\t<td><strong>Errors</strong>Must be fixed</td>
\t\t</tr>
\t\t<tr>
\t\t\t<td><div class=\'configureMessageBox foswikiAlert configureWarn\'><span><strong>Warning</strong></div></td>
\t\t\t<td><strong>Warnings</strong>Non-fatal, but often a good indicator that something is wrong</td>
\t\t</tr>
\t\t<tr>
\t\t\t<td><div class=\'configureMessageBox foswikiAlert configureExpertExample\'>{Validation}{Method}</div></td>
\t\t\t<td><strong>Expert settings</strong>For expert use only. You should not fiddle with them unless you have read all the documentation first.</td>
\t\t</tr>
\t</table>
</div>

<h3>If your Foswiki site is already working</h3>
<p>You will now need to consider how you are going to manage
authentication and access control.<br />
See the reference manual sections on <a rel="nofollow" href="/~arthur/unittestfoswiki/core/bin/view/System/UserAuthentication">
authentication</a> and
<a rel="nofollow" href="/~arthur/unittestfoswiki/core/bin/view/System/AccessControl">
access control</a>, and the \'Security\' section.</p>

<p>Continue to <a rel="nofollow" href="/~arthur/unittestfoswiki/core/bin/view/System/WebHome">
browse to the Foswiki WebHome</a>.</p>

<h3>How to become an administrator</h3>
<p>You need to first <a rel="nofollow" href="/~arthur/unittestfoswiki/core/bin/view/System/UserRegistration">
register</a> as a normal user and then goto <a rel="nofollow" href="/~arthur/unittestfoswiki/core/bin/view/Main/AdminGroup">
AdminGroup</a> and add that user to the GROUP setting (follow the text in yellow).</p>

<h3>If you are on a non-standard platform or environment</h3>
There are a lot of <a href="http://foswiki.org/Support/SupplementalDocuments">supplemental documents</a> on Foswiki.org</p>

<h3>If you get stuck</h3>
<p>There is a lot of support available at the
<a href="http://foswiki.org/Support/WebHome">Support forum</a>.</p>

<p class="foswikiClear"></p>
</div><!--/securityBody-->';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

# findextensionsintro.tmpl

=pod

=cut

sub test_findextensionsintro {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    $template = '<#assign localErrorMessage>
<div class=\'foswikiAlert configureWarn\'>
Cannot load the extensions installer.<br />
Check \'Perl Modules\' in the \'CGI Setup\' section above, and install any
missing modules required for the Extensions Installer.
</div>
</#assign>

<#assign localOkMessage>
<div class=\'foswikiNotification enableWhenSomethingChanged foswikiHidden\'>
<span class="foswikiAlert"><strong>You made some changes! Consider saving them first.</strong></span>
Otherwise click to <a href=\'${scriptName}?action=FindMoreExtensions\' class=\'foswikiButton\'>Install and Update Extensions</a>
</div>
<div class=\'foswikiNotification showWhenNothingChanged\'>
<strong>If you have made any changes, consider saving them first.</strong>
<a href=\'${scriptName}?action=FindMoreExtensions\' class=\'foswikiButton\'>Install and Update Extensions</a>
</div>
</#assign>

<#if hasError?? && hasError == 1>
${localErrorMessage}
<#else>
${localOkMessage}
</#if>
';
    $parser = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed = $parser->parse( $template, {} );
    $result = $parsed;
    $expected =
'<div class=\'foswikiNotification enableWhenSomethingChanged foswikiHidden\'>
<span class="foswikiAlert"><strong>You made some changes! Consider saving them first.</strong></span>
Otherwise click to <a href=\'?action=FindMoreExtensions\' class=\'foswikiButton\'>Install and Update Extensions</a>
</div>
<div class=\'foswikiNotification showWhenNothingChanged\'>
<strong>If you have made any changes, consider saving them first.</strong>
<a href=\'?action=FindMoreExtensions\' class=\'foswikiButton\'>Install and Update Extensions</a>
</div>';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

sub test_if_with_undefined_values {
    my ($this) = @_;

    my $template;
    my $parser;
    my $parsed, my $data;
    my $result;
    my $expected;

    # ---
    # 2x undef
    $template = '<#if depth < 3 && (warnings?? || errors??) >1</#if>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse(
        $template,
        {
            depth    => 2,
            warnings => undef,
            errors   => undef,
        }
    );
    $result   = $parsed;
    $expected = '';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ---
    # 1x undef
    $template = '<#if depth < 3 && (warnings?? || errors??) >1</#if>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse(
        $template,
        {
            depth    => 2,
            warnings => 1,
            errors   => undef,
        }
    );
    $result   = $parsed;
    $expected = '1';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );

    # ---
    # 1x undef, no ellipsis
    $template = '<#if depth < 3 && warnings?? || errors?? >1</#if>';
    $parser   = new Foswiki::Plugins::FreeMarkerPlugin::FreeMarkerParser();
    $parser->{debugLevel} = $PARSER_DEBUG_LEVEL;
    $parser->{debug}      = $PARSER_DEBUG;
    $parsed               = $parser->parse(
        $template,
        {
            depth    => 2,
            warnings => 1,
            errors   => undef,
        }
    );
    $result   = $parsed;
    $expected = '1';

    _trimSpaces($result);
    _trimSpaces($expected);

    print("RES=$result.\n")   if $DEBUG;
    print("EXP=$expected.\n") if $DEBUG;
    $this->assert( $result eq $expected );
}

# HELPER FUNCTIONS

sub _trimSpaces {

    #my $parsed = $_[0]

    $_[0] =~ s/^\s+//s;    # trim at start
    $_[0] =~ s/\s+$//s;    # trim at end
}

sub _dump {
    my ($data) = @_;

    use Data::Dumper;
    print "data=" . Dumper($data);
}

1;
