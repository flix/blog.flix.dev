# The Flix Blog

## Installation Instructions

1. Install `zola`
2. `git clone git@github.com:flix/blog.flix.dev.git`
3. `git submodule update --init --recursive`
4. `mkdir -p themes/tabi/templates/tabi/`
5. `cp -r themes/extend_body.html themes/tabi/templates/tabi/extend_body.html`
6. `zola serve`

## Updating highlight js
Replace `static/highlight.js` with the new update and update the sha256 sum in `themes/extend_body.html`.
