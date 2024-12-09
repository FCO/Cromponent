#!/usr/bin/env raku

use lib "lib";
use Cro::WebApp::Template;
use Cro::HTTP::Router;
use Cro::HTTP::Server;

use Cromponent;

class Col {
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

class Row {
	has Col() @.cols is required;
	multi method new(@cols) {
		$.new: :@cols
	}

	method RENDER {
		q:to/END/
			<tr>
				<@.cols: $col>
					<&Col($col)>
				</@>
			</tr>
		END
	}
}

class Table {
	has Row() @.rows is required;
	multi method new(@rows) {
		$.new: :@rows
	}

	method RENDER {
		q:to/END/
			<table border=1>
				<@.rows: $row>
					<&Row($row)>
				</@>
			</table>
		END
	}
}

my $routes = route {

	my $table = Table.new: [[1,2],[3,4]];

	get  -> {
		template-with-components Q:to/END/, { :$table };
		<html>
			<head>
				<script src="https://unpkg.com/htmx.org@2.0.3" integrity="sha384-0895/pl2MU10Hqc6jd4RvrthNlDiE9U1tWmX7WRESftEDRosgxNsQG/Ze9YMRzHq" crossorigin="anonymous"></script>
			</head>
			<body>
				<&Table(.table)>
			</body>
		</html>
		END
	}

	#iamerejh - sort out id
	add-components Table, Row, Col;
}


my Cro::Service $http = Cro::HTTP::Server.new(
    http => <1.1>,
    host => "0.0.0.0",
    port => 3000,
    application => $routes,
);
$http.start;
say "Listening at http://0.0.0.0:3000";
react {
    whenever signal(SIGINT) {
        say "Shutting down...";
        $http.stop;
        done;
    }
}
