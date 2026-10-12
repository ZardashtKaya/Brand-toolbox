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

    @State private var showingBrandMenu: Bool = false
    @State private var copiedColorId: UUID? = nil
    @State private var copiedLogoId: UUID? = nil
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
            .shadow(color: Color.black.opacity(0.55), radius: 12, x: 0, y: 4)
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
                                store.selectedBrandId = brand.id
                                store.savePreferences()
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
                                                Text("LOGO")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(isDark ? .white : .black)
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
                                    .onDrag {
                                        let p = NSItemProvider()
                                        if let f = store.fileURLForLogo(logo) {
                                            p.registerObject(f as NSURL, visibility: .all)
                                        }
                                        if let img = store.imageForLogo(logo) {
                                            p.registerObject(img, visibility: .all)
                                        }
                                        return p
                                    }
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
                .stroke(Color.white.opacity(0.2), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.65), radius: 20, x: 0, y: 8)
    }

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
}
