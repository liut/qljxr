PRODUCT_NAME = QLJPEGXR
EXTENSION_NAME = JXRPreviewExtension
BUNDLE_ID = com.qljxr.QLJPEGXR
EXTENSION_ID = com.qljxr.QLJPEGXR.JXRPreviewExtension
DEVELOPER_ID = $$(security find-identity -v -s "Developer ID Application" 2>/dev/null | grep "Developer ID Application" | grep -oE '[A-F0-9]{40}' | head -1)
VERSION = 1.0.0
BUILD_PATH = .build
RELEASE_APP_PATH = $(BUILD_PATH)/Build/Products/Release/$(PRODUCT_NAME).app

.PHONY: all build run run-app deploy register clean sign

all: build

# Xcode 26.5 workaround: COMPILER_INDEX_STORE_ENABLE=NO
build:
	xcodebuild -project $(PRODUCT_NAME).xcodeproj \
		-scheme $(PRODUCT_NAME) \
		-configuration Release \
		-derivedDataPath $(BUILD_PATH) \
		COMPILER_INDEX_STORE_ENABLE=NO

# Launch the app (loads the JXR viewer window).
run: deploy
	pkill -f $(PRODUCT_NAME) 2>/dev/null || true
	open $(RELEASE_APP_PATH)

# Build + deploy + open a specific JXR file for testing.
# Usage: make test JXR=/path/to/image.jxr
test: deploy
	pkill -f $(PRODUCT_NAME) 2>/dev/null || true
	open -a $(RELEASE_APP_PATH) "$(JXR)"

# Test QuickLook preview via qlmanage.
# Usage: make preview JXR=/path/to/image.jxr
preview: deploy register
	qlmanage -p -c com.jxrquicklook.jxr "$(JXR)" 2>/dev/null &

# Copy app to /Applications/ and refresh Launch Services.
deploy: build
	rm -rf /Applications/$(PRODUCT_NAME).app
	cp -R $(RELEASE_APP_PATH) /Applications/

# Register the QuickLook extension with pluginkit.
# macOS caches extension metadata; force-refresh after each deploy.
register:
	pluginkit -r /Applications/$(PRODUCT_NAME).app/Contents/PlugIns/$(EXTENSION_NAME).appex 2>/dev/null || true
	sleep 1
	pluginkit -a /Applications/$(PRODUCT_NAME).app/Contents/PlugIns/$(EXTENSION_NAME).appex
	@echo "Registered. Verify: pluginkit -m -p com.apple.quicklook.preview | grep $(BUNDLE_ID)"

# Ad-hoc sign for local development.
sign: build
	codesign --sign - --force --entitlements HostApp/HostApp.entitlements $(RELEASE_APP_PATH)

# Clean all build artifacts.
clean:
	rm -rf .build

# Reset Launch Services and re-register (use when QuickLook isn't picking up the extension).
ls-reset:
	/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister \
		-kill -r -domain local -domain system -domain user
	sleep 2
	pluginkit -a /Applications/$(PRODUCT_NAME).app/Contents/PlugIns/$(EXTENSION_NAME).appex
	@echo "Launch Services reset. Restart Finder if needed: killall Finder"
