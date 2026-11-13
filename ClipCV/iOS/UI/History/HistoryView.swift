import SwiftData
import SwiftUI

enum HistoryFilter: String, CaseIterable {
    case all = "全部", pinned = "钉选", text = "文字", link = "链接", image = "图片"
}

struct HistoryView: View {
    @Environment(AppRuntime.self) private var runtime
    @Query(sort: \ClipboardItem.createdAt, order: .reverse) private var items: [ClipboardItem]
    @State private var filter = HistoryFilter.all
    @State private var search = ""
    @State private var query = ""
    @State private var selection: ClipboardItem?
    @State private var editing: ClipboardItem?

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            filters
            historyList
        }
        .clipPage().toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { recordingControls }
        .navigationDestination(item: $selection) { ItemDetailView(item: $0) }
        .sheet(item: $editing) { ItemEditView(item: $0) }
        .task(id: search) {
            try? await Task.sleep(for: .milliseconds(120))
            if !Task.isCancelled { query = String(search.prefix(512)).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        .onChange(of: items.map { "\($0.identifier)-\($0.createdAt)-\($0.pinned)-\($0.pinOrder)-\($0.alias)" }) {
            runtime.didChangeHistory()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("ClipCV").font(.system(size: 34, weight: .bold, design: .rounded))
                RecordingStatusLabel().font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            NavigationLink { SettingsView() } label: { CircleControl(symbol: "gearshape") }
                .accessibilityLabel("设置")
        }.padding(.horizontal, 23).padding(.top, 14).padding(.bottom, 17)
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
            TextField("搜索历史记录", text: $search).font(.system(size: 15)).autocorrectionDisabled().accessibilityIdentifier("history-search")
            if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }.accessibilityLabel("清除搜索") }
        }.padding(.horizontal, 16).frame(height: 48).background(ClipStyle.card, in: Capsule())
            .padding(.horizontal, 20).padding(.bottom, 12)
    }

    private var filters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(HistoryFilter.allCases, id: \.self) { value in
                    Button { filter = value } label: {
                        Text(LocalizedStringKey(value.rawValue)).font(.system(size: 13, weight: filter == value ? .semibold : .regular))
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background { if filter == value { Capsule().fill(ClipStyle.gradient) } else { Capsule().fill(ClipStyle.card) } }
                            .foregroundStyle(filter == value ? .black.opacity(0.8) : .secondary)
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 20)
        }.scrollIndicators(.hidden).padding(.bottom, 8)
    }

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if filtered.isEmpty { ContentUnavailableView(query.isEmpty ? "暂无记录" : "无匹配记录", systemImage: query.isEmpty ? "clipboard" : "magnifyingglass") }
                let pins = filtered.filter(\.pinned)
                let recent = filtered.filter { !$0.pinned }
                if !pins.isEmpty { sectionTitle("钉选", sorting: true); rows(pins) }
                if !recent.isEmpty { sectionTitle("最近"); rows(recent) }
            }.padding(.horizontal, 20).padding(.bottom, 12)
        }.scrollDismissesKeyboard(.interactively)
    }

    private func sectionTitle(_ title: LocalizedStringKey, sorting: Bool = false) -> some View {
        HStack {
            Text(title)
            Spacer()
            if sorting { NavigationLink("排序") { PinOrderView() } }
        }.font(.system(size: 12)).foregroundStyle(.secondary).padding(.horizontal, 5).padding(.top, 9)
    }

    private func rows(_ records: [ClipboardItem]) -> some View {
        ForEach(records) { item in
            HistoryItemRow(item: item).contentShape(RoundedRectangle(cornerRadius: 26))
                .onTapGesture { selection = item }
                .contextMenu { HistoryItemMenu(item: item, edit: { editing = item }, delete: { runtime.perform { try runtime.history.delete([item]) } }) }
        }
    }

    private var recordingControls: some View {
        HStack(spacing: 10) {
            NavigationLink { RecordingSettingsView() } label: { Label("记录设置", systemImage: "clock") }.buttonStyle(PrimaryButtonStyle())
            Button { runtime.settings.paused.toggle() } label: { CircleControl(symbol: runtime.settings.paused ? "play.fill" : "pause.fill").frame(width: 52, height: 52) }
                .accessibilityLabel(Text(runtime.settings.paused ? "继续记录" : "暂停记录"))
        }.padding(.horizontal, 20).padding(.vertical, 10).background(ClipStyle.background)
    }

    private var filtered: [ClipboardItem] {
        items.filter { item in
            let matchesType = switch filter {
            case .all: true
            case .pinned: item.pinned
            case .image: item.hasImage
            case .link: !item.hasImage && ClipboardRules.isWebLinkItem(item)
            case .text: !item.hasImage && !ClipboardRules.isFileItem(item) && !ClipboardRules.isWebLinkItem(item)
            }
            guard matchesType else { return false }
            if query.isEmpty { return true }
            if [item.alias, item.title, item.ocrText ?? ""].contains(where: { $0.localizedCaseInsensitiveContains(query) }) { return true }
            return !item.hasImage && !ClipboardRules.isFileItem(item) && (ClipboardRules.plainText(from: item.payloads)?.localizedCaseInsensitiveContains(query) ?? false)
        }.sorted { $0.pinned && $1.pinned ? $0.pinOrder < $1.pinOrder : $0.createdAt > $1.createdAt }
    }
}
