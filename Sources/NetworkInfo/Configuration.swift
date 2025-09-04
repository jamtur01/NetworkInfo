import Foundation

/// Centralized configuration for NetworkInfo application
struct NetworkInfoConfiguration {
    
    // MARK: - Timing Constants
    
    /// Base refresh interval when network is stable (in seconds)
    static let baseRefreshInterval: TimeInterval = 120
    
    /// Fast refresh interval when network is unstable (in seconds)  
    static let fastRefreshInterval: TimeInterval = 30
    
    /// Minimum refresh interval to prevent excessive polling (in seconds)
    static let minRefreshInterval: TimeInterval = 15
    
    /// How often to check service status (in seconds) 
    static let serviceCheckInterval: TimeInterval = 60
    
    /// Request timeout for network operations (in seconds)
    static let networkTimeout: TimeInterval = 5.0
    
    // MARK: - DNS Configuration
    
    /// Expected local DNS server for service validation
    static let expectedDNS = "127.0.0.1"
    
    /// Domains used for DNS resolution testing
    static let testDomains = ["example.com", "google.com", "cloudflare.com"]
    
    /// DNS services to monitor
    static let dnsServices = [
        "unbound": "org.cronokirby.unbound",
        "kresd": "org.knot-resolver.kresd"
    ]
    
    // MARK: - Network Configuration
    
    /// Test IP addresses used in testing mode
    static let testLocalIP = "192.168.1.100"
    
    /// Ports for service response checking
    static let servicePorts: [String: String] = [
        "unbound": "53",
        "kresd": "8053"  // kresd is configured to listen on port 8053 according to kresd.conf
    ]
    
    // MARK: - File Paths
    
    /// DNS configuration filename
    static let dnsConfigFilename = "dns.conf"
    
    /// Legacy DNS configuration path (for migration)
    static let legacyDNSConfigPath = ".config/hammerspoon/dns.conf"
    
    // MARK: - Application Configuration
    
    /// Application name for configuration directory
    static let appName = "NetworkInfo"
    
    /// Notification identifier prefix
    static let notificationPrefix = "com.jamtur01.NetworkInfo"
    
    // MARK: - Example DNS Configuration Content
    
    static let exampleDNSConfig = """
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
}