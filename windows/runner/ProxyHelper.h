#include <windows.h>
#include <iostream>
#include <string>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

namespace pclash {

/// Windows system proxy helper using Registry
class WindowsProxyHelper {
public:
    /// Set system proxy via Windows Registry
    static bool SetSystemProxy(bool enabled, int port) {
        HKEY hKey;
        LONG result = RegOpenKeyEx(
            HKEY_CURRENT_USER,
            TEXT("Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings"),
            0, KEY_WRITE, &hKey);
        
        if (result != ERROR_SUCCESS) {
            return false;
        }
        
        // Enable/disable proxy
        DWORD proxyEnable = enabled ? 1 : 0;
        RegSetValueEx(hKey, TEXT("ProxyEnable"), 0, REG_DWORD, 
                     (const BYTE*)&proxyEnable, sizeof(proxyEnable));
        
        if (enabled) {
            // Set proxy server
            std::wstring proxyServer = L"127.0.0.1:" + std::to_wstring(port);
            RegSetValueEx(hKey, TEXT("ProxyServer"), 0, REG_SZ,
                         (const BYTE*)proxyServer.c_str(),
                         (proxyServer.length() + 1) * sizeof(wchar_t));
            
            // Set proxy override (bypass local addresses)
            std::wstring proxyOverride = L"<local>";
            RegSetValueEx(hKey, TEXT("ProxyOverride"), 0, REG_SZ,
                         (const BYTE*)proxyOverride.c_str(),
                         (proxyOverride.length() + 1) * sizeof(wchar_t));
        }
        
        RegCloseKey(hKey);
        
        // Notify system of proxy change
        InternetSetOption(nullptr, INTERNET_OPTION_SETTINGS_CHANGED, nullptr, 0);
        InternetSetOption(nullptr, INTERNET_OPTION_REFRESH, nullptr, 0);
        
        return true;
    }
    
    /// Get current proxy status
    static std::map<std::string, flutter::EncodableValue> GetProxyStatus() {
        HKEY hKey;
        LONG result = RegOpenKeyEx(
            HKEY_CURRENT_USER,
            TEXT("Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings"),
            0, KEY_READ, &hKey);
        
        std::map<std::string, flutter::EncodableValue> status;
        
        if (result == ERROR_SUCCESS) {
            DWORD proxyEnable = 0;
            DWORD size = sizeof(proxyEnable);
            DWORD type = REG_DWORD;
            
            RegQueryValueEx(hKey, TEXT("ProxyEnable"), nullptr, &type,
                           (LPBYTE)&proxyEnable, &size);
            
            wchar_t proxyServer[256] = {0};
            size = sizeof(proxyServer);
            type = REG_SZ;
            
            RegQueryValueEx(hKey, TEXT("ProxyServer"), nullptr, &type,
                           (LPBYTE)proxyServer, &size);
            
            RegCloseKey(hKey);
            
            status["enabled"] = flutter::EncodableValue(proxyEnable == 1);
            status["server"] = flutter::EncodableValue(
                std::string(proxyServer, proxyServer + wcslen(proxyServer)));
        }
        
        return status;
    }
};

} // namespace pclash
