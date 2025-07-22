import AppKit
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var networkInfoManager = NetworkInfoManager()
    var currentMenu: NSMenu?
    var isMenuVisible = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notification permissions: \(error)")
            }
        }
        
        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Use a custom icon based on OS version
            if #available(macOS 11.0, *) {
                // Use SF Symbols on newer macOS
                button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Network Info")
            } else {
                // Fallback to text on older macOS
                button.title = "Net"
            }
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
    
    @objc func showMenu(_ sender: AnyObject?) {
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
    
    @objc func refreshData(_ sender: NSMenuItem) {
        // Show refresh indicator in menu
        sender.title = "Refreshing..."
        sender.isEnabled = false
        
        networkInfoManager.refreshData()
    }
    
    @objc func networkDataUpdated() {
        // If menu is currently visible, update it
        if isMenuVisible {
            statusItem?.menu = nil
            showMenu(nil)
        }
    }
    
    @objc func quitApp(_ sender: NSMenuItem) {
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
