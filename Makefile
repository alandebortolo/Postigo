.PHONY: test build app install run check

test:
	swift test

build:
	swift build -c release --product DeskCam

app: build
	./scripts/package.sh

install: app
	mkdir -p "$(HOME)/Applications"
	rm -rf "$(HOME)/Applications/DeskCam.app"
	cp -R dist/DeskCam.app "$(HOME)/Applications/DeskCam.app"
	@echo "instalado em ~/Applications/DeskCam.app"

run: install
	open "$(HOME)/Applications/DeskCam.app"

check:
	./check.sh
