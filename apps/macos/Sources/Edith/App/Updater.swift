import Sparkle
import SwiftUI

@MainActor
final class UpdaterModel: NSObject, ObservableObject,
    @preconcurrency SPUStandardUserDriverDelegate
{
    @Published private(set) var updateReady: String?
    @Published private(set) var updaterAvailable = false
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var lastUpdateCheckDate: Date?
    @Published var automaticallyChecksForUpdates = true {
        didSet {
            guard
                let updater,
                updater.automaticallyChecksForUpdates != automaticallyChecksForUpdates
            else { return }
            updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }
    @Published var automaticallyDownloadsUpdates = true {
        didSet {
            guard
                let updater,
                updater.automaticallyDownloadsUpdates != automaticallyDownloadsUpdates
            else { return }
            updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
        }
    }

    let installOnQuitInfo =
        "Downloaded updates install automatically when you quit or relaunch Edith."

    private var updaterController: SPUStandardUpdaterController?
    private var canCheckObservation: NSKeyValueObservation?
    private var automaticChecksObservation: NSKeyValueObservation?
    private var automaticDownloadsObservation: NSKeyValueObservation?
    private var updater: SPUUpdater? { updaterController?.updater }

    init(startingUpdater: Bool = false) {
        super.init()
        guard startingUpdater else { return }
        let updaterController = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: nil, userDriverDelegate: self)
        self.updaterController = updaterController
        let updater = updaterController.updater
        do {
            try updater.start()
            updaterAvailable = true
        } catch {
            updaterAvailable = false
            return
        }
        if UserDefaults.standard.object(forKey: "SUAutomaticallyUpdate") == nil {
            updater.automaticallyDownloadsUpdates = true
        }
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        lastUpdateCheckDate = updater.lastUpdateCheckDate
        canCheckObservation = updater.observe(
            \.canCheckForUpdates, options: [.initial, .new]
        ) { [weak self] updater, change in
            let canCheckForUpdates = change.newValue ?? updater.canCheckForUpdates
            let lastUpdateCheckDate = updater.lastUpdateCheckDate
            Task { @MainActor [weak self] in
                self?.canCheckForUpdates = canCheckForUpdates
                self?.lastUpdateCheckDate = lastUpdateCheckDate
            }
        }
        automaticChecksObservation = updater.observe(
            \.automaticallyChecksForUpdates, options: [.new]
        ) { [weak self] _, change in
            guard let value = change.newValue else { return }
            Task { @MainActor [weak self] in
                self?.automaticallyChecksForUpdates = value
            }
        }
        automaticDownloadsObservation = updater.observe(
            \.automaticallyDownloadsUpdates, options: [.new]
        ) { [weak self] _, change in
            guard let value = change.newValue else { return }
            Task { @MainActor [weak self] in
                self?.automaticallyDownloadsUpdates = value
            }
        }
    }

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func checkForUpdates() {
        guard updaterAvailable else { return }
        updaterController?.checkForUpdates(nil)
    }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard !handleShowingUpdate, !state.userInitiated else { return }
        updateReady = update.displayVersionString
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        updateReady = nil
    }

    func standardUserDriverWillFinishUpdateSession() {
        updateReady = nil
        lastUpdateCheckDate = updater?.lastUpdateCheckDate
    }
}
