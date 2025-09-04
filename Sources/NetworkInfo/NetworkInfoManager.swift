import Foundation
import Network
import AppKit
import CoreLocation

// MARK: - NetworkInfoManager Core
@objcMembers @MainActor class NetworkInfoManager: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    // MARK: - Constants
    internal let SERVICE_CHECK_INTERVAL = NetworkInfoConfiguration.serviceCheckInterval
    internal let EXPECTED_DNS = NetworkInfoConfiguration.expectedDNS
    internal let TEST_DOMAINS = NetworkInfoConfiguration.testDomains
    
    // MARK: - Adaptive Refresh
    private var currentRefreshInterval = NetworkInfoConfiguration.baseRefreshInterval
    private var networkStabilityScore = 0.0 // 0.0 = unstable, 1.0 = very stable
    private var lastNetworkPath: NWPath?
    
    // MARK: - File paths
    // Change from let to var to allow setting for tests
    nonisolated(unsafe) internal var dnsConfigPath: String
    
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
    nonisolated let networkMonitorQueue = DispatchQueue(label: "com.jamtur01.NetworkInfo.networkMonitor")
    
    // MARK: - Location manager for WiFi access
    internal var locationManager: CLLocationManager?
    
    // MARK: - AsyncStream for data updates
    private var dataUpdateContinuation: AsyncStream<NetworkData>.Continuation?
    private lazy var dataUpdateStream: AsyncStream<NetworkData> = {
        AsyncStream { continuation in
            self.dataUpdateContinuation = continuation
        }
    }()
    
    // For tests
    nonisolated(unsafe) internal var isTestMode = false
    
    // MARK: - Initialization
    override init() {
        // Standard macOS app configuration location: Application Support directory
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = applicationSupport.appendingPathComponent(NetworkInfoConfiguration.appName)
        
        // Create the directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        
        dnsConfigPath = appDirectory.appendingPathComponent(NetworkInfoConfiguration.dnsConfigFilename).path
        
        // For backward compatibility, check if a config exists in the legacy location
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let legacyPath = homeDir.appendingPathComponent(NetworkInfoConfiguration.legacyDNSConfigPath).path
        
        // If the file exists in legacy location but not in the new location, copy it
        if FileManager.default.fileExists(atPath: legacyPath) && !FileManager.default.fileExists(atPath: dnsConfigPath) {
            try? FileManager.default.copyItem(atPath: legacyPath, toPath: dnsConfigPath)
            Logger.info("Migrated DNS config from \(legacyPath) to \(dnsConfigPath)", category: "Config")
        }
        
        // Create a default config file with examples if it doesn't exist
        if !FileManager.default.fileExists(atPath: dnsConfigPath) {
            try? NetworkInfoConfiguration.exampleDNSConfig.write(toFile: dnsConfigPath, atomically: true, encoding: .utf8)
            Logger.info("Created new DNS config with examples at: \(dnsConfigPath)", category: "Config")
        } else {
            Logger.debug("Using existing DNS config at: \(dnsConfigPath)", category: "Config")
        }
        
        super.init()
    }
    
    // MARK: - Public API
    func start() {
        // Set up location manager for WiFi SSID access
        setupLocationManager()
        
        // Run an immediate refresh to populate data
        refreshData()
        
        // Run immediate service and DNS checks
        monitorServices()
        testDNSResolution()
        
        // Set up adaptive refresh timer
        startAdaptiveRefresh()
        
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
        Task {
            await refreshDataAsync()
        }
    }
    
    private func refreshDataAsync() async {
        // Preserve DNS configuration
        let dnsConfiguration = data.dnsConfiguration
        
        // Reset data
        data = NetworkData()
        data.dnsConfiguration = dnsConfiguration
        
        // Fetch all data concurrently using TaskGroup
        await withTaskGroup(of: Void.self) { [self] group in
            group.addTask { self.getGeoIPData() }
            group.addTask { self.getLocalIPAddress() }
            group.addTask { self.getCurrentSSID() }
            group.addTask { self.getVPNConnections() }
            group.addTask { self.getDNSInfo() }
            group.addTask { self.testDNSResolution() }
            group.addTask { self.monitorServices() }
        }
        
        Logger.debug("All network data refreshed", category: "Network")
        
        // Emit data update through AsyncStream
        dataUpdateContinuation?.yield(data)
        
        // Post a notification that data has been updated (for legacy compatibility)
        NotificationCenter.default.post(name: NSNotification.Name("NetworkDataUpdated"), object: nil)
    }
    
    // MARK: - Async Data Fetching Wrappers
    
    
    // MARK: - Helper Methods
    func logNotification(title: String, body: String) {
        Logger.notification("\(title): \(body)", category: "Notification")
    }
    
    // MARK: - Location Services Setup
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        
        // Request location permission for WiFi SSID access
        if CLLocationManager.locationServicesEnabled() {
            switch locationManager?.authorizationStatus {
            case .notDetermined:
                Logger.info("Requesting location permission for WiFi SSID access", category: "Location")
                locationManager?.requestAlwaysAuthorization()
            case .denied, .restricted:
                Logger.warning("Location services denied/restricted - SSID will show as restricted", category: "Location")
            case .authorizedAlways, .authorizedWhenInUse:
                Logger.info("Location services authorized - SSID detection should work", category: "Location")
            case .none:
                Logger.error("No location manager available", category: "Location")
            @unknown default:
                Logger.warning("Unknown location authorization status", category: "Location")
            }
        } else {
            Logger.warning("Location services disabled - SSID will show as restricted", category: "Location")
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            Logger.info("Location permission granted - refreshing data for SSID detection", category: "Location")
            Task { @MainActor in
                try await Task.sleep(for: .seconds(1))
                self.refreshData() 
            }
        case .denied, .restricted:
            Logger.warning("Location permission denied - SSID will show as restricted", category: "Location")
        case .notDetermined:
            Logger.debug("Location permission not determined", category: "Location")
        @unknown default:
            Logger.warning("Unknown location authorization status: \(status.rawValue)", category: "Location")
        }
    }
    
    // MARK: - Adaptive Refresh System
    
    private func startAdaptiveRefresh() {
        updateRefreshTimer()
    }
    
    private func updateRefreshTimer() {
        refreshTimer?.invalidate()
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: currentRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshData()
            }
        }
        
        Logger.debug("Updated refresh timer to \(currentRefreshInterval)s interval", category: "Performance")
    }
    
    internal func updateNetworkStability(newPath: NWPath) {
        defer { lastNetworkPath = newPath }
        
        guard let lastPath = lastNetworkPath else {
            // First path update - assume stable initially
            networkStabilityScore = 0.8
            return
        }
        
        // Calculate stability based on path changes
        let pathChanged = lastPath.status != newPath.status || 
                         lastPath.isExpensive != newPath.isExpensive ||
                         lastPath.isConstrained != newPath.isConstrained
        
        if pathChanged {
            // Network changed - decrease stability
            networkStabilityScore = max(0.0, networkStabilityScore - 0.3)
            Logger.info("Network path changed, stability score: \(networkStabilityScore)", category: "Performance")
        } else {
            // Network stable - gradually increase stability
            networkStabilityScore = min(1.0, networkStabilityScore + 0.1)
        }
        
        // Adjust refresh interval based on stability
        let targetInterval: TimeInterval
        if networkStabilityScore > 0.7 {
            // Very stable - use base interval
            targetInterval = NetworkInfoConfiguration.baseRefreshInterval
        } else if networkStabilityScore > 0.4 {
            // Moderately stable - use faster refresh
            targetInterval = NetworkInfoConfiguration.fastRefreshInterval
        } else {
            // Unstable - use minimum interval
            targetInterval = NetworkInfoConfiguration.minRefreshInterval
        }
        
        // Only update timer if interval changed significantly (avoid thrashing)
        if abs(currentRefreshInterval - targetInterval) > 5.0 {
            currentRefreshInterval = targetInterval
            updateRefreshTimer()
        }
    }
    
    // MARK: - Data Streaming Interface
    
    /// AsyncStream that emits NetworkData updates for reactive programming
    var networkDataUpdates: AsyncStream<NetworkData> {
        return dataUpdateStream
    }
    
    // MARK: - Public Menu Interface
    func buildMenu(menu: NSMenu) {
        // This method is implemented in the UI extension
        buildMenuItems(menu: menu)
    }
}