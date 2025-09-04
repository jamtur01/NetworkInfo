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
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Exactly match the process from the Lua code
            let task = Process()
            task.launchPath = "/bin/launchctl"
            task.arguments = ["print", "system/\(label)"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            task.launch()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            
            // Process output on main thread to update UI
            DispatchQueue.main.async {
                if output.contains("could not find service") {
                    print("\(service): Service not found")
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
                        print("\(service): Running with PID \(pid)")
                    } else {
                        self.serviceStates[service]?.pid = nil
                        print("\(service): \(isRunning ? "Running" : "Not running"), but no PID found")
                    }
                }
                
                // Now check if the service is responding by sending a DNS query
                self.checkServiceResponse(service: service)
            }
            
            task.waitUntilExit()
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
            
            // Continue with the port checking logic on the background queue
            Task.detached { [weak self] in
                guard let self = self else { return }
                
                // Different services listen on different ports
                // unbound typically uses port 53
                // kresd typically uses port 53053 or sometimes 5353
            let server = "127.0.0.1"
            let port: String
            
            switch service {
            case "unbound":
                port = "53"
            case "kresd":
                // kresd is configured to listen on port 8053 according to kresd.conf
                port = "8053"
            default:
                port = "53"
            }
            
            let task = Process()
            task.launchPath = "/usr/bin/dig"
            task.arguments = ["@\(server)", "-p", port, "example.com", "+short", "+time=2"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe() // Capture stderr to prevent console error messages
            
            task.launch()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            
            // Use the same IP address pattern detection as the Lua code
            let ipAddressPattern = "\\d+\\.\\d+\\.\\d+\\.\\d+"
            let responding = (output.range(of: ipAddressPattern, options: .regularExpression) != nil)
            
            print("\(service) DNS test on port \(port): \(responding ? "Responding" : "Not responding")")
            if !output.isEmpty {
                print("Output: \(output)")
            }
            
                await MainActor.run {
                    let prevState = self.serviceStates[service]?.responding ?? false
                    self.serviceStates[service]?.responding = responding
                    
                    // Send notification for state changes
                    if prevState != responding {
                        let pidValue = self.serviceStates[service]?.pid?.intValue
                        let pid = pidValue != nil ? String(pidValue!) : "N/A"
                        
                        let status = "\(service): Running (PID: \(pid)) - \(responding ? "Responding" : "Not Responding")"
                        
                        self.sendNotification(
                            title: "DNS Service Status Change",
                            body: status
                        )
                    }
                }
                
                task.waitUntilExit()
            }
        }
    }
}