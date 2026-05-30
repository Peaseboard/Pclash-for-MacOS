#include "proxy_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/plugin_registrar_windows.h>
#include <windows.h>
#include <wininet.h>
#include <shlwapi.h>
#include <iostream>
#include <map>
#include <string>

#pragma comment(lib, "wininet.lib")
#pragma comment(lib, "shlwapi.lib")

namespace pclash {

// static
void ProxyPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "com.pclash.app/proxy",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<ProxyPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

ProxyPlugin::ProxyPlugin() {}

ProxyPlugin::~ProxyPlugin() {}

void ProxyPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (method_call.method_name().compare("setSystemProxy") == 0) {
    const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!args) {
      result->Error("INVALID_ARGUMENT", "Arguments required");
      return;
    }

    bool enabled = false;
    int port = 7890;

    auto enabled_it = args->find(flutter::EncodableValue("enabled"));
    if (enabled_it != args->end()) {
      enabled = std::get<bool>(enabled_it->second);
    }

    auto port_it = args->find(flutter::EncodableValue("port"));
    if (port_it != args->end()) {
      port = std::get<int>(port_it->second);
    }

    bool success = SetSystemProxy(enabled, port);
    result->Success(flutter::EncodableValue(success));

  } else if (method_call.method_name().compare("getProxyStatus") == 0) {
    auto status = GetProxyStatus();
    result->Success(flutter::EncodableValue(status));

  } else if (method_call.method_name().compare("setAutoStart") == 0) {
    const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!args) {
      result->Error("INVALID_ARGUMENT", "Arguments required");
      return;
    }

    bool enabled = false;
    auto enabled_it = args->find(flutter::EncodableValue("enabled"));
    if (enabled_it != args->end()) {
      enabled = std::get<bool>(enabled_it->second);
    }

    bool success = SetAutoStart(enabled);
    result->Success(flutter::EncodableValue(success));

  } else {
    result->NotImplemented();
  }
}

bool ProxyPlugin::SetSystemProxy(bool enabled, int port) {
  HKEY hKey;
  LONG result = RegOpenKeyEx(
      HKEY_CURRENT_USER,
      TEXT("Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings"),
      0, KEY_WRITE, &hKey);
  
  if (result != ERROR_SUCCESS) {
    return false;
  }
  
  DWORD proxyEnable = enabled ? 1 : 0;
  RegSetValueEx(hKey, TEXT("ProxyEnable"), 0, REG_DWORD, 
               (const BYTE*)&proxyEnable, sizeof(proxyEnable));
  
  if (enabled) {
    std::wstring proxyServer = L"127.0.0.1:" + std::to_wstring(port);
    RegSetValueEx(hKey, TEXT("ProxyServer"), 0, REG_SZ,
                 (const BYTE*)proxyServer.c_str(),
                 (proxyServer.length() + 1) * sizeof(wchar_t));
    
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

flutter::EncodableMap ProxyPlugin::GetProxyStatus() {
  HKEY hKey;
  LONG result = RegOpenKeyEx(
      HKEY_CURRENT_USER,
      TEXT("Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings"),
      0, KEY_READ, &hKey);
  
  flutter::EncodableMap status;
  
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
    
    status[flutter::EncodableValue("enabled")] = flutter::EncodableValue(proxyEnable == 1);
    status[flutter::EncodableValue("server")] = flutter::EncodableValue(
        std::string(proxyServer, proxyServer + wcslen(proxyServer)));
  }
  
  return status;
}

bool ProxyPlugin::SetAutoStart(bool enabled) {
  HKEY hKey;
  const wchar_t* runKey = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
  
  LONG result = RegOpenKeyEx(HKEY_CURRENT_USER, runKey, 0, KEY_WRITE, &hKey);
  if (result != ERROR_SUCCESS) {
    return false;
  }
  
  if (enabled) {
    // Get current executable path
    wchar_t exePath[MAX_PATH];
    GetModuleFileName(nullptr, exePath, MAX_PATH);
    
    RegSetValueEx(hKey, TEXT("PClash"), 0, REG_SZ,
                 (const BYTE*)exePath,
                 (wcslen(exePath) + 1) * sizeof(wchar_t));
  } else {
    RegDeleteValue(hKey, TEXT("PClash"));
  }
  
  RegCloseKey(hKey);
  return true;
}

}  // namespace pclash
