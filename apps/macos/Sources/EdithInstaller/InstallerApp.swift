import SwiftUI

@main
struct EdithInstallerApp: App {
    var body: some Scene {
        Window("Edith Installer", id: "installer") {
            InstallerView()
                .frame(width: 440, height: 430)
        }
        .defaultPosition(.center)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
