import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
public struct MiniDockView: View {
    @ObservedObject var store: BrandStore
    public let onTogglePin: () -> Void
    public let onSwitchMode: () -> Void
    public let onOpenSettings: () -> Void

    @State private var showingBrandMenu: Bool = false
    @State private var showingAddBrandSheet: Bool = false
    @State private var showingAddColorSheet: Bool = false
    @State private var copiedColorId: UUID? = nil
    @State private var copiedLogoId: UUID? = nil
    @State private var isDropTargeted: Bool = false

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
        VStack(spacing: 10) {
            // MARK: - Top Brand Colors (Horizontal Pills)
            colorsSection

            // MARK: - Middle Brand Logos (Square Tiles)
            logosSection

            Spacer(minLength: 4)

            // MARK: - Bottom Brand Switcher Chevron
            chevronButton
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 9)
        .frame(width: 76, height: 460)
        .background(
            ZStack {
                // OLED deep black capsule
                Color(red: 0.05, green: 0.05, blue: 0.06)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.65), radius: 22, x: 6, y: 0)
        .sheet(isPresented: $showingAddBrandSheet) {
            AddBrandSheet(store: store)
        }
        .sheet(isPresented: $showingAddColorSheet) {
            if let brand = store.selectedBrand {
                AddColorSheet(store: store, brand: brand)
            }
        }
    }

    // MARK: - Colors Section (Pills)

    private var colorsSection: some View {
        VStack(spacing: 8) {
            if let brand = store.selectedBrand {
                let displayColors = Array(brand.colors.prefix(3))
                ForEach(displayColors) { color in
                    colorPill(color: color)
                }

                // If less than 3 colors, fill with secondary or plus
                if displayColors.isEmpty {
                    colorPillPlaceholder
                }
            } else {
                colorPillPlaceholder
            }
        }
    }

    private func colorPill(color: BrandColor) -> some View {
        let isCopied = copiedColorId == color.id

        return Button(action: {
            triggerCopyColor(color)
        }) {
            ZStack {
                Capsule()
                    .fill(color.swiftUIColor)
                    .frame(width: 58, height: 26)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                    )
                    .shadow(color: color.swiftUIColor.opacity(0.4), radius: 4, x: 0, y: 2)

                if isCopied {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .black))
                        Text("HEX")
                            .font(.system(size: 9, weight: .heavy))
                    }
                    .foregroundColor(color.contrastTextColor)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("\(color.name): \(color.formattedHex) (Click to copy)")
        .contextMenu {
            Button("Copy \(color.formattedHex)") {
                triggerCopyColor(color)
            }
            Button("Copy RGB (\(color.formatted(for: .rgb)))") {
                store.copyColor(color, format: .rgb)
            }
            Button("Copy SwiftUI Color") {
                store.copyColor(color, format: .swiftUI)
            }
            Divider()
            Button("Add Color...") {
                showingAddColorSheet = true
            }
            if let brand = store.selectedBrand {
                Button("Delete Color", role: .destructive) {
                    store.deleteColor(from: brand, colorId: color.id)
                }
            }
        }
    }

    private var colorPillPlaceholder: some View {
        Button(action: { showingAddColorSheet = true }) {
            ZStack {
                Capsule()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundColor(Color.white.opacity(0.3))
                    .frame(width: 58, height: 26)

                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
        .help("Add Brand Color")
    }

    private func triggerCopyColor(_ color: BrandColor) {
        store.copyColor(color)
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            copiedColorId = color.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                if copiedColorId == color.id {
                    copiedColorId = nil
                }
            }
        }
    }

    // MARK: - Logos Section (Square Tiles)

    private var logosSection: some View {
        VStack(spacing: 8) {
            if let brand = store.selectedBrand {
                let displayLogos = Array(brand.logos.prefix(3))

                ForEach(Array(displayLogos.enumerated()), id: \.element.id) { index, logo in
                    logoTile(logo: logo, index: index)
                }

                // If less than 3 logos, fill with placeholder add slot
                if displayLogos.count < 3 {
                    ForEach(displayLogos.count..<3, id: \.self) { _ in
                        logoTilePlaceholder(brand: brand)
                    }
                }
            } else {
                logoTilePlaceholder(brand: nil)
            }
        }
        .onDrop(of: [.fileURL, .image], isTargeted: $isDropTargeted) { providers in
            if let brand = store.selectedBrand {
                return handleDroppedFiles(providers: providers, for: brand)
            }
            return false
        }
    }

    private func logoTile(logo: BrandLogo, index: Int) -> some View {
        let isCopied = copiedLogoId == logo.id
        // Match screenshot: top two tiles are bright white, third tile is dark gradient!
        let isDarkTile = index >= 2

        return Button(action: {
            triggerCopyLogo(logo)
        }) {
            ZStack {
                // Background Tile
                if isDarkTile {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.55),
                                    Color(white: 0.25),
                                    Color(white: 0.12)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 58, height: 58)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 58, height: 58)
                }

                // Logo content / preview
                if let nsImage = store.imageForLogo(logo) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(8)
                        .frame(width: 58, height: 58)
                } else {
                    Text("LOGO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isDarkTile ? .white : .black)
                }

                // Copied Overlay
                if isCopied {
                    ZStack {
                        Color.black.opacity(0.8)
                        VStack(spacing: 2) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.green)
                            Text("COPIED")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundColor(.white)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(width: 58, height: 58)
                    .transition(.opacity)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(isDarkTile ? 0.3 : 0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("\(logo.name) (Click to copy, Drag to use in Figma/Finder)")
        // DRAG AND DROP OUT
        .onDrag {
            createDragProvider(for: logo)
        }
        .contextMenu {
            Button("Copy Image") {
                triggerCopyLogo(logo)
            }
            if let fileURL = store.fileURLForLogo(logo) {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                }
            }
            Divider()
            if let brand = store.selectedBrand {
                Button("Delete Logo", role: .destructive) {
                    store.deleteLogo(from: brand, logoId: logo.id)
                }
            }
        }
    }

    private func logoTilePlaceholder(brand: Brand?) -> some View {
        Button(action: {
            if let brand {
                pickAndAddLogo(for: brand)
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 58, height: 58)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .foregroundColor(Color.white.opacity(0.2))
                    )

                VStack(spacing: 2) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                    Text("LOGO")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .buttonStyle(.plain)
        .help("Drop image or click to add logo")
    }

    private func triggerCopyLogo(_ logo: BrandLogo) {
        store.copyLogoImage(logo)
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            copiedLogoId = logo.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                if copiedLogoId == logo.id {
                    copiedLogoId = nil
                }
            }
        }
    }

    private func createDragProvider(for logo: BrandLogo) -> NSItemProvider {
        let provider = NSItemProvider()
        if let fileURL = store.fileURLForLogo(logo) {
            provider.registerFileRepresentation(
                forTypeIdentifier: UTType.image.identifier,
                fileOptions: [],
                visibility: .all
            ) { completion in
                completion(fileURL, false, nil)
                return nil
            }
            provider.registerObject(fileURL as NSURL, visibility: .all)
            if let img = store.imageForLogo(logo) {
                provider.registerObject(img, visibility: .all)
            }
        } else if let img = store.imageForLogo(logo) {
            provider.registerObject(img, visibility: .all)
        }
        return provider
    }

    // MARK: - Bottom Chevron (Brand Switcher & Controls)

    private var chevronButton: some View {
        Button(action: {
            showingBrandMenu.toggle()
        }) {
            ZStack {
                Color.clear
                    .frame(width: 58, height: 32)

                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(showingBrandMenu ? 1.15 : 1.0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Switch Brand / Options (\(store.selectedBrand?.name ?? ""))")
        .popover(isPresented: $showingBrandMenu, arrowEdge: .trailing) {
            brandPickerPopover
        }
    }

    private var brandPickerPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("Select Brand")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    showingBrandMenu = false
                    showingAddBrandSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Add New Brand")
            }

            Divider()

            // Brands List
            VStack(alignment: .leading, spacing: 4) {
                ForEach(store.brands) { brand in
                    let isSel = store.selectedBrandId == brand.id
                    Button(action: {
                        store.selectedBrandId = brand.id
                        store.savePreferences()
                        showingBrandMenu = false
                    }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(brand.accentColor)
                                .frame(width: 14, height: 14)

                            Text(brand.name)
                                .font(.system(size: 12, weight: isSel ? .bold : .medium))
                                .foregroundColor(.white)

                            Spacer()

                            if isSel {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSel ? Color.white.opacity(0.12) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Actions
            VStack(alignment: .leading, spacing: 4) {
                Button(action: {
                    showingBrandMenu = false
                    showingAddColorSheet = true
                }) {
                    Label("Add Color...", systemImage: "paintbrush.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.85))
                }
                .buttonStyle(.plain)

                if let brand = store.selectedBrand {
                    Button(action: {
                        showingBrandMenu = false
                        pickAndAddLogo(for: brand)
                    }) {
                        Label("Add Logo...", systemImage: "photo.badge.plus")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: {
                    store.isPinned.toggle()
                    store.savePreferences()
                    showingBrandMenu = false
                }) {
                    Label(store.isPinned ? "Unpin Dock" : "Pin Dock Open", systemImage: store.isPinned ? "pin.slash.fill" : "pin.fill")
                        .font(.system(size: 11))
                        .foregroundColor(store.isPinned ? .yellow : .white.opacity(0.85))
                }
                .buttonStyle(.plain)

                Button(action: {
                    showingBrandMenu = false
                    onSwitchMode()
                }) {
                    Label("Switch to Dynamic Island", systemImage: "capsule.portrait")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.85))
                }
                .buttonStyle(.plain)

                Button(action: {
                    showingBrandMenu = false
                    onOpenSettings()
                }) {
                    Label("Preferences...", systemImage: "gearshape")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.85))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 210)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
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
