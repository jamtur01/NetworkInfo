import Foundation
import Network
import AppKit
import UserNotifications

class NetworkInfoManager {
    // Constants
    private let GEOIP_SERVICE_URL = "https://ipapi.co/json"
    private let REFRESH_INTERVAL: TimeInterval = 120 // seconds
    private let SERVICE_CHECK_INTERVAL: TimeInterval = 60 // seconds
    private let EXPECTED_DNS = "127.0.0.1"
    private let TEST_DOMAINS = ["example.com", "google.com", "cloudflare.com"]
    
    // File paths
    private let dnsConfigPath: String
    
    // State variables
    private var serviceStates: [String: ServiceState] = [
        "unbound": ServiceState(),
        "kresd": ServiceState()
    ]
    
    private var data = NetworkData()
    private var lastAppliedDNSConfig = DNSConfig()
    
    // Timers
    private var refreshTimer: Timer?
    private var serviceTimer: Timer?
    
    // Watchers
    private var configWatcher: DispatchSourceFileSystemObject?
    private var networkMonitor: NWPathMonitor?
    
    // Dispatch queues
    private var networkMonitorQueue = DispatchQueue(label: "com.jamtur01.NetworkInfo.networkMonitor")
    private var backgroundQueue = DispatchQueue(label: "com.jamtur01.NetworkInfo.background", qos: .utility, attributes: .concurrent)
    
    init() {
        // Mimic the original spoon location for DNS configuration
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let preferredPath = homeDir.appendingPathComponent(".config/hammerspoon/dns.conf").path
        
        // Check if the config file exists in the original location
        if FileManager.default.fileExists(atPath: preferredPath) {
            dnsConfigPath = preferredPath
            print("Using existing DNS config at: \(dnsConfigPath)")
        } else {
            // Fall back to application support directory
            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDirectory = applicationSupport.appendingPathComponent("NetworkInfo")
            
            // Create the directory if it doesn't exist
            try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            dnsConfigPath = appDirectory.appendingPathComponent("dns.conf").path
            
            // Create a default config file if it doesn't exist
            if !FileManager.default.fileExists(atPath: dnsConfigPath) {
                try? "# DNS Configuration\n# Format: SSID = DNS_Server1 DNS_Server2 ...\n".write(toFile: dnsConfigPath, atomically: true, encoding: .utf8)
                print("Created new DNS config at: \(dnsConfigPath)")
            } else {
                print("Using existing DNS config at: \(dnsConfigPath)")
            }
        }
    }
    
    func start() {
        // Run an immediate refresh to populate data
        refreshData()
        
        // Run immediate service and DNS checks
        monitorServices()
        testDNSResolution()
        
        // Set up periodic refresh
        refreshTimer = Timer.scheduledTimer(withTimeInterval: REFRESH_INTERVAL, repeats: true) { [weak self] _ in
            self?.refreshData()
        }
        
        // Set up service monitoring
        serviceTimer = Timer.scheduledTimer(withTimeInterval: SERVICE_CHECK_INTERVAL, repeats: true) { [weak self] _ in
            self?.monitorServices()
        }
        
        // Set up network monitor
        setupNetworkMonitor()
        
        // Set up config file watcher
        watchConfigFile()
    }
    
    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        
        serviceTimer?.invalidate()
        serviceTimer = nil
        
        networkMonitor?.cancel()
        networkMonitor = nil
        
        configWatcher?.cancel()
        configWatcher = nil
    }
    
    func refreshData() {
        // Preserve DNS configuration
        let dnsConfiguration = data.dnsConfiguration
        
        // Reset data
        data = NetworkData()
        data.dnsConfiguration = dnsConfiguration
        
        // Fetch all data asynchronously
        backgroundQueue.async { [weak self] in
            self?.getGeoIPData()
        }
        
        backgroundQueue.async { [weak self] in
            self?.getLocalIPAddress()
        }
        
        backgroundQueue.async { [weak self] in
            self?.getCurrentSSID()
        }
        
        backgroundQueue.async { [weak self] in
            self?.getVPNConnections()
        }
        
        backgroundQueue.async { [weak self] in
            self?.getDNSInfo()
        }
        
        backgroundQueue.async { [weak self] in
            self?.testDNSResolution()
        }
        
        backgroundQueue.async { [weak self] in
            self?.monitorServices()
        }
    }
    
    // Helper function to send notifications
    private func sendNotification(title: String, body: String) {
        print("📣 \(title): \(body)")
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error)")
            }
        }
    }
    
    // Async data fetching functions
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
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
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
            
            do {
                task.launch()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
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
            } catch {
                print("Error getting SSID: \(error)")
                DispatchQueue.main.async {
                    self.data.ssid = "Error"
                    self.data.dnsConfiguration = nil
                }
            }
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
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            var vpnConnections: [VPNConnection] = []
            
            output.components(separatedBy: .newlines).forEach { line in
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
    
    func getDNSInfo() {
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Use the exact same shell command as the original spoon
            let task = Process()
            task.launchPath = "/bin/sh"
            task.arguments = ["-c", "scutil --dns | grep 'nameserver\\[[0-9]*\\]' | awk '{print $3}'"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            task.launch()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            var dnsInfo: [String] = []
            var uniqueDNS: Set<String> = []
            
            // Process each line, preserving order but eliminating duplicates like the Lua code
            for line in output.components(separatedBy: .newlines) {
                let dns = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !dns.isEmpty && !uniqueDNS.contains(dns) {
                    uniqueDNS.insert(dns)
                    dnsInfo.append(dns)
                }
            }
            
            print("DNS Servers: \(dnsInfo.joined(separator: ", "))")
            
            DispatchQueue.main.async {
                self.data.dnsInfo = dnsInfo
            }
            
            task.waitUntilExit()
        }
    }
    
    func testDNSResolution() {
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            var results: [String: DNSTestResult] = [:]
            let group = DispatchGroup()
            
            for domain in self.TEST_DOMAINS {
                group.enter()
                
                // Use the exact same command format as the original spoon
                let task = Process()
                task.launchPath = "/usr/bin/dig"
                task.arguments = ["@127.0.0.1", domain, "+short", "+time=2"]
                
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = Pipe() // Capture stderr to avoid console output
                
                do {
                    task.launch()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    
                    // Check for valid IP address in the response, just like the Lua code
                    let ipAddressPattern = "\\d+\\.\\d+\\.\\d+\\.\\d+"
                    let success = (output.range(of: ipAddressPattern, options: .regularExpression) != nil)
                    
                    print("DNS test for \(domain): \(success ? "Success" : "Failed")")
                    
                    results[domain] = DNSTestResult(success: success, response: output)
                    
                    task.waitUntilExit()
                } catch {
                    print("Error running DNS test for \(domain): \(error)")
                    results[domain] = DNSTestResult(success: false, response: "Error: \(error.localizedDescription)")
                }
                
                group.leave()
            }
            
            group.notify(queue: .main) { [weak self] in
                guard let self = self else { return }
                
                let successes = results.values.filter { $0.success }.count
                self.data.dnsTest = DNSTest(
                    working: successes > 0,
                    successRate: Double(successes) / Double(self.TEST_DOMAINS.count) * 100.0,
                    details: results
                )
                
                print("DNS Resolution Test: \(successes)/\(self.TEST_DOMAINS.count) success (\(self.data.dnsTest!.successRate)%)")
            }
        }
    }
    
    func monitorServices() {
        let services = [
            "unbound": "org.cronokirby.unbound",
            "kresd": "org.knot-resolver.kresd"
        ]
        
        for (service, label) in services {
            getServiceInfo(service: service, label: label)
        }
    }
    
    func getServiceInfo(service: String, label: String) {
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
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            // Process output on main thread to update UI
            DispatchQueue.main.async {
                if output.contains("could not find service") {
                    print("\(service): Service not found")
                    self.serviceStates[service]?.running = false
                    self.serviceStates[service]?.pid = nil
                } else {
                    // Check if running using the same regex pattern as the Lua code
                    let isRunning = output.contains("state = running")
                    self.serviceStates[service]?.running = isRunning
                    
                    // Extract PID using a regex
                    if isRunning, let pidRange = output.range(of: "pid = [0-9]+", options: .regularExpression),
                       let pidValueRange = output[pidRange].range(of: "[0-9]+", options: .regularExpression),
                       let pid = Int(output[pidValueRange]) {
                        self.serviceStates[service]?.pid = pid
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
    
    func checkServiceResponse(service: String) {
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Get service information from state
            guard let isRunning = self.serviceStates[service]?.running,
                  isRunning else {
                // If service is not running, it can't be responding
                DispatchQueue.main.async {
                    self.serviceStates[service]?.responding = false
                }
                return
            }
            
            // For kresd specifically, we'll use a more direct method since it's special
            if service == "kresd" {
                // First check if process is running with ps
                let psTask = Process()
                psTask.launchPath = "/bin/sh"
                psTask.arguments = ["-c", "ps -p 42028 -o comm="]
                
                let psPipe = Pipe()
                psTask.standardOutput = psPipe
                
                psTask.launch()
                psTask.waitUntilExit()
                
                let psData = psPipe.fileHandleForReading.readDataToEndOfFile()
                let psOutput = String(data: psData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                print("Process check for kresd (PID 42028): \(psOutput)")
                
                // If process exists and is running, we'll consider it responding
                let isResponding = !psOutput.isEmpty
                
                DispatchQueue.main.async {
                    self.serviceStates[service]?.responding = isResponding
                }
                
                print("Setting kresd responding status to: \(isResponding)")
                return
            }
            
            // For unbound, use the regular DNS check
            let server = "127.0.0.1"
            let port = "53"  // unbound is always on port 53
            
            let task = Process()
            task.launchPath = "/usr/bin/dig"
            task.arguments = ["@\(server)", "-p", port, "example.com", "+short", "+time=2"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe() // Capture stderr to prevent console error messages
            
            task.launch()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            // Use the same IP address pattern detection as the Lua code
            let ipAddressPattern = "\\d+\\.\\d+\\.\\d+\\.\\d+"
            let responding = (output.range(of: ipAddressPattern, options: .regularExpression) != nil)
            
            print("\(service) DNS test on port \(port): \(responding ? "Responding" : "Not responding")")
            print("Output: \(output)")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let prevState = self.serviceStates[service]?.responding ?? false
                self.serviceStates[service]?.responding = responding
                
                // Send notification for state changes
                if prevState != responding {
                    let pid = self.serviceStates[service]?.pid.map { String($0) } ?? "N/A"
                    
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
    
    func readDNSConfig(ssid: String) -> (String?, Bool) {
        guard !ssid.isEmpty else { return (nil, false) }
        
        do {
            let fileContent = try String(contentsOfFile: dnsConfigPath, encoding: .utf8)
            for line in fileContent.components(separatedBy: .newlines) {
                // Skip empty lines and comments
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                    continue
                }
                
                // Check for SSID = DNS servers format (exact matching from the Lua code)
                guard let range = trimmedLine.range(of: "=") else { continue }
                
                let configSSID = trimmedLine[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                let dnsServers = trimmedLine[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                
                if configSSID == ssid && !dnsServers.isEmpty {
                    print("Found DNS configuration for SSID '\(ssid)': \(dnsServers)")
                    return (dnsServers, true)
                }
            }
            print("No DNS configuration found for SSID: \(ssid)")
        } catch {
            print("Error reading DNS config: \(error)")
        }
        
        return (nil, false)
    }
    
    func updateDNSSettings(dnsServers: String) -> Bool {
        // Validate that we have DNS servers
        guard !dnsServers.isEmpty else { 
            print("No DNS servers specified")
            return false 
        }
        
        // Split DNS servers into an array
        let dnsArray = dnsServers.split(separator: " ").map { String($0) }
        guard !dnsArray.isEmpty else {
            print("No valid DNS servers found in: \(dnsServers)")
            return false
        }
        
        // Match the exact command from the Lua code
        let cmd = "/usr/sbin/networksetup -setdnsservers Wi-Fi \(dnsArray.joined(separator: " "))"
        print("Executing: \(cmd)")
        
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", cmd]
        
        task.launch()
        task.waitUntilExit()
        
        let success = task.terminationStatus == 0
        if success {
            print("DNS update successful: \(dnsServers)")
        } else {
            print("Failed to update DNS: exit code \(task.terminationStatus)")
        }
        
        return success
    }
    
    func setupNetworkMonitor() {
        networkMonitor = NWPathMonitor()
        
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                print("Network configuration changed")
                self?.getCurrentSSID()
            }
        }
        
        networkMonitor?.start(queue: networkMonitorQueue)
    }
    
    func watchConfigFile() {
        // Stop any existing watcher
        configWatcher?.cancel()
        
        // Set up file watcher
        let fileDescriptor = open(dnsConfigPath, O_EVTONLY)
        if fileDescriptor < 0 {
            print("Error watching config file")
            return
        }
        
        configWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.main
        )
        
        configWatcher?.setEventHandler { [weak self] in
            print("dns.conf has changed. Reloading DNS configuration.")
            self?.getCurrentSSID()
        }
        
        configWatcher?.setCancelHandler {
            close(fileDescriptor)
        }
        
        configWatcher?.resume()
    }
    
    // Menu building
    func buildMenu(menu: NSMenu) {
        // Public IP
        let publicIP = data.geoIPData?.query ?? "N/A"
        let publicIPItem = NSMenuItem(title: "🌍 Public IP: \(publicIP)", action: #selector(AppDelegate.copyToClipboard(_:)), keyEquivalent: "")
        publicIPItem.representedObject = publicIP
        menu.addItem(publicIPItem)
        
        // Local IP
        let localIP = data.localIP ?? "N/A"
        let localIPItem = NSMenuItem(title: "💻 Local IP: \(localIP)", action: #selector(AppDelegate.copyToClipboard(_:)), keyEquivalent: "")
        localIPItem.representedObject = localIP
        menu.addItem(localIPItem)
        
        // SSID with DNS Configuration
        let ssid = data.ssid ?? "Not connected"
        let ssidItem = NSMenuItem(title: "📶 SSID: \(ssid)", action: #selector(AppDelegate.copyToClipboard(_:)), keyEquivalent: "")
        ssidItem.representedObject = ssid
        menu.addItem(ssidItem)
        
        if let dnsConfig = data.dnsConfiguration {
            if dnsConfig.configured, let servers = dnsConfig.servers {
                let dnsConfigItem = NSMenuItem(title: "  ✅ DNS Config: \(servers)", action: #selector(AppDelegate.copyToClipboard(_:)), keyEquivalent: "")
                dnsConfigItem.representedObject = servers
                dnsConfigItem.indentationLevel = 1
                menu.addItem(dnsConfigItem)
            } else {
                let noDNSConfigItem = NSMenuItem(title: "  ⚠️ No Custom DNS Config", action: nil, keyEquivalent: "")
                noDNSConfigItem.isEnabled = false
                noDNSConfigItem.indentationLevel = 1
                menu.addItem(noDNSConfigItem)
            }
        }
        
        // DNS Information
        if let dnsInfo = data.dnsInfo, !dnsInfo.isEmpty {
            menu.addItem(NSMenuItem.separator())
            
            var expectedDNS: Set<String> = Set([EXPECTED_DNS])
            if let dnsConfig = data.dnsConfiguration, dnsConfig.configured, let servers = dnsConfig.servers {
                expectedDNS = Set(servers.split(separator: " ").map { String($0) })
            }
            
            let dnsHeader = NSMenuItem(title: "🔒 Current DNS Servers:", action: nil, keyEquivalent: "")
            dnsHeader.isEnabled = false
            menu.addItem(dnsHeader)
            
            for dns in dnsInfo {
                let icon = expectedDNS.contains(dns) ? "✅" : "⚠️"
                let dnsItem = NSMenuItem(title: "  \(icon) \(dns)", action: #selector(AppDelegate.copyToClipboard(_:)), keyEquivalent: "")
                dnsItem.representedObject = dns
                dnsItem.indentationLevel = 1
                menu.addItem(dnsItem)
            }
        }
        
        // VPN Connections
        if let vpnConnections = data.vpnConnections, !vpnConnections.isEmpty {
            menu.addItem(NSMenuItem.separator())
            
            let vpnHeader = NSMenuItem(title: "🔐 VPN Connections:", action: nil, keyEquivalent: "")
            vpnHeader.isEnabled = false
            menu.addItem(vpnHeader)
            
            for vpn in vpnConnections {
                let vpnItem = NSMenuItem(title: "  • \(vpn.name): \(vpn.ip)", action: #selector(AppDelegate.copyToClipboard(_:)), keyEquivalent: "")
                vpnItem.representedObject = "\(vpn.name): \(vpn.ip)"
                vpnItem.indentationLevel = 1
                menu.addItem(vpnItem)
            }
        }
        
        // Service Status
        menu.addItem(NSMenuItem.separator())
        
        let serviceHeader = NSMenuItem(title: "🔄 Service Status:", action: nil, keyEquivalent: "")
        serviceHeader.isEnabled = false
        menu.addItem(serviceHeader)
        
        for (service, state) in serviceStates {
            let runningStatus = state.running ? "Running" : "Stopped"
            let pidInfo = state.pid.map { " (PID: \($0))" } ?? " (PID: N/A)"
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
        
        // ISP and Location
        if let geoIPData = data.geoIPData {
            menu.addItem(NSMenuItem.separator())
            
            // ISP
            let ispValue = geoIPData.isp != "N/A" ? geoIPData.isp : "Unknown"
            let ispItem = NSMenuItem(title: "📇 ISP: \(ispValue)", action: #selector(AppDelegate.copyToClipboard(_:)), keyEquivalent: "")
            ispItem.representedObject = ispValue
            menu.addItem(ispItem)
            
            // Location
            let locationText = "\(geoIPData.country) (\(geoIPData.countryCode))"
            let locationItem = NSMenuItem(title: "📍 Location: \(locationText)", action: #selector(AppDelegate.copyToClipboard(_:)), keyEquivalent: "")
            locationItem.representedObject = locationText
            menu.addItem(locationItem)
        }
        
        // Refresh Option
        menu.addItem(NSMenuItem.separator())
        let refreshItem = NSMenuItem(title: "🔄 Refresh", action: #selector(AppDelegate.refreshData(_:)), keyEquivalent: "")
        menu.addItem(refreshItem)
        
        // Quit Option
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "🚪 Quit", action: #selector(AppDelegate.quitApp(_:)), keyEquivalent: "")
        menu.addItem(quitItem)
    }
}
