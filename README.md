# The Flix Blog

## Installation Instructions

1. Install `zola`
2. `git clone git@github.com:flix/blog.flix.dev.git`
3. `zola serve`

## Syntax highlighting

Code blocks are highlighted by Zola, using the grammar from
[flix/textmate](https://github.com/flix/textmate) -- the same one flix.dev uses.
It is vendored at `syntaxes/flix.tmLanguage.json` so that a clone builds with
nothing but Zola. To pick up grammar changes, bump `GRAMMAR_COMMIT` in the
`Makefile` and run `make update-grammar`.

The colours come from the theme named in `[markdown.highlighting]`; Zola writes
them to `static/giallo.css`, which `templates/tabi/extend_head.html` links.

Changing the theme is a one-line edit, but delete `static/giallo.css` afterwards:
Zola writes that file only when it is absent, so the old colours survive both a
rebuild and a running `zola serve` until the stale copy is gone.

## Updating tabi submodule

Nothing to do beyond the update itself; the theme is used as it comes.
