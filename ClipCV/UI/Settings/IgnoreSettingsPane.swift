//
//  IgnoreSettingsPane.swift
//  ClipCV
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum IgnoreSubtab: String, CaseIterable, Identifiable {
    case apps, types, regex
    var id: Self { self }
    var title: String {
        switch self {
        case .apps: L10n.t(.ignoreApps)
        case .types: L10n.t(.ignorePasteboardTypes)
        case .regex: L10n.t(.ignoreRegexps)
        }
    }
}

struct IgnoreSettingsPane: View {
    @Environment(AppSettings.self) private var settings
    @State private var subtab: IgnoreSubtab = .apps

    var body: some View {
        let _ = settings.appLanguage
        VStack(spacing: 12) {
            Picker("", selection: $subtab) {
                ForEach(IgnoreSubtab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Group {
                switch subtab {
                case .apps: IgnoreApplicationsSettingsView()
                case .types:
                    IgnoreStringListView(
                        items: Bindable(settings).ignoredPasteboardTypes,
                        placeholder: "xxx.yyy.zzz",
                        sorts: true,
                        footnote: L10n.t(.ignoredPasteboardTypesDescription),
                        onReset: { settings.resetIgnoredPasteboardTypes() }
                    )
                case .regex:
                    IgnoreStringListView(
                        items: Bindable(settings).ignoredRegexps,
                        placeholder: "^[a-zA-Z0-9]{50}$",
                        sorts: false,
                        footnote: L10n.t(.ignoredRegexpsDescription)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .id(settings.appLanguage)
    }
}

private struct IgnoreApplicationsSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @State private var selection: String?
    @State private var isAdding = false

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 10) {
            List(selection: $selection) {
                ForEach(settings.ignoredBundleIDs, id: \.self) { bundleID in
                    Group {
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                            Label {
                                Text(FileManager.default.displayName(atPath: url.path)).padding(.horizontal, 4)
                            } icon: {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            }
                        } else {
                            Label {
                                Text(bundleID).padding(.horizontal, 4)
                            } icon: {
                                Image(systemName: "questionmark.circle").imageScale(.large)
                            }
                        }
                    }
                    .frame(height: 30)
                    .padding(.horizontal, 4)
                    .tag(bundleID)
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onDeleteCommand { if let selection { remove(selection) } }

            HStack(spacing: 12) {
                ControlGroup {
                    Button("", systemImage: "plus") { isAdding = true }
                        .accessibilityLabel(L10n.t(.add))
                    Button("", systemImage: "minus") { if let selection { remove(selection) } }
                        .accessibilityLabel(L10n.t(.delete))
                        .disabled(selection == nil)
                }
                .frame(width: 50)
                .fileDialogDefaultDirectory(URL(fileURLWithPath: "/Applications"))
                .fileImporter(isPresented: $isAdding, allowedContentTypes: [.application]) { result in
                    guard case .success(let appURL) = result else { return }
                    let accessing = appURL.startAccessingSecurityScopedResource()
                    defer { if accessing { appURL.stopAccessingSecurityScopedResource() } }
                    if let id = Bundle(url: appURL)?.bundleIdentifier {
                        settings.addIgnored(id)
                    }
                }
                Toggle(L10n.t(.ignoreAllAppsExceptListed), isOn: $settings.ignoreAllAppsExceptListed)
            }
            SettingsFootnote(L10n.t(.ignoredAppsDescription))
        }
    }

    private func remove(_ app: String) {
        settings.removeIgnored(app)
        if selection == app { selection = nil }
    }
}

private struct IgnoreStringListView: View {
    @Binding var items: [String]
    let placeholder: String
    var sorts = false
    let footnote: String
    var onReset: (() -> Void)?

    @FocusState private var focus: String?
    @State private var selection: String?
    @State private var edit = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            List(selection: $selection) {
                ForEach(items, id: \.self) { value in
                    TextField(
                        "",
                        text: Binding(
                            get: { value },
                            set: { guard !$0.isEmpty, value != $0 else { return }; edit = $0 }
                        )
                    )
                    .textFieldStyle(.plain)
                    .focused($focus, equals: value)
                    .onSubmit { replace(value, with: edit) }
                    .tag(value)
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onDeleteCommand { remove(selection) }

            HStack {
                ControlGroup {
                    Button("", systemImage: "plus") {
                        guard !items.contains(placeholder) else {
                            selection = placeholder
                            focus = placeholder
                            edit = placeholder
                            return
                        }
                        items.append(placeholder)
                        if sorts { items.sort() }
                        selection = placeholder
                        focus = placeholder
                        edit = placeholder
                    }
                    .accessibilityLabel(L10n.t(.add))
                    Button("", systemImage: "minus") { remove(selection) }
                        .accessibilityLabel(L10n.t(.delete))
                        .disabled(selection == nil)
                }
                .frame(width: 50)
                Spacer()
                if let onReset {
                    Button(L10n.t(.reset)) {
                        onReset()
                        selection = nil
                    }
                }
            }
            SettingsFootnote(footnote)
        }
    }

    private func remove(_ value: String?) {
        guard let value else { return }
        items.removeAll { $0 == value }
        if selection == value { selection = nil }
    }

    private func replace(_ old: String, with newValue: String) {
        let value = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        var next = items.filter { $0 != old }
        if !next.contains(value) { next.append(value) }
        items = sorts ? next.sorted() : next
        selection = value
        focus = value
    }
}
