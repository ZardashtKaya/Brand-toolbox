import SwiftUI

@main
struct BrandToolboxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(store: BrandStore.shared)
        }
    }
}
