import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
public struct LeftDockView: View {
    @ObservedObject var store: BrandStore
    public let onTogglePin: () -> Void
    public let onSwitchMode: () -> Void
    public let onOpenSettings: () -> Void

    @State private var showingAddBrandSheet: Bool = false
    @State private var showingAddColorSheet: Bool = false
    @State private var isDropTargeted: Bool = false
    @State private var selectedTab: DockTab = .all

    public enum DockTab: String, CaseIterable {
        case all = "All"
        case colors = "Colors"
        case logos = "Logos"
    }

    public init(
        store: BrandStore = .shared,
        onTogglePin: @escaping () -> Void = {},
        onSwitchMode: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.store = store
        self.onTogglePin = onTogglePin
        self.onSwitchMode = onSwitchMode
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            headerView
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()
                .background(Color.white.opacity(0.1))

            // MARK: - Brand Switcher Rail
            BrandSelectorRail(store: store) {
                showingAddBrandSheet = true
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            // MARK: - Tab / Filter Selector
            HStack(spacing: 6) {
                ForEach(DockTab.allCases, id: \.self) { tab in
                    let isSel = selectedTab == tab
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            selectedTab = tab
                        }
                    }) {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: isSel ? .semibold : .medium))
                            .foregroundColor(isSel ? .white : .white.opacity(0.55))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(isSel ? Color.white.opacity(0.14) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()

                // Search button / query input
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                    TextField("Filter...", text: $store.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                        .frame(width: 70)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.06)))
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            // MARK: - Main Content Area
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    if let brand = store.selectedBrand {
                        // COLORS SECTION
                        if selectedTab == .all || selectedTab == .colors {
                            colorsSection(brand: brand)
                        }

                        // LOGOS SECTION
                        if selectedTab == .all || selectedTab == .logos {
                            logosSection(brand: brand)
                        }
                    } else {
                        emptyStateView
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 20)
            }

            // MARK: - Copied Toast Bar
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
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.85))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.green.opacity(0.4)),
                    alignment: .top
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 320, height: 560)
        .background(
            ZStack {
                // Ultra Thin Dark Glass
                VisualEffectBlurView(material: .hudWindow, blendingMode: .behindWindow)
                Color(red: 0.08, green: 0.08, blue: 0.10).opacity(0.88)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.06),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .sheet(isPresented: $showingAddBrandSheet) {
            AddBrandSheet(store: store)
        }
        .sheet(isPresented: $showingAddColorSheet) {
            if let brand = store.selectedBrand {
                AddColorSheet(store: store, brand: brand)
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 10) {
            // App / Brand Icon
            if let brand = store.selectedBrand {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(brand.accentColor.opacity(0.9))
                        .frame(width: 26, height: 26)

                    Image(systemName: brand.iconSymbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(brand.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    if !brand.tagline.isEmpty {
                        Text(brand.tagline)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                }
            } else {
                Text("Brand Toolbox")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            // Mode Switcher (Switch to Dynamic Island)
            Button(action: onSwitchMode) {
                Image(systemName: "capsule.portrait")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .padding(6)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Switch to Dynamic Island / Notch Mode")

            // Pin Button
            Button(action: onTogglePin) {
                Image(systemName: store.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(store.isPinned ? .yellow : .white.opacity(0.75))
                    .padding(6)
                    .background(Circle().fill(store.isPinned ? Color.yellow.opacity(0.2) : Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help(store.isPinned ? "Unpin (Auto-hide on mouse exit)" : "Pin open (Keep dock visible)")

            // Settings Gear
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.75))
                    .padding(6)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Settings & Preferences")
        }
    }

    // MARK: - Colors Section

    private func colorsSection(brand: Brand) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BRAND COLORS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
                    .tracking(0.8)

                Spacer()

                Button(action: { showingAddColorSheet = true }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Add Color")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(brand.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(brand.accentColor.opacity(0.14)))
                }
                .buttonStyle(.plain)
            }

            let colors = store.filteredColors
            if colors.isEmpty {
                Text("No colors match your search")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 6) {
                    ForEach(colors) { color in
                        ColorSwatchCard(
                            store: store,
                            color: color,
                            onEdit: {
                                // Can trigger edit
                            },
                            onDelete: {
                                store.deleteColor(from: brand, colorId: color.id)
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Logos Section

    private func logosSection(brand: Brand) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LOGOS & ASSETS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
                    .tracking(0.8)

                Spacer()

                // Add Logo File Button
                Button(action: {
                    pickAndAddLogo(for: brand)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Add Logo")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(brand.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(brand.accentColor.opacity(0.14)))
                }
                .buttonStyle(.plain)
            }

            // Drag & Drop Hint Banner / Drop target
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isDropTargeted ? brand.accentColor.opacity(0.15) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                            )
                            .foregroundColor(isDropTargeted ? brand.accentColor : Color.white.opacity(0.12))
                    )

                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 13))
                        .foregroundColor(isDropTargeted ? brand.accentColor : .white.opacity(0.5))
                    Text(isDropTargeted ? "Drop Image Here" : "Drag & drop files here to add logos")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.vertical, 8)
            }
            .onDrop(of: [.fileURL, .image], isTargeted: $isDropTargeted) { providers in
                handleDroppedFiles(providers: providers, for: brand)
            }

            let logos = store.filteredLogos
            if !logos.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(logos) { logo in
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
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "paintpalette")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.3))
            Text("No Brand Selected")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            Button("Add First Brand") {
                showingAddBrandSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }

    // MARK: - Actions

    private func pickAndAddLogo(for brand: Brand) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .png, .jpeg, .svg, .pdf]
        panel.prompt = "Add to Brand"

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

// MARK: - AppKit Visual Effect Blur Helper

public struct VisualEffectBlurView: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
