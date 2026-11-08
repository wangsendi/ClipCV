//
//  SoftwareUpdater.swift
//  ClipCV
//

import Foundation
import Observation
import Sparkle

/// Sparkle wrapper — same shape as Maccy's SoftwareUpdater.
@MainActor
@Observable
final class SoftwareUpdater {
    static let shared = SoftwareUpdater()

    /// False until `SUPublicEDKey` is a real EdDSA public key (and not under XCTest).
    private(set) var isAvailable = false

    var automaticallyChecksForUpdates = false {
        didSet {
            guard let updater else { return }
            guard automaticallyChecksForUpdates != updater.automaticallyChecksForUpdates else { return }
            updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }

    private let updaterController: SPUStandardUpdaterController?
    private var updater: SPUUpdater? { updaterController?.updater }
    private var automaticallyChecksObservation: NSKeyValueObservation?

    private init() {
        // XCTest host + placeholder EdDSA key both make Sparkle abort on start.
        let underTest = NSClassFromString("XCTestCase") != nil
        let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        let keyReady = !publicKey.isEmpty && !publicKey.contains("REPLACE_WITH")
        guard !underTest, keyReady else {
            updaterController = nil
            isAvailable = false
            return
        }
        isAvailable = true

        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController = controller
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
        automaticallyChecksObservation = controller.updater.observe(
            \.automaticallyChecksForUpdates,
            options: [.new]
        ) { [weak self] _, change in
            guard let value = change.newValue else { return }
            Task { @MainActor [weak self] in
                guard let self, self.automaticallyChecksForUpdates != value else { return }
                self.automaticallyChecksForUpdates = value
            }
        }
    }

    func checkForUpdates() {
        updater?.checkForUpdates()
    }
}
