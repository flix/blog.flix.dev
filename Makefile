.PHONY: build-site

build-site:
	zola build
	mkdir -p themes/tabi/templates/tabi/
	cp partials/extend_body.html themes/tabi/templates/tabi/extend_body.html
