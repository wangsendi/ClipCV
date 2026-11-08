//
//  ItemEditForm.swift
//  ClipCV
//

import AppKit
import SwiftUI

struct ItemEditForm: View {
    @Environment(AppSettings.self) private var settings
    let item: ClipboardItem
    let usedPinKeys: Set<String>
    let onSave: (String, String?, String?) -> ApplyEditResult
    let onCancel: () -> Void

    @State private var aliasText = ""
    @State private var contentText = ""
    @State private var selectedPinKey: String?
    @State private var originalContent = ""
    @State private var pinKeyError: String?
    @FocusState private var focusAlias: Bool

    private var contentEditable: Bool { ClipboardRules.isContentEditable(item) }
    private var isImage: Bool { item.hasImage }

    private var pinOptions: [String] {
        HotkeyFormatting.availablePinKeys(
            used: usedPinKeys,
            current: selectedPinKey ?? item.pinKey,
            order: settings.pinKeyOrder
        )
    }

    private var hasChanges: Bool {
        let aliasChanged = !isImage && aliasText != item.alias
        let pinChanged = item.pinned && selectedPinKey != item.pinKey
        let contentChanged = contentEditable && contentText != originalContent
        return aliasChanged || pinChanged || contentChanged
    }

    private var canSave: Bool {
        guard hasChanges else { return false }
        if contentEditable, contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        return true
    }

    var body: some View {
        let _ = settings.appLanguage
        VStack(alignment: .leading, spacing: 12) {
            aliasField
            if item.pinned { pinKeyField }
            contentField
            actionBar
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: load)
        .onExitCommand(perform: onCancel)
    }

    private var aliasField: some View {
        field(L10n.t(.alias)) {
            TextField(L10n.t(.aliasPlaceholder), text: $aliasText)
                .textFieldStyle(.roundedBorder)
                .disabled(isImage)
                .focused($focusAlias)
                .onSubmit { focusAlias = false }
        }
    }

    private var pinKeyField: some View {
        field(L10n.t(.pinKeyLabel)) {
            VStack(alignment: .leading, spacing: 4) {
                Picker("", selection: $selectedPinKey) {
                    ForEach(pinOptions, id: \.self) { key in
                        Text(key).tag(Optional(key))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 160, alignment: .leading)
                .onChange(of: selectedPinKey) { _, _ in pinKeyError = nil }

                if let pinKeyError {
                    Text(pinKeyError)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var contentField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.t(.content))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Group {
                if contentEditable {
                    TextEditor(text: $contentText)
                        .font(.system(size: 12))
                        .scrollContentBackground(.hidden)
                        .padding(6)
                } else {
                    Text(L10n.t(.contentNotEditable))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
        .frame(maxHeight: .infinity)
    }

    private var actionBar: some View {
        HStack {
            Spacer()
            Button(L10n.t(.cancel), role: .cancel, action: onCancel)
            Button(L10n.t(.done), action: commit)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!canSave)
        }
    }

    private func field<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func load() {
        aliasText = item.alias
        let plain = ClipboardRules.plainText(from: item.payloads) ?? ""
        contentText = plain
        originalContent = plain
        selectedPinKey = item.pinKey
        pinKeyError = nil
        focusAlias = !isImage
    }

    private func commit() {
        guard canSave else { return }
        let result = onSave(
            aliasText,
            contentEditable && contentText != originalContent ? contentText : nil,
            item.pinned ? selectedPinKey : nil
        )
        switch result {
        case .saved:
            pinKeyError = nil
        case .pinKeyTaken:
            pinKeyError = L10n.t(.pinKeyTaken)
        case .pinKeyInvalid:
            pinKeyError = L10n.t(.pinKeyInvalid)
        }
    }
}
