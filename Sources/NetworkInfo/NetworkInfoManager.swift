import Foundation
import Network
import AppKit
import UserNotifications

// MARK: - NetworkInfoManager Core
@objcMembers class NetworkInfoManager: NSObject {
    // MARK: - Constants
    internal let REFRESH_INTERVAL: TimeInterval = 120 // seconds
    internal let SERVICE_CHECK_INTERVAL: TimeInterval = 60 // seconds
    internal let EXPECTED_DNS = "127.0.0.1"
    internal let TEST_DOMAINS = ["example.com", "google.com", "cloudflare.com"]
    
    // MARK: - File paths
    // Change from let to var to allow setting for tests
    internal var dnsConfigPath: String
    
    // MARK: - State variables
    internal var serviceStates: [String: ServiceState] = [
        "unbound": ServiceState(),
        "kresd": ServiceState()
    ]
    
    internal var data = NetworkData()
    internal var lastAppliedDNSConfig = DNSConfig()
    
    // MARK: - Timers
    internal var refreshTimer: Timer?
    internal var serviceTimer: Timer?
    
    // MARK: - Watchers
    // Note: These can't be @objc due to incompatible types
    internal var configWatcher: DispatchSourceFileSystemObject?
    internal var networkMonitor: NWPathMonitor?
    
    // MARK: - Dispatch queues
    internal var networkMonitorQueue = DispatchQueue(label: "com.jamtur01.NetworkInfo.networkMonitor")
    internal var backgroundQueue = DispatchQueue(label: "com.jamtur01.NetworkInfo.background", qos: .utility, attributes: .concurrent)
    
    // For tests
    internal var isTestMode = false
    
    // MARK: - Initialization
    override init() {
        // Standard macOS app configuration location: Application Support directory
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = applicationSupport.appendingPathComponent("NetworkInfo")
        
        // Create the directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        
        dnsConfigPath = appDirectory.appendingPathComponent("dns.conf").path
        
        // For backward compatibility, check if a config exists in the legacy location
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let legacyPath = homeDir.appendingPathComponent(".config/hammerspoon/dns.conf").path
        
        // If the file exists in legacy location but not in the new location, copy it
        if FileManager.default.fileExists(atPath: legacyPath) && !FileManager.default.fileExists(atPath: dnsConfigPath) {
            try? FileManager.default.copyItem(atPath: legacyPath, toPath: dnsConfigPath)
            print("Migrated DNS config from \(legacyPath) to \(dnsConfigPath)")
        }
        
        // Create a default config file with examples if it doesn't exist
        if !FileManager.default.fileExists(atPath: dnsConfigPath) {
            let exampleConfig = """
            # NetworkInfo DNS Configuration
            # 
            # This file configures custom DNS servers for different Wi-Fi networks.
            # Format: SSID = DNS_Server1 DNS_Server2 ...
            #
            # Examples:
            # 
            # Home = 1.1.1.1 8.8.8.8
            # Work = 192.168.1.1 192.168.1.2
            # 
            # Use Cloudflare for home networks:
            # HomeWifi = 1.1.1.1 1.0.0.1
            # 
            # Use Google DNS for coffee shops:
            # CoffeeShopWifi = 8.8.8.8 8.8.4.4
            # 
            # For empty DNS configuration (use network defaults):
            # GuestNetwork = 
            
            """
            try? exampleConfig.write(toFile: dnsConfigPath, atomically: true, encoding: .utf8)
            print("Created new DNS config with examples at: \(dnsConfigPath)")
        } else {
            print("Using existing DNS config at: \(dnsConfigPath)")
        }
        
        super.init()
    }
    
    // MARK: - Public API
    func start() {
        // Run an immediate refresh to populate data
        refreshData()
        
        // Run immediate service and DNS checks
        monitorServices()
        testDNSResolution()
        
        // Set up periodic refresh
        refreshTimer = Timer.scheduledTimer(withTimeInterval: REFRESH_INTERVAL, repeats: true) { [weak self] _ in
            self?.refreshData()
        }
        
        // Set up service monitoring
        serviceTimer = Timer.scheduledTimer(withTimeInterval: SERVICE_CHECK_INTERVAL, repeats: true) { [weak self] _ in
            self?.monitorServices()
        }
        
        // Set up network monitor
        setupNetworkMonitor()
        
        // Set up config file watcher
        watchConfigFile()
    }
    
    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        
        serviceTimer?.invalidate()
        serviceTimer = nil
        
        networkMonitor?.cancel()
        networkMonitor = nil
        
        configWatcher?.cancel()
        configWatcher = nil
    }
    
    func refreshData() {
        // Preserve DNS configuration
        let dnsConfiguration = data.dnsConfiguration
        
        // Reset data
        data = NetworkData()
        data.dnsConfiguration = dnsConfiguration
        
        // Fetch all data asynchronously
        backgroundQueue.async { [weak self] in
            self?.getGeoIPData()
        }
        
        backgroundQueue.async { [weak self] in
            self?.getLocalIPAddress()
        }
        
        backgroundQueue.async { [weak self] in
            self?.getCurrentSSID()
        }
        
        backgroundQueue.async { [weak self] in
            self?.getVPNConnections()
        }
        
        backgroundQueue.async { [weak self] in
            self?.getDNSInfo()
        }
        
        backgroundQueue.async { [weak self] in
            self?.testDNSResolution()
        }
        
        backgroundQueue.async { [weak self] in
            self?.monitorServices()
        }
    }
    
    // MARK: - Helper Methods
    func sendNotification(title: String, body: String) {
        print("📣 \(title): \(body)")
        
        // Skip UserNotifications in test mode
        if isTestMode {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error)")
            }
        }
    }
    
    // MARK: - Public Menu Interface
    func buildMenu(menu: NSMenu) {
        // This method is implemented in the UI extension
        buildMenuItems(menu: menu)
    }
}