import Foundation
import Network

// MARK: - File and Network Monitoring Extension
extension NetworkInfoManager {
    func setupNetworkMonitor() {
        networkMonitor = NWPathMonitor()
        
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                
                Logger.info("Network configuration changed", category: "Network")
                
                // Update network stability tracking
                self.updateNetworkStability(newPath: path)
                
                // Refresh all data when network changes
                self.refreshData()
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
            Logger.error("Error watching config file", category: "Config")
            return
        }
        
        configWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.main
        )
        
        configWatcher?.setEventHandler { [weak self] in
            Logger.info("dns.conf has changed. Reloading DNS configuration.", category: "Config")
            self?.refreshData()
        }
        
        configWatcher?.setCancelHandler {
            close(fileDescriptor)
        }
        
        configWatcher?.resume()
    }
}