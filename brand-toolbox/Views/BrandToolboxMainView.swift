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
                MiniDockView(
                    store: store,
                    onToggleExpand: onToggleExpand,
                    onTogglePin: onTogglePin,
                    onSwitchMode: onSwitchMode,
                    onOpenSettings: onOpenSettings
                )

            case .dynamicIsland:
                DynamicIslandMiniView(
                    store: store,
                    onToggleExpand: onToggleExpand,
                    onTogglePin: onTogglePin,
                    onSwitchMode: onSwitchMode,
                    onOpenSettings: onOpenSettings
                )
            }
        }
    }
}

// MARK: - Previews

#Preview("Vertical Dock Mode") {
    ZStack {
        LinearGradient(
            colors: [Color.indigo.opacity(0.6), Color.black.opacity(0.9)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        HStack {
            BrandToolboxMainView(
                store: {
                    let s = BrandStore.shared
                    s.overlayMode = .leftDock
                    return s
                }(),
                isExpanded: .constant(true)
            )
            .padding(.leading, 12)
            Spacer()
        }
    }
    .frame(width: 400, height: 600)
}

#Preview("Dynamic Island Mode") {
    ZStack(alignment: .top) {
        LinearGradient(
            colors: [Color.indigo.opacity(0.6), Color.black.opacity(0.9)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        BrandToolboxMainView(
            store: {
                let s = BrandStore.shared
                s.overlayMode = .dynamicIsland
                return s
            }(),
            isExpanded: .constant(true)
        )
        .padding(.top, 12)
    }
    .frame(width: 480, height: 420)
}
