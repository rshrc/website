clean:
	rm -rf ./build

run: builder
	serve -s build -l 3000

deploy: builder
		firebase deploy
		echo "Visit @ https://banerjeerishi.com"

builder: copy_web htmlgen


copy_web: spanify
	mkdir -p build
	cp -R ./web/* ./build

copy_old:
	cp -R ./old/* ./build

spanify:
	dart --enable-asserts tool/spanify.dart \
	  --html src/index.template.html \
	  src/index.md \
	  > web/index.html

htmlgen:
	dart --enable-asserts tool/htmlgen.dart
