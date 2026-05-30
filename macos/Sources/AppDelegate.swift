import Foundation
import Cocoa

/// macOS App Delegate - handles tray icon, menu bar, and lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupTrayIcon()
    }
    
    /// Set up system tray/menu bar icon
    private func setupTrayIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "PClash")
            button.target = self
            button.action = #selector(statusItemClicked)
        }
        
        // Set up menu
        let menu = NSMenu()
        
        // Connection status item
        let statusItem = NSMenuItem(title: "🟢 已连接", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quick toggle
        let toggleItem = NSMenuItem(title: "断开连接", action: #selector(toggleConnection), keyEquivalent: "")
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Open app
        let openItem = NSMenuItem(title: "打开 PClash", action: #selector(openApp), keyEquivalent: "")
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc func statusItemClicked() {
        statusItem?.button?.performClick(nil)
    }
    
    @objc func toggleConnection() {
        // TODO: Send event to Flutter via MethodChannel
    }
    
    @objc func openApp() {
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up mihomo process on quit
    }
}
