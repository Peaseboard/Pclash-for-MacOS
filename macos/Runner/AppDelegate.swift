import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  
  private var statusItem: NSStatusItem!
  private var statusMenu: NSMenu!
  private var channel: FlutterMethodChannel?
  private var proxyChannel: FlutterMethodChannel?
  
  // Menu state
  private var isSystemProxyEnabled = false
  private var proxyGroups: [(name: String, nodes: [String])] = []
  private var currentMode = "rule"
  private var trafficUp = "0 B"
  private var trafficDown = "0 B"

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    
    NSApp.setActivationPolicy(.regular)
    NSApplication.shared.mainMenu = createMainMenu()
    
    // Setup Flutter channels
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      // Status Bar Channel
      channel = FlutterMethodChannel(name: "com.pclash.app/status_bar", binaryMessenger: controller.engine.binaryMessenger)
      channel?.setMethodCallHandler { [weak self] call, result in
        self?.handleStatusBarMethodCall(call, result: result)
      }
      
      // System Proxy Channel
      proxyChannel = FlutterMethodChannel(name: "com.pclash.app/proxy", binaryMessenger: controller.engine.binaryMessenger)
      proxyChannel.setMethodCallHandler { [weak self] call, result in
        self?.handleProxyMethod(call, result: result)
      }
    }
    
    // Setup status bar immediately (synchronously)
    setupStatusBar()
  }
  
  private func handleStatusBarMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "updateProxyGroups":
      if let args = call.arguments as? [String: Any],
         let groups = args["groups"] as? [[String: Any]] {
        proxyGroups.removeAll()
        for group in groups {
          let name = group["name"] as? String ?? "Unknown"
          let nodes = group["nodes"] as? [String] ?? []
          proxyGroups.append((name: name, nodes: nodes))
        }
        rebuildStatusMenu()
      }
      result(nil)
    case "updateTraffic":
      if let args = call.arguments as? [String: Any] {
        trafficUp = args["up"] as? String ?? "0 B"
        trafficDown = args["down"] as? String ?? "0 B"
        rebuildStatusMenu()
      }
      result(nil)
    case "updateMode":
      if let mode = call.arguments as? String {
        currentMode = mode
        rebuildStatusMenu()
      }
      result(nil)
    case "setProxyEnabled":
      if let enabled = call.arguments as? Bool {
        isSystemProxyEnabled = enabled
        rebuildStatusMenu()
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  // --- System Proxy Implementation ---
  private func handleProxyMethod(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setSystemProxy":
      if let args = call.arguments as? [String: Any],
         let enabled = args["enabled"] as? Bool,
         let port = args["port"] as? Int {
        setSystemProxy(enabled: enabled, port: port, result: result)
      } else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func setSystemProxy(enabled: Bool, port: Int, result: @escaping FlutterResult) {
    // Get all network services
    let listTask = Process()
    listTask.launchPath = "/usr/sbin/networksetup"
    listTask.arguments = ["-listallnetworkservices"]
    let pipe = Pipe()
    listTask.standardOutput = pipe
    listTask.launch()
    listTask.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
      let services = output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && $0 != "*" }
      
      var successCount = 0
      for service in services {
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        if enabled {
          // Set Web and Secure Web Proxy
          task.arguments = ["-setwebproxy", service, "127.0.0.1", "\(port)", "-setsecurewebproxy", service, "127.0.0.1", "\(port)"]
        } else {
          // Disable Proxies
          task.arguments = ["-setwebproxystate", service, "off", "-setsecurewebproxystate", service, "off"]
        }
        
        let errorPipe = Pipe()
        task.standardError = errorPipe
        task.launch()
        task.waitUntilExit()
        
        if task.terminationStatus == 0 {
          successCount += 1
        }
      }
      
      if successCount > 0 {
        result(nil)
      } else {
        result(FlutterError(code: "PROXY_FAILED", message: "Failed to set proxy on any interface", details: nil))
      }
    } else {
      result(FlutterError(code: "LIST_FAILED", message: "Could not list network services", details: nil))
    }
  }
  // ----------------------------------
  
  private func setupStatusBar() {
    print("PClash: Setting up status bar...")
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    // Fallback to text first
    statusItem.button?.title = "PClash"
    statusItem.button?.font = NSFont.boldSystemFont(ofSize: 12)
    
    // Try to load icon
    if let iconImage = NSImage(named: "AppIcon") {
      iconImage.size = NSSize(width: 16, height: 16)
      iconImage.isTemplate = false // Show color
      statusItem.button?.image = iconImage
      statusItem.button?.title = "" // Clear text if icon loaded
      print("PClash: Status bar icon loaded successfully.")
    } else {
      print("PClash: Warning - Could not load AppIcon for status bar.")
    }
    
    rebuildStatusMenu()
    print("PClash: Status bar menu assigned.")
  }
  
  private func rebuildStatusMenu() {
    statusMenu = NSMenu()
    
    // Status
    let statusTitle = isSystemProxyEnabled ? "✅ 系统代理已开启" : " 系统代理未开启"
    let statusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
    statusItem.isEnabled = false
    statusMenu.addItem(statusItem)
    statusMenu.addItem(NSMenuItem.separator())
    
    // Toggle
    let toggleTitle = isSystemProxyEnabled ? "关闭系统代理" : "开启系统代理"
    let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleSystemProxy), keyEquivalent: "")
    toggleItem.target = self
    statusMenu.addItem(toggleItem)
    statusMenu.addItem(NSMenuItem.separator())
    
    // Mode
    let modeLabel = NSMenuItem(title: "代理模式: \(currentMode.uppercased())", action: nil, keyEquivalent: "")
    modeLabel.isEnabled = false
    statusMenu.addItem(modeLabel)
    
    let modeMenu = NSMenu()
    for mode in ["rule", "global", "direct"] {
      let modeItem = NSMenuItem(title: mode.uppercased(), action: #selector(changeMode(_:)), keyEquivalent: "")
      modeItem.target = self
      modeItem.representedObject = mode
      if mode == currentMode { modeItem.state = .on }
      modeMenu.addItem(modeItem)
    }
    let modeSelector = NSMenuItem(title: "模式", action: nil, keyEquivalent: "")
    modeSelector.submenu = modeMenu
    statusMenu.addItem(modeSelector)
    statusMenu.addItem(NSMenuItem.separator())
    
    // Groups
    for group in proxyGroups {
      let groupMenu = NSMenu()
      for node in group.nodes.prefix(20) {
        let nodeItem = NSMenuItem(title: node, action: #selector(selectProxy(_:)), keyEquivalent: "")
        nodeItem.target = self
        nodeItem.representedObject = ["group": group.name, "node": node]
        groupMenu.addItem(nodeItem)
      }
      let groupSelector = NSMenuItem(title: group.name, action: nil, keyEquivalent: "")
      groupSelector.submenu = groupMenu
      statusMenu.addItem(groupSelector)
    }
    
    if !proxyGroups.isEmpty { statusMenu.addItem(NSMenuItem.separator()) }
    
    // Traffic
    let trafficTitle = "↑ \(trafficUp)  ↓ \(trafficDown)"
    let trafficItem = NSMenuItem(title: trafficTitle, action: nil, keyEquivalent: "")
    trafficItem.isEnabled = false
    statusMenu.addItem(trafficItem)
    statusMenu.addItem(NSMenuItem.separator())
    
    // Actions
    let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
    settingsItem.target = self
    statusMenu.addItem(settingsItem)
    
    let quitItem = NSMenuItem(title: "退出 PClash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    statusMenu.addItem(quitItem)
    
    statusItem.menu = statusMenu
  }
  
  @objc private func toggleSystemProxy() {
    isSystemProxyEnabled.toggle()
    rebuildStatusMenu()
    channel?.invokeMethod("onToggleProxy", arguments: isSystemProxyEnabled)
  }
  
  @objc private func changeMode(_ sender: NSMenuItem) {
    if let mode = sender.representedObject as? String {
      currentMode = mode
      rebuildStatusMenu()
      channel?.invokeMethod("onChangeMode", arguments: mode)
    }
  }
  
  @objc private func selectProxy(_ sender: NSMenuItem) {
    if let info = sender.representedObject as? [String: String] {
      channel?.invokeMethod("onSelectProxy", arguments: info)
    }
  }
  
  @objc private func openSettings() {
    NSApp.activate(ignoringOtherApps: true)
    mainFlutterWindow?.makeKeyAndOrderFront(nil)
    channel?.invokeMethod("onOpenSettings", arguments: nil)
  }
  
  private func createMainMenu() -> NSMenu {
    let mainMenu = NSMenu(title: "PClash")
    
    // App
    let appItem = NSMenuItem()
    let appMenu = NSMenu(title: "PClash")
    appMenu.addItem(NSMenuItem(title: "关于 PClash", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(NSMenuItem(title: "设置…", action: nil, keyEquivalent: ","))
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(NSMenuItem(title: "退出 PClash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    appItem.submenu = appMenu
    mainMenu.addItem(appItem)
    
    // File
    let fileItem = NSMenuItem()
    let fileMenu = NSMenu(title: "文件")
    fileMenu.addItem(NSMenuItem(title: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
    fileItem.submenu = fileMenu
    mainMenu.addItem(fileItem)
    
    // Edit (Removed undo/redo)
    let editItem = NSMenuItem()
    let editMenu = NSMenu(title: "编辑")
    editMenu.addItem(NSMenuItem(title: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
    editMenu.addItem(NSMenuItem(title: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
    editMenu.addItem(NSMenuItem(title: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
    editMenu.addItem(NSMenuItem(title: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
    editItem.submenu = editMenu
    mainMenu.addItem(editItem)
    
    // View
    let viewItem = NSMenuItem()
    let viewMenu = NSMenu(title: "显示")
    viewMenu.addItem(NSMenuItem(title: "全屏", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f"))
    viewItem.submenu = viewMenu
    mainMenu.addItem(viewItem)
    
    // Window
    let windowItem = NSMenuItem()
    let windowMenu = NSMenu(title: "窗口")
    windowMenu.addItem(NSMenuItem(title: "最小化", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
    windowMenu.addItem(NSMenuItem(title: "缩放", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
    windowItem.submenu = windowMenu
    mainMenu.addItem(windowItem)
    
    // Help
    let helpItem = NSMenuItem()
    let helpMenu = NSMenu(title: "帮助")
    helpMenu.addItem(NSMenuItem(title: "PClash 帮助", action: nil, keyEquivalent: ""))
    helpItem.submenu = helpMenu
    mainMenu.addItem(helpItem)
    
    return mainMenu
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}