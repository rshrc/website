# Everything goes through make: `make run` while working on the site,
# `make deploy` to ship it. Builds never touch the network; `make covers` does.

.PHONY: run deploy builder clean copy_web spanify htmlgen booksgen covers \
        update-sitemap check-sitemap-urls r s g b u c

run:
	ruby tool/dev_server.rb

deploy: builder
	firebase deploy
	echo "Visit @ https://banerjeerishi.com"

# booksgen writes into ./web, so it has to run before copy_web copies ./web
# into ./build, or generated book pages land in the build one run late.
builder: booksgen copy_web htmlgen

clean:
	rm -rf ./build

copy_web: spanify
	mkdir -p build
	cp -R ./web/. ./build
	cp sitemap.xml robots.txt build/

# homegen fills the YAML sections, essay list and hover cards into copies of
# index.md and its template first, so spanify animates generated words too.
# Writing to a temp file (named per process, in case two builds overlap) means
# a failed run never leaves a half-empty page.
spanify:
	ruby tool/homegen.rb
	mkdir -p web
	tmp=web/index.html.$$$$; \
	dart --enable-asserts tool/spanify.dart --html src/.index.template.generated.html src/.index.generated.md > $$tmp \
	  && mv $$tmp web/index.html || { rm -f $$tmp; exit 1; }

htmlgen:
	dart --enable-asserts tool/htmlgen.dart

booksgen:
	ruby tool/booksgen.rb

# Fetches cover art for new Spotify links in src/home/*.yaml.
covers:
	ruby tool/covers.rb

update-sitemap:
	ruby tool/update_sitemap.rb

check-sitemap-urls: builder
	ruby tool/check_sitemap_urls.rb --sitemap sitemap.xml --build-dir build

r: run
s: spanify
g: htmlgen
b: booksgen
u: update-sitemap
c: check-sitemap-urls
