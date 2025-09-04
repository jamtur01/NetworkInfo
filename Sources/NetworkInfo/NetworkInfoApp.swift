import AppKit

// Main application entry point using pure AppKit pattern
@main
class NetworkInfoApp {
    static func main() {
        // Create and configure the NSApplication
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        
        // Configure as an agent app (menu bar only, no dock icon)
        app.setActivationPolicy(.accessory)
        
        // Start the application event loop
        app.run()
    }
}

