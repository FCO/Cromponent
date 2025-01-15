#!/usr/bin/env raku

use lib "bin/lib";
use Cro::HTTP::Router;
use Cro::HTTP::Server;
use Cro::WebApp::Template;
use SearchTable;

use HTML::Functional :CRO;


my $routes = route {
	SearchTable.^add-cromponent-routes;

	get -> {
		content 'text/html',
		  html
			head
			  title  "SearchTable",
			  script :src<https://unpkg.com/htmx.org@1.7.0">;
			body
			  div
				searchtable :thead<First Last Email>, :id(0);
	}
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
