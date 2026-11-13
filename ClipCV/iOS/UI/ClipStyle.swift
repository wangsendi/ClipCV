import SwiftUI

enum ClipStyle {
    static let background = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.12, green: 0.13, blue: 0.11, alpha: 1)
        : UIColor(red: 0.953, green: 0.953, blue: 0.945, alpha: 1)
    })
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let green = Color(red: 0.42, green: 0.7, blue: 0.2)
    static let gradient = LinearGradient(colors: [Color(red: 0.09, green: 0.76, blue: 0.42), Color(red: 0.72, green: 0.9, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension View {
    func clipCard(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(ClipStyle.card, in: RoundedRectangle(cornerRadius: 26))
            .shadow(color: .black.opacity(0.035), radius: 16, y: 7)
    }

    func clipPage() -> some View {
        self.background(ClipStyle.background).toolbarTitleDisplayMode(.inline)
    }
}

struct CircleControl: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol).font(.system(size: 17, weight: .medium))
            .frame(width: 44, height: 44)
            .background(ClipStyle.card, in: Circle())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 16, weight: .medium, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(.white).background(.black.opacity(0.9), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct PlushToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 14)
            Button { configuration.isOn.toggle() } label: { Color.clear.frame(width: 43, height: 28) }
                .buttonStyle(SwitchButtonStyle(isOn: configuration.isOn))
                .accessibilityLabel(Text(configuration.isOn ? "已开启" : "已关闭"))
                .accessibilityValue(configuration.isOn ? "1" : "0")
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SwitchButtonStyle: ButtonStyle {
    let isOn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule().fill(.quaternary)
            Capsule().fill(ClipStyle.gradient).opacity(isOn ? 1 : 0)
            Capsule().fill(.white)
                .frame(width: configuration.isPressed ? 28 : 24, height: 24).padding(2)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
        }
        .frame(width: 43, height: 28)
        .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.7), value: isOn)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct CopyButton: View {
    let item: ClipboardItem
    var prominent = false
    @Environment(AppRuntime.self) private var runtime
    @State private var copied = false

    var body: some View {
        Button {
            guard runtime.copy(item) else { return }
            copied = true
        } label: {
            if prominent {
                Label(copied ? "已复制" : "复制", systemImage: copied ? "checkmark" : "square.on.square")
            } else {
                Image(systemName: copied ? "checkmark" : "square.on.square")
                    .font(.system(size: 16)).frame(width: 36, height: 36)
                    .foregroundStyle(copied ? ClipStyle.green : .primary)
                    .background(ClipStyle.background, in: Circle())
            }
        }
        .accessibilityLabel(Text(copied ? "已复制" : "复制"))
        .sensoryFeedback(.success, trigger: copied)
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1))
            copied = false
        }
    }
}
