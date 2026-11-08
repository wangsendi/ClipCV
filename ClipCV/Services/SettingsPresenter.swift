//
//  SettingsPresenter.swift
//  ClipCV
//

import AppKit

@MainActor
enum SettingsPresenter {
    private static var openAction: (() -> Void)?
    private static var closeAction: (() -> Void)?

    static func register(open: @escaping () -> Void, close: @escaping () -> Void = {}) {
        openAction = open
        closeAction = close
    }

    static func open() { openAction?() }
    static func close() { closeAction?() }
}
