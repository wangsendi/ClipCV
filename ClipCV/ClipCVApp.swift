//
//  ClipCVApp.swift
//  ClipCV
//

import AppKit
import SwiftData
import SwiftUI

@main
struct ClipCVApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // SwiftUI App requires a Scene; real prefs live in SettingsPopoverController.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController!
    private var hotkeys: HotkeyManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let settings = AppSettings.shared
        let monitor = ClipboardMonitor(context: AppRuntime.container.mainContext, settings: settings)
        AppRuntime.monitor = monitor
        monitor.start()
        menuBar = MenuBarController(settings: settings, monitor: monitor, container: AppRuntime.container)
        hotkeys = HotkeyManager()
        hotkeys.onPressed = { [weak menuBar] in
            menuBar?.togglePanel(at: .cursor, cycleIfVisible: true)
        }
        hotkeys.register(settings.hotkey)
        settings.onHotkeyChanged = { [weak hotkeys] hotkey in
            hotkeys?.register(hotkey)
        }
        settings.onCaptureChanged = { [weak hotkeys] capturing in
            guard let hotkeys else { return }
            capturing ? hotkeys.unregister() : hotkeys.register(settings.hotkey)
        }
        // Keep a strong reference so Sparkle auto-checks from launch (not only when Settings opens).
        _ = SoftwareUpdater.shared
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppRuntime.monitor?.clearUnpinnedOnQuit()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
