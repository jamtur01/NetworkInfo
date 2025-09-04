import Foundation

/// Protocol for services that provide geographical IP information
protocol GeoIPProvider: Sendable {
    /// Fetches geographical IP information
    /// - Returns: GeoIPData if successful, nil if all providers fail
    static func fetchGeoIPData() async -> GeoIPData?
    
    /// Creates test data for testing environments
    /// - Returns: Test GeoIPData
    static func createTestData() async -> GeoIPData
}

/// Protocol for services that detect VPN connections
protocol VPNDetector: Sendable {
    /// Detects all active VPN connections with detailed information
    /// - Returns: Array of VPNConnection objects with comprehensive details
    static func detectVPNConnections() async -> [VPNConnection]
}

/// Protocol for services that detect WiFi SSID
protocol SSIDDetector: Sendable {
    /// Detects the current WiFi SSID using multiple fallback methods
    /// - Returns: SSID string or appropriate status message
    static func detectSSID() async -> String
}

/// Protocol for process execution services
protocol ProcessExecutor: Sendable {
    /// Executes a shell command with arguments asynchronously
    /// - Parameters:
    ///   - command: The command to execute (full path)
    ///   - arguments: Command arguments
    ///   - timeout: Optional timeout in seconds
    /// - Returns: Command output as string
    /// - Throws: ProcessError if execution fails
    static func execute(command: String, arguments: [String], timeout: TimeInterval) async throws -> String
    
    /// Executes a shell script asynchronously
    /// - Parameters:
    ///   - script: Shell script content
    ///   - shell: Shell to use (default: /bin/sh)
    ///   - timeout: Optional timeout in seconds
    /// - Returns: Script output as string
    /// - Throws: ProcessError if execution fails
    static func executeScript(_ script: String, shell: String, timeout: TimeInterval) async throws -> String
    
    /// Executes a command and returns success/failure without throwing
    /// - Parameters:
    ///   - command: The command to execute
    ///   - arguments: Command arguments
    /// - Returns: Tuple of (success: Bool, output: String)
    static func executeSafely(command: String, arguments: [String]) async -> (success: Bool, output: String)
}

/// Protocol for dependency injection container
protocol ServiceContainer {
    /// Resolves a service instance of the specified type
    /// - Parameter type: The service type to resolve
    /// - Returns: Instance of the requested service type
    func resolve<T>(_ type: T.Type) -> T
}

/// Default service implementations for production use
enum DefaultServices {
    static let geoIP: any GeoIPProvider.Type = GeoIPService.self
    static let vpn: any VPNDetector.Type = VPNService.self
    static let ssid: any SSIDDetector.Type = SSIDService.self
    static let process: any ProcessExecutor.Type = ProcessService.self
}