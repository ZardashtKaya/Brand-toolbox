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
    @State private var showingAddBrandSheet: Bool = false
    @State private var showingAddColorSheet: Bool = false
    @State private var copiedColorId: UUID? = nil
    @State private var copiedLogoId: UUID? = nil

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
                expandedIslandView
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

    // MARK: - Closed Pill View

    private var closedPillView: some View {
        Button(action: onToggleExpand) {
            HStack(spacing: 8) {
                if let brand = store.selectedBrand {
                    // Accent dot
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
            .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded Island View

    private var expandedIslandView: some View {
        HStack(spacing: 12) {
            // Colors stack
            HStack(spacing: 6) {
                if let brand = store.selectedBrand {
                    ForEach(Array(brand.colors.prefix(3))) { color in
                        let isCopied = copiedColorId == color.id
                        Button(action: {
                            store.copyColor(color)
                            copiedColorId = color.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if copiedColorId == color.id { copiedColorId = nil }
                            }
                        }) {
                            ZStack {
                                Capsule()
                                    .fill(color.swiftUIColor)
                                    .frame(width: 44, height: 26)
                                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.8))

                                if isCopied {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(color.contrastTextColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .help("\(color.name): \(color.formattedHex)")
                    }
                }
            }

            Divider()
                .frame(height: 36)
                .background(Color.white.opacity(0.15))

            // Logos stack
            HStack(spacing: 8) {
                if let brand = store.selectedBrand {
                    ForEach(Array(brand.logos.prefix(3).enumerated()), id: \.element.id) { idx, logo in
                        let isDark = idx >= 2
                        Button(action: {
                            store.copyLogoImage(logo)
                            copiedLogoId = logo.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if copiedLogoId == logo.id { copiedLogoId = nil }
                            }
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isDark ? Color.gray.opacity(0.3) : Color.white)
                                    .frame(width: 38, height: 38)

                                if let img = store.imageForLogo(logo) {
                                    Image(nsImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .padding(4)
                                        .frame(width: 38, height: 38)
                                } else {
                                    Text("LOGO")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(isDark ? .white : .black)
                                }

                                if copiedLogoId == logo.id {
                                    Color.black.opacity(0.7)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
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

            Divider()
                .frame(height: 36)
                .background(Color.white.opacity(0.15))

            // Chevron Brand Switcher
            Button(action: { showingBrandMenu.toggle() }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingBrandMenu) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Select Brand").font(.headline)
                    Divider()
                    ForEach(store.brands) { b in
                        Button(action: {
                            store.selectedBrandId = b.id
                            showingBrandMenu = false
                        }) {
                            HStack {
                                Circle().fill(b.accentColor).frame(width: 12, height: 12)
                                Text(b.name).foregroundColor(.white)
                                Spacer()
                                if store.selectedBrandId == b.id {
                                    Image(systemName: "checkmark").foregroundColor(.accentColor)
                                }
                            }
                            .padding(.vertical, 3)
                        }
                        .buttonStyle(.plain)
                    }
                    Divider()
                    Button("Switch to Left Dock") {
                        showingBrandMenu = false
                        onSwitchMode()
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .frame(width: 180)
            }

            // Close
            Button(action: onToggleExpand) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(red: 0.05, green: 0.05, blue: 0.06))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.6), radius: 16, x: 0, y: 6)
    }
}
