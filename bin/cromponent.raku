#!/usr/bin/env raku

use lib "lib";
use Cro::HTTP::Router;
use Cro::HTTP::Server;
use Cromponent;

my UInt $next = 1;
my $cromponent = Cromponent.new;

class Todo {
	has UInt $.id = $next++;
	has Bool $.done is rw = False;
	has Str  $.data is required;

	method toggle {
		$!done = !$!done
	}

	method RENDER {
		qq:to/END/;
			<tr>
				<td>
					<input
						type=checkbox
						<?.done> checked </?>
						hx-get="/todo/<.id>/toggle"
						hx-target="closest tr"
						hx-swap="outerHTML"
					>
				</td>
				<td>
					<?.done>
						<del><.data></del>
					</?>
					<!>
						<.data>
					</!>
				</td>
				<td>
					<button
						hx-delete="/todo/<.id>"
						hx-confirm="Are you sure?"
						hx-target="closest tr"
						hx-swap="delete"
					>
						-
					</button>
				</td>
			</tr>
		END
	}
}

my $routes = route {
	my @todos = do for <blablabla blebleble> -> $data { Todo.new: :$data }
	get  -> {
		template-with-components $cromponent, Q:to/END/, { :@todos };
		<html>
			<head>
				<script src="https://unpkg.com/htmx.org@2.0.3" integrity="sha384-0895/pl2MU10Hqc6jd4RvrthNlDiE9U1tWmX7WRESftEDRosgxNsQG/Ze9YMRzHq" crossorigin="anonymous"></script>
			</head>
			<body>
				<table>
					<@.todos: $todo>
						<&Todo($todo)>
					</@>
				</table>
				<form
					hx-post="/todo"
					hx-target="table"
					hx-swap="beforeend"
					hx-on::after-request="this.reset()"
				>
					<input name=data><button type=submit>+</button>
				</form>
			</body>
		</html>
		END
	}
	$cromponent.add:
		Todo,
		:load( -> UInt() $id { @todos.first: { .id == $id } }),
		:create(-> *%data { @todos.push: my $n = Todo.new: |%data; $n }),
		:delete( -> UInt() $id { @todos .= grep: { .id != $id } }),
	;
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
