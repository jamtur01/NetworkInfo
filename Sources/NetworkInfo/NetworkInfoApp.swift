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
        
        // Register the bundle to load assets
        let bundle = Bundle.module
        if let bundleID = bundle.bundleIdentifier {
            print("Bundle identifier: \(bundleID)")
            NSImage.imageNames.forEach { name in
                if let image = bundle.image(forResource: name) {
                    print("Loaded image: \(name)")
                    NSImage.registerImage(image, name: name)
                }
            }
        }
        
        // Configure as an agent app (menu bar only, no dock icon)
        app.setActivationPolicy(.accessory)
        
        // Run the application
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}

// Extension to help with image loading
extension NSImage {
    static var imageNames: [String] {
        return ["MenuIcons", "PublicIP", "LocalIP", "SSID", "DNS", "VPN", 
                "Service", "ISP", "Location", "Refresh", "Quit"]
    }
    
    static func registerImage(_ image: NSImage, name: String) {
        image.setName(name)
    }
}

// Extension to Bundle for easier resource loading
extension Bundle {
    func image(forResource name: String) -> NSImage? {
        guard let imagePath = self.path(forResource: name, ofType: "png") ?? 
                             self.path(forResource: name, ofType: "jpg") ??
                             self.path(forResource: name, ofType: "pdf") else {
            return nil
        }
        return NSImage(contentsOfFile: imagePath)
    }
}
