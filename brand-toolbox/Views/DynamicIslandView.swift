import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
public struct DynamicIslandView: View {
    @ObservedObject var store: BrandStore
    public let isExpanded: Bool
    public let onToggleExpand: () -> Void
    public let onTogglePin: () -> Void
    public let onSwitchMode: () -> Void
    public let onOpenSettings: () -> Void

    @State private var showingAddBrandSheet: Bool = false
    @State private var showingAddColorSheet: Bool = false
    @State private var isDropTargeted: Bool = false

    public init(
        store: BrandStore = .shared,
        isExpanded: Bool,
        onToggleExpand: @escaping () -> Void = {},
        onTogglePin: @escaping () -> Void = {},
        onSwitchMode: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.store = store
        self.isExpanded = isExpanded
        self.onToggleExpand = onToggleExpand
        self.onTogglePin = onTogglePin
        self.onSwitchMode = onSwitchMode
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        Group {
            if isExpanded {
                openedIslandView
            } else {
                closedPillView
            }
        }
        .sheet(isPresented: $showingAddBrandSheet) {
            AddBrandSheet(store: store)
        }
        .sheet(isPresented: $showingAddColorSheet) {
            if let brand = store.selectedBrand {
                AddColorSheet(store: store, brand: brand)
            }
        }
    }

    // MARK: - Closed Pill View (Hugs the notch / Dynamic Island)

    private var closedPillView: some View {
        Button(action: onToggleExpand) {
            HStack(spacing: 10) {
                if let brand = store.selectedBrand {
                    // Left: Brand Icon dot
                    ZStack {
                        Circle()
                            .fill(brand.accentColor)
                            .frame(width: 20, height: 20)

                        Image(systemName: brand.iconSymbol)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }

                    // Center: Brand Name
                    Text(brand.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer(minLength: 4)

                    // Right: Color dots palette
                    HStack(spacing: 4) {
                        ForEach(brand.colors.prefix(4)) { c in
                            Circle()
                                .fill(c.swiftUIColor)
                                .frame(width: 9, height: 9)
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                        }
                    }

                    // Expand indicator
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                } else {
                    Text("Brand Toolbox")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(width: 230, height: 36)
            .background(
                ZStack {
                    VisualEffectBlurView(material: .hudWindow, blendingMode: .behindWindow)
                    Color.black.opacity(0.92)
                }
            )
            .clipShape(ClosedPillShape(cornerRadius: 18))
            .overlay(
                ClosedPillShape(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Opened Island View (Expanded Notch Card)

    private var openedIslandView: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 10) {
                // Brand selector rail
                BrandSelectorRail(store: store) {
                    showingAddBrandSheet = true
                }

                Spacer()

                // Switch to Left Dock Mode
                Button(action: onSwitchMode) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Switch to Left Dock Mode")

                // Pin Button
                Button(action: onTogglePin) {
                    Image(systemName: store.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(store.isPinned ? .yellow : .white.opacity(0.75))
                        .padding(6)
                        .background(Circle().fill(store.isPinned ? Color.yellow.opacity(0.2) : Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help(store.isPinned ? "Unpin (Auto-collapse on mouse leave)" : "Pin open")

                // Settings
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Preferences")

                // Collapse Button
                Button(action: onToggleExpand) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Collapse Island")
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .background(Color.white.opacity(0.1))

            // Two-Column Grid Content
            if let brand = store.selectedBrand {
                HStack(alignment: .top, spacing: 16) {
                    // LEFT COLUMN: Colors
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("COLORS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.45))
                                .tracking(0.8)

                            Spacer()

                            Button(action: { showingAddColorSheet = true }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("Add")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(brand.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(brand.accentColor.opacity(0.14)))
                            }
                            .buttonStyle(.plain)
                        }

                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 6) {
                                ForEach(store.filteredColors) { color in
                                    ColorSwatchCard(
                                        store: store,
                                        color: color,
                                        onDelete: {
                                            store.deleteColor(from: brand, colorId: color.id)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Divider()
                        .background(Color.white.opacity(0.1))

                    // RIGHT COLUMN: Logos
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("LOGOS & ASSETS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.45))
                                .tracking(0.8)

                            Spacer()

                            Button(action: { pickAndAddLogo(for: brand) }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("Add")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(brand.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(brand.accentColor.opacity(0.14)))
                            }
                            .buttonStyle(.plain)
                        }

                        // Drop Target
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isDropTargeted ? brand.accentColor.opacity(0.15) : Color.white.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                        .foregroundColor(isDropTargeted ? brand.accentColor : Color.white.opacity(0.12))
                                )

                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.doc.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                                Text("Drop files to import")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.vertical, 6)
                        }
                        .onDrop(of: [.fileURL, .image], isTargeted: $isDropTargeted) { providers in
                            handleDroppedFiles(providers: providers, for: brand)
                        }

                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                                ForEach(store.filteredLogos) { logo in
                                    LogoCardView(
                                        store: store,
                                        logo: logo,
                                        onDelete: {
                                            store.deleteLogo(from: brand, logoId: logo.id)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            // Toast Bar
            if let toast = store.copiedToastMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text(toast)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.85))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 530, height: 380)
        .background(
            ZStack {
                VisualEffectBlurView(material: .hudWindow, blendingMode: .behindWindow)
                Color(red: 0.08, green: 0.08, blue: 0.10).opacity(0.92)
            }
        )
        .clipShape(NotchShape(topCornerRadius: 22, bottomCornerRadius: 22))
        .overlay(
            NotchShape(topCornerRadius: 22, bottomCornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.55), radius: 24, x: 0, y: 12)
    }

    // MARK: - Actions

    private func pickAndAddLogo(for brand: Brand) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .png, .jpeg, .svg, .pdf]

        if panel.runModal() == .OK {
            for url in panel.urls {
                store.addLogoFile(to: brand, fileURL: url)
            }
        }
    }

    private func handleDroppedFiles(providers: [NSItemProvider], for brand: Brand) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            store.addLogoFile(to: brand, fileURL: url)
                        }
                    } else if let url = item as? URL {
                        DispatchQueue.main.async {
                            store.addLogoFile(to: brand, fileURL: url)
                        }
                    }
                }
                handled = true
            }
        }
        return handled
    }
}
