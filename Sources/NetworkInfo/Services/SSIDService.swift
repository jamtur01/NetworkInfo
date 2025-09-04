import Foundation
import CoreWLAN

/// Service for detecting WiFi SSID using multiple fallback strategies
actor SSIDService: SSIDDetector {
    
    // MARK: - SSID Detection Strategies
    
    /// Detects the current WiFi SSID using multiple fallback methods
    /// - Returns: SSID string or appropriate status message
    static func detectSSID() async -> String {
        // Strategy 1: Core WLAN framework (most reliable for macOS 15+)
        if let ssid = await tryCorWLAN() {
            Logger.info("Detected SSID via Core WLAN: \(ssid)", category: "SSID")
            return ssid
        }
        
        // Strategy 2: networksetup command
        if let ssid = await tryNetworkSetup() {
            Logger.info("Detected SSID via networksetup: \(ssid)", category: "SSID")
            return ssid
        }
        
        // Strategy 3: airport utility (deprecated but might work)
        if let ssid = await tryAirportUtility() {
            Logger.info("Detected SSID via airport utility: \(ssid)", category: "SSID")
            return ssid
        }
        
        // Strategy 4: ipconfig command (original method)
        if let ssid = await tryIPConfig() {
            if ssid == "<redacted>" {
                Logger.warning("SSID redacted - Location Services permission required", category: "SSID")
                return "Privacy restricted"
            }
            Logger.info("Detected SSID via ipconfig: \(ssid)", category: "SSID") 
            return ssid
        }
        
        Logger.warning("All SSID detection methods failed", category: "SSID")
        return "Not connected"
    }
    
    // MARK: - Detection Strategy Implementations
    
    /// Try Core WLAN framework (requires Location Services permission)
    private static func tryCorWLAN() async -> String? {
        let wifiClient = CWWiFiClient.shared()
        
        // Try default interface first
        if let wifiInterface = wifiClient.interface(),
           let networkName = wifiInterface.ssid() {
            return networkName
        }
        
        // Try all WiFi interfaces
        if let interfaces = wifiClient.interfaces() {
            for interface in interfaces {
                if let networkName = interface.ssid() {
                    return networkName
                }
            }
        }
        
        return nil
    }
    
    /// Try networksetup command for all interfaces
    private static func tryNetworkSetup() async -> String? {
        do {
            let output = try await ProcessService.execute(command: "/usr/sbin/networksetup", arguments: ["-listallhardwareports"])
            
            // Parse interfaces and try each one
            let lines = output.components(separatedBy: .newlines)
            var wifiInterface: String?
            
            for line in lines {
                if line.contains("Hardware Port: Wi-Fi") {
                    // Found Wi-Fi port, next line should have device
                    continue
                } else if line.hasPrefix("Device: ") && wifiInterface == nil {
                    wifiInterface = String(line.dropFirst(8))
                    break
                }
            }
            
            if let interface = wifiInterface {
                let airportOutput = try await ProcessService.execute(
                    command: "/usr/sbin/networksetup", 
                    arguments: ["-getairportnetwork", interface]
                )
                
                if !airportOutput.isEmpty &&
                   !airportOutput.contains("You are not associated") &&
                   !airportOutput.contains("Error") {
                    if let range = airportOutput.range(of: "Current Wi-Fi Network: ") {
                        return String(airportOutput[range.upperBound...])
                    }
                }
            }
        } catch {
            Logger.error("networksetup command failed: \(error.localizedDescription)", category: "SSID")
        }
        
        return nil
    }
    
    /// Try deprecated airport utility 
    private static func tryAirportUtility() async -> String? {
        let airportPath = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
        
        guard FileManager.default.fileExists(atPath: airportPath) else {
            return nil
        }
        
        do {
            let output = try await ProcessService.execute(command: airportPath, arguments: ["-I"])
            
            // Parse airport output for SSID
            for line in output.components(separatedBy: .newlines) {
                if line.contains("SSID: ") {
                    let components = line.components(separatedBy: "SSID: ")
                    if components.count > 1 {
                        let ssid = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        if !ssid.isEmpty {
                            return ssid
                        }
                    }
                }
            }
        } catch {
            Logger.debug("airport utility failed: \(error.localizedDescription)", category: "SSID")
        }
        
        return nil
    }
    
    /// Try original ipconfig method (may return <redacted>)
    private static func tryIPConfig() async -> String? {
        do {
            let script = """
            for i in ${(o)$(ifconfig -lX "en[0-9]")};do ipconfig getsummary ${i} | awk '/ SSID/ {print $NF}';done 2> /dev/null
            """
            let output = try await ProcessService.executeScript(script, shell: "/bin/zsh")
            return output.isEmpty ? nil : output
        } catch {
            Logger.error("ipconfig command failed: \(error.localizedDescription)", category: "SSID")
            return nil
        }
    }
}