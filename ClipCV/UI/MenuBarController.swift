import AppKit
import SwiftData

@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let settings: AppSettings
    private let monitor: ClipboardMonitor
    private let actions = HistoryActions()
    private let panelController: HistoryPanelController
    private let settingsPopover: SettingsPopoverController
    private var ignoreNextToggle = false

    init(settings: AppSettings, monitor: ClipboardMonitor, container: ModelContainer) {
        self.settings = settings
        self.monitor = monitor
        panelController = HistoryPanelController(settings: settings, actions: actions, container: container)
        settingsPopover = SettingsPopoverController(settings: settings, container: container)
        super.init()
        panelController.anchorButton = statusItem.button
        panelController.onAnchorClick = { [weak self] in
            self?.ignoreNextToggle = true
        }
        panelController.onDidHide = { [weak self] in
            self?.refreshAppearance()
        }
        settingsPopover.onDidClose = { [weak self] in
            self?.refreshAppearance()
        }
        SettingsPresenter.register(
            open: { [weak self] in self?.showSettings() },
            close: { [weak self] in self?.settingsPopover.hide() }
        )
        wireActions()
        configureStatusItem()
        settings.onPausedChanged = { [weak self] in
            self?.refreshAppearance()
        }
        settings.onStatusBarAppearanceChanged = { [weak self] in
            self?.refreshAppearance()
        }
    }

    func togglePanel(at anchor: PanelAnchor = .cursor, cycleIfVisible: Bool = false) {
        settingsPopover.hide()
        if panelController.panel.isVisible {
            if cycleIfVisible {
                actions.cycleRequest = UUID()
            } else {
                panelController.hide()
            }
        } else {
            actions.presentationID = UUID()
            panelController.show(at: anchor)
        }
        refreshAppearance()
    }

    func showSettings() {
        panelController.hide()
        guard let button = statusItem.button else { return }
        settingsPopover.show(relativeTo: button)
        refreshAppearance()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        refreshAppearance()
    }

    private func wireActions() {
        wireClipboardActions()
        wirePanelActions()
        wireAppActions()
    }

    private func wireClipboardActions() {
        actions.copy = { [weak self] item in
            self?.copy(item, thenPaste: false, plain: false)
        }
        actions.paste = { [weak self] item in
            self?.copy(item, thenPaste: true, plain: false)
        }
        actions.pastePlain = { [weak self] item in
            self?.copy(item, thenPaste: true, plain: true)
        }
        actions.delete = { [weak self] items in
            self?.monitor.delete(items)
        }
        actions.applyEdit = { [weak self] item, alias, content, pinKey in
            self?.monitor.applyEdit(item, alias: alias, content: content, pinKey: pinKey) ?? .saved
        }
        actions.copyText = { [weak self] text in
            guard let self, !text.isEmpty else { return }
            ClipboardWriter.write([
                ClipboardPayload(type: ClipboardRules.Kind.string, data: Data(text.utf8)),
            ])
            monitor.notePasteboardChangedByUs()
        }
        actions.recognizeOCR = { [weak self] item in
            await self?.monitor.recognizeOCR(for: item)
        }
        actions.togglePin = { [weak self] item in
            self?.monitor.togglePin(item)
        }
        actions.reorderPin = { [weak self] moving, before in
            self?.monitor.reorderPins(moving: moving, before: before)
        }
        actions.clear = { [weak self] includingPinned in
            self?.monitor.clear(includingPinned: includingPinned)
        }
    }

    private func wirePanelActions() {
        actions.hideForDrag = { [weak self] in
            self?.panelController.hideForDrag()
            self?.refreshAppearance()
        }
        actions.showAfterDrag = { [weak self] in
            self?.actions.presentationID = UUID()
            self?.panelController.showAfterDrag()
            self?.refreshAppearance()
        }
        actions.setSuppressAutoClose = { [weak self] suppress in
            self?.panelController.panel.suppressAutoClose = suppress
        }
        actions.close = { [weak self] in
            self?.panelController.hide()
            self?.refreshAppearance()
        }
        actions.resizePanelForContent = { [weak self] count in
            self?.panelController.resizeForContent(itemCount: count)
        }
        actions.resizePanelForPreview = { [weak self] expanded in
            guard let self else { return }
            actions.previewLeading = panelController.setExpandedForPreview(expanded)
        }
    }

    private func wireAppActions() {
        actions.openSettings = { [weak self] in
            self?.showSettings()
        }
        actions.quit = {
            NSApp.terminate(nil)
        }
    }

    private func copy(_ item: ClipboardItem, thenPaste: Bool, plain: Bool) {
        let payloads = plain ? ClipboardRules.payloadsRemovingFormatting(item.payloads) : item.payloads
        guard !payloads.isEmpty else { return }
        ClipboardWriter.write(payloads)
        monitor.notePasteboardChangedByUs()
        panelController.hide()
        monitor.recordUse(of: item)
        refreshAppearance()
        guard thenPaste else { return }
        guard PasteService.isTrusted(prompt: false)
            || (PasteService.isTrusted(prompt: true) && PasteService.isTrusted(prompt: false))
        else {
            presentAccessibilityAlert(plain: plain)
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            PasteService.sendPaste()
        }
    }

    private func presentAccessibilityAlert(plain: Bool) {
        let alert = NSAlert()
        alert.messageText = L10n.t(.needsAccessibility)
        alert.informativeText = plain ? L10n.t(.accessibilityCopiedPlain) : L10n.t(.accessibilityCopied)
        alert.addButton(withTitle: L10n.t(.systemSettings))
        alert.addButton(withTitle: L10n.t(.ok))
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn {
            PasteService.openAccessibilitySettings()
        }
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let flags = event?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
        guard event?.type != .rightMouseUp else {
            ignoreNextToggle = false
            showMenu()
            return
        }
        guard !ignoreNextToggle else {
            ignoreNextToggle = false
            refreshAppearance()
            return
        }
        if flags.contains(.option), flags.contains(.shift) {
            settings.ignoreNext = true
            refreshAppearance()
            return
        }
        guard !flags.contains(.option) else {
            settings.paused.toggle()
            return
        }
        togglePanel(at: .statusItem)
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(item(L10n.t(.showHistory), action: #selector(showHistory)))
        let pause = item(settings.paused ? L10n.t(.resumeRecording) : L10n.t(.pauseRecording), action: #selector(togglePause))
        pause.state = settings.paused ? .on : .off
        menu.addItem(pause)
        menu.addItem(item(L10n.t(.ignoreNextCopy), action: #selector(ignoreNextCopy)))
        menu.addItem(.separator())
        menu.addItem(item(L10n.t(.clearUnpinned), action: #selector(clearUnpinned)))
        menu.addItem(item(L10n.t(.clearEverything), action: #selector(clearAll)))
        menu.addItem(.separator())
        menu.addItem(item(L10n.t(.settings), action: #selector(openSettings)))
        menu.addItem(item(L10n.t(.quitApp), action: #selector(quit)))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func item(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func showHistory() {
        guard !panelController.panel.isVisible else { return }
        togglePanel(at: .statusItem)
    }

    @objc private func togglePause() {
        settings.paused.toggle()
    }

    @objc private func ignoreNextCopy() {
        settings.ignoreNext = true
        refreshAppearance()
    }

    @objc private func clearUnpinned() {
        monitor.clear(includingPinned: false)
    }

    @objc private func clearAll() {
        monitor.clear(includingPinned: true)
    }

    @objc private func openSettings() {
        showSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func refreshAppearance() {
        statusItem.isVisible = settings.showInStatusBar
        guard let button = statusItem.button else { return }
        button.image = statusItemImage()
        button.appearsDisabled = settings.paused
        if settings.showRecentCopyInMenuBar,
           let latest = try? AppRuntime.container.mainContext.fetch(
            FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
           ).first {
            statusItem.length = NSStatusItem.variableLength
            button.title = " " + String(latest.title.prefix(18))
        } else {
            statusItem.length = NSStatusItem.squareLength
            button.title = ""
        }
        button.toolTip = settings.ignoreNext
            ? L10n.t(.ignoreNextTooltip)
            : settings.paused ? L10n.t(.pausedTooltip) : "ClipCV  \(settings.hotkey.display)"
        button.isHighlighted = panelController.panel.isVisible || settingsPopover.isShown
    }

    /// Menu bar icons are template images so macOS tints them for light/dark menu bar.
    private func statusItemImage() -> NSImage? {
        if settings.paused {
            return NSImage(systemSymbolName: "pause.circle", accessibilityDescription: "ClipCV")
        }
        if let symbol = settings.menuIcon.systemImage {
            return NSImage(systemSymbolName: symbol, accessibilityDescription: "ClipCV")
        }
        guard let image = NSImage(named: "MenuBarIcon") else {
            return NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipCV")
        }
        let icon = image.copy() as? NSImage ?? image
        icon.isTemplate = true
        icon.size = NSSize(width: 18, height: 18)
        return icon
    }
}
