import AppKit
import SwiftUI

struct SettingsStepperField: View {
    @Binding var value: Int
    var range: ClosedRange<Int>
    var width: CGFloat = 96

    var body: some View {
        let formatter = NumberFormatter()
        formatter.minimum = NSNumber(value: range.lowerBound)
        formatter.maximum = NSNumber(value: range.upperBound)
        return HStack(spacing: 4) {
            TextField("", value: $value, formatter: formatter)
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
                .labelsHidden()
            Stepper("", value: $value, in: range).labelsHidden()
        }
    }
}

struct SettingsMenuPicker<SelectionValue: Hashable, Content: View>: View {
    @Binding var selection: SelectionValue
    var width: CGFloat = SettingsMetrics.controlMenuWidth
    @ViewBuilder var content: () -> Content

    var body: some View {
        Picker("", selection: $selection, content: content)
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: width, alignment: .leading)
    }
}

struct SettingsHotkeyRow: View {
    let label: String
    let title: String
    let help: String
    let value: Hotkey
    let target: HotkeyCaptureTarget
    var showsDivider = false

    @Environment(AppSettings.self) private var settings

    var body: some View {
        let capturing = settings.capturingTarget == target
        SettingsRow(title: label, showsDivider: showsDivider) {
            HStack(spacing: 6) {
                Button { settings.beginCapture(target) } label: {
                    Text(capturing ? L10n.t(.capturingHotkey) : (value.isCleared ? "—" : value.display))
                        .font(.system(size: 12, weight: .semibold).monospaced())
                        .foregroundStyle(capturing ? Color.accentColor : Color.primary)
                        .lineLimit(1)
                        .frame(minWidth: 92)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(capturing ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.08))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(
                                    capturing ? Color.accentColor.opacity(0.8) : Color.primary.opacity(0.14),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)

                if !value.isCleared {
                    Button { settings.clearHotkey(target) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.t(.reset))
                }
            }
            .help(help)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
            .accessibilityValue(capturing ? L10n.t(.capturingHotkey) : value.display)
        }
    }
}

struct HotkeyCaptureInstaller: ViewModifier {
    @Environment(AppSettings.self) private var settings
    @State private var keyMonitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear(perform: install)
            .onDisappear {
                settings.capturingTarget = nil
                if let keyMonitor {
                    NSEvent.removeMonitor(keyMonitor)
                    self.keyMonitor = nil
                }
            }
            .onChange(of: settings.capturingTarget) { _, target in
                if target != nil { install() }
            }
    }

    private func install() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = event.keyCode
            let flags = event.modifierFlags
            guard MainActor.assumeIsolated({ settings.capturingTarget != nil }) else { return event }
            MainActor.assumeIsolated { settings.capture(keyCode: keyCode, modifierFlags: flags) }
            return nil
        }
    }
}

extension View {
    func installsHotkeyCapture() -> some View {
        modifier(HotkeyCaptureInstaller())
    }
}
