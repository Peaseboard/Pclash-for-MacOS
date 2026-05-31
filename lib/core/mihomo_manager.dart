import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'mihomo_api.dart';
import 'config_manager.dart';

/// Manages the Mihomo core process lifecycle
class MihomoManager {
  Process? _process;
  MihomoApi? _api;
  int _apiPort;
  int _mixedPort;
  String _secret;
  bool _isRunning = false;
  String? _workDir;

  MihomoManager({
    int? apiPort,
    int? mixedPort,
    String? secret,
  })  : _apiPort = apiPort ?? 9090,
        _mixedPort = mixedPort ?? 7890,
        _secret = secret ?? 'pclash-secret';

  bool get isRunning => _isRunning;
  MihomoApi? get api => _api;
  int get apiPort => _apiPort;
  int get mixedPort => _mixedPort;
  String get secret => _secret;

  /// Initialize working directory and generate config
  Future<void> initialize({
    required int apiPort,
    required int mixedPort,
    required String secret,
    String? subscriptionContent,
  }) async {
    _apiPort = apiPort;
    _mixedPort = mixedPort;
    _secret = secret;

    final appDir = await getApplicationSupportDirectory();
    _workDir = p.join(appDir.path, 'pclash');
    await Directory(_workDir!).create(recursive: true);

    // Generate config
    await ConfigManager.generateConfig(
      workDir: _workDir!,
      apiPort: _apiPort,
      mixedPort: _mixedPort,
      secret: _secret,
      subscriptionContent: subscriptionContent,
    );
  }

  /// Get platform-specific mihomo binary path
  Future<String?> _getBinaryPath() async {
    // Try to extract and use bundled assets
    final bundle = await _getBundledBinary();
    if (bundle != null) return bundle;

    // Fallback: system mihomo
    if (Platform.isMacOS) return 'mihomo';
    if (Platform.isAndroid) return null; // Android uses VpnService path
    if (Platform.isWindows) return 'mihomo.exe';
    if (Platform.isLinux) return 'mihomo';

    return null;
  }

  /// Get bundled mihomo binary from assets
  Future<String?> _getBundledBinary() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final binaryDir = p.join(appDir.path, 'pclash', 'bin');
      await Directory(binaryDir).create(recursive: true);
      
      String binaryName;
      if (Platform.isMacOS) {
        final arch = await _getMacOSArch();
        binaryName = arch == 'arm64' ? 'mihomo-darwin-arm64' : 'mihomo-darwin-amd64';
      } else if (Platform.isAndroid) {
        binaryName = 'mihomo-android-arm64'; // Or detect ABI
      } else {
        return null;
      }

      final binaryPath = p.join(binaryDir, binaryName);
      final file = File(binaryPath);

      // If binary already exists, just ensure it's executable
      if (await file.exists()) {
        await Process.run('chmod', ['+x', binaryPath]);
        return binaryPath;
      }

      // If not, extract from assets
      print('Extracting mihomo binary ($binaryName) from assets...');
      final ByteData data = await rootBundle.load('assets/mihomo/$binaryName');
      final Uint8List bytes = data.buffer.asUint8List();
      await file.writeAsBytes(bytes);
      
      await Process.run('chmod', ['+x', binaryPath]);
      
      if (await file.exists()) {
        return binaryPath;
      }
    } catch (e) {
      print('Failed to get bundled binary: $e');
    }
    return null;
  }

  /// Detect macOS architecture
  Future<String> _getMacOSArch() async {
    try {
      final result = await Process.run('uname', ['-m']);
      final arch = (result.stdout as String).trim();
      return arch == 'arm64' ? 'arm64' : 'amd64';
    } catch (_) {
      return 'amd64';
    }
  }

  /// Start mihomo process
  Future<bool> start({String? subscriptionContent}) async {
    if (_isRunning) {
      if (_process != null && _process!.exitCode == null) {
        return true;
      }
    }

    try {
      await initialize(
        apiPort: _apiPort,
        mixedPort: _mixedPort,
        secret: _secret,
        subscriptionContent: subscriptionContent,
      );

      final binaryPath = await _getBinaryPath();
      if (binaryPath == null) {
        throw Exception('Mihomo binary not found for this platform');
      }

      final configPath = p.join(_workDir!, 'config.yaml');

      _process = await Process.start(
        binaryPath,
        ['-d', _workDir!, '-f', configPath],
        workingDirectory: _workDir,
        mode: ProcessStartMode.detached,
      );

      _api = MihomoApi(
        host: '127.0.0.1',
        port: _apiPort,
        secret: _secret,
      );

      // Wait for API to be ready
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await _api!.isApiAvailable()) {
          _isRunning = true;
          return true;
        }
      }

      throw TimeoutException('Mihomo failed to start within 10 seconds');
    } catch (e) {
      _isRunning = false;
      rethrow;
    }
  }

  /// Stop mihomo process
  Future<void> stop() async {
    if (_process != null) {
      try {
        _process!.kill(ProcessSignal.sigterm);
        await _process!.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            _process!.kill(ProcessSignal.sigkill);
            return 0;
          },
        );
      } catch (_) {
        _process?.kill(ProcessSignal.sigkill);
      }
      _process = null;
    }
    _api?.dispose();
    _api = null;
    _isRunning = false;
  }

  String? get workDir => _workDir;

  void dispose() {
    stop();
  }
}
