import Foundation
@testable import NetworkInfo

// Test extensions to expose private properties for testing
extension NetworkInfoManager {
    // Properties for testing access - direct access since KVC is disabled in Swift 6.0
    @MainActor var testDNSConfigPath: String {
        return dnsConfigPath
    }
    
    @MainActor var testData: NetworkData {
        return data
    }
    
    @MainActor func setTestData(_ newData: NetworkData) {
        data = newData
    }
    
    @MainActor var testServiceStates: [String: ServiceState] {
        return serviceStates
    }
    
    @MainActor func setTestServiceState(for service: String, state: ServiceState) {
        serviceStates[service] = state
    }
    
    @MainActor func setTestDNSConfigPath(_ path: String) {
        dnsConfigPath = path
    }
    
    // Helper methods to set specific data properties for testing
    @MainActor func setTestLocalIP(_ ip: String) {
        data.localIP = ip
    }
    
    @MainActor func setTestSSID(_ ssid: String) {
        data.ssid = ssid
    }
    
    @MainActor func setTestGeoIPData(_ geoIPData: GeoIPData) {
        data.geoIPData = geoIPData
    }
    
    @MainActor func setTestDNSInfo(_ dnsInfo: [String]) {
        data.dnsInfo = dnsInfo
    }
    
    @MainActor func setTestDNSTest(_ dnsTest: DNSTest) {
        data.dnsTest = dnsTest
    }
    
    @MainActor func setTestVPNConnections(_ vpnConnections: [VPNConnection]) {
        data.vpnConnections = vpnConnections
    }
    
    @MainActor func setTestDNSConfiguration(_ dnsConfiguration: DNSConfig) {
        data.dnsConfiguration = dnsConfiguration
    }
    
    // Helper methods to get specific data properties for testing
    @MainActor func getTestGeoIPData() -> GeoIPData? {
        return data.geoIPData
    }
    
    @MainActor func getTestDNSConfiguration() -> DNSConfig? {
        return data.dnsConfiguration
    }
    
    // Enable test mode
    @MainActor func enableTestMode() {
        isTestMode = true
    }
}
