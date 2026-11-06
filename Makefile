PROJECT   := Stremio.xcodeproj
SCHEME    := Stremio
DERIVED   ?= build/DerivedData
SIMULATOR ?= iPhone 18 Pro
APP       := $(DERIVED)/Build/Products/Debug-iphoneos/Stremio.app
SOURCES   := Stremio Tests

.PHONY: bootstrap generate build test format lint install clean

bootstrap:
	scripts/bootstrap.sh

generate:
	xcodegen generate --quiet

build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-destination 'generic/platform=iOS' -derivedDataPath $(DERIVED) -allowProvisioningUpdates build

test: generate
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR)' -derivedDataPath $(DERIVED)

format:
	xcrun swift-format format --in-place --recursive $(SOURCES)

lint:
	xcrun swift-format lint --strict --recursive $(SOURCES)

install:
	@test -n "$(DEVICE)" || { echo "usage: make install DEVICE=<device-id>"; exit 1; }
	$(MAKE) build
	xcrun devicectl device install app --device $(DEVICE) $(APP)

clean:
	rm -rf build
