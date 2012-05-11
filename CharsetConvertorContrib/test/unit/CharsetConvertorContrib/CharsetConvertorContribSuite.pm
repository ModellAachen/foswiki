# Convert entire Foswiki RCS databases from one character set to another
# Tests by Crawford Currie
# Requires co and ci to be installed on the test machine
package CharsetConvertorContribSuite;
use strict;
use utf8;
use warnings qw( FATAL utf8 );
use charnames qw( :full :short );

use FoswikiTestCase;
our @ISA = ('FoswikiTestCase');

use Foswiki();
use Encode();
use Data::Dumper;
use Foswiki::Contrib::CharsetConvertorContrib;

if ( $^V >= 5.12 ) {

    require feature;
    feature->import('unicode_strings');
}

my %origFoswikiCfg = %Foswiki::cfg;

# A selection of albhabetic character sequences in different encodings.
# These are of course stored in the source code here in utf8.
my %tests = (
    'iso-8859-1' => {    # 8 bit, western
        web        => 'ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏ',
        topic      => 'ÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞ',
        content    => 'ßàáâãäåæçèéêëìíî',
        attachment => 'ïðñòóôõöøùúûü.ýþÿ'
    },
    'cp-1251' => {       # 8 bit, Cyrillic
        topic      => 'АВБГДЕЖЗИЙКЛМНО',
        web        => 'ПРСТУФХЦЧШЩЪЫ',
        content    => 'ЬЭЮЯабвгдежзийклмно',
        attachment => 'прстуфхцчшщъыь.эюя'
    },
    'koi8-r' => {        # 8 bit, Cyrillic
        web        => 'юабцдефгхийклмнопярст',
        topic      => 'ужвьызшэщчъЮАБЦДЕФ',
        content    => 'ГХИЙКЛМНОПЯРСТУЖ',
        attachment => 'ВЬЫЗШЭ.ЩЧЪ'
    },
    'euc-jp' => {        # multibyte encoding, hiragana and kanji
        web        => 'ぁあぃいぅうぇえぉおかがきぎく',
        topic      => 'ぐけげこごさざしじすずせぜそ',
        content    => '亜唖娃阿哀愛挨姶逢葵茜穐悪握',
        attachment => '渥|旭葦芦鯵梓圧斡扱宛姐虻'
    },
    'big-5' => {         # multibyte encoding, TW chinese
        web        => '纘纙臠臡虆虇虈襹襺襼襻觿讘讙躥',
        topic      => '躤躣鑮鑭鑯鑱鑳靉顲饟鱨鱮鱭鸋鸍鸐',
        content    => '鸏鸒鸑麡黵鼉齇齸齻齺齹圞灦籯蠼',
        attachment => '釃鑴鑸鑶鑵驠鱴鱳鱱鱵鸔鸓黶鼊'
    }
);

sub new {
    my $class = shift;
    return $class->SUPER::new( 'CharsetConvertorTests', @_ );
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    binmode( STDOUT, ":utf8" );
    binmode( STDERR, ":utf8" );
}

sub fixture_groups {
    my ( $this, $suite ) = @_;

    return ( [ $this->fixgroup_charsets() ], $this->SUPER::fixture_groups );
}

sub fixgroup_charsets {
    my ($this) = @_;
    my @groups;

    foreach my $charset ( keys %tests ) {
        my $fn;
        my $name = $charset;
        $name =~ s/-/_/g;
        $fn = "SiteCharSet_$name";
        push( @groups, $fn );
        no strict 'refs';
        *{$fn} = sub {
            $Foswiki::cfg{Site}{CharSet} = $charset;
        };
        use strict 'refs';
    }

    return @groups;
}

# For each charset, construct a web using that charset.
sub set_up_verify {
    my $this = shift;

    $this->{test_web} = "TemporaryCharsetConvertorTestWeb";
    my $utf8 = $tests{ $Foswiki::cfg{Site}{CharSet} };
    my %c;
    foreach my $k ( keys %$utf8 ) {

    # DANGER, Will Robinson!
    # Encode::encode smashes the string passed to it, despite what the doc says.
        my $string = $utf8->{$k};
        $c{$k} = Encode::encode( $Foswiki::cfg{Site}{CharSet},
            $string, Encode::FB_CROAK );
        $this->assert( !utf8::is_utf8( $c{$k} ) );
    }
    $this->{session} = new Foswiki();

    my $root = new Foswiki::Meta( $this->{session}, $this->{test_web} );
    $root->populateNewWeb();

    # Create a subweb.
    # CHECK: that it's renamed
    my $subweb =
      new Foswiki::Meta( $this->{session}, $this->{test_web} . '/' . $c{web} );
    $subweb->populateNewWeb();

    $this->assert(
        $this->{session}->webExists( $this->{test_web} . '/' . $c{web} ) );

    # Create a topic
    # CHECK: that it's renamed
    my $topic =
      new Foswiki::Meta( $this->{session}, $this->{test_web} . '/' . $c{web},
        $c{topic}, $c{content} );
    $this->assert( !utf8::is_utf8( $c{content} ) );
    $topic->save();

# Use DataDir for an attachment file, both to check it isn't renamed but also so
# it get mopped up when the fixture is removed.
# CHECK: that it's still there, with the same name
    my $f;
    $this->assert(
        open( $f, ">$Foswiki::cfg{DataDir}/$this->{test_web}/$c{attachment}" ),
        $!
    );
    print $f join( '', values %c );
    close($f);
    $topic->attach(
        name    => $c{attachment},
        dontlog => 1,
        comment => $c{content},
        file    => "$Foswiki::cfg{DataDir}/$this->{test_web}/$c{attachment}"
    );

    $topic =
      new Foswiki::Meta( $this->{session}, $this->{test_web} . '/' . $c{web},
        $c{topic} );
    $topic->text("$c{content} Cabbage water $c{content}");
    $topic->save( forcenewrevision => 1 );

    $topic =
      new Foswiki::Meta( $this->{session}, $this->{test_web} . '/' . $c{web},
        $c{topic} );
    $topic->text( $c{content} );
    $topic->save( forcenewrevision => 1 );

    $this->assert(
        -e "$Foswiki::cfg{DataDir}/$this->{test_web}/$c{web}/$c{topic}.txt" );
    $this->assert( $this->{session}
          ->topicExists( $this->{test_web} . '/' . $c{web}, $c{topic} ) );

    $topic =
      Foswiki::Meta->load( $this->{session}, "$this->{test_web}/$c{web}",
        $c{topic} );
    $this->assert( $topic->hasAttachment( $c{attachment} ) );
}

sub verify_conversion {
    my $this = shift;
    $this->set_up_verify();

    Foswiki::Contrib::CharsetConvertorContrib::convertCollection(
        $this->{test_web},
        -a => 1,
        -q => 1,
        -i => 0
    );

    # Make sure it happened!
    $this->{session}->finish();

    # The web, topic etc names will now be UTF8
    my $utf8 = $tests{ $Foswiki::cfg{Site}{CharSet} };

    # And the charset too
    $Foswiki::cfg{Site}{CharSet} = 'utf-8';

    $this->{session} = new Foswiki();
    $this->assert( $this->{session}->webExists( $this->{test_web} ) );
    $this->assert(
        $this->{session}->webExists("$this->{test_web}/$utf8->{web}") );
    $this->assert( $this->{session}
          ->topicExists( "$this->{test_web}/$utf8->{web}", $utf8->{topic} ) );

    # Load the latest (should be rev 4)
    my $meta =
      Foswiki::Meta->load( $this->{session}, "$this->{test_web}/$utf8->{web}",
        $utf8->{topic} );
    $this->assert( $meta->hasAttachment( $utf8->{attachment} ) );
    my $t = $meta->text();
    utf8::decode($t);
    $this->assert_str_equals( $utf8->{content}, $t );

    # There should be 3 revs, 1, 2 and 3. Revs 1 and 3 contain the same content,
    # while rev 2 has the content twice.
    $meta =
      Foswiki::Meta->load( $this->{session}, "$this->{test_web}/$utf8->{web}",
        $utf8->{topic}, 2 );
    $t = $meta->text();
    utf8::decode($t);
    $this->assert_str_equals( "$utf8->{content} Cabbage water $utf8->{content}",
        $t );

    $meta =
      Foswiki::Meta->load( $this->{session}, "$this->{test_web}/$utf8->{web}",
        $utf8->{topic}, 1 );
    $t = $meta->text();
    utf8::decode($t);
    $this->assert_str_equals( $utf8->{content}, $t );

    # TODO: check the content of the fixture.
    # TODO: check what happens with encoded comments, user IDs etc

    # Clean up fixture
    $this->removeWebFixture( $this->{session}, $this->{test_web} );
    $this->{session}->finish();
}

1;
