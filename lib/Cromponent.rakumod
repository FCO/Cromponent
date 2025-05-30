use Cromponent::CroTemplateOverrides;
use Cromponent::MetaCromponentRole;

multi trait_mod:<is>(Mu:U $comp, Bool :$macro!) is export {
	my role CromponentMacroHOW {
		method is-macro(|) { True }
	}
	$comp.HOW does CromponentMacroHOW
}

multi trait_mod:<is>(Method $m, Bool :$accessible!) is export {
	trait_mod:<is>($m, :accessible{})
}

multi trait_mod:<is>(
	Method $m,
	:%accessible! (
		:$name = $m.name,
		:$returns-cromponent = False,
		:$returns-html = False,
		:$http-method = "GET",
	)
) is export {
	my role IsAccessible {
		has Str  $.is-accessible-name is rw;
		method is-accessible { True }
	}
	
	my role ReturnsCromponent {
		method returns-cromponent { True }
	}

	my role ReturnsHtml {
		method returns-html { True }
	}

	my role HTTPMethod {
		has Str $.http-method;
	}

	$m does IsAccessible($name);
	$m does ReturnsCromponent if $returns-cromponent;
	$m does ReturnsHtml if $returns-html;
	$m does HTTPMethod($http-method);
	$m
}

role Cromponent {
	::?CLASS.HOW does Cromponent::MetaCromponentRole;

	my $name = ::?CLASS.^name;
	::?CLASS.^add_method: "Str", my method (|c) {
		my Str $compiled = self.WHAT.&compile-cromponent;
		my $name = self.^name;
		my &compiled = comp $compiled, $name;
		my %*WARNINGS;
		use Cro::WebApp::Template::Repository;
		my $*TEMPLATE-REPOSITORY = get-template-repository;

		my $resp = compiled.(self, |c);

		if %*WARNINGS {
			for %*WARNINGS.kv -> $text, $number {
				warn "$text ($number time{ $number == 1 ?? '' !! 's' })";
			}
		}
		$resp
	}
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

You can also define the method C<ADD>, C<DELETE>, and C<UPDATE> to allow it to create other endpoints.

=end item

=head1 AUTHOR

Fernando Corrêa de Oliveira <fco@cpan.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2024 Fernando Corrêa de Oliveira

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
