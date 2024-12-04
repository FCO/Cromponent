unit class Cromponent;
use Cro::WebApp::Template;
use Cro::HTTP::Router;

my %components;

role Accessible {
	has Bool $.accessible = True;
}

multi trait_mod:<is>(Method $m, :$accessible!) is export {
	$m does Accessible
}

sub add-component(
	$component is copy,
	:&load is copy,
	:delete(&del) is copy,
	:&create is copy,
	:$url-part = $component.^name.lc,
) is export {
	%components.push: $component.^name => %(:&load, :&delete, :$component);

	get -> Str $ where $url-part, $id {
		my $tag = $component.^name;
		my $comp = load $id;
		template-with-components "<\&{ $tag }( .comp )>", { :$comp };
	}
	post -> Str $ where $url-part {
		request-body -> $data {
			my $new = create $data.pairs.Map;
			redirect "/{$url-part}/{ $new.id }", :see-other
		}

	}
	delete -> Str $ where $url-part, $id {
		del $id;
		content 'text/html', ""
	}
	for $component.^methods -> $meth {
		my $name = $meth.name;
		get -> Str $ where $url-part, $id, Str $name {
			load($id)."$name"();
			redirect "/{ $url-part }/{ $id }", :see-other
		}
	}
}

sub template-with-components($template, $data!) is export {
	my $header = %components.values.map({
		my $name = .<component>.^name;
		my $t    = .<component>.RENDER;
		"<:sub {$name}(\$_)> $t </:>"
	}).join: "\n";
	template-inline "$header \n\n\n$template", $data;
}


=begin pod

=head1 NAME

Cromponent - blah blah blah

=head1 SYNOPSIS

=begin code :lang<raku>

use Cromponent;

=end code

=head1 DESCRIPTION

Cromponent is ...

=head1 AUTHOR

Fernando Corrêa de Oliveira <fernando.correa@humanstate.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2024 Fernando Corrêa de Oliveira

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
