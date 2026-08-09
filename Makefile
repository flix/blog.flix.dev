# The Flix grammar Zola highlights code blocks with. Pinned to a commit of
# flix/textmate so a build is reproducible; bump the SHA to pick up grammar
# changes. Editing this file re-triggers the fetch.
GRAMMAR_COMMIT := befa883ecec4b0c84e436bdd176dec5475e584ab
GRAMMAR := syntaxes/flix.tmLanguage.json

# Do not leave a half-written grammar behind: without this a download cut short
# still satisfies the rule, and the next build silently reuses the truncated file.
.DELETE_ON_ERROR:

.PHONY: build-site serve

build-site: $(GRAMMAR)
	zola build

serve: $(GRAMMAR)
	zola serve

# Fetched rather than committed so this blog and flix.dev highlight Flix from
# the same grammar. -f makes a 404 fail the build instead of writing a file full
# of HTML, and --create-dirs saves a `mkdir -p` that Windows shells lack.
$(GRAMMAR): Makefile
	curl -sSfL --create-dirs -o $@ \
	  https://raw.githubusercontent.com/flix/textmate/$(GRAMMAR_COMMIT)/syntaxes/flix.tmLanguage.json
