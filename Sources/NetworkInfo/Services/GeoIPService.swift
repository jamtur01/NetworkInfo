import Foundation

/// Service for fetching geographical IP information from multiple providers
actor GeoIPService: GeoIPProvider {
    
    // MARK: - API Endpoints
    private static let apiUrls = [
        "https://ipapi.co/json",      // Primary service (confirmed working)
        "http://ip-api.com/json/",
        "https://ipinfo.io/json"
    ]
    
    // MARK: - Public Interface
    
    /// Fetches GeoIP data from multiple providers with failover
    /// - Returns: GeoIPData if successful, nil if all providers fail
    static func fetchGeoIPData() async -> GeoIPData? {
        var errorCount = 0
        
        for apiUrl in apiUrls {
            guard let url = URL(string: apiUrl) else { continue }
            
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 5.0
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    Logger.error("HTTP error for \(apiUrl): \(response)", category: "GeoIP")
                    errorCount += 1
                    continue
                }
                
                if let geoData = try parseGeoIPResponse(data: data, from: apiUrl) {
                    Logger.info("Successfully retrieved GeoIP data from \(apiUrl)", category: "GeoIP")
                    return geoData
                }
                
            } catch {
                Logger.error("Error fetching GeoIP data from \(apiUrl): \(error.localizedDescription)", category: "GeoIP")
                errorCount += 1
            }
        }
        
        // If all services failed, return fallback data
        if errorCount == apiUrls.count {
            Logger.warning("All GeoIP services failed", category: "GeoIP")
            return GeoIPData(
                query: "Check connection",
                isp: "Network issue", 
                country: "Unavailable",
                countryCode: "N/A"
            )
        }
        
        return nil
    }
    
    // MARK: - Private Helpers
    
    /// Parses GeoIP response data based on the API provider
    private static func parseGeoIPResponse(data: Data, from apiUrl: String) throws -> GeoIPData? {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        if apiUrl.contains("ipapi.co") {
            // ipapi.co format
            return GeoIPData(
                query: json["ip"] as? String ?? "N/A",
                isp: json["org"] as? String ?? "N/A", 
                country: json["country_name"] as? String ?? "N/A",
                countryCode: json["country_code"] as? String ?? "N/A"
            )
        } else if apiUrl.contains("ip-api.com") {
            // ip-api.com format
            return GeoIPData(
                query: json["query"] as? String ?? "N/A",
                isp: json["isp"] as? String ?? "N/A",
                country: json["country"] as? String ?? "N/A", 
                countryCode: json["countryCode"] as? String ?? "N/A"
            )
        } else if apiUrl.contains("ipinfo.io") {
            // ipinfo.io format  
            return GeoIPData(
                query: json["ip"] as? String ?? "N/A",
                isp: json["org"] as? String ?? "N/A",
                country: json["country"] as? String ?? "N/A",
                countryCode: json["country"] as? String ?? "N/A"
            )
        }
        
        return nil
    }
    
    /// Creates test GeoIP data for testing environments
    static func createTestData() async -> GeoIPData {
        return GeoIPData(
            query: "192.168.1.100",
            isp: "Test ISP",
            country: "Test Country", 
            countryCode: "TC"
        )
    }
}