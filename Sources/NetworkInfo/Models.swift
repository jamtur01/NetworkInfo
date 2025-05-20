import Foundation

struct ServiceState {
    var pid: Int?
    var running: Bool = false
    var responding: Bool = false
}

struct VPNConnection {
    var name: String
    var ip: String
}

struct DNSTestResult {
    var success: Bool
    var response: String
}

struct DNSTest {
    var working: Bool
    var successRate: Double
    var details: [String: DNSTestResult]
}

struct GeoIPData {
    var query: String = "N/A"
    var isp: String = "N/A"
    var country: String = "N/A"
    var countryCode: String = "N/A"
}

struct DNSConfig {
    var ssid: String?
    var servers: String?
    var configured: Bool = false
}

struct NetworkData {
    var geoIPData: GeoIPData?
    var dnsInfo: [String]?
    var dnsTest: DNSTest?
    var localIP: String?
    var ssid: String?
    var vpnConnections: [VPNConnection]?
    var dnsConfiguration: DNSConfig?
}
