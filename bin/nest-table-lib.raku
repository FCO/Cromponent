#!/usr/bin/env raku

use lib "lib";
use Cro::WebApp::Template;
use Cro::HTTP::Router;
use Cro::HTTP::Server;

use Cromponent;
use Cromponent::MyLib;

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

	add-components Table, Row, Cell;
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
