import Foundation

// MARK: - KVC Support Extension
extension NetworkInfoManager {
    // This class needs to handle direct access to properties
    
    override func setValue(_ value: Any?, forKey key: String) {
        switch key {
        // Property keys
        case "dnsConfigPath":
            if let stringValue = value as? String {
                dnsConfigPath = stringValue
            }
        case "data":
            if let dataValue = value as? NetworkData {
                data = dataValue
            }
        case "serviceStates":
            if let statesDict = value as? [String: ServiceState] {
                serviceStates = statesDict
            }
        case "lastAppliedDNSConfig":
            if let config = value as? DNSConfig {
                lastAppliedDNSConfig = config
            }
            
        // Special properties
        case "configWatcher", "networkMonitor", "networkMonitorQueue", "backgroundQueue":
            // These properties can't be accessed through KVC due to incompatible types
            print("Warning: Attempted to set non-KVC compliant property: \(key)")
            
        // Data model properties - forwarding to data object
        case "localIP":
            data.localIP = value as? String
        case "ssid":
            data.ssid = value as? String
        case "geoIPData":
            data.geoIPData = value as? GeoIPData
        case "dnsInfo":
            data.dnsInfo = value as? [String]
        case "dnsTest":
            data.dnsTest = value as? DNSTest
        case "vpnConnections":
            data.vpnConnections = value as? [VPNConnection]
        case "dnsConfiguration":
            data.dnsConfiguration = value as? DNSConfig
        default:
            super.setValue(value, forKey: key)
        }
    }
    
    override func value(forKey key: String) -> Any? {
        switch key {
        // Property keys
        case "dnsConfigPath":
            return dnsConfigPath
        case "data":
            return data
        case "serviceStates":
            return serviceStates
        case "lastAppliedDNSConfig":
            return lastAppliedDNSConfig
            
        // Special properties
        case "configWatcher", "networkMonitor", "networkMonitorQueue", "backgroundQueue":
            print("Warning: Attempted to access non-KVC compliant property: \(key)")
            return nil
            
        // Data model properties - forwarding to data object
        case "localIP":
            return data.localIP
        case "ssid":
            return data.ssid
        case "geoIPData":
            return data.geoIPData
        case "dnsInfo":
            return data.dnsInfo
        case "dnsTest":
            return data.dnsTest
        case "vpnConnections":
            return data.vpnConnections
        case "dnsConfiguration":
            return data.dnsConfiguration
        default:
            return super.value(forKey: key)
        }
    }
}