import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
public struct DynamicIslandMiniView: View {
    @ObservedObject var store: BrandStore
    public let isExpanded: Bool
    public let onToggleExpand: () -> Void
    public let onTogglePin: () -> Void
    public let onSwitchMode: () -> Void
    public let onOpenSettings: () -> Void

    @State private var copiedColorId: UUID? = nil
    @State private var copiedLogoId: UUID? = nil
    @State private var copiedFontId: UUID? = nil
    @State private var isDropTargeted: Bool = false
    @State private var isLogoDropTargeted: Bool = false

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
                fullyOpenedIslandView
            } else {
                closedPillView
            }
        }
    }

    // MARK: - Closed Pill View (Hugs the notch / Dynamic Island)

    private var closedPillView: some View {
        Button(action: onToggleExpand) {
            HStack(spacing: 8) {
                if let brand = store.selectedBrand {
                    // Brand Icon Dot
                    Circle()
                        .fill(brand.accentColor)
                        .frame(width: 14, height: 14)

                    Text(brand.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)

                    Spacer(minLength: 4)

                    // Color capsules preview
                    HStack(spacing: 3) {
                        ForEach(brand.colors.prefix(3)) { c in
                            Capsule()
                                .fill(c.swiftUIColor)
                                .frame(width: 14, height: 8)
                        }
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(width: 210, height: 36)
            .background(Color(red: 0.05, green: 0.05, blue: 0.06))
            .clipShape(ClosedPillShape(cornerRadius: 18))
            .overlay(
                ClosedPillShape(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("Click to expand Brand Island")
    }

    // MARK: - Fully Opened Island View

    private var fullyOpenedIslandView: some View {
        VStack(spacing: 10) {
            // Header Bar
            HStack(spacing: 8) {
                // Brand selector chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(store.brands) { brand in
                            let isSel = store.selectedBrandId == brand.id
                            Button(action: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                    store.selectedBrandId = brand.id
                                    store.savePreferences()
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(brand.accentColor)
                                        .frame(width: 8, height: 8)
                                    Text(brand.name)
                                        .font(.system(size: 11, weight: isSel ? .bold : .medium))
                                        .foregroundColor(isSel ? .white : .white.opacity(0.6))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(isSel ? Color.white.opacity(0.16) : Color.white.opacity(0.04)))
                                .overlay(
                                    Capsule().stroke(isSel ? brand.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .help("\(brand.name) (Click to select, Right-click to manage)")
                            .contextMenu {
                                Button("Add Color...") {
                                    store.selectedBrandId = brand.id
                                    OverlayPanelController.shared.openAddColorWindow()
                                }
                                Button("Add Logo...") {
                                    store.selectedBrandId = brand.id
                                    pickAndAddLogo(for: brand)
                                }
                                Button("Add Font...") {
                                    store.selectedBrandId = brand.id
                                    OverlayPanelController.shared.openAddFontWindow()
                                }
                                if store.brands.count > 1 {
                                    Divider()
                                    Button("Delete Brand '\(brand.name)'", role: .destructive) {
                                        store.deleteBrand(brand)
                                    }
                                }
                            }
                        }

                        Button(action: {
                            OverlayPanelController.shared.openAddBrandWindow()
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(5)
                                .background(Circle().fill(Color.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                        .help("Add New Brand")
                    }
                }

                Spacer()

                // Switch to Left Dock Mode
                Button(action: onSwitchMode) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(5)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Switch to Left Dock Mode")

                // Pin Button
                Button(action: onTogglePin) {
                    Image(systemName: store.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(store.isPinned ? .yellow : .white.opacity(0.75))
                        .padding(5)
                        .background(Circle().fill(store.isPinned ? Color.yellow.opacity(0.2) : Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help(store.isPinned ? "Unpin" : "Pin open")

                // Settings
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(5)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Preferences")

                // Collapse Button
                Button(action: onToggleExpand) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(5)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Collapse")
            }

            Divider()
                .background(Color.white.opacity(0.12))

            // Body: 2 Columns (Colors on Left, Logos on Right)
            if let brand = store.selectedBrand {
                HStack(alignment: .top, spacing: 14) {
                    // LEFT: Colors
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("COLORS")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.45))
                                .tracking(0.6)
                            Spacer()
                            Button(action: {
                                OverlayPanelController.shared.openAddColorWindow()
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(brand.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("Add Color")
                        }

                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 6) {
                                ForEach(brand.colors) { color in
                                    let isCopied = copiedColorId == color.id
                                    Button(action: {
                                        store.copyColor(color)
                                        withAnimation { copiedColorId = color.id }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            if copiedColorId == color.id { copiedColorId = nil }
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            Capsule()
                                                .fill(color.swiftUIColor)
                                                .frame(width: 32, height: 18)
                                                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))

                                            Text(color.name)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.white)
                                                .lineLimit(1)

                                            Spacer()

                                            if isCopied {
                                                Text("COPIED")
                                                    .font(.system(size: 8, weight: .heavy))
                                                    .foregroundColor(.green)
                                            } else {
                                                Text(color.formattedHex)
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundColor(.white.opacity(0.55))
                                            }
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                                    }
                                    .buttonStyle(.plain)
                                    .help("\(color.name): \(color.formattedHex) (Click to copy, Right-click for options)")
                                    .contextMenu {
                                        Button("Copy \(color.formattedHex)") {
                                            store.copyColor(color)
                                        }
                                        Button("Copy RGB (\(color.formatted(for: .rgb)))") {
                                            store.copyColor(color, format: .rgb)
                                        }
                                        Button("Copy SwiftUI Color") {
                                            store.copyColor(color, format: .swiftUI)
                                        }
                                        Button("Copy CSS (\(color.formatted(for: .cssVar)))") {
                                            store.copyColor(color, format: .cssVar)
                                        }
                                        Divider()
                                        Button("Add Color...") {
                                            OverlayPanelController.shared.openAddColorWindow()
                                        }
                                        Button("Delete Color", role: .destructive) {
                                            store.deleteColor(from: brand, colorId: color.id)
                                        }
                                    }
                                }

                                if brand.colors.isEmpty {
                                    Button(action: {
                                        OverlayPanelController.shared.openAddColorWindow()
                                    }) {
                                        HStack {
                                            Image(systemName: "plus.circle")
                                            Text("Add Color")
                                        }
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.4))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                                .foregroundColor(Color.white.opacity(0.15))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Divider()
                        .background(Color.white.opacity(0.12))

                    // RIGHT: Logos
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("LOGOS")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.45))
                                .tracking(0.6)
                            Spacer()
                            Button(action: {
                                pickAndAddLogo(for: brand)
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(brand.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("Add Logo")
                        }

                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                                ForEach(Array(brand.logos.enumerated()), id: \.element.id) { idx, logo in
                                    let isDark = idx >= 2
                                    Button(action: {
                                        store.copyLogoImage(logo)
                                        withAnimation { copiedLogoId = logo.id }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            if copiedLogoId == logo.id { copiedLogoId = nil }
                                        }
                                    }) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(isDark ? Color.gray.opacity(0.25) : Color.white)
                                                .frame(height: 48)

                                            if let img = store.imageForLogo(logo) {
                                                Image(nsImage: img)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .padding(6)
                                            } else {
                                                Text(logo.name.prefix(4).uppercased())
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(isDark ? .white : .black)
                                            }

                                            // SVG Pill Badge
                                            if store.isSVGLogo(logo) {
                                                VStack {
                                                    HStack {
                                                        Spacer()
                                                        Text("SVG")
                                                            .font(.system(size: 7, weight: .heavy, design: .rounded))
                                                            .foregroundColor(.white.opacity(0.9))
                                                            .padding(.horizontal, 3.5)
                                                            .padding(.vertical, 1.5)
                                                            .background(Capsule().fill(Color.black.opacity(0.7)))
                                                            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                                                            .padding(3.5)
                                                    }
                                                    Spacer()
                                                }
                                            }

                                            if copiedLogoId == logo.id {
                                                Color.black.opacity(0.7)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .help("\(logo.name) (Click to copy, Drag to use, Right-click for options)")
                                    .onDrag {
                                        createDragProvider(for: logo)
                                    }
                                    .contextMenu {
                                        Button("Copy Logo") {
                                            store.copyLogoImage(logo)
                                        }
                                        if store.isSVGLogo(logo) {
                                            Button("Copy SVG Code") {
                                                store.copySVGCode(logo)
                                            }
                                        }
                                        if let fileURL = store.fileURLForLogo(logo) {
                                            Button("Reveal in Finder") {
                                                NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                                            }
                                        }
                                        Divider()
                                        Button("Delete Logo", role: .destructive) {
                                            store.deleteLogo(from: brand, logoId: logo.id)
                                        }
                                    }
                                }
                                dropAndAddTile(brand: brand)
                            }

                            Divider()
                                .background(Color.white.opacity(0.12))
                                .padding(.vertical, 4)

                            // FONTS Section
                            HStack {
                                Text("FONTS")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.45))
                                    .tracking(0.6)
                                Spacer()
                                Button(action: {
                                    OverlayPanelController.shared.openAddFontWindow()
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(brand.accentColor)
                                }
                                .buttonStyle(.plain)
                                .help("Add Font")
                            }

                            VStack(spacing: 5) {
                                ForEach(brand.fonts) { font in
                                    fontRow(font: font, brand: brand)
                                }

                                if brand.fonts.isEmpty {
                                    Button(action: {
                                        OverlayPanelController.shared.openAddFontWindow()
                                    }) {
                                        HStack {
                                            Image(systemName: "textformat")
                                            Text("Add Font")
                                        }
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.4))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                                .foregroundColor(Color.white.opacity(0.15))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 440, height: 220)
        .background(Color(red: 0.05, green: 0.05, blue: 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isDropTargeted ? 0.45 : 0.2),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isDropTargeted ? 1.8 : 1.2
                )
        )
        .onDrop(of: [.fileURL, .image, .png, .jpeg, .tiff, .svg, .plainText], isTargeted: $isDropTargeted) { providers in
            if let brand = store.selectedBrand {
                return store.handleDroppedProviders(providers, for: brand)
            }
            return false
        }
    }

    private func pickAndAddLogo(for brand: Brand) {
        OverlayPanelController.shared.isInteracting = true
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
        OverlayPanelController.shared.isInteracting = false
    }

    private func createDragProvider(for logo: BrandLogo) -> NSItemProvider {
        let provider = NSItemProvider()
        if let fileURL = store.fileURLForLogo(logo) {
            let isSVG = store.isSVGLogo(logo)
            let primaryType: UTType = isSVG ? .svg : .image

            provider.registerFileRepresentation(
                forTypeIdentifier: primaryType.identifier,
                fileOptions: [],
                visibility: .all
            ) { completion in
                completion(fileURL, false, nil)
                return nil
            }

            if isSVG {
                provider.registerFileRepresentation(
                    forTypeIdentifier: UTType.image.identifier,
                    fileOptions: [],
                    visibility: .all
                ) { completion in
                    completion(fileURL, false, nil)
                    return nil
                }
                if let svgContent = store.svgContentForLogo(logo) {
                    provider.registerObject(svgContent as NSString, visibility: .all)
                }
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

    private func fontRow(font: BrandFont, brand: Brand) -> some View {
        let isCopied = copiedFontId == font.id

        return Button(action: {
            store.copyFontName(font)
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                copiedFontId = font.id
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                withAnimation(.easeOut(duration: 0.2)) {
                    if copiedFontId == font.id {
                        copiedFontId = nil
                    }
                }
            }
        }) {
            HStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 22, height: 18)
                    Text("Aa")
                        .font(.system(size: 9, weight: .bold, design: .serif))
                        .foregroundColor(.white.opacity(0.75))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(font.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if !font.role.isEmpty {
                        Text(font.role)
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                Spacer(minLength: 4)

                if isCopied {
                    Text("COPIED")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4.5)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
        }
        .buttonStyle(.plain)
        .help("\(font.name) (\(font.role)) - Click to copy font name")
        .contextMenu {
            Button("Copy Font Name") {
                store.copyFontName(font)
            }
            Divider()
            Button("Delete Font", role: .destructive) {
                store.deleteFont(from: brand, fontId: font.id)
            }
        }
    }

    private func dropAndAddTile(brand: Brand) -> some View {
        Button(action: {
            pickAndAddLogo(for: brand)
        }) {
            VStack(spacing: 3) {
                Image(systemName: isLogoDropTargeted ? "arrow.down.circle.fill" : "plus.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isLogoDropTargeted ? brand.accentColor : .white.opacity(0.55))
                Text(isLogoDropTargeted ? "Drop Here" : "Drop / Add")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(isLogoDropTargeted ? brand.accentColor : .white.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isLogoDropTargeted ? brand.accentColor.opacity(0.22) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: isLogoDropTargeted ? 1.6 : 1, dash: [4, 3])
                    )
                    .foregroundColor(isLogoDropTargeted ? brand.accentColor : Color.white.opacity(0.2))
            )
        }
        .buttonStyle(.plain)
        .help("Drag & drop an image or click to choose file")
        .onDrop(of: [.fileURL, .image, .png, .jpeg, .tiff, .svg, .plainText], isTargeted: $isLogoDropTargeted) { providers in
            store.handleDroppedProviders(providers, for: brand)
        }
    }
}

// MARK: - Previews

#Preview("Dynamic Island - Expanded") {
    ZStack(alignment: .top) {
        LinearGradient(
            colors: [Color(red: 0.12, green: 0.12, blue: 0.22), Color.black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        DynamicIslandMiniView(
            store: .shared,
            isExpanded: true
        )
        .padding(.top, 16)
    }
    .frame(width: 480, height: 420)
}

#Preview("Dynamic Island - Closed Pill") {
    ZStack(alignment: .top) {
        LinearGradient(
            colors: [Color(red: 0.12, green: 0.12, blue: 0.22), Color.black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        DynamicIslandMiniView(
            store: .shared,
            isExpanded: false
        )
        .padding(.top, 16)
    }
    .frame(width: 320, height: 120)
}
