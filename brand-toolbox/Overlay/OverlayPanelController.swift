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

    @Published public var isExpanded: Bool = true
    @Published public var isInteracting: Bool = false

    private var panel: OverlayPanel?
    private var store: BrandStore = .shared

    private var globalMoveMonitor: Any?
    private var localMoveMonitor: Any?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?

    private var autoCollapseWorkItem: DispatchWorkItem?
    private var settingsWindowController: NSWindowController?
    private var addBrandWindowController: NSWindowController?
    private var addColorWindowController: NSWindowController?
    private var addFontWindowController: NSWindowController?
    private var cancellables = Set<AnyCancellable>()

    public init() {
        // Observe mode changes or brand changes to update frame & height
        store.$overlayMode
            .sink { [weak self] _ in
                self?.repositionPanel(animated: true)
            }
            .store(in: &cancellables)

        store.$selectedBrandId
            .sink { [weak self] _ in
                self?.repositionPanel(animated: true)
            }
            .store(in: &cancellables)

        store.$brands
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

        // Keep panel open and active during any context menu interaction
        NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isInteracting = true
            self?.autoCollapseWorkItem?.cancel()
        }

        NotificationCenter.default.addObserver(
            forName: NSMenu.didEndTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self?.isInteracting = false
            }
        }
    }

    // MARK: - Setup & Presentation

    public func setup() {
        if panel != nil { return }

        let initialFrame = calculatePanelFrame(isExpanded: true)
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

        // Launch peek grace period: let user see the dock, then collapse after 3.5s if not hovered or pinned
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            guard let self, !self.store.isPinned, !self.isInteracting else { return }
            let mouseLoc = NSEvent.mouseLocation
            if let panel = self.panel, !NSMouseInRect(mouseLoc, panel.frame.insetBy(dx: -40, dy: -40), false) {
                self.setExpanded(false)
            }
        }
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
        isInteracting = true
        if let existing = settingsWindowController {
            existing.showWindow(nil)
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(store: store)
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Brand Toolbox Preferences"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.isInteracting = false
        }

        let wc = NSWindowController(window: window)
        self.settingsWindowController = wc
        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func openAddBrandWindow() {
        isInteracting = true
        if let existing = addBrandWindowController {
            existing.close()
            self.addBrandWindowController = nil
        }

        var windowRef: NSWindow?
        let closeHandler: () -> Void = { [weak self] in
            windowRef?.close()
            self?.addBrandWindowController = nil
            self?.isInteracting = false
        }

        let sheetView = AddBrandSheet(store: store, onClose: closeHandler)
        let hostingController = NSHostingController(rootView: sheetView)
        let window = NSWindow(contentViewController: hostingController)
        windowRef = window
        window.title = "Create New Brand"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.backgroundColor = .white
        window.level = .floating
        window.center()

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.addBrandWindowController = nil
            self?.isInteracting = false
        }

        let wc = NSWindowController(window: window)
        self.addBrandWindowController = wc
        wc.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func openAddColorWindow() {
        guard let brand = store.selectedBrand else { return }
        isInteracting = true
        if let existing = addColorWindowController {
            existing.close()
            self.addColorWindowController = nil
        }

        var windowRef: NSWindow?
        let closeHandler: () -> Void = { [weak self] in
            windowRef?.close()
            self?.addColorWindowController = nil
            self?.isInteracting = false
        }

        let sheetView = AddColorSheet(store: store, brand: brand, onClose: closeHandler)
        let hostingController = NSHostingController(rootView: sheetView)
        let window = NSWindow(contentViewController: hostingController)
        windowRef = window
        window.title = "Add Color • \(brand.name)"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.backgroundColor = .white
        window.level = .floating
        window.center()

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.addColorWindowController = nil
            self?.isInteracting = false
        }

        let wc = NSWindowController(window: window)
        self.addColorWindowController = wc
        wc.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func openAddFontWindow() {
        guard let brand = store.selectedBrand else { return }
        isInteracting = true
        if let existing = addFontWindowController {
            existing.close()
            self.addFontWindowController = nil
        }

        var windowRef: NSWindow?
        let closeHandler: () -> Void = { [weak self] in
            windowRef?.close()
            self?.addFontWindowController = nil
            self?.isInteracting = false
        }

        let sheetView = AddFontSheet(store: store, brand: brand, onClose: closeHandler)
        let hostingController = NSHostingController(rootView: sheetView)
        let window = NSWindow(contentViewController: hostingController)
        windowRef = window
        window.title = "Add Font • \(brand.name)"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.backgroundColor = .white
        window.level = .floating
        window.center()

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.addFontWindowController = nil
            self?.isInteracting = false
        }

        let wc = NSWindowController(window: window)
        self.addFontWindowController = wc
        wc.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
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
            return NSRect(x: 14, y: 200, width: 76, height: 380)
        }

        let sFrame = screen.frame

        switch store.overlayMode {
        case .leftDock:
            let width: CGFloat = 196
            let height = store.idealDockHeight(maxAllowed: sFrame.height - 120)
            let y: CGFloat = sFrame.minY + (sFrame.height - height) / 2
            let x: CGFloat = isExpanded ? (sFrame.minX + 14) : (sFrame.minX - width + 6)
            return NSRect(x: x, y: y, width: width, height: height)

        case .rightDock:
            let width: CGFloat = 196
            let height = store.idealDockHeight(maxAllowed: sFrame.height - 120)
            let y: CGFloat = sFrame.minY + (sFrame.height - height) / 2
            let x: CGFloat = isExpanded ? (sFrame.maxX - width - 14) : (sFrame.maxX - 6)
            return NSRect(x: x, y: y, width: width, height: height)

        case .dynamicIsland:
            if isExpanded {
                let width: CGFloat = 440
                let height: CGFloat = 220
                let x = sFrame.midX - (width / 2)
                let topOffset: CGFloat = screen.hasNotch ? screen.notchHeight + 2 : 10
                let y = sFrame.maxY - height - topOffset
                return NSRect(x: x, y: y, width: width, height: height)
            } else {
                let width: CGFloat = 210
                let height: CGFloat = 36
                let x = sFrame.midX - (width / 2)
                let y = sFrame.maxY - height - (screen.hasNotch ? 0 : 8)
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

        // Never auto-collapse if user is actively interacting with a menu/sheet, or pinned
        if isInteracting || store.isPinned {
            autoCollapseWorkItem?.cancel()
            return
        }

        switch store.overlayMode {
        case .leftDock:
            let sensitivity = CGFloat(max(10, store.edgeSensitivityPx))
            let isAtLeftEdge = location.x <= (screen.frame.minX + sensitivity)

            if isAtLeftEdge {
                autoCollapseWorkItem?.cancel()
                if !isExpanded {
                    setExpanded(true)
                }
            } else if isExpanded {
                // Wide hit area including any popover tray to the right (up to x: 300)
                let dockHitArea = NSRect(
                    x: screen.frame.minX - 10,
                    y: panelFrame.minY - 30,
                    width: panelFrame.width + 40,
                    height: panelFrame.height + 60
                )
                if NSMouseInRect(location, dockHitArea, false) {
                    autoCollapseWorkItem?.cancel()
                } else {
                    scheduleAutoCollapse()
                }
            }

        case .rightDock:
            let sensitivity = CGFloat(max(10, store.edgeSensitivityPx))
            let isAtRightEdge = location.x >= (screen.frame.maxX - sensitivity)

            if isAtRightEdge {
                autoCollapseWorkItem?.cancel()
                if !isExpanded {
                    setExpanded(true)
                }
            } else if isExpanded {
                let dockHitArea = NSRect(
                    x: panelFrame.minX - 30,
                    y: panelFrame.minY - 30,
                    width: panelFrame.width + 40,
                    height: panelFrame.height + 60
                )
                if NSMouseInRect(location, dockHitArea, false) {
                    autoCollapseWorkItem?.cancel()
                } else {
                    scheduleAutoCollapse()
                }
            }

        case .dynamicIsland:
            let isNearNotch = location.y >= (screen.frame.maxY - 45) && abs(location.x - screen.frame.midX) <= 120

            if isNearNotch {
                autoCollapseWorkItem?.cancel()
                if !isExpanded {
                    setExpanded(true)
                }
            } else if isExpanded {
                let hitArea = panelFrame.insetBy(dx: -40, dy: -40)
                if NSMouseInRect(location, hitArea, false) {
                    autoCollapseWorkItem?.cancel()
                } else {
                    scheduleAutoCollapse()
                }
            }
        }
    }

    private func handleMouseDown(_ location: NSPoint) {
        // If user is interacting with an open popover or modal, do NOT dismiss!
        if isInteracting || store.isPinned {
            return
        }

        guard let panel, isExpanded else { return }
        let hitArea = panel.frame.insetBy(dx: -20, dy: -20)
        if !NSMouseInRect(location, hitArea, false) {
            setExpanded(false)
        }
    }

    private func scheduleAutoCollapse() {
        guard autoCollapseWorkItem == nil, !isInteracting, !store.isPinned else { return }

        let item = DispatchWorkItem { [weak self] in
            guard let self, !self.store.isPinned, !self.isInteracting else { return }
            self.setExpanded(false)
            self.autoCollapseWorkItem = nil
        }
        self.autoCollapseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + store.autoHideDelay, execute: item)
    }
}
