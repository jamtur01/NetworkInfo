import AppKit

@MainActor class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var networkInfoManager = NetworkInfoManager()
    var currentMenu: NSMenu?
    var isMenuVisible = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Skip notification setup for SPM builds to avoid bundle issues
        Logger.info("NetworkInfo starting...", category: "App")
        
        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Use SF Symbols (macOS 15+ target)
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Network Info")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(showMenu(_:))
        }
        
        // Listen for data updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkDataUpdated),
            name: NSNotification.Name("NetworkDataUpdated"),
            object: nil
        )
        
        // Start network monitoring
        networkInfoManager.start()
    }
    
    @MainActor @objc func showMenu(_ sender: AnyObject?) {
        let menu = NSMenu()
        menu.delegate = self
        networkInfoManager.buildMenu(menu: menu)
        currentMenu = menu
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }
    
    @objc func copyToClipboard(_ sender: NSMenuItem) {
        if let text = sender.representedObject as? String {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }
    
    @MainActor @objc func refreshData(_ sender: NSMenuItem) {
        // Show refresh indicator in menu
        sender.title = "Refreshing..."
        sender.isEnabled = false
        
        networkInfoManager.refreshData()
    }
    
    @MainActor @objc func networkDataUpdated() {
        // If menu is currently visible, update it
        if isMenuVisible {
            statusItem?.menu = nil
            showMenu(nil)
        }
    }
    
    @MainActor @objc func quitApp(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - NSMenuDelegate
extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        isMenuVisible = true
    }
    
    func menuDidClose(_ menu: NSMenu) {
        isMenuVisible = false
        statusItem?.menu = nil
    }
}
