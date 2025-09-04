import Foundation

// MARK: - Service Monitoring Extension
extension NetworkInfoManager {
    nonisolated func monitorServices() {
        let services = [
            "unbound": "org.cronokirby.unbound",
            "kresd": "org.knot-resolver.kresd"
        ]
        
        for (service, label) in services {
            getServiceInfo(service: service, label: label)
        }
    }
    
    nonisolated func getServiceInfo(service: String, label: String) {
        Task {
            do {
                let output = try await ProcessService.execute(command: "/bin/launchctl", arguments: ["print", "system/\(label)"])
                
                await MainActor.run {
                if output.contains("could not find service") {
                    Logger.info("\(service): Service not found", category: "Service")
                    self.serviceStates[service]?.running = false
                    self.serviceStates[service]?.pid = nil // Using nil directly for NSNumber
                } else {
                    // Check if running using the same regex pattern as the Lua code
                    let isRunning = output.contains("state = running")
                    self.serviceStates[service]?.running = isRunning
                    
                    // Extract PID using a regex
                    if isRunning, let pidRange = output.range(of: "pid = [0-9]+", options: .regularExpression),
                       let pidValueRange = output[pidRange].range(of: "[0-9]+", options: .regularExpression),
                       let pid = Int(output[pidValueRange]) {
                        self.serviceStates[service]?.pid = NSNumber(value: pid) // Using NSNumber instead of Int
                        Logger.info("\(service): Running with PID \(pid)", category: "Service")
                    } else {
                        self.serviceStates[service]?.pid = nil
                        Logger.info("\(service): \(isRunning ? "Running" : "Not running"), but no PID found", category: "Service")
                    }
                }
                
                // Now check if the service is responding by sending a DNS query
                self.checkServiceResponse(service: service)
                }
            } catch {
                Logger.error("Failed to get service info for \(service): \(error.localizedDescription)", category: "Service")
                await MainActor.run {
                    self.serviceStates[service]?.running = false
                    self.serviceStates[service]?.pid = nil
                }
            }
        }
    }
    
    nonisolated func checkServiceResponse(service: String) {
        Task { @MainActor in
            guard let isRunning = self.serviceStates[service]?.running,
                  isRunning else {
                // If service is not running, it can't be responding
                self.serviceStates[service]?.responding = false
                return
            }
            
            // Continue with the port checking logic
            Task.detached { [weak self] in
                guard let self = self else { return }
                
                // Get service port configuration
                let port = NetworkInfoConfiguration.servicePorts[service] ?? "53"
                let server = "127.0.0.1"
                
                do {
                    let output = try await ProcessService.execute(
                        command: "/usr/bin/dig",
                        arguments: ["@\(server)", "-p", port, "example.com", "+short", "+time=2"],
                        timeout: 3.0
                    )
            
                    // Use the same IP address pattern detection as the Lua code
                    let ipAddressPattern = "\\d+\\.\\d+\\.\\d+\\.\\d+"
                    let responding = (output.range(of: ipAddressPattern, options: .regularExpression) != nil)
                    
                    Logger.info("\(service) DNS test on port \(port): \(responding ? "Responding" : "Not responding")", category: "Service")
                    if !output.isEmpty {
                        Logger.debug("DNS test output: \(output)", category: "Service")
                    }
                    
                    await MainActor.run {
                        let prevState = self.serviceStates[service]?.responding ?? false
                        self.serviceStates[service]?.responding = responding
                        
                        // Send notification for state changes
                        if prevState != responding {
                            let pidValue = self.serviceStates[service]?.pid?.intValue
                            let pid = pidValue != nil ? String(pidValue!) : "N/A"
                            
                            let status = "\(service): Running (PID: \(pid)) - \(responding ? "Responding" : "Not Responding")"
                            
                            self.logNotification(
                                title: "DNS Service Status Change",
                                body: status
                            )
                        }
                    }
                } catch {
                    Logger.error("Service response check failed for \(service): \(error.localizedDescription)", category: "Service")
                    await MainActor.run {
                        self.serviceStates[service]?.responding = false
                    }
                }
            }
        }
    }
}