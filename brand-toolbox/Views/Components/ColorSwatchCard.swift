import SwiftUI

@MainActor
public struct ColorSwatchCard: View {
    @ObservedObject var store: BrandStore
    public let color: BrandColor
    public let onEdit: () -> Void
    public let onDelete: () -> Void

    @State private var isHovered: Bool = false
    @State private var showCopiedBadge: Bool = false

    public init(
        store: BrandStore = .shared,
        color: BrandColor,
        onEdit: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {}
    ) {
        self.store = store
        self.color = color
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    public var body: some View {
        Button(action: {
            triggerCopy(format: nil)
        }) {
            HStack(spacing: 12) {
                // Color circle/squircle preview
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.swiftUIColor)
                        .frame(width: 36, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: color.swiftUIColor.opacity(0.35), radius: 4, x: 0, y: 2)

                    if showCopiedBadge {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(color.contrastTextColor)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                // Name & Hex
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(color.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if color.role != .custom {
                            Text(color.role.rawValue.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.white.opacity(0.1)))
                        }
                    }

                    Text(color.formattedHex)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.65))
                }

                Spacer()

                // Copy Action Indicator
                ZStack {
                    if showCopiedBadge {
                        Text("COPIED!")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(Color.green.opacity(0.2))
                            )
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    } else if isHovered {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .transition(.opacity)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHovered ? Color.white.opacity(0.1) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        showCopiedBadge ? Color.green.opacity(0.4) : (isHovered ? Color.white.opacity(0.2) : Color.white.opacity(0.06)),
                        lineWidth: 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Copy #HEX (\(color.formattedHex))") {
                triggerCopy(format: .hexHash)
            }
            Button("Copy Plain HEX (\(color.normalizedHex))") {
                triggerCopy(format: .hexPlain)
            }
            Button("Copy RGB (\(color.formatted(for: .rgb)))") {
                triggerCopy(format: .rgb)
            }
            Button("Copy SwiftUI Color (\(color.formatted(for: .swiftUI)))") {
                triggerCopy(format: .swiftUI)
            }
            Button("Copy CSS Variable (\(color.formatted(for: .cssVar)))") {
                triggerCopy(format: .cssVar)
            }
            Divider()
            Button("Edit Color...") {
                onEdit()
            }
            Button("Delete Color", role: .destructive) {
                onDelete()
            }
        }
    }

    private func triggerCopy(format: CopyFormat?) {
        store.copyColor(color, format: format)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            showCopiedBadge = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.2)) {
                showCopiedBadge = false
            }
        }
    }
}
