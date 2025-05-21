import SwiftUI
import AppKit

// Main application entry point
@main
struct NetworkInfoApp {
    static func main() {
        // Create and configure the application
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        
        // Configure as an agent app (menu bar only, no dock icon)
        app.setActivationPolicy(.accessory)
        
        // Run the application
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}

