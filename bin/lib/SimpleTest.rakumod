use Cromponent;
unit class SimpleTest does Cromponent;

has $.value = 42;

method RENDER { "<h1><.value><h1>" }
