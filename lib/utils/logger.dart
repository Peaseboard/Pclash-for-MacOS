/// Application-wide logging utility
class AppLogger {
  AppLogger._();

  static const String _prefix = '🐌 PClash';
  static bool _debugMode = false;

  static void setDebugMode(bool enabled) {
    _debugMode = enabled;
  }

  static void info(String message, [String? tag]) {
    print('$_prefix [INFO] ${tag != null ? '[$tag] ' : ''}$message');
  }

  static void debug(String message, [String? tag]) {
    if (_debugMode) {
      print('$_prefix [DEBUG] ${tag != null ? '[$tag] ' : ''}$message');
    }
  }

  static void warning(String message, [String? tag]) {
    print('$_prefix [WARN] ${tag != null ? '[$tag] ' : ''}$message');
  }

  static void error(String message, [String? tag, Exception? e]) {
    print('$_prefix [ERROR] ${tag != null ? '[$tag] ' : ''}$message');
    if (e != null) {
      print('$_prefix [ERROR]   Exception: $e');
    }
  }

  static void proxy(String message) {
    info(message, 'PROXY');
  }

  static void vpn(String message) {
    info(message, 'VPN');
  }

  static void api(String message) {
    debug(message, 'API');
  }

  static void config(String message) {
    debug(message, 'CONFIG');
  }
}
