import SwiftUI

enum SettingsMetrics {
    static let popoverSize = CGSize(width: 640, height: 448)
    static let sidebarWidth: CGFloat = 156
    static let contentWidth: CGFloat = 440
    static let labelMinWidth: CGFloat = 88
    static let controlMenuWidth: CGFloat = 168
    static let rowSpacing: CGFloat = 10
    static let sectionSpacing: CGFloat = 16
}

private struct SettingsLabelWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct SettingsLabelWidthEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGFloat = 108
}

extension EnvironmentValues {
    var settingsLabelWidth: CGFloat {
        get { self[SettingsLabelWidthEnvironmentKey.self] }
        set { self[SettingsLabelWidthEnvironmentKey.self] = newValue }
    }
}

enum SettingsLabelStyle {
    static func titled(_ title: String, chinese: Bool) -> String {
        if title.hasSuffix(":") || title.hasSuffix("：") { return title }
        return title + (chinese ? "：" : ":")
    }
}

struct SettingsPage<Content: View>: View {
    var contentWidth: CGFloat = SettingsMetrics.contentWidth
    @ViewBuilder var content: () -> Content

    @State private var labelWidth: CGFloat = 108

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsMetrics.sectionSpacing) {
                content()
            }
            .environment(\.settingsLabelWidth, labelWidth)
            .onPreferenceChange(SettingsLabelWidthKey.self) {
                labelWidth = max(SettingsMetrics.labelMinWidth, $0)
            }
            .frame(maxWidth: contentWidth, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.automatic)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct SettingsSection<Content: View>: View {
    var title: String?
    var footnote: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.3)
            }

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.thinMaterial)
                    .opacity(0.88)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )

            if let footnote {
                SettingsFootnote(footnote)
                    .padding(.horizontal, 4)
            }
        }
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    var alignment: VerticalAlignment = .firstTextBaseline
    var showsDivider = false
    @ViewBuilder var content: () -> Content

    @Environment(\.settingsLabelWidth) private var labelWidth

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: alignment, spacing: 12) {
                Text(title)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: SettingsLabelWidthKey.self,
                                value: geo.size.width
                            )
                        }
                    )
                    .frame(width: labelWidth, alignment: .trailing)

                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 7)

            if showsDivider {
                Divider()
                    .padding(.leading, labelWidth + 12)
            }
        }
    }
}

struct SettingsBlock<Content: View>: View {
    var indent = true
    var showsDivider = false
    @ViewBuilder var content: () -> Content

    @Environment(\.settingsLabelWidth) private var labelWidth

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, indent ? labelWidth + 12 : 0)
                .padding(.vertical, 7)

            if showsDivider {
                Divider()
                    .padding(.leading, indent ? labelWidth + 12 : 0)
            }
        }
    }
}

struct SettingsFootnote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
