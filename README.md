# The Flix Blog

## Installation Instructions

1. Install `zola`
2. `git clone git@github.com:flix/blog.flix.dev.git`
3. `git submodule update --init --recursive`
4. `make`
5. `zola serve`

## Updating highlight js
Replace `static/highlight.js` with the new update and update the sha256 sum under `hljs_sha` in `config.toml`.
