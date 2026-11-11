import AppKit
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(AppSettings.self) private var settings
    @Query(sort: \ClipboardItem.createdAt, order: .reverse) private var items: [ClipboardItem]
    @State private var query = ""
    @State private var category: HistoryTypeFilter = .all
    @State private var sourceAppFilter: String?

    private var pinnedItems: [ClipboardItem] {
        matchingFilters(items.filter(\.pinned)).sorted { $0.pinOrder < $1.pinOrder }
    }
    private var unpinnedFiltered: [ClipboardItem] {
        let matching = matchingFilters(items.filter { !$0.pinned })
        // 查询已按最近复制排序，避免重复排序。
        return settings.sortMode == .lastCopiedAt ? matching : matching.sorted(by: sortUnpinned)
    }
    private var sourceApps: [String] { ClipboardRules.sourceApps(from: items) }

    // 选择变化留在子视图，避免每次按键都重新筛选整份历史。
    var body: some View {
        HistoryContentView(
            items: items, pinnedItems: pinnedItems, unpinnedFiltered: unpinnedFiltered,
            sourceApps: sourceApps, query: $query, category: $category,
            sourceAppFilter: $sourceAppFilter
        )
    }

    private func matchingFilters(_ source: [ClipboardItem]) -> [ClipboardItem] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return source.filter {
            category.matches($0)
                && (sourceAppFilter == nil || $0.sourceApp == sourceAppFilter)
                && (keyword.isEmpty || SearchService.matches($0, query: keyword, mode: settings.searchMode))
        }
    }

    private func sortUnpinned(_ lhs: ClipboardItem, _ rhs: ClipboardItem) -> Bool {
        switch settings.sortMode {
        case .lastCopiedAt: return lhs.createdAt > rhs.createdAt
        case .firstCopiedAt: return lhs.firstCopiedAt > rhs.firstCopiedAt
        case .numberOfCopies:
            return lhs.numberOfCopies == rhs.numberOfCopies
                ? lhs.createdAt > rhs.createdAt
                : lhs.numberOfCopies > rhs.numberOfCopies
        }
    }
}

private struct HistoryContentView: View {
    @Environment(HistoryActions.self) private var actions
    @Environment(AppSettings.self) private var settings
    let items: [ClipboardItem]
    let pinnedItems: [ClipboardItem]
    let unpinnedFiltered: [ClipboardItem]
    let sourceApps: [String]
    @Binding var query: String
    @Binding var category: HistoryTypeFilter
    @Binding var sourceAppFilter: String?

    @State private var selectedIndex = 0
    @State private var selectedIDs: Set<UUID> = []
    @State private var optionHeld = false
    @State private var shiftHeld = false
    @State private var commandHeld = false
    @FocusState private var searchFocused: Bool
    @State private var keyMonitor: Any?
    @State private var flagsMonitor: Any?
    @State private var previewVisible = false
    @State private var previewPinned = false
    @State private var previewTask: Task<Void, Never>?
    @State private var pendingSelectionID: UUID?
    @State private var keyboardNavigating = false
    @State private var scrollToID: UUID?
    @State private var mouseMoveMonitor: Any?
    @State private var isPreviewEditing = false

    private var canReorderPins: Bool { query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var filtered: [ClipboardItem] {
        settings.pinTo == .top ? pinnedItems + unpinnedFiltered : unpinnedFiltered + pinnedItems
    }
    private var selectedItem: ClipboardItem? {
        let current = filtered
        return current.indices.contains(selectedIndex) ? current[selectedIndex] : nil
    }
    private var selectedItems: [ClipboardItem] {
        filtered.filter { selectedIDs.contains($0.identifier) }
    }
    private var showsSearchField: Bool {
        guard settings.showSearch else { return false }
        return settings.searchVisibility != .duringSearch || !query.isEmpty || searchFocused
    }

    // 分离布局与事件，避免主视图同时承担多种职责。
    var body: some View {
        let _ = settings.appLanguage
        panelContent
            .onChange(of: isPreviewEditing) { _, editing in
                actions.setSuppressAutoClose(editing)
                if !editing { searchFocused = true }
            }
            .onAppear {
                searchFocused = true
                installMonitors()
                resetSelection(clearFilters: false)
            }
            .onDisappear {
                removeMonitors()
                previewTask?.cancel()
                setPreviewVisible(false, pinned: false)
            }
            .onChange(of: actions.presentationID) { _, _ in resetSelection(clearFilters: true) }
            .onChange(of: category) { _, _ in resetSelection() }
            .onChange(of: sourceAppFilter) { _, _ in resetSelection() }
            .onChange(of: query) { _, _ in resetSelection() }
            .onChange(of: selectedIndex) { _, _ in
                isPreviewEditing = false
                scheduleAutoPreview()
            }
            .onChange(of: actions.cycleRequest) { _, _ in
                guard !filtered.isEmpty else { return }
                moveSelection(1, wrap: true)
                scheduleAutoPreview()
            }
            .onChange(of: filtered.count) { _, count in updateSelection(itemCount: count) }
            // 结果改变后更新事件闭包，让快捷键始终使用当前列表。
            .onChange(of: filtered) { _, _ in
                removeMonitors()
                installMonitors()
            }
            .onChange(of: pinnedItems.map(\.identifier)) { _, _ in restorePinSelection() }
    }

    private var panelContent: some View {
        ZStack {
            PopupBackground()
            HStack(alignment: .top, spacing: 0) {
                if previewVisible, let item = selectedItem, actions.previewLeading {
                    previewColumn(item)
                    previewDivider
                }
                listColumn
                    .frame(width: PopupStyle.listWidth)
                    .frame(maxHeight: .infinity)
                if previewVisible, let item = selectedItem, !actions.previewLeading {
                    previewDivider
                    previewColumn(item)
                }
            }
            // 预览展开时固定列表位置，避免选中行随窗口移动。
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: actions.previewLeading ? .trailing : .leading
            )
            .clipped()
        }
        .frame(
            minWidth: PopupStyle.listWidth,
            maxWidth: .infinity,
            minHeight: PopupStyle.preferredHeight(itemCount: filtered.count),
            maxHeight: .infinity
        )
    }

    private func updateSelection(itemCount count: Int) {
        if count == 0 {
            selectedIndex = 0
            selectedIDs = []
            setPreviewVisible(false, pinned: false)
        } else if selectedIndex >= count {
            selectIndex(count - 1, scroll: true, lockHover: true)
        }
        actions.resizePanelForContent(count)
        actions.resizePanelForPreview(previewVisible && selectedItem != nil)
    }

    // 置顶会改变记录位置，按 ID 恢复选择。
    private func restorePinSelection() {
        guard let id = pendingSelectionID,
              let index = filtered.firstIndex(where: { $0.identifier == id })
        else { return }
        selectIndex(index, scroll: true, lockHover: true)
        pendingSelectionID = nil
    }

    private func previewColumn(_ item: ClipboardItem) -> some View {
        ItemPreviewPane(
            item: item,
            usedPinKeys: Set(
                items.compactMap { other -> String? in
                    guard other.identifier != item.identifier, other.pinned else { return nil }
                    return other.pinKey
                }
            ),
            isEditing: $isPreviewEditing,
            onSave: { alias, content, pinKey in
                actions.applyEdit(item, alias, content, pinKey)
            },
            onPin: { togglePinSelection() },
            onDelete: { deleteSelection() },
            onOCR: {
                guard let text = await actions.recognizeOCR(item) else { return }
                actions.copyText(text)
            }
        )
        .frame(width: PopupStyle.previewWidth)
        .frame(maxHeight: .infinity)
    }

    private var listColumn: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, PopupStyle.verticalPadding)
                .padding(.horizontal, 10)
                .fixedSize(horizontal: false, vertical: true)

            historyBody
                .padding(.horizontal, PopupStyle.horizontalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Divider()
                .padding(.horizontal, PopupStyle.horizontalPadding + 4)
            HistoryTypeBar(selection: $category, sourceApp: $sourceAppFilter, apps: sourceApps, totalCount: items.count)
                .padding(.horizontal, PopupStyle.horizontalPadding + 4)
                .padding(.bottom, PopupStyle.verticalPadding)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // 置顶区不参与滚动，避免键盘定位影响布局。
    private var historyBody: some View {
        Group {
            if filtered.isEmpty {
                Text(items.isEmpty ? L10n.t(.noHistory) : L10n.t(.noMatches))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 16)
            } else {
                VStack(spacing: 0) {
                    if settings.pinTo == .top, !pinnedItems.isEmpty {
                        pinSection(baseIndex: 0, topPadding: true)
                        if !unpinnedFiltered.isEmpty { pinDivider }
                    }

                    if !unpinnedFiltered.isEmpty {
                        unpinnedScroll
                    } else {
                        Spacer(minLength: 0)
                    }

                    if settings.pinTo == .bottom, !pinnedItems.isEmpty {
                        if !unpinnedFiltered.isEmpty { pinDivider }
                        pinSection(baseIndex: unpinnedFiltered.count, topPadding: false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private var pinDivider: some View {
        Divider()
            .padding(.horizontal, PopupStyle.horizontalSeparatorPadding)
            .padding(.vertical, PopupStyle.verticalSeparatorPadding)
    }

    private func pinSection(baseIndex: Int, topPadding: Bool) -> some View {
        itemRows(pinnedItems, baseIndex: baseIndex, reorderable: canReorderPins)
            .padding(.top, topPadding ? PopupStyle.verticalSeparatorPadding : 0)
            .padding(.bottom, topPadding ? 0 : PopupStyle.verticalSeparatorPadding)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var unpinnedScroll: some View {
        ScrollView {
            ScrollViewReader { proxy in
                LazyVStack(spacing: 0) {
                    itemRows(
                        unpinnedFiltered,
                        baseIndex: settings.pinTo == .top ? pinnedItems.count : 0
                    )
                }
                .padding(
                    .top,
                    (settings.pinTo == .top && !pinnedItems.isEmpty)
                        ? 0
                        : PopupStyle.verticalSeparatorPadding
                )
                .padding(.bottom, PopupStyle.verticalSeparatorPadding)
                // 连续按键不加滚动动画，避免选择落后于输入。
                .onChange(of: scrollToID) { _, id in
                    guard let id else { return }
                    proxy.scrollTo(id)
                    scrollToID = nil
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 8) {
            if settings.showTitle { titleButton }
            if showsSearchField {
                searchField
            } else {
                Spacer(minLength: 0)
            }
            clearMenu
        }
    }

    private var clearMenu: some View {
        Menu {
            Button(L10n.t(.clearUnpinned)) { actions.clear(false) }
            Button(L10n.t(.clearEverything), role: .destructive) { actions.clear(true) }
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help(L10n.t(.clearHelp))
        .disabled(items.isEmpty)
        .opacity(items.isEmpty ? 0.35 : 1)
    }

    private var titleButton: some View {
        Button {
            actions.close()
            SettingsPresenter.open()
        } label: {
            Text("ClipCV")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(L10n.t(.settings))
        .padding(.leading, 5)
    }

    private var searchField: some View {
        ZStack {
            RoundedRectangle(cornerRadius: PopupStyle.cornerRadius, style: .continuous)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 23)
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.8)
                    .padding(.leading, 5)
                TextField(L10n.t(.searchPlaceholder), text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($searchFocused)
                    .disableAutocorrection(true)
                    .onSubmit {
                        guard let item = selectedItem else { return }
                        activate(item, option: optionHeld, shift: shiftHeld)
                    }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .opacity(0.9)
                            .padding(.trailing, 5)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var previewDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func itemRows(
        _ sectionItems: [ClipboardItem],
        baseIndex: Int,
        reorderable: Bool = false
    ) -> some View {
        ForEach(Array(sectionItems.enumerated()), id: \.element.identifier) { offset, item in
            let index = baseIndex + offset
            HistoryItemDragContainer(
                makeSnapshots: {
                    let group = selectedIDs.count > 1 && selectedIDs.contains(item.identifier)
                        ? selectedItems : [item]
                    return group.compactMap { DesktopPinSnapshot.make(from: $0) }
                },
                reorderID: reorderable ? item.identifier : nil,
                onActivate: { handleRowActivate(item, index: index) },
                onHover: { hovering in
                    guard hovering else { return }
                    // 滚动会触发悬停，键盘导航时不能让鼠标抢走选择。
                    guard !keyboardNavigating, !commandHeld, selectedIDs.count <= 1 else { return }
                    selectedIndex = index
                    selectedIDs = [item.identifier]
                },
                onReorder: reorderable ? { actions.reorderPin($0, item.identifier) } : nil,
                onHidePanelForDrag: { actions.hideForDrag() },
                onShowPanelAfterDrag: { actions.showAfterDrag() }
            ) {
                HistoryItemRow(
                    item: item,
                    isSelected: selectedIDs.contains(item.identifier)
                        || (selectedIDs.isEmpty && selectedIndex == index),
                    shortcut: shortcutLabel(for: item, slot: offset),
                    query: query
                )
            }
            .id(item.identifier)
        }
    }

    private func resetSelection(clearFilters: Bool = false) {
        if clearFilters {
            query = ""
            category = .all
            sourceAppFilter = nil
            searchFocused = true
            setPreviewVisible(false, pinned: false)
        }
        selectIndex(0, scroll: true, lockHover: false)
        actions.resizePanelForContent(filtered.count)
        actions.resizePanelForPreview(previewVisible && selectedItem != nil)
        scheduleAutoPreview()
    }

    private func selectIndex(_ index: Int, scroll: Bool, lockHover: Bool) {
        let current = filtered
        guard current.indices.contains(index) || (index == 0 && current.isEmpty) else { return }
        if lockHover {
            keyboardNavigating = true
        }
        selectedIndex = index
        selectedIDs = current.indices.contains(index) ? [current[index].identifier] : []
        guard scroll, current.indices.contains(index), !current[index].pinned else { return }
        scrollToID = current[index].identifier
    }

    private func handleRowActivate(_ item: ClipboardItem, index: Int) {
        if commandHeld, shiftHeld {
            let lo = min(selectedIndex, index)
            let hi = max(selectedIndex, index)
            selectedIDs = Set(filtered[lo...hi].map(\.identifier))
            selectedIndex = index
            return
        }
        if commandHeld {
            if selectedIDs.isEmpty, filtered.indices.contains(selectedIndex) {
                selectedIDs.insert(filtered[selectedIndex].identifier)
            }
            if selectedIDs.contains(item.identifier) {
                selectedIDs.remove(item.identifier)
            } else {
                selectedIDs.insert(item.identifier)
            }
            selectedIndex = index
            return
        }
        selectedIDs = [item.identifier]
        selectedIndex = index
        activate(item, option: optionHeld, shift: shiftHeld)
    }

    private func setPreviewVisible(_ visible: Bool, pinned: Bool) {
        previewPinned = pinned
        previewVisible = visible
        actions.resizePanelForPreview(visible && selectedItem != nil)
    }

    private func scheduleAutoPreview() {
        previewTask?.cancel()
        guard settings.openPreviewAutomatically, selectedItem != nil else {
            if !previewPinned { setPreviewVisible(false, pinned: false) }
            return
        }
        if previewPinned {
            previewVisible = true
            actions.resizePanelForPreview(true)
            return
        }
        previewTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(max(0, settings.previewDelay)))
            guard !Task.isCancelled, settings.openPreviewAutomatically, selectedItem != nil else { return }
            setPreviewVisible(true, pinned: false)
        }
    }

    private func shortcutLabel(for item: ClipboardItem, slot: Int) -> String? {
        if item.pinned, let pinKey = item.pinKey {
            return HotkeyFormatting.decoratedShortcut(
                key: pinKey,
                prefix: settings.pinnedShortcutPrefix,
                optionHeld: optionHeld,
                shiftHeld: shiftHeld,
                commandHeld: commandHeld
            )
        }
        let order = Array(settings.unpinnedKeyOrder)
        guard !item.pinned, order.indices.contains(slot) else { return nil }
        return HotkeyFormatting.decoratedShortcut(
            key: String(order[slot]),
            prefix: settings.unpinnedShortcutPrefix,
            optionHeld: optionHeld,
            shiftHeld: shiftHeld,
            commandHeld: commandHeld
        )
    }

    private var actionTargets: [ClipboardItem] {
        if selectedIDs.count > 1 { return selectedItems }
        return selectedItem.map { [$0] } ?? []
    }

    private func deleteSelection() {
        let targets = actionTargets
        guard !targets.isEmpty else { return }
        actions.delete(targets)
        selectedIDs = []
    }

    private func togglePinSelection() {
        let targets = actionTargets
        guard let first = targets.first else { return }
        pendingSelectionID = first.identifier
        targets.forEach(actions.togglePin)
    }

    private func activate(_ item: ClipboardItem, option: Bool, shift: Bool) {
        if settings.pasteByDefault {
            guard !option || shift else { return actions.copy(item) }
            let plain = settings.removeFormattingByDefault != shift
            return plain ? actions.pastePlain(item) : actions.paste(item)
        }
        guard option else { return actions.copy(item) }
        let plain = shift || settings.removeFormattingByDefault
        plain ? actions.pastePlain(item) : actions.paste(item)
    }

    private func historyShortcutTarget(for keyCode: UInt16) -> (ClipboardItem, ShortcutModifierPrefix)? {
        guard let name = HotkeyFormatting.keyName(for: keyCode) else { return nil }
        if let item = pinnedItems.first(where: { $0.pinKey == name }) {
            return (item, settings.pinnedShortcutPrefix)
        }
        let order = Array(settings.unpinnedKeyOrder)
        let unpinned = unpinnedFiltered
        guard let index = order.firstIndex(of: Character(name)),
              unpinned.indices.contains(index)
        else { return nil }
        return (unpinned[index], settings.unpinnedShortcutPrefix)
    }

    private func moveSelection(_ delta: Int, wrap: Bool = false) {
        let count = filtered.count
        guard count > 0 else { return }
        let next = wrap
            ? (selectedIndex + delta % count + count) % count
            : min(max(selectedIndex + delta, 0), count - 1)
        guard next != selectedIndex else { return }
        selectIndex(next, scroll: true, lockHover: true)
    }

    private func moveSelectionToEdge(first: Bool) {
        guard !filtered.isEmpty else { return }
        selectIndex(first ? 0 : filtered.count - 1, scroll: true, lockHover: true)
    }

    private func installMonitors() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.window is KeyablePanel, event.window?.isVisible == true else { return event }
            let consumed = MainActor.assumeIsolated {
                self.handleKey(
                    keyCode: event.keyCode,
                    flags: event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                )
            }
            return consumed ? nil : event
        }
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            MainActor.assumeIsolated {
                self.optionHeld = flags.contains(.option)
                self.shiftHeld = flags.contains(.shift)
                self.commandHeld = flags.contains(.command)
            }
            return event
        }
        mouseMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { event in
            MainActor.assumeIsolated { self.keyboardNavigating = false }
            return event
        }
    }

    private func removeMonitors() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor); self.flagsMonitor = nil }
        if let mouseMoveMonitor { NSEvent.removeMonitor(mouseMoveMonitor); self.mouseMoveMonitor = nil }
    }

    private func handleKey(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        // 面板关闭时可能漏掉松键事件，按键时校正修饰键状态。
        optionHeld = flags.contains(.option)
        shiftHeld = flags.contains(.shift)
        commandHeld = flags.contains(.command)
        if isPreviewEditing {
            if keyCode == 53 {
                isPreviewEditing = false
                return true
            }
            return false
        }
        if handleConfiguredHotkeys(keyCode: keyCode, flags: flags) { return true }
        if handleCommandShortcuts(keyCode: keyCode, flags: flags) { return true }
        if handleControlNavigation(keyCode: keyCode, flags: flags) { return true }
        if handleHistoryItemShortcut(keyCode: keyCode, flags: flags) { return true }
        return handleNavigationKeys(keyCode: keyCode, flags: flags)
    }

    private func handleConfiguredHotkeys(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        if settings.previewHotkey.matches(keyCode: keyCode, flags: flags) {
            guard selectedItem != nil else { return true }
            let pinnedOpen = previewVisible && previewPinned
            setPreviewVisible(!pinnedOpen, pinned: !pinnedOpen)
            return true
        }
        if settings.deleteHotkey.matches(keyCode: keyCode, flags: flags) {
            deleteSelection()
            return true
        }
        if settings.pinHotkey.matches(keyCode: keyCode, flags: flags) {
            togglePinSelection()
            return true
        }
        return false
    }
}

private extension HistoryContentView {
    func handleCommandShortcuts(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        let option = flags.contains(.option)
        let command = flags.contains(.command)
        let shift = flags.contains(.shift)
        let control = flags.contains(.control)
        if command, !option, !control, !shift {
            switch keyCode {
            case 0x0C: actions.quit(); return true
            case 0x2B:
                actions.close()
                SettingsPresenter.open()
                return true
            default: break
            }
        }
        if keyCode == 51, option, command {
            actions.clear(shift)
            return true
        }
        return false
    }

    func handleControlNavigation(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        let option = flags.contains(.option)
        let command = flags.contains(.command)
        let shift = flags.contains(.shift)
        let control = flags.contains(.control)
        guard control, !command else { return false }
        switch keyCode {
        case 0x20 where !option && !shift:
            query = ""; searchFocused = true; return true
        case 0x04 where !option && !shift:
            searchFocused = true
            if !query.isEmpty { query.removeLast() }
            return true
        case 0x0D where !option && !shift:
            searchFocused = true
            guard !query.isEmpty else { return true }
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            if let idx = trimmed.lastIndex(where: \.isWhitespace) {
                query = String(trimmed[..<idx]).trimmingCharacters(in: .whitespaces)
            } else {
                query = ""
            }
            return true
        case 0x2D:
            option ? moveSelectionToEdge(first: false) : moveSelection(1)
            return true
        case 0x23:
            option ? moveSelectionToEdge(first: true) : moveSelection(-1)
            return true
        case 0x26 where !option:
            moveSelection(1); return true
        case 0x28 where !option:
            if selectedIndex > 0 { moveSelection(-1) }
            return true
        default:
            return false
        }
    }

    func handleHistoryItemShortcut(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        guard let (item, prefix) = historyShortcutTarget(for: keyCode) else { return false }
        let control = flags.contains(.control)
        let base = flags.intersection([.command, .option, .control])
        let matches = prefix == .none
            ? (base.isEmpty ? query.isEmpty : base == prefix.secondaryFlagSet)
            : (base == prefix.flagSet || base == prefix.secondaryFlagSet)
        guard matches else { return false }
        if control, prefix != .control { return false }
        let mods = flags.intersection([.command, .option, .shift, .control])
        activate(
            item,
            option: mods.subtracting(.shift) == prefix.secondaryFlagSet,
            shift: mods.contains(.shift)
        )
        return true
    }

    func handleNavigationKeys(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        let option = flags.contains(.option)
        let command = flags.contains(.command)
        let shift = flags.contains(.shift)
        let control = flags.contains(.control)
        switch keyCode {
        case 53:
            if previewVisible {
                setPreviewVisible(false, pinned: false)
            } else {
                actions.close()
            }
            return true
        case 126:
            (command || option) ? moveSelectionToEdge(first: true) : moveSelection(-1)
            return true
        case 125:
            (command || option) ? moveSelectionToEdge(first: false) : moveSelection(1)
            return true
        case 116:
            moveSelectionToEdge(first: true); return true
        case 121:
            moveSelectionToEdge(first: false); return true
        case 0x30:
            moveSelection(shift ? -1 : 1, wrap: true); return true
        case 36, 76:
            guard !command, !control, let item = selectedItem else { return false }
            activate(item, option: option, shift: shift)
            return true
        default:
            return false
        }
    }
}
