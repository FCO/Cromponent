use Cro::WebApp::Template;
use Cro::HTTP::Router;

role Accessible {
	has Bool $.accessible = True;
}

multi trait_mod:<is>(Method $m, :$accessible!) is export {
	$m does Accessible
}

class Cromponent {
	has $.location = '';
	has %.components;

	multi method add(*@components) {
		self.add: $_ for @components
	}

	multi method add(
		$component is copy,
		:&load is copy,
		:delete(&del) is copy,
		:&create is copy,
		:&update is copy,
		:$url-part = $component.^name.lc,
		:$macro = False,
					 ) {
		%!components.push: $component.^name => %(:&load, :&delete, :$component, :tag-type($macro ?? 'macro' !! 'sub'));

		with &load {
			post -> Str $ where $url-part {
				request-body -> $data {
					my $new = create |$data.pairs.Map;
					redirect "{$!location}/{$url-part}/{ $new.id }", :see-other
				} with &create;
			}

			get -> Str $ where $url-part, $id {
				my $tag = $component.^name;
				my $comp = load $id;
				template-with-components self, "<\&{ $tag }( .comp )>", { :$comp };
			}

			delete -> Str $ where $url-part, $id {
				del $id;
				content 'text/html', ""
			} with &del;

			put -> Str $ where $url-part, $id {
				request-body -> $data {
					my $comp = load $id;
					update $comp, |$data.pairs.Map
				}
			} with &update;

			for $component.^methods -> $meth {
				my $name = $meth.name;

				if $meth.signature.params > 2 {
					put -> Str $ where $url-part, $id, Str $name {
						request-body -> $data {
							load($id)."$name"(|$data.pairs.Map);
							redirect "{$!location}/{ $url-part }/{ $id }", :see-other
						}
					}
				} else {
					get -> Str $ where $url-part, $id, Str $name {
						load($id)."$name"();
						redirect "{$!location}/{ $url-part }/{ $id }", :see-other
					}
				}
			}
		}
	}
}

sub template-with-components($cromponent, $template, $data?) is export {
	my %components := $cromponent.components;

	my $header = %components.values.map({
		my $sig  = .<component>.^attributes.grep(*.has_accessor).map({ ":\${ .name.substr(2) }" }).join: ", ";
		my $name = .<component>.^name;
		my $t    = .<component>.RENDER;
		my $tag  = .<tag-type> // "sub";
		my $call = $tag eq "sub" ?? "&" !! "|";
		qq:to/END/
		<:{ $tag } {$name}(\$_ = \$cromponents.{$name})>
		$t.indent(4)
		</:{ $tag }>
		<:{ $tag } {$name}-new({ $sig })>
			<{ $call }{ $name }(\$cromponents.{ $name }.new({ $sig }))> { " <:body> </{ $call }{ $name }> " if $tag eq "macro" }
		</:{ $tag }>
		END
	}).join: "\n";
	my $wrapped-data = {
		:$data,
		:cromponents(%components.kv.map(-> $key, % (:$component, |){ $key => $component }).Map)
	};
	my $wrapped-template = qq:to/END/;
		<:sub cromponent-wrapper\(\$cromponents, \$_)>
		$header.indent(4)
		$template.indent(4)
		</:sub>
		<&cromponent-wrapper\(.cromponents, .data)>
		END
	#say $wrapped-template;
	#say $wrapped-data;

	template-inline $wrapped-template, $wrapped-data;
}


=begin pod

=head1 NAME

Cromponent - A way create web components with cro templates

=head1 SYNOPSIS

=begin code :lang<raku>

use Cromponent;
class AComponent {
	has $.data;

	method RENDER {
		Q:to/END/
		<h1><.data></h1>
		END
	}
}

# for how to use that, please follow the examples on the bin/ dir

=end code

=head1 DESCRIPTION

Cromponent is a way create web components with cro templates

=head1 AUTHOR

Fernando Corrêa de Oliveira <fco@cpan.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2024 Fernando Corrêa de Oliveira

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
