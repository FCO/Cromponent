use Cromponent;
use Cell;

class Row does Cromponent {
	has Str()  $.id;
	has Str()  @.classes;
	has Cell() @.cells;

	multi method new(@cells, *%pars) {
		self.new: :@cells, |%pars
	}

	method arguments {
		'<?.classes>class="<@.classes><$_></@>"</?> <?.id>id="<.id>"</?>'
	}

	method RENDER {
		q:c:to/END/;
		<tr
			{ $.arguments // "" }
		>
		<@.cells>
			<&HTML($_)>
		</@>
		</tr>
		END
	}
}

sub EXPORT() { Row.^exports }
