import Foundation

// MARK: - KVC Support Extension
extension NetworkInfoManager {
    // This class needs to handle direct access to properties
    
    nonisolated override func setValue(_ value: Any?, forKey key: String) {
        switch key {
        // Property keys
        case "dnsConfigPath":
            if let stringValue = value as? String {
                dnsConfigPath = stringValue
            }
        case "data":
            if let dataValue = value as? NetworkData {
                Task { @MainActor in
                    data = dataValue
                }
            }
        case "serviceStates":
            if let statesDict = value as? [String: ServiceState] {
                Task { @MainActor in
                    serviceStates = statesDict
                }
            }
        case "lastAppliedDNSConfig":
            if let config = value as? DNSConfig {
                Task { @MainActor in
                    lastAppliedDNSConfig = config
                }
            }
            
        // Special properties
        case "configWatcher", "networkMonitor", "networkMonitorQueue", "backgroundQueue":
            // These properties can't be accessed through KVC due to incompatible types
            print("Warning: Attempted to set non-KVC compliant property: \(key)")
            
        // Data model properties - forwarding to data object
        case "localIP", "ssid", "geoIPData", "dnsInfo", "dnsTest", "vpnConnections", "dnsConfiguration":
            // TODO: KVC for data properties disabled in Swift 6.0 due to concurrency
            print("Warning: KVC access to data properties is disabled in Swift 6.0")
        default:
            super.setValue(value, forKey: key)
        }
    }
    
    nonisolated override func value(forKey key: String) -> Any? {
        switch key {
        // Property keys
        case "dnsConfigPath":
            return dnsConfigPath
        case "data":
            // TODO: Fix for Swift 6.0 concurrency
            return nil  // data access requires MainActor
        case "serviceStates":
            // TODO: Fix for Swift 6.0 concurrency  
            return nil  // serviceStates access requires MainActor
        case "lastAppliedDNSConfig":
            // TODO: Fix for Swift 6.0 concurrency
            return nil  // lastAppliedDNSConfig access requires MainActor
            
        // Special properties
        case "configWatcher", "networkMonitor", "networkMonitorQueue", "backgroundQueue":
            print("Warning: Attempted to access non-KVC compliant property: \(key)")
            return nil
            
        // Data model properties - forwarding to data object  
        case "localIP":
            // TODO: Fix for Swift 6.0 concurrency
            return nil  // data access requires MainActor
        case "ssid":
            // TODO: Fix for Swift 6.0 concurrency
            return nil  // data access requires MainActor
        case "geoIPData":
            // TODO: Fix for Swift 6.0 concurrency
            return nil  // data access requires MainActor
        case "dnsInfo":
            // TODO: Fix for Swift 6.0 concurrency
            return nil  // data access requires MainActor
        case "dnsTest":
            // TODO: Fix for Swift 6.0 concurrency
            return nil  // data access requires MainActor
        case "vpnConnections":
            // TODO: Fix for Swift 6.0 concurrency
            return nil  // data access requires MainActor
        case "dnsConfiguration":
            // TODO: Fix for Swift 6.0 concurrency
            return nil  // data access requires MainActor
        default:
            return super.value(forKey: key)
        }
    }
}