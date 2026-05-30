#ifndef PROXY_PLUGIN_H_
#define PROXY_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace pclash {

/// Windows plugin for system proxy control
/// Handles MethodChannel calls for setting/getting system proxy
class ProxyPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  ProxyPlugin();

  virtual ~ProxyPlugin();

  // Disallow copy and assign.
  ProxyPlugin(const ProxyPlugin&) = delete;
  ProxyPlugin& operator=(const ProxyPlugin&) = delete;

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  /// Set system proxy via Windows Registry
  bool SetSystemProxy(bool enabled, int port);

  /// Get current proxy status
  flutter::EncodableMap GetProxyStatus();

  /// Set up auto-start via Registry Run key
  bool SetAutoStart(bool enabled);
};

}  // namespace pclash

#endif  // PROXY_PLUGIN_H_
