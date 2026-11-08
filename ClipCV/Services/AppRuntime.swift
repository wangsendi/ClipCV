//
//  AppRuntime.swift
//  ClipCV
//

import Foundation
import SwiftData

@MainActor
enum AppRuntime {
    static let isRunningTests = NSClassFromString("XCTestCase") != nil

    static let container: ModelContainer = {
        guard isRunningTests else { return AppModelContainer.make() }
        let schema = Schema([ClipboardItem.self, ClipboardContent.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create test ModelContainer: \(error)")
        }
    }()
    static var monitor: ClipboardMonitor!
}
