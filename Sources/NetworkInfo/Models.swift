import Foundation

@objc class ServiceState: NSObject {
    // Use NSNumber for Objective-C compatibility with optionals
    @objc var pid: NSNumber? = nil
    @objc var running: Bool = false
    @objc var responding: Bool = false
    
    // Add convenience methods for working with Int? <-> NSNumber?
    func setPidInt(_ value: Int?) {
        if let value = value {
            pid = NSNumber(value: value)
        } else {
            pid = nil
        }
    }
    
    func getPidInt() -> Int? {
        return pid?.intValue
    }
    
    // Add a custom initializer for tests - NSNumber is compatible with Objective-C
    // Note: Can't use optional Int as parameter in @objc methods, 
    // so we use NSNumber? instead or we drop @objc
    convenience init(pid: Int?, running: Bool, responding: Bool) {
        self.init()
        if let pidValue = pid {
            self.pid = NSNumber(value: pidValue)
        } else {
            self.pid = nil
        }
        self.running = running
        self.responding = responding
    }
}

@objc class VPNConnection: NSObject {
    @objc var name: String
    @objc var ip: String
    
    init(name: String, ip: String) {
        self.name = name
        self.ip = ip
        super.init()
    }
}

@objc class DNSTestResult: NSObject {
    @objc var success: Bool
    @objc var response: String
    
    init(success: Bool, response: String) {
        self.success = success
        self.response = response
        super.init()
    }
}

@objc class DNSTest: NSObject {
    @objc var working: Bool
    @objc var successRate: Double
    // Dictionary is not directly compatible with Objective-C
    // Store it as a non-objc property
    var details: [String: DNSTestResult]
    
    init(working: Bool, successRate: Double, details: [String: DNSTestResult]) {
        self.working = working
        self.successRate = successRate
        self.details = details
        super.init()
    }
}

@objc class GeoIPData: NSObject {
    @objc var query: String = "N/A"
    @objc var isp: String = "N/A"
    @objc var country: String = "N/A"
    @objc var countryCode: String = "N/A"
    
    override init() {
        super.init()
    }
    
    init(query: String, isp: String, country: String, countryCode: String) {
        self.query = query
        self.isp = isp
        self.country = country
        self.countryCode = countryCode
        super.init()
    }
}

@objc class DNSConfig: NSObject {
    @objc var ssid: String?
    @objc var servers: String?
    @objc var configured: Bool = false
    
    override init() {
        super.init()
    }
    
    init(ssid: String? = nil, servers: String? = nil, configured: Bool = false) {
        self.ssid = ssid
        self.servers = servers
        self.configured = configured
        super.init()
    }
}

@objc class NetworkData: NSObject {
    @objc var geoIPData: GeoIPData?
    @objc var dnsInfo: [String]?
    @objc var dnsTest: DNSTest?
    @objc var localIP: String?
    @objc var ssid: String?
    @objc var vpnConnections: [VPNConnection]?
    @objc var dnsConfiguration: DNSConfig?
    
    override init() {
        super.init()
    }
}