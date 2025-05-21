import Foundation

// MARK: - KVC Support Extension
extension NetworkInfoManager {
    override func setValue(_ value: Any?, forKey key: String) {
        switch key {
        case "dnsConfigPath":
            // Use super.setValue for private constants
            super.setValue(value, forKey: key)
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
        case "dnsConfigPath":
            return dnsConfigPath
        case "data":
            return data
        case "serviceStates":
            return serviceStates
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