import Foundation
@testable import NetworkInfo

// Test extensions to expose private properties for testing
extension NetworkInfoManager {
    // Properties for testing access
    var testDNSConfigPath: String {
        return self.value(forKey: "dnsConfigPath") as! String
    }
    
    var testData: NetworkData {
        return self.value(forKey: "data") as! NetworkData
    }
    
    func setTestData(_ newData: NetworkData) {
        self.setValue(newData, forKey: "data")
    }
    
    var testServiceStates: [String: ServiceState] {
        return self.value(forKey: "serviceStates") as! [String: ServiceState]
    }
    
    func setTestServiceState(for service: String, state: ServiceState) {
        var states = self.testServiceStates
        states[service] = state
        self.setValue(states, forKey: "serviceStates")
    }
    
    func setTestDNSConfigPath(_ path: String) {
        // Using setValue because dnsConfigPath is a let constant
        self.setValue(path, forKey: "dnsConfigPath")
    }
    
    // Helper methods to set specific data properties for testing
    func setTestLocalIP(_ ip: String) {
        let data = self.testData
        data.localIP = ip
        self.setValue(data, forKey: "data")
    }
    
    func setTestSSID(_ ssid: String) {
        let data = self.testData
        data.ssid = ssid
        self.setValue(data, forKey: "data")
    }
    
    func setTestGeoIPData(_ geoIPData: GeoIPData) {
        let data = self.testData
        data.geoIPData = geoIPData
        self.setValue(data, forKey: "data")
    }
    
    func setTestDNSInfo(_ dnsInfo: [String]) {
        let data = self.testData
        data.dnsInfo = dnsInfo
        self.setValue(data, forKey: "data")
    }
    
    func setTestDNSTest(_ dnsTest: DNSTest) {
        let data = self.testData
        data.dnsTest = dnsTest
        self.setValue(data, forKey: "data")
    }
    
    func setTestVPNConnections(_ vpnConnections: [VPNConnection]) {
        let data = self.testData
        data.vpnConnections = vpnConnections
        self.setValue(data, forKey: "data")
    }
    
    func setTestDNSConfiguration(_ dnsConfiguration: DNSConfig) {
        let data = self.testData
        data.dnsConfiguration = dnsConfiguration
        self.setValue(data, forKey: "data")
    }
    
    // Helper methods to get specific data properties for testing
    func getTestGeoIPData() -> GeoIPData? {
        return self.testData.geoIPData
    }
    
    func getTestDNSConfiguration() -> DNSConfig? {
        return self.testData.dnsConfiguration
    }
    
    // Enable test mode
    func enableTestMode() {
        self.isTestMode = true
    }
}
