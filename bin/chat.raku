#!/usr/bin/env raku

use lib "bin/lib";
use Cro::HTTP::Router;
use Cro::HTTP::Server;
use Cro::WebApp::Template;
use WebSocket;
use Red:api<2>;
use UUID;

model UserSession { ... }
model User        { ... }
model Msg         { ... }

model Room {
    has UInt $!id    is serial;
    has User @.users is relationship{ .id };
    has Msg  @.msgs  is relationship{ .id };
}

model Msg {
    has UInt $!id is serial;
    has Str  $.data is column;
    has UInt $.from-id is referencing( *.id, :model(User) );
    has UInt $.to-id   is referencing( *.id, :model(User) );
    has User $.from    is relationship{ .from-id };
    has User $.to      is relationship{ .to-id };
}

model User is table<account> {
    has UInt            $!id       is serial;
    has Str             $.name     is column;
    has Str             $.email    is column{ :unique };
    has Str             $.password is column;
    has UserSession     @.sessions is relationship{ .uid }

    method check-password($password) {
        $password eq $!password
    }
}

model UserSession is table<logged_user> does Cro::HTTP::Auth {
    has Str  $.id         is id;
    has UInt $.uid        is referencing(*.id, :model(User));
    has User $.user       is relationship{ .uid } is rw;
}

my $routes = route {
	PROCESS::<$RED-DEBUG> = %*ENV<RED_DEBUG>;
	red-defaults "SQLite";

	template-location "resources/";
	WebSocket.^add-cromponent-routes;

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

