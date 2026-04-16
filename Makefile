APP     = tlrc.app
BINARY  = $(APP)/Contents/MacOS/tlrc
SWIFTC  = swiftc
FLAGS   = -parse-as-library \
          -framework Cocoa \
          -framework IOKit \
          -framework SwiftUI \
          -framework ServiceManagement

.PHONY: build open install clean kill

build: $(APP)

$(APP): tlrc.swift Info.plist AppIcon.icns tlrc_logo.png menubar.png menubar@2x.png
	mkdir -p $(APP)/Contents/MacOS
	mkdir -p $(APP)/Contents/Resources
	$(SWIFTC) $(FLAGS) tlrc.swift -o $(BINARY)
	cp Info.plist $(APP)/Contents/Info.plist
	cp AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	cp tlrc_logo.png $(APP)/Contents/Resources/tlrc_logo.png
	cp menubar.png $(APP)/Contents/Resources/menubar.png
	cp "menubar@2x.png" "$(APP)/Contents/Resources/menubar@2x.png"
	@echo "Built $(APP)"

open: build
	open $(APP)

install: build
	cp -r $(APP) "/Applications/tl;rc.app"
	@echo "Installed to /Applications"

# Kill any running instance then reopen (handy during development)
dev: build
	@pkill -x tlrc 2>/dev/null || true
	open $(APP)

clean:
	rm -rf $(APP)
