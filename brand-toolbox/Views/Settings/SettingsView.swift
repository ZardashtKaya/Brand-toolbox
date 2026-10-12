import SwiftUI

public struct SettingsView: View {
    @ObservedObject var store: BrandStore

    public init(store: BrandStore = .shared) {
        self.store = store
    }

    public var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            brandsTab
                .tabItem {
                    Label("Brands", systemImage: "paintpalette")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 360)
        .padding(16)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("Position & Presentation") {
                Picker("Position Mode", selection: $store.overlayMode) {
                    ForEach(OverlayPositionMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.iconName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: store.overlayMode) {
                    store.savePreferences()
                }

                Toggle("Pin by Default (Keep open)", isOn: $store.isPinned)
                    .onChange(of: store.isPinned) {
                        store.savePreferences()
                    }
            }

            Section("Clipboard & Copying") {
                Picker("Default Copy Format", selection: $store.copyFormat) {
                    ForEach(CopyFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .onChange(of: store.copyFormat) {
                    store.savePreferences()
                }

            Toggle("Sound & Haptic Feedback", isOn: $store.soundAndHaptics)
                .onChange(of: store.soundAndHaptics) {
                    store.savePreferences()
                }
            }

            Section("Hover & Edge Behavior") {
                HStack {
                    Text("Edge Sensitivity")
                    Slider(value: $store.edgeSensitivityPx, in: 4...24, step: 2)
                    Text("\(Int(store.edgeSensitivityPx)) px")
                        .monospacedDigit()
                        .frame(width: 45)
                }
                .onChange(of: store.edgeSensitivityPx) {
                    store.savePreferences()
                }

                HStack {
                    Text("Auto-Hide Delay")
                    Slider(value: $store.autoHideDelay, in: 0.15...1.0, step: 0.05)
                    Text(String(format: "%.2f s", store.autoHideDelay))
                        .monospacedDigit()
                        .frame(width: 45)
                }
                .onChange(of: store.autoHideDelay) {
                    store.savePreferences()
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Brands Tab

    private var brandsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Managed Brands (\(store.brands.count))")
                .font(.headline)

            List {
                ForEach(store.brands) { brand in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(brand.accentColor)
                            .frame(width: 18, height: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(brand.name)
                                .font(.system(size: 13, weight: .semibold))
                            Text("\(brand.colors.count) colors • \(brand.logos.count) logos")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if store.selectedBrandId == brand.id {
                            Text("Active")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                                .foregroundColor(.accentColor)
                        } else {
                            Button("Set Active") {
                                store.selectedBrandId = brand.id
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Brand Toolbox")
                .font(.title2.bold())

            Text("Version 1.0 • Designed for macOS")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("A high-velocity companion dock and Dynamic Island overlay for brand colors and logo drag-and-drop.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 30)

            Spacer()
        }
        .padding(.top, 24)
    }
}
