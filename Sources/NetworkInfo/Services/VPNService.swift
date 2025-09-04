import Foundation

/// Service for detecting and analyzing VPN connections
actor VPNService: VPNDetector {
    
    // MARK: - VPN Interface Types
    private static let vpnInterfacePatterns = [
        "utun": "IPSec/IKEv2",
        "tun": "OpenVPN/Tunnel", 
        "tap": "TAP Bridge",
        "ppp": "PPP/L2TP",
        "ipsec": "IPSec"
    ]
    
    // MARK: - Public Interface
    
    /// Detects all active VPN connections with detailed information
    /// - Returns: Array of VPNConnection objects with comprehensive details
    static func detectVPNConnections() async -> [VPNConnection] {
        async let interfaceConnections = detectInterfaceVPNs()
        async let systemServices = detectSystemVPNServices()
        
        let interfaces = await interfaceConnections
        let services = await systemServices
        
        // Merge interface and service data
        var mergedConnections = interfaces
        
        for service in services {
            // Check if we already have this VPN in our interface list
            if let existingVPN = mergedConnections.first(where: { $0.serverName == service.serverName }) {
                // Update existing VPN with service name
                existingVPN.serverName = service.serverName
                existingVPN.status = service.status
            } else {
                // Add new service-based VPN
                mergedConnections.append(service)
            }
        }
        
        Logger.info("Detected \(mergedConnections.count) VPN connections", category: "VPN")
        return mergedConnections
    }
    
    // MARK: - Interface Detection
    
    /// Detects VPN connections through network interfaces
    private static func detectInterfaceVPNs() async -> [VPNConnection] {
        do {
            let output = try await ProcessService.executeScript(buildVPNDetectionScript())
            return parseVPNInterfaceOutput(output)
        } catch {
            Logger.error("VPN interface detection failed: \(error.localizedDescription)", category: "VPN")
            return []
        }
    }
    
    /// Detects VPN connections through system services
    private static func detectSystemVPNServices() async -> [VPNConnection] {
        do {
            let output = try await ProcessService.execute(command: "/usr/sbin/scutil", arguments: ["--nc", "list"])
            return parseVPNServiceOutput(output)
        } catch {
            Logger.error("VPN service detection failed: \(error.localizedDescription)", category: "VPN")
            return []
        }
    }
    
    // MARK: - Private Helpers
    
    private static func buildVPNDetectionScript() -> String {
        return """
        # Detect VPN interfaces and gather detailed information
        for iface in $(ifconfig -l | tr ' ' '\\n' | grep -E '^(utun|tun|tap|ppp|ipsec)[0-9]*$'); do
            # Get interface details
            ifconfig_output=$(ifconfig "$iface" 2>/dev/null)
            if [ $? -eq 0 ]; then
                # Extract IP address
                ip=$(echo "$ifconfig_output" | awk '/inet / && !/127\\\\.0\\\\.0\\\\.1/ {print $2; exit}')
                if [ -n "$ip" ]; then
                    # Get interface flags and status
                    flags=$(echo "$ifconfig_output" | head -1 | sed 's/.*flags=[0-9]*<\\\\\\\\([^>]*\\\\\\\\)>.*/\\\\\\\\1/')
                    mtu=$(echo "$ifconfig_output" | head -1 | sed 's/.*mtu \\\\\\\\([0-9]*\\\\\\\\).*/\\\\\\\\1/')
                    
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
                        rx_bytes=$(echo "$stats" | grep input | sed -n 's/.*input.*\\\\\\\\([0-9]\\\\\\\\+ bytes\\\\\\\\).*/\\\\\\\\1/p' | head -1)
                        tx_bytes=$(echo "$stats" | grep output | sed -n 's/.*output.*\\\\\\\\([0-9]\\\\\\\\+ bytes\\\\\\\\).*/\\\\\\\\1/p' | head -1)
                        if [ -n "$rx_bytes" ] || [ -n "$tx_bytes" ]; then
                            echo "STATS:$iface|RX:${rx_bytes:-0 bytes}|TX:${tx_bytes:-0 bytes}"
                        fi
                    fi
                fi
            fi
        done
        """
    }
    
    private static func parseVPNInterfaceOutput(_ output: String) -> [VPNConnection] {
        var vpnConnections: [VPNConnection] = []
        let lines = output.components(separatedBy: .newlines)
        var currentInterface: String?
        
        for line in lines {
            guard !line.isEmpty else { continue }
            
            if line.hasPrefix("INTERFACE:") {
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
                var stats: [String: String] = [:]
                
                for component in components {
                    let parts = component.components(separatedBy: ":")
                    if parts.count >= 2 {
                        stats[parts[0]] = parts[1...].joined(separator: ":")
                    }
                }
                
                // Update the last VPN connection with stats
                if let lastVPN = vpnConnections.last {
                    lastVPN.bytesReceived = stats["RX"]
                    lastVPN.bytesSent = stats["TX"]
                }
                
                currentInterface = nil
            }
        }
        
        return vpnConnections
    }
    
    private static func parseVPNServiceOutput(_ output: String) -> [VPNConnection] {
        var vpnServices: [VPNConnection] = []
        
        for line in output.components(separatedBy: .newlines) {
            if line.contains("Connected") || line.contains("Connecting") {
                // Extract VPN service name and status
                let components = line.components(separatedBy: "\"")
                if components.count >= 2 {
                    let serviceName = components[1]
                    let status = line.contains("Connected") ? "Connected" : "Connecting"
                    
                    let serviceVPN = VPNConnection(
                        interfaceName: "Service",
                        ip: "N/A",
                        vpnType: "System VPN",
                        status: status
                    )
                    serviceVPN.serverName = serviceName
                    vpnServices.append(serviceVPN)
                }
            }
        }
        
        return vpnServices
    }
}