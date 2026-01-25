use Cromponent;

class PageExample2 does Cromponent {
	method LOAD { $.new }

	method RENDER {
		Q:to/END/
		<h1>Page Example 2</h1>
		END
	}
}

sub EXPORT() { PageExample2.^exports }
