sub compile-cromponent(Mu:U $cromponent) {
	Q[sub ($_) { join "", (Q『test』) }].EVAL
}

role Cromponent {
	my &compiled = ::?CLASS.&compile-cromponent;
	::?CLASS.^add_method: "Str", &compiled;
}

