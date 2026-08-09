# The Flix grammar Zola highlights code blocks with. Pinned to a commit of
# flix/textmate so a build is reproducible; bump the SHA to pick up grammar
# changes. Editing this file re-triggers the fetch.
GRAMMAR_COMMIT := befa883ecec4b0c84e436bdd176dec5475e584ab
GRAMMAR := syntaxes/flix.tmLanguage.json

# Do not leave a half-written grammar behind: without this a download cut short
# still satisfies the rule, and the next build silently reuses the truncated file.
.DELETE_ON_ERROR:

.PHONY: build-site serve

# Zola writes static/giallo.css only when it is absent, so a theme change in
# config.toml would otherwise leave the old colours on disk forever.
build-site: $(GRAMMAR)
	rm -f static/giallo.css
	zola build

serve: $(GRAMMAR)
	rm -f static/giallo.css
	zola serve

# Fetched rather than committed so this blog and flix.dev highlight Flix from
# the same grammar. -f makes a 404 fail the build instead of writing a file
# full of HTML.
$(GRAMMAR): Makefile
	@mkdir -p $(dir $@)
	curl -sSfL -o $@ \
	  https://raw.githubusercontent.com/flix/textmate/$(GRAMMAR_COMMIT)/syntaxes/flix.tmLanguage.json
