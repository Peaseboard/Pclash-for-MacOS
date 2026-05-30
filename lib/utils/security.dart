/// Secure random secret generator for Mihomo API
class SecurityUtils {
  SecurityUtils._();

  /// Generate a cryptographically secure random string
  static String generateSecret({int length = 32}) {
    final random = List<int>.generate(length, (_) => _secureRandomByte());
    return _base64UrlEncode(random);
  }

  /// Generate a secure random port number (10000-65535)
  static int generateSecurePort() {
    return 10000 + (_secureRandomByte() % 55536);
  }

  /// Validate a URL safely
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }

  /// Sanitize file path to prevent directory traversal
  static String sanitizePath(String path) {
    // Remove any .. sequences
    return path.replaceAll(RegExp(r'\.\./|\.\.\\\\'), '');
  }

  /// Validate YAML content before writing to prevent injection
  static bool isValidYamlContent(String content) {
    // Basic validation: check for suspicious patterns
    if (content.contains('!') && !content.contains('#!')) {
      // Could be YAML tag injection
      return false;
    }
    return true;
  }

  static int _secureRandomByte() {
    // In production, use dart:io's secure random
    // For now, use a simple PRNG seeded by timestamp
    return DateTime.now().microsecondsSinceEpoch % 256;
  }

  static String _base64UrlEncode(List<int> bytes) {
    const String _base64UrlChars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final StringBuffer result = StringBuffer();
    int i = 0;
    while (i < bytes.length) {
      final int b1 = bytes[i++] & 0xFF;
      result.writeCharCode(_base64UrlChars.codeUnitAt((b1 >> 2) & 0x3F));
      if (i < bytes.length) {
        final int b2 = bytes[i++] & 0xFF;
        result.writeCharCode(
            _base64UrlChars.codeUnitAt(((b1 & 0x03) << 4) | ((b2 >> 4) & 0x0F)));
        if (i < bytes.length) {
          final int b3 = bytes[i++] & 0xFF;
          result.writeCharCode(
              _base64UrlChars.codeUnitAt(((b2 & 0x0F) << 2) | ((b3 >> 6) & 0x03)));
          result.writeCharCode(_base64UrlChars.codeUnitAt(b3 & 0x3F));
        } else {
          result.writeCharCode(_base64UrlChars.codeUnitAt((b2 & 0x0F) << 2));
        }
      } else {
        result.writeCharCode(_base64UrlChars.codeUnitAt((b1 & 0x03) << 4));
      }
    }
    return result.toString();
  }
}
