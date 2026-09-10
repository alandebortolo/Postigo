.PHONY: test build app install run check icons

test:
	swift test

build:
	swift build -c release --product Postigo

icons:
	./scripts/make-icons.sh

app: icons build
	./scripts/package.sh

install: app
	mkdir -p "$(HOME)/Applications"
	rm -rf "$(HOME)/Applications/Postigo.app" "$(HOME)/Applications/DeskCam.app"
	cp -R dist/Postigo.app "$(HOME)/Applications/Postigo.app"
	@echo "instalado em ~/Applications/Postigo.app"

run: install
	open "$(HOME)/Applications/Postigo.app"

check:
	./check.sh

zip: app
	rm -f dist/Postigo.zip
	cd dist && zip -r -X Postigo.zip Postigo.app
	@ls -lh dist/Postigo.zip
