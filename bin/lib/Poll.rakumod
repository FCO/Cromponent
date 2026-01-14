use Red:api<2>;
use Cromponent;

model Poll does Cromponent {
	has UInt $.id    is serial;
	has Str  $.descr is column;
	has      @.items is relationship(*.poll-id, :model<PollItem>);
	has      @.votes is relationship(*.poll-id, :model<PollVote>);
	has Str  $.user is rw;

	# How to load the component
	method LOAD(Int $poll-id, Str :$user! is cookie) {
		my $pool = Poll.^load: $poll-id;
		$pool.user = $user;
		$pool
	}

	# Unique dentifier passed by websocket. Used on LOAD
	method IDS { $!id }

	# How to redraw the component when asked by websocket
	method REDRAW(:$!user! is cookie) { $.Str }

	# List of items from poll sorted
	method sorted-items {
		@!items.sort: {
			|(-.votes if $.did-user-vote),
			.id
		}
	}

	# Cro template to be rendered
	method RENDER {
		Q:to/END/;
		<div class="poll" id="poll-<.id>">
			<h2>
				<a href="/polls/<.id>">
					<.descr> (<.votes.elems> vote<?{ .votes.elems != 1 }>s</?>)
				</a>
			</h2>
			<table>
				<@.sorted-items.Seq>
					<&HTML($_)>
				</@>
			</table>
		</div>
		END
	}

	method did-user-vote($user = $!user) {
		?@.votes.first: *.user eq $user
	}
}

sub EXPORT { Poll.^exports }
