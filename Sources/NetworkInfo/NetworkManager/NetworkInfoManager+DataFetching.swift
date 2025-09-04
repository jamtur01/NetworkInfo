import Foundation
import CoreWLAN
import CoreLocation

// MARK: - Data Fetching Extension
extension NetworkInfoManager {
    nonisolated func getGeoIPData() {
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Skip real network calls in test mode
            if self.isTestMode {
                // In test mode, use existing test data or set a default
                Task { @MainActor in
                    if self.data.geoIPData == nil {
                        self.data.geoIPData = GeoIPData(
                            query: "192.168.1.100",
                            isp: "Test ISP",
                            country: "Test Country",
                            countryCode: "TC"
                        )
                    }
                }
                return
            }
            
            // Use multiple services with ipapi.co as the primary
            let apiUrls = [
                "https://ipapi.co/json",  // Primary service (confirmed working)
                "http://ip-api.com/json/",
                "https://ipinfo.io/json"
            ]
            
            var errorCount = 0
            
            for apiUrl in apiUrls {
                guard let url = URL(string: apiUrl) else { continue }
                
                let semaphore = DispatchSemaphore(value: 0)
                
                // Use a class wrapper to avoid concurrency warnings
                final class DataContainer: @unchecked Sendable {
                    var data: GeoIPData?
                    private let lock = NSLock()
                    
                    func set(_ value: GeoIPData?) {
                        lock.lock()
                        defer { lock.unlock() }
                        data = value
                    }
                    
                    func get() -> GeoIPData? {
                        lock.lock()
                        defer { lock.unlock() }
                        return data
                    }
                }
                
                let container = DataContainer()
                
                var request = URLRequest(url: url)
                request.timeoutInterval = 5.0
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    defer { semaphore.signal() }
                    
                    guard let data = data,
                          let response = response as? HTTPURLResponse,
                          response.statusCode == 200,
                          error == nil else {
                        print("Error fetching GeoIP data from \(apiUrl): \(error?.localizedDescription ?? "Unknown error")")
                        return
                    }
                    
                    // Try to parse the response
                    do {
                        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                        
                        let geoData: GeoIPData
                        if apiUrl.contains("ipapi.co") {
                            // ipapi.co format
                            geoData = GeoIPData(
                                query: json?["ip"] as? String ?? "N/A",
                                isp: json?["org"] as? String ?? "N/A",
                                country: json?["country_name"] as? String ?? "N/A",
                                countryCode: json?["country_code"] as? String ?? "N/A"
                            )
                        } else if apiUrl.contains("ip-api.com") {
                            // ip-api.com format
                            geoData = GeoIPData(
                                query: json?["query"] as? String ?? "N/A",
                                isp: json?["isp"] as? String ?? "N/A",
                                country: json?["country"] as? String ?? "N/A",
                                countryCode: json?["countryCode"] as? String ?? "N/A"
                            )
                        } else if apiUrl.contains("ipinfo.io") {
                            // ipinfo.io format
                            geoData = GeoIPData(
                                query: json?["ip"] as? String ?? "N/A",
                                isp: json?["org"] as? String ?? "N/A",
                                country: json?["country"] as? String ?? "N/A",
                                countryCode: json?["country"] as? String ?? "N/A"
                            )
                        } else {
                            return // Unknown API format
                        }
                        
                        container.set(geoData)
                        print("Successfully retrieved GeoIP data from \(apiUrl)")
                    } catch {
                        print("Error parsing GeoIP data from \(apiUrl): \(error.localizedDescription)")
                    }
                }.resume()
                
                // Wait for the request to complete with a timeout
                _ = semaphore.wait(timeout: .now() + 5)
                
                if let data = container.get(), data.query != "N/A" {
                    DispatchQueue.main.async {
                        self.data.geoIPData = data
                    }
                    return
                }
                
                errorCount += 1
            }
            
            // If all services failed, update with a fallback message
            if errorCount == apiUrls.count {
                DispatchQueue.main.async {
                    self.data.geoIPData = GeoIPData(
                        query: "Check connection",
                        isp: "Network issue",
                        country: "Unavailable",
                        countryCode: "N/A"
                    )
                }
            }
        }
    }
    
    nonisolated func getLocalIPAddress() {
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Skip real network check in test mode
            if self.isTestMode {
                // In test mode, use a preset IP value if none exists
                Task { @MainActor in
                    if self.data.localIP == nil || self.data.localIP == "" {
                        self.data.localIP = "192.168.1.100" // Test default
                    }
                }
                return
            }
            
            let task = Process()
            task.launchPath = "/bin/sh"
            task.arguments = ["-c", "ipconfig getifaddr en0"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            task.launch()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            
            DispatchQueue.main.async {
                self.data.localIP = output.isEmpty ? "N/A" : output
            }
            
            task.waitUntilExit()
        }
    }
    
    nonisolated func getCurrentSSID() {
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Skip real network check in test mode
            if self.isTestMode {
                // In test mode, just use existing test SSID value
                Task { @MainActor in
                    let ssid = self.data.ssid == nil || self.data.ssid?.isEmpty == true ? "Not connected" : self.data.ssid!
                    self.processSSIDForDNSConfig(ssid: ssid)
                }
                return
            }
            
            var ssid = "Not connected"
            
            // Method 1: Try Core WLAN framework first (requires Location Services permission)
            let wifiClient = CWWiFiClient.shared()
            
            // Try default interface first
            if let wifiInterface = wifiClient.interface() {
                if let networkName = wifiInterface.ssid() {
                    ssid = networkName
                    print("Detected SSID via Core WLAN (default interface): \(ssid)")
                    self.processSSIDForDNSConfig(ssid: ssid)
                    return
                }
            }
            
            // Try all WiFi interfaces
            if let interfaces = wifiClient.interfaces() {
                for interface in interfaces {
                    if let networkName = interface.ssid() {
                        ssid = networkName
                        print("Detected SSID via Core WLAN (interface \(interface.interfaceName ?? "unknown")): \(ssid)")
                        self.processSSIDForDNSConfig(ssid: ssid)
                        return
                    }
                }
            }
            
            // Method 2: Try networksetup command for all interfaces
            let networksetupTask = Process()
            networksetupTask.launchPath = "/usr/sbin/networksetup"
            networksetupTask.arguments = ["-listallhardwareports"]
            
            let networksetupPipe = Pipe()
            networksetupTask.standardOutput = networksetupPipe
            networksetupTask.launch()
            
            let networksetupData = networksetupPipe.fileHandleForReading.readDataToEndOfFile()
            let networksetupOutput = String(data: networksetupData, encoding: .utf8) ?? ""
            networksetupTask.waitUntilExit()
            
            // Parse interfaces and try each one
            let lines = networksetupOutput.components(separatedBy: .newlines)
            var currentInterface: String?
            
            for line in lines {
                if line.contains("Hardware Port: Wi-Fi") {
                    // Found Wi-Fi port, next line should have device
                    continue
                } else if line.hasPrefix("Device: ") && currentInterface == nil {
                    currentInterface = String(line.dropFirst(8))
                    
                    if let interface = currentInterface {
                        let airportTask = Process()
                        airportTask.launchPath = "/usr/sbin/networksetup"
                        airportTask.arguments = ["-getairportnetwork", interface]
                        
                        let airportPipe = Pipe()
                        airportTask.standardOutput = airportPipe
                        airportTask.launch()
                        
                        let airportData = airportPipe.fileHandleForReading.readDataToEndOfFile()
                        let airportOutput = String(data: airportData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        airportTask.waitUntilExit()
                        
                        if !airportOutput.isEmpty && 
                           !airportOutput.contains("You are not associated") &&
                           !airportOutput.contains("Error") {
                            if let range = airportOutput.range(of: "Current Wi-Fi Network: ") {
                                ssid = String(airportOutput[range.upperBound...])
                                print("Detected SSID via networksetup (\(interface)): \(ssid)")
                                self.processSSIDForDNSConfig(ssid: ssid)
                                return
                            }
                        }
                    }
                    currentInterface = nil // Reset for next iteration
                }
            }
            
            // Method 3: Try airport utility (deprecated but might work)
            let airportPath = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
            if FileManager.default.fileExists(atPath: airportPath) {
                let airportTask = Process()
                airportTask.launchPath = airportPath
                airportTask.arguments = ["-I"]
                
                let airportPipe = Pipe()
                airportTask.standardOutput = airportPipe
                airportTask.launch()
                
                let airportData = airportPipe.fileHandleForReading.readDataToEndOfFile()
                let airportOutput = String(data: airportData, encoding: .utf8) ?? ""
                airportTask.waitUntilExit()
                
                // Parse airport output for SSID
                for line in airportOutput.components(separatedBy: .newlines) {
                    if line.contains("SSID: ") {
                        let components = line.components(separatedBy: "SSID: ")
                        if components.count > 1 {
                            ssid = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                            if !ssid.isEmpty {
                                print("Detected SSID via airport utility: \(ssid)")
                                self.processSSIDForDNSConfig(ssid: ssid)
                                return
                            }
                        }
                    }
                }
            }
            
            // Method 4: Fallback to original shell command
            let task = Process()
            task.launchPath = "/bin/zsh"
            task.arguments = ["-c", "for i in ${(o)$(ifconfig -lX \"en[0-9]\")};do ipconfig getsummary ${i} | awk '/ SSID/ {print $NF}';done 2> /dev/null"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.launch()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            task.waitUntilExit()
            
            if !output.isEmpty && output != "<redacted>" {
                ssid = output
                print("Detected SSID via shell command fallback: \(ssid)")
            } else {
                print("All SSID detection methods failed. Output: \(output.isEmpty ? "empty" : output)")
                if output == "<redacted>" {
                    ssid = "Privacy restricted"
                } else {
                    // Check if we have an active network connection but can't get SSID
                    Task { @MainActor in
                        if self.data.localIP != nil && self.data.localIP != "N/A" && !self.data.localIP!.isEmpty {
                            ssid = "Connected (SSID unavailable)"
                        }
                    }
                }
            }
            
            self.processSSIDForDNSConfig(ssid: ssid)
        }
    }
    
    nonisolated private func processSSIDForDNSConfig(ssid: String) {
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
                            if self.updateDNSSettings(dnsServers: servers) {
                                print("Successfully applied DNS configuration for \(ssid)")
                                
                                await MainActor.run {
                                    self.sendNotification(
                                        title: "Wi-Fi DNS Changed",
                                        body: "Connected to \(ssid) with DNS: \(servers)"
                                    )
                                    
                                    self.lastAppliedDNSConfig.ssid = ssid
                                    self.lastAppliedDNSConfig.servers = servers
                                }
                            } else {
                                print("Failed to apply DNS configuration for \(ssid)")
                            }
                        }
                    } else {
                        print("DNS configuration already applied for \(ssid)")
                    }
                } else {
                    print("No custom DNS configuration for \(ssid)")
                    self.data.dnsConfiguration = DNSConfig(ssid: ssid, configured: false)
                    self.lastAppliedDNSConfig.ssid = nil
                    self.lastAppliedDNSConfig.servers = nil
                }
            } else {
                print("Not connected to any Wi-Fi network")
                self.data.dnsConfiguration = nil
                self.lastAppliedDNSConfig.ssid = nil
                self.lastAppliedDNSConfig.servers = nil
            }
        }
    }
    
    nonisolated func getVPNConnections() {
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Enhanced VPN detection script
            let task = Process()
            task.launchPath = "/bin/sh"
            task.arguments = ["-c", """
                # Detect VPN interfaces and gather detailed information
                for iface in $(ifconfig -l | tr ' ' '\n' | grep -E '^(utun|tun|tap|ppp|ipsec)[0-9]*$'); do
                    # Get interface details
                    ifconfig_output=$(ifconfig "$iface" 2>/dev/null)
                    if [ $? -eq 0 ]; then
                        # Extract IP address
                        ip=$(echo "$ifconfig_output" | awk '/inet / && !/127\\.0\\.0\\.1/ {print $2; exit}')
                        if [ -n "$ip" ]; then
                            # Get interface flags and status
                            flags=$(echo "$ifconfig_output" | head -1 | sed 's/.*flags=[0-9]*<\\\\([^>]*\\\\)>.*/\\\\1/')
                            mtu=$(echo "$ifconfig_output" | head -1 | sed 's/.*mtu \\\\([0-9]*\\\\).*/\\\\1/')
                            
                            # Get statistics if available
                            stats=$(echo "$ifconfig_output" | grep -E "(input|output)" | head -2)
                            
                            # Determine VPN type based on interface name
                            case "$iface" in
                                utun*) vpn_type="IPSec/IKEv2" ;;
                                tun*) vpn_type="OpenVPN/Tunnel" ;;
                                tap*) vpn_type="TAP Bridge" ;;
                                ppp*) vpn_type="PPP/L2TP" ;;
                                ipsec*) vpn_type="IPSec" ;;
                                *) vpn_type="Unknown" ;;
                            esac
                            
                            # Check if interface is active
                            if echo "$flags" | grep -q "UP.*RUNNING"; then
                                status="Connected"
                            else
                                status="Inactive"
                            fi
                            
                            echo "INTERFACE:$iface|IP:$ip|TYPE:$vpn_type|STATUS:$status|FLAGS:$flags|MTU:$mtu"
                            
                            # Add statistics if available
                            if [ -n "$stats" ]; then
                                rx_bytes=$(echo "$stats" | grep input | sed -n 's/.*input.*\\\\([0-9]\\\\+ bytes\\\\).*/\\\\1/p' | head -1)
                                tx_bytes=$(echo "$stats" | grep output | sed -n 's/.*output.*\\\\([0-9]\\\\+ bytes\\\\).*/\\\\1/p' | head -1)
                                if [ -n "$rx_bytes" ] || [ -n "$tx_bytes" ]; then
                                    echo "STATS:$iface|RX:${rx_bytes:-0 bytes}|TX:${tx_bytes:-0 bytes}"
                                fi
                            fi
                        fi
                    fi
                done
                
                # Also check for common VPN processes
                echo "--- PROCESSES ---"
                ps aux | grep -E '(openvpn|wireguard|strongswan|racoon|cisco|tunnelblick)' | grep -v grep | while read line; do
                    proc=$(echo "$line" | awk '{print $11}' | sed 's|.*/||')
                    pid=$(echo "$line" | awk '{print $2}')
                    echo "PROCESS:$proc|PID:$pid"
                done
            """]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            task.launch()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            
            var vpnConnections: [VPNConnection] = []
            var vpnProcesses: [String] = []
            
            let lines = output.components(separatedBy: CharacterSet.newlines)
            var currentInterface: String?
            var interfaceStats: [String: String] = [:]
            
            for line in lines {
                guard !line.isEmpty else { continue }
                
                if line == "--- PROCESSES ---" {
                    // Switch to process parsing mode
                    continue
                } else if line.hasPrefix("INTERFACE:") {
                    // Parse interface information
                    let components = line.components(separatedBy: "|")
                    var interfaceInfo: [String: String] = [:]
                    
                    for component in components {
                        let parts = component.components(separatedBy: ":")
                        if parts.count >= 2 {
                            let key = parts[0]
                            let value = parts[1...].joined(separator: ":")
                            interfaceInfo[key] = value
                        }
                    }
                    
                    if let interface = interfaceInfo["INTERFACE"],
                       let ip = interfaceInfo["IP"] {
                        let vpnType = interfaceInfo["TYPE"] ?? "Unknown"
                        let status = interfaceInfo["STATUS"] ?? "Unknown"
                        
                        let vpnConnection = VPNConnection(
                            interfaceName: interface,
                            ip: ip,
                            vpnType: vpnType,
                            status: status
                        )
                        
                        vpnConnections.append(vpnConnection)
                        currentInterface = interface
                    }
                } else if line.hasPrefix("STATS:") && currentInterface != nil {
                    // Parse statistics for the current interface
                    let components = line.components(separatedBy: "|")
                    for component in components {
                        let parts = component.components(separatedBy: ":")
                        if parts.count >= 2 {
                            interfaceStats[parts[0]] = parts[1...].joined(separator: ":")
                        }
                    }
                    
                    // Update the last VPN connection with stats
                    if let lastVPN = vpnConnections.last {
                        lastVPN.bytesReceived = interfaceStats["RX"]
                        lastVPN.bytesSent = interfaceStats["TX"]
                    }
                    
                    currentInterface = nil
                    interfaceStats.removeAll()
                } else if line.hasPrefix("PROCESS:") {
                    // Parse VPN process information
                    let components = line.components(separatedBy: "|")
                    var processInfo: [String: String] = [:]
                    
                    for component in components {
                        let parts = component.components(separatedBy: ":")
                        if parts.count >= 2 {
                            processInfo[parts[0]] = parts[1...].joined(separator: ":")
                        }
                    }
                    
                    if let process = processInfo["PROCESS"],
                       let pid = processInfo["PID"] {
                        vpnProcesses.append("\(process) (PID: \(pid))")
                    }
                }
            }
            
            // Also try to get active VPN services from scutil
            let scutilTask = Process()
            scutilTask.launchPath = "/usr/sbin/scutil"
            scutilTask.arguments = ["--nc", "list"]
            
            let scutilPipe = Pipe()
            scutilTask.standardOutput = scutilPipe
            scutilTask.launch()
            
            let scutilData = scutilPipe.fileHandleForReading.readDataToEndOfFile()
            let scutilOutput = String(data: scutilData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            scutilTask.waitUntilExit()
            
            // Parse scutil output for VPN services
            for line in scutilOutput.components(separatedBy: .newlines) {
                if line.contains("Connected") || line.contains("Connecting") {
                    // Extract VPN service name and status
                    let components = line.components(separatedBy: "\"")
                    if components.count >= 2 {
                        let serviceName = components[1]
                        let status = line.contains("Connected") ? "Connected" : "Connecting"
                        
                        // Check if we already have this VPN in our interface list
                        let existingVPN = vpnConnections.first { $0.serverName == serviceName }
                        if existingVPN == nil {
                            // Create a new VPN entry for service-based VPNs
                            let serviceVPN = VPNConnection(
                                interfaceName: "Service",
                                ip: "N/A",
                                vpnType: "System VPN",
                                status: status
                            )
                            serviceVPN.serverName = serviceName
                            vpnConnections.append(serviceVPN)
                        } else {
                            // Update existing VPN with service name
                            existingVPN?.serverName = serviceName
                        }
                    }
                }
            }
            
            print("Detected \(vpnConnections.count) VPN connections")
            if !vpnProcesses.isEmpty {
                print("VPN Processes: \(vpnProcesses.joined(separator: ", "))")
            }
            
            DispatchQueue.main.async {
                self.data.vpnConnections = vpnConnections
            }
            
            task.waitUntilExit()
        }
    }
}