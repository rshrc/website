clean:
	rm -rf ./build

run:
	ruby tool/dev_server

deploy: builder
		firebase deploy
		echo "Visit @ https://banerjeerishi.com"

# booksgen writes into ./web, so it has to run before copy_web copies ./web
# into ./build — otherwise generated book pages land in the build one run late.
builder: booksgen copy_web htmlgen


copy_web: spanify
	mkdir -p build
	cp -R ./web/. ./build
	cp sitemap.xml build/
	cp robots.txt build/

copy_old:
	cp -R ./old/* ./build

spanify:
	ruby tool/site_tasks spanify

htmlgen:
	ruby tool/site_tasks htmlgen

booksgen:
	ruby tool/site_tasks booksgen

check-sitemap-urls: builder
	ruby tool/site_tasks check-sitemap-urls

update-sitemap:
	ruby tool/site_tasks update-sitemap

r: run
s: spanify
g: htmlgen
b: booksgen
u: update-sitemap
c: check-sitemap-urls
