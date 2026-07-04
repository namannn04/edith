import Foundation

/// Owns the per-tab stores and their lifecycles. A disabled tab's store is
/// never created - no timers, no network, no audio session, no caches - and
/// disabling a live tab tears its store down and frees those resources.
/// Future tabs: add a flag + store pair here and a case in RootView.
@MainActor
final class AppServices: ObservableObject {
    @Published private(set) var usage: UsageStore?
    @Published private(set) var music: MusicPlayer?

    static func tabEnabled(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    init() {
        sync()
    }

    /// Reconcile live stores with the enabled-tab flags in UserDefaults.
    func sync() {
        let usageOn = Self.tabEnabled("tabUsageEnabled")
        let musicOn = Self.tabEnabled("tabMusicEnabled")

        if usageOn, usage == nil { usage = UsageStore() }
        if !usageOn, let store = usage {
            store.shutdown()
            usage = nil
        }
        if musicOn, music == nil { music = MusicPlayer() }
        if !musicOn, let player = music {
            player.shutdown()
            music = nil
        }
    }
}
