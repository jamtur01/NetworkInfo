import Foundation

// MARK: - DNS Configuration and Testing Extension
extension NetworkInfoManager {
    nonisolated func getDNSInfo() {
        Task {
            do {
                let output = try await ProcessService.executeScript("scutil --dns | grep 'nameserver\\[[0-9]*\\]' | awk '{print $3}'")
                
                var dnsInfo: [String] = []
                var uniqueDNS: Set<String> = []
                
                // Process each line, preserving order but eliminating duplicates
                for line in output.components(separatedBy: CharacterSet.newlines) {
                    let dns = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if !dns.isEmpty && !uniqueDNS.contains(dns) {
                        uniqueDNS.insert(dns)
                        dnsInfo.append(dns)
                    }
                }
                
                Logger.info("DNS Servers: \(dnsInfo.joined(separator: ", "))", category: "DNS")
                
                await MainActor.run {
                    self.data.dnsInfo = dnsInfo
                }
            } catch {
                Logger.error("Failed to get DNS info: \(error.localizedDescription)", category: "DNS")
                await MainActor.run {
                    self.data.dnsInfo = []
                }
            }
        }
    }
    
    nonisolated func testDNSResolution() {
        Task {
            var results: [String: DNSTestResult] = [:]
            
            // Test all domains concurrently using async/await
            await withTaskGroup(of: (String, DNSTestResult).self) { group in
                for domain in self.TEST_DOMAINS {
                    group.addTask {
                        do {
                            let output = try await ProcessService.execute(
                                command: "/usr/bin/dig",
                                arguments: ["@\(self.EXPECTED_DNS)", domain, "+short", "+time=2"],
                                timeout: 3.0
                            )
                            
                            // Check for valid IP address in the response
                            let ipAddressPattern = "\\d+\\.\\d+\\.\\d+\\.\\d+"
                            let success = (output.range(of: ipAddressPattern, options: .regularExpression) != nil)
                            
                            Logger.debug("DNS test for \(domain): \(success ? "Success" : "Failed")", category: "DNS")
                            
                            return (domain, DNSTestResult(success: success, response: output))
                        } catch {
                            Logger.error("DNS test failed for \(domain): \(error.localizedDescription)", category: "DNS")
                            return (domain, DNSTestResult(success: false, response: "Error: \(error.localizedDescription)"))
                        }
                    }
                }
                
                // Collect all results
                for await (domain, result) in group {
                    results[domain] = result
                }
            }
            
            await MainActor.run {
                let successes = results.values.filter { $0.success }.count
                self.data.dnsTest = DNSTest(
                    working: successes > 0,
                    successRate: Double(successes) / Double(self.TEST_DOMAINS.count) * 100.0,
                    details: results
                )
                
                Logger.info("DNS Resolution Test: \(successes)/\(self.TEST_DOMAINS.count) success (\(self.data.dnsTest!.successRate)%)", category: "DNS")
            }
        }
    }
    
    internal nonisolated func readDNSConfig(ssid: String) -> (String?, Bool) {
        guard !ssid.isEmpty else { return (nil, false) }
        
        do {
            let fileContent = try String(contentsOfFile: dnsConfigPath, encoding: .utf8)
            for line in fileContent.components(separatedBy: CharacterSet.newlines) {
                // Skip empty lines and comments
                let trimmedLine = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                    continue
                }
                
                // Check for SSID = DNS servers format (exact matching from the Lua code)
                guard let range = trimmedLine.range(of: "=") else { continue }
                
                let configSSID = trimmedLine[..<range.lowerBound].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                let dnsServers = trimmedLine[range.upperBound...].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                
                if configSSID == ssid {
                    Logger.info("Found DNS configuration for SSID '\(ssid)': \(dnsServers)", category: "DNS")
                    return (dnsServers, true)
                }
            }
            Logger.debug("No DNS configuration found for SSID: \(ssid)", category: "DNS")
        } catch {
            Logger.error("Error reading DNS config: \(error)", category: "DNS")
        }
        
        return (nil, false)
    }
    
    nonisolated func updateDNSSettings(dnsServers: String) async -> Bool {
        // Validate that we have DNS servers
        guard !dnsServers.isEmpty else { 
            Logger.warning("No DNS servers specified", category: "DNS")
            return false 
        }
        
        // Split DNS servers into an array
        let dnsArray = dnsServers.split(separator: " ").map { String($0) }
        guard !dnsArray.isEmpty else {
            Logger.error("No valid DNS servers found in: \(dnsServers)", category: "DNS")
            return false
        }
        
        // Match the exact command from the Lua code
        let cmd = "/usr/sbin/networksetup -setdnsservers Wi-Fi \(dnsArray.joined(separator: " "))"
        Logger.info("Executing: \(cmd)", category: "DNS")
        
        if isTestMode {
            Logger.info("Note: DNS update would have used command: \(cmd)", category: "DNS")
            Logger.info("Ignoring in test mode", category: "DNS")
            return true
        }
        
        let (success, output) = await ProcessService.executeSafely(command: "/bin/sh", arguments: ["-c", cmd])
        
        if success {
            Logger.info("DNS update successful: \(dnsServers)", category: "DNS")
        } else {
            Logger.error("Failed to update DNS: \(output)", category: "DNS")
        }
        
        return success
    }
}