#!/usr/bin/env raku

use lib "bin/lib";
use Cro::HTTP::Router;
use Cro::HTTP::Server;
use Cro::WebApp::Template;
use Poll;
use PollItem;
use PollVote;
use WebSocket;
use Red:api<2>;
use UUID;

my $routes = route {
	PROCESS::<$RED-DEBUG> = %*ENV<RED_DEBUG>;
	red-defaults "SQLite";
	Poll.^create-table:     :unless-exists;
	PollItem.^create-table: :unless-exists;
	PollVote.^create-table: :unless-exists;

	template-location "resources/";
	PollItem.^add-cromponent-routes;
	WebSocket.^add-cromponent-routes;

	Poll.^create:
	    :descr('What is your favourite Raku feature?'),
	    :items[
		%(:descr('Grammar')),
		%(:descr('Lazy lists')),
		%(:descr('OOP')),
		%(:descr('Meta')),
		%(:descr('Multi paradigm')),
		%(:descr('Multi sub/methods')),
		%(:descr('Concurrency/parallelism')),
	    ]
	;

	Poll.^create:
	    :descr('What is your favourite way of communication to talk about Raku?'),
	    :items[
		%(:descr('IRC')),
		%(:descr('Discord')),
		%(:descr('Reddit')),
		%(:descr('Twitter')),
		%(:descr('Mastodom')),
		%(:descr('Facebook')),
		%(:descr('Email list')),
	    ]
	;

	get -> 'polls', Str :$*user is cookie = UUID.new.Str {
		response.set-cookie: "user", $*user;
		my @polls = Poll.^all.Seq;
		template "polls.crotmp", {
			:$*user, :@polls
		}
	}

	get -> 'polls', UInt $id, Str :$*user is cookie = UUID.new.Str {
		response.set-cookie: "user", $*user;
		my $polls = Poll.LOAD: $id;
		template "polls.crotmp", {
			:$*user, :$polls
		}
	}

	get -> "css" {
	    static 'resources/polls.css'
	}
}
my Cro::Service $http = Cro::HTTP::Server.new(
    http => <1.1>,
    host => "0.0.0.0",
    port => 2000,
    application => $routes,
);
$http.start;
say "Listening at http://0.0.0.0:2000";
react {
    whenever signal(SIGINT) {
        say "Shutting down...";
        $http.stop;
        done;
    }
}

