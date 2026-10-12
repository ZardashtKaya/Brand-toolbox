import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
public struct LogoCardView: View {
    @ObservedObject var store: BrandStore
    public let logo: BrandLogo
    public let onDelete: () -> Void

    @State private var isHovered: Bool = false
    @State private var showCopiedBadge: Bool = false

    public init(
        store: BrandStore = .shared,
        logo: BrandLogo,
        onDelete: @escaping () -> Void = {}
    ) {
        self.store = store
        self.logo = logo
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))

                // Optional subtle checkerboard
                CheckerboardView(squareSize: 6)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .opacity(0.4)

                // Logo preview
                if let nsImage = store.imageForLogo(logo) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.4))
                }

                // Drag indicator overlay on hover
                if isHovered && !showCopiedBadge {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "hand.draw.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        Spacer()
                    }
                    .padding(5)
                    .transition(.opacity)
                }

                // Copied feedback badge
                if showCopiedBadge {
                    ZStack {
                        Color.black.opacity(0.7)
                        VStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.green)
                            Text("COPIED")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .transition(.opacity)
                }
            }
            .frame(height: 74)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isHovered ? Color.white.opacity(0.25) : Color.white.opacity(0.08), lineWidth: 1)
            )

            // Name
            Text(logo.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(4)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        // CLICK TO COPY
        .onTapGesture {
            store.copyLogoImage(logo)
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                showCopiedBadge = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showCopiedBadge = false
                }
            }
        }
        // DRAG AND DROP OUT
        .onDrag {
            createItemProvider()
        }
        .contextMenu {
            Button("Copy Image") {
                store.copyLogoImage(logo)
            }
            if let fileURL = store.fileURLForLogo(logo) {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                }
            }
            Divider()
            Button("Delete Logo", role: .destructive) {
                onDelete()
            }
        }
    }

    private func createItemProvider() -> NSItemProvider {
        let provider = NSItemProvider()

        if let fileURL = store.fileURLForLogo(logo) {
            // Register file URL for Finder, Desktop, Figma
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
}
