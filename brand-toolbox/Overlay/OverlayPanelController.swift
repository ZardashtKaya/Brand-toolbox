import AppKit
import SwiftUI
import Combine

// MARK: - Custom Floating NSPanel

public final class OverlayPanel: NSPanel {
    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return false
    }
}

// MARK: - Overlay Panel Controller

@MainActor
public final class OverlayPanelController: ObservableObject {
    public static let shared = OverlayPanelController()

    @Published public var isExpanded: Bool = false

    private var panel: OverlayPanel?
    private var store: BrandStore = .shared

    private var globalMoveMonitor: Any?
    private var localMoveMonitor: Any?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?

    private var autoCollapseWorkItem: DispatchWorkItem?
    private var settingsWindowController: NSWindowController?
    private var cancellables = Set<AnyCancellable>()

    public init() {
        // Observe mode changes to update position
        store.$overlayMode
            .sink { [weak self] _ in
                self?.repositionPanel(animated: true)
            }
            .store(in: &cancellables)

        store.$isPinned
            .sink { [weak self] pinned in
                if pinned {
                    self?.autoCollapseWorkItem?.cancel()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Setup & Presentation

    public func setup() {
        if panel != nil { return }

        let initialFrame = calculatePanelFrame(isExpanded: false)
        let newPanel = OverlayPanel(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        newPanel.isFloatingPanel = true
        newPanel.level = .statusBar
        newPanel.sharingType = .readOnly
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = false
        newPanel.isMovable = false
        newPanel.hidesOnDeactivate = false
        newPanel.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces, .ignoresCycle, .stationary]
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true

        let rootView = BrandToolboxMainView(
            store: store,
            isExpanded: Binding(
                get: { self.isExpanded },
                set: { self.setExpanded($0) }
            ),
            onToggleExpand: { [weak self] in
                self?.toggleExpand()
            },
            onTogglePin: { [weak self] in
                guard let self else { return }
                self.store.isPinned.toggle()
                self.store.savePreferences()
            },
            onSwitchMode: { [weak self] in
                self?.toggleMode()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            }
        )

        let hostingView = NSHostingView(rootView: rootView)
        newPanel.contentView = hostingView
        self.panel = newPanel

        newPanel.orderFrontRegardless()
        startMouseMonitoring()
    }

    public func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else { return }
        isExpanded = expanded
        repositionPanel(animated: true)
    }

    public func toggleExpand() {
        setExpanded(!isExpanded)
    }

    public func toggleMode() {
        if store.overlayMode == .leftDock {
            store.overlayMode = .dynamicIsland
        } else {
            store.overlayMode = .leftDock
        }
        store.savePreferences()
        repositionPanel(animated: true)
    }

    public func openSettings() {
        if let existing = settingsWindowController {
            existing.showWindow(nil)
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(store: store)
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Brand Toolbox Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()

        let wc = NSWindowController(window: window)
        self.settingsWindowController = wc
        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Frame Calculation & Positioning

    public func repositionPanel(animated: Bool = true) {
        guard let panel, let screen = targetScreen() else { return }
        let targetFrame = calculatePanelFrame(isExpanded: isExpanded, screen: screen)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(targetFrame, display: true)
            }
        } else {
            panel.setFrame(targetFrame, display: true)
        }
    }

    private func targetScreen() -> NSScreen? {
        // Return screen containing cursor, or main screen
        let mouseLocation = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            if NSMouseInRect(mouseLocation, screen.frame, false) {
                return screen
            }
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private func calculatePanelFrame(isExpanded: Bool, screen: NSScreen? = nil) -> NSRect {
        guard let screen = screen ?? targetScreen() else {
            return NSRect(x: 0, y: 0, width: 320, height: 560)
        }

        let sFrame = screen.frame

        switch store.overlayMode {
        case .leftDock:
            let width: CGFloat = isExpanded ? 320 : 16
            let height: CGFloat = isExpanded ? 560 : 76
            let x: CGFloat = isExpanded ? (sFrame.minX + 8) : sFrame.minX
            let y: CGFloat = sFrame.midY - (height / 2)
            return NSRect(x: x, y: y, width: width, height: height)

        case .rightDock:
            let width: CGFloat = isExpanded ? 320 : 16
            let height: CGFloat = isExpanded ? 560 : 76
            let x: CGFloat = isExpanded ? (sFrame.maxX - width - 8) : (sFrame.maxX - width)
            let y: CGFloat = sFrame.midY - (height / 2)
            return NSRect(x: x, y: y, width: width, height: height)

        case .dynamicIsland:
            if isExpanded {
                let width: CGFloat = 530
                let height: CGFloat = 380
                let x = sFrame.midX - (width / 2)
                let y = sFrame.maxY - height
                return NSRect(x: x, y: y, width: width, height: height)
            } else {
                let width: CGFloat = 230
                let height: CGFloat = screen.hasNotch ? max(36, screen.notchHeight) : 36
                let x = sFrame.midX - (width / 2)
                let y = sFrame.maxY - height
                return NSRect(x: x, y: y, width: width, height: height)
            }
        }
    }

    // MARK: - Mouse Event Monitoring & Hover Triggers

    private func startMouseMonitoring() {
        stopMouseMonitoring()

        var lastMoveTime: TimeInterval = 0
        let throttleInterval: TimeInterval = 0.04

        globalMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            let now = ProcessInfo.processInfo.systemUptime
            guard now - lastMoveTime >= throttleInterval else { return }
            lastMoveTime = now
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                self?.handleMouseMoved(location)
            }
        }

        localMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            let now = ProcessInfo.processInfo.systemUptime
            guard now - lastMoveTime >= throttleInterval else { return event }
            lastMoveTime = now
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                self?.handleMouseMoved(location)
            }
            return event
        }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                self?.handleMouseDown(location)
            }
        }

        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                self?.handleMouseDown(location)
            }
            return event
        }
    }

    private func stopMouseMonitoring() {
        if let g = globalMoveMonitor { NSEvent.removeMonitor(g) }
        if let l = localMoveMonitor { NSEvent.removeMonitor(l) }
        if let gc = globalClickMonitor { NSEvent.removeMonitor(gc) }
        if let lc = localClickMonitor { NSEvent.removeMonitor(lc) }
        globalMoveMonitor = nil
        localMoveMonitor = nil
        globalClickMonitor = nil
        localClickMonitor = nil
    }

    private func handleMouseMoved(_ location: NSPoint) {
        guard let panel, let screen = targetScreen() else { return }
        let panelFrame = panel.frame

        switch store.overlayMode {
        case .leftDock:
            let sensitivity = CGFloat(store.edgeSensitivityPx)
            let isAtLeftEdge = location.x <= (screen.frame.minX + sensitivity)

            if !isExpanded && isAtLeftEdge {
                // User hovered far left edge: open dock!
                autoCollapseWorkItem?.cancel()
                setExpanded(true)
            } else if isExpanded {
                // Generous hit test area so the cursor can move around comfortably
                let hitArea = panelFrame.insetBy(dx: -30, dy: -30)
                if NSMouseInRect(location, hitArea, false) {
                    autoCollapseWorkItem?.cancel()
                } else if !store.isPinned {
                    scheduleAutoCollapse()
                }
            }

        case .rightDock:
            let sensitivity = CGFloat(store.edgeSensitivityPx)
            let isAtRightEdge = location.x >= (screen.frame.maxX - sensitivity)

            if !isExpanded && isAtRightEdge {
                autoCollapseWorkItem?.cancel()
                setExpanded(true)
            } else if isExpanded {
                let hitArea = panelFrame.insetBy(dx: -30, dy: -30)
                if NSMouseInRect(location, hitArea, false) {
                    autoCollapseWorkItem?.cancel()
                } else if !store.isPinned {
                    scheduleAutoCollapse()
                }
            }

        case .dynamicIsland:
            let isNearNotch = location.y >= (screen.frame.maxY - 45) && abs(location.x - screen.frame.midX) <= 130

            if !isExpanded && isNearNotch {
                autoCollapseWorkItem?.cancel()
                setExpanded(true)
            } else if isExpanded {
                let hitArea = panelFrame.insetBy(dx: -30, dy: -30)
                if NSMouseInRect(location, hitArea, false) {
                    autoCollapseWorkItem?.cancel()
                } else if !store.isPinned {
                    scheduleAutoCollapse()
                }
            }
        }
    }

    private func handleMouseDown(_ location: NSPoint) {
        guard let panel, isExpanded, !store.isPinned else { return }
        let hitArea = panel.frame
        if !NSMouseInRect(location, hitArea, false) {
            // Click outside when unpinned: collapse immediately
            setExpanded(false)
        }
    }

    private func scheduleAutoCollapse() {
        guard autoCollapseWorkItem == nil else { return }

        let item = DispatchWorkItem { [weak self] in
            guard let self, !self.store.isPinned else { return }
            self.setExpanded(false)
            self.autoCollapseWorkItem = nil
        }
        self.autoCollapseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + store.autoHideDelay, execute: item)
    }
}
