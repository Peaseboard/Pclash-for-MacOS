# 🐌 PClash - Modern Proxy Client

> A modern, cross-platform proxy client powered by [Mihomo](https://github.com/MetaCubeX/mihomo) (formerly Clash.Meta).

**一款现代、轻量、跨平台的代理客户端。**

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL%203.0-blue.svg)](LICENSE)
[![Release](https://img.shields.io/badge/release-v1.0.0-green.svg)]()

---

## ✨ 特性

- **全协议支持** — SS / VMess / VLESS / Trojan / Hysteria2 / TUIC / Snell / WireGuard
- **全平台支持** — macOS、Android、Windows、Linux
- **订阅管理** — 兼容 Xboard / Pboard 标准订阅格式
- **规则引擎** — 智能分流，GEOSITE/GEOIP 规则
- **实时流量** — WebSocket 实时上行/下行监控
- **暗色主题** — Material 3 设计，跟随系统
- **开机自启** — 各平台原生实现

## 📱 平台状态

| 平台 | 状态 | 代理模式 | 开机自启 | 架构 |
|------|------|----------|----------|------|
| **macOS** | 🟡 开发中 | SystemConfiguration (HTTP/SOCKS) | ✅ LaunchAgent | arm64 + x86_64 |
| **Android** | 🟡 开发中 | VpnService + TUN | ✅ BootReceiver | arm64-v8a + x86_64 |
| **Windows** | 🟡 开发中 | Registry (Internet Settings) | ✅ Registry Run | x86 + x86_64 + ARM64 |
| **Linux** | 🟡 开发中 | gsettings / kwriteconfig5 | ✅ systemd user | x86_64 + ARM |

## 🏗️ 架构

```
┌──────────────────────────────────────────────┐
│              Flutter UI (Dart)                │
│   Riverpod · Material 3 · Dio                │
├──────────────────────────────────────────────┤
│         ConnectionNotifier (Orchestrator)     │
│  • Subscribe management                       │
│  • Mihomo process lifecycle                   │
│  • Platform proxy routing                     │
│  • Real-time traffic monitoring               │
├──────────────────────────────────────────────┤
│         Platform Channels                     │
│  ┌─────────┬──────────┬──────────┬─────────┐  │
│  │ macOS   │ Android  │ Windows  │ Linux   │  │
│  │ Proxy   │ VpnChan  │ Proxy    │ Proxy   │  │
│  │ Helper  │          │ Plugin   │ Helper  │  │
│  └─────────┴──────────┴──────────┴─────────┘  │
├──────────────────────────────────────────────┤
│         Mihomo Core (Go Binary)               │
│   external-controller: 127.0.0.1:{port}       │
│   SS/VMess/VLESS/Trojan/HY2/TUIC/WG           │
└───────────────────────────────────────────────┘
```

## 🚀 快速开始

### 前置要求

- Flutter 3.2+
- Dart 3.2+
- 各平台开发工具（Xcode for macOS, Android SDK, Visual Studio for Windows）

### 构建

```bash
# 1. Clone 项目
git clone https://github.com/Peaseboard/Pclash.git
cd Pclash

# 2. 补全平台构建文件
flutter create .

# 3. 获取依赖
flutter pub get

# 4. 构建
flutter build macos --release      # macOS
flutter build apk --release        # Android
flutter build windows --release          # Windows x64
flutter build windows --release --target-platform=windows-x86    # Windows x86
flutter build windows --release --target-platform=windows-arm64  # Windows ARM64
```

### 一键构建

```bash
./build.sh all    # 构建所有支持的桌面平台
./build.sh macos  # 仅 macOS
./build.sh android # 仅 Android
```

### Mihomo 内核

项目已内置 Mihomo v1.19.25 二进制文件（`assets/mihomo/`），覆盖以下平台：
- `mihomo-darwin-arm64` — macOS Apple Silicon
- `mihomo-darwin-amd64` — macOS Intel
- `mihomo-android-arm64` — Android arm64-v8a
- `mihomo-android-amd64` — Android x86_64

如需最新版本，请从 [Mihomo Releases](https://github.com/MetaCubeX/mihomo/releases) 下载并替换。

## 📋 订阅格式

PClash 兼容 Clash/Mihomo 标准订阅格式：

```yaml
proxies:
  - name: "US Node"
    type: vmess
    server: example.com
    port: 443
    uuid: your-uuid
    alterId: 0
    cipher: auto
    tls: true
    network: ws

proxy-groups:
  - name: "🚀 节点选择"
    type: select
    proxies: ["US Node", "DIRECT"]

rules:
  - GEOSITE,cn,DIRECT
  - MATCH,🚀 节点选择
```

## 📂 项目结构

```
pclash/
├── lib/
│   ├── main.dart                         # 入口 + 主题
│   ├── core/
│   │   ├── mihomo_api.dart               # Mihomo REST API 客户端
│   │   ├── mihomo_manager.dart           # 内核进程管理
│   │   ├── config_manager.dart           # 配置生成器
│   │   ├── subscription_manager.dart     # 订阅管理
│   │   └── platform/
│   │       ├── vpn_channel.dart          # Android VPN 平台通道
│   │       ├── system_proxy_channel.dart # 统一桌面平台代理通道
│   │       ├── macos_proxy_channel.dart  # macOS 代理
│   │       ├── windows_proxy_channel.dart # Windows 代理
│   │       └── linux_proxy_channel.dart  # Linux 代理
│   ├── models/
│   │   ├── proxy.dart                    # 代理节点模型
│   │   ├── traffic_stats.dart            # 流量统计
│   │   └── subscription.dart             # 订阅模型
│   ├── providers/
│   │   └── app_providers.dart            # Riverpod 状态管理 + ConnectionNotifier
│   ├── screens/
│   │   ├── home_screen.dart              # 首页（连接开关+流量+模式）
│   │   ├── proxy_screen.dart             # 节点管理
│   │   ├── subscription_screen.dart      # 订阅管理
│   │   └── settings_screen.dart          # 设置
│   └── utils/
│       ├── constants.dart                # 常量定义
│       ├── security.dart                 # 安全工具
│       └── logger.dart                   # 日志系统
├── android/                              # Android 原生代码
│   └── app/src/main/kotlin/.../pclash/
│       ├── MainActivity.kt               # 入口 + MethodChannel
│       ├── PClashVpnService.kt           # VpnService + TUN
│       └── BootReceiver.kt               # 开机自启
├── macos/                                # macOS 原生代码
│   └── Sources/
│       ├── AppDelegate.swift             # 菜单栏托盘
│       └── ProxyHelper.swift             # 系统代理设置
├── windows/                              # Windows 原生代码
│   └── runner/
│       ├── proxy_plugin.h                # 代理插件头文件
│       ├── proxy_plugin.cpp              # 注册表代理控制
│       └── ProxyHelper.h                 # 代理辅助类
├── linux/                                # Linux 原生代码
│   └── linux_proxy_helper.sh             # gsettings/kde 代理脚本
├── assets/
│   └── mihomo/                           # 预编译内核
│       ├── mihomo-darwin-arm64
│       ├── mihomo-darwin-amd64
│       ├── mihomo-android-arm64
│       └── mihomo-android-amd64
└── test/
    └── models_test.dart                  # 单元测试
```

## 🔧 开发

### 平台适配指南

每个桌面平台需要实现一个 MethodChannel 处理器：

```dart
// lib/core/platform/xxx_proxy_channel.dart
class XxxProxyChannel {
  static const _channel = MethodChannel('com.pclash.app/proxy');

  static Future<bool> setSystemProxy({
    required bool enabled,
    required int port,
  }) async {
    return await _channel.invokeMethod<bool>('setSystemProxy', {
      'enabled': enabled,
      'port': port,
    }) ?? false;
  }
}
```

原生端实现：
- **macOS**: Swift → SystemConfiguration.framework
- **Windows**: C++ → Windows Registry (Internet Settings)
- **Linux**: Bash → gsettings / kwriteconfig5

### API 端点

PClash 通过 Mihomo 的 `external-controller` API 控制内核：

| 端点 | 方法 | 说明 |
|------|------|------|
| `/proxies` | GET | 获取所有代理节点 |
| `/proxies/{name}` | PUT | 选择节点 |
| `/proxies/{name}/delay` | GET | 测试延迟 |
| `/configs` | GET/PATCH | 获取/修改配置 |
| `/traffic` | WS | 实时流量 |
| `/connections` | WS | 连接信息 |
| `/logs` | WS | 实时日志 |

详见 [Mihomo API 文档](https://wiki.metacubex.one/en/api)

## 🤝 订阅集成

PClash 原生支持标准订阅格式：

1. 获取你的订阅 URL
2. 在 PClash → 订阅 页面添加 URL
3. 自动解析节点、流量信息、过期时间

## 🔐 安全设计

| 安全措施 | 实现 |
|----------|------|
| API 认证 | 随机生成的 Bearer token |
| 网络暴露 | API 仅绑定 127.0.0.1 |
| 文件权限 | 配置存储在应用沙箱内 |
| 路径遍历防护 | `SecurityUtils.sanitizePath()` |
| URL 验证 | 仅允许 http/https 协议 |
| YAML 注入防护 | 内容白名单验证 |
| 进程超时 | 10 秒启动超时保护 |
| 资源清理 | 断开时完整释放所有资源 |

## 📄 隐私政策

PClash 不收集任何用户数据。

## 📄 许可证

GPL-3.0 License

Copyright © 2024-2026 PClash Contributors

---

**Powered by Mihomo · Built with Flutter**
