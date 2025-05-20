.PHONY: build clean

APP_NAME = NetworkInfo
APP_PATH = $(APP_NAME).app
CONTENTS_PATH = $(APP_PATH)/Contents
MACOS_PATH = $(CONTENTS_PATH)/MacOS
RESOURCES_PATH = $(CONTENTS_PATH)/Resources
EXECUTABLE_PATH = .build/release/$(APP_NAME)

build: clean
	# Build the executable
	swift build -c release
	
	# Create app directory structure
	mkdir -p $(MACOS_PATH)
	mkdir -p $(RESOURCES_PATH)
	
	# Verify the executable exists
	test -f $(EXECUTABLE_PATH) || (echo "Executable not found at $(EXECUTABLE_PATH)" && exit 1)
	
	# Copy executable and set permissions
	cp $(EXECUTABLE_PATH) $(MACOS_PATH)/
	chmod +x $(MACOS_PATH)/$(APP_NAME)
	
	# Create PkgInfo
	echo "APPL????" > $(CONTENTS_PATH)/PkgInfo
	
	# Create Info.plist
	cp Sources/$(APP_NAME)/Info.plist $(CONTENTS_PATH)/
	
	# Create a basic empty Resources file if needed
	touch $(RESOURCES_PATH)/.empty
	
	# Verify the bundle structure
	@echo "Verifying bundle structure..."
	@ls -la $(APP_PATH)
	@ls -la $(CONTENTS_PATH)
	@ls -la $(MACOS_PATH)
	@file $(MACOS_PATH)/$(APP_NAME)
	
	@echo "App bundle created at $(APP_PATH)"

clean:
	rm -rf $(APP_PATH)
	rm -rf .build

run: build
	open $(APP_PATH)
