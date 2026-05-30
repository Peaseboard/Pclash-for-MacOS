# PClash 开发指南

## 项目架构

```
┌─────────────────────────────────────────────┐
│              Flutter UI Layer                │
│  ┌──────────┬──────────┬──────────────────┐  │
│  │ 首页     │ 节点页   │ 订阅页/设置页    │  │
│  └────┬─────┴────┬─────┴────────┬─────────┘  │
│       └──────────┴──────────────┘             │
│              ↕ Riverpod Providers             │
├───────────────────────────────────────────────┤
│            Business Logic Layer                │
│  ┌──────────────┐  ┌───────────────────────┐  │
│  │ConnectionMgr │  │ SubscriptionManager   │  │
│  └──────┬───────┘  └───────────┬───────────┘  │
│         └───────────┬──────────┘              │
│              ↕ MihomoApi (REST + WS)          │
├───────────────────────────────────────────────┤
│              Core Layer                        │
│  ┌──────────────────────────────────────────┐  │
│  │        MihomoManager                     │  │
│  │  • Process lifecycle (start/stop)        │  │
│  │  • Config generation                     │  │
│  │  • Binary management                     │  │
│  └──────────────────────────────────────────┘  │
├───────────────────────────────────────────────┤
│            Platform Layer                      │
│  ┌──────────────────┬─────────────────────┐    │
│  │  macOS           │  Android            │    │
│  │  ProxyHelper     │  VpnChannel         │    │
│  │  (System Proxy)  │  (VpnService+TUN)   │    │
│  └──────────────────┴─────────────────────┘    │
└─────────────────────────────────────────────────┘
```

## 数据流

```
用户点击"连接"
  ↓
ConnectionNotifier.connect()
  ↓
1. 加载订阅 → SubscriptionManager.fetch()
2. 生成配置 → ConfigManager.generateConfig()
3. 启动内核 → MihomoManager.start()
4. 建立 API 连接 → MihomoApi
5. 平台适配 → VpnChannel (Android) / ProxyHelper (macOS)
6. 启动流量监控 → trafficStream()
  ↓
连接成功，UI 更新
```

## 安全设计

### 1. API 安全
- 每个实例使用随机生成的 secret
- API 仅绑定 127.0.0.1，不暴露到网络
- 使用 Bearer token 认证

### 2. 文件安全
- 配置文件存储在应用沙箱内
- 启动前验证文件权限
- 防止目录遍历攻击

### 3. 进程安全
- Mihomo 以最小权限运行
- 进程崩溃自动清理
- 超时保护（10 秒启动超时）

### 4. 订阅安全
- URL 格式验证
- YAML 内容注入防护
- 超时和大小限制

## 添加新平台

1. 在 `lib/core/platform/` 创建平台通道封装
2. 在对应平台原生代码实现 MethodChannel
3. 在 `ConnectionNotifier` 中集成
4. 更新 `build.sh` 支持新平台

## 调试

```bash
# 查看日志
flutter logs

# Android 日志
adb logcat | grep -i pclash

# macOS 日志
log stream --predicate 'process == "pclash"'
```

## 发布检查清单

- [ ] 所有测试通过
- [ ] 构建无警告
- [ ] 订阅功能正常
- [ ] 各协议连通性测试
- [ ] 内存泄漏检查
- [ ] 崩溃报告集成
- [ ] 隐私政策更新
- [ ] 版本号递增
