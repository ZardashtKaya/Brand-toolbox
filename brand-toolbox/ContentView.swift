import SwiftUI

@main
struct BrandingToolboxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(store: BrandStore.shared)
        }
    }
}

// MARK: - Previews

#Preview("Branding Toolbox Settings") {
    SettingsView(store: .shared)
}
