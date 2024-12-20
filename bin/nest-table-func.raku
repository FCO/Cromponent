#!/usr/bin/env raku

use lib "lib";
use lib "bin/lib";
use Cromponent;
use MyLib;

my $cromponent = Cromponent.new;

my $template;
my $topic;

{  #use a block to avoid namespace collision
    use HTML::Functional;

    $template =
        html :lang<en>, [
            head [ script :src<https://unpkg.com/htmx.org@2.0.3"> ],
            body [
                mytable $[[1, 2], [3, 4]], :$topic;
                row $[5,6], :$topic;
                cell 42, :$topic;
            ]
        ];

}


use Cro::WebApp::Template;
use Cro::HTTP::Router;
use Cro::HTTP::Server;

my $routes = route {
    $cromponent.add: MyTable, Row, Cell;

    get  -> {
        template-with-components $cromponent, $template, $topic;
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

