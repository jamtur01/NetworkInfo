import AppKit
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var networkInfoManager = NetworkInfoManager()
    
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
            button.title = "🔗"
            button.target = self
            button.action = #selector(showMenu(_:))
        }
        
        // Start network monitoring
        networkInfoManager.start()
    }
    
    @objc func showMenu(_ sender: AnyObject?) {
        let menu = NSMenu()
        networkInfoManager.buildMenu(menu: menu)
        statusItem?.menu = menu
    }
    
    @objc func copyToClipboard(_ sender: NSMenuItem) {
        if let text = sender.representedObject as? String {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }
    
    @objc func refreshData(_ sender: NSMenuItem) {
        networkInfoManager.refreshData()
    }
    
    @objc func quitApp(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }
}
