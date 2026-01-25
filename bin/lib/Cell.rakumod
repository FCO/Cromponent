use Cromponent;

class Cell does Cromponent {
	has Str() $.id;
	has Str() @.classes;
	has Str() $.scope;
	has Str() $.value;
	has Bool  $.header = False;

	multi method new(Str $value, *%pars) {
		self.new: :$value, |%pars
	}

	method arguments {
		'<?.classes>class="<@.classes><$_></@>"</?> <?.id>id="<.id>"</?>'
	}

	method RENDER {
		q:c:to/END/;
		<?.header>
			<th
				<?.scope>scope=<.scope></?>
				{ $.arguments // "" }
			>
				<?.value><.value></?>
			</th>
		</?>
		<!>
			<td { $.arguments // "" }>
				<?.value><.value></?>
			</td>
		</!>
		END
	}
}

sub EXPORT() { Cell.^exports }
