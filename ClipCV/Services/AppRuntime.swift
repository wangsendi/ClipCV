//
//  AppRuntime.swift
//  ClipCV
//

import SwiftData

@MainActor
enum AppRuntime {
    static let container: ModelContainer = AppModelContainer.make()
    static var monitor: ClipboardMonitor!
}
