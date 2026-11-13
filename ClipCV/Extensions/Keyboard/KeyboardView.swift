import SwiftUI

struct KeyboardView: View {
    let entries: [KeyboardEntry]
    let insert: (String) -> Void
    let next: () -> Void
    @State private var pinned = false
    @State private var inserted: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 9) {
            HStack {
                Text("ClipCV").font(.system(size: 19, weight: .bold, design: .rounded))
                Spacer()
                Picker("历史", selection: $pinned) {
                    Text("最近").tag(false)
                    Text("钉选").tag(true)
                }.pickerStyle(.segmented).frame(width: 145)
                Button(action: next) { Image(systemName: "globe").frame(width: 38, height: 38) }
                    .accessibilityLabel("切换键盘")
            }
            ScrollView {
                LazyVStack(spacing: 7) {
                    let visible = pinned ? entries.filter(\.pinned) : entries
                    if visible.isEmpty { Text("暂无记录").foregroundStyle(.secondary).padding(.top, 60) }
                    ForEach(visible) { entry in
                        Button {
                            insert(entry.text)
                            inserted = entry.id
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.title).font(.system(size: 14, weight: .medium)).lineLimit(1)
                                    Text(entry.text).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: inserted == entry.id ? "checkmark" : "arrow.up.left")
                                    .font(.system(size: 13)).foregroundStyle(.green)
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                .background(.background, in: RoundedRectangle(cornerRadius: 17))
                        }.buttonStyle(.plain)
                    }
                }
            }.scrollIndicators(.hidden)
        }.padding(12).background(Color(uiColor: .systemGroupedBackground))
            .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: pinned)
            .task(id: inserted) {
                guard inserted != nil else { return }
                try? await Task.sleep(for: .milliseconds(800))
                if !Task.isCancelled { inserted = nil }
            }
    }
}
