import Foundation
import Network
import AppKit
import UserNotifications

// MARK: - NetworkInfoManager Core
@objcMembers class NetworkInfoManager: NSObject {
    // MARK: - Constants
    private let REFRESH_INTERVAL: TimeInterval = 120 // seconds
    private let SERVICE_CHECK_INTERVAL: TimeInterval = 60 // seconds
    private let EXPECTED_DNS = "127.0.0.1"
    private let TEST_DOMAINS = ["example.com", "google.com", "cloudflare.com"]
    
    // MARK: - File paths
    private let dnsConfigPath: String
    
    // MARK: - State variables
    private var serviceStates: [String: ServiceState] = [
        "unbound": ServiceState(),
        "kresd": ServiceState()
    ]
    
    private var data = NetworkData()
    private var lastAppliedDNSConfig = DNSConfig()
    
    // MARK: - Timers
    private var refreshTimer: Timer?
    private var serviceTimer: Timer?
    
    // MARK: - Watchers
    private var configWatcher: DispatchSourceFileSystemObject?
    private var networkMonitor: NWPathMonitor?
    
    // MARK: - Dispatch queues
    private var networkMonitorQueue = DispatchQueue(label: "com.jamtur01.NetworkInfo.networkMonitor")
    private var backgroundQueue = DispatchQueue(label: "com.jamtur01.NetworkInfo.background", qos: .utility, attributes: .concurrent)
    
    // MARK: - Initialization
    override init() {
        // Mimic the original spoon location for DNS configuration
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let preferredPath = homeDir.appendingPathComponent(".config/hammerspoon/dns.conf").path
        
        // Check if the config file exists in the original location
        if FileManager.default.fileExists(atPath: preferredPath) {
            dnsConfigPath = preferredPath
            print("Using existing DNS config at: \(dnsConfigPath)")
        } else {
            // Fall back to application support directory
            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDirectory = applicationSupport.appendingPathComponent("NetworkInfo")
            
            // Create the directory if it doesn't exist
            try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            dnsConfigPath = appDirectory.appendingPathComponent("dns.conf").path
            
            // Create a default config file if it doesn't exist
            if !FileManager.default.fileExists(atPath: dnsConfigPath) {
                try? "# DNS Configuration\n# Format: SSID = DNS_Server1 DNS_Server2 ...\n".write(toFile: dnsConfigPath, atomically: true, encoding: .utf8)
                print("Created new DNS config at: \(dnsConfigPath)")
            } else {
                print("Using existing DNS config at: \(dnsConfigPath)")
            }
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