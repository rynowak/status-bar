APP_NAME := StatusBar
BUNDLE_NAME := $(APP_NAME).app
BUNDLE_DIR := .build/bundle/$(BUNDLE_NAME)
DMG_NAME := $(APP_NAME).dmg
DMG_DIR := .build/dmg

.PHONY: build bundle dmg install uninstall clean

build:
	swift build -c release

bundle: build
	rm -rf $(BUNDLE_DIR)
	mkdir -p $(BUNDLE_DIR)/Contents/MacOS
	mkdir -p $(BUNDLE_DIR)/Contents/Resources
	cp .build/release/$(APP_NAME) $(BUNDLE_DIR)/Contents/MacOS/$(APP_NAME)
	cp Sources/StatusBar/Info.plist $(BUNDLE_DIR)/Contents/Info.plist
	-cp -R .build/release/*.bundle $(BUNDLE_DIR)/Contents/Resources/ 2>/dev/null
	codesign --force --sign - $(BUNDLE_DIR)

dmg: bundle
	rm -rf $(DMG_DIR)
	mkdir -p $(DMG_DIR)
	cp -R $(BUNDLE_DIR) $(DMG_DIR)/
	ln -s /Applications $(DMG_DIR)/Applications
	hdiutil create -volname "$(APP_NAME)" -srcfolder $(DMG_DIR) -ov -format UDZO .build/$(DMG_NAME)
	rm -rf $(DMG_DIR)

install: bundle
	rm -rf /Applications/$(BUNDLE_NAME)
	cp -R $(BUNDLE_DIR) /Applications/$(BUNDLE_NAME)

uninstall:
	rm -rf /Applications/$(BUNDLE_NAME)

clean:
	rm -rf .build
