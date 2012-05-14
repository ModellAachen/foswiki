package Foswiki::Plugins::SkillsPlugin::SkillNode;
use strict;
use Foswiki::Plugins::SkillsPlugin::NamedNode ();
our @ISA = ('Foswiki::Plugins::SkillsPlugin::NamedNode');

# Skill node, representing a skill or a category
sub new {
    my ( $class, $name ) = @_;
    my $this = $class->SUPER::new($name);
    $this->{text} = '';
    return $this;
}

sub serializable {
    my ( $this, $field ) = @_;
    return 1 if $field eq 'text';
    return $this->SUPER::serializable($field);
}

sub toString {
    my $this = shift;

    my $out = '';

    if ( $this->getDepth() ) {
        $out = '---' . ( '+' x $this->getDepth() ) . " $this->{name}\n";
    }
    $out .= $this->{text} . "\n" if $this->{text};

    foreach my $kid ( @{ $this->{childNodes} } ) {
        $out .= $kid->toString();
    }
    return $out;
}

1;

