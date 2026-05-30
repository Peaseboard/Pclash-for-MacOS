import Foundation
import SystemConfiguration

/// macOS system proxy helper
/// Sets HTTP/SOCKS proxy through SystemConfiguration framework
class ProxyHelper {
    
    static let proxyHelperChannel = "com.pclash.app/proxy"
    
    /// Set system-wide HTTP and SOCKS proxy
    static func setSystemProxy(enabled: Bool, port: Int) -> Bool {
        let proxies = enabled ? [
            kCFNetworkProxiesHTTPEnable: true,
            kCFNetworkProxiesHTTPPort: port,
            kCFNetworkProxiesHTTPProxy: "127.0.0.1",
            kCFNetworkProxiesSOCKSEnable: true,
            kCFNetworkProxiesSOCKSPort: port,
            kCFNetworkProxiesSOCKSProxy: "127.0.0.1",
        ] as CFDictionary : [String: Any]()
        
        return setProxy(proxies)
    }
    
    /// Set only SOCKS proxy (for global mode)
    static func setSocksProxy(enabled: Bool, port: Int) -> Bool {
        let proxies = enabled ? [
            kCFNetworkProxiesSOCKSEnable: true,
            kCFNetworkProxiesSOCKSPort: port,
            kCFNetworkProxiesSOCKSProxy: "127.0.0.1",
        ] as CFDictionary : [String: Any]()
        
        return setProxy(proxies)
    }
    
    /// Set proxy configuration
    private static func setProxy(_ proxies: CFDictionary) -> Bool {
        // Get current network service
        guard let prefs = SCPreferencesCreate(nil, "PClash" as CFString, nil) else {
            return false
        }
        
        let proxySettings = proxies as NSDictionary
        let path = "/Sets/Current/Network/Global/Proxies"
        
        // Apply proxy settings
        let success = SCPreferencesSetValue(prefs, path as CFString, proxySettings)
        if success {
            // Commit changes
            return SCPreferencesCommitChanges(prefs)
        }
        
        return false
    }
    
    /// Get current system proxy status
    static func getSystemProxyStatus() -> [String: Any]? {
        guard let proxies = CFNetworkCopySystemProxySettings()?.takeUnretainedValue() as? [String: Any] else {
            return nil
        }
        
        let httpEnabled = proxies[kCFNetworkProxiesHTTPEnable as String] as? Bool ?? false
        let socksEnabled = proxies[kCFNetworkProxiesSOCKSEnable as String] as? Bool ?? false
        let httpPort = proxies[kCFNetworkProxiesHTTPPort as String] as? Int ?? 0
        let socksPort = proxies[kCFNetworkProxiesSOCKSPort as String] as? Int ?? 0
        
        return [
            "httpEnabled": httpEnabled,
            "socksEnabled": socksEnabled,
            "httpPort": httpPort,
            "socksPort": socksPort,
        ]
    }
    
    /// Disable all system proxies
    static func disableSystemProxy() -> Bool {
        let emptyProxies = [
            kCFNetworkProxiesHTTPEnable: false,
            kCFNetworkProxiesSOCKSEnable: false,
        ] as CFDictionary
        
        return setProxy(emptyProxies)
    }
    
    /// Generate PAC content for smart routing
    static func generatePAC(mixedPort: Int, directDomains: [String]) -> String {
        let domainList = directDomains.map { "'\(String($0).lowercased())'" }.joined(separator: ", ")
        
        return """
        function FindProxyForURL(url, host) {
            var directDomains = [\(domainList)];
            
            for (var i = 0; i < directDomains.length; i++) {
                if (dnsDomainIs(host, directDomains[i])) {
                    return "DIRECT";
                }
            }
            
            return "PROXY 127.0.0.1:\(mixedPort); SOCKS 127.0.0.1:\(mixedPort)";
        }
        """
    }
}
