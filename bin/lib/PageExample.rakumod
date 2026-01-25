use Cromponent;

class PageExample does Cromponent {
	method LOAD { $.new }

	method RENDER {
		Q:to/END/
		<h1>Page Example</h1>
		END
	}
}

sub EXPORT() { PageExample.^exports }
