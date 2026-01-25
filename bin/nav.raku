#!/usr/bin/env raku

use lib "bin/lib";
use Cro::HTTP::Router;
use Cro::HTTP::Server;
use Cro::WebApp::Template;
use Nav;
use PageExample;
use PageExample2;

my $routes = route {
	template-location "resources/";

        my $nav = Nav.new: :target<#content>, [
            example => PageExample.new,
            example2 => PageExample2.new,
            subnav => Nav.new: :target<#content>, [
                example => PageExample.new,
                example2 => PageExample2.new,
            ],
        ];

        $nav.^add-cromponent-routes;

        get -> {
            template "nav.crotmp", %( :$nav )
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


