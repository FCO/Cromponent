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

sub parse(Mu:U $cromponent) {
	use Cro::WebApp::Template::Repository;
	use Cro::WebApp::Template::Parser;
	use Cro::WebApp::Template::ASTBuilder;

	my $code = $cromponent.RENDER;

	my $*TEMPLATE-FILE = $cromponent.^name.IO;
	my $*TEMPLATE-REPOSITORY = get-template-repository;

	my $*COMPILING-PRELUDE = True;
	#my $GLOBAL::COMPILING-PRELUDE = False;
	my %*WARNINGS;
	my $ast := Cro::WebApp::Template::Parser.parse(
		$code,
		actions => Cro::WebApp::Template::ASTBuilder,
	).ast;
	say $ast;
	$ast
}

sub compile($ast --> Str) {
	my $*IN-SUB = True;
        my $*IN-FRAGMENT = False;
        my $children-compiled = $ast.children.map(*.compile).join(", ");
        'sub ($_) { join "", (' ~ $children-compiled ~ ') }';
}
sub compile-cromponent(Mu:U $cromponent) {
	my $ast := $cromponent.&parse;
	my Str $code = $ast.&compile;
	say $code;
	$code
}

role Cromponent {
	my Str $compiled = ::?CLASS.&compile-cromponent;
	::?CLASS.^add_method: "Str", $compiled.EVAL;
}

