use Cromponent;
use Tag;
use Cell;
use Row;

class Table does Tag does Cromponent {
	has Str() $.theme;
	has Str() $.head-theme;
	has Str() $.body-theme;
	has Str() $.foot-theme;
	has Row() @.head;
	has Row() @.body;
	has Row() @.foot;

	submethod BUILD(:@head, :@body, :@foot) {
		for @head <-> $row {
			next if $row ~~ Row;
			for $row[] <-> $cell {
				next if $cell ~~ Cell;
				$cell = Cell.new: $cell, :header, :scope<col>
			}
		}
		@!head = @head;
		for @body <-> $row {
			next if $row ~~ Row;
			next if $row.head ~~ Cell;
			$row[0] = Cell.new: $row.head, :header, :scope<row>
		}
		@!body = @body;
		for @foot <-> $row {
			next if $row ~~ Row;
			next if $row.head ~~ Cell;
			$row[0] = Cell.new: $row.head, :header, :scope<row>
		}
		@!foot = @foot;
	}

	method RENDER {
		q:c:to/END/;
		<table
			<?.theme>data-theme=<.theme></?>
			{ $.arguments }
		>
			<thead
				<?.head-theme>data-theme=<.head-theme></?>
			>
				<@.head>
					<&HTML($_)>
				</@>
			</thead>
			<tbody
				<?.body-theme>data-theme=<.body-theme></?>
			>
				<@.body>
					<&HTML($_)>
				</@>
			</tbody>
			<tfoot
				<?.foot-theme>data-theme=<.foot-theme></?>
			>
				<@.foot>
					<&HTML($_)>
				</@>
			</tfoot>
		</table>
		END
	}
}

sub EXPORT() { Row.^exports }
