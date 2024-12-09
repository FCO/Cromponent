use Cromponent;

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

role Table is export {
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
