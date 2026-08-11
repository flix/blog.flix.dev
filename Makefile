# The Flix grammar Zola highlights code blocks with is vendored under syntaxes/,
# so a clone builds with nothing but Zola -- no make, no shell, no network, which
# matters on Windows, where make is not something the OS ships.
#
# To pick up grammar changes, bump the SHA below and run `make update-grammar`.
# The refreshed grammar lands in the working tree, where a partial or wrong
# download shows up as a diff before it can be committed.
GRAMMAR_COMMIT := f4d05bbfcd34342f76bcf135f7ae58ab7cd2dd58
GRAMMAR := syntaxes/flix.tmLanguage.json

.PHONY: build-site serve update-grammar

build-site:
	zola build

serve:
	zola serve

# -f turns a 404 into a failure rather than a file full of HTML; --create-dirs
# saves a `mkdir -p`, which cmd.exe does not have.
update-grammar:
	curl -sSfL --create-dirs -o $(GRAMMAR) \
	  https://raw.githubusercontent.com/flix/textmate/$(GRAMMAR_COMMIT)/syntaxes/flix.tmLanguage.json
