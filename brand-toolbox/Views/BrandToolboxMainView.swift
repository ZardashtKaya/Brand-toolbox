import SwiftUI

@MainActor
public struct BrandToolboxMainView: View {
    @ObservedObject var store: BrandStore
    @Binding var isExpanded: Bool
    public let onToggleExpand: () -> Void
    public let onTogglePin: () -> Void
    public let onSwitchMode: () -> Void
    public let onOpenSettings: () -> Void

    public init(
        store: BrandStore = .shared,
        isExpanded: Binding<Bool>,
        onToggleExpand: @escaping () -> Void = {},
        onTogglePin: @escaping () -> Void = {},
        onSwitchMode: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.store = store
        self._isExpanded = isExpanded
        self.onToggleExpand = onToggleExpand
        self.onTogglePin = onTogglePin
        self.onSwitchMode = onSwitchMode
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        Group {
            switch store.overlayMode {
            case .leftDock, .rightDock:
                if isExpanded {
                    LeftDockView(
                        store: store,
                        onTogglePin: onTogglePin,
                        onSwitchMode: onSwitchMode,
                        onOpenSettings: onOpenSettings
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: store.overlayMode == .leftDock ? .leading : .trailing).combined(with: .opacity),
                        removal: .move(edge: store.overlayMode == .leftDock ? .leading : .trailing).combined(with: .opacity)
                    ))
                } else {
                    // Peek strip indicator on the screen edge
                    collapsedDockPeekStrip
                }

            case .dynamicIsland:
                DynamicIslandView(
                    store: store,
                    isExpanded: isExpanded,
                    onToggleExpand: onToggleExpand,
                    onTogglePin: onTogglePin,
                    onSwitchMode: onSwitchMode,
                    onOpenSettings: onOpenSettings
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.overlayMode)
    }

    // MARK: - Collapsed Dock Peek Strip

    private var collapsedDockPeekStrip: some View {
        Button(action: onToggleExpand) {
            ZStack {
                Capsule()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: 8, height: 72)
                    .overlay(
                        Capsule()
                            .fill(store.selectedBrand?.accentColor ?? Color.white)
                            .frame(width: 4, height: 36)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: (store.selectedBrand?.accentColor ?? Color.white).opacity(0.5), radius: 6, x: 2, y: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Hover to open Brand Toolbox")
    }
}
