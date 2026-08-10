#!/usr/bin/env raku

use lib "lib";
use lib "bin/lib";
use Cro::HTTP::Router;
use Cro::HTTP::Server;
use Cro::WebApp::Template;
use Table;

my $routes = route {
	my $table = Table.new:
		:head[["Planet", "Fiameter (km)", "Distance to Sun (AU)", "Orbit (days)"],],
		:body[
			["Mercury", "4,880" , "0.39", "88" ],
			["Venus"  , "12,104", "0.72", "225"],
			["Earth"  , "12,742", "1.00", "365"],
			["Mars"   , "6,779" , "1.52", "687"],
		],
		:foot[["Average", "9,126", "0.91", "341"],]
	;

	my $themed  = $table.clone: :head-theme<light>;
	my $striped = $table.clone: :classes<striped>;

	my $tables = {
		:tables[ $table, $themed, $striped ],
	};

	template-location "resources/";
	get  -> {
		template "table.crotmp", $tables;
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

