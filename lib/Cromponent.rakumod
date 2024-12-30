sub make-returner($ast) {
	my &renderer := $ast.compile;
	-> |c { renderer | c }
}

sub compile-cromponent(Mu:U $cromponent) {
	use Cro::WebApp::Template::Repository;
	use Cro::WebApp::Template::Parser;
	use Cro::WebApp::Template::ASTBuilder;

	my $*TEMPLATE-FILE = $cromponent.^name.IO;
	my $code = $cromponent.RENDER;

	my $*TEMPLATE-REPOSITORY = get-template-repository;

	my $ast = Cro::WebApp::Template::Parser.parse(
		$code,
		actions => Cro::WebApp::Template::ASTBuilder # if I comment out this actions, it stops breaking
	).ast;

	return make-returner $ast;

}

unit role Cromponent;

my %compiled := ::?CLASS.&compile-cromponent;
::?CLASS.^add_method: "Str", %compiled<renderer>;
dd %compiled;

