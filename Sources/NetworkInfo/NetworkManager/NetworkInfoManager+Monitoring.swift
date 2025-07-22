import Foundation
import Network

// MARK: - File and Network Monitoring Extension
extension NetworkInfoManager {
    func setupNetworkMonitor() {
        networkMonitor = NWPathMonitor()
        
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                print("Network configuration changed")
                // Refresh all data when network changes
                self?.refreshData()
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
            self?.refreshData()
        }
        
        configWatcher?.setCancelHandler {
            close(fileDescriptor)
        }
        
        configWatcher?.resume()
    }
}