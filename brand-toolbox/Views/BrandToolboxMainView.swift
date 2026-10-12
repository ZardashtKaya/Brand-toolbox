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
                    isExpanded: isExpanded,
                    onToggleExpand: onToggleExpand,
                    onTogglePin: onTogglePin,
                    onSwitchMode: onSwitchMode,
                    onOpenSettings: onOpenSettings
                )
            }
        }
    }
}
