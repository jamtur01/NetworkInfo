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
            let task = Process()
            task.launchPath = "/bin/sh"
            task.arguments = ["-c", """
                for iface in $(ifconfig -l | grep -o 'utun[0-9]*'); do
                    ip=$(ifconfig "$iface" | awk '/inet / {print $2}')
                    if [ -n "$ip" ]; then
                        echo "VPN Interface: $iface, IP Address: $ip"
                    fi
                done
            """]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            task.launch()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            
            var vpnConnections: [VPNConnection] = []
            
            output.components(separatedBy: CharacterSet.newlines).forEach { line in
                guard !line.isEmpty else { return }
                
                do {
                    let pattern = "VPN Interface: (\\S+), IP Address: (\\S+)"
                    let regex = try NSRegularExpression(pattern: pattern, options: [])
                    
                    if let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.count)) {
                        if let interfaceRange = Range(match.range(at: 1), in: line),
                           let ipRange = Range(match.range(at: 2), in: line) {
                            let interface = String(line[interfaceRange])
                            let ip = String(line[ipRange])
                            vpnConnections.append(VPNConnection(name: interface, ip: ip))
                        }
                    }
                } catch {
                    print("Error parsing VPN connections: \(error)")
                }
            }
            
            DispatchQueue.main.async {
                self?.data.vpnConnections = vpnConnections
            }
            
            task.waitUntilExit()
        }
    }
}