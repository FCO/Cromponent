use Cromponent;

my @manifest = <MyTable Row Cell>;

role Cell is export {
	has $.data is required;
	
	multi method new($data) {
		$.new: :$data
	}

	method RENDER {
		q:to/END/
			<td><.data></td>
		END
	}
}

role Row is export {
	has Cell() @.cells is required;
	
	multi method new(@cells) {
		$.new: :@cells
	}

	method RENDER {
		q:to/END/
			<tr>
				<@.cells: $c>
					<&Cell($c)>
				</@>
			</tr>
		END
	}
}

role MyTable is export {
	has Row() @.rows is required;
	
	multi method new(@rows) {
		$.new: :@rows
	}

	method RENDER {
		q:to/END/
			<table border=1>
				<@.rows: $r>
					<&Row($r)>
				</@>
			</table>
		END
	}
}


##### HTML Functional Export #####

# put in all the tags programmatically
# viz. https://docs.raku.org/language/modules#Exporting_and_selective_importing

my package EXPORT::DEFAULT {
	for @manifest -> $name {

		my $label = $name.lc;

		OUR::{'&' ~ $label} :=

			sub (*@a, :$topic! is rw, *%h) {

				$topic{$label} = ::($name).new( |@a, |%h );
				'<&' ~ $name ~ '(.' ~ $label ~ ')>';

			};
	}
}
