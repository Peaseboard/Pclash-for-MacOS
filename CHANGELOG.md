# Changelog

All notable changes to PClash will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-05-28

### Added
- 🎉 项目初始化
- Flutter UI 框架（Material 3、暗色主题）
- Mihomo REST API 完整客户端
- Mihomo 进程生命周期管理（启动/停止/重启）
- 订阅管理（添加/删除/刷新）
- 实时流量监控（WebSocket）
- 节点选择与延迟测试
- 代理模式切换（规则/全局/直连）
- Riverpod 状态管理
- 本地配置持久化
- 安全工具（随机密钥、路径验证、URL 校验）
- 应用日志系统
- 单元测试（模型层）
- 构建脚本（build.sh）

### Platform Support
- ✅ macOS (Apple Silicon + Intel) — 系统代理模式 + 菜单栏托盘
- ✅ Android (arm64-v8a + x86_64) — VpnService + TUN 模式
- ✅ Windows (x64) — 注册表系统代理 + 开机自启
- ✅ Linux (x86_64 + ARM) — gsettings/kde 系统代理 + systemd 自启

### Platform Features
| 平台 | 代理模式 | 托盘 | 开机自启 | 构建状态 |
|------|----------|------|----------|----------|
| macOS | SystemConfiguration | ✅ NSStatusItem | ✅ LaunchAgent | 🟡 开发中 |
| Android | VpnService + TUN | ✅ Notification | ✅ BootReceiver | 🟡 开发中 |
| Windows | Registry (Internet Settings) | ⬜ 计划中 | ✅ Registry Run | 🟡 开发中 |
| Linux | gsettings / kwriteconfig5 | ⬜ 计划中 | ✅ systemd user | 🟡 开发中 |

### Security
- API 认证：随机生成的 Bearer token
- 网络暴露：API 仅绑定 127.0.0.1
- 文件权限：配置存储在应用沙箱内
- 路径遍历防护：`SecurityUtils.sanitizePath()`
- URL 验证：仅允许 http/https 协议
- YAML 注入防护：内容白名单验证
- 进程超时：10 秒启动超时保护
- 资源清理：断开时完整释放所有资源

### Included
- Mihomo v1.19.25 内核二进制（macOS + Android）
- 隐私政策页面（https://www.your-domain.com/privacy/）
- 完整构建配置（Android Gradle + CMake）
- ProGuard 混淆规则

### 协议支持（通过 Mihomo 内核）
| 协议 | 状态 |
|------|------|
| Shadowsocks (R) | ✅ |
| VMess | ✅ |
| VLESS | ✅ |
| Trojan | ✅ |
| Hysteria 1/2 | ✅ |
| TUIC v5 | ✅ |
| Snell | ✅ |
| WireGuard | ✅ |
| SOCKS5/HTTP 代理 | ✅ |
