# The Flix Blog

## Installation Instructions

1. Install `zola`
2. `git clone git@github.com:flix/blog.flix.dev.git`
3. `make serve`

Use `make serve` rather than `zola serve`: the Flix syntax highlighting grammar
is fetched by the Makefile, and Zola refuses to build without it.

## Syntax highlighting

Code blocks are highlighted by Zola, using the grammar from
[flix/textmate](https://github.com/flix/textmate) -- the same one flix.dev uses.
To pick up grammar changes, bump `GRAMMAR_COMMIT` in the `Makefile`.

The colours come from the theme named in `[markdown.highlighting]`; Zola writes
them to `static/giallo.css`, which `templates/tabi/extend_head.html` links.
Changing the theme is a one-line edit, and `make` regenerates the stylesheet.

## Updating tabi submodule

Nothing to do beyond the update itself; the theme is used as it comes.
