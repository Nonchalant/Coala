BINARY?=coala
BUILD_FOLDER?=.build
PREFIX?=/usr/local
PROJECT?=Coala
RELEASE_BINARY_FOLDER?=$(BUILD_FOLDER)/release/$(PROJECT)

debug:
	swift build

build:
	swift build -c release --disable-sandbox --disable-package-manifest-caching

test:
	swift test

clean:
	swift package clean
	rm -rf DerivedData
	rm -rf $(BUILD_FOLDER) $(PROJECT).xcodeproj

xcode:
	swift package generate-xcodeproj

install: build
	mkdir -p $(PREFIX)/bin
	cp -f $(RELEASE_BINARY_FOLDER) $(PREFIX)/bin/$(BINARY)
