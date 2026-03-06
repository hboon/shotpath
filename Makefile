PREFIX ?= /usr/local
BINARY = shotpath
BUILD_DIR = dist

$(BUILD_DIR)/$(BINARY): Sources/main.swift
	mkdir -p $(BUILD_DIR)
	swiftc -O -o $(BUILD_DIR)/$(BINARY) Sources/main.swift -framework AppKit -framework CoreServices

install: $(BUILD_DIR)/$(BINARY)
	install -d $(PREFIX)/bin
	install -m 755 $(BUILD_DIR)/$(BINARY) $(PREFIX)/bin/$(BINARY)

install-launchagent:
	sed 's|/usr/local/bin/shotpath|$(PREFIX)/bin/shotpath|g' com.shotpathapp.agent.plist > ~/Library/LaunchAgents/com.shotpathapp.agent.plist
	launchctl load ~/Library/LaunchAgents/com.shotpathapp.agent.plist

uninstall-launchagent:
	-launchctl unload ~/Library/LaunchAgents/com.shotpathapp.agent.plist
	rm -f ~/Library/LaunchAgents/com.shotpathapp.agent.plist

uninstall: uninstall-launchagent
	rm -f $(PREFIX)/bin/$(BINARY)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: install install-launchagent uninstall-launchagent uninstall clean
