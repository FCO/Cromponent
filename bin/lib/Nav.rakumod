use Cromponent;

class Nav does Cromponent { ... }

class NavItem does Cromponent {
	has Str        $.name;
	has Cromponent $.component;
	has Str        $.target;

	multi method new(Pair (:$key, :$value), :$target) {
		$.new: $key, $value, :$target
	}

	multi method new(Str $name, Cromponent $component, :$target) {
		$.new: :$name, :$component, :$target
	}

	method subnav {
		$!component ~~ Nav
	}
	method url {
		$!component.^url
	}

	method RENDER {
		q:to/END/
		<li>
			<?.subnav>
				<&HTML(.component)>
			</?>
			<!>
				<a href="<.url>" hx-get="<.url>" hx-target="<.target>"><.name></a>
			</!>
		</li>
		END
	}
}

class Nav does Cromponent {
	has NavItem @.items;
	has Str     $.target;

	multi method new(NavItem() @items, :$target, *%pars) {
		self.new: :$target, :@items, |%pars
	}

	multi method new(@items where { .are: Pair }, :$target, *%pars) {
		self.new:
			:$target,
			:items[@items.map: -> Pair $pair { NavItem.new: $pair, :$target }],
			|%pars,
		;
	}

	method EXTRA-ENDPOINTS {
		for @!items {
			given .component {
				.HOW.?add-cromponent-routes: $_
			}
		}
	}
	method RENDER {
		q:to/END/;
		<ul>
			<@.items: $item>
				<&HTML($item)>
			</@>
		</ul>
		END
	}
}

sub EXPORT() { Map.new: (|Nav.^exports, |NavItem.^exports) }
