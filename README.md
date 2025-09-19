# The Flix Blog

## Installation Instructions

1. Install `zola`
2. `git clone git@github.com:flix/blog.flix.dev.git`
3. `git submodule update --init --recursive`
4. `make`
5. `zola serve`

## Updating highlight js
Replace `static/highlight.js` with the new update and update the sha256 sum under `hljs_sha` in `config.toml`.

## Updating tabi submodule

Ensure that the bottom of `themes\tabi\templates\partials\header.html` contains:

```html
<script defer src="{{ get_url(path='highlight.js') | safe }}"></script>
<script defer src="{{ get_url(path='highlight_activate.js') | safe }}"></script>
```
