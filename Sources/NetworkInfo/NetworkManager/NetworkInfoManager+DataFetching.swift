import Foundation

// MARK: - Data Fetching Extension
extension NetworkInfoManager {
    func getGeoIPData() {
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
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
                var fetchedData: GeoIPData?
                
                URLSession.shared.dataTask(with: url) { data, response, error in
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
                        
                        if apiUrl.contains("ipapi.co") {
                            // ipapi.co format
                            let geoData = GeoIPData(
                                query: json?["ip"] as? String ?? "N/A",
                                isp: json?["org"] as? String ?? "N/A",
                                country: json?["country_name"] as? String ?? "N/A",
                                countryCode: json?["country_code"] as? String ?? "N/A"
                            )
                            fetchedData = geoData
                        } else if apiUrl.contains("ip-api.com") {
                            // ip-api.com format
                            let geoData = GeoIPData(
                                query: json?["query"] as? String ?? "N/A",
                                isp: json?["isp"] as? String ?? "N/A",
                                country: json?["country"] as? String ?? "N/A",
                                countryCode: json?["countryCode"] as? String ?? "N/A"
                            )
                            fetchedData = geoData
                        } else if apiUrl.contains("ipinfo.io") {
                            // ipinfo.io format
                            let geoData = GeoIPData(
                                query: json?["ip"] as? String ?? "N/A",
                                isp: json?["org"] as? String ?? "N/A",
                                country: json?["country"] as? String ?? "N/A",
                                countryCode: json?["country"] as? String ?? "N/A"
                            )
                            fetchedData = geoData
                        }
                        
                        print("Successfully retrieved GeoIP data from \(apiUrl)")
                    } catch {
                        print("Error parsing GeoIP data from \(apiUrl): \(error.localizedDescription)")
                    }
                }.resume()
                
                // Wait for the request to complete with a timeout
                _ = semaphore.wait(timeout: .now() + 5)
                
                if let data = fetchedData, data.query != "N/A" {
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
    
    func getLocalIPAddress() {
        backgroundQueue.async { [weak self] in
            let task = Process()
            task.launchPath = "/bin/sh"
            task.arguments = ["-c", "ipconfig getifaddr en0"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            task.launch()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            
            DispatchQueue.main.async {
                self?.data.localIP = output.isEmpty ? "N/A" : output
            }
            
            task.waitUntilExit()
        }
    }
    
    func getCurrentSSID() {
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Using the exact same command from the original zsh code
            let task = Process()
            task.launchPath = "/bin/zsh"
            task.arguments = ["-c", "for i in ${(o)$(ifconfig -lX \"en[0-9]\")};do ipconfig getsummary ${i} | awk '/ SSID/ {print $NF}';done 2> /dev/null"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            task.launch()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            
            let ssid = output.isEmpty ? "Not connected" : output
            print("Detected SSID: \(ssid)")
            
            // Process DNS configuration in the background
            let (dnsServers, configured) = self.readDNSConfig(ssid: ssid)
            
            DispatchQueue.main.async {
                self.data.ssid = ssid
                
                // Update DNS config based on SSID
                if ssid != "Not connected" {
                    if configured, let servers = dnsServers {
                        self.data.dnsConfiguration = DNSConfig(ssid: ssid, servers: servers, configured: true)
                        
                        // Only update DNS settings if the SSID or DNS servers have changed.
                        if self.lastAppliedDNSConfig.ssid != ssid || self.lastAppliedDNSConfig.servers != servers {
                            // Update DNS in background
                            self.backgroundQueue.async {
                                if self.updateDNSSettings(dnsServers: servers) {
                                    print("Successfully applied DNS configuration for \(ssid)")
                                    
                                    DispatchQueue.main.async {
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
            
            task.waitUntilExit()
        }
    }
    
    func getVPNConnections() {
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