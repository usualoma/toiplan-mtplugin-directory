package jQuery;

use strict;
use warnings;

our @EXPORT = qw(jQuery);
use base qw(Exporter);

=pod

Usage:

	use jQuery;

	sub cb_edit_entry {
		my ( $cb, $app, $param, $tmpl ) = @_;

		jQuery('<app:setting id="a_field" />', $tmpl)->
			attr('label' => 'A Text Field')->
			attr('required' => 1)->
			html('<input name="a_field" />')->
			insertBefore('#tags');
	}

=cut

sub jQuery {
	jQuery->new(@_);
}

sub new {
	my $class = shift;
	my $self = bless({}, $class);
	my ($str, $tmpl) = @_;

	$self->{tmpl} = $tmpl;
	$self->{elements} = undef;

	if ($str =~ m/^#(\w+)/) {
    	$self->{elements} = [ $tmpl->getElementById($1) ];
	}
	elsif ($str =~ m/^\.(\w+)/) {
    	$self->{elements} = [ $tmpl->getElementsByClassName($1) ];
	}
	elsif ($str =~ m/^<\s*([\w:_]+)(.*)\/?>/) {
    	my $elm = $tmpl->createElement($1);
		while ($str =~ m/\s*(\w+)="([^"]+)"/g) {
			$elm->setAttribute($1, $2);
		}
		$self->{elements} = [ $elm ];
	}

	$self;
}

sub attr {
	my $self = shift;
	my ($key, $value) = @_;

	foreach my $e (@{ $self->{elements} }) {
		$e->setAttribute($key, $value);
	}

	$self;
}

sub insertBefore {
	my $self = shift;

	my ($str) = @_;
	foreach my $e1 (@{ jQuery($str, $self->{tmpl})->{elements} }) {
		foreach my $e2 (@{ $self->{elements} }) {
    		$self->{tmpl}->insertBefore($e2, $e1);
		}
	}

	$self;
}

sub html {
	my $self = shift;
	my ($str) = @_;

	foreach my $e (@{ $self->{elements} }) {
    	$e->innerHTML($str);
	}

	$self;
}

1;
