import Foundation
import CoreLocation

// MARK: - Data Fetching Extension
extension NetworkInfoManager {
    nonisolated func getGeoIPData() {
        Task {
            let geoIPData: GeoIPData
            
            if self.isTestMode {
                // Use test data in test mode
                geoIPData = await GeoIPService.createTestData()
            } else {
                // Fetch real data from GeoIP service
                if let realData = await GeoIPService.fetchGeoIPData() {
                    geoIPData = realData
                } else {
                    geoIPData = await GeoIPService.createTestData()
                }
            }
            
            await MainActor.run {
                if self.data.geoIPData == nil || !self.isTestMode {
                    self.data.geoIPData = geoIPData
                }
            }
        }
    }
    
    nonisolated func getLocalIPAddress() {
        Task {
            let localIP: String
            
            if self.isTestMode {
                localIP = NetworkInfoConfiguration.testLocalIP
            } else {
                do {
                    let output = try await ProcessService.execute(command: "/bin/sh", arguments: ["-c", "ipconfig getifaddr en0"])
                    localIP = output.isEmpty ? "N/A" : output
                } catch {
                    Logger.error("Failed to get local IP: \(error.localizedDescription)", category: "Network")
                    localIP = "N/A"
                }
            }
            
            await MainActor.run {
                self.data.localIP = localIP
            }
        }
    }
    
    nonisolated func getCurrentSSID() {
        Task {
            let ssid: String
            
            if self.isTestMode {
                ssid = await MainActor.run {
                    return self.data.ssid ?? "Not connected"
                }
            } else {
                ssid = await SSIDService.detectSSID()
            }
            
            await MainActor.run {
                self.processSSIDForDNSConfig(ssid: ssid)
            }
        }
    }
    
    private nonisolated func processSSIDForDNSConfig(ssid: String) {
        // Process DNS configuration in the background
        let (dnsServers, configured) = self.readDNSConfig(ssid: ssid)
        
        Task { @MainActor in
            self.data.ssid = ssid
            
            // Update DNS config based on SSID
            if ssid != "Not connected" {
                if configured, let servers = dnsServers {
                    self.data.dnsConfiguration = DNSConfig(ssid: ssid, servers: servers, configured: true)
                    
                    // Only update DNS settings if the SSID or DNS servers have changed.
                    if self.lastAppliedDNSConfig.ssid != ssid || self.lastAppliedDNSConfig.servers != servers {
                        // Update DNS in background
                        Task.detached { [weak self] in
                            guard let self = self else { return }
                            if await self.updateDNSSettings(dnsServers: servers) {
                                Logger.info("Successfully applied DNS configuration for \(ssid)", category: "DNS")
                                
                                await MainActor.run {
                                    self.logNotification(
                                        title: "Wi-Fi DNS Changed",
                                        body: "Connected to \(ssid) with DNS: \(servers)"
                                    )
                                    
                                    self.lastAppliedDNSConfig.ssid = ssid
                                    self.lastAppliedDNSConfig.servers = servers
                                }
                            } else {
                                Logger.error("Failed to apply DNS configuration for \(ssid)", category: "DNS")
                            }
                        }
                    } else {
                        Logger.debug("DNS configuration already applied for \(ssid)", category: "DNS")
                    }
                } else {
                    Logger.debug("No custom DNS configuration for \(ssid)", category: "DNS")
                    self.data.dnsConfiguration = DNSConfig(ssid: ssid, configured: false)
                    self.lastAppliedDNSConfig.ssid = nil
                    self.lastAppliedDNSConfig.servers = nil
                }
            } else {
                Logger.debug("Not connected to any Wi-Fi network", category: "SSID")
                self.data.dnsConfiguration = nil
                self.lastAppliedDNSConfig.ssid = nil
                self.lastAppliedDNSConfig.servers = nil
            }
        }
    }
    
    nonisolated func getVPNConnections() {
        Task {
            let vpnConnections = await VPNService.detectVPNConnections()
            
            await MainActor.run {
                self.data.vpnConnections = vpnConnections
            }
        }
    }
}