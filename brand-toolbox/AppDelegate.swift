import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let store = BrandStore.shared
    private let overlay = OverlayPanelController.shared

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory agent overlay
        NSApp.setActivationPolicy(.accessory)

        // Setup floating overlay dock / island
        overlay.setup()

        // Setup menu bar icon
        setupStatusItem()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "paintpalette.fill", accessibilityDescription: "Brand Toolbox")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Brand Toolbox"
        }

        let menu = NSMenu()
        updateMenu(menu)
        item.menu = menu
        self.statusItem = item
    }

    private func updateMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        // Title item
        let titleItem = NSMenuItem(title: "Brand Toolbox", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // Toggle Panel
        let toggleTitle = overlay.isExpanded ? "Hide Toolbox" : "Show Toolbox"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleOverlay), keyEquivalent: "b")
        toggleItem.keyEquivalentModifierMask = [.command, .shift]
        toggleItem.target = self
        menu.addItem(toggleItem)

        // Mode switch submenu
        let modeMenu = NSMenu()
        for mode in OverlayPositionMode.allCases {
            let modeItem = NSMenuItem(title: mode.title, action: #selector(changeMode(_:)), keyEquivalent: "")
            modeItem.target = self
            modeItem.representedObject = mode
            if store.overlayMode == mode {
                modeItem.state = .on
            }
            modeMenu.addItem(modeItem)
        }
        let modeParent = NSMenuItem(title: "Display Mode", action: nil, keyEquivalent: "")
        modeParent.submenu = modeMenu
        menu.addItem(modeParent)

        // Pin toggle
        let pinItem = NSMenuItem(
            title: store.isPinned ? "Pinned (Always Visible)" : "Pin Open",
            action: #selector(togglePin),
            keyEquivalent: "p"
        )
        pinItem.target = self
        pinItem.state = store.isPinned ? .on : .off
        menu.addItem(pinItem)

        menu.addItem(NSMenuItem.separator())

        // Brands list
        let brandsMenu = NSMenu()
        for brand in store.brands {
            let bItem = NSMenuItem(title: brand.name, action: #selector(selectBrand(_:)), keyEquivalent: "")
            bItem.target = self
            bItem.representedObject = brand.id
            if store.selectedBrandId == brand.id {
                bItem.state = .on
            }
            brandsMenu.addItem(bItem)
        }
        let brandsParent = NSMenuItem(title: "Active Brand (\(store.selectedBrand?.name ?? ""))", action: nil, keyEquivalent: "")
        brandsParent.submenu = brandsMenu
        menu.addItem(brandsParent)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Preferences...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Brand Toolbox", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func toggleOverlay() {
        overlay.toggleExpand()
        if let menu = statusItem?.menu {
            updateMenu(menu)
        }
    }

    @objc private func changeMode(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? OverlayPositionMode {
            store.overlayMode = mode
            store.savePreferences()
            overlay.repositionPanel(animated: true)
            if let menu = statusItem?.menu {
                updateMenu(menu)
            }
        }
    }

    @objc private func togglePin() {
        store.isPinned.toggle()
        store.savePreferences()
        if let menu = statusItem?.menu {
            updateMenu(menu)
        }
    }

    @objc private func selectBrand(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? UUID {
            store.selectedBrandId = id
            store.savePreferences()
            if let menu = statusItem?.menu {
                updateMenu(menu)
            }
        }
    }

    @objc private func openSettings() {
        overlay.openSettings()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
