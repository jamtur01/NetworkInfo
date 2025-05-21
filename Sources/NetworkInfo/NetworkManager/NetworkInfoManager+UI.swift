import AppKit
import Foundation

// MARK: - UI (Menu Building) Extension
extension NetworkInfoManager {
    func buildMenuItems(menu: NSMenu) {
        // Public IP
        let publicIP = data.geoIPData?.query ?? "N/A"
        let publicIPItem = NSMenuItem(title: "Public IP: \(publicIP)", action: #selector(AppDelegate.copyToClipboard(_:)), keyEquivalent: "")
        publicIPItem.representedObject = publicIP
        if #available(macOS 11.0, *) {
            publicIPItem.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Public IP")
        } else {
            publicIPItem.image = NSImage(named: "NSGlobeTemplate")
        }
        menu.addItem(publicIPItem)
        
        // Local IP
        let localIP = data.localIP ?? "N/A"
        let localIPItem = NSMenuItem(title: "Local IP: \(localIP)", action: #selector(AppDelegate.copyToClipboard(_:)), keyEquivalent: "")
        localIPItem.representedObject = localIP
        if #available(macOS 11.0, *) {
            localIPItem.image = NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: "Local IP")
        } else {
            localIPItem.image = NSImage(named: "NSComputer")
        }
        menu.addItem(localIPItem)
        
        // SSID with DNS Configuration
        addSSIDMenuItems(menu: menu)
        
        // DNS Information
        addDNSInfoMenuItems(menu: menu)
        
        // VPN Connections
        addVPNMenuItems(menu: menu)
        
        // Service Status
        addServiceStatusMenuItems(menu: menu)
        
        // ISP and Location
        addLocationMenuItems(menu: menu)
        
        // Refresh Option
        menu.addItem(NSMenuItem.separator())
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(AppDelegate.refreshData(_:)), keyEquivalent: "r")
        if #available(macOS 11.0, *) {
            refreshItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
        } else {
            refreshItem.image = NSImage(named: "NSRefreshTemplate")
        }
        menu.addItem(refreshItem)
        
        // Quit Option
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(AppDelegate.quitApp(_:)), keyEquivalent: "q")
        if #available(macOS 11.0, *) {
            quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit")
        }
        menu.addItem(quitItem)
    }
    
    private func addSSIDMenuItems(menu: NSMenu) {
        let ssid = data.ssid ?? "Not connected"
        let ssidItem = NSMenuItem(title: "SSID: \(ssid)", action: #selector(AppDelegate.copyToClipboard(_:)), keyEquivalent: "")
        ssidItem.representedObject = ssid
        if #available(macOS 11.0, *) {
            ssidItem.image = NSImage(systemSymbolName: "wifi", accessibilityDescription: "SSID")
        } else {
            ssidItem.image = NSImage(named: "NSNetwork")
        }
        menu.addItem(ssidItem)
        
        if let dnsConfig = data.dnsConfiguration {
            if dnsConfig.configured, let servers = dnsConfig.servers {
                let dnsConfigItem = NSMenuItem(title: "  DNS Config: \(servers)", action: #selector(AppDelegate.copyToClipboard(_:)), keyEquivalent: "")
                dnsConfigItem.representedObject = servers
                dnsConfigItem.indentationLevel = 1
                menu.addItem(dnsConfigItem)
            } else {
                let noDNSConfigItem = NSMenuItem(title: "  No Custom DNS Config", action: nil, keyEquivalent: "")
                noDNSConfigItem.isEnabled = false
                noDNSConfigItem.indentationLevel = 1
                menu.addItem(noDNSConfigItem)
            }
        }
    }
    
    private func addDNSInfoMenuItems(menu: NSMenu) {
        if let dnsInfo = data.dnsInfo, !dnsInfo.isEmpty {
            menu.addItem(NSMenuItem.separator())
            
            var expectedDNS: Set<String> = Set([EXPECTED_DNS])
            if let dnsConfig = data.dnsConfiguration, dnsConfig.configured, let servers = dnsConfig.servers {
                expectedDNS = Set(servers.split(separator: " ").map { String($0) })
            }
            
            let dnsHeader = NSMenuItem(title: "Current DNS Servers:", action: nil, keyEquivalent: "")
            dnsHeader.isEnabled = false
            if #available(macOS 11.0, *) {
                dnsHeader.image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: "DNS Servers")
            }
            menu.addItem(dnsHeader)
            
            for dns in dnsInfo {
                let icon = expectedDNS.contains(dns) ? "✅" : "⚠️"
                let dnsItem = NSMenuItem(title: "  \(icon) \(dns)", action: #selector(AppDelegate.copyToClipboard(_:)), keyEquivalent: "")
                dnsItem.representedObject = dns
                dnsItem.indentationLevel = 1
                menu.addItem(dnsItem)
            }
        }
    }
    
    private func addVPNMenuItems(menu: NSMenu) {
        if let vpnConnections = data.vpnConnections, !vpnConnections.isEmpty {
            menu.addItem(NSMenuItem.separator())
            
            let vpnHeader = NSMenuItem(title: "VPN Connections:", action: nil, keyEquivalent: "")
            vpnHeader.isEnabled = false
            if #available(macOS 11.0, *) {
                vpnHeader.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "VPN Connections")
            }
            menu.addItem(vpnHeader)
            
            for vpn in vpnConnections {
                let vpnItem = NSMenuItem(title: "  • \(vpn.name): \(vpn.ip)", action: #selector(AppDelegate.copyToClipboard(_:)), keyEquivalent: "")
                vpnItem.representedObject = "\(vpn.name): \(vpn.ip)"
                vpnItem.indentationLevel = 1
                menu.addItem(vpnItem)
            }
        }
    }
    
    private func addServiceStatusMenuItems(menu: NSMenu) {
        menu.addItem(NSMenuItem.separator())
        
        let serviceHeader = NSMenuItem(title: "Service Status:", action: nil, keyEquivalent: "")
        serviceHeader.isEnabled = false
        if #available(macOS 11.0, *) {
            serviceHeader.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Service Status")
        } else {
            serviceHeader.image = NSImage(named: "NSAdvanced")
        }
        menu.addItem(serviceHeader)
        
        for (service, state) in serviceStates {
            let runningStatus = state.running ? "Running" : "Stopped"
            // Use the NSNumber value safely
            let pidInfo = state.pid != nil ? " (PID: \(state.pid!.intValue))" : " (PID: N/A)"
            let respondingInfo = state.running ? (state.responding ? " - Responding" : " - Not Responding") : ""
            
            let serviceName = service.prefix(1).uppercased() + service.dropFirst()
            let serviceTitle = "  • \(serviceName): \(runningStatus)\(pidInfo)\(respondingInfo)"
            
            let serviceItem = NSMenuItem(title: serviceTitle, action: #selector(AppDelegate.copyToClipboard(_:)), keyEquivalent: "")
            serviceItem.representedObject = "\(serviceName) status: \(runningStatus)\(respondingInfo)"
            serviceItem.indentationLevel = 1
            serviceItem.isEnabled = true
            
            menu.addItem(serviceItem)
        }
        
        // DNS Resolution - also make this clickable
        if let dnsTest = data.dnsTest {
            let dnsResolutionTitle = String(format: "  • DNS Resolution: %.1f%% Success Rate", dnsTest.successRate)
            let dnsResolutionItem = NSMenuItem(title: dnsResolutionTitle, action: #selector(AppDelegate.copyToClipboard(_:)), keyEquivalent: "")
            dnsResolutionItem.representedObject = String(format: "DNS Resolution: %.1f%% Success Rate", dnsTest.successRate)
            dnsResolutionItem.indentationLevel = 1
            dnsResolutionItem.isEnabled = true
            
            menu.addItem(dnsResolutionItem)
        }
    }
    
    private func addLocationMenuItems(menu: NSMenu) {
        if let geoIPData = data.geoIPData {
            menu.addItem(NSMenuItem.separator())
            
            // ISP
            let ispValue = geoIPData.isp != "N/A" ? geoIPData.isp : "Unknown"
            let ispItem = NSMenuItem(title: "ISP: \(ispValue)", action: #selector(AppDelegate.copyToClipboard(_:)), keyEquivalent: "")
            ispItem.representedObject = ispValue
            if #available(macOS 11.0, *) {
                ispItem.image = NSImage(systemSymbolName: "network", accessibilityDescription: "ISP")
            }
            menu.addItem(ispItem)
            
            // Location
            let locationText = "\(geoIPData.country) (\(geoIPData.countryCode))"
            let locationItem = NSMenuItem(title: "Location: \(locationText)", action: #selector(AppDelegate.copyToClipboard(_:)), keyEquivalent: "")
            locationItem.representedObject = locationText
            if #available(macOS 11.0, *) {
                locationItem.image = NSImage(systemSymbolName: "mappin.and.ellipse", accessibilityDescription: "Location")
            } else {
                locationItem.image = NSImage(named: "NSLocation")
            }
            menu.addItem(locationItem)
        }
    }
}