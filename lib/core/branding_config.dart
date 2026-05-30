import 'dart:io';
import 'package:yaml/yaml.dart';

/// Branding configuration loader
/// Reads branding.yaml and provides typed access to all customization options
class BrandingConfig {
  static BrandingConfig? _instance;
  
  // App
  late final String name;
  late final String tagline;
  late final String version;
  late final String packageName;
  late final String executable;
  
  // Subscription
  late final String pboardBaseUrl;
  late final String pboardSubscribePath;
  late final String pboardUserPanelUrl;
  late final bool pboardEnabled;
  late final bool allowCustomSubscription;
  late final bool showBrandLink;
  
  // Theme
  late final String primaryColor;
  late final String secondaryColor;
  late final String accentColor;
  late final bool allowThemeSwitch;
  
  // Defaults
  late final String defaultProxyMode;
  late final int defaultMixedPort;
  late final int defaultApiPort;
  late final bool systemProxyDefault;
  late final bool autoStartDefault;
  late final String delayTestUrl;
  late final int delayTestTimeout;
  
  // Features
  late final bool featureDelayTest;
  late final bool featureTrafficMonitor;
  late final bool featureConnectionDetails;
  late final bool featureLogViewer;
  late final bool featureGeoUpdate;
  late final bool featureSubscriptionAutoRefresh;
  late final int subscriptionRefreshInterval;
  
  // Legal
  late final String privacyPolicyUrl;
  late final String termsOfServiceUrl;
  late final String helpUrl;
  late final String supportEmail;
  late final String copyright;
  
  // Build
  late final String androidApplicationId;
  late final int androidMinSdk;
  late final int androidTargetSdk;
  late final String macosBundleId;
  late final String macosDeploymentTarget;
  late final String windowsCompanyName;
  late final String linuxAppId;

  BrandingConfig._();

  /// Load configuration from branding.yaml
  static Future<BrandingConfig> load() async {
    if (_instance != null) return _instance!;

    final config = BrandingConfig._();
    
    try {
      final file = File('assets/branding.yaml');
      if (!await file.exists()) {
        // Fallback to defaults
        _applyDefaults(config);
        _instance = config;
        return config;
      }

      final content = await file.readAsString();
      final yaml = loadYaml(content) as YamlMap;

      // App
      final app = yaml['app'] as YamlMap?;
      config.name = app?['name'] as String? ?? 'PClash';
      config.tagline = app?['tagline'] as String? ?? 'Modern Proxy Client';
      config.version = app?['version'] as String? ?? '1.0.0';
      config.packageName = app?['package_name'] as String? ?? 'com.pclash.app';
      config.executable = app?['executable'] as String? ?? 'pclash';

      // Subscription
      final pboard = yaml['pboard'] as YamlMap?;
      config.subscribeBaseUrl = pboard?['base_url'] as String? ?? 'https://your-domain.com';
      config.subscribePath = pboard?['subscribe_path'] as String? ?? '/api/v1/client/subscribe';
      config.userPanelUrl = pboard?['user_panel_url'] as String? ?? 'https://your-domain.com/user';
      config.subscribeEnabled = pboard?['enabled'] as bool? ?? true;
      config.allowCustomSubscription = pboard?['allow_custom_subscription'] as bool? ?? true;
      config.showBrandLink = pboard?['show_brand_link'] as bool? ?? true;

      // Theme
      final theme = yaml['theme'] as YamlMap?;
      config.primaryColor = theme?['primary_color'] as String? ?? '#3B82F6';
      config.secondaryColor = theme?['secondary_color'] as String? ?? '#10B981';
      config.accentColor = theme?['accent_color'] as String? ?? '#F59E0B';
      config.allowThemeSwitch = theme?['allow_theme_switch'] as bool? ?? true;

      // Defaults
      final defaults = yaml['defaults'] as YamlMap?;
      config.defaultProxyMode = defaults?['proxy_mode'] as String? ?? 'rule';
      config.defaultMixedPort = defaults?['mixed_port'] as int? ?? 7890;
      config.defaultApiPort = defaults?['api_port'] as int? ?? 9090;
      config.systemProxyDefault = defaults?['system_proxy_default'] as bool? ?? true;
      config.autoStartDefault = defaults?['auto_start_default'] as bool? ?? false;
      config.delayTestUrl = defaults?['delay_test_url'] as String? ?? 'https://www.gstatic.com/generate_204';
      config.delayTestTimeout = defaults?['delay_test_timeout'] as int? ?? 5000;

      // Features
      final features = yaml['features'] as YamlMap?;
      config.featureDelayTest = features?['delay_test'] as bool? ?? true;
      config.featureTrafficMonitor = features?['traffic_monitor'] as bool? ?? true;
      config.featureConnectionDetails = features?['connection_details'] as bool? ?? true;
      config.featureLogViewer = features?['log_viewer'] as bool? ?? true;
      config.featureGeoUpdate = features?['geo_update'] as bool? ?? true;
      config.featureSubscriptionAutoRefresh = features?['subscription_auto_refresh'] as bool? ?? true;
      config.subscriptionRefreshInterval = features?['subscription_refresh_interval'] as int? ?? 24;

      // Legal
      final legal = yaml['legal'] as YamlMap?;
      config.privacyPolicyUrl = legal?['privacy_policy_url'] as String? ?? 'https://your-domain.com/privacy/';
      config.termsOfServiceUrl = legal?['terms_of_service_url'] as String? ?? 'https://your-domain.com/terms/';
      config.helpUrl = legal?['help_url'] as String? ?? 'https://your-domain.com/help/';
      config.supportEmail = legal?['support_email'] as String? ?? 'support@your-domain.com';
      config.copyright = legal?['copyright'] as String? ?? '© 2024-2026 PClash Contributors. All rights reserved.';

      // Build
      final build = yaml['build'] as YamlMap?;
      final android = build?['android'] as YamlMap?;
      config.androidApplicationId = android?['application_id'] as String? ?? config.packageName;
      config.androidMinSdk = android?['min_sdk'] as int? ?? 24;
      config.androidTargetSdk = android?['target_sdk'] as int? ?? 34;

      final macos = build?['macos'] as YamlMap?;
      config.macosBundleId = macos?['bundle_id'] as String? ?? config.packageName;
      config.macosDeploymentTarget = macos?['deployment_target'] as String? ?? '10.15';

      final windows = build?['windows'] as YamlMap?;
      config.windowsCompanyName = windows?['company_name'] as String? ?? 'PClash Contributors';

      final linux = build?['linux'] as YamlMap?;
      config.linuxAppId = linux?['app_id'] as String? ?? config.packageName;

      _instance = config;
      return config;
    } catch (e) {
      // Fallback to defaults on error
      _applyDefaults(config);
      _instance = config;
      return config;
    }
  }

  static void _applyDefaults(BrandingConfig config) {
    config.name = 'PClash';
    config.tagline = 'Modern Proxy Client';
    config.version = '1.0.0';
    config.packageName = 'com.pclash.app';
    config.executable = 'pclash';
    config.subscribeBaseUrl = 'https://your-domain.com';
    config.subscribePath = '/api/v1/client/subscribe';
    config.userPanelUrl = 'https://your-domain.com/user';
    config.subscribeEnabled = true;
    config.allowCustomSubscription = true;
    config.showBrandLink = true;
    config.primaryColor = '#3B82F6';
    config.secondaryColor = '#10B981';
    config.accentColor = '#F59E0B';
    config.allowThemeSwitch = true;
    config.defaultProxyMode = 'rule';
    config.defaultMixedPort = 7890;
    config.defaultApiPort = 9090;
    config.systemProxyDefault = true;
    config.autoStartDefault = false;
    config.delayTestUrl = 'https://www.gstatic.com/generate_204';
    config.delayTestTimeout = 5000;
    config.featureDelayTest = true;
    config.featureTrafficMonitor = true;
    config.featureConnectionDetails = true;
    config.featureLogViewer = true;
    config.featureGeoUpdate = true;
    config.featureSubscriptionAutoRefresh = true;
    config.subscriptionRefreshInterval = 24;
    config.privacyPolicyUrl = 'https://your-domain.com/privacy/';
    config.termsOfServiceUrl = 'https://your-domain.com/terms/';
    config.helpUrl = 'https://your-domain.com/help/';
    config.supportEmail = 'support@your-domain.com';
    config.copyright = '© 2024-2026 PClash Contributors. All rights reserved.';
    config.androidApplicationId = 'com.pclash.app';
    config.androidMinSdk = 24;
    config.androidTargetSdk = 34;
    config.macosBundleId = 'com.pclash.app';
    config.macosDeploymentTarget = '10.15';
    config.windowsCompanyName = 'PClash Contributors';
    config.linuxAppId = 'com.pclash.app';
  }

  /// Get the full subscription URL for a token
  String getSubscribeUrl(String token) {
    return '$pboardBaseUrl$pboardSubscribePath?token=$token';
  }

  /// Parse hex color string to Color
  int get primaryColorInt => _parseColor(primaryColor);
  int get secondaryColorInt => _parseColor(secondaryColor);
  int get accentColorInt => _parseColor(accentColor);

  static int _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return int.parse('FF$clean', radix: 16);
    }
    return int.parse(clean, radix: 16);
  }

  @override
  String toString() {
    return 'BrandingConfig(name: $name, version: $version, pboard: $pboardBaseUrl)';
  }
}
