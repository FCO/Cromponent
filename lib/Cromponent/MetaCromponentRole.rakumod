use Cromponent::CroTemplateOverrides;
use Cromponent::Traits;
unit role Cromponent::MetaCromponentRole;

sub to-kebab(Str() $_) {
	lc S:g/(\w)<?before <[A..Z]>>/$0-/
}

method call-pars(&load) {
	&load.signature.params.map({ .name }).join(", ");
}

sub has-traits(Parameter $_) {
	.?trait-used || .^roles.any.^name.starts-with: "Cro::HTTP::Router::"
}

method load-sig(&load) {
	&load.signature.params.map({
		my Str $type = .type.HOW ~~ Metamodel::CoercionHOW
			?? .type.^constraint_type.^name
			!! .type.^name
		;

		"$type { .name }{ " is { .Str }" with .?trait-used }"
	}).join: ", "
}

method load-sig-no-traits(&load) {
	&load.signature.params.map({
		my Str $type = .type.HOW ~~ Metamodel::CoercionHOW
			?? .type.^constraint_type.^name
			!! .type.^name
		;

		next with .&has-traits;
		.say;
		say .^roles;
		"$type { .name }"
	}).join: ", "
}

method url-path(&load) {
	&load.signature.params.map({ "/<{ .type.^name } { .name }>" }).join: ""
}

method url-path-no-trait(&load) {
	&load.signature.params.map({
		next if .&has-traits;
		"/<{ .type.^name } { .name }>"
	}).join: ""
}

method get-sub(
	$component,
	&load,
	Str() :$url-part  = $component.^shortname.&to-kebab,
	Str() :$load-sig  = $.load-sig(&load),
	Str() :$call-pars = $.call-pars(&load),
) {
	my &LOAD = &load;
	use Cro::HTTP::Router;
	my $code = ("-> '$url-part'{ ", $load-sig" if $load-sig }" ~ q[ {
		my $tag = $component.^name;
		my $comp = LOAD ] ~ $call-pars ~ Q[;
		my $html = $comp.Str;
		content 'text/html', $html
	}]);
	say "code: $code";
	$code.EVAL
}

method del-sub(
	$component,
	&load,
	&del,
	Str() :$url-part  = $component.^shortname.&to-kebab,
	Str() :$del-sig  = $.load-sig(&load),
	Str() :$call-pars = $.call-pars(&del),
) {
	use Cro::HTTP::Router;
	("-> '$url-part'{ ", $del-sig" if $del-sig }" ~ q[ {
		my $ret = del ] ~ $call-pars ~ Q[;
		return content 'text/html', $ret.Str if $ret.^roles.map(*.^name).first: "Cromponent";
		content 'text/html', ""
	}]).EVAL
}

method update-sub(
	$component,
	&load,
	&update,
	Str() :$url-part  = $component.^shortname.&to-kebab,
	Str() :$update-sig  = $.load-sig(&load),
) {
	use Cro::HTTP::Router;
	("-> '$url-part'{ ", $update-sig" if $update-sig }" ~ q[ {
		request-body -> $data {
			my $updated = update |$data.pairs.Map;
			if $updated.^roles.map(*.^name).first: "Cromponent" {
				return content 'text/html', $updated.Str
			}
			content 'text/html', $component.Str
		}
	}]).EVAL
}

method list-loads($component, &load?) {
	my @loads = &load.defined
	?? &load.candidates
	!! do with $component.^find_method: "LOAD" {
		.candidates.map: {
			my $sig = .signature.params.skip.head(*-1).map({
				"{ .gist }{ " is {.Str}" with .?trait-used }"
			}).join: ", ";
			my $call = .signature.params.skip.head(*-1)>>.name.join: ", ";
			my $l = "-> $sig \{ \$component.LOAD{ ": $call" if $call} }";
			$l.EVAL
		}
	}

	@loads.sort: -*.count
}

sub note-route-added(Str $method, Str $path) {
	return unless %*ENV<CROMPONENT_ROUTES_ADDED>;
	note "adding $method $path"
}

method add-cromponent-routes(
	$component    is copy,
	:&load        is copy,
	:delete(&del) is copy,
	:&add         is copy,
	:&update      is copy,
	:$url-part = $component.^shortname.&to-kebab,
	:$macro    = $component.HOW.?is-macro($component) // False,
) is export {
	my $cmp-name = $component.^name;
	use Cro::HTTP::Router;
	without $*CRO-ROUTE-SET {
		die "Cromponents should be added from inside a `route {}` block"
	}
	my $route-set := $*CRO-ROUTE-SET;

	$component.?EXTRA-ENDPOINTS;

	for @.list-loads: $component, &load -> &load {
		my $load-sig            = $.load-sig: &load;
		my $load-sig-no-traits  = $.load-sig-no-traits: &load;
		my $call-pars           = $.call-pars: &load;

		&add    //= -> *%pars      { $component.ADD: |%pars  }       if $component.^can: "ADD";
		&del    //= "-> $load-sig \{ load($call-pars).DELETE }".EVAL if $component.^can: "DELETE";

		# TODO: differentiate load args from update args
		&update //= "-> {"$load-sig, " if $load-sig }*%pars \{ load($call-pars).UPDATE: |%pars }".EVAL if $component.^can: "UPDATE";

		my $l = qq[-> $load-sig \{
			my \$obj = load $call-pars;
			die "Cromponent '$cmp-name' could not be loaded\{ " with '$call-pars'" if ($call-pars) }" without \$obj;
			\$obj
		}];
		my &LOAD = $l.EVAL;
		my $path = $.url-path: &LOAD;
		my $path-no-trait = $.url-path-no-trait: &LOAD;
		say $path-no-trait;

		note-route-added "GET", "{ $url-part }$path-no-trait";
		get $.get-sub: $component, &LOAD;

		with &add {
			post ("-> '$url-part'{ ", { .Str }" with $load-sig } " ~ q[{
				request-body -> $data {
					my $new = add |$data.pairs.Map;
					if $new.^roles.map(*.^name).first: "Cromponent" {
						content 'text/html', $new.Str
					} elsif &load.count > 0 {
						redirect "$url-part/{ $new.id }", :see-other
					} else {
						redirect "$url-part", :see-other
					}
				}
			}]).EVAL;
		}

		with &del {
			note-route-added "DELETE", "$url-part$path-no-trait";
			delete $.del-sub: $component, &LOAD, &del;
		}

		with &update {
			note-route-added "PUT", "$url-part$path-no-trait";
			put $.update-sub: $component, &LOAD, &update;
		}

		for $component.^methods.grep(*.?is-accessible) -> $meth {
			my $name = $meth.is-accessible-name // $meth.name;
			my $returns-cromponent = $meth.?returns-cromponent;
			my $returns-html = $meth.?returns-html;

			my sub treat-request(:$load-capture, :$params-capture) {
				my $obj = LOAD |$load-capture;
				my $ret = $obj."$name"(|$params-capture);
				do if $returns-cromponent {
					content 'text/html', $ret.Str
				} elsif $returns-html {
					content 'text/html', $ret
				} else {
					return content "text/html", "" unless $ret;
					# redirect "../$url-part$path-no-trait", :see-other
					content 'text/html', $obj.Str
				}
			}

			my @params = $meth.signature.params.skip.head(*-1);
			my :(:@no-trait, :@trait) := @params.classify: { .?trait-used ?? "trait" !! "no-trait" }
			my $traits = @trait.map({ ", { .gist } is { .trait-used }" });
			my $traits-call = @trait.map({ "{ ":" if .named }{ .name }" }).join: ", ";
			note-route-added $meth.http-method.uc, "$url-part$path-no-trait/$name";
			if $meth.http-method.uc ne "GET" {
				my @param-names = @no-trait.map: *.name.substr: 1;
				my $code = ("sub ('$url-part'{", $load-sig-no-traits" if $load-sig-no-traits}, '$name'{ $traits }) \{
					request-body -> \$data \{
						treat-request
							:load-capture(\\($call-pars)),
							:params-capture(\\({
								(
									|@param-names.map({
										":$_\(\$data\<$_>)"
									}),
									$traits-call
								).join: ", "
							}))
						;
					}
				}");
				http $meth.http-method.uc, $code.EVAL;
			} else {
				my $query  = @no-trait.map({", { .gist } is query"}).join: ", ";
				my $params = @params.map({":{.name}"}).join: ", ";

				my $code = ("sub ('$url-part'{", $load-sig-no-traits" if $load-sig-no-traits}, '$name'{ "$query" if @params }{ $traits }) \{
					treat-request :load-capture(\\($call-pars)), :params-capture(\\($params))
				}");
				get $code.EVAL
			}
		}
	}
}

method exports(Mu:U $class) {
	my Str $compiled = $class.&compile-cromponent;
	my $name = $class.^shortname;
	my &compiled = comp $compiled, $name;
	do if $class.HOW.?is-macro: $class {
		Map.new: (
			'&__TEMPLATE_MACRO__' ~ $name => sub (&body, |c) {
				my $obj = $class.new: |c;
				.push: $obj with @*CROMPONENTS;
				{
					my @*CROMPONENTS := $obj.children[];
					compiled.(&body, $obj);
				}
			}
		)
	} else {
		Map.new: (
			'&__TEMPLATE_SUB__' ~ $name => sub (|c) {
				my $obj = $class.new: |c;
				.push: $obj with @*CROMPONENTS;
				{
					my @*CROMPONENTS := $obj.children[];
					compiled.($obj);
				}
			}
		)
	}
}
