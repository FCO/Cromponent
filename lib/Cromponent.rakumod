use Cro::WebApp::Template::Builtins;

multi trait_mod:<is>(Mu:U $comp, Bool :$macro!) is export {
	my role CromponentMacroHOW {
		method is-macro(|) { True }
	}
	$comp.HOW does CromponentMacroHOW
}

multi trait_mod:<is>(Method $m, Bool :$accessible!) is export {
	trait_mod:<is>($m, :accessible{})
}

multi trait_mod:<is>(Method $m, :$accessible! (:$name = $m.name)) is export {
	my role IsAccessible {
		has Str $.is-accessible-name;
		method is-accessible { True }
	}

	$m does IsAccessible($name)
}

my constant %escapes = %(
	'&' => '&amp;',
	'<' => '&lt;',
	'>' => '&gt;',
	'"' => '&quot;',
	"'" => '&apos;',
);

multi escape-text(Mu:U $t, Mu $file, Mu $line) {
	%*WARNINGS{"An expression at $file:$line evaluated to $t.^name()"}++;
	''
}

multi escape-text(Mu:D $text, Mu $, Mu $) {
	$text.Str.subst(/<[<>&]>/, { %escapes{.Str} }, :g)
}

multi escape-attribute(Mu:U $t, Mu $file, Mu $line) {
	%*WARNINGS{"An expression at $file:$line evaluted to $t.^name()"}++;
	''
}

multi escape-attribute(Mu:D $attr, Mu $, Mu $) {
	$attr.Str.subst(/<[&"']>/, { %escapes{.Str} }, :g)
}

my %pcache;

sub parse(Mu:U $cromponent) {
	my $name = $cromponent.^name;
	.return with %pcache{$name};
	use Cro::WebApp::Template::Repository;
	use Cro::WebApp::Template::Parser;
	use Cro::WebApp::Template::ASTBuilder;

	my $code = $cromponent.?RENDER // '';   #iamerejh

	my $*TEMPLATE-FILE = $cromponent.^name.IO;
	my $*TEMPLATE-REPOSITORY = get-template-repository;

	my $*COMPILING-PRELUDE = True;
	my %*WARNINGS;
	my $ast := Cro::WebApp::Template::Parser.parse(
		$code,
		actions => Cro::WebApp::Template::ASTBuilder,
		).ast;
	if %*WARNINGS {
		for %*WARNINGS.kv -> $text, $number {
			warn "$text ($number time{ $number == 1 ?? '' !! 's' })";
		}
	}
	%pcache{$name} = $ast;
	$ast
}

sub compile($ast, Bool :$macro = False --> Str) {
	my $*IN-SUB = False;
	my $*IN-FRAGMENT = False;
	my $children-compiled = $ast.children.map(*.compile).join(", ");
	$macro
		?? 'sub (&__MACRO_BODY__, $_) { join "", (' ~ $children-compiled ~ ') }'
		!! 'sub ($_) { join "", (' ~ $children-compiled ~ ') }'
		;
}
my %scache;
sub compile-cromponent(Mu:U $cromponent) {
	my $name = $cromponent.^name;
	.return with %scache{$name};
	my $ast := $cromponent.&parse;
	my Str $code = $ast.&compile: |(:macro if $cromponent.HOW.?is-macro: $cromponent);
	%scache{$name} = $code;
	$code
}
my %cache;
sub comp($code, $name) {
	sub {
		%cache{$name} //= $code.EVAL;
	}
}

use Cro::HTTP::Router;

role Cromponent {
	my $name = ::?CLASS.^name;
	::?CLASS.HOW does my role ExportMethod {
		method add-cromponent-routes(
			$component    is copy,
			:&load        is copy,
			:delete(&del) is copy,
			:&create      is copy,
			:&update      is copy,
			:$url-part = $component.^name.split('::').tail.lc,
			:$macro    = $component.HOW.?is-macro($component) // False,
									 ) is export {
			my $cmp-name = $component.^name;
			#			use Cro::HTTP::Router;
			without $*CRO-ROUTE-SET {
				die "Cromponents should be added from inside a `route {}` block"
			}
			my $route-set := $*CRO-ROUTE-SET;

			&load   //= -> $id         { $component.LOAD: $id      } if $component.^can: "LOAD";
			&create //= -> *%pars      { $component.CREATE: |%pars } if $component.^can: "CREATE";
			&del    //= -> $id         { load($id).DELETE          } if $component.^can: "DELETE";
			&update //= -> $id, *%pars { load($id).UPDATE: |%pars  } if $component.^can: "UPDATE";

			with &load {
				my &LOAD = -> $id {
					my $obj = load $id;
					die "Cromponent '$cmp-name' could not be loaded with id '$id'" without $obj;
					$obj
				}
				with &create {
					note "adding POST $url-part";
					post -> Str $ where $url-part {
						request-body -> $data {
							my $new = create |$data.pairs.Map;
							redirect "$url-part/{ $new.id }", :see-other
						}
					}
				}

				note "adding GET $url-part/<id>";
				get -> Str $ where $url-part, $id {
					my $tag = $component.^name;
					my $comp = LOAD $id;
					if $component.^can: "RESPOND" {
						respond $comp
					} else {
						content 'text/html', $comp.Str
					}
				}

				with &del {
					note "adding DELETE $url-part/<id>";
					delete -> Str $ where $url-part, $id {
						del $id;
						content 'text/html', ""
					}
				}

				with &update {
					note "adding PUT $url-part/<id>";
					put -> Str $ where $url-part, $id {
						request-body -> $data {
							update $id, |$data.pairs.Map
						}
					}
				}

				for $component.^methods.grep(*.?is-accessible) -> $meth {
					my $name = $meth.is-accessible-name;

					if $meth.signature.params > 2 {
						note "adding PUT $url-part/<id>/$name";
						put -> Str $ where $url-part, $id, Str $name {
							request-body -> $data {
								LOAD($id)."$name"(|$data.pairs.Map);
								redirect "../{ $id }", :see-other unless $component.^can: "RESPOND"
							}
						}
					} else {
						note "adding GET $url-part/<id>/$name";
						get -> Str $ where $url-part, $id, Str $name {
							LOAD($id)."$name"();
							redirect "../{ $id }", :see-other unless $component.^can: "RESPOND"
						}
					}
				}
			}
		}
		method exports( Mu:U $class --> Map() ) {
			if $class.^can: "RENDER" {
				my Str $compiled = $class.&compile-cromponent;
				my $name = $class.^name;
				my &compiled = comp $compiled, $name;
				do if $class.HOW.?is-macro: $class {
					Map.new: (
					'&__TEMPLATE_MACRO__' ~ $name => sub (&body, |c) {
						compiled.(&body, $class.new: |c)
					}
					)
				} else {
					Map.new: (
					'&__TEMPLATE_SUB__' ~ $name => sub (|c) {
						compiled.($class.new(|c))
					}
					)
				}
			}
		}
	}
	::?CLASS.^add_method: "Str", my method (|c) {
		my Str $compiled = self.WHAT.&compile-cromponent;
		my $name = self.^name;
		my &compiled = comp $compiled, $name;
		my %*WARNINGS;
		use Cro::WebApp::Template::Repository;
		my $*TEMPLATE-REPOSITORY = get-template-repository;

		my $resp = compiled.(self,|c);

		if %*WARNINGS {
			for %*WARNINGS.kv -> $text, $number {
				warn "$text ($number time{ $number == 1 ?? '' !! 's' })";
			}
		}
		$resp
	}
}

sub respond($comp) is export {
	content 'text/html', $comp.RESPOND
}

=begin pod

=head1 NAME

Cromponent - A way create web components with cro templates

=head1 SYNOPSIS

=begin code :lang<raku>

use Cromponent;
class AComponent does Cromponent {
	has $.data;

	method RENDER {
		Q:to/END/
		<h1><.data></h1>
		END
	}
}

sub EXPORT { AComponent.^exports }

=end code

=head1 DESCRIPTION

Cromponent is a way create web components with cro templates

You can use Cromponents in 3 distinct (and complementar) ways

=begin item

In a template only way:
If wou just want your Cromponent to be a "fancy substitute for cro-template sub/macro",
You can simpley create your Cromponent, and on yout template, <:use> it, it with export
a sub (or a macro if you used the C<is macro> trait) to your template, that sub (or macro)
will accept any arguments you pass it and will pass it to your Cromponent's conscructor
(new), and use the result of that as the value to be used.

Ex:

=begin code :lang<raku>
use Cromponent;

class H1 does Cromponent is macro {
	has Str $.prefix = "My fancy H1";

	method RENDER {
		Q[<h1><.prefix><:body></h1>]
	}
}

sub EXPORT { H1.^exports }

=end code

On your template:

=begin code :lang<crotmp>

<:use H1>
<|H1(:prefix('Something very important: '))>
	That was it
</|>

=end code

=end item

=begin item

As a value passed as data to the template.
If a Cromponent is passed as a value to a template, you can simply "print" it inside the template
to have its rendered version, it will probably be an HTML, so it will need to be called inside
a <&HTML()> call (I'm still trying to figureout how to avoid that requirement).

Ex:

=begin code :lang<raku>
use Cromponent;

class Todo does Cromponent {
	has Str  $.text is required;
	has Bool &.done = False;

	method RENDER {
		Q:to/END/
		<tr>
			<td>
				<input type='checkbox' <?.done>checked</?>>
			</td>
			<td>
				<.text>
			</td>
		</tr>
		END
	}
}

sub EXPORT { Todo.^exports }

=end code

On your route:

=begin code :lang<raku>

template "todos.crotmp", { :todos(<bla ble bli>.map: -> $text { Todo.new: :$text }) }

=end code

On your template:

=begin code :lang<crotmp>
<@.todos: $todo>
	<&HTML($todo)>
</@>

=end code

=end item

=begin item

You can also use a Cromponent to auto-generate cro routes

Ex:

=begin code :lang<raku>
use Cromponent;

class Text does Cromponent {
	my UInt $next-id = 1;
	my %texts;

	has UInt $.id      = $next-id++;
	has Str  $.text is required;
	has Bool $.deleted = False;

	method TWEAK(|) { %tests{$!id} = self }

	method LOAD($id) { %tests{$id} }

	method all { %texts.values }

	method toggle is accessoble {
		$!deleted = !$!deleted
	}

	method RENDER {
		Q:to/END/
		<?.deleted><del><.text></del></?>
		<!><.text></!>
		END
	}
}

sub EXPORT { Todo.^exports }

=end code

On your route:

=begin code :lang<raku>

use Text;
route {
	Text.^add-cromponent-routes;

	get -> {
		template "texts.crotmp", { :texts[ Texts.all ] }
	}
}

=end code

The call to the .^add-cromponent-routes method will create (on this case) 2 endpoints:

=item C</text/<id>> -- that will return the HTML ot the obj with that id rendered (it will use the method C<LOAD> to get the object)

=item C</text/<id>/toggle> -- that will load the object using the method C<LOAD> and call C<toggle> on it

You can also define the method C<CREATE>, C<DELETE>, and C<UPDATE> to allow it to create other endpoints.

=end item

=head1 AUTHOR

Fernando Corrêa de Oliveira <fco@cpan.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2024 Fernando Corrêa de Oliveira

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
